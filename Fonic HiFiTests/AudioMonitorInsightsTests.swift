@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioMonitorInsightsTests: XCTestCase {
    func testPerformanceTrendsDetectDegradingPattern() {
        let environment = makeInsightsEnvironment()
        let metrics: [AudioMetrics] = [
            AudioMetrics(
                cpuUsage: 40,
                memoryUsage: 400_000_000,
                bufferUnderruns: 0,
                decodingLatency: 0.02,
                bufferFillLevel: 0.82,
                droppedFrames: 0,
                renderLatency: 0.03,
                performanceScore: 0.9,
                qualityScore: 0.88,
                efficiencyScore: 0.82
            ),
            AudioMetrics(
                cpuUsage: 42,
                memoryUsage: 408_000_000,
                bufferUnderruns: 0,
                decodingLatency: 0.023,
                bufferFillLevel: 0.8,
                droppedFrames: 0,
                renderLatency: 0.033,
                performanceScore: 0.86,
                qualityScore: 0.84,
                efficiencyScore: 0.78
            ),
            AudioMetrics(
                cpuUsage: 44,
                memoryUsage: 416_000_000,
                bufferUnderruns: 1,
                decodingLatency: 0.026,
                bufferFillLevel: 0.78,
                droppedFrames: 1,
                renderLatency: 0.036,
                performanceScore: 0.82,
                qualityScore: 0.8,
                efficiencyScore: 0.74
            ),
            AudioMetrics(
                cpuUsage: 46,
                memoryUsage: 424_000_000,
                bufferUnderruns: 1,
                decodingLatency: 0.029,
                bufferFillLevel: 0.76,
                droppedFrames: 1,
                renderLatency: 0.039,
                performanceScore: 0.78,
                qualityScore: 0.76,
                efficiencyScore: 0.7
            ),
            AudioMetrics(
                cpuUsage: 48,
                memoryUsage: 432_000_000,
                bufferUnderruns: 2,
                decodingLatency: 0.032,
                bufferFillLevel: 0.74,
                droppedFrames: 2,
                renderLatency: 0.042,
                performanceScore: 0.74,
                qualityScore: 0.72,
                efficiencyScore: 0.66
            )
        ]

        metrics.forEach { environment.analytics.append($0) }

        let summary = environment.insights.performanceTrends()

        XCTAssertEqual(summary.overallTrend, .degrading)
        XCTAssertEqual(summary.cpuTrend.direction, .degrading)
        XCTAssertEqual(summary.bufferTrend.direction, .degrading)
    }

    func testQualityAssessmentHighlightsIssues() {
        let environment = makeInsightsEnvironment()
        let metrics: [AudioMetrics] = [
            AudioMetrics(
                cpuUsage: 60,
                memoryUsage: 460_000_000,
                bufferUnderruns: 0,
                decodingLatency: 0.03,
                bufferFillLevel: 0.7,
                droppedFrames: 0,
                renderLatency: 0.04,
                sampleRate: 192_000,
                bitDepth: 24,
                channelCount: 2,
                engineType: "TestEngine",
                audioFormat: "FLAC",
                isBitPerfect: true,
                estimatedSNR: 85,
                dynamicRange: 92,
                performanceScore: 0.8,
                qualityScore: 0.8,
                efficiencyScore: 0.74
            ),
            AudioMetrics(
                cpuUsage: 68,
                memoryUsage: 480_000_000,
                bufferUnderruns: 1,
                decodingLatency: 0.045,
                bufferFillLevel: 0.48,
                droppedFrames: 1,
                renderLatency: 0.055,
                currentBitrate: 2_500_000,
                averageLatency: 0.05,
                peakLatency: 0.08,
                glitchCount: 1,
                sampleRate: 192_000,
                bitDepth: 24,
                channelCount: 2,
                engineType: "TestEngine",
                audioFormat: "FLAC",
                isBitPerfect: false,
                estimatedSNR: 60,
                dynamicRange: 60,
                jitter: 0.006,
                performanceScore: 0.6,
                qualityScore: 0.55,
                efficiencyScore: 0.6
            )
        ]

        metrics.forEach { environment.analytics.append($0) }

        let assessment = environment.insights.qualityAssessment()

        XCTAssertLessThan(assessment.qualityScore, 70)
        XCTAssertTrue(assessment.qualityIssues.contains { $0.type == .device || $0.type == .processing })
        XCTAssertTrue(assessment.improvements.contains { $0.title.contains("Bit-Perfect") })
        XCTAssertTrue(assessment.signalIntegrity.issues.contains(.noise))
        XCTAssertEqual(assessment.bitPerfectStatus, .available)
    }

    func testActiveIssuesCombineAlertsAndAnalyticsSignals() {
        let alertBox = AlertHistoryBox()
        let environment = makeInsightsEnvironment(alertHistoryBox: alertBox)

        let metric = AudioMetrics(
            cpuUsage: 90,
            memoryUsage: 800_000_000,
            bufferUnderruns: 0,
            decodingLatency: 0.02,
            bufferFillLevel: 0.2,
            droppedFrames: 0,
            renderLatency: 0.03,
            performanceScore: 0.5,
            qualityScore: 0.8,
            efficiencyScore: 0.5
        )
        environment.analytics.append(metric)

        alertBox.alerts = [
            PlaybackAlert(
                type: .lowBufferFill,
                severity: .medium,
                message: "Buffer below threshold",
                technicalDetails: "Fill 20%",
                triggerValues: ["bufferFill": 0.2],
                suggestedActions: ["Increase buffer"]
            )
        ]

        let issues = environment.insights.activeIssues()

        XCTAssertTrue(issues.contains { $0.title == AlertType.lowBufferFill.displayName })
        XCTAssertTrue(issues.contains { $0.title.contains("Sustained high CPU") })
    }

    func testRecommendationsReflectAdvisorOutput() {
        let environment = makeInsightsEnvironment()
        environment.analytics.append(
            AudioMetrics(
                cpuUsage: 85,
                memoryUsage: 700_000_000,
                bufferUnderruns: 1,
                decodingLatency: 0.02,
                bufferFillLevel: 0.3,
                droppedFrames: 0,
                renderLatency: 0.02,
                estimatedSNR: 75,
                jitter: 0.006,
                performanceScore: 0.65,
                qualityScore: 0.7,
                efficiencyScore: 0.6
            )
        )

        let recommendations = environment.insights.recommendations()

        XCTAssertTrue(recommendations.contains { $0.type == .performanceModeAdjustment })
    }

    func testResourceUtilizationClassifiesHighUsage() {
        let environment = makeInsightsEnvironment()
        let metrics: [AudioMetrics] = [
            AudioMetrics(
                cpuUsage: 72,
                memoryUsage: 620_000_000,
                bufferUnderruns: 0,
                decodingLatency: 0.025,
                bufferFillLevel: 0.75,
                droppedFrames: 0,
                renderLatency: 0.032,
                currentBitrate: 2_000_000,
                averageLatency: 0.03,
                peakLatency: 0.05,
                glitchCount: 0,
                sampleRate: 192_000,
                bitDepth: 24,
                channelCount: 2,
                engineType: "TestEngine",
                audioFormat: "FLAC",
                isBitPerfect: true,
                bufferSize: 512,
                bufferResets: 0,
                averageBufferFill: 0.78,
                underrunRate: 0,
                diskIOPS: 120,
                networkBandwidth: 12_000_000,
                thermalPressure: 0.3,
                batteryUsageRate: 150,
                threadUtilization: ThreadUtilization(audioThreadCPU: 18, decoderThreadCPU: 14, ioThreadCPU: 10, mainThreadCPU: 6, activeThreadCount: 4),
                estimatedSNR: 85,
                dynamicRange: 80,
                jitter: 0.003,
                clockDrift: 0.001,
                recoverableErrors: 0,
                criticalErrors: 0,
                recoverySuccessRate: 0.98,
                performanceScore: 0.75,
                qualityScore: 0.82,
                reliabilityScore: 0.9,
                efficiencyScore: 0.7
            ),
            AudioMetrics(
                cpuUsage: 88,
                memoryUsage: 920_000_000,
                bufferUnderruns: 1,
                decodingLatency: 0.03,
                bufferFillLevel: 0.62,
                droppedFrames: 1,
                renderLatency: 0.048,
                currentBitrate: 2_500_000,
                averageLatency: 0.04,
                peakLatency: 0.08,
                glitchCount: 1,
                sampleRate: 192_000,
                bitDepth: 24,
                channelCount: 2,
                engineType: "TestEngine",
                audioFormat: "FLAC",
                isBitPerfect: false,
                bufferSize: 512,
                bufferResets: 0,
                averageBufferFill: 0.66,
                underrunRate: 1.2,
                diskIOPS: 160,
                networkBandwidth: 18_000_000,
                thermalPressure: 0.6,
                batteryUsageRate: 260,
                threadUtilization: ThreadUtilization(audioThreadCPU: 24, decoderThreadCPU: 18, ioThreadCPU: 12, mainThreadCPU: 8, activeThreadCount: 4),
                estimatedSNR: 68,
                dynamicRange: 58,
                jitter: 0.006,
                clockDrift: 0.002,
                recoverableErrors: 2,
                criticalErrors: 0,
                recoverySuccessRate: 0.9,
                performanceScore: 0.6,
                qualityScore: 0.6,
                reliabilityScore: 0.7,
                efficiencyScore: 0.5
            )
        ]

        metrics.forEach { environment.analytics.append($0) }

        let summary = environment.insights.resourceUtilization()

        XCTAssertEqual(summary.cpuUtilization.classification, .excessive)
        XCTAssertEqual(summary.memoryUtilization.classification, .excessive)
        XCTAssertEqual(summary.batteryUtilization.classification, .high)
        XCTAssertEqual(summary.networkUtilization.classification, .excessive)
        XCTAssertEqual(summary.overallEfficiency, .fair)
    }

    func testErrorHistorySummarizesAlerts() {
        let alertBox = AlertHistoryBox()
        let environment = makeInsightsEnvironment(alertHistoryBox: alertBox)

        environment.analytics.append(
            AudioMetrics(
                cpuUsage: 60,
                memoryUsage: 400_000_000,
                bufferUnderruns: 0,
                decodingLatency: 0.02,
                bufferFillLevel: 0.7,
                droppedFrames: 0,
                renderLatency: 0.03,
                recoverySuccessRate: 0.95,
                performanceScore: 0.8,
                qualityScore: 0.85,
                efficiencyScore: 0.78
            )
        )

        alertBox.alerts = [
            PlaybackAlert(
                type: .bufferUnderrun,
                severity: .medium,
                message: "Buffer underrun detected",
                technicalDetails: "",
                timestamp: Date().addingTimeInterval(-4000),
                suggestedActions: ["retry"]
            ),
            PlaybackAlert(
                type: .audioDropout,
                severity: .high,
                message: "Audio dropout",
                technicalDetails: "",
                triggerValues: ["latency": 0.08]
            )
        ]

        let summary = environment.insights.errorHistory(alertHistory: alertBox.alerts)

        XCTAssertEqual(summary.totalErrors, 2)
        XCTAssertEqual(summary.errorsByCategory[.buffer], 1)
        XCTAssertEqual(summary.errorsByCategory[.network], 1)
        XCTAssertEqual(summary.mostRecentError?.category, .network)
        XCTAssertTrue(summary.mostRecentError?.recoverySuccessful ?? false)
        XCTAssertEqual(summary.errorFrequencyTrend, .stable)
    }

    func testMilestonesIncludeKeyAchievements() {
        let alertBox = AlertHistoryBox()
        alertBox.alerts = [
            PlaybackAlert(
                type: .bufferUnderrun,
                severity: .medium,
                message: "Earlier underrun",
                technicalDetails: "",
                timestamp: Date().addingTimeInterval(-4000)
            )
        ]

        let environment = makeInsightsEnvironment(alertHistoryBox: alertBox)
        let start = Date().addingTimeInterval(-5400)
        environment.analytics.startNewSession(at: start)

        let metrics = [
            AudioMetrics(
                cpuUsage: 40,
                memoryUsage: 300_000_000,
                bufferUnderruns: 0,
                decodingLatency: 0.02,
                bufferFillLevel: 0.9,
                droppedFrames: 0,
                renderLatency: 0.02,
                performanceScore: 0.95,
                qualityScore: 0.98,
                efficiencyScore: 0.94
            ),
            AudioMetrics(
                cpuUsage: 42,
                memoryUsage: 320_000_000,
                bufferUnderruns: 0,
                decodingLatency: 0.018,
                bufferFillLevel: 0.92,
                droppedFrames: 0,
                renderLatency: 0.018,
                performanceScore: 0.96,
                qualityScore: 0.97,
                efficiencyScore: 0.93
            )
        ]

        metrics.forEach { environment.analytics.append($0) }

        let milestones = environment.insights.milestones(alertHistory: alertBox.alerts)

        XCTAssertTrue(milestones.contains { $0.type == .uptime })
        XCTAssertTrue(milestones.contains { $0.type == .quality })
        XCTAssertTrue(milestones.contains { $0.type == .efficiency })
        XCTAssertTrue(milestones.contains { $0.type == .stability })
    }

    func testOptimizationOpportunitiesIncludeThermalState() async {
        let thermalInfo = ThermalMonitoringInfo(
            thermalState: .serious,
            cpuTemperature: 44,
            isThrottling: true,
            recommendedAdjustments: []
        )
        let environment = makeInsightsEnvironment(thermalInfo: thermalInfo)

        let profiler = AudioPerformanceProfiler()
        profiler.beginProfiling(duration: nil)

        let samples = [
            AudioMetrics(
                cpuUsage: 88,
                memoryUsage: 850_000_000,
                bufferUnderruns: 2,
                decodingLatency: 0.04,
                bufferFillLevel: 0.3,
                droppedFrames: 1,
                renderLatency: 0.06,
                performanceScore: 0.6,
                qualityScore: 0.65,
                efficiencyScore: 0.55
            ),
            AudioMetrics(
                cpuUsage: 82,
                memoryUsage: 780_000_000,
                bufferUnderruns: 1,
                decodingLatency: 0.038,
                bufferFillLevel: 0.35,
                droppedFrames: 1,
                renderLatency: 0.055,
                performanceScore: 0.62,
                qualityScore: 0.68,
                efficiencyScore: 0.57
            )
        ]

        for sample in samples {
            profiler.collectSample(from: sample)
        }

        profiler.finalize()
        guard let profilingData = profiler.profilingData else {
            XCTFail("Expected profiling data")
            return
        }

        let opportunities = await environment.insights.optimizationOpportunities(profilingData: profilingData)

        XCTAssertTrue(opportunities.contains { $0.description.contains("thermal conditions") })
        XCTAssertTrue(opportunities.contains { $0.type == .resourceManagement })
    }
}

