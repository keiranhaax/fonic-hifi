@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioMonitorMetricsCollectorTests: XCTestCase {
    func testCollectorCombinesMetricsAndCalculatesScores() async {
        let systemMetrics = SystemMetrics(
            cpuUsage: 85,
            memoryUsage: 750_000_000,
            diskIOPS: 120,
            networkBandwidth: 9_000_000,
            batteryUsageRate: 80
        )

        let thermalInfo = ThermalMonitoringInfo(
            thermalState: .serious,
            cpuTemperature: 42,
            isThrottling: true,
            recommendedAdjustments: ["Reduce workload"],
            timestamp: Date()
        )

        let engineMetrics = EngineMetrics(
            bufferUnderruns: 2,
            decodingLatency: 0.05,
            bufferFillLevel: 0.4,
            droppedFrames: 1,
            renderLatency: 0.2,
            currentBitrate: 3_000_000,
            glitchCount: 1,
            sampleRate: 192_000,
            bitDepth: 24,
            channelCount: 2,
            engineType: "AVAudioEngine",
            audioFormat: "FLAC",
            isBitPerfect: false,
            bufferSize: 512,
            bufferResets: 0,
            threadUtilization: ThreadUtilization(
                audioThreadCPU: 40,
                decoderThreadCPU: 20,
                ioThreadCPU: 10,
                mainThreadCPU: 5,
                activeThreadCount: 4,
                threadPriorities: ["audio": 0.9]
            ),
            estimatedSNR: 110,
            dynamicRange: 80,
            frequencyResponseScore: 0.95,
            jitter: 0.005,
            clockDrift: 0.001,
            recoverableErrors: 1,
            criticalErrors: 1,
            recoverySuccessRate: 0.5,
            lastRecoveryTime: 2
        )

        let collector = AudioMonitorMetricsCollector(
            systemMetricsCollector: StubSystemMetricsCollector(current: systemMetrics),
            thermalStateMonitor: StubThermalMonitor(state: thermalInfo),
            engineMetricsCollector: StubEngineMetricsCollector(metrics: engineMetrics)
        )

        let analytics = AudioSessionAnalytics()
        analytics.startNewSession(at: Date().addingTimeInterval(-120))

        analytics.append(
            AudioMetrics(
                cpuUsage: 70,
                memoryUsage: 600_000_000,
                bufferUnderruns: 1,
                decodingLatency: 0.04,
                bufferFillLevel: 0.6,
                droppedFrames: 0,
                renderLatency: 0.12,
                performanceScore: 0.8,
                qualityScore: 0.85,
                efficiencyScore: 0.65
            )
        )
        analytics.append(
            AudioMetrics(
                cpuUsage: 75,
                memoryUsage: 650_000_000,
                bufferUnderruns: 0,
                decodingLatency: 0.03,
                bufferFillLevel: 0.7,
                droppedFrames: 0,
                renderLatency: 0.1,
                performanceScore: 0.9,
                qualityScore: 0.9,
                efficiencyScore: 0.7
            )
        )

        let result = await collector.collectMetrics(for: nil, analytics: analytics, timeSinceLastUnderrun: 12)

        XCTAssertEqual(result.cpuUsage, systemMetrics.cpuUsage)
        XCTAssertEqual(result.memoryUsage, systemMetrics.memoryUsage)
        XCTAssertEqual(result.bufferUnderruns, engineMetrics.bufferUnderruns)
        XCTAssertEqual(result.currentBitrate, engineMetrics.currentBitrate)
        XCTAssertEqual(result.averageLatency, analytics.averageLatency(), accuracy: 0.0001)
        XCTAssertEqual(result.peakLatency, analytics.peakLatency(), accuracy: 0.0001)
        XCTAssertEqual(result.averageBufferFill, analytics.averageBufferFill(), accuracy: 0.0001)
        XCTAssertEqual(result.thermalPressure, 0.8, accuracy: 0.001)
        XCTAssertEqual(result.performanceScore, 0)
        XCTAssertEqual(result.qualityScore, 0.8, accuracy: 0.0001)
        XCTAssertEqual(result.reliabilityScore, 0.15, accuracy: 0.0001)
        XCTAssertEqual(result.efficiencyScore, 0.55, accuracy: 0.0001)
        XCTAssertEqual(result.threadUtilization.activeThreadCount, 4)
        XCTAssertEqual(result.timeSinceLastUnderrun, 12)
        XCTAssertEqual(result.underrunRate, analytics.underrunRate(), accuracy: 0.0001)
    }

    func testCollectorPreservesUnavailableEngineMetricsState() async {
        let collector = AudioMonitorMetricsCollector(
            systemMetricsCollector: StubSystemMetricsCollector(
                current: SystemMetrics(
                    cpuUsage: 10,
                    memoryUsage: 100,
                    diskIOPS: 0,
                    networkBandwidth: 0,
                    batteryUsageRate: nil
                )
            ),
            thermalStateMonitor: StubThermalMonitor(
                state: ThermalMonitoringInfo(
                    thermalState: .nominal,
                    cpuTemperature: nil,
                    isThrottling: false,
                    recommendedAdjustments: []
                )
            ),
            engineMetricsCollector: StubEngineMetricsCollector(metrics: .default)
        )

        let result = await collector.collectMetrics(
            for: nil,
            analytics: AudioSessionAnalytics(),
            timeSinceLastUnderrun: nil
        )

        XCTAssertEqual(result.engineMetricsAvailability, .unavailable)
        XCTAssertEqual(result.qualityScore, 0)
        XCTAssertEqual(result.reliabilityScore, 0)
    }
}

// MARK: - Test Doubles

@MainActor
private final class StubSystemMetricsCollector: SystemMetricsCollecting {
    private let current: SystemMetrics

    init(current: SystemMetrics) {
        self.current = current
    }

    func startMonitoring() async {}

    func collectCurrentMetrics() async -> SystemMetrics { current }

    func collectSystemMetrics() async -> SystemAudioMetrics {
        let device = AudioDeviceInfo(
            deviceID: "headphones",
            name: "USB DAC",
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            bufferSize: 256,
            latency: 0.01
        )

        return SystemAudioMetrics(
            systemAudioCPU: 35,
            activeAudioSessions: 2,
            systemAudioMemory: 120_000_000,
            deviceInfo: device,
            interruptionCount: 1,
            audioUnitLoad: 0.6
        )
    }
}

@MainActor
private final class StubThermalMonitor: ThermalStateMonitoring {
    private let state: ThermalMonitoringInfo

    init(state: ThermalMonitoringInfo) {
        self.state = state
    }

    func startMonitoring() async {}

    func getCurrentState() async -> ThermalMonitoringInfo { state }
}

@MainActor
private final class StubEngineMetricsCollector: EngineMetricsCollecting {
    private let metrics: EngineMetrics

    init(metrics: EngineMetrics) {
        self.metrics = metrics
    }

    func metrics(for _: AudioEngineService?) async -> EngineMetrics { metrics }
}
