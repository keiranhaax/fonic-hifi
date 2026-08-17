@testable import Fonic_HiFi
import OSLog
import XCTest

@MainActor
final class AudioMonitorEngineHooksTests: XCTestCase {
    func testStartMonitoringPollsEngineMetrics() async throws {
        let engine = StubEngine()
        let expectation = expectation(description: "collectMetrics")
        expectation.expectedFulfillmentCount = 2

        engine.onCollectMetrics = {
            expectation.fulfill()
        }

        let hooks = AudioMonitorEngineHooks(
            logger: Logger(subsystem: "FonicHiFiTests", category: "AudioMonitorEngineHooksTests"),
            sleep: { interval in
                try await Task.sleep(nanoseconds: UInt64(max(interval, 0.001) * 1_000_000_000))
            }
        )

        hooks.setEngine(engine)
        hooks.startMonitoring(interval: 0.01)

        await fulfillment(of: [expectation], timeout: 0.5)

        hooks.stopMonitoring()
        XCTAssertGreaterThanOrEqual(engine.collectMetricsCallCount, 2)
    }

    func testChangingIntervalRestartsPolling() async throws {
        let engine = StubEngine()
        let firstExpectation = expectation(description: "initialCollect")
        firstExpectation.expectedFulfillmentCount = 2

        let secondExpectation = expectation(description: "updatedCollect")
        secondExpectation.expectedFulfillmentCount = 2

        var fulfillForUpdatedInterval = false
        engine.onCollectMetrics = {
            if fulfillForUpdatedInterval {
                secondExpectation.fulfill()
            } else {
                firstExpectation.fulfill()
            }
        }

        let hooks = AudioMonitorEngineHooks(
            logger: Logger(subsystem: "FonicHiFiTests", category: "AudioMonitorEngineHooksTests"),
            sleep: { interval in
                try await Task.sleep(nanoseconds: UInt64(max(interval, 0.001) * 1_000_000_000))
            }
        )

        hooks.setEngine(engine)
        hooks.startMonitoring(interval: 0.02)

        await fulfillment(of: [firstExpectation], timeout: 0.5)

        fulfillForUpdatedInterval = true
        hooks.updateMonitoringInterval(to: 0.01)

        await fulfillment(of: [secondExpectation], timeout: 0.5)

        hooks.stopMonitoring()
    }

    func testDetachingEngineStopsPolling() async throws {
        let engine = StubEngine()
        let hooks = AudioMonitorEngineHooks(
            logger: Logger(subsystem: "FonicHiFiTests", category: "AudioMonitorEngineHooksTests"),
            sleep: { interval in
                try await Task.sleep(nanoseconds: UInt64(max(interval, 0.001) * 1_000_000_000))
            }
        )

        hooks.setEngine(engine)
        hooks.startMonitoring(interval: 0.01)

        try await Task.sleep(nanoseconds: 50_000_000)

        hooks.setEngine(nil)
        let countAfterDetach = engine.collectMetricsCallCount

        try await Task.sleep(nanoseconds: 50_000_000)

        XCTAssertEqual(engine.collectMetricsCallCount, countAfterDetach)
    }

    func testUnsupportedEngineIsNotPolled() async throws {
        let engine = StubEngine(metricsAvailability: .unavailable)
        let hooks = AudioMonitorEngineHooks(
            logger: Logger(subsystem: "FonicHiFiTests", category: "AudioMonitorEngineHooksTests"),
            sleep: { _ in
                try await Task.sleep(nanoseconds: 1_000_000)
            }
        )

        hooks.setEngine(engine)
        hooks.startMonitoring(interval: 0.01)
        try await Task.sleep(nanoseconds: 30_000_000)

        XCTAssertEqual(engine.collectMetricsCallCount, 0)
    }
}

@MainActor
private final class StubEngine: AudioEngineService {
    let metricsAvailability: AudioMetricsAvailability

    init(metricsAvailability: AudioMetricsAvailability = .partial) {
        self.metricsAvailability = metricsAvailability
    }

    var currentTime: TimeInterval { get async { 0 } }
    var duration: TimeInterval { get async { 0 } }
    var isPlaying: Bool { get async { false } }
    var volume: Float { get async { 1.0 } }
    var audioFormat: AudioFormat? { get async { nil } }
    var isBitPerfect: Bool { get async { true } }

    var collectMetricsCallCount = 0
    var onCollectMetrics: (() -> Void)?

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

    func availableMetrics() async -> AudioMetrics? {
        AudioMetrics(cpuUsage: 0, memoryUsage: 0, bufferUnderruns: 0, decodingLatency: 0, bufferFillLevel: 1, droppedFrames: 0, renderLatency: 0)
    }

    func collectMetrics() async {
        collectMetricsCallCount += 1
        onCollectMetrics?()
    }
}
