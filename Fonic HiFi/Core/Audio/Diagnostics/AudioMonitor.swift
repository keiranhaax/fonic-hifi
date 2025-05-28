//
//  AudioMonitor.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation
import Combine
import AVFoundation
import OSLog
import os

/// Comprehensive audio monitoring implementation with periodic polling and real-time metrics
@MainActor
public final class AudioMonitor: ObservableObject, AudioMonitoringService {
    
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
    
    private var monitoringTimer: Timer?
    private var profilingTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    
    private var _isMonitoring = false
    private var _isProfiling = false
    private var _currentEngine: AudioEngineService?
    
    private var updateInterval: TimeInterval = 1.0
    private var alertConfiguration = AlertConfiguration.default
    
    // MARK: - Data Storage
    
    private var metricsHistory: [AudioMetrics] = []
    private var alertHistory: [PlaybackAlert] = []
    private var sessionStartTime: Date?
    private var lastAlertTimes: [AlertType: Date] = [:]
    
    // MARK: - Performance Tracking
    
    private var performanceCounters: [String: Double] = [:]
    private let systemMetricsCollector: SystemMetricsCollector
    private let thermalStateMonitor: ThermalStateMonitor
    private let interruptionStatsTracker: InterruptionStatsTracker
    
    // MARK: - Profiling Data
    
    private var profilingData: ProfilingData?
    private var profilingStartTime: Date?
    private var profilingDuration: TimeInterval?
    
    // MARK: - Logging
    
    private let logger = Logger(subsystem: "com.fonic.hifi", category: "AudioMonitor")
    
    // MARK: - Initialization
    
    public init() {
        self.systemMetricsCollector = SystemMetricsCollector()
        self.thermalStateMonitor = ThermalStateMonitor()
        self.interruptionStatsTracker = InterruptionStatsTracker()
        
        setupMonitoring()
        setupInterruptionHandling()
    }
    
    deinit {
        // Cleanup is handled by ARC
    }
    
    // MARK: - Monitoring Control
    
    public func startMonitoring(updateInterval: TimeInterval = 1.0) async {
        logger.info("Starting audio monitoring with interval: \(updateInterval)s")
        
        self.updateInterval = updateInterval
        _isMonitoring = true
        sessionStartTime = Date()
        
        // Clear historical data for new session
        metricsHistory.removeAll()
        alertHistory.removeAll()
        lastAlertTimes.removeAll()
        
        // Start periodic monitoring
        startPeriodicMonitoring()
        
        // Initialize baseline metrics
        let initialMetrics = await collectCurrentMetrics()
        _metricsSubject.send(initialMetrics)
        _healthStatusSubject.send(initialMetrics.healthStatus)
    }
    
    public func stopMonitoring() async {
        logger.info("Stopping audio monitoring")
        
        _isMonitoring = false
        monitoringTimer?.invalidate()
        monitoringTimer = nil
        
        await stopProfiling()
    }
    
    public var isMonitoring: Bool {
        get async { _isMonitoring }
    }
    
    public func updateMonitoringInterval(_ interval: TimeInterval) async {
        guard _isMonitoring else { return }
        
        self.updateInterval = interval
        
        // Restart monitoring with new interval
        monitoringTimer?.invalidate()
        startPeriodicMonitoring()
        
        logger.info("Updated monitoring interval to: \(interval)s")
    }
    
    // MARK: - Metrics Retrieval
    
    public func getCurrentMetrics() async -> AudioMetrics {
        return await collectCurrentMetrics()
    }
    
    public func getHistoricalMetrics(from startTime: Date, to endTime: Date) async -> [AudioMetrics] {
        return metricsHistory.filter { metrics in
            metrics.timestamp >= startTime && metrics.timestamp <= endTime
        }
    }
    
    public func getSessionSummary() async -> AudioSessionSummary {
        guard let sessionStart = sessionStartTime else {
            return createEmptySessionSummary()
        }
        
        let duration = Date().timeIntervalSince(sessionStart)
        let averageMetrics = calculateAverageMetrics()
        let peakMetrics = calculatePeakMetrics()
        let alertsByType = Dictionary(grouping: alertHistory, by: { $0.type })
            .mapValues { $0.count }
        let healthRating = calculateOverallHealthRating()
        let performanceScore = calculateSessionPerformanceScore()
        
        return AudioSessionSummary(
            sessionStart: sessionStart,
            duration: duration,
            averageMetrics: averageMetrics,
            peakMetrics: peakMetrics,
            totalAlerts: alertHistory.count,
            alertsByType: alertsByType,
            healthRating: healthRating,
            sampleCount: metricsHistory.count,
            performanceScore: performanceScore
        )
    }
    
    public func clearHistory() async {
        logger.info("Clearing metrics history")
        metricsHistory.removeAll()
        alertHistory.removeAll()
        lastAlertTimes.removeAll()
    }
    
    // MARK: - Engine Integration
    
    public func attachToEngine(_ engine: AudioEngineService) async {
        logger.info("Attaching to audio engine: \(type(of: engine))")
        _currentEngine = engine
        
        // Set up engine-specific monitoring if needed
        await setupEngineSpecificMonitoring(engine)
    }
    
    public func detachFromEngine() async {
        logger.info("Detaching from current audio engine")
        _currentEngine = nil
    }
    
    public var currentEngine: AudioEngineService? {
        get async { _currentEngine }
    }
    
    // MARK: - Diagnostics & Health
    
