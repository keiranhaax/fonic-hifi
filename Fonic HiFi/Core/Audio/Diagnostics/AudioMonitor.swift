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
#if canImport(UIKit)
import UIKit
#endif

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
    
    private func recentMetrics(window: Int = 120) -> [AudioMetrics] {
        guard !metricsHistory.isEmpty else { return [] }
        let count = min(window, metricsHistory.count)
        return Array(metricsHistory.suffix(count))
    }
    
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
            // Timer callbacks can run on background threads, so explicitly dispatch to main
            DispatchQueue.main.async {
                guard let self = self else { return }
                Task { @MainActor in
                    await self.performPeriodicMonitoring()
                }
            }
        }
    }
    
    func startProfilingTimer() {
        // Higher frequency for profiling (every 100ms)
        profilingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // Timer callbacks can run on background threads, so explicitly dispatch to main
            DispatchQueue.main.async {
                guard let self = self else { return }
                Task { @MainActor in
                    await self.collectProfilingData()
                }
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
    var sampleTimestamps: [Date] = []
    var underrunCount: Int = 0
    var lastKnownBufferUnderrunTotal: Int?
    
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
        let maxLatency = latencySamples.max() ?? 0
        let threshold = max(avg * 1.5, avg + 0.01)
        
        var spikes: [LatencySpike] = []
        for index in latencySamples.indices where latencySamples[index] > threshold {
            let timestamp = sampleTimestamps.indices.contains(index) ? sampleTimestamps[index] : Date()
            let previousTimestamp = index > 0 && sampleTimestamps.indices.contains(index - 1) ? sampleTimestamps[index - 1] : timestamp
            let duration = max(timestamp.timeIntervalSince(previousTimestamp), 0.1)
            let latency = latencySamples[index]
            let possibleCause: String?
            if latency > 0.08 {
                possibleCause = "Decoder back-pressure"
            } else if latency > 0.05 {
                possibleCause = "Render scheduling delay"
            } else {
                possibleCause = nil
            }
            spikes.append(
                LatencySpike(
                    timestamp: timestamp,
                    duration: duration,
                    peakLatency: latency,
                    possibleCause: possibleCause
                )
            )
        }
        
        return LatencyProfile(
            averageLatency: avg,
            maxLatency: maxLatency,
            latencyDistribution: latencySamples,
            spikes: spikes
        )
    }
    
    var bufferProfile: BufferProfile {
        let avg = bufferFillSamples.isEmpty ? 1.0 : bufferFillSamples.reduce(0, +) / Float(bufferFillSamples.count)
        let min = bufferFillSamples.min() ?? 1.0
        
        return BufferProfile(
            averageBufferFill: avg,
            minBufferFill: min,
            underrunCount: underrunCount,
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
        let session = AVAudioSession.sharedInstance()
        let category = session.category.rawValue
        let mode = session.mode.rawValue
        let options = session.categoryOptions.optionNames
        let sampleRate = session.sampleRate
        let bufferDuration = session.ioBufferDuration
        let isOtherAudioPlaying = session.isOtherAudioPlaying
        let isActive = !session.secondaryAudioShouldBeSilencedHint || _isMonitoring
        
        return AudioSessionInfo(
            category: category,
            mode: mode,
            options: options,
            sampleRate: sampleRate,
            ioBufferDuration: bufferDuration,
            isActive: isActive,
            isOtherAudioPlaying: isOtherAudioPlaying
        )
    }
    
    func collectDeviceInfo() async -> AudioDeviceInfo {
        let session = AVAudioSession.sharedInstance()
        let route = session.currentRoute
        let output = route.outputs.first
        let sampleRate = session.sampleRate
        let channels = Int(session.outputNumberOfChannels)
        let bufferFrames = Int(session.ioBufferDuration * sampleRate)
        let latency = session.outputLatency + session.ioBufferDuration
        let bitDepth = Int(metricsHistory.last?.bitDepth ?? 24)
        
        return AudioDeviceInfo(
            deviceID: output?.uid ?? "unknown",
            name: output?.portName ?? "Unknown Output",
            sampleRate: sampleRate,
            bitDepth: max(bitDepth, 16),
            channels: max(channels, 2),
            bufferSize: max(bufferFrames, 256),
            latency: latency
        )
    }
    
    func collectProfilingData() async {
        guard let profilingData = profilingData else { return }
        
        let metrics = await collectCurrentMetrics()
        let timestamp = Date()
        profilingData.cpuSamples.append(metrics.cpuUsage)
        profilingData.memorySamples.append(metrics.memoryUsage)
        profilingData.latencySamples.append(metrics.renderLatency)
        profilingData.bufferFillSamples.append(metrics.bufferFillLevel)
        profilingData.sampleTimestamps.append(timestamp)
        
        if let previousUnderruns = profilingData.lastKnownBufferUnderrunTotal {
            let delta = max(0, metrics.bufferUnderruns - previousUnderruns)
            profilingData.underrunCount += delta
        }
        profilingData.lastKnownBufferUnderrunTotal = metrics.bufferUnderruns
        
        // Keep profiling windows bounded to avoid unbounded growth (~1 minute of data at 10Hz)
        let maxSamples = 600
        if profilingData.cpuSamples.count > maxSamples {
            profilingData.cpuSamples.removeFirst(profilingData.cpuSamples.count - maxSamples)
            profilingData.memorySamples.removeFirst(profilingData.memorySamples.count - maxSamples)
            profilingData.latencySamples.removeFirst(profilingData.latencySamples.count - maxSamples)
            profilingData.bufferFillSamples.removeFirst(profilingData.bufferFillSamples.count - maxSamples)
            profilingData.sampleTimestamps.removeFirst(profilingData.sampleTimestamps.count - maxSamples)
        }
    }
    
    func finalizeProfilingData() async {
        guard let profilingData = profilingData else { return }
        
        if let start = profilingStartTime {
            profilingDuration = Date().timeIntervalSince(start)
        }
        
        // Ensure sample arrays stay aligned
        let alignedCount = min(
            profilingData.sampleTimestamps.count,
            profilingData.cpuSamples.count,
            profilingData.memorySamples.count,
            profilingData.latencySamples.count,
            profilingData.bufferFillSamples.count
        )
        if alignedCount > 0 {
            profilingData.sampleTimestamps = Array(profilingData.sampleTimestamps.suffix(alignedCount))
            profilingData.cpuSamples = Array(profilingData.cpuSamples.suffix(alignedCount))
            profilingData.memorySamples = Array(profilingData.memorySamples.suffix(alignedCount))
            profilingData.latencySamples = Array(profilingData.latencySamples.suffix(alignedCount))
            profilingData.bufferFillSamples = Array(profilingData.bufferFillSamples.suffix(alignedCount))
        }
        profilingData.lastKnownBufferUnderrunTotal = nil
        
        let durationSeconds = profilingDuration ?? 0
        logger.info("Profiling finalized with \(alignedCount) samples over \(String(format: "%.2f", durationSeconds))s")
    }
    
    func identifyBottlenecks(from profilingData: ProfilingData) async -> [PerformanceBottleneck] {
        var bottlenecks: [PerformanceBottleneck] = []
        
        let cpuAverage = profilingData.cpuProfile.averageUsage
        if cpuAverage > 65 {
            let severity: BottleneckSeverity
            switch cpuAverage {
            case 0..<75: severity = .moderate
            case 75..<85: severity = .major
            default: severity = .critical
            }
            bottlenecks.append(
                PerformanceBottleneck(
                    type: .cpu,
                    description: "Audio threads are consuming \(Int(cpuAverage))% CPU on average",
                    severity: severity,
                    impactPercentage: min(cpuAverage, 100)
                )
            )
        }
        
        let memoryPeakMB = Double(profilingData.memoryProfile.peakUsage) / 1_048_576
        if memoryPeakMB > 350 {
            let severity: BottleneckSeverity = memoryPeakMB > 600 ? .major : .moderate
            bottlenecks.append(
                PerformanceBottleneck(
                    type: .memory,
                    description: "Peak audio memory usage reached \(Int(memoryPeakMB)) MB",
                    severity: severity,
                    impactPercentage: Float(min(memoryPeakMB / 8.0 * 100.0, 100.0))
                )
            )
        }
        
        let maxLatency = profilingData.latencyProfile.maxLatency
        if maxLatency > 0.04 {
            let severity: BottleneckSeverity = maxLatency > 0.08 ? .critical : .major
            bottlenecks.append(
                PerformanceBottleneck(
                    type: .io,
                    description: "Render latency spiked to \(String(format: "%.0f", maxLatency * 1000)) ms",
                    severity: severity,
                    impactPercentage: Float(min(maxLatency * 2000, 100))
                )
            )
        }
        
        let minBufferFill = profilingData.bufferProfile.minBufferFill
        if minBufferFill < 0.35 {
            let severity: BottleneckSeverity = minBufferFill < 0.2 ? .critical : .major
            bottlenecks.append(
                PerformanceBottleneck(
                    type: .buffer,
                    description: "Buffer fill dipped to \(Int(minBufferFill * 100))%",
                    severity: severity,
                    impactPercentage: Float((1 - minBufferFill) * 100)
                )
            )
        }
        
        let thermalState = await thermalStateMonitor.getCurrentState()
        if thermalState.thermalState.isElevated {
            bottlenecks.append(
                PerformanceBottleneck(
                    type: .thermal,
                    description: "Device reported \(thermalState.thermalState.displayName) thermal conditions",
                    severity: .moderate,
                    impactPercentage: 45
                )
            )
        }
        
        func severityRank(_ severity: BottleneckSeverity) -> Int {
            switch severity {
            case .critical: return 4
            case .major: return 3
            case .moderate: return 2
            case .minor: return 1
            }
        }

        return bottlenecks
            .sorted { severityRank($0.severity) > severityRank($1.severity) }
    }
    
    func identifyOptimizationsFromProfiling(_ profilingData: ProfilingData) async -> [OptimizationOpportunity] {
        var opportunities: [OptimizationOpportunity] = []
        
        if profilingData.cpuProfile.averageUsage > 65 {
            opportunities.append(
                OptimizationOpportunity(
                    type: .resourceManagement,
                    description: "Lower decoder quality or offload visualizations to reduce CPU load",
                    expectedGain: 15,
                    complexity: .medium
                )
            )
        }
        
        let minBufferFill = profilingData.bufferProfile.minBufferFill
        if minBufferFill < 0.4 {
            opportunities.append(
                OptimizationOpportunity(
                    type: .bufferSizing,
                    description: "Increase output buffer size to protect against underruns",
                    expectedGain: Float((0.5 - minBufferFill) * 100).clamped(to: 5.0...30.0),
                    complexity: .low
                )
            )
        }
        
        let maxLatency = profilingData.latencyProfile.maxLatency
        if maxLatency > 0.05 {
            opportunities.append(
                OptimizationOpportunity(
                    type: .formatOptimization,
                    description: "Pre-decode high complexity formats or enable hardware decoding",
                    expectedGain: Float(min(maxLatency * 1200, 30)),
                    complexity: .medium
                )
            )
        }
        
        if profilingData.memoryProfile.peakUsage > 400 * 1_048_576 {
            opportunities.append(
                OptimizationOpportunity(
                    type: .resourceManagement,
                    description: "Release cached waveform data and purge inactive buffers",
                    expectedGain: 10,
                    complexity: .low
                )
            )
        }
        
        return opportunities
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
    
    // MARK: - Analysis
    func analyzePerformanceTrends() async -> PerformanceTrendSummary {
        let window = recentMetrics(window: 120)
        guard !window.isEmpty else {
            return PerformanceTrendSummary(
                cpuTrend: TrendIndicator(currentValue: 0, changePercent: 0, direction: .stable, stability: .stable),
                memoryTrend: TrendIndicator(currentValue: 0, changePercent: 0, direction: .stable, stability: .stable),
                latencyTrend: TrendIndicator(currentValue: 0, changePercent: 0, direction: .stable, stability: .stable),
                qualityTrend: TrendIndicator(currentValue: 0, changePercent: 0, direction: .stable, stability: .stable),
                bufferTrend: TrendIndicator(currentValue: 0, changePercent: 0, direction: .stable, stability: .stable),
                overallTrend: .stable
            )
        }
        
        let cpuTrend = buildTrend(from: window.map { Double($0.cpuUsage) }, higherIsBetter: false)
        let memoryTrend = buildTrend(from: window.map { Double($0.memoryUsage) / 1_048_576 }, higherIsBetter: false)
        let latencyTrend = buildTrend(from: window.map { Double($0.renderLatency * 1000) }, higherIsBetter: false)
        let qualityTrend = buildTrend(from: window.map { Double($0.qualityScore * 100) }, higherIsBetter: true)
        let bufferTrend = buildTrend(from: window.map { Double($0.bufferFillLevel * 100) }, higherIsBetter: true)
        
        let overallTrend = deriveOverallTrend([cpuTrend, memoryTrend, latencyTrend, qualityTrend, bufferTrend])
        
        return PerformanceTrendSummary(
            cpuTrend: cpuTrend,
            memoryTrend: memoryTrend,
            latencyTrend: latencyTrend,
            qualityTrend: qualityTrend,
            bufferTrend: bufferTrend,
            overallTrend: overallTrend
        )
    }
    
    func analyzeResourceUtilization() async -> ResourceUtilizationSummary {
        let window = recentMetrics(window: 180)
        guard let latest = window.last else {
            return ResourceUtilizationSummary(
                cpuUtilization: ResourceUsageAnalysis(currentUsage: 0, averageUsage: 0, peakUsage: 0, efficiencyScore: 1.0, classification: .minimal),
                memoryUtilization: ResourceUsageAnalysis(currentUsage: 0, averageUsage: 0, peakUsage: 0, efficiencyScore: 1.0, classification: .minimal),
                batteryUtilization: ResourceUsageAnalysis(currentUsage: 0, averageUsage: 0, peakUsage: 0, efficiencyScore: 1.0, classification: .minimal),
                networkUtilization: ResourceUsageAnalysis(currentUsage: 0, averageUsage: 0, peakUsage: 0, efficiencyScore: 1.0, classification: .minimal),
                overallEfficiency: .excellent
            )
        }
        
        let cpuValues = window.map { Double($0.cpuUsage) }
        let memoryValues = window.map { Double($0.memoryUsage) / 1_048_576 }
        let networkValues = window.map { Double($0.networkBandwidth) / 1_000_000 }
        let batteryValues = window.compactMap { $0.batteryUsageRate.map(Double.init) }
        
        let cpuAnalysis = ResourceUsageAnalysis(
            currentUsage: Double(latest.cpuUsage),
            averageUsage: average(of: cpuValues),
            peakUsage: cpuValues.max() ?? Double(latest.cpuUsage),
            efficiencyScore: (1.0 - average(of: cpuValues) / 100).clamped(to: 0...1),
            classification: classifyCPUUsage(Double(latest.cpuUsage))
        )
        
        let memoryAnalysis = ResourceUsageAnalysis(
            currentUsage: Double(latest.memoryUsage) / 1_048_576,
            averageUsage: average(of: memoryValues),
            peakUsage: memoryValues.max() ?? Double(latest.memoryUsage) / 1_048_576,
            efficiencyScore: (1.0 - average(of: memoryValues) / 512).clamped(to: 0...1),
            classification: classifyMemoryUsage(Double(latest.memoryUsage) / 1_048_576)
        )
        
        let batteryCurrent = batteryValues.last ?? Double(latest.batteryUsageRate ?? 0)
        let batteryAverage = batteryValues.isEmpty ? batteryCurrent : average(of: batteryValues)
        let batteryPeak = batteryValues.max() ?? batteryCurrent
        let batteryAnalysis = ResourceUsageAnalysis(
            currentUsage: batteryCurrent,
            averageUsage: batteryAverage,
            peakUsage: batteryPeak,
            efficiencyScore: (1.0 - batteryAverage / 350).clamped(to: 0...1),
            classification: classifyBatteryUsage(batteryCurrent)
        )
        
        let networkAnalysis = ResourceUsageAnalysis(
            currentUsage: networkValues.last ?? Double(latest.networkBandwidth) / 1_000_000,
            averageUsage: average(of: networkValues),
            peakUsage: networkValues.max() ?? Double(latest.networkBandwidth) / 1_000_000,
            efficiencyScore: (1.0 - average(of: networkValues) / 15).clamped(to: 0...1),
            classification: classifyNetworkUsage(networkValues.last ?? Double(latest.networkBandwidth) / 1_000_000)
        )
        
        let efficiencySamples = window.map { Double($0.efficiencyScore) }
        let overallScore = efficiencySamples.isEmpty ? (cpuAnalysis.efficiencyScore + batteryAnalysis.efficiencyScore) / 2 : average(of: efficiencySamples)
        let overallRating: EfficiencyRating
        switch overallScore {
        case 0.85...: overallRating = .excellent
        case 0.7..<0.85: overallRating = .good
        case 0.5..<0.7: overallRating = .fair
        default: overallRating = .poor
        }
        
        return ResourceUtilizationSummary(
            cpuUtilization: cpuAnalysis,
            memoryUtilization: memoryAnalysis,
            batteryUtilization: batteryAnalysis,
            networkUtilization: networkAnalysis,
            overallEfficiency: overallRating
        )
    }
    
    func assessAudioQuality() async -> QualityAssessmentSummary {
        let window = recentMetrics(window: 120)
        guard let latest = window.last else {
            return QualityAssessmentSummary(
                qualityScore: 0,
                bitPerfectStatus: .unavailable,
                signalIntegrity: SignalIntegrityAssessment(
                    integrityScore: 0,
                    issues: [],
                    pathAnalysis: "No playback metrics available",
                    jitterLevel: .minimal
                ),
                qualityIssues: [],
                improvements: []
            )
        }
        
        let qualityScores = window.map { Double($0.qualityScore) }
        let qualityScore = Int((average(of: qualityScores) * 100).clamped(to: 0...100))
        
        let bitPerfectStatus: BitPerfectStatus
        if latest.isBitPerfect {
            bitPerfectStatus = .active
        } else if window.contains(where: { $0.isBitPerfect }) {
            bitPerfectStatus = .available
        } else if latest.audioFormat.lowercased().contains("lossless") {
            bitPerfectStatus = .limited
        } else {
            bitPerfectStatus = .unavailable
        }
        
        let snrValues = window.compactMap { $0.estimatedSNR.map(Double.init) }
        let dynamicRangeValues = window.compactMap { $0.dynamicRange.map(Double.init) }
        let jitterValues = window.map { Double($0.jitter) }
        let glitchTotal = window.reduce(0) { $0 + $1.glitchCount }
        
        let averageSNR = average(of: snrValues)
        let averageDynamicRange = average(of: dynamicRangeValues)
        let averageJitter = average(of: jitterValues)
        
        var signalIssues: Set<SignalIssue> = []
        if averageSNR > 0 && averageSNR < 80 { signalIssues.insert(.noise) }
        if averageDynamicRange > 0 && averageDynamicRange < 65 { signalIssues.insert(.distortion) }
        if averageJitter > 0.004 { signalIssues.insert(.jitter) }
        if glitchTotal > 0 { signalIssues.insert(.dropout) }
        
        let integrityScore = computeIntegrityScore(snr: averageSNR, dynamicRange: averageDynamicRange, jitter: averageJitter, glitches: glitchTotal)
        let jitterLevel = jitterLevel(for: averageJitter)
        let pathAnalysis = buildPathAnalysis(signalIssues: Array(signalIssues), bitPerfectActive: latest.isBitPerfect)
        
        var qualityIssues: [QualityIssue] = []
        if !signalIssues.isEmpty {
            if signalIssues.contains(.noise), averageSNR > 0 {
                qualityIssues.append(
                    QualityIssue(
                        type: .device,
                        description: "Average SNR measured \(Int(averageSNR)) dB, introducing audible noise floor.",
                        impact: .significant,
                        resolution: "Use an external DAC or reduce analog volume to improve signal-to-noise ratio."
                    )
                )
            }
            if signalIssues.contains(.distortion), averageDynamicRange > 0 {
                qualityIssues.append(
                    QualityIssue(
                        type: .processing,
                        description: "Dynamic range collapsed to \(Int(averageDynamicRange)) dB during playback.",
                        impact: .significant,
                        resolution: "Disable loudness normalization or replay gain during high fidelity sessions."
                    )
                )
            }
            if signalIssues.contains(.jitter) {
                qualityIssues.append(
                    QualityIssue(
                        type: .device,
                        description: "Digital jitter averaged \(String(format: "%.3f", averageJitter * 1_000)) ms across the session.",
                        impact: .moderate,
                        resolution: "Use wired output or a reclocking DAC to minimize transport jitter."
                    )
                )
            }
            if signalIssues.contains(.dropout) {
                qualityIssues.append(
                    QualityIssue(
                        type: .processing,
                        description: "Detected \(glitchTotal) glitch events while rendering audio.",
                        impact: .moderate,
                        resolution: "Increase buffer size or reduce background decoding load to eliminate dropouts."
                    )
                )
            }
        }
        
        if bitPerfectStatus != .active {
            qualityIssues.append(
                QualityIssue(
                    type: .format,
                    description: "Bit-perfect playback is not active; output is routed through the system mixer.",
                    impact: .moderate,
                    resolution: "Enable Bit-Perfect playback in Settings to bypass CoreAudio resampling."
                )
            )
        }
        
        var improvements: [QualityImprovement] = []
        if bitPerfectStatus != .active {
            improvements.append(
                QualityImprovement(
                    title: "Enable Bit-Perfect Output",
                    description: "Activating bit-perfect mode avoids CoreAudio resampling for lossless formats.",
                    expectedGain: 8,
                    difficulty: .easy
                )
            )
        }
        if signalIssues.contains(.jitter) {
            improvements.append(
                QualityImprovement(
                    title: "Stabilize Digital Clock",
                    description: "Use a wired USB DAC or reduce wireless interference to minimize transport jitter.",
                    expectedGain: 6,
                    difficulty: .moderate
                )
            )
        }
        if signalIssues.contains(.noise) {
            improvements.append(
                QualityImprovement(
                    title: "Improve Signal-to-Noise",
                    description: "Lower analog gain and avoid stacked pre-amps to reduce the noise floor.",
                    expectedGain: 5,
                    difficulty: .easy
                )
            )
        }
        
        return QualityAssessmentSummary(
            qualityScore: qualityScore,
            bitPerfectStatus: bitPerfectStatus,
            signalIntegrity: SignalIntegrityAssessment(
                integrityScore: Int(integrityScore.clamped(to: 0...100)),
                issues: Array(signalIssues),
                pathAnalysis: pathAnalysis,
                jitterLevel: jitterLevel
            ),
            qualityIssues: qualityIssues,
            improvements: improvements
        )
    }
    
    func analyzeEfficiency() async -> EfficiencyAnalysisSummary {
        let window = recentMetrics(window: 180)
        guard !window.isEmpty else {
            return EfficiencyAnalysisSummary(
                efficiencyScore: 100,
                powerEfficiency: .excellent,
                performanceEfficiency: .excellent,
                optimizationOpportunities: []
            )
        }
        
        let efficiencyValues = window.map { Double($0.efficiencyScore) }
        let efficiencyScore = Int((average(of: efficiencyValues) * 100).clamped(to: 0...100))
        
        let cpuAverage = average(of: window.map { Double($0.cpuUsage) })
        let batteryAverage = average(of: window.compactMap { $0.batteryUsageRate.map(Double.init) })
        
        let performanceRating = efficiencyRating(forCPU: cpuAverage)
        let powerRating = efficiencyRating(forBattery: batteryAverage)
        
        var optimizations: [EfficiencyOptimization] = []
        if cpuAverage > 65 {
            optimizations.append(
                EfficiencyOptimization(
                    title: "Reduce Decoder Load",
                    expectedGain: 12,
                    resourceImpact: "CPU usage -12%",
                    steps: [
                        "Disable real-time waveform visualizations",
                        "Prefer hardware-accelerated decoders for ALAC/FLAC"
                    ]
                )
            )
        }
        if batteryAverage > 200 {
            optimizations.append(
                EfficiencyOptimization(
                    title: "Enable Low Power Audio Mode",
                    expectedGain: 10,
                    resourceImpact: "Battery drain -10%",
                    steps: [
                        "Reduce background refresh interval to 30s",
                        "Lower particle effects intensity in Now Playing"
                    ]
                )
            )
        }
        let networkAverage = average(of: window.map { Double($0.networkBandwidth) / 1_000_000 })
        if networkAverage > 5 {
            optimizations.append(
                EfficiencyOptimization(
                    title: "Prefetch Lossless Tracks",
                    expectedGain: 7,
                    resourceImpact: "Network spikes -40%",
                    steps: [
                        "Cache playlists before playback for offline sessions",
                        "Disable Hi-Res streaming on cellular"
                    ]
                )
            )
        }
        
        return EfficiencyAnalysisSummary(
            efficiencyScore: efficiencyScore,
            powerEfficiency: powerRating,
            performanceEfficiency: performanceRating,
            optimizationOpportunities: optimizations
        )
    }
    
    func identifyActiveIssues() async -> [DiagnosticIssue] {
        var issues: [DiagnosticIssue] = []
        let recentAlerts = alertHistory.suffix(10)
        var seenKeys = Set<String>()
        
        for alert in recentAlerts {
            let severity = issueSeverity(for: alert.severity)
            let type = diagnosticIssueType(for: alert.type)
            let key = "\(alert.type.rawValue)_\(severity.rawValue)"
            if seenKeys.contains(key) { continue }
            seenKeys.insert(key)
            let resolution = alert.suggestedActions.first ?? defaultResolution(for: alert.type)
            issues.append(
                DiagnosticIssue(
                    type: type,
                    severity: severity,
                    title: alert.type.displayName,
                    description: alert.message,
                    technicalDetails: alert.technicalDetails,
                    resolution: resolution,
                    canAutoResolve: alert.type == .lowBufferFill || alert.type == .bufferUnderrun,
                    firstDetected: alert.timestamp
                )
            )
        }
        
        if let latest = metricsHistory.last {
            if latest.cpuUsage > 85 && !seenKeys.contains("cpu_usage_major") {
                issues.append(
                    DiagnosticIssue(
                        type: .performance,
                        severity: .major,
                        title: "Sustained high CPU",
                        description: "Audio pipeline is consuming \(Int(latest.cpuUsage))% CPU",
                        technicalDetails: "Thread utilization: audio=\(String(format: "%.1f", latest.threadUtilization.audioThreadCPU))%",
                        resolution: "Disable visual effects or lower upsampling quality to reduce decoder load.",
                        canAutoResolve: false,
                        firstDetected: Date()
                    )
                )
            }
            if latest.bufferFillLevel < 0.3 && !seenKeys.contains("low_buffer_fill_minor") {
                issues.append(
                    DiagnosticIssue(
                        type: .performance,
                        severity: .moderate,
                        title: "Buffer at risk",
                        description: "Output buffer fell to \(Int(latest.bufferFillLevel * 100))%",
                        technicalDetails: "Underrun rate: \(String(format: "%.2f", latest.underrunRate)) events/min",
                        resolution: "Increase output buffer duration in Settings > Audio > Advanced.",
                        canAutoResolve: true,
                        firstDetected: Date()
                    )
                )
            }
        }
        
        return issues
    }
    
    func generateRecommendations() async -> [PerformanceRecommendation] {
        var recommendations: [PerformanceRecommendation] = []
        if let latest = metricsHistory.last {
            if latest.cpuUsage > 75 {
                recommendations.append(
                    PerformanceRecommendation(
                        type: .performanceModeAdjustment,
                        priority: .high,
                        title: "Enable Performance Mode",
                        description: "CPU usage averaged \(Int(latest.cpuUsage))%. Enable performance mode to prioritize audio threads.",
                        expectedImprovement: "CPU spikes reduced by ~15%",
                        technicalDetails: "Activates AVAudioSessionModeVideoRecording and raises audio thread QoS.",
                        canAutoApply: false
                    )
                )
            }
            if latest.bufferFillLevel < 0.35 {
                recommendations.append(
                    PerformanceRecommendation(
                        type: .audioSessionConfiguration,
                        priority: .medium,
                        title: "Increase IO Buffer Duration",
                        description: "Buffer fill dropped to \(Int(latest.bufferFillLevel * 100))%. Increasing IO buffer provides more headroom.",
                        expectedImprovement: "Underruns reduced by up to 60%",
                        technicalDetails: "Set AVAudioSession.ioBufferDuration to 0.012s when using high resolution content.",
                        canAutoApply: true
                    )
                )
            }
            if latest.jitter > 0.004 {
                recommendations.append(
                    PerformanceRecommendation(
                        type: .engineSelection,
                        priority: .medium,
                        title: "Use Wired Output",
                        description: "Detected jitter of \(String(format: "%.3f", latest.jitter * 1_000)) ms. Wired output stabilizes the master clock.",
                        expectedImprovement: "Jitter floor reduced by ~40%",
                        technicalDetails: "Switch to USB or Lightning DAC for critical listening sessions.",
                        canAutoApply: false
                    )
                )
            }
            if !latest.isBitPerfect {
                recommendations.append(
                    PerformanceRecommendation(
                        type: .formatOptimization,
                        priority: .medium,
                        title: "Review Output Format",
                        description: "Bit-perfect playback is disabled. Matching output sample rate avoids SRC artifacts.",
                        expectedImprovement: "Quality score +5",
                        technicalDetails: "Align AVAudioSession sample rate with source (\(Int(latest.sampleRate)) Hz).",
                        canAutoApply: false
                    )
                )
            }
        }
        
        if recommendations.isEmpty {
            recommendations.append(
                PerformanceRecommendation(
                    type: .backgroundAppManagement,
                    priority: .low,
                    title: "Maintain Current Configuration",
                    description: "No critical issues detected during the monitoring window.",
                    expectedImprovement: "N/A",
                    technicalDetails: "Continue monitoring if workload changes.",
                    canAutoApply: false
                )
            )
        }
        
        return recommendations
    }
    
    func identifyOptimizations() async -> [OptimizationOpportunity] {
        var opportunities: [OptimizationOpportunity] = []
        if let profilingData = profilingData {
            opportunities.append(contentsOf: await identifyOptimizationsFromProfiling(profilingData))
        }
        if let latest = metricsHistory.last {
            if Double(latest.memoryUsage) / 1_048_576 > 450 {
                opportunities.append(
                    OptimizationOpportunity(
                        type: .resourceManagement,
                        description: "Unload inactive visualizers to reclaim \(Int(Double(latest.memoryUsage) / 1_048_576 - 450)) MB",
                        expectedGain: 12,
                        complexity: .medium
                    )
                )
            }
            if Double(latest.networkBandwidth) / 1_000_000 > 8 {
                opportunities.append(
                    OptimizationOpportunity(
                        type: .formatOptimization,
                        description: "Transcode cached radio streams to AAC 256 for lower bandwidth during roaming",
                        expectedGain: 9,
                        complexity: .medium
                    )
                )
            }
        }
        return opportunities
    }
    
    func createSessionStatistics() async -> SessionStatisticsSummary {
        let summary = await getSessionSummary()
        let durationHours = max(summary.duration / 3600, 0.1)
        let errorRate = Double(summary.totalAlerts) / durationHours
        let bufferUnderruns = alertHistory.filter { $0.type == .bufferUnderrun || $0.type == .lowBufferFill }.count
        let qualityDrops = metricsHistory.filter { $0.qualityScore < 0.85 }.count
        let recoverySuccess = metricsHistory.isEmpty ? 1.0 : Double(metricsHistory.last?.recoverySuccessRate ?? 1.0)
        
        return SessionStatisticsSummary(
            totalUptime: summary.duration,
            averagePerformanceScore: summary.performanceScore,
            totalAlerts: summary.totalAlerts,
            errorRate: errorRate,
            bufferUnderrunIncidents: bufferUnderruns,
            qualityDropCount: qualityDrops,
            recoverySuccessRate: recoverySuccess
        )
    }
    
    func createErrorHistory() async -> ErrorHistorySummary {
        let alerts = alertHistory
        let totalErrors = alerts.count
        let errorsByCategory = Dictionary(grouping: alerts) { errorCategory(for: $0.type) }
            .mapValues { $0.count }
        let mostRecentError = alerts.last.map { alert -> DiagnosticError in
            DiagnosticError(
                code: alert.type.rawValue.uppercased(),
                category: errorCategory(for: alert.type),
                description: alert.message,
                timestamp: alert.timestamp,
                recoveryAttempted: alert.suggestedActions.contains { $0.lowercased().contains("retry") },
                recoverySuccessful: (metricsHistory.last?.recoverySuccessRate ?? 1) > 0.9
            )
        }
        let mostCommonCategory = errorsByCategory.max(by: { $0.value < $1.value })?.key
        let trend = errorTrend(for: alerts)
        
        return ErrorHistorySummary(
            totalErrors: totalErrors,
            errorsByCategory: errorsByCategory,
            mostRecentError: mostRecentError,
            mostCommonErrorType: mostCommonCategory,
            errorFrequencyTrend: trend
        )
    }
    
    func identifyMilestones() async -> [PerformanceMilestone] {
        var milestones: [PerformanceMilestone] = []
        let now = Date()
        if let start = sessionStartTime {
            let uptime = now.timeIntervalSince(start)
            milestones.append(
                PerformanceMilestone(
                    type: .uptime,
                    achievedAt: now,
                    description: "Monitoring active for \(String(format: "%.1f", uptime / 3600)) hours",
                    value: uptime
                )
            )
        }
        if let peakQuality = metricsHistory.map({ Double($0.qualityScore) }).max(), peakQuality > 0.95 {
            milestones.append(
                PerformanceMilestone(
                    type: .quality,
                    achievedAt: now,
                    description: "Peak quality score \(Int(peakQuality * 100))",
                    value: peakQuality
                )
            )
        }
        let efficiencyValues = metricsHistory.map { Double($0.efficiencyScore) }
        let efficiencyAverage = average(of: efficiencyValues)
        if efficiencyAverage > 0.9 {
            milestones.append(
                PerformanceMilestone(
                    type: .efficiency,
                    achievedAt: now,
                    description: "Efficiency sustained above 90%",
                    value: efficiencyAverage
                )
            )
        }
        if alertHistory.isEmpty || alertHistory.filter({ now.timeIntervalSince($0.timestamp) < 1800 }).isEmpty {
            milestones.append(
                PerformanceMilestone(
                    type: .stability,
                    achievedAt: now,
                    description: "No alerts recorded in the last 30 minutes",
                    value: 1800
                )
            )
        }
        return milestones
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
        let sessionInfo = await collectSessionInfo()
        let deviceInfo = await collectDeviceInfo()
        let thermalInfo = await thermalStateMonitor.getCurrentState()
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let deviceIdentifier = currentDeviceIdentifier()
        let architecture = currentArchitecture()
        let availableMemory = Int64(ProcessInfo.processInfo.physicalMemory)
        
        let bufferAverage = metricsHistory.isEmpty ? 1.0 : Double(metricsHistory.map { $0.bufferFillLevel }.reduce(0, +)) / Double(metricsHistory.count)
        let bufferMinimum = metricsHistory.map { Double($0.bufferFillLevel) }.min() ?? 1.0
        
        let audioStackInfo = AudioStackDebugInfo(
            activeAudioUnits: _currentEngine.map { [String(describing: type(of: $0))] } ?? [],
            sessionDetails: [
                "category": sessionInfo.category,
                "mode": sessionInfo.mode,
                "options": sessionInfo.options.joined(separator: ",")
            ],
            engineConfiguration: [
                "updateInterval": updateInterval,
                "profiling": _isProfiling,
                "metricsSamples": metricsHistory.count
            ].mapValues { String(describing: $0) },
            bufferInfo: BufferDebugInfo(
                bufferSizes: [
                    "ioBufferFrames": Int(sessionInfo.ioBufferDuration * sessionInfo.sampleRate),
                    "deviceFrames": deviceInfo.bufferSize
                ],
                bufferUtilization: [
                    "average": Float(bufferAverage),
                    "minimum": Float(bufferMinimum)
                ],
                allocationHistory: []
            )
        )
        
        let debugFlags: [String: String] = [
            "monitoring": String(_isMonitoring),
            "profiling": String(_isProfiling),
            "alerts": String(alertHistory.count)
        ]
        
        return DebugInformation(
            sessionID: UUID().uuidString,
            systemInfo: SystemDebugInfo(
                deviceIdentifier: deviceIdentifier,
                systemVersion: systemVersion,
                availableMemory: availableMemory,
                cpuArchitecture: architecture,
                thermalState: thermalInfo.thermalState.rawValue
            ),
            audioStackInfo: audioStackInfo,
            performanceCounters: performanceCounters,
            debugFlags: debugFlags.reduce(into: [:]) { $0[$1.key] = $1.value == "true" }
        )
    }
    
    func collectRecentLogEntries() async -> [DiagnosticLogEntry] {
        var entries: [DiagnosticLogEntry] = []
        for alert in alertHistory.suffix(10) {
            let level: LogLevel
            switch alert.severity {
            case .low: level = .warning
            case .medium: level = .warning
            case .high: level = .error
            case .critical: level = .critical
            }
            let context = alert.triggerValues.mapValues { String(format: "%.2f", $0) }
            entries.append(
                DiagnosticLogEntry(
                    timestamp: alert.timestamp,
                    level: level,
                    category: alert.type.rawValue,
                    message: alert.message,
                    context: context
                )
            )
        }
        for metric in metricsHistory.suffix(5) {
            let context: [String: String] = [
                "cpu": String(format: "%.1f", metric.cpuUsage),
                "memoryMB": String(format: "%.0f", Double(metric.memoryUsage) / 1_048_576),
                "latencyMs": String(format: "%.2f", metric.renderLatency * 1000),
                "buffer": String(format: "%.1f", metric.bufferFillLevel * 100)
            ]
            entries.append(
                DiagnosticLogEntry(
                    timestamp: metric.timestamp,
                    level: .info,
                    category: "metrics",
                    message: "Metrics snapshot",
                    context: context
                )
            )
        }
        return entries.sorted { $0.timestamp < $1.timestamp }
    }
    
    func createConfigurationDump() async -> ConfigurationDump {
        let sessionInfo = await collectSessionInfo()
        let deviceInfo = await collectDeviceInfo()
        let systemVersion = ProcessInfo.processInfo.operatingSystemVersionString
        let deviceIdentifier = currentDeviceIdentifier()
        
        let engineConfig = [
            "updateInterval": String(format: "%.2f", updateInterval),
            "profiling": String(_isProfiling),
            "metricsSamples": String(metricsHistory.count)
        ]
        let sessionConfig = [
            "category": sessionInfo.category,
            "mode": sessionInfo.mode,
            "options": sessionInfo.options.joined(separator: ","),
            "sampleRate": String(format: "%.0f", sessionInfo.sampleRate),
            "ioBufferDuration": String(format: "%.4f", sessionInfo.ioBufferDuration)
        ]
        let deviceConfig = [
            "name": deviceInfo.name,
            "sampleRate": String(format: "%.0f", deviceInfo.sampleRate),
            "bitDepth": String(deviceInfo.bitDepth),
            "channels": String(deviceInfo.channels),
            "bufferSize": String(deviceInfo.bufferSize)
        ]
        let defaults = UserDefaults.standard
        let userPreferences = [
            "volume": String(format: "%.2f", defaults.double(forKey: "volume")),
            "isShuffleEnabled": String(defaults.bool(forKey: "isShuffleEnabled")),
            "repeatMode": defaults.string(forKey: "repeatMode") ?? "none"
        ]
        let systemSettings = [
            "osVersion": systemVersion,
            "device": deviceIdentifier
        ]
        
        return ConfigurationDump(
            engineConfig: engineConfig,
            sessionConfig: sessionConfig,
            deviceConfig: deviceConfig,
            userPreferences: userPreferences,
            systemSettings: systemSettings
        )
    }
    
    // Export methods
    func exportAsJSON(_ metrics: [AudioMetrics]) async -> Data {
        let payload = metrics.map(EncodedMetric.init)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted]
        encoder.dateEncodingStrategy = .iso8601
        return (try? encoder.encode(payload)) ?? Data()
    }
    
    func exportAsCSV(_ metrics: [AudioMetrics]) async -> Data {
        var rows = ["timestamp,cpuUsage,memoryUsageMB,bufferFill,renderLatencyMs,performanceScore,qualityScore,isBitPerfect"]
        let formatter = ISO8601DateFormatter()
        for metric in metrics {
            let memoryMB = Double(metric.memoryUsage) / 1_048_576
            let row = "\(formatter.string(from: metric.timestamp)),\(String(format: "%.1f", metric.cpuUsage)),\(String(format: "%.0f", memoryMB)),\(String(format: "%.2f", metric.bufferFillLevel)),\(String(format: "%.3f", metric.renderLatency * 1000)),\(String(format: "%.2f", metric.performanceScore)),\(String(format: "%.2f", metric.qualityScore)),\(metric.isBitPerfect)"
            rows.append(row)
        }
        return rows.joined(separator: "\n").data(using: .utf8) ?? Data()
    }
    
    func exportAsXML(_ metrics: [AudioMetrics]) async -> Data {
        let formatter = ISO8601DateFormatter()
        var xml = "<metrics>\n"
        for metric in metrics {
            xml += "  <metric timestamp=\"\(formatter.string(from: metric.timestamp))\">\n"
            xml += "    <cpuUsage>\(String(format: "%.1f", metric.cpuUsage))</cpuUsage>\n"
            xml += "    <memoryUsageMB>\(String(format: "%.0f", Double(metric.memoryUsage) / 1_048_576))</memoryUsageMB>\n"
            xml += "    <bufferFill>\(String(format: "%.2f", metric.bufferFillLevel))</bufferFill>\n"
            xml += "    <renderLatencyMs>\(String(format: "%.3f", metric.renderLatency * 1000))</renderLatencyMs>\n"
            xml += "    <performanceScore>\(String(format: "%.2f", metric.performanceScore))</performanceScore>\n"
            xml += "    <qualityScore>\(String(format: "%.2f", metric.qualityScore))</qualityScore>\n"
            xml += "    <bitPerfect>\(metric.isBitPerfect)</bitPerfect>\n"
            xml += "  </metric>\n"
        }
        xml += "</metrics>"
        return xml.data(using: .utf8) ?? Data()
    }
    
    func exportAsBinary(_ metrics: [AudioMetrics]) async -> Data {
        let payload = metrics.map(EncodedMetric.init)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return (try? encoder.encode(payload)) ?? Data()
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
        guard metrics.count >= 2 else { return [] }
        let cpuIndicator = buildTrend(from: metrics.map { Double($0.cpuUsage) }, higherIsBetter: false)
        let memoryIndicator = buildTrend(from: metrics.map { Double($0.memoryUsage) / 1_048_576 }, higherIsBetter: false)
        let latencyIndicator = buildTrend(from: metrics.map { Double($0.renderLatency * 1000) }, higherIsBetter: false)
        let qualityIndicator = buildTrend(from: metrics.map { Double($0.qualityScore * 100) }, higherIsBetter: true)
        let bufferIndicator = buildTrend(from: metrics.map { Double($0.bufferFillLevel * 100) }, higherIsBetter: true)
        
        let trends = [
            makePerformanceTrend(label: "CPU Usage", indicator: cpuIndicator, higherIsBetter: false),
            makePerformanceTrend(label: "Memory Usage", indicator: memoryIndicator, higherIsBetter: false),
            makePerformanceTrend(label: "Render Latency", indicator: latencyIndicator, higherIsBetter: false),
            makePerformanceTrend(label: "Quality Score", indicator: qualityIndicator, higherIsBetter: true),
            makePerformanceTrend(label: "Buffer Fill", indicator: bufferIndicator, higherIsBetter: true)
        ]
        
        return trends.filter { abs($0.magnitude) >= 1 || $0.direction != .stable }
    }
    
    private func average(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }
    
    private func standardDeviation(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = average(of: values)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance)
    }
    
    private func buildTrend(from values: [Double], higherIsBetter: Bool) -> TrendIndicator {
        guard !values.isEmpty else {
            return TrendIndicator(currentValue: 0, changePercent: 0, direction: .stable, stability: .stable)
        }
        let current = values.last ?? 0
        let historical = Array(values.dropLast())
        let baseline = historical.isEmpty ? current : average(of: historical)
        let delta = current - baseline
        let changePercent = baseline == 0 ? 0 : (delta / abs(baseline)) * 100
        let stability = trendStability(for: values)
        let direction: TrendDirection
        if stability == .volatile {
            direction = .volatile
        } else {
            let threshold = higherIsBetter ? 1.5 : 1.5
            if higherIsBetter {
                if changePercent > threshold { direction = .improving }
                else if changePercent < -threshold { direction = .degrading }
                else { direction = .stable }
            } else {
                if changePercent < -threshold { direction = .improving }
                else if changePercent > threshold { direction = .degrading }
                else { direction = .stable }
            }
        }
        return TrendIndicator(currentValue: current, changePercent: changePercent, direction: direction, stability: stability)
    }
    
    private func makePerformanceTrend(label: String, indicator: TrendIndicator, higherIsBetter: Bool) -> PerformanceTrend {
        let magnitude = abs(indicator.changePercent)
        let significance: TrendSignificance
        switch magnitude {
        case 0..<2: significance = .low
        case 2..<5: significance = .medium
        case 5..<10: significance = .high
        default: significance = .veryHigh
        }
        let description = "\(label): \(String(format: "%.1f", indicator.currentValue)) (\(String(format: "%.1f", indicator.changePercent))%)"
        return PerformanceTrend(metric: label, direction: indicator.direction, magnitude: magnitude, significance: significance, description: description)
    }
    
    private func trendStability(for values: [Double]) -> TrendStability {
        guard !values.isEmpty else { return .stable }
        let mean = average(of: values.map { abs($0) })
        let deviation = standardDeviation(of: values)
        let ratio = mean == 0 ? deviation : deviation / (mean + 1)
        switch ratio {
        case ..<0.05: return .stable
        case ..<0.15: return .fluctuating
        default: return .volatile
        }
    }
    
    private func deriveOverallTrend(_ indicators: [TrendIndicator]) -> TrendDirection {
        if indicators.contains(where: { $0.direction == .volatile }) {
            return .volatile
        }
        let score = indicators.reduce(0.0) { partial, indicator -> Double in
            switch indicator.direction {
            case .improving: return partial + 1
            case .degrading: return partial - 1
            case .volatile: return partial
            case .stable: return partial
            }
        } / Double(max(indicators.count, 1))
        if score > 0.3 { return .improving }
        if score < -0.3 { return .degrading }
        return .stable
    }
    
    private func classifyCPUUsage(_ value: Double) -> UsageClassification {
        switch value {
        case ..<5: return .minimal
        case ..<25: return .low
        case ..<50: return .moderate
        case ..<75: return .high
        default: return .excessive
        }
    }
    
    private func classifyMemoryUsage(_ value: Double) -> UsageClassification {
        switch value {
        case ..<128: return .minimal
        case ..<256: return .low
        case ..<512: return .moderate
        case ..<768: return .high
        default: return .excessive
        }
    }
    
    private func classifyBatteryUsage(_ value: Double) -> UsageClassification {
        switch value {
        case ..<40: return .minimal
        case ..<120: return .low
        case ..<200: return .moderate
        case ..<320: return .high
        default: return .excessive
        }
    }
    
    private func classifyNetworkUsage(_ value: Double) -> UsageClassification {
        switch value {
        case ..<0.5: return .minimal
        case ..<2: return .low
        case ..<5: return .moderate
        case ..<10: return .high
        default: return .excessive
        }
    }
    
    private func efficiencyRating(forCPU value: Double) -> EfficiencyRating {
        switch value {
        case ..<35: return .excellent
        case ..<55: return .good
        case ..<75: return .fair
        default: return .poor
        }
    }
    
    private func efficiencyRating(forBattery value: Double) -> EfficiencyRating {
        switch value {
        case ..<50: return .excellent
        case ..<140: return .good
        case ..<220: return .fair
        default: return .poor
        }
    }
    
    private func issueSeverity(for severity: AlertSeverity) -> IssueSeverity {
        switch severity {
        case .low: return .minor
        case .medium: return .moderate
        case .high: return .major
        case .critical: return .critical
        }
    }
    
    private func diagnosticIssueType(for type: AlertType) -> DiagnosticIssueType {
        switch type {
        case .bufferUnderrun, .lowBufferFill, .highCPUUsage, .highMemoryUsage, .latencySpike:
            return .performance
        case .thermalThrottling:
            return .hardware
        case .audioInterruption:
            return .configuration
        case .formatMismatch:
            return .compatibility
        case .engineError:
            return .software
        case .audioDropout:
            return .performance
        }
    }
    
    private func defaultResolution(for type: AlertType) -> String {
        switch type {
        case .bufferUnderrun, .lowBufferFill:
            return "Increase IO buffer duration or reduce decoder complexity."
        case .highCPUUsage:
            return "Lower visualization intensity or disable background decoding."
        case .highMemoryUsage:
            return "Purge waveform caches and reload library assets on demand."
        case .latencySpike:
            return "Preload tracks and keep device thermals in nominal range."
        case .thermalThrottling:
            return "Pause playback briefly and move device to a cooler environment."
        case .audioInterruption:
            return "Resume playback after interruption ended and re-activate session."
        case .formatMismatch:
            return "Convert the track to a supported output format before playback."
        case .engineError:
            return "Reset the audio engine and reload the active track."
        case .audioDropout:
            return "Increase buffering or switch to offline playback."
        }
    }
    
    private func errorCategory(for type: AlertType) -> ErrorCategory {
        switch type {
        case .bufferUnderrun, .lowBufferFill:
            return .buffer
        case .highCPUUsage, .highMemoryUsage, .engineError:
            return .decoding
        case .latencySpike, .audioDropout:
            return .network
        case .thermalThrottling:
            return .device
        case .audioInterruption:
            return .session
        case .formatMismatch:
            return .device
        }
    }
    
    private func errorTrend(for alerts: [PlaybackAlert]) -> TrendDirection {
        guard alerts.count >= 4 else { return alerts.isEmpty ? .stable : .stable }
        let midpoint = alerts.count / 2
        let firstHalf = alerts.prefix(midpoint).count
        let secondHalf = alerts.suffix(alerts.count - midpoint).count
        if secondHalf > firstHalf { return .degrading }
        if secondHalf < firstHalf { return .improving }
        return .stable
    }
    
    private func computeIntegrityScore(snr: Double, dynamicRange: Double, jitter: Double, glitches: Int) -> Double {
        var score = 100.0
        if snr > 0 { score -= max(0, 90 - snr) * 0.4 }
        if dynamicRange > 0 { score -= max(0, 70 - dynamicRange) * 0.6 }
        score -= min(15, jitter * 2000)
        score -= Double(min(glitches * 3, 15))
        return max(0, score)
    }
    
    private func jitterLevel(for jitter: Double) -> JitterLevel {
        switch jitter {
        case ..<0.002: return .minimal
        case ..<0.004: return .low
        case ..<0.006: return .moderate
        case ..<0.01: return .high
        default: return .excessive
        }
    }
    
    private func buildPathAnalysis(signalIssues: [SignalIssue], bitPerfectActive: Bool) -> String {
        if signalIssues.isEmpty {
            return bitPerfectActive ? "Signal chain is bit-perfect with nominal jitter." : "Signal chain stable; playback routed through system mixer."
        }
        let issueDescriptions = signalIssues.map { $0.rawValue }.joined(separator: ", ")
        return "Detected integrity issues: \(issueDescriptions). Review output chain for optimizations."
    }
    
    private func currentDeviceIdentifier() -> String {
        #if canImport(UIKit)
        return UIDevice.current.name
        #else
        return Host.current().localizedName ?? "Unknown"
        #endif
    }
    
    private func currentArchitecture() -> String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce(into: "") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return }
            identifier.append(Character(UnicodeScalar(UInt8(value))))
        }
        return identifier.isEmpty ? "arm64" : identifier
    }
}

