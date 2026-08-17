import Combine
@testable import Fonic_HiFi
import Foundation
import Testing

@Suite("State Coordinator Interruption and Route Safety")
struct StateCoordinatorInterruptionTests {
    @Test(
        "Interruption resumes only when playback was active and the system permits it",
        arguments: [
            (PlaybackState.playing(currentTime: 10, duration: 120), true, 1, 1),
            (PlaybackState.playing(currentTime: 10, duration: 120), false, 1, 0),
            (PlaybackState.paused(currentTime: 10, duration: 120), true, 0, 0),
            (PlaybackState.paused(currentTime: 10, duration: 120), false, 0, 0),
        ]
    )
    @MainActor
    func interruptionIntentMatrix(
        initialState: PlaybackState,
        systemShouldResume: Bool,
        expectedPauseCount: Int,
        expectedResumeCount: Int
    ) async {
        let harness = makeHarness(initialState: initialState)

        await harness.coordinator.handleSessionInterruption(.began)
        await harness.coordinator.handleSessionInterruption(
            .ended(shouldResume: systemShouldResume)
        )

        #expect(harness.owner.pauseCallCount == expectedPauseCount)
        #expect(harness.owner.resumeCallCount == expectedResumeCount)
    }

    @Test("Route loss pauses active playback and cancels interruption resume intent")
    @MainActor
    func routeLossPausesActivePlayback() async {
        let harness = makeHarness(
            initialState: .playing(currentTime: 30, duration: 180)
        )

        await harness.coordinator.handleSessionInterruption(.began)
        await harness.coordinator.handleRouteChange(
            AudioRouteChange(
                reason: .oldDeviceUnavailable,
                previousRoute: "Headphones",
                currentRoute: "Speaker"
            )
        )
        await harness.coordinator.handleSessionInterruption(.ended(shouldResume: true))

        #expect(harness.owner.pauseCallCount == 2)
        #expect(harness.owner.resumeCallCount == 0)
    }

    @Test("Route loss does not issue a redundant pause while already paused")
    @MainActor
    func routeLossDoesNotPauseInactivePlayback() async {
        let harness = makeHarness(
            initialState: .paused(currentTime: 30, duration: 180)
        )

        await harness.coordinator.handleRouteChange(
            AudioRouteChange(
                reason: .oldDeviceUnavailable,
                previousRoute: "Headphones",
                currentRoute: "Speaker"
            )
        )

        #expect(harness.owner.pauseCallCount == 0)
    }

    @MainActor
    private func makeHarness(initialState: PlaybackState) -> Harness {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        stateManager.forceUpdateState(initialState)
        let queueManager = AudioQueueManager()
        let monitor = StateCoordinatorMonitorStub()
        let owner = StateCoordinatorOwnerSpy(monitor: monitor)
        let coordinator = StateCoordinator(
            stateManager: stateManager,
            queueManager: queueManager,
            sessionManager: AudioSessionManager(
                notificationCenter: NotificationCenter()
            ),
            uiStateStore: AudioUIState(),
            facade: owner,
            monitor: monitor
        )
        return Harness(coordinator: coordinator, owner: owner)
    }
}

@MainActor
private struct Harness {
    let coordinator: StateCoordinator
    let owner: StateCoordinatorOwnerSpy
}

@MainActor
private final class StateCoordinatorOwnerSpy: AudioStateCoordinatorOwner {
    let stateCoordinatorMonitor: any AudioPerformanceMonitoring
    var isRuntimeMonitoringEnabled = false
    private(set) var resumeCallCount = 0
    private(set) var pauseCallCount = 0

    init(monitor: any AudioPerformanceMonitoring) {
        stateCoordinatorMonitor = monitor
    }

    func resume() async throws {
        resumeCallCount += 1
    }

    func pause() async {
        pauseCallCount += 1
    }

    func stop() async {}
    func playNext() async throws {}
    func playPrevious() async throws {}
    func seek(to _: TimeInterval) async throws {}
    func renegotiatePreferredSampleRate() async {}
    func reportPlaybackControlError(_: Error) {}
}

@MainActor
private final class StateCoordinatorMonitorStub: AudioPerformanceMonitoring {
    var metricsPublisher: AnyPublisher<AudioMetrics, Never> {
        Empty(completeImmediately: false).eraseToAnyPublisher()
    }

    var isMonitoring: Bool {
        get async { false }
    }

    var currentEngine: AudioEngineService? {
        get async { nil }
    }

    var isProfiling: Bool {
        get async { false }
    }

    func startMonitoring(updateInterval _: TimeInterval) async {}
    func stopMonitoring() async {}
    func updateMonitoringInterval(_: TimeInterval) async {}
    func getCurrentMetrics() async -> AudioMetrics {
        .empty
    }

    func getSystemAudioMetrics() async -> SystemAudioMetrics {
        SystemAudioMetrics(
            systemAudioCPU: 0,
            activeAudioSessions: 0,
            systemAudioMemory: 0,
            deviceInfo: AudioDeviceInfo(
                deviceID: "state-coordinator-test",
                name: "State Coordinator Test",
                sampleRate: 44100,
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
    func startProfiling(duration _: TimeInterval?) async {}
    func stopProfiling() async {}
}
