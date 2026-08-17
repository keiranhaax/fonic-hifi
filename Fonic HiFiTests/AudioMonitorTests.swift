import Foundation
@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioMonitorTests: XCTestCase {
    func testStartMonitoringDelegatesToRuntimeAndEngineHooks() async throws {
        let runtime = StubRuntime()
        let hooks = StubEngineHooks()
        let monitor = makeMonitor(runtime: runtime, hooks: hooks)

        await monitor.startMonitoring(updateInterval: 0.5)

        XCTAssertEqual(runtime.startMonitoringCalls.count, 1)
        let call = try XCTUnwrap(runtime.startMonitoringCalls.first)
        XCTAssertEqual(call.interval, 0.5, accuracy: 0.0001)
        XCTAssertNil(call.engine)
        XCTAssertEqual(hooks.startMonitoringIntervals, [0.5])
    }

    func testAttachAndDetachEnginePropagatesToCollaborators() async {
        let runtime = StubRuntime()
        let hooks = StubEngineHooks()
        let monitor = makeMonitor(runtime: runtime, hooks: hooks)
        let engine = StubEngineService()

        await monitor.attachToEngine(engine)
        await monitor.detachFromEngine()

        XCTAssertEqual(runtime.updateEngineValues.count, 2)
        XCTAssertTrue(runtime.updateEngineValues[0] is StubEngineService)
        XCTAssertNil(runtime.updateEngineValues[1])
        XCTAssertEqual(hooks.setEngineValues.count, 2)
        XCTAssertTrue(hooks.setEngineValues[0] is StubEngineService)
        XCTAssertNil(hooks.setEngineValues[1])
    }

    func testPlaybackHealthEventsRemainAvailableOnLiveMonitorSurface() {
        let monitor = makeMonitor(runtime: StubRuntime(), hooks: StubEngineHooks())

        monitor.recordPlaybackHealthEvent(.audioEngineConfigurationRecoveryFailed, detail: "test")

        XCTAssertEqual(monitor.playbackHealthEvents.count, 1)
        XCTAssertEqual(monitor.playbackHealthEvents.first?.detail, "test")
    }

    private func makeMonitor(runtime: StubRuntime, hooks: StubEngineHooks) -> AudioMonitor {
        AudioMonitor(
            alertManager: StubAlertManager(),
            runtimeController: runtime,
            engineHookController: hooks
        )
    }
}

@MainActor
private final class StubRuntime: AudioMonitorRuntimeControlling {
    struct StartCall {
        let interval: TimeInterval
        let engine: AudioEngineService?
    }

    private(set) var startMonitoringCalls: [StartCall] = []
    private(set) var updateEngineValues: [AudioEngineService?] = []
    var updateInterval: TimeInterval = 1.0
    var isMonitoring = false
    var isProfiling = false

    func startMonitoring(updateInterval: TimeInterval, engine: AudioEngineService?) async {
        self.updateInterval = updateInterval
        isMonitoring = true
        startMonitoringCalls.append(StartCall(interval: updateInterval, engine: engine))
    }

    func stopMonitoring() async {
        isMonitoring = false
    }

    func updateMonitoringInterval(to interval: TimeInterval) {
        updateInterval = interval
    }

    func collectCurrentMetrics() async -> AudioMetrics {
        .empty
    }

    func evaluateAlerts() async {}

    func startProfiling(duration _: TimeInterval?) async {
        isProfiling = true
    }

    func stopProfiling() async {
        isProfiling = false
    }

    func updateEngine(_ engine: AudioEngineService?) {
        updateEngineValues.append(engine)
    }

    func invalidate() {}
}

@MainActor
private final class StubEngineHooks: AudioMonitorEngineHooking {
    private(set) var setEngineValues: [AudioEngineService?] = []
    private(set) var startMonitoringIntervals: [TimeInterval] = []

    func setEngine(_ engine: AudioEngineService?) {
        setEngineValues.append(engine)
    }

    func startMonitoring(interval: TimeInterval) {
        startMonitoringIntervals.append(interval)
    }

    func stopMonitoring() {}

    func updateMonitoringInterval(to _: TimeInterval) {}
}

@MainActor
private final class StubAlertManager: AudioAlertManaging {
    var alertConfiguration: AlertConfiguration = .default
    var alertHistory: [PlaybackAlert] = []

    func updateConfiguration(_ configuration: AlertConfiguration) {
        alertConfiguration = configuration
    }

    func evaluateAlerts(for _: AudioMetrics) -> [PlaybackAlert] {
        []
    }

    func recordInterruptionAlert(_ alert: PlaybackAlert) {
        alertHistory.append(alert)
    }

    func reset() {
        alertHistory.removeAll()
    }
}

extension StubAlertManager: @unchecked Sendable {}

@MainActor
private final class StubEngineService: AudioEngineService {
    var currentTime: TimeInterval { get async { 0 } }
    var duration: TimeInterval { get async { 0 } }
    var isPlaying: Bool { get async { false } }
    var volume: Float { get async { 1.0 } }
    var audioFormat: AudioFormat? { get async { nil } }
    var isBitPerfect: Bool { get async { true } }

    func load(url _: URL) async throws {}
    func play() async throws {}
    func pause() async {}
    func stop() async {}
    func seek(to _: TimeInterval) async throws {}
    func setVolume(_: Float) async {}
    func setPlaybackRate(_: Double) async {}
    func applyReplayGain(_: Float) async {}
    func configure(with _: AudioEngineConfiguration) async throws {}
    func prepareNext(url _: URL) async {}
    func invalidatePreparedTransition() async {}
    func crossfade(to _: URL, duration _: TimeInterval, playbackRate _: Double, gainDB _: Float) async throws {}
    var metricsAvailability: AudioMetricsAvailability { .available }
    func availableMetrics() async -> AudioMetrics? { .empty }
    func collectMetrics() async {}
}