    public func performDiagnosticsCheck() async -> PlaybackDiagnostics {
        logger.info("Performing comprehensive diagnostics check")
        
        let currentMetrics = await collectCurrentMetrics()
        let sessionSummary = await getSessionSummary()
        
        return PlaybackDiagnostics(
            sessionDuration: sessionSummary.duration,
            systemHealth: mapHealthStatus(currentMetrics.healthStatus),
            currentMetrics: currentMetrics,
            engineInfo: await collectEngineInfo(),
            sessionInfo: await collectSessionInfo(),
            deviceInfo: await collectDeviceInfo(),
            performanceTrends: await analyzePerformanceTrends(),
            resourceUtilization: await analyzeResourceUtilization(),
            qualityAssessment: await assessAudioQuality(),
            efficiencyAnalysis: await analyzeEfficiency(),
            activeIssues: await identifyActiveIssues(),
            recentAlerts: Array(alertHistory.suffix(10)),
            recommendations: await generateRecommendations(),
            optimizations: await identifyOptimizations(),
            sessionStatistics: await createSessionStatistics(),
            errorHistory: await createErrorHistory(),
            milestones: await identifyMilestones(),
            osCompatibility: await assessOSCompatibility(),
            hardwareCompatibility: await assessHardwareCompatibility(),
            formatSupport: await analyzeFormatSupport(),
            debugInfo: await collectDebugInfo(),
            logEntries: await collectRecentLogEntries(),
            configurationDump: await createConfigurationDump()
        )
    }
    
    public func checkPlaybackHealth() async -> PlaybackHealthStatus {
        let metrics = await collectCurrentMetrics()
        return metrics.healthStatus
    }
    
    public func getPerformanceRecommendations() async -> [PerformanceRecommendation] {
        return await generateRecommendations()
    }
    
    // MARK: - Alerting & Thresholds
    
    public func configureAlerts(_ configuration: AlertConfiguration) async {
        logger.info("Configuring alert thresholds")
        self.alertConfiguration = configuration
    }
    
    public func getAlertConfiguration() async -> AlertConfiguration {
        return alertConfiguration
    }
    
    public func evaluateAlerts() async {
        let metrics = await collectCurrentMetrics()
        await checkForAlerts(metrics: metrics)
    }
    
    // MARK: - System Resource Monitoring
    
    public func getSystemAudioMetrics() async -> SystemAudioMetrics {
        return await systemMetricsCollector.collectSystemMetrics()
    }
    
    public func getThermalState() async -> ThermalMonitoringInfo {
        return await thermalStateMonitor.getCurrentState()
    }
    
    public func getInterruptionStatistics() async -> InterruptionStatistics {
        return await interruptionStatsTracker.getStatistics()
    }
    
    // MARK: - Performance Profiling
    
    public func startProfiling(duration: TimeInterval? = nil) async {
        logger.info("Starting performance profiling")
        
        _isProfiling = true
        profilingStartTime = Date()
        profilingDuration = duration
        profilingData = ProfilingData()
        
        // Start detailed profiling timer (higher frequency)
        startProfilingTimer()
        
        // Schedule stop if duration is specified
        if let duration = duration {
            Task {
                try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
                await stopProfiling()
            }
        }
    }
    
    public func stopProfiling() async {
        guard _isProfiling else { return }
        
        logger.info("Stopping performance profiling")
        
        _isProfiling = false
        profilingTimer?.invalidate()
        profilingTimer = nil
        
        // Finalize profiling data
        await finalizeProfilingData()
    }
    
    public func getProfilingResults() async -> PerformanceProfile? {
        guard let profilingData = profilingData,
              let startTime = profilingStartTime else {
            return nil
        }
        
        let duration = Date().timeIntervalSince(startTime)
        
        return PerformanceProfile(
            startTime: startTime,
            duration: duration,
            cpuProfile: profilingData.cpuProfile,
            memoryProfile: profilingData.memoryProfile,
            latencyProfile: profilingData.latencyProfile,
            bufferProfile: profilingData.bufferProfile,
            bottlenecks: await identifyBottlenecks(from: profilingData),
            optimizations: await identifyOptimizationsFromProfiling(profilingData)
        )
    }
    
    public var isProfiling: Bool {
        get async { _isProfiling }
    }
    
    // MARK: - Export & Reporting
    
    public func exportMetrics(format: ExportFormat, timeRange: DateInterval? = nil) async -> Data {
        let metrics: [AudioMetrics]
        
        if let timeRange = timeRange {
            metrics = await getHistoricalMetrics(from: timeRange.start, to: timeRange.end)
        } else {
            metrics = metricsHistory
        }
        
        switch format {
        case .json:
            return await exportAsJSON(metrics)
        case .csv:
            return await exportAsCSV(metrics)
        case .xml:
            return await exportAsXML(metrics)
        case .binary:
            return await exportAsBinary(metrics)
        }
    }
    
    public func generateReport(for timeRange: DateInterval) async -> MonitoringReport {
        let metrics = await getHistoricalMetrics(from: timeRange.start, to: timeRange.end)
        let alerts = alertHistory.filter { alert in
            timeRange.contains(alert.timestamp)
        }
        
        let summary = await generateReportSummary(metrics: metrics, alerts: alerts)
        let keyFindings = await generateKeyFindings(metrics: metrics, alerts: alerts)
        let trends = await analyzePerformanceTrends(for: metrics)
        let recommendations = await generateRecommendations()
        let sessionData = await getSessionSummary()
        
        return MonitoringReport(
            generatedAt: Date(),
            timeRange: timeRange,
            summary: summary,
            keyFindings: keyFindings,
            trends: trends,
            recommendations: recommendations,
            metricsData: sessionData,
            alertHistory: alerts
        )
    }
}

// MARK: - Private Implementation

private extension AudioMonitor {
    
    func setupMonitoring() {
        // Set up system-level monitoring
        Task {
            await systemMetricsCollector.startMonitoring()
            await thermalStateMonitor.startMonitoring()
        }
    }
    
    func setupInterruptionHandling() {
        NotificationCenter.default.publisher(for: AVAudioSession.interruptionNotification)
            .sink { [weak self] notification in
                Task { @MainActor [weak self] in
                    await self?.handleAudioInterruption(notification)
                }
            }
            .store(in: &cancellables)
    }
    
