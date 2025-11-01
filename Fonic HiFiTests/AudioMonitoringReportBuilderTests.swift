@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioMonitoringReportBuilderTests: XCTestCase {
    func testSummaryReportsCounts() {
        let builder = AudioMonitoringReportBuilder()

        let metrics = [AudioMetrics(cpuUsage: 10, memoryUsage: 1_000, bufferUnderruns: 0, decodingLatency: 0.01, bufferFillLevel: 0.9, droppedFrames: 0, renderLatency: 0.01)]
        let alerts = [PlaybackAlert(type: .highCPUUsage, severity: .high, message: "", technicalDetails: "")]

        let summary = builder.summary(metrics: metrics, alerts: alerts)

        XCTAssertTrue(summary.contains("1 samples"))
        XCTAssertTrue(summary.contains("1 alerts"))
    }

    func testKeyFindingsIncludeHighCpuMessage() {
        let builder = AudioMonitoringReportBuilder()

        let metrics = (0..<3).map { index in
            AudioMetrics(
                cpuUsage: Float(60 + index * 5),
                memoryUsage: 10_000,
                bufferUnderruns: 0,
                decodingLatency: 0.01,
                bufferFillLevel: 0.8,
                droppedFrames: 0,
                renderLatency: 0.01
            )
        }

        let findings = builder.keyFindings(metrics: metrics, alerts: [])

        XCTAssertTrue(findings.contains { $0.contains("Average CPU usage") })
    }

    func testPerformanceTrendsComputesTrendIndicators() {
        let builder = AudioMonitoringReportBuilder()

        var metrics: [AudioMetrics] = []
        for index in 0..<5 {
            let cpuUsage = Float(30 + index)
            let memoryUsage = Int64(100_000 + index * 10_000)
            let bufferFillLevel = 0.9 - Float(index) * 0.05
            let renderLatency = 0.02 + Double(index) * 0.001
            metrics.append(
                AudioMetrics(
                    cpuUsage: cpuUsage,
                    memoryUsage: memoryUsage,
                    bufferUnderruns: 0,
                    decodingLatency: 0.01,
                    bufferFillLevel: bufferFillLevel,
                    droppedFrames: 0,
                    renderLatency: renderLatency
                )
            )
        }

        let trends = builder.performanceTrends(for: metrics)

        XCTAssertFalse(trends.isEmpty)
        XCTAssertTrue(trends.contains { $0.metric == "CPU Usage" })
    }
}
