import AVFoundation
@testable import Fonic_HiFi
import MediaPlayer
import XCTest

final class AudioSessionServiceTests: XCTestCase {
    func testRouteChangeReasonMappingMatchesAVFoundationCases() {
        let expectations: [(AVAudioSession.RouteChangeReason, AudioRouteChangeReason)] = [
            (.newDeviceAvailable, .newDeviceAvailable),
            (.oldDeviceUnavailable, .oldDeviceUnavailable),
            (.categoryChange, .categoryChange),
            (.override, .override),
            (.wakeFromSleep, .wakeFromSleep),
            (.noSuitableRouteForCategory, .noSuitableRouteForCategory),
            (.routeConfigurationChange, .routeConfigurationChange),
        ]

        for (reason, expected) in expectations {
            XCTAssertEqual(AudioRouteChangeReason(from: reason), expected)
        }

        XCTAssertEqual(AudioRouteChangeReason(from: .unknown), .unknown)
    }

    func testRouteChangeReasonDescriptions() {
        let allReasons: [AudioRouteChangeReason] = [
            .newDeviceAvailable,
            .oldDeviceUnavailable,
            .categoryChange,
            .override,
            .wakeFromSleep,
            .noSuitableRouteForCategory,
            .routeConfigurationChange,
            .unknown,
        ]

        for reason in allReasons {
            XCTAssertFalse(reason.description.isEmpty)
        }
    }

    func testRemoteCommandDescriptionsRenderAssociatedValues() {
        XCTAssertEqual(RemoteCommand.play.description, "play")
        XCTAssertEqual(RemoteCommand.pause.description, "pause")
        XCTAssertEqual(RemoteCommand.changePlaybackRate(1.25).description, "changePlaybackRate(1.25)")
        XCTAssertEqual(RemoteCommand.seek(to: 42.5).description, "seek(to: 42.5)")
        XCTAssertEqual(RemoteCommand.skipForward(15).description, "skipForward(15.0)")
        XCTAssertEqual(RemoteCommand.skipBackward(7.5).description, "skipBackward(7.5)")
    }

    func testModernInterruptionMappingIgnoresAppDeactivationAndMapsRecommendations() {
        XCTAssertNil(
            AudioSessionManager.interruption(from: AVAudioSession.DeactivationResult.appDeactivated)
        )

        guard case let .ended(shouldResume) = AudioSessionManager.interruption(
            from: AVAudioSession.ResumptionRecommendation.shouldResume
        ) else {
            return XCTFail("Expected a resumption event")
        }
        XCTAssertTrue(shouldResume)

        guard case let .ended(shouldResume) = AudioSessionManager.interruption(
            from: AVAudioSession.ResumptionRecommendation.shouldNotResume
        ) else {
            return XCTFail("Expected a non-resumption event")
        }
        XCTAssertFalse(shouldResume)
    }

    @MainActor
    func testPlaybackConfigurationDoesNotUsePlayAndRecordOnlyAirPlayOption() async throws {
        let manager = AudioSessionManager()

        try await manager.configureAudioSession()

        let session = AVAudioSession.sharedInstance()
        XCTAssertEqual(session.category, .playback)
        XCTAssertFalse(session.categoryOptions.contains(.allowAirPlay))
    }

    @MainActor
    func testActivationAndDeactivationUpdateManagedState() async throws {
        let manager = AudioSessionManager()

        try await manager.configureAudioSession()
        try await manager.activateAudioSession()
        let isActive = await manager.isSessionActive
        XCTAssertTrue(isActive)

        try await manager.deactivateAudioSession()
        let isInactive = await manager.isSessionActive
        XCTAssertFalse(isInactive)
    }

    @MainActor
    func testUnsupportedSkipCommandsRemainDisabledWhenRemoteCommandsAreEnabled() async {
        let manager = AudioSessionManager()
        let commandCenter = MPRemoteCommandCenter.shared()

        await manager.disableRemoteCommands()
        await manager.enableRemoteCommands()

        XCTAssertFalse(commandCenter.skipForwardCommand.isEnabled)
        XCTAssertFalse(commandCenter.skipBackwardCommand.isEnabled)

        await manager.disableRemoteCommands()
    }

    @MainActor
    func testRemoteCommandRegistrationIsIdempotentAndUnregistersEveryOwnedCommand() async {
        let manager = AudioSessionManager()

        await manager.enableRemoteCommands()
        let firstRegistration = manager.registeredRemoteCommandDescriptions
        let firstGeneration = manager.remoteCommandRegistrationGeneration

        await manager.enableRemoteCommands()

        XCTAssertEqual(manager.registeredRemoteCommandDescriptions, firstRegistration)
        XCTAssertEqual(
            manager.remoteCommandRegistrationGeneration,
            firstGeneration + 1
        )
        XCTAssertTrue(firstRegistration.contains("stop"))
        XCTAssertTrue(firstRegistration.contains("togglePlayPause"))

        await manager.disableRemoteCommands()
        XCTAssertTrue(manager.registeredRemoteCommandDescriptions.isEmpty)
    }

