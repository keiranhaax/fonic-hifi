@testable import Fonic_HiFi
import XCTest

final class AudioMetricsTests: XCTestCase {
    func testHealthClassification() {
        let healthy = makeMetrics(
            cpuUsage: 45,
            bufferUnderruns: 0,
            droppedFrames: 0,
            bufferFillLevel: 0.8,
            performanceScore: 0.92
        )

        XCTAssertTrue(healthy.isHealthy)
        XCTAssertEqual(healthy.healthStatus, .excellent)

        let warning = makeMetrics(
            cpuUsage: 60,
            bufferUnderruns: 0,
            droppedFrames: 2,
            performanceScore: 0.7
        )

        XCTAssertFalse(warning.isHealthy)
        XCTAssertEqual(warning.healthStatus, .fair)

        let critical = makeMetrics(
            cpuUsage: 95,
            bufferUnderruns: 5,
            droppedFrames: 12,
            performanceScore: 0.3,
            criticalErrors: 2
        )

        XCTAssertFalse(critical.isHealthy)
        XCTAssertEqual(critical.healthStatus, .critical)
    }

    func testFormattedOutputs() {
        let metrics = makeMetrics(
            cpuUsage: 32,
            bufferUnderruns: 0,
            droppedFrames: 0,
            bufferFillLevel: 0.75,
            renderLatency: 0.012,
            memoryUsage: 150 * 1024 * 1024,
            currentBitrate: 320_000,
            sampleRate: 96_000,
            bitDepth: 24,
            audioFormat: "FLAC"
        )

        XCTAssertTrue(metrics.formattedMemoryUsage.contains("MB"))
        XCTAssertEqual(metrics.formattedBitrate, "320.0 kbps")
        XCTAssertEqual(metrics.formatDescription, "FLAC • 96kHz/24-bit")
        XCTAssertTrue(metrics.performanceSummary.contains("CPU"))
        XCTAssertTrue(metrics.performanceSummary.contains("Latency"))
    }

    func testQualityIndicatorsAndEfficiency() {
        let excellent = makeMetrics(
            cpuUsage: 15,
            bufferUnderruns: 0,
            droppedFrames: 0,
            isBitPerfect: true,
            batteryUsageRate: 80
        )

        XCTAssertEqual(excellent.qualityIndicator, "Excellent")
        XCTAssertEqual(excellent.efficiencyRating, "Excellent")
        XCTAssertFalse(excellent.hasCriticalIssues)

        let degraded = makeMetrics(
            cpuUsage: 70,
            bufferUnderruns: 4,
            droppedFrames: 15,
            isBitPerfect: false,
            thermalPressure: 0.85,
            batteryUsageRate: 250,
            criticalErrors: 1
        )

        XCTAssertEqual(degraded.qualityIndicator, "Poor")
        XCTAssertEqual(degraded.efficiencyRating, "Poor")
        XCTAssertTrue(degraded.hasCriticalIssues)
    }

    func testGenerateInsightsCoversCommonAlerts() {
        let metrics = makeMetrics(
            cpuUsage: 85,
            bufferUnderruns: 2,
            droppedFrames: 12,
            bufferFillLevel: 0.3,
            renderLatency: 0.15,
            isBitPerfect: false,
            thermalPressure: 0.7,
            performanceScore: 0.5
        )

        let insights = metrics.generateInsights()

        XCTAssertTrue(insights.contains(where: { $0.contains("Buffer underruns") }))
        XCTAssertTrue(insights.contains(where: { $0.contains("High CPU usage") }))
        XCTAssertTrue(insights.contains(where: { $0.contains("Thermal pressure") }))
        XCTAssertTrue(insights.contains(where: { $0.contains("frames being dropped") }))
        XCTAssertTrue(insights.contains(where: { $0.contains("render latency") }))
        XCTAssertTrue(insights.contains(where: { $0.contains("not bit-perfect eligible") }))
        XCTAssertTrue(insights.contains(where: { $0.contains("Overall performance below optimal") }))
    }

