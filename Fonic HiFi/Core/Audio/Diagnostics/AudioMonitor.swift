//
//  AudioMonitor.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import AVFoundation
import Combine
import Foundation
import OSLog
#if canImport(UIKit)
    import UIKit
#endif

/// Comprehensive audio monitoring implementation with periodic polling and real-time metrics
@MainActor
public final class AudioMonitor: ObservableObject, AudioHealthMonitoring, AudioPerformanceMonitoring, AudioDiagnosticsReporting, AudioSessionMonitoring {
    // MARK: - Publishers

    private let _metricsSubject = PassthroughSubject<AudioMetrics, Never>()
    private let _healthStatusSubject = PassthroughSubject<PlaybackHealthStatus, Never>()
    private let _alertsSubject = PassthroughSubject<PlaybackAlert, Never>()

    public var metricsPublisher: AnyPublisher<AudioMetrics, Never> {
        _metricsSubject.eraseToAnyPublisher()
    }

    public var healthStatusPublisher: AnyPublisher<PlaybackHealthStatus, Never> {
        _healthStatusSubject.eraseToAnyPublisher()
    }

    public var alertsPublisher: AnyPublisher<PlaybackAlert, Never> {
        _alertsSubject.eraseToAnyPublisher()
    }

    // MARK: - Private Properties

    private var interruptionObservationTokens = Set<NotificationCenter.ObservationToken>()
    private var _currentEngine: AudioEngineService?
    private let alertManager: any AudioAlertManaging
    private let performanceProfiler: AudioPerformanceProfiler
    private let runtime: any AudioMonitorRuntimeControlling

    // MARK: - Data Storage

    private let analytics = AudioSessionAnalytics()
    private let reportBuilder = AudioMonitoringReportBuilder()
    private let performanceAdvisor = AudioPerformanceAdvisor()
    private let metricsCollector: AudioMonitorMetricsCollector
    private let insights: AudioMonitorInsights
    private let reporter: AudioMonitorReporter
    private let engineHooks: any AudioMonitorEngineHooking
    private let diagnosticsBuilder: any AudioMonitorDiagnosticsBuilding

    private var alertHistory: [PlaybackAlert] {
        alertManager.alertHistory
    }

    // MARK: - Performance Tracking

    private let systemMetricsCollector: any SystemMetricsCollecting
    private let thermalStateMonitor: any ThermalStateMonitoring
    private let interruptionStatsTracker: any InterruptionStatsTracking
    private let engineMetricsCollector: any EngineMetricsCollecting

    // MARK: - Logging

    private let logger = Log.logger(.diagnosticsMonitor)

    // MARK: - Initialization

    public convenience init(
        performanceMonitor: PerformanceMonitor? = nil,
        performanceProfiler: AudioPerformanceProfiler? = nil,
        systemMetricsCollector: (any SystemMetricsCollecting)? = nil,
        thermalStateMonitor: (any ThermalStateMonitoring)? = nil,
        interruptionStatsTracker: (any InterruptionStatsTracking)? = nil,
        engineMetricsCollector: (any EngineMetricsCollecting)? = nil,
        alertManager: (any AudioAlertManaging)? = nil
    ) {
        self.init(
            performanceMonitor: performanceMonitor,
            performanceProfiler: performanceProfiler,
            systemMetricsCollector: systemMetricsCollector,
            thermalStateMonitor: thermalStateMonitor,
            interruptionStatsTracker: interruptionStatsTracker,
            engineMetricsCollector: engineMetricsCollector,
            alertManager: alertManager,
            runtimeController: nil,
            engineHookController: nil,
            diagnosticsBuilderOverride: nil
        )
    }