    @MainActor
    func testRegisteredRemoteCommandTestingRouteDeliversStopAndToggleOnlyWhileRegistered() async {
        let manager = AudioSessionManager()
        let delegate = MediaServicesResetDelegateSpy()
        let commandHandled = expectation(description: "registered remote commands handled")
        commandHandled.expectedFulfillmentCount = 2
        delegate.onCommand = { commandHandled.fulfill() }
        manager.delegate = delegate

        await manager.enableRemoteCommands()
        manager.dispatchRegisteredRemoteCommandForTesting(.stop)
        manager.dispatchRegisteredRemoteCommandForTesting(.togglePlayPause)
        await fulfillment(of: [commandHandled], timeout: 2)
        XCTAssertEqual(delegate.commandCount, 2)

        await manager.disableRemoteCommands()
        manager.dispatchRegisteredRemoteCommandForTesting(.stop)
        await Task.yield()
        XCTAssertEqual(delegate.commandCount, 2)
    }

    @MainActor
    func testMediaServicesResetRebuildsCommandsAndNotifiesPlaybackOwner() async throws {
        let notificationCenter = NotificationCenter()
        let manager = AudioSessionManager(notificationCenter: notificationCenter)
        let delegate = MediaServicesResetDelegateSpy()
        let resetHandled = expectation(description: "media services reset handled")
        delegate.onReset = {
            resetHandled.fulfill()
        }
        manager.delegate = delegate

        try await manager.configureAudioSession()
        let initialCommandGeneration = manager.remoteCommandRegistrationGeneration

        notificationCenter.post(
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: AVAudioSession.sharedInstance()
        )

        await fulfillment(of: [resetHandled], timeout: 2)
        XCTAssertEqual(
            manager.remoteCommandRegistrationGeneration,
            initialCommandGeneration + 1
        )

        await manager.disableRemoteCommands()
    }

    @MainActor
    func testFrameworkCallbacksFromConcurrentExecutorHopToDelegateOwner() async throws {
        let notificationCenter = NotificationCenter()
        let manager = AudioSessionManager(notificationCenter: notificationCenter)
        let delegate = MediaServicesResetDelegateSpy()
        let interruptionHandled = expectation(description: "interruption callback handled")
        let routeHandled = expectation(description: "route callback handled")
        let remoteCommandHandled = expectation(description: "remote callback handled")
        delegate.onInterruption = {
            interruptionHandled.fulfill()
        }
        delegate.onRouteChange = {
            routeHandled.fulfill()
        }
        delegate.onCommand = {
            remoteCommandHandled.fulfill()
        }
        manager.delegate = delegate
        try await manager.configureAudioSession()

        let postCallbacks = Task { @concurrent in
            AudioSessionManager.routeInterruption(
                AudioSessionManager.interruption(from: .shouldResume),
                to: manager
            )
            notificationCenter.post(
                name: AVAudioSession.routeChangeNotification,
                object: AVAudioSession.sharedInstance(),
                userInfo: [
                    AVAudioSessionRouteChangeReasonKey:
                        AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue,
                ]
            )
            AudioSessionManager.routeRemoteCommand(.nextTrack, to: manager)
        }
        await postCallbacks.value

        await fulfillment(
            of: [interruptionHandled, routeHandled, remoteCommandHandled],
            timeout: 2
        )

        guard case let .ended(shouldResume)? = delegate.lastInterruption else {
            return XCTFail("Expected interruption-ended callback")
        }
        XCTAssertTrue(shouldResume)
        XCTAssertEqual(delegate.lastRouteChange?.reason, .oldDeviceUnavailable)
        guard case .nextTrack? = delegate.lastCommand else {
            return XCTFail("Expected next-track remote command")
        }
    }

    @MainActor
    func testRepeatedTeardownDeactivatesManagedSessionOnce() async throws {
        let manager = AudioSessionManager(notificationCenter: NotificationCenter())
        try await manager.configureAudioSession()
        try await manager.activateAudioSession()
        let facade = AudioEngineFacade(
            sessionManager: manager,
            monitor: AudioMonitor(),
            runtimeMonitoringEnabled: false
        )

        await facade.shutdown()
        await facade.shutdown()

        XCTAssertEqual(manager.activationTransitionCount, 1)
        XCTAssertEqual(manager.deactivationTransitionCount, 1)
    }
}

@MainActor
private final class MediaServicesResetDelegateSpy: AudioSessionDelegate {
    var onReset: (() -> Void)?
    var onInterruption: (() -> Void)?
    var onRouteChange: (() -> Void)?
    var onCommand: (() -> Void)?
    private(set) var lastInterruption: AudioInterruptionType?
    private(set) var lastRouteChange: AudioRouteChange?
    private(set) var lastCommand: RemoteCommand?
    private(set) var commandCount = 0

    func audioSessionDidInterrupt(_ interruption: AudioInterruptionType) async {
        lastInterruption = interruption
        onInterruption?()
    }

    func audioSessionRouteDidChange(_ change: AudioRouteChange) async {
        lastRouteChange = change
        onRouteChange?()
    }

    func audioSessionDidReceiveCommand(_ command: RemoteCommand) async {
        lastCommand = command
        commandCount += 1
        onCommand?()
    }

    func audioSessionMediaServicesWereReset() async {
        onReset?()
    }
}