    func startPeriodicMonitoring() {
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.performPeriodicMonitoring()
            }
        }
    }
    
    func startProfilingTimer() {
        // Higher frequency for profiling (every 100ms)
        profilingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.collectProfilingData()
            }
        }
    }
    
    func performPeriodicMonitoring() async {
        let metrics = await collectCurrentMetrics()
        
        // Store metrics in history
        metricsHistory.append(metrics)
        
        // Limit history size (keep last 1000 entries)
        if metricsHistory.count > 1000 {
            metricsHistory.removeFirst(metricsHistory.count - 1000)
        }
        
        // Emit metrics
        _metricsSubject.send(metrics)
        _healthStatusSubject.send(metrics.healthStatus)
        
        // Check for alerts
        await checkForAlerts(metrics: metrics)
        
        // Update performance counters
        updatePerformanceCounters(metrics: metrics)
    }
    
    func collectCurrentMetrics() async -> AudioMetrics {
        let systemMetrics = await systemMetricsCollector.collectCurrentMetrics()
        let thermalInfo = await thermalStateMonitor.getCurrentState()
        let engineMetrics = await collectEngineMetrics()
        
        return AudioMetrics(
            cpuUsage: systemMetrics.cpuUsage,
            memoryUsage: systemMetrics.memoryUsage,
            bufferUnderruns: engineMetrics.bufferUnderruns,
            decodingLatency: engineMetrics.decodingLatency,
            bufferFillLevel: engineMetrics.bufferFillLevel,
            droppedFrames: engineMetrics.droppedFrames,
            renderLatency: engineMetrics.renderLatency,
            currentBitrate: engineMetrics.currentBitrate,
            averageLatency: calculateAverageLatency(),
            peakLatency: calculatePeakLatency(),
            glitchCount: engineMetrics.glitchCount,
            sampleRate: engineMetrics.sampleRate,
            bitDepth: engineMetrics.bitDepth,
            channelCount: engineMetrics.channelCount,
            engineType: engineMetrics.engineType,
            audioFormat: engineMetrics.audioFormat,
            isBitPerfect: engineMetrics.isBitPerfect,
            bufferSize: engineMetrics.bufferSize,
            bufferResets: engineMetrics.bufferResets,
            averageBufferFill: calculateAverageBufferFill(),
            underrunRate: calculateUnderrunRate(),
            timeSinceLastUnderrun: calculateTimeSinceLastUnderrun(),
            diskIOPS: systemMetrics.diskIOPS,
            networkBandwidth: systemMetrics.networkBandwidth,
            thermalPressure: Float(thermalInfo.isThrottling ? 0.8 : 0.2),
            batteryUsageRate: systemMetrics.batteryUsageRate,
            threadUtilization: engineMetrics.threadUtilization,
            estimatedSNR: engineMetrics.estimatedSNR,
            dynamicRange: engineMetrics.dynamicRange,
            frequencyResponseScore: engineMetrics.frequencyResponseScore,
            jitter: engineMetrics.jitter,
            clockDrift: engineMetrics.clockDrift,
            recoverableErrors: engineMetrics.recoverableErrors,
            criticalErrors: engineMetrics.criticalErrors,
            recoverySuccessRate: engineMetrics.recoverySuccessRate,
            lastRecoveryTime: engineMetrics.lastRecoveryTime,
            performanceScore: calculatePerformanceScore(systemMetrics, engineMetrics),
            qualityScore: calculateQualityScore(engineMetrics),
            reliabilityScore: calculateReliabilityScore(engineMetrics),
            efficiencyScore: calculateEfficiencyScore(systemMetrics, thermalInfo)
        )
    }
    
    func collectEngineMetrics() async -> EngineMetrics {
        guard let engine = _currentEngine else {
            return EngineMetrics.default
        }
        
        // Get metrics from the current engine
        let audioMetrics = await engine.getMetrics()
        return EngineMetrics(
            bufferUnderruns: audioMetrics.bufferUnderruns,
            decodingLatency: audioMetrics.decodingLatency,
            bufferFillLevel: audioMetrics.bufferFillLevel,
            droppedFrames: audioMetrics.droppedFrames,
            renderLatency: audioMetrics.renderLatency,
            currentBitrate: audioMetrics.currentBitrate,
            glitchCount: audioMetrics.glitchCount,
            sampleRate: audioMetrics.sampleRate,
            bitDepth: audioMetrics.bitDepth,
            channelCount: audioMetrics.channelCount,
            engineType: audioMetrics.engineType,
            audioFormat: audioMetrics.audioFormat,
            isBitPerfect: audioMetrics.isBitPerfect,
            bufferSize: audioMetrics.bufferSize,
            bufferResets: audioMetrics.bufferResets,
            threadUtilization: audioMetrics.threadUtilization,
            estimatedSNR: audioMetrics.estimatedSNR,
            dynamicRange: audioMetrics.dynamicRange,
            frequencyResponseScore: audioMetrics.frequencyResponseScore,
            jitter: audioMetrics.jitter,
            clockDrift: audioMetrics.clockDrift,
            recoverableErrors: audioMetrics.recoverableErrors,
            criticalErrors: audioMetrics.criticalErrors,
            recoverySuccessRate: audioMetrics.recoverySuccessRate,
            lastRecoveryTime: audioMetrics.lastRecoveryTime
        )
    }
    
    func checkForAlerts(metrics: AudioMetrics) async {
        var alertsToSend: [PlaybackAlert] = []
        
        // Check CPU usage
        if metrics.cpuUsage > alertConfiguration.cpuThreshold {
            if shouldSendAlert(type: .highCPUUsage) {
                let alert = PlaybackAlert(
                    type: .highCPUUsage,
                    severity: metrics.cpuUsage > 90 ? .critical : .high,
                    message: "High CPU usage detected (\(String(format: "%.1f", metrics.cpuUsage))%)",
                    technicalDetails: "CPU usage above threshold: \(alertConfiguration.cpuThreshold)%",
                    triggerValues: ["cpu_usage": Double(metrics.cpuUsage)],
                    suggestedActions: [
                        "Close background applications",
                        "Reduce audio quality settings",
                        "Check for system updates"
                    ]
                )
                alertsToSend.append(alert)
                updateLastAlertTime(type: .highCPUUsage)
            }
        }
        
        // Check memory usage
        if metrics.memoryUsage > alertConfiguration.memoryThreshold {
            if shouldSendAlert(type: .highMemoryUsage) {
                let alert = PlaybackAlert(
                    type: .highMemoryUsage,
                    severity: .high,
                    message: "High memory usage detected (\(metrics.formattedMemoryUsage))",
                    technicalDetails: "Memory usage above threshold: \(ByteCountFormatter().string(fromByteCount: alertConfiguration.memoryThreshold))",
                    triggerValues: ["memory_usage": Double(metrics.memoryUsage)],
                    suggestedActions: [
                        "Close unused applications",
                        "Restart the audio engine",
                        "Clear audio cache"
                    ]
                )
                alertsToSend.append(alert)
                updateLastAlertTime(type: .highMemoryUsage)
            }
        }
        
        // Check buffer fill level
        if metrics.bufferFillLevel < alertConfiguration.bufferFillThreshold {
            if shouldSendAlert(type: .lowBufferFill) {
                let alert = PlaybackAlert(
                    type: .lowBufferFill,
                    severity: metrics.bufferFillLevel < 0.1 ? .critical : .medium,
                    message: "Low buffer fill level (\(String(format: "%.1f", metrics.bufferFillLevel * 100))%)",
                    technicalDetails: "Buffer fill below threshold: \(String(format: "%.1f", alertConfiguration.bufferFillThreshold * 100))%",
                    triggerValues: ["buffer_fill": Double(metrics.bufferFillLevel)],
                    suggestedActions: [
                        "Increase buffer size",
                        "Reduce system load",
                        "Check storage performance"
                    ]
                )
                alertsToSend.append(alert)
                updateLastAlertTime(type: .lowBufferFill)
            }
        }
        
        // Check buffer underruns
        if metrics.bufferUnderruns > alertConfiguration.maxBufferUnderruns {
            if shouldSendAlert(type: .bufferUnderrun) {
                let alert = PlaybackAlert(
                    type: .bufferUnderrun,
                    severity: .critical,
                    message: "Buffer underruns detected (\(metrics.bufferUnderruns))",
                    technicalDetails: "Buffer underruns exceed threshold: \(alertConfiguration.maxBufferUnderruns)",
                    triggerValues: ["underruns": Double(metrics.bufferUnderruns)],
                    suggestedActions: [
                        "Increase buffer size immediately",
                        "Check system performance",
                        "Verify storage speed"
                    ]
                )
                alertsToSend.append(alert)
                updateLastAlertTime(type: .bufferUnderrun)
            }
        }
        
        // Check latency spikes
        if metrics.renderLatency > alertConfiguration.latencyThreshold {
            if shouldSendAlert(type: .latencySpike) {
                let alert = PlaybackAlert(
                    type: .latencySpike,
                    severity: .medium,
                    message: "High latency detected (\(String(format: "%.1f", metrics.renderLatency * 1000))ms)",
                    technicalDetails: "Latency above threshold: \(String(format: "%.1f", alertConfiguration.latencyThreshold * 1000))ms",
                    triggerValues: ["latency": metrics.renderLatency],
                    suggestedActions: [
                        "Optimize audio settings",
                        "Check system load",
                        "Restart audio engine"
                    ]
                )
                alertsToSend.append(alert)
                updateLastAlertTime(type: .latencySpike)
            }
        }
        
        // Check thermal throttling
        if alertConfiguration.enableThermalMonitoring && metrics.thermalPressure > 0.6 {
            if shouldSendAlert(type: .thermalThrottling) {
                let alert = PlaybackAlert(
                    type: .thermalThrottling,
                    severity: .high,
                    message: "Thermal throttling detected",
                    technicalDetails: "Device thermal pressure: \(String(format: "%.1f", metrics.thermalPressure))",
                    triggerValues: ["thermal_pressure": Double(metrics.thermalPressure)],
                    suggestedActions: [
                        "Allow device to cool down",
                        "Reduce audio quality temporarily",
                        "Close background apps"
                    ]
                )
                alertsToSend.append(alert)
                updateLastAlertTime(type: .thermalThrottling)
            }
        }
        
        // Send all alerts
        for alert in alertsToSend {
            alertHistory.append(alert)
            _alertsSubject.send(alert)
            logger.warning("Alert triggered: \(alert.type.rawValue) - \(alert.message)")
        }
    }
    
    func shouldSendAlert(type: AlertType) -> Bool {
        guard let lastAlertTime = lastAlertTimes[type] else {
            return true
        }
        
        let timeSinceLastAlert = Date().timeIntervalSince(lastAlertTime)
        return timeSinceLastAlert >= alertConfiguration.alertCooldownSeconds
    }
    
    func updateLastAlertTime(type: AlertType) {
        lastAlertTimes[type] = Date()
    }
    
    func handleAudioInterruption(_ notification: Notification) async {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        let interruptionType: InterruptionType
        switch type {
        case .began:
            interruptionType = .began
        case .ended:
            interruptionType = .ended
        @unknown default:
            interruptionType = .began
        }
        
        await interruptionStatsTracker.recordInterruption(type: interruptionType)
        
        let alert = PlaybackAlert(
            type: .audioInterruption,
            severity: .medium,
            message: "Audio session interrupted",
            technicalDetails: "Interruption type: \(type == .began ? "began" : "ended")",
            suggestedActions: ["Audio will resume automatically when possible"]
        )
        
        alertHistory.append(alert)
        _alertsSubject.send(alert)
    }
    
    // MARK: - Calculation Helpers
    
    func calculatePerformanceScore(_ systemMetrics: SystemMetrics, _ engineMetrics: EngineMetrics) -> Float {
        var score: Float = 1.0
        
        // CPU penalty
        if systemMetrics.cpuUsage > 80 {
            score -= 0.3
        } else if systemMetrics.cpuUsage > 60 {
            score -= 0.15
        }
        
        // Buffer underrun penalty
        if engineMetrics.bufferUnderruns > 0 {
            score -= 0.4
        }
        
        // Dropped frames penalty
        if engineMetrics.droppedFrames > 0 {
            score -= 0.2
        }
        
        // Latency penalty
        if engineMetrics.renderLatency > 0.1 {
            score -= 0.1
        }
        
        return max(0.0, min(1.0, score))
    }
    
    func calculateQualityScore(_ engineMetrics: EngineMetrics) -> Float {
        var score: Float = 1.0
        
        // Bit-perfect bonus
        if engineMetrics.isBitPerfect {
            score += 0.1
        }
        
        // High resolution bonus
        if engineMetrics.sampleRate >= 96000 && engineMetrics.bitDepth >= 24 {
            score += 0.05
        }
        
        // Glitch penalty
        if engineMetrics.glitchCount > 0 {
            score -= 0.3
        }
        
        // SNR bonus
        if let snr = engineMetrics.estimatedSNR, snr > 100 {
            score += 0.05
        }
        
        return max(0.0, min(1.0, score))
    }
    
    func calculateReliabilityScore(_ engineMetrics: EngineMetrics) -> Float {
        var score: Float = 1.0
        
        // Critical errors penalty
        if engineMetrics.criticalErrors > 0 {
            score -= 0.5
        }
        
        // Recoverable errors penalty
        if engineMetrics.recoverableErrors > 0 {
            score -= 0.2
        }
        
        // Recovery success rate bonus
        score *= engineMetrics.recoverySuccessRate
        
        return max(0.0, min(1.0, score))
    }
    
    func calculateEfficiencyScore(_ systemMetrics: SystemMetrics, _ thermalInfo: ThermalMonitoringInfo) -> Float {
        var score: Float = 1.0
        
        // CPU efficiency
        if systemMetrics.cpuUsage < 30 {
            score += 0.1
        } else if systemMetrics.cpuUsage > 70 {
            score -= 0.2
        }
        
        // Thermal efficiency
        if thermalInfo.isThrottling {
            score -= 0.3
        }
        
        // Battery efficiency
        if let batteryRate = systemMetrics.batteryUsageRate, batteryRate < 100 {
            score += 0.05
        }
        
        return max(0.0, min(1.0, score))
    }
    
    func calculateAverageLatency() -> TimeInterval {
        let latencies = metricsHistory.map { $0.renderLatency }
        return latencies.isEmpty ? 0 : latencies.reduce(0, +) / Double(latencies.count)
    }
    
    func calculatePeakLatency() -> TimeInterval {
        return metricsHistory.map { $0.renderLatency }.max() ?? 0
    }
    
    func calculateAverageBufferFill() -> Float {
        let fills = metricsHistory.map { $0.bufferFillLevel }
        return fills.isEmpty ? 1.0 : fills.reduce(0, +) / Float(fills.count)
    }
    
    func calculateUnderrunRate() -> Float {
        guard let sessionStart = sessionStartTime else { return 0 }
        
        let sessionDuration = Date().timeIntervalSince(sessionStart)
        let totalUnderruns = metricsHistory.last?.bufferUnderruns ?? 0
        
        return sessionDuration > 0 ? Float(totalUnderruns) / Float(sessionDuration / 60) : 0
    }
    
    func calculateTimeSinceLastUnderrun() -> TimeInterval? {
        // This would need to be tracked when underruns occur
        return nil
    }
    
    func updatePerformanceCounters(metrics: AudioMetrics) {
        performanceCounters["total_samples"] = (performanceCounters["total_samples"] ?? 0) + 1
        performanceCounters["cpu_max"] = max(performanceCounters["cpu_max"] ?? 0, Double(metrics.cpuUsage))
        performanceCounters["memory_max"] = max(performanceCounters["memory_max"] ?? 0, Double(metrics.memoryUsage))
        performanceCounters["latency_max"] = max(performanceCounters["latency_max"] ?? 0, metrics.renderLatency)
        performanceCounters["underruns_total"] = Double(metrics.bufferUnderruns)
    }
    
    func calculateAverageMetrics() -> AudioMetrics {
        guard !metricsHistory.isEmpty else { return AudioMetrics.empty }
        
        let count = Float(metricsHistory.count)
        let avgCPU = metricsHistory.map { $0.cpuUsage }.reduce(0, +) / count
        let avgMemory = metricsHistory.map { $0.memoryUsage }.reduce(0, +) / Int64(metricsHistory.count)
        let avgLatency = metricsHistory.map { $0.renderLatency }.reduce(0, +) / Double(metricsHistory.count)
        let avgBufferFill = metricsHistory.map { $0.bufferFillLevel }.reduce(0, +) / count
        
        return AudioMetrics(
            cpuUsage: avgCPU,
            memoryUsage: avgMemory,
            bufferUnderruns: 0,
            decodingLatency: avgLatency,
            bufferFillLevel: avgBufferFill,
            droppedFrames: 0,
            renderLatency: avgLatency
        )
    }
    
    func calculatePeakMetrics() -> AudioMetrics {
        guard !metricsHistory.isEmpty else { return AudioMetrics.empty }
        
        let maxCPU = metricsHistory.map { $0.cpuUsage }.max() ?? 0
        let maxMemory = metricsHistory.map { $0.memoryUsage }.max() ?? 0
        let maxLatency = metricsHistory.map { $0.renderLatency }.max() ?? 0
        let minBufferFill = metricsHistory.map { $0.bufferFillLevel }.min() ?? 1.0
        let maxUnderruns = metricsHistory.map { $0.bufferUnderruns }.max() ?? 0
        let maxDroppedFrames = metricsHistory.map { $0.droppedFrames }.max() ?? 0
        
        return AudioMetrics(
            cpuUsage: maxCPU,
            memoryUsage: maxMemory,
            bufferUnderruns: maxUnderruns,
            decodingLatency: maxLatency,
            bufferFillLevel: minBufferFill,
            droppedFrames: maxDroppedFrames,
            renderLatency: maxLatency
        )
    }
    
    func calculateOverallHealthRating() -> PlaybackHealthStatus {
        guard !metricsHistory.isEmpty else { return .excellent }
        
        let recentMetrics = metricsHistory.suffix(10)
        let avgPerformanceScore = recentMetrics.map { $0.performanceScore }.reduce(0, +) / Float(recentMetrics.count)
        let hasUnderruns = recentMetrics.contains { $0.bufferUnderruns > 0 }
        let hasCriticalErrors = recentMetrics.contains { $0.criticalErrors > 0 }
        
        if hasCriticalErrors {
            return .critical
        } else if hasUnderruns {
            return .poor
        } else if avgPerformanceScore >= 0.9 {
            return .excellent
        } else if avgPerformanceScore >= 0.7 {
            return .good
        } else {
            return .fair
        }
    }
    
    func calculateSessionPerformanceScore() -> Double {
        guard !metricsHistory.isEmpty else { return 1.0 }
        
        let avgPerformanceScore = metricsHistory.map { $0.performanceScore }.reduce(0, +) / Float(metricsHistory.count)
        return Double(avgPerformanceScore)
    }
    
    func createEmptySessionSummary() -> AudioSessionSummary {
        return AudioSessionSummary(
            sessionStart: Date(),
            duration: 0,
            averageMetrics: AudioMetrics.empty,
            peakMetrics: AudioMetrics.empty,
            totalAlerts: 0,
            alertsByType: [:],
            healthRating: .excellent,
            sampleCount: 0,
            performanceScore: 1.0
        )
    }
}

