import Foundation

@MainActor
final class AudioMonitorDiagnosticsBuilder {
    struct RuntimeSnapshot {
        let updateInterval: TimeInterval
        let isMonitoring: Bool
        let isProfiling: Bool
    }

    private let insights: AudioMonitorInsights
    private let reporter: AudioMonitorReporter
    private let performanceProfiler: AudioPerformanceProfiler
    private let engineMetricsCollector: any EngineMetricsCollecting

    init(
        insights: AudioMonitorInsights,
        reporter: AudioMonitorReporter,
        performanceProfiler: AudioPerformanceProfiler,
        engineMetricsCollector: any EngineMetricsCollecting
    ) {
        self.insights = insights
        self.reporter = reporter
        self.performanceProfiler = performanceProfiler
        self.engineMetricsCollector = engineMetricsCollector
    }

    func makeDiagnostics(
        currentMetrics: AudioMetrics,
        latestMetric: AudioMetrics?,
        sessionSummary: AudioSessionSummary,
        alertHistory: [PlaybackAlert],
        runtime: RuntimeSnapshot,
        engine: AudioEngineService?,
        metricsSampleCount: Int,
        systemHealth: DiagnosticHealthStatus
    ) async -> PlaybackDiagnostics {
        let engineInfo = await reporter.engineInfo(for: engine, metricsCollector: engineMetricsCollector)
        let sessionInfo = reporter.sessionInfo(isMonitoring: runtime.isMonitoring)
        let deviceInfo = reporter.deviceInfo(latestMetric: latestMetric ?? currentMetrics)

        let performanceTrends = insights.performanceTrends()
        let resourceUtilization = insights.resourceUtilization()
        let qualityAssessment = insights.qualityAssessment()
        let efficiencyAnalysis = insights.efficiencyAnalysis()
        let activeIssues = insights.activeIssues()
        let recommendations = insights.recommendations()
        let optimizations = await insights.optimizationOpportunities(profilingData: performanceProfiler.profilingData)
        let sessionStatistics = insights.sessionStatistics(alertHistory: alertHistory, sessionSummary: sessionSummary)
        let errorHistory = insights.errorHistory(alertHistory: alertHistory)
        let milestones = insights.milestones(alertHistory: alertHistory)
        let osCompatibility = insights.osCompatibilityInfo()
        let hardwareCompatibility = insights.hardwareCompatibilityInfo(latestMetric: latestMetric ?? currentMetrics)
        let formatSupport = insights.formatSupportMatrix()

        let debugInfo = await reporter.debugInformation(
            updateInterval: runtime.updateInterval,
            isMonitoring: runtime.isMonitoring,
            isProfiling: runtime.isProfiling,
            metricsCount: metricsSampleCount,
            engine: engine,
            sessionInfo: sessionInfo,
            deviceInfo: deviceInfo
        )

        let logEntries = reporter.recentLogEntries()
        let configurationDump = reporter.configurationDump(
            updateInterval: runtime.updateInterval,
            isProfiling: runtime.isProfiling,
            metricsCount: metricsSampleCount,
            sessionInfo: sessionInfo,
            deviceInfo: deviceInfo
        )

        return PlaybackDiagnostics(
            sessionDuration: sessionSummary.duration,
            systemHealth: systemHealth,
            currentMetrics: currentMetrics,
            engineInfo: engineInfo,
            sessionInfo: sessionInfo,
            deviceInfo: deviceInfo,
            performanceTrends: performanceTrends,
            resourceUtilization: resourceUtilization,
            qualityAssessment: qualityAssessment,
            efficiencyAnalysis: efficiencyAnalysis,
            activeIssues: activeIssues,
            recentAlerts: Array(alertHistory.suffix(10)),
            recommendations: recommendations,
            optimizations: optimizations,
            sessionStatistics: sessionStatistics,
            errorHistory: errorHistory,
            milestones: milestones,
            osCompatibility: osCompatibility,
            hardwareCompatibility: hardwareCompatibility,
            formatSupport: formatSupport,
            debugInfo: debugInfo,
            logEntries: logEntries,
            configurationDump: configurationDump
        )
    }
}

extension AudioMonitorDiagnosticsBuilder: AudioMonitorDiagnosticsBuilding {}