    func testMetricsComparisonReportsExpectedDeltas() {
        let older = makeMetrics(
            cpuUsage: 40,
            bufferUnderruns: 3,
            renderLatency: 0.08,
            memoryUsage: 500_000,
            performanceScore: 0.6,
            qualityScore: 0.7,
            timestamp: Date(timeIntervalSince1970: 1_000)
        )

        let newer = makeMetrics(
            cpuUsage: 35,
            bufferUnderruns: 1,
            renderLatency: 0.05,
            memoryUsage: 400_000,
            performanceScore: 0.75,
            qualityScore: 0.8,
            timestamp: Date(timeIntervalSince1970: 1_010)
        )

        let comparison = newer.compare(with: older)

        XCTAssertLessThan(comparison.cpuUsageDelta, 0)
        XCTAssertLessThan(comparison.memoryUsageDelta, 0)
        XCTAssertLessThan(comparison.latencyDelta, 0)
        XCTAssertLessThan(comparison.bufferUnderrunsDelta, 0)
        XCTAssertGreaterThan(comparison.performanceScoreDelta, 0)
        XCTAssertTrue(comparison.hasImproved)
        XCTAssertFalse(comparison.hasDegraded)
        XCTAssertEqual(comparison.timeInterval, 10, accuracy: 0.1)
    }

    func testThreadUtilizationTotalCPUUsage() {
        let threads = ThreadUtilization(
            audioThreadCPU: 10,
            decoderThreadCPU: 15,
            ioThreadCPU: 5,
            mainThreadCPU: 20,
            activeThreadCount: 4,
            threadPriorities: ["audio": 0.9]
        )

        XCTAssertEqual(threads.totalCPUUsage, 50)
    }

    // MARK: - Helpers

    private func makeMetrics(
        cpuUsage: Float,
        bufferUnderruns: Int = 0,
        droppedFrames: Int = 0,
        bufferFillLevel: Float = 0.75,
        renderLatency: TimeInterval = 0.02,
        memoryUsage: Int64 = 256 * 1024 * 1024,
        currentBitrate: Int64 = 0,
        sampleRate: Double = 96_000,
        bitDepth: Int = 24,
        audioFormat: String = "FLAC",
        isBitPerfect: Bool = false,
        thermalPressure: Float = 0.2,
        batteryUsageRate: Float? = nil,
        performanceScore: Float = 0.85,
        qualityScore: Float = 0.9,
        reliabilityScore: Float = 0.95,
        efficiencyScore: Float = 0.9,
        criticalErrors: Int = 0,
        timestamp: Date = Date()
    ) -> AudioMetrics {
        AudioMetrics(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
            bufferUnderruns: bufferUnderruns,
            decodingLatency: 0.01,
            bufferFillLevel: bufferFillLevel,
            droppedFrames: droppedFrames,
            renderLatency: renderLatency,
            timestamp: timestamp,
            currentBitrate: currentBitrate,
            averageLatency: 0.01,
            peakLatency: 0.02,
            glitchCount: 0,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channelCount: 2,
            engineType: "AudioKit",
            audioFormat: audioFormat,
            isBitPerfect: isBitPerfect,
            bufferSize: 512,
            bufferResets: 0,
            averageBufferFill: 0.8,
            underrunRate: 0,
            timeSinceLastUnderrun: nil,
            diskIOPS: 10,
            networkBandwidth: 0,
            thermalPressure: thermalPressure,
            batteryUsageRate: batteryUsageRate,
            threadUtilization: ThreadUtilization(),
            estimatedSNR: 90,
            dynamicRange: 100,
            frequencyResponseScore: 95,
            jitter: 0.5,
            clockDrift: 0.1,
            recoverableErrors: 0,
            criticalErrors: criticalErrors,
            recoverySuccessRate: 1.0,
            lastRecoveryTime: nil,
            performanceScore: performanceScore,
            qualityScore: qualityScore,
            reliabilityScore: reliabilityScore,
            efficiencyScore: efficiencyScore
        )
    }
}