// MARK: - Supporting Types

/// Collected system metrics
private struct SystemMetrics {
    let cpuUsage: Float
    let memoryUsage: Int64
    let diskIOPS: Float
    let networkBandwidth: Int64
    let batteryUsageRate: Float?
}

/// Collected engine metrics
private struct EngineMetrics {
    let bufferUnderruns: Int
    let decodingLatency: TimeInterval
    let bufferFillLevel: Float
    let droppedFrames: Int
    let renderLatency: TimeInterval
    let currentBitrate: Int64
    let glitchCount: Int
    let sampleRate: Double
    let bitDepth: Int
    let channelCount: Int
    let engineType: String
    let audioFormat: String
    let isBitPerfect: Bool
    let bufferSize: Int
    let bufferResets: Int
    let threadUtilization: ThreadUtilization
    let estimatedSNR: Float?
    let dynamicRange: Float?
    let frequencyResponseScore: Float?
    let jitter: Float
    let clockDrift: Float
    let recoverableErrors: Int
    let criticalErrors: Int
    let recoverySuccessRate: Float
    let lastRecoveryTime: TimeInterval?
    
    static var `default`: EngineMetrics {
        return EngineMetrics(
            bufferUnderruns: 0,
            decodingLatency: 0,
            bufferFillLevel: 1.0,
            droppedFrames: 0,
            renderLatency: 0,
            currentBitrate: 0,
            glitchCount: 0,
            sampleRate: 44100,
            bitDepth: 16,
            channelCount: 2,
            engineType: "unknown",
            audioFormat: "unknown",
            isBitPerfect: false,
            bufferSize: 512,
            bufferResets: 0,
            threadUtilization: ThreadUtilization(
                audioThreadCPU: 0.0,
                decoderThreadCPU: 0.0,
                ioThreadCPU: 0.0,
                mainThreadCPU: 0.0,
                activeThreadCount: 1,
                threadPriorities: [:]
            ),
            estimatedSNR: nil,
            dynamicRange: nil,
            frequencyResponseScore: nil,
            jitter: 0,
            clockDrift: 0,
            recoverableErrors: 0,
            criticalErrors: 0,
            recoverySuccessRate: 1.0,
            lastRecoveryTime: nil
        )
    }
}

