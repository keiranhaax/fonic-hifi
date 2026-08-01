import Foundation

#if canImport(UIKit)
import UIKit
#endif

@MainActor
final class AudioMonitorInsights {
    private let analytics: AudioSessionAnalytics
    private let reportBuilder: AudioMonitoringReportBuilder
    private let performanceAdvisor: AudioPerformanceAdvisor
    private let performanceProfiler: AudioPerformanceProfiler
    private let thermalStateMonitor: any ThermalStateMonitoring
    private let alertHistoryProvider: @Sendable @MainActor () -> [PlaybackAlert]

    init(
        analytics: AudioSessionAnalytics,
        reportBuilder: AudioMonitoringReportBuilder,
        performanceAdvisor: AudioPerformanceAdvisor,
        performanceProfiler: AudioPerformanceProfiler,
        thermalStateMonitor: any ThermalStateMonitoring,
        alertHistoryProvider: @escaping @Sendable @MainActor () -> [PlaybackAlert]
    ) {
        self.analytics = analytics
        self.reportBuilder = reportBuilder
        self.performanceAdvisor = performanceAdvisor
        self.performanceProfiler = performanceProfiler
        self.thermalStateMonitor = thermalStateMonitor
        self.alertHistoryProvider = alertHistoryProvider
    }

    func performanceTrends() -> PerformanceTrendSummary {
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

        return reportBuilder.trendSummary(for: window)
    }

    func resourceUtilization() -> ResourceUtilizationSummary {
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
            averageUsage: reportBuilder.average(of: cpuValues),
            peakUsage: cpuValues.max() ?? Double(latest.cpuUsage),
            efficiencyScore: (1.0 - reportBuilder.average(of: cpuValues) / 100).clamped(to: 0 ... 1),
            classification: classifyCPUUsage(Double(latest.cpuUsage))
        )

        let memoryAnalysis = ResourceUsageAnalysis(
            currentUsage: Double(latest.memoryUsage) / 1_048_576,
            averageUsage: reportBuilder.average(of: memoryValues),
            peakUsage: memoryValues.max() ?? Double(latest.memoryUsage) / 1_048_576,
            efficiencyScore: (1.0 - reportBuilder.average(of: memoryValues) / 512).clamped(to: 0 ... 1),
            classification: classifyMemoryUsage(Double(latest.memoryUsage) / 1_048_576)
        )

        let batteryCurrent = batteryValues.last ?? Double(latest.batteryUsageRate ?? 0)
        let batteryAverage = batteryValues.isEmpty ? batteryCurrent : reportBuilder.average(of: batteryValues)
        let batteryPeak = batteryValues.max() ?? batteryCurrent
        let batteryAnalysis = ResourceUsageAnalysis(
            currentUsage: batteryCurrent,
            averageUsage: batteryAverage,
            peakUsage: batteryPeak,
            efficiencyScore: (1.0 - batteryAverage / 350).clamped(to: 0 ... 1),
            classification: classifyBatteryUsage(batteryCurrent)
        )

        let networkAnalysis = ResourceUsageAnalysis(
            currentUsage: networkValues.last ?? Double(latest.networkBandwidth) / 1_000_000,
            averageUsage: reportBuilder.average(of: networkValues),
            peakUsage: networkValues.max() ?? Double(latest.networkBandwidth) / 1_000_000,
            efficiencyScore: (1.0 - reportBuilder.average(of: networkValues) / 15).clamped(to: 0 ... 1),
            classification: classifyNetworkUsage(networkValues.last ?? Double(latest.networkBandwidth) / 1_000_000)
        )

        let efficiencySamples = window.map { Double($0.efficiencyScore) }
        let overallScore = efficiencySamples.isEmpty ? (cpuAnalysis.efficiencyScore + batteryAnalysis.efficiencyScore) / 2 : reportBuilder.average(of: efficiencySamples)
        let overallRating: EfficiencyRating = switch overallScore {
        case 0.85...: .excellent
        case 0.7 ..< 0.85: .good
        case 0.5 ..< 0.7: .fair
        default: .poor
        }

