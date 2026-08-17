@testable import Fonic_HiFi
import OSLog
import XCTest

@MainActor
final class AudioMonitorRuntimeTests: XCTestCase {
    func testStartMonitoringPublishesMetricsAndAlerts() async throws {
        let scheduler = AudioMetricsScheduler()
        let analytics = AudioSessionAnalytics()
        let metricsCollector = makeMetricsCollector()
        let alert = PlaybackAlert(
            type: .highCPUUsage,
            severity: .high,
            message: "High CPU",
            technicalDetails: "",
            triggerValues: [:],
            suggestedActions: []
        )
        let alertManager = StubAlertManager(alerts: [alert])
        let logger = Logger(subsystem: "FonicHiFiTests", category: "AudioMonitorRuntime")

        var publishedMetrics: [AudioMetrics] = []
        var publishedHealth: [PlaybackHealthStatus] = []
        var publishedAlerts: [PlaybackAlert] = []

        let metricsExpectation = expectation(description: "metrics")
        let alertExpectation = expectation(description: "alert")

        let runtime = AudioMonitorRuntime(
            scheduler: scheduler,
            analytics: analytics,
            metricsCollector: metricsCollector,
            alertManager: alertManager,
            performanceMonitor: nil,
            logger: logger,
            publishMetrics: { metrics in
                publishedMetrics.append(metrics)
                if publishedMetrics.count == 1 {
                    metricsExpectation.fulfill()
                }
            },
            publishHealthStatus: { status in
                publishedHealth.append(status)
            },
            publishAlert: { newAlert in
                publishedAlerts.append(newAlert)
                if publishedAlerts.count == 1 {
                    alertExpectation.fulfill()
                }
            }
        )

        await runtime.startMonitoring(updateInterval: 0.05, engine: nil)

        await fulfillment(of: [metricsExpectation, alertExpectation], timeout: 1.0)

        XCTAssertFalse(publishedMetrics.isEmpty)
        XCTAssertFalse(publishedHealth.isEmpty)
        XCTAssertEqual(publishedAlerts.count, 1)
        XCTAssertEqual(alertManager.evaluatedMetricsCount, 1)

        await runtime.stopMonitoring()
        XCTAssertFalse(runtime.isMonitoring)
    }

    func testUpdateMonitoringIntervalWhileActive() async {
        let scheduler = AudioMetricsScheduler()
        let analytics = AudioSessionAnalytics()
        let metricsCollector = makeMetricsCollector()
        let alertManager = StubAlertManager(alerts: [])
        let logger = Logger(subsystem: "FonicHiFiTests", category: "AudioMonitorRuntime")

        let runtime = AudioMonitorRuntime(
            scheduler: scheduler,
            analytics: analytics,
            metricsCollector: metricsCollector,
            alertManager: alertManager,
            performanceMonitor: nil,
            logger: logger,
            publishMetrics: { _ in },
            publishHealthStatus: { _ in },
            publishAlert: { _ in }
        )

        await runtime.startMonitoring(updateInterval: 0.05, engine: nil)
        runtime.updateMonitoringInterval(to: 0.12)

        XCTAssertEqual(runtime.updateInterval, 0.12, accuracy: 0.0001)

        await runtime.stopMonitoring()
    }

    func testUpdateMonitoringIntervalIgnoredWhenIdle() {
        let scheduler = AudioMetricsScheduler()
        let analytics = AudioSessionAnalytics()
        let metricsCollector = makeMetricsCollector()
        let alertManager = StubAlertManager(alerts: [])
        let logger = Logger(subsystem: "FonicHiFiTests", category: "AudioMonitorRuntime")

        let runtime = AudioMonitorRuntime(
            scheduler: scheduler,
            analytics: analytics,
            metricsCollector: metricsCollector,
            alertManager: alertManager,
            performanceMonitor: nil,
            logger: logger,
            publishMetrics: { _ in },
            publishHealthStatus: { _ in },
            publishAlert: { _ in }
        )

        runtime.updateMonitoringInterval(to: 0.2)
        XCTAssertEqual(runtime.updateInterval, 1.0)
    }

}

// MARK: - Test Helpers

@MainActor
private func makeMetricsCollector() -> AudioMonitorMetricsCollector {
    let system = StubSystemMetricsCollector()
    let thermal = StubThermalMonitor()
    let engine = StubEngineMetricsCollector()
    return AudioMonitorMetricsCollector(
        systemMetricsCollector: system,
        thermalStateMonitor: thermal,
        engineMetricsCollector: engine
    )
}

@MainActor
private final class StubAlertManager: AudioAlertManaging {
    private(set) var evaluatedMetricsCount = 0
    private let alertsToReturn: [PlaybackAlert]

    init(alerts: [PlaybackAlert]) {
        self.alertsToReturn = alerts
    }

    var alertConfiguration: AlertConfiguration { .default }
    var alertHistory: [PlaybackAlert] { [] }

    func updateConfiguration(_ configuration: AlertConfiguration) {}

    func evaluateAlerts(for metrics: AudioMetrics) -> [PlaybackAlert] {
        evaluatedMetricsCount += 1
        return alertsToReturn
    }

    func recordInterruptionAlert(_ alert: PlaybackAlert) {}

    func reset() {}
}

@MainActor
private final class StubSystemMetricsCollector: SystemMetricsCollecting {
    func startMonitoring() async {}

    func collectCurrentMetrics() async -> SystemMetrics {
        SystemMetrics(
            cpuUsage: 65,
            memoryUsage: 420_000_000,
            diskIOPS: 150,
            networkBandwidth: 1_000_000,
            batteryUsageRate: 120
        )
    }

    func collectSystemMetrics() async -> SystemAudioMetrics {
        SystemAudioMetrics(
            systemAudioCPU: 20,
            activeAudioSessions: 1,
            systemAudioMemory: 120_000_000,
            deviceInfo: AudioDeviceInfo(
                deviceID: "test",
                name: "Test Device",
                sampleRate: 96_000,
                bitDepth: 24,
                channels: 2,
                bufferSize: 512,
                latency: 0.03
            ),
            interruptionCount: 0,
            audioUnitLoad: 0.4
        )
    }
}

@MainActor
private final class StubThermalMonitor: ThermalStateMonitoring {
    func startMonitoring() async {}

    func getCurrentState() async -> ThermalMonitoringInfo {
        ThermalMonitoringInfo(thermalState: .fair, isThrottling: false, recommendedAdjustments: [])
    }
}

@MainActor
private final class StubEngineMetricsCollector: EngineMetricsCollecting {
    func metrics(for engine: AudioEngineService?) async -> EngineMetrics {
        EngineMetrics(
            bufferUnderruns: 1,
            decodingLatency: 0.02,
            bufferFillLevel: 0.6,
            droppedFrames: 0,
            renderLatency: 0.03,
            currentBitrate: 2_000_000,
            glitchCount: 0,
            sampleRate: 96_000,
            bitDepth: 24,
            channelCount: 2,
            engineType: "TestEngine",
            audioFormat: "FLAC",
            isBitPerfect: true,
            bufferSize: 512,
            bufferResets: 0,
            threadUtilization: ThreadUtilization(audioThreadCPU: 15, decoderThreadCPU: 10, ioThreadCPU: 5, mainThreadCPU: 5, activeThreadCount: 4, threadPriorities: [:]),
            estimatedSNR: 110,
            dynamicRange: 85,
            frequencyResponseScore: 0.9,
            jitter: 0.002,
            clockDrift: 0.001,
            recoverableErrors: 0,
            criticalErrors: 0,
            recoverySuccessRate: 1.0,
            lastRecoveryTime: nil
        )
    }
}