/// Profiling data collection
private class ProfilingData {
    var cpuSamples: [Float] = []
    var memorySamples: [Int64] = []
    var latencySamples: [TimeInterval] = []
    var bufferFillSamples: [Float] = []
    
    var cpuProfile: CPUProfile {
        let avg = cpuSamples.isEmpty ? 0 : cpuSamples.reduce(0, +) / Float(cpuSamples.count)
        let peak = cpuSamples.max() ?? 0
        
        return CPUProfile(
            averageUsage: avg,
            peakUsage: peak,
            usageDistribution: cpuSamples,
            performanceStates: [:]
        )
    }
    
    var memoryProfile: MemoryProfile {
        let avg = memorySamples.isEmpty ? 0 : memorySamples.reduce(0, +) / Int64(memorySamples.count)
        let peak = memorySamples.max() ?? 0
        
        return MemoryProfile(
            averageUsage: avg,
            peakUsage: peak,
            allocationPatterns: [],
            leakIndicators: []
        )
    }
    
    var latencyProfile: LatencyProfile {
        let avg = latencySamples.isEmpty ? 0 : latencySamples.reduce(0, +) / Double(latencySamples.count)
        let max = latencySamples.max() ?? 0
        
        return LatencyProfile(
            averageLatency: avg,
            maxLatency: max,
            latencyDistribution: latencySamples,
            spikes: []
        )
    }
    
