import Combine
import Foundation
import Testing

@testable import Fonic_HiFi

@Suite("StateCoordinator Behavior Tests")
struct StateCoordinatorTests {
    @Test("State transitions adjust monitor cadence")
    @MainActor
    func stateTransitionsAdjustMonitoring() async throws {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let queueManager = AudioQueueManager()
        let monitor = StateCoordinatorMonitorStub()
        let facade = AudioEngineFacade(
            stateManager: stateManager,
            queueManager: queueManager,
            monitor: monitor,
            runtimeMonitoringEnabled: true
        )
        _ = facade

        stateManager.forceUpdateState(.playing(currentTime: 1, duration: 120))
        try await Task.sleep(for: .milliseconds(100))
        stateManager.forceUpdateState(.paused(currentTime: 10, duration: 120))
        try await Task.sleep(for: .milliseconds(100))
        stateManager.forceUpdateState(.stopped)
        try await Task.sleep(for: .milliseconds(100))

        #expect(monitor.startIntervals.contains(2.0))
        #expect(monitor.updateIntervals.contains(5.0))
        #expect(monitor.stopMonitoringCount >= 1)
    }

    @Test("Remote stop command routes through coordinator to facade")
    @MainActor
    func remoteStopRoutesToFacade() async throws {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let queueManager = AudioQueueManager()
        let facade = AudioEngineFacade(
            stateManager: stateManager,
            queueManager: queueManager,
            monitor: StateCoordinatorMonitorStub()
        )

        stateManager.forceUpdateState(.playing(currentTime: 3, duration: 90))
        await facade.audioSessionDidReceiveCommand(.stop)
        try await Task.sleep(for: .milliseconds(100))

        #expect(facade.currentState == .stopped)
    }

    @Test("Invalid transition is rejected by state manager")
    @MainActor
    func invalidTransitionRejected() async throws {
        let manager = PlaybackStateManager(
            initialState: .idle,
            enableTransitionValidation: true
        )

        let success = manager.updateState(.playing(currentTime: 0, duration: 60))

        #expect(success == false)
        #expect(manager.currentState == .idle)
    }

    @Test("First playing state reveals the mini player")
    @MainActor
    func playbackStateChangeKeepsMiniPlayerVisible() async throws {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let queueManager = AudioQueueManager()
        let facade = AudioEngineFacade(
            stateManager: stateManager,
            queueManager: queueManager,
            monitor: StateCoordinatorMonitorStub()
        )

        #expect(facade.showMiniPlayer == false)
        facade.setCurrentTrack(makeStateCoordinatorTrack())
        stateManager.forceUpdateState(.playing(currentTime: 0, duration: 120))
        try await Task.sleep(for: .milliseconds(100))

        #expect(facade.showMiniPlayer == true)
    }

    @Test("Non-playing state changes do not reveal the mini player")
    @MainActor
    func nonPlayingStateChangeKeepsMiniPlayerHidden() async throws {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let queueManager = AudioQueueManager()
        let facade = AudioEngineFacade(
            stateManager: stateManager,
            queueManager: queueManager,
            monitor: StateCoordinatorMonitorStub()
        )

        #expect(facade.showMiniPlayer == false)
        facade.setCurrentTrack(makeStateCoordinatorTrack())
        stateManager.forceUpdateState(.loading())
        try await Task.sleep(for: .milliseconds(100))
        #expect(facade.showMiniPlayer == false)

        stateManager.forceUpdateState(.paused(currentTime: 5, duration: 120))
        try await Task.sleep(for: .milliseconds(100))
        #expect(facade.showMiniPlayer == false)

        stateManager.forceUpdateState(.stopped)
        try await Task.sleep(for: .milliseconds(100))
        #expect(facade.showMiniPlayer == false)
    }

    @Test("Mini player stays visible after pausing mid-session")
    @MainActor
    func miniPlayerStaysVisibleAfterPause() async throws {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let queueManager = AudioQueueManager()
        let facade = AudioEngineFacade(
            stateManager: stateManager,
            queueManager: queueManager,
            monitor: StateCoordinatorMonitorStub()
        )

        facade.setCurrentTrack(makeStateCoordinatorTrack())
        stateManager.forceUpdateState(.playing(currentTime: 0, duration: 120))
        try await Task.sleep(for: .milliseconds(100))
        #expect(facade.showMiniPlayer == true)

        stateManager.forceUpdateState(.paused(currentTime: 10, duration: 120))
        try await Task.sleep(for: .milliseconds(100))
        #expect(facade.showMiniPlayer == true)
    }