// MARK: - Helpers

@MainActor
private func makeInsightsEnvironment(
    alertHistoryBox: AlertHistoryBox = AlertHistoryBox(),
    thermalInfo: ThermalMonitoringInfo = ThermalMonitoringInfo(
        thermalState: .fair,
        cpuTemperature: 37,
        isThrottling: false,
        recommendedAdjustments: []
    )
) -> InsightsEnvironment {
    let analytics = AudioSessionAnalytics()
    analytics.startNewSession(at: Date().addingTimeInterval(-300))

    let reportBuilder = AudioMonitoringReportBuilder()
    let advisor = AudioPerformanceAdvisor()
    let profiler = AudioPerformanceProfiler()
    let thermalMonitor = StubThermalMonitor(state: thermalInfo)

    let insights = AudioMonitorInsights(
        analytics: analytics,
        reportBuilder: reportBuilder,
        performanceAdvisor: advisor,
        performanceProfiler: profiler,
        thermalStateMonitor: thermalMonitor,
        alertHistoryProvider: { alertHistoryBox.alerts }
    )

    return InsightsEnvironment(analytics: analytics, insights: insights, alertHistory: alertHistoryBox)
}

// MARK: - Supporting Types

@MainActor
private final class AlertHistoryBox {
    var alerts: [PlaybackAlert] = []
}

@MainActor
private struct InsightsEnvironment {
    let analytics: AudioSessionAnalytics
    let insights: AudioMonitorInsights
    let alertHistory: AlertHistoryBox
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