    var bufferProfile: BufferProfile {
        let avg = bufferFillSamples.isEmpty ? 1.0 : bufferFillSamples.reduce(0, +) / Float(bufferFillSamples.count)
        let min = bufferFillSamples.min() ?? 1.0
        
        return BufferProfile(
            averageBufferFill: avg,
            minBufferFill: min,
            underrunCount: 0,
            fillDistribution: bufferFillSamples
        )
    }
}

/// System metrics collector
@MainActor
private class SystemMetricsCollector {
    func startMonitoring() async {
        // Implementation would start system-level monitoring
    }
    
    func collectCurrentMetrics() async -> SystemMetrics {
        // Implementation would collect real system metrics
        return SystemMetrics(
            cpuUsage: 25.0,
            memoryUsage: 50_000_000,
            diskIOPS: 100,
            networkBandwidth: 0,
            batteryUsageRate: 150
        )
    }
    
    func collectSystemMetrics() async -> SystemAudioMetrics {
        // Implementation would collect system-wide audio metrics
        return SystemAudioMetrics(
            systemAudioCPU: 15.0,
            activeAudioSessions: 2,
            systemAudioMemory: 25_000_000,
            deviceInfo: AudioDeviceInfo(
                deviceID: "built-in",
                name: "iPhone Speaker",
                sampleRate: 44100,
                bitDepth: 16,
                channels: 2,
                bufferSize: 512,
                latency: 0.023
            ),
            interruptionCount: 0,
            audioUnitLoad: 0.3
        )
    }
}

