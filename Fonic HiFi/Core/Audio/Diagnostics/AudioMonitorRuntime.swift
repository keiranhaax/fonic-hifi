import AVFoundation
import Foundation
import OSLog

@MainActor
final class AudioMonitorRuntime {
    private let scheduler: AudioMetricsScheduler
    private let analytics: AudioSessionAnalytics
    private let metricsCollector: AudioMonitorMetricsCollector
    private let alertManager: any AudioAlertManaging
    private var performanceMonitor: PerformanceMonitor?
    private let logger: Logger
    private let publishMetrics: (AudioMetrics) -> Void
    private let publishHealthStatus: (PlaybackHealthStatus) -> Void
    private let publishAlert: (PlaybackAlert) -> Void

    private var engine: AudioEngineService?
    private var lastUnderrunDate: Date?
    private(set) var updateInterval: TimeInterval = 1.0
    private(set) var isMonitoring = false

    init(
        scheduler: AudioMetricsScheduler,
        analytics: AudioSessionAnalytics,
        metricsCollector: AudioMonitorMetricsCollector,
        alertManager: any AudioAlertManaging,
        performanceMonitor: PerformanceMonitor?,
        logger: Logger,
        publishMetrics: @escaping (AudioMetrics) -> Void,
        publishHealthStatus: @escaping (PlaybackHealthStatus) -> Void,
        publishAlert: @escaping (PlaybackAlert) -> Void
    ) {
        self.scheduler = scheduler
        self.analytics = analytics
        self.metricsCollector = metricsCollector
        self.alertManager = alertManager
        self.performanceMonitor = performanceMonitor
        self.logger = logger
        self.publishMetrics = publishMetrics
        self.publishHealthStatus = publishHealthStatus
        self.publishAlert = publishAlert
    }

    func startMonitoring(updateInterval: TimeInterval, engine: AudioEngineService?) async {
        logger.info("Starting audio monitoring with interval: \(updateInterval, privacy: .public)s")

        self.updateInterval = updateInterval
        isMonitoring = true
        self.engine = engine
        lastUnderrunDate = nil

        analytics.startNewSession()
        alertManager.reset()

        scheduler.startMonitoring(every: updateInterval) { [weak self] in
            await self?.performPeriodicMonitoring()
        }

        let initialMetrics = await collectCurrentMetrics()
        publishMetrics(initialMetrics)
        publishHealthStatus(initialMetrics.healthStatus)
    }

    func stopMonitoring() async {
        guard isMonitoring else { return }

        logger.info("Stopping audio monitoring")

        isMonitoring = false
        scheduler.stopMonitoring()
    }

    func updateMonitoringInterval(to interval: TimeInterval) {
        guard isMonitoring else { return }

        updateInterval = interval
        scheduler.updateMonitoringInterval(to: interval)

        logger.info("Updated monitoring interval to: \(interval, privacy: .public)s")
    }

    func updateEngine(_ engine: AudioEngineService?) {
        self.engine = engine
    }

    func collectCurrentMetrics() async -> AudioMetrics {
        await metricsCollector.collectMetrics(
            for: engine,
            analytics: analytics,
            timeSinceLastUnderrun: lastUnderrunDate.map { Date().timeIntervalSince($0) }
        )
    }

    func invalidate() {
        scheduler.cancelAll()
    }
}

private extension AudioMonitorRuntime {
    func performPeriodicMonitoring() async {
        let metrics = await collectCurrentMetrics()

        analytics.append(metrics)
        if metrics.bufferUnderruns > 0 {
            lastUnderrunDate = Date()
        }

        if let performanceMonitor {
            let outputLatency = await audioOutputLatency()
            let totalLatency = metrics.renderLatency + outputLatency
            await performanceMonitor.recordAudioLatency(totalLatency)

            if metrics.bufferUnderruns > 0 {
                for _ in 0 ..< metrics.bufferUnderruns {
                    await performanceMonitor.recordBufferUnderrun()
                }
            }

            await performanceMonitor.recordMemoryUsage(metrics.memoryUsage)

            let memoryPressure = await performanceMonitor.checkMemoryPressure()
            if memoryPressure == .warning || memoryPressure == .urgent || memoryPressure == .critical {
                await performanceMonitor.recordMemoryWarning()
            }
        }

        publishMetrics(metrics)
        publishHealthStatus(metrics.healthStatus)

        processAlerts(for: metrics)
        analytics.recordPerformanceCounters(for: metrics)
    }

    func processAlerts(for metrics: AudioMetrics) {
        let alerts = alertManager.evaluateAlerts(for: metrics)
        guard !alerts.isEmpty else { return }

        for alert in alerts {
            publishAlert(alert)
            logger.warning("Alert triggered: \(alert.type.rawValue, privacy: .public) - \(alert.message, privacy: .private)")
        }
    }

    func audioOutputLatency() async -> TimeInterval {
        let session = AVAudioSession.sharedInstance()
        return session.outputLatency + session.ioBufferDuration
    }
}

extension AudioMonitorRuntime: AudioMonitorRuntimeControlling {}