        return ResourceUtilizationSummary(
            cpuUtilization: cpuAnalysis,
            memoryUtilization: memoryAnalysis,
            batteryUtilization: batteryAnalysis,
            networkUtilization: networkAnalysis,
            overallEfficiency: overallRating
        )
    }

    func qualityAssessment() -> QualityAssessmentSummary {
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
        let qualityScore = Int((reportBuilder.average(of: qualityScores) * 100).clamped(to: 0 ... 100))

        let bitPerfectStatus: BitPerfectStatus = if latest.isBitPerfect {
            .active
        } else if window.contains(where: \.isBitPerfect) {
            .available
        } else if latest.audioFormat.lowercased().contains("lossless") {
            .limited
        } else {
            .unavailable
        }

        let snrValues = window.compactMap { $0.estimatedSNR.map(Double.init) }
        let dynamicRangeValues = window.compactMap { $0.dynamicRange.map(Double.init) }
        let jitterValues = window.map { Double($0.jitter) }
        let glitchTotal = window.reduce(0) { $0 + $1.glitchCount }

        let averageSNR = reportBuilder.average(of: snrValues)
        let averageDynamicRange = reportBuilder.average(of: dynamicRangeValues)
        let averageJitter = reportBuilder.average(of: jitterValues)

        var signalIssues: Set<SignalIssue> = []
        if averageSNR > 0, averageSNR < 80 { signalIssues.insert(.noise) }
        if averageDynamicRange > 0, averageDynamicRange < 65 { signalIssues.insert(.distortion) }
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
                        description: "Digital jitter averaged \(String(format: "%.3f", averageJitter * 1000)) ms across the session.",
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
                    resolution: "Use a bit-perfect-eligible configuration and verify the physical output before making a bit-perfect claim."
                )
            )
        }

        var improvements: [QualityImprovement] = []
        if bitPerfectStatus != .active {
            improvements.append(
                QualityImprovement(
                    title: "Improve Bit-Perfect Eligibility",
                    description: "Match formats and bypass DSP; this does not measure the physical output.",
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
                integrityScore: Int(integrityScore.clamped(to: 0 ... 100)),
                issues: Array(signalIssues),
                pathAnalysis: pathAnalysis,
                jitterLevel: jitterLevel
            ),
            qualityIssues: qualityIssues,
            improvements: improvements
        )
    }

    func efficiencyAnalysis() -> EfficiencyAnalysisSummary {
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
        let efficiencyScore = Int((reportBuilder.average(of: efficiencyValues) * 100).clamped(to: 0 ... 100))

        let cpuAverage = reportBuilder.average(of: window.map { Double($0.cpuUsage) })
        let batteryAverage = reportBuilder.average(of: window.compactMap { $0.batteryUsageRate.map(Double.init) })

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
        let networkAverage = reportBuilder.average(of: window.map { Double($0.networkBandwidth) / 1_000_000 })
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

    func activeIssues() -> [DiagnosticIssue] {
        var issues: [DiagnosticIssue] = []
        let recentAlerts = Array(alertHistoryProvider().suffix(10))
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

        if let latest = analytics.latestMetric {
            if latest.cpuUsage > 85, !seenKeys.contains("cpu_usage_major") {
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
            if latest.bufferFillLevel < 0.3, !seenKeys.contains("low_buffer_fill_minor") {
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

    func recommendations() -> [PerformanceRecommendation] {
        performanceAdvisor.recommendations(for: analytics.latestMetric)
    }

    func optimizationOpportunities(profilingData: ProfilingData?) async -> [OptimizationOpportunity] {
        var opportunities = performanceAdvisor.opportunities(for: analytics.latestMetric)
        if let profilingData {
            let thermalState = await thermalStateMonitor.getCurrentState()
            var profilingOpportunities = performanceProfiler.optimizationOpportunities(for: profilingData)
            if thermalState.thermalState.isElevated {
                profilingOpportunities.append(
                    OptimizationOpportunity(
                        type: .resourceManagement,
                        description: "Device reported \(thermalState.thermalState.displayName) thermal conditions; reduce workload to prevent throttling.",
                        expectedGain: 5,
                        complexity: .medium
                    )
                )
            }
            opportunities.append(contentsOf: profilingOpportunities)
        }
        return opportunities
    }

    func sessionStatistics(alertHistory: [PlaybackAlert], sessionSummary: AudioSessionSummary) -> SessionStatisticsSummary {
        let durationHours = max(sessionSummary.duration / 3600, 0.1)
        let errorRate = Double(sessionSummary.totalAlerts) / durationHours
        let bufferUnderruns = alertHistory.count(where: { $0.type == .bufferUnderrun || $0.type == .lowBufferFill })
        let qualityDrops = analytics.historySnapshot.count(where: { $0.qualityScore < 0.85 })
        let recoverySuccess = analytics.historySnapshot.isEmpty ? 1.0 : Double(analytics.latestMetric?.recoverySuccessRate ?? 1.0)

        return SessionStatisticsSummary(
            totalUptime: sessionSummary.duration,
            averagePerformanceScore: sessionSummary.performanceScore,
            totalAlerts: sessionSummary.totalAlerts,
            errorRate: errorRate,
            bufferUnderrunIncidents: bufferUnderruns,
            qualityDropCount: qualityDrops,
            recoverySuccessRate: recoverySuccess
        )
    }

    func errorHistory(alertHistory: [PlaybackAlert]) -> ErrorHistorySummary {
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
                recoverySuccessful: (analytics.latestMetric?.recoverySuccessRate ?? 1) > 0.9
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

    func milestones(alertHistory: [PlaybackAlert]) -> [PerformanceMilestone] {
        var milestones: [PerformanceMilestone] = []
        let now = Date()
        if let start = analytics.sessionStartTime {
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
        if let peakQuality = analytics.historySnapshot.map({ Double($0.qualityScore) }).max(), peakQuality > 0.95 {
            milestones.append(
                PerformanceMilestone(
                    type: .quality,
                    achievedAt: now,
                    description: "Peak quality score \(Int(peakQuality * 100))",
                    value: peakQuality
                )
            )
        }
        let efficiencyValues = analytics.historySnapshot.map { Double($0.efficiencyScore) }
        let efficiencyAverage = reportBuilder.average(of: efficiencyValues)
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

    func osCompatibilityInfo() -> OSCompatibilityInfo {
        OSCompatibilityInfo(
            iosVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            deviceModel: currentDeviceIdentifier(),
            compatibilityStatus: .excellent,
            knownIssues: [],
            recommendedSettings: []
        )
    }

    func hardwareCompatibilityInfo(latestMetric: AudioMetrics?) -> HardwareCompatibilityInfo {
        let bitDepth = latestMetric?.bitDepth ?? 24
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
                    maxBitDepth: bitDepth,
                    snr: 90
                ),
                externalDevices: [],
                supportedFormats: []
            ),
            performanceLimitations: [],
            upgradeRecommendations: []
        )
    }

    func formatSupportMatrix() -> FormatSupportMatrix {
        FormatSupportMatrix(
            supportedFormats: [],
            compatibilityScore: 85,
            recommendations: []
        )
    }

    func performanceTrends(for metrics: [AudioMetrics]) -> [PerformanceTrend] {
        reportBuilder.performanceTrends(for: metrics)
    }

    func bottlenecks(from profilingData: ProfilingData) async -> [PerformanceBottleneck] {
        var bottlenecks = performanceProfiler.detectedBottlenecks(for: profilingData)

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
            case .critical: 4
            case .major: 3
            case .moderate: 2
            case .minor: 1
            }
        }

        return bottlenecks.sorted { severityRank($0.severity) > severityRank($1.severity) }
    }

    func optimizationOpportunities(from profilingData: ProfilingData) -> [OptimizationOpportunity] {
        performanceProfiler.optimizationOpportunities(for: profilingData)
    }

    private func recentMetrics(window: Int) -> [AudioMetrics] {
        analytics.recentMetrics(window: window)
    }

    private func classifyCPUUsage(_ value: Double) -> UsageClassification {
        switch value {
        case ..<5: .minimal
        case ..<25: .low
        case ..<50: .moderate
        case ..<75: .high
        default: .excessive
        }
    }

    private func classifyMemoryUsage(_ value: Double) -> UsageClassification {
        switch value {
        case ..<128: .minimal
        case ..<256: .low
        case ..<512: .moderate
        case ..<768: .high
        default: .excessive
        }
    }

    private func classifyBatteryUsage(_ value: Double) -> UsageClassification {
        switch value {
        case ..<40: .minimal
        case ..<120: .low
        case ..<200: .moderate
        case ..<320: .high
        default: .excessive
        }
    }

    private func classifyNetworkUsage(_ value: Double) -> UsageClassification {
        switch value {
        case ..<0.5: .minimal
        case ..<2: .low
        case ..<5: .moderate
        case ..<10: .high
        default: .excessive
        }
    }

    private func efficiencyRating(forCPU value: Double) -> EfficiencyRating {
        switch value {
        case ..<35: .excellent
        case ..<55: .good
        case ..<75: .fair
        default: .poor
        }
    }

    private func efficiencyRating(forBattery value: Double) -> EfficiencyRating {
        switch value {
        case ..<50: .excellent
        case ..<140: .good
        case ..<220: .fair
        default: .poor
        }
    }

    private func issueSeverity(for severity: AlertSeverity) -> IssueSeverity {
        switch severity {
        case .low: .minor
        case .medium: .moderate
        case .high: .major
        case .critical: .critical
        }
    }

    private func diagnosticIssueType(for type: AlertType) -> DiagnosticIssueType {
        switch type {
        case .bufferUnderrun, .lowBufferFill, .highCPUUsage, .highMemoryUsage, .latencySpike:
            .performance
        case .thermalThrottling:
            .hardware
        case .audioInterruption:
            .configuration
        case .formatMismatch:
            .compatibility
        case .engineError:
            .software
        case .audioDropout:
            .performance
        }
    }

    private func defaultResolution(for type: AlertType) -> String {
        switch type {
        case .bufferUnderrun, .lowBufferFill:
            "Increase IO buffer duration or reduce decoder complexity."
        case .highCPUUsage:
            "Lower visualization intensity or disable background decoding."
        case .highMemoryUsage:
            "Purge waveform caches and reload library assets on demand."
        case .latencySpike:
            "Preload tracks and keep device thermals in nominal range."
        case .thermalThrottling:
            "Pause playback briefly and move device to a cooler environment."
        case .audioInterruption:
            "Resume playback after interruption ended and re-activate session."
        case .formatMismatch:
            "Convert the track to a supported output format before playback."
        case .engineError:
            "Reset the audio engine and reload the active track."
        case .audioDropout:
            "Increase buffering or switch to offline playback."
        }
    }

    private func errorCategory(for type: AlertType) -> ErrorCategory {
        switch type {
        case .bufferUnderrun, .lowBufferFill:
            .buffer
        case .highCPUUsage, .highMemoryUsage, .engineError:
            .decoding
        case .latencySpike, .audioDropout:
            .network
        case .thermalThrottling:
            .device
        case .audioInterruption:
            .session
        case .formatMismatch:
            .device
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
        case ..<0.002: .minimal
        case ..<0.004: .low
        case ..<0.006: .moderate
        case ..<0.01: .high
        default: .excessive
        }
    }

    private func buildPathAnalysis(signalIssues: [SignalIssue], bitPerfectActive: Bool) -> String {
        if signalIssues.isEmpty {
            return bitPerfectActive
                ? "Software signal chain is bit-perfect eligible; physical output is not measured."
                : "Signal chain stable; playback routed through system mixer."
        }
        let issueDescriptions = signalIssues.map(\.rawValue).joined(separator: ", ")
        return "Detected integrity issues: \(issueDescriptions). Review output chain for optimizations."
    }

    private func currentDeviceIdentifier() -> String {
        #if canImport(UIKit)
            return UIDevice.current.name
        #else
            return Host.current().localizedName ?? "Unknown"
        #endif
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