    init(
        performanceMonitor: PerformanceMonitor? = nil,
        performanceProfiler: AudioPerformanceProfiler? = nil,
        systemMetricsCollector: (any SystemMetricsCollecting)? = nil,
        thermalStateMonitor: (any ThermalStateMonitoring)? = nil,
        interruptionStatsTracker: (any InterruptionStatsTracking)? = nil,
        engineMetricsCollector: (any EngineMetricsCollecting)? = nil,
        alertManager: (any AudioAlertManaging)? = nil,
        runtimeController: (any AudioMonitorRuntimeControlling)? = nil,
        engineHookController: (any AudioMonitorEngineHooking)? = nil,
        diagnosticsBuilderOverride: (any AudioMonitorDiagnosticsBuilding)? = nil
    ) {
        self.systemMetricsCollector = systemMetricsCollector ?? SystemMetricsCollector()
        self.thermalStateMonitor = thermalStateMonitor ?? ThermalStateMonitor()
        self.interruptionStatsTracker = interruptionStatsTracker ?? InterruptionStatsTracker()
        self.engineMetricsCollector = engineMetricsCollector ?? EngineMetricsCollector()
        let performanceMonitorInstance = performanceMonitor ?? PerformanceMonitor()
        self.performanceProfiler = performanceProfiler ?? AudioPerformanceProfiler()
        self.alertManager = alertManager ?? AudioAlertManager()

        self.metricsCollector = AudioMonitorMetricsCollector(
            systemMetricsCollector: self.systemMetricsCollector,
            thermalStateMonitor: self.thermalStateMonitor,
            engineMetricsCollector: self.engineMetricsCollector
        )

        let alertManagerInstance = self.alertManager
        self.insights = AudioMonitorInsights(
            analytics: analytics,
            reportBuilder: reportBuilder,
            performanceAdvisor: performanceAdvisor,
            performanceProfiler: self.performanceProfiler,
            thermalStateMonitor: self.thermalStateMonitor,
            alertHistoryProvider: {
                MainActor.assumeIsolated { alertManagerInstance.alertHistory }
            }
        )

        self.reporter = AudioMonitorReporter(
            analytics: analytics,
            thermalStateMonitor: self.thermalStateMonitor,
            alertHistoryProvider: {
                MainActor.assumeIsolated { alertManagerInstance.alertHistory }
            }
        )

        let metricsSubject = _metricsSubject
        let healthStatusSubject = _healthStatusSubject
        let alertsSubject = _alertsSubject

        let runtimeInstance: any AudioMonitorRuntimeControlling
        if let runtimeController {
            runtimeInstance = runtimeController
        } else {
            let scheduler = AudioMetricsScheduler()
            runtimeInstance = AudioMonitorRuntime(
                scheduler: scheduler,
                analytics: analytics,
                metricsCollector: metricsCollector,
                alertManager: self.alertManager,
                performanceMonitor: performanceMonitorInstance,
                performanceProfiler: self.performanceProfiler,
                logger: logger,
                publishMetrics: { metricsSubject.send($0) },
                publishHealthStatus: { healthStatusSubject.send($0) },
                publishAlert: { alertsSubject.send($0) }
            )
        }
        self.runtime = runtimeInstance

        let engineHooksInstance = engineHookController ?? AudioMonitorEngineHooks(logger: logger)
        self.engineHooks = engineHooksInstance

        let diagnosticsBuilderInstance: any AudioMonitorDiagnosticsBuilding
        if let diagnosticsBuilderOverride {
            diagnosticsBuilderInstance = diagnosticsBuilderOverride
        } else {
            diagnosticsBuilderInstance = AudioMonitorDiagnosticsBuilder(
                insights: self.insights,
                reporter: self.reporter,
                performanceProfiler: self.performanceProfiler,
                engineMetricsCollector: self.engineMetricsCollector
            )
        }
        self.diagnosticsBuilder = diagnosticsBuilderInstance

        setupMonitoring()
        setupInterruptionHandling()
    }

    deinit {
        MainActor.assumeIsolated {
            for token in interruptionObservationTokens {
                NotificationCenter.default.removeObserver(token)
            }
            runtime.invalidate()
        }
    }

    // MARK: - Monitoring Control

    public func startMonitoring(updateInterval: TimeInterval = 1.0) async {
        await runtime.startMonitoring(updateInterval: updateInterval, engine: _currentEngine)
        engineHooks.startMonitoring(interval: updateInterval)
    }

    public func stopMonitoring() async {
        await runtime.stopMonitoring()
        engineHooks.stopMonitoring()
    }

    public var isMonitoring: Bool {
        get async { runtime.isMonitoring }
    }

    public func updateMonitoringInterval(_ interval: TimeInterval) async {
        runtime.updateMonitoringInterval(to: interval)
        engineHooks.updateMonitoringInterval(to: interval)
    }

    // MARK: - Metrics Retrieval

    public func getCurrentMetrics() async -> AudioMetrics {
        await runtime.collectCurrentMetrics()
    }