    @Test("Unplug delivered as interruption plus route change never re-arms auto-resume")
    @MainActor
    func unplugInterruptionAndRouteChangeDoNotAutoResume() async throws {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let owner = StateCoordinatorOwnerSpy(stateManager: stateManager)
        let coordinator = StateCoordinator(
            stateManager: stateManager,
            queueManager: AudioQueueManager(),
            sessionManager: AudioSessionManager(),
            uiStateStore: AudioUIState(),
            facade: owner,
            monitor: StateCoordinatorMonitorStub()
        )

        stateManager.forceUpdateState(.playing(currentTime: 5, duration: 120))

        // iOS 17+ interrupts active Now Playing sessions on route disconnect,
        // so the interruption lands first and pauses playback.
        await coordinator.handleSessionInterruption(.began)
        #expect(owner.pauseCount == 1)

        // The classic route change then arrives while already paused.
        await coordinator.handleRouteChange(
            AudioRouteChange(
                reason: .oldDeviceUnavailable,
                previousRoute: "Headphones",
                currentRoute: "Speaker"
            )
        )
        #expect(owner.pauseCount == 1)

        // A conditional resume hint must not restart playback onto the new route.
        await coordinator.handleSessionInterruption(.ended(shouldResume: true))
        #expect(owner.resumeCount == 0)
    }

    @Test("Route-only unplug pauses and blocks a later resume hint")
    @MainActor
    func routeOnlyUnplugPausesWithoutAutoResume() async throws {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let owner = StateCoordinatorOwnerSpy(stateManager: stateManager)
        let coordinator = StateCoordinator(
            stateManager: stateManager,
            queueManager: AudioQueueManager(),
            sessionManager: AudioSessionManager(),
            uiStateStore: AudioUIState(),
            facade: owner,
            monitor: StateCoordinatorMonitorStub()
        )

        stateManager.forceUpdateState(.playing(currentTime: 5, duration: 120))

        await coordinator.handleRouteChange(
            AudioRouteChange(
                reason: .oldDeviceUnavailable,
                previousRoute: "Headphones",
                currentRoute: "Speaker"
            )
        )
        #expect(owner.pauseCount == 1)

        await coordinator.handleSessionInterruption(.ended(shouldResume: true))
        #expect(owner.resumeCount == 0)
    }

    @Test("Remote toggle routes to pause while playing and resume while paused")
    @MainActor
    func remoteToggleRoutesToCurrentPlaybackState() async {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let owner = StateCoordinatorOwnerSpy(stateManager: stateManager)
        let coordinator = StateCoordinator(
            stateManager: stateManager,
            queueManager: AudioQueueManager(),
            sessionManager: AudioSessionManager(),
            uiStateStore: AudioUIState(),
            facade: owner,
            monitor: StateCoordinatorMonitorStub()
        )

        stateManager.forceUpdateState(.playing(currentTime: 4, duration: 120))
        await coordinator.handleRemoteCommand(.togglePlayPause)
        #expect(owner.pauseCount == 1)

        stateManager.forceUpdateState(.paused(currentTime: 4, duration: 120))
        await coordinator.handleRemoteCommand(.togglePlayPause)
        #expect(owner.resumeCount == 1)
    }

    @Test("New route and route configuration changes renegotiate the active source rate")
    @MainActor
    func routeChangesRenegotiatePreferredSampleRate() async {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let owner = StateCoordinatorOwnerSpy(stateManager: stateManager)
        let coordinator = StateCoordinator(
            stateManager: stateManager,
            queueManager: AudioQueueManager(),
            sessionManager: AudioSessionManager(),
            uiStateStore: AudioUIState(),
            facade: owner,
            monitor: StateCoordinatorMonitorStub()
        )

        await coordinator.handleRouteChange(
            AudioRouteChange(reason: .newDeviceAvailable, previousRoute: "Speaker", currentRoute: "Headphones")
        )
        await coordinator.handleRouteChange(
            AudioRouteChange(reason: .routeConfigurationChange, previousRoute: "Headphones", currentRoute: "USB")
        )

        #expect(owner.renegotiatePreferredSampleRateCount == 2)
    }

}