/// Thermal state monitor
@MainActor
private class ThermalStateMonitor {
    func startMonitoring() async {
        // Implementation would start thermal monitoring
    }
    
    func getCurrentState() async -> ThermalMonitoringInfo {
        // Implementation would get actual thermal state
        return ThermalMonitoringInfo(
            thermalState: .nominal,
            isThrottling: false,
            recommendedAdjustments: []
        )
    }
}

/// Interruption statistics tracker
@MainActor
private class InterruptionStatsTracker {
    private var interruptions: [InterruptionRecord] = []
    
    func recordInterruption(type: InterruptionType) async {
        let record = InterruptionRecord(
            type: type,
            timestamp: Date(),
            duration: 0,
            recoverySuccessful: true
        )
        interruptions.append(record)
    }
    
    func getStatistics() async -> InterruptionStatistics {
        let byType = Dictionary(grouping: interruptions, by: { $0.type })
            .mapValues { $0.count }
        
        let avgDuration = interruptions.map { $0.duration }.reduce(0, +) / Double(max(1, interruptions.count))
        let maxDuration = interruptions.map { $0.duration }.max() ?? 0
        let successRate = Double(interruptions.filter { $0.recoverySuccessful }.count) / Double(max(1, interruptions.count))
        
        return InterruptionStatistics(
            totalInterruptions: interruptions.count,
            interruptionsByType: byType,
            averageInterruptionDuration: avgDuration,
            longestInterruptionDuration: maxDuration,
            recoverySuccessRate: successRate,
            lastInterruptionTime: interruptions.last?.timestamp
        )
    }
}

/// Interruption record for tracking
private struct InterruptionRecord {
    let type: InterruptionType
    let timestamp: Date
    let duration: TimeInterval
    let recoverySuccessful: Bool
}

// MARK: - Placeholder Extensions

private extension AudioMonitor {
    
    func setupEngineSpecificMonitoring(_ engine: AudioEngineService) async {
        // Implementation would set up engine-specific monitoring
    }
    
    func collectEngineInfo() async -> AudioEngineInfo {
        // Implementation would collect engine information
        return AudioEngineInfo(
            type: "AVAudioEngine",
            version: "1.0",
            capabilities: ["Standard", "LowLatency"],
            configuration: [:],
            performanceProfile: "Standard",
            lastInitialized: Date()
        )
    }
    
    func collectSessionInfo() async -> AudioSessionInfo {
        // Implementation would collect session information
        return AudioSessionInfo(
            category: "playback",
            mode: "default",
            options: [],
            sampleRate: 44100,
            ioBufferDuration: 0.023,
            isActive: true,
            isOtherAudioPlaying: false
        )
    }
    
    func collectDeviceInfo() async -> AudioDeviceInfo {
        // Implementation would collect device information
        return AudioDeviceInfo(
            deviceID: "built-in",
            name: "iPhone Speaker",
            sampleRate: 44100,
            bitDepth: 16,
            channels: 2,
            bufferSize: 512,
            latency: 0.023
        )
    }
    
    func collectProfilingData() async {
        guard let profilingData = profilingData else { return }
        
        let metrics = await collectCurrentMetrics()
        profilingData.cpuSamples.append(metrics.cpuUsage)
        profilingData.memorySamples.append(metrics.memoryUsage)
        profilingData.latencySamples.append(metrics.renderLatency)
        profilingData.bufferFillSamples.append(metrics.bufferFillLevel)
    }
    
    func finalizeProfilingData() async {
        // Implementation would finalize profiling data
    }
    
    func identifyBottlenecks(from profilingData: ProfilingData) async -> [PerformanceBottleneck] {
        // Implementation would analyze profiling data for bottlenecks
        return []
    }
    
    func identifyOptimizationsFromProfiling(_ profilingData: ProfilingData) async -> [OptimizationOpportunity] {
        // Implementation would identify optimization opportunities
        return []
    }
    
    func mapHealthStatus(_ status: PlaybackHealthStatus) -> DiagnosticHealthStatus {
        switch status {
        case .excellent: return .excellent
        case .good: return .good
        case .fair: return .fair
        case .poor: return .poor
        case .critical: return .critical
        }
    }
    
    // Placeholder implementations for all the analysis methods
    func analyzePerformanceTrends() async -> PerformanceTrendSummary {
        return PerformanceTrendSummary(
            cpuTrend: TrendIndicator(currentValue: 25, changePercent: 0, direction: .stable, stability: .stable),
            memoryTrend: TrendIndicator(currentValue: 50, changePercent: 0, direction: .stable, stability: .stable),
            latencyTrend: TrendIndicator(currentValue: 23, changePercent: 0, direction: .stable, stability: .stable),
            qualityTrend: TrendIndicator(currentValue: 95, changePercent: 0, direction: .stable, stability: .stable),
            bufferTrend: TrendIndicator(currentValue: 85, changePercent: 0, direction: .stable, stability: .stable),
            overallTrend: .stable
        )
    }
    
    func analyzeResourceUtilization() async -> ResourceUtilizationSummary {
        return ResourceUtilizationSummary(
            cpuUtilization: ResourceUsageAnalysis(currentUsage: 25, averageUsage: 23, peakUsage: 30, efficiencyScore: 0.8, classification: .low),
            memoryUtilization: ResourceUsageAnalysis(currentUsage: 50, averageUsage: 48, peakUsage: 60, efficiencyScore: 0.7, classification: .moderate),
            batteryUtilization: ResourceUsageAnalysis(currentUsage: 150, averageUsage: 140, peakUsage: 200, efficiencyScore: 0.75, classification: .moderate),
            networkUtilization: ResourceUsageAnalysis(currentUsage: 0, averageUsage: 0, peakUsage: 0, efficiencyScore: 1.0, classification: .minimal),
            overallEfficiency: .good
        )
    }
    
