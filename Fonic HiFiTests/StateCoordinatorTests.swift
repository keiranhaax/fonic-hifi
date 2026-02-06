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
            monitor: monitor
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

    @Test("Playback state change keeps mini player visible")
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
        stateManager.forceUpdateState(.playing(currentTime: 0, duration: 120))
        try await Task.sleep(for: .milliseconds(100))

        #expect(facade.showMiniPlayer == true)
    }

}

@MainActor
private final class StateCoordinatorMonitorStub: AudioPerformanceMonitoring, AudioDiagnosticsReporting {
    var metricsPublisher: AnyPublisher<AudioMetrics, Never> { Empty(completeImmediately: false).eraseToAnyPublisher() }

    private(set) var startIntervals: [TimeInterval] = []
    private(set) var updateIntervals: [TimeInterval] = []
    private(set) var stopMonitoringCount = 0

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
    func getProfilingResults() async -> PerformanceProfile? { nil }
    var isProfiling: Bool { get async { false } }

    func performDiagnosticsCheck() async -> PlaybackDiagnostics {
        fatalError("performDiagnosticsCheck() is not used by these tests")
    }

    func getPerformanceRecommendations() async -> [PerformanceRecommendation] {
        []
    }

    func exportMetrics(format _: ExportFormat, timeRange _: DateInterval?) async -> Data {
        Data()
    }

    func generateReport(for _: DateInterval) async -> MonitoringReport {
        fatalError("generateReport(for:) is not used by these tests")
    }
}
