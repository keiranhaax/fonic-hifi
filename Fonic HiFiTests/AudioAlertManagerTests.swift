@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioAlertManagerTests: XCTestCase {
    func testDefaultMemoryThresholdMatchesPerformanceTarget() {
        XCTAssertEqual(AlertConfiguration.default.memoryThreshold, PerformanceThresholds.targetMemoryUsage)
    }

    func testHighCPUUsageGeneratesCriticalAlert() {
        let manager = AudioAlertManager(configuration: AlertConfiguration(
            cpuThreshold: 80,
            memoryThreshold: 200_000_000,
            bufferFillThreshold: 0.2,
            maxBufferUnderruns: 1,
            latencyThreshold: 0.05,
            enableThermalMonitoring: true,
            alertCooldownSeconds: 60,
        ))

        let metrics = makeMetrics(cpu: 95)
        let alerts = manager.evaluateAlerts(for: metrics)

        XCTAssertEqual(alerts.count, 1)
        XCTAssertEqual(alerts.first?.type, .highCPUUsage)
        XCTAssertEqual(alerts.first?.severity, .critical)
        XCTAssertEqual(manager.alertHistory.count, 1)
    }

    func testAlertCooldownPreventsDuplicateInterrupts() {
        let manager = AudioAlertManager(configuration: AlertConfiguration(
            cpuThreshold: 50,
            memoryThreshold: 100_000_000,
            bufferFillThreshold: 0.4,
            maxBufferUnderruns: 0,
            latencyThreshold: 0.02,
            enableThermalMonitoring: true,
            alertCooldownSeconds: 5,
        ))

        let metrics = makeMetrics(cpu: 70)

        let first = manager.evaluateAlerts(for: metrics)
        let second = manager.evaluateAlerts(for: metrics)

        XCTAssertEqual(first.count, 1)
        XCTAssertTrue(second.isEmpty)
        XCTAssertEqual(manager.alertHistory.count, 1)
    }

    func testResetClearsAlertHistory() {
        let manager = AudioAlertManager(configuration: .default)
        let metrics = makeMetrics(cpu: 90, bufferFill: 0.1, underruns: 3, latency: 0.1)

        _ = manager.evaluateAlerts(for: metrics)

        let interruption = PlaybackAlert(
            type: .audioInterruption,
            severity: .medium,
            message: "Playback interrupted",
            technicalDetails: "Test interruption",
        )
        manager.recordInterruptionAlert(interruption)

        XCTAssertGreaterThanOrEqual(manager.alertHistory.count, 2)

        manager.reset()

        XCTAssertTrue(manager.alertHistory.isEmpty)
    }
}

private extension AudioAlertManagerTests {
    func makeMetrics(
        cpu: Float = 10,
        memory: Int64 = 20_000_000,
        bufferFill: Float = 0.8,
        underruns: Int = 0,
        latency: TimeInterval = 0.01,
    ) -> AudioMetrics {
        AudioMetrics(
            cpuUsage: cpu,
            memoryUsage: memory,
            bufferUnderruns: underruns,
            decodingLatency: 0.005,
            bufferFillLevel: bufferFill,
            droppedFrames: 0,
            renderLatency: latency,
            currentBitrate: 320_000,
            averageLatency: latency,
            peakLatency: latency * 1.5,
            glitchCount: 0,
            sampleRate: 44100,
            bitDepth: 16,
            channelCount: 2,
            engineType: "TestEngine",
            audioFormat: "flac",
            isBitPerfect: true,
            bufferSize: 512,
            bufferResets: 0,
            averageBufferFill: bufferFill,
            underrunRate: 0,
            timeSinceLastUnderrun: nil,
            diskIOPS: 0,
            networkBandwidth: 0,
            thermalPressure: 0.2,
            batteryUsageRate: 120,
            threadUtilization: ThreadUtilization(audioThreadCPU: cpu / 2, decoderThreadCPU: cpu / 4, ioThreadCPU: 2, mainThreadCPU: 1, activeThreadCount: 3),
            estimatedSNR: 90,
            dynamicRange: 100,
            frequencyResponseScore: 0.8,
            jitter: 0.0005,
            clockDrift: 0.0001,
            recoverableErrors: 0,
            criticalErrors: 0,
            recoverySuccessRate: 1,
            lastRecoveryTime: nil,
            performanceScore: 0.85,
            qualityScore: 0.9,
            reliabilityScore: 0.95,
            efficiencyScore: 0.8,
        )
    }
}