    public func getHistoricalMetrics(from startTime: Date, to endTime: Date) async -> [AudioMetrics] {
        analytics.historySnapshot.filter { metrics in
            metrics.timestamp >= startTime && metrics.timestamp <= endTime
        }
    }

    public func getSessionSummary() async -> AudioSessionSummary {
        analytics.sessionSummary(alertHistory: alertHistory)
    }

    public func clearHistory() async {
        logger.info("Clearing metrics history")
        analytics.reset()
        alertManager.reset()
    }

    // MARK: - Engine Integration

    public func attachToEngine(_ engine: AudioEngineService) async {
        logger.info("Attaching to audio engine: \(type(of: engine), privacy: .public)")
        _currentEngine = engine
        runtime.updateEngine(engine)
        engineHooks.setEngine(engine)
    }

    public func detachFromEngine() async {
        logger.info("Detaching from current audio engine")
        engineHooks.setEngine(nil)
        _currentEngine = nil
        runtime.updateEngine(nil)
    }

    public var currentEngine: AudioEngineService? {
        get async { _currentEngine }
    }

    // MARK: - Diagnostics & Health

    public func performDiagnosticsCheck() async -> PlaybackDiagnostics {
        logger.info("Performing comprehensive diagnostics check")

        let currentMetrics = await runtime.collectCurrentMetrics()
        let sessionSummary = await getSessionSummary()
        let snapshot = AudioMonitorDiagnosticsBuilder.RuntimeSnapshot(
            updateInterval: runtime.updateInterval,
            isMonitoring: runtime.isMonitoring,
            isProfiling: runtime.isProfiling
        )

        return await diagnosticsBuilder.makeDiagnostics(
            currentMetrics: currentMetrics,
            latestMetric: analytics.latestMetric,
            sessionSummary: sessionSummary,
            alertHistory: alertHistory,
            runtime: snapshot,
            engine: _currentEngine,
            metricsSampleCount: analytics.metricsCount,
            systemHealth: mapHealthStatus(currentMetrics.healthStatus)
        )
    }

    public func checkPlaybackHealth() async -> PlaybackHealthStatus {
        let metrics = await runtime.collectCurrentMetrics()
        return metrics.healthStatus
    }

    public func getPerformanceRecommendations() async -> [PerformanceRecommendation] {
        insights.recommendations()
    }

    // MARK: - Alerting & Thresholds

    public func configureAlerts(_ configuration: AlertConfiguration) async {
        logger.info("Configuring alert thresholds")
        alertManager.updateConfiguration(configuration)
    }

    public func getAlertConfiguration() async -> AlertConfiguration {
        alertManager.alertConfiguration
    }

    public func evaluateAlerts() async {
        await runtime.evaluateAlerts()
    }

    // MARK: - System Resource Monitoring

    public func getSystemAudioMetrics() async -> SystemAudioMetrics {
        async let metricsTask = systemMetricsCollector.collectSystemMetrics()
        async let interruptionStatsTask = interruptionStatsTracker.getStatistics()

        let systemMetrics = await metricsTask
        let interruptionStats = await interruptionStatsTask

        return systemMetrics.updatingInterruptionCount(interruptionStats.totalInterruptions)
    }

    public func getThermalState() async -> ThermalMonitoringInfo {
        await thermalStateMonitor.getCurrentState()
    }

    public func getInterruptionStatistics() async -> InterruptionStatistics {
        await interruptionStatsTracker.getStatistics()
    }

    // MARK: - Performance Profiling

    public func startProfiling(duration: TimeInterval? = nil) async {
        await runtime.startProfiling(duration: duration)
    }

    public func stopProfiling() async {
        await runtime.stopProfiling()
    }

    public func getProfilingResults() async -> PerformanceProfile? {
        guard let profilingData = performanceProfiler.profilingData,
              let startTime = performanceProfiler.profilingStartTime
        else {
            return nil
        }

        let duration = performanceProfiler.profilingDuration ?? Date().timeIntervalSince(startTime)

        return PerformanceProfile(
            startTime: startTime,
            duration: duration,
            cpuProfile: profilingData.cpuProfile,
            memoryProfile: profilingData.memoryProfile,
            latencyProfile: profilingData.latencyProfile,
            bufferProfile: profilingData.bufferProfile,
            bottlenecks: await insights.bottlenecks(from: profilingData),
            optimizations: insights.optimizationOpportunities(from: profilingData),
        )
    }