    func assessAudioQuality() async -> QualityAssessmentSummary {
        return QualityAssessmentSummary(
            qualityScore: 85,
            bitPerfectStatus: .available,
            signalIntegrity: SignalIntegrityAssessment(
                integrityScore: 90,
                issues: [],
                pathAnalysis: "Clean signal path",
                jitterLevel: .low
            ),
            qualityIssues: [],
            improvements: []
        )
    }
    
    func analyzeEfficiency() async -> EfficiencyAnalysisSummary {
        return EfficiencyAnalysisSummary(
            efficiencyScore: 80,
            powerEfficiency: .good,
            performanceEfficiency: .good,
            optimizationOpportunities: []
        )
    }
    
    func identifyActiveIssues() async -> [DiagnosticIssue] {
        return []
    }
    
    func generateRecommendations() async -> [PerformanceRecommendation] {
        return []
    }
    
    func identifyOptimizations() async -> [OptimizationOpportunity] {
        return []
    }
    
    func createSessionStatistics() async -> SessionStatisticsSummary {
        let summary = await getSessionSummary()
        return SessionStatisticsSummary(
            totalUptime: summary.duration,
            averagePerformanceScore: summary.performanceScore,
            totalAlerts: summary.totalAlerts,
            errorRate: 0,
            bufferUnderrunIncidents: 0,
            qualityDropCount: 0,
            recoverySuccessRate: 1.0
        )
    }
    
    func createErrorHistory() async -> ErrorHistorySummary {
        return ErrorHistorySummary(
            totalErrors: 0,
            errorsByCategory: [:],
            mostRecentError: nil,
            mostCommonErrorType: nil,
            errorFrequencyTrend: .stable
        )
    }
    
    func identifyMilestones() async -> [PerformanceMilestone] {
        return []
    }
    
    func assessOSCompatibility() async -> OSCompatibilityInfo {
        return OSCompatibilityInfo(
            iosVersion: "17.0",
            deviceModel: "iPhone",
            compatibilityStatus: .excellent,
            knownIssues: [],
            recommendedSettings: []
        )
    }
    
    func assessHardwareCompatibility() async -> HardwareCompatibilityInfo {
        return HardwareCompatibilityInfo(
            deviceCapabilities: DeviceCapabilityAssessment(
                capabilityScore: 80,
                cpuRating: .good,
                memoryRating: .good,
                audioProcessingCapability: .standard
            ),
            audioHardware: AudioHardwareInfo(
                builtInAudio: BuiltInAudioInfo(
                    dacQuality: .good,
                    maxSampleRate: 48000,
                    maxBitDepth: 24,
                    snr: 90
                ),
                externalDevices: [],
                supportedFormats: []
            ),
            performanceLimitations: [],
            upgradeRecommendations: []
        )
    }
    
    func analyzeFormatSupport() async -> FormatSupportMatrix {
        return FormatSupportMatrix(
            supportedFormats: [],
            compatibilityScore: 85,
            recommendations: []
        )
    }
    
    func collectDebugInfo() async -> DebugInformation {
        return DebugInformation(
            sessionID: UUID().uuidString,
            systemInfo: SystemDebugInfo(
                deviceIdentifier: "iPhone",
                systemVersion: "17.0",
                availableMemory: 1_000_000_000,
                cpuArchitecture: "arm64",
                thermalState: "nominal"
            ),
            audioStackInfo: AudioStackDebugInfo(
                activeAudioUnits: [],
                sessionDetails: [:],
                engineConfiguration: [:],
                bufferInfo: BufferDebugInfo(
                    bufferSizes: [:],
                    bufferUtilization: [:],
                    allocationHistory: []
                )
            ),
            performanceCounters: performanceCounters,
            debugFlags: [:]
        )
    }
    
    func collectRecentLogEntries() async -> [DiagnosticLogEntry] {
        return []
    }
    
    func createConfigurationDump() async -> ConfigurationDump {
        return ConfigurationDump(
            engineConfig: [:],
            sessionConfig: [:],
            deviceConfig: [:],
            userPreferences: [:],
            systemSettings: [:]
        )
    }
    
    // Export methods
    func exportAsJSON(_ metrics: [AudioMetrics]) async -> Data {
        // Implementation would export as JSON
        return Data()
    }
    
    func exportAsCSV(_ metrics: [AudioMetrics]) async -> Data {
        // Implementation would export as CSV
        return Data()
    }
    
    func exportAsXML(_ metrics: [AudioMetrics]) async -> Data {
        // Implementation would export as XML
        return Data()
    }
    
    func exportAsBinary(_ metrics: [AudioMetrics]) async -> Data {
        // Implementation would export as binary format
        return Data()
    }
    
    // Report generation methods
    func generateReportSummary(metrics: [AudioMetrics], alerts: [PlaybackAlert]) async -> String {
        return "Performance summary for \(metrics.count) samples and \(alerts.count) alerts"
    }
    
    func generateKeyFindings(metrics: [AudioMetrics], alerts: [PlaybackAlert]) async -> [String] {
        var findings: [String] = []
        
        if !alerts.isEmpty {
            findings.append("Total of \(alerts.count) alerts during monitoring period")
        }
        
        let avgCPU = metrics.map { $0.cpuUsage }.reduce(0, +) / Float(max(1, metrics.count))
        if avgCPU > 50 {
            findings.append("Average CPU usage was elevated at \(String(format: "%.1f", avgCPU))%")
        }
        
        return findings
    }
    
    func analyzePerformanceTrends(for metrics: [AudioMetrics]) async -> [PerformanceTrend] {
        // Implementation would analyze trends in the metrics
        return []
    }
} 