@MainActor
private final class StateCoordinatorOwnerSpy: AudioStateCoordinatorOwner {
    private let stateManager: PlaybackStateManager
    private(set) var pauseCount = 0
    private(set) var resumeCount = 0
    private(set) var renegotiatePreferredSampleRateCount = 0

    init(stateManager: PlaybackStateManager) {
        self.stateManager = stateManager
    }

    var isRuntimeMonitoringEnabled: Bool { false }
    var stateCoordinatorMonitor: any AudioPerformanceMonitoring { StateCoordinatorMonitorStub() }

    func resume() async throws {
        resumeCount += 1
    }

    func pause() async {
        pauseCount += 1
        stateManager.forceUpdateState(.paused(currentTime: 5, duration: 120))
    }

    func stop() async {}
    func playNext() async throws {}
    func playPrevious() async throws {}
    func seek(to _: TimeInterval) async throws {}
    func reportPlaybackControlError(_: Error) {}

    func renegotiatePreferredSampleRate() async {
        renegotiatePreferredSampleRateCount += 1
    }
}

@MainActor
private func makeStateCoordinatorTrack() -> Track {
    Track(
        url: URL(fileURLWithPath: "/tmp/state-coordinator.flac"),
        title: "State Coordinator",
        artist: "Test Artist",
        album: "Test Album",
        audioFormat: "FLAC",
        duration: 120
    )
}

@MainActor
private final class StateCoordinatorMonitorStub: AudioPerformanceMonitoring, PlaybackHealthEventLogging {
    var metricsPublisher: AnyPublisher<AudioMetrics, Never> { Empty(completeImmediately: false).eraseToAnyPublisher() }

    private(set) var startIntervals: [TimeInterval] = []
    private(set) var updateIntervals: [TimeInterval] = []
    private(set) var stopMonitoringCount = 0
    private(set) var playbackHealthEvents: [PlaybackHealthEvent] = []
    private let playbackHealthEventsSubject = CurrentValueSubject<[PlaybackHealthEvent], Never>([])

    var playbackHealthEventsPublisher: AnyPublisher<[PlaybackHealthEvent], Never> {
        playbackHealthEventsSubject.eraseToAnyPublisher()
    }

    func recordPlaybackHealthEvent(_ kind: PlaybackHealthEvent.Kind, detail: String?) {
        playbackHealthEvents.append(
            PlaybackHealthEvent(kind: kind, timestamp: Date(), detail: detail)
        )
        playbackHealthEventsSubject.send(playbackHealthEvents)
    }

    var isMonitoring: Bool { get async { !startIntervals.isEmpty && stopMonitoringCount == 0 } }

    func startMonitoring(updateInterval: TimeInterval) async {
        startIntervals.append(updateInterval)
    }

    func stopMonitoring() async {
        stopMonitoringCount += 1
    }

    func updateMonitoringInterval(_ interval: TimeInterval) async {
        updateIntervals.append(interval)
    }

    func getCurrentMetrics() async -> AudioMetrics { .empty }

    func getSystemAudioMetrics() async -> SystemAudioMetrics {
        SystemAudioMetrics(
            systemAudioCPU: 0,
            activeAudioSessions: 0,
            systemAudioMemory: 0,
            deviceInfo: AudioDeviceInfo(
                deviceID: "stub",
                name: "stub",
                sampleRate: 44_100,
                bitDepth: 16,
                channels: 2,
                bufferSize: 512,
                latency: 0
            ),
            interruptionCount: 0,
            audioUnitLoad: 0
        )
    }

    func attachToEngine(_: AudioEngineService) async {}
    func detachFromEngine() async {}
    var currentEngine: AudioEngineService? { get async { nil } }

    func startProfiling(duration _: TimeInterval?) async {}
    func stopProfiling() async {}
    var isProfiling: Bool { get async { false } }

}