    public var isProfiling: Bool {
        get async { runtime.isProfiling }
    }

    // MARK: - Export & Reporting

    public func exportMetrics(format: ExportFormat, timeRange: DateInterval? = nil) async -> Data {
        let metrics: [AudioMetrics] = if let timeRange {
            await getHistoricalMetrics(from: timeRange.start, to: timeRange.end)
        } else {
            analytics.historySnapshot
        }

        return reporter.export(metrics: metrics, format: format)
    }

    public func generateReport(for timeRange: DateInterval) async -> MonitoringReport {
        let metrics = await getHistoricalMetrics(from: timeRange.start, to: timeRange.end)
        let alerts = alertHistory.filter { alert in
            timeRange.contains(alert.timestamp)
        }

        let summary = reportBuilder.summary(metrics: metrics, alerts: alerts)
        let keyFindings = reportBuilder.keyFindings(metrics: metrics, alerts: alerts)
        let trends = insights.performanceTrends(for: metrics)
        let recommendations = insights.recommendations()
        let sessionData = await getSessionSummary()

        return MonitoringReport(
            generatedAt: Date(),
            timeRange: timeRange,
            summary: summary,
            keyFindings: keyFindings,
            trends: trends,
            recommendations: recommendations,
            metricsData: sessionData,
            alertHistory: alerts,
        )
    }
}

// MARK: - Private Implementation

private extension AudioMonitor {
    func setupMonitoring() {
        // Set up system-level monitoring
        Task { @MainActor in
            await systemMetricsCollector.startMonitoring()
            await thermalStateMonitor.startMonitoring()
        }
    }

    func setupInterruptionHandling() {
        let notificationCenter = NotificationCenter.default
        let session = AVAudioSession.sharedInstance()

        let inactiveObservation = notificationCenter.addObserver(
            of: session,
            for: .didBecomeInactive
        ) { [weak self] message in
            guard case let .systemInterruption(context) = message.deactivationResult else {
                return
            }
            let interruption = AudioSessionInterruption.from(
                interruptionReason: context.reason
            )
            Self.routeAudioInterruption(interruption, to: self)
        }
        interruptionObservationTokens.insert(inactiveObservation)

        let resumptionObservation = notificationCenter.addObserver(
            of: session,
            for: .resumptionRecommendation
        ) { [weak self] message in
            let interruption = AudioSessionInterruption.from(
                resumptionRecommendation: message.recommendation
            )
            Self.routeAudioInterruption(interruption, to: self)
        }
        interruptionObservationTokens.insert(resumptionObservation)
    }

    nonisolated static func routeAudioInterruption(
        _ interruption: AudioSessionInterruption,
        to owner: AudioMonitor?
    ) {
        Task { @MainActor [weak owner] in
            await owner?.handleAudioInterruption(interruption)
        }
    }

    func handleAudioInterruption(_ interruption: AudioSessionInterruption) async {
        await interruptionStatsTracker.recordInterruption(interruption)

        let severity: AlertSeverity = interruption.type == .began ? .medium : .low
        let alert = PlaybackAlert(
            type: .audioInterruption,
            severity: severity,
            message: interruption.userDescription,
            technicalDetails: interruption.debugDescription,
            suggestedActions: [interruption.recommendedAction.description]
        )

        alertManager.recordInterruptionAlert(alert)
        _alertsSubject.send(alert)
    }

    // MARK: - Calculation Helpers

}

private extension SystemAudioMetrics {
    func updatingInterruptionCount(_ count: Int) -> SystemAudioMetrics {
        SystemAudioMetrics(
            systemAudioCPU: systemAudioCPU,
            activeAudioSessions: activeAudioSessions,
            systemAudioMemory: systemAudioMemory,
            deviceInfo: deviceInfo,
            interruptionCount: count,
            audioUnitLoad: audioUnitLoad
        )
    }
}

// MARK: - Monitoring Helpers

private extension AudioMonitor {
    func mapHealthStatus(_ status: PlaybackHealthStatus) -> DiagnosticHealthStatus {
        switch status {
        case .excellent: .excellent
        case .good: .good
        case .fair: .fair
        case .poor: .poor
        case .critical: .critical
        }
    }
}

extension ThermalState {
    var isElevated: Bool {
        switch self {
        case .nominal:
            false
        case .fair, .serious, .critical:
            true
        }
    }

    var displayName: String {
        rawValue.capitalized
    }
}