private extension ThermalState {
    var isElevated: Bool {
        switch self {
        case .nominal:
            return false
        case .fair, .serious, .critical:
            return true
        }
    }
    
    var displayName: String {
        rawValue.capitalized
    }
}

private extension Float {
    func clamped(to range: ClosedRange<Float>) -> Float {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension Double {
    func clamped(to range: ClosedRange<Double>) -> Double {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension AVAudioSession.CategoryOptions {
    var optionNames: [String] {
        var names: [String] = []
        if contains(.mixWithOthers) { names.append("mixWithOthers") }
        if contains(.duckOthers) { names.append("duckOthers") }
        if contains(.allowBluetooth) { names.append("allowBluetooth") }
        if contains(.defaultToSpeaker) { names.append("defaultToSpeaker") }
        if contains(.allowBluetoothA2DP) { names.append("allowBluetoothA2DP") }
        if contains(.allowAirPlay) { names.append("allowAirPlay") }
        if contains(.interruptSpokenAudioAndMixWithOthers) { names.append("interruptSpokenAudio") }
        if names.isEmpty { names.append("none") }
        return names
    }
}

private struct EncodedMetric: Codable {
    let timestamp: Date
    let cpuUsage: Float
    let memoryUsage: Int64
    let bufferFillLevel: Float
    let renderLatency: Double
    let performanceScore: Float
    let qualityScore: Float
    let isBitPerfect: Bool
    let bufferUnderruns: Int
    
    init(_ metric: AudioMetrics) {
        self.timestamp = metric.timestamp
        self.cpuUsage = metric.cpuUsage
        self.memoryUsage = metric.memoryUsage
        self.bufferFillLevel = metric.bufferFillLevel
        self.renderLatency = metric.renderLatency
        self.performanceScore = metric.performanceScore
        self.qualityScore = metric.qualityScore
        self.isBitPerfect = metric.isBitPerfect
        self.bufferUnderruns = metric.bufferUnderruns
    }
}

