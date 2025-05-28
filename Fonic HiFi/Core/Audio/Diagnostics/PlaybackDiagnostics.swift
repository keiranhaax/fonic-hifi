//
//  PlaybackDiagnostics.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation
import AVFoundation

/// Comprehensive diagnostics snapshot for UI-level display and debugging
public struct PlaybackDiagnostics: Sendable {
    
    // MARK: - Snapshot Information
    
    /// Timestamp when diagnostics were captured
    public let timestamp: Date
    
    /// Duration of monitoring session
    public let sessionDuration: TimeInterval
    
    /// Current diagnostics version for compatibility
    public let diagnosticsVersion: String
    
    // MARK: - System Overview
    
    /// Overall system health status
    public let systemHealth: DiagnosticHealthStatus
    
    /// Current audio metrics snapshot
    public let currentMetrics: AudioMetrics
    
    /// Audio engine information
    public let engineInfo: AudioEngineInfo
    
    /// Audio session configuration
    public let sessionInfo: AudioSessionInfo
    
    /// Device information
    public let deviceInfo: AudioDeviceInfo
    
    // MARK: - Performance Analysis
    
    /// Performance trends over the session
    public let performanceTrends: PerformanceTrendSummary
    
    /// Resource utilization analysis
    public let resourceUtilization: ResourceUtilizationSummary
    
    /// Quality assessment
    public let qualityAssessment: QualityAssessmentSummary
    
    /// Efficiency analysis
    public let efficiencyAnalysis: EfficiencyAnalysisSummary
    
    // MARK: - Issues and Recommendations
    
    /// Active issues detected
    public let activeIssues: [DiagnosticIssue]
    
    /// Recent alerts and warnings
    public let recentAlerts: [PlaybackAlert]
    
    /// Performance recommendations
    public let recommendations: [PerformanceRecommendation]
    
    /// Optimization opportunities
    public let optimizations: [OptimizationOpportunity]
    
    // MARK: - Historical Data
    
    /// Session statistics summary
    public let sessionStatistics: SessionStatisticsSummary
    
    /// Error history during session
    public let errorHistory: ErrorHistorySummary
    
    /// Performance milestones achieved
    public let milestones: [PerformanceMilestone]
    
    // MARK: - System Compatibility
    
    /// iOS version compatibility
    public let osCompatibility: OSCompatibilityInfo
    
    /// Hardware compatibility assessment
    public let hardwareCompatibility: HardwareCompatibilityInfo
    
    /// Audio format support matrix
    public let formatSupport: FormatSupportMatrix
    
    // MARK: - Debug Information
    
    /// Technical debug information
    public let debugInfo: DebugInformation
    
    /// Log entries for troubleshooting
    public let logEntries: [DiagnosticLogEntry]
    
    /// Configuration dump for support
    public let configurationDump: ConfigurationDump
    
    // MARK: - Initialization
    
    public init(
        timestamp: Date = Date(),
        sessionDuration: TimeInterval,
        diagnosticsVersion: String = "1.0",
        systemHealth: DiagnosticHealthStatus,
        currentMetrics: AudioMetrics,
        engineInfo: AudioEngineInfo,
        sessionInfo: AudioSessionInfo,
        deviceInfo: AudioDeviceInfo,
        performanceTrends: PerformanceTrendSummary,
        resourceUtilization: ResourceUtilizationSummary,
        qualityAssessment: QualityAssessmentSummary,
        efficiencyAnalysis: EfficiencyAnalysisSummary,
        activeIssues: [DiagnosticIssue],
        recentAlerts: [PlaybackAlert],
        recommendations: [PerformanceRecommendation],
        optimizations: [OptimizationOpportunity],
        sessionStatistics: SessionStatisticsSummary,
        errorHistory: ErrorHistorySummary,
        milestones: [PerformanceMilestone],
        osCompatibility: OSCompatibilityInfo,
        hardwareCompatibility: HardwareCompatibilityInfo,
        formatSupport: FormatSupportMatrix,
        debugInfo: DebugInformation,
        logEntries: [DiagnosticLogEntry],
        configurationDump: ConfigurationDump
    ) {
        self.timestamp = timestamp
        self.sessionDuration = sessionDuration
        self.diagnosticsVersion = diagnosticsVersion
        self.systemHealth = systemHealth
        self.currentMetrics = currentMetrics
        self.engineInfo = engineInfo
        self.sessionInfo = sessionInfo
        self.deviceInfo = deviceInfo
        self.performanceTrends = performanceTrends
        self.resourceUtilization = resourceUtilization
        self.qualityAssessment = qualityAssessment
        self.efficiencyAnalysis = efficiencyAnalysis
        self.activeIssues = activeIssues
        self.recentAlerts = recentAlerts
        self.recommendations = recommendations
        self.optimizations = optimizations
        self.sessionStatistics = sessionStatistics
        self.errorHistory = errorHistory
        self.milestones = milestones
        self.osCompatibility = osCompatibility
        self.hardwareCompatibility = hardwareCompatibility
        self.formatSupport = formatSupport
        self.debugInfo = debugInfo
        self.logEntries = logEntries
        self.configurationDump = configurationDump
    }
    
    // MARK: - Computed Properties
    
    /// Quick health summary for UI
    public var healthSummary: String {
        switch systemHealth {
        case .excellent:
            return "System performing optimally"
        case .good:
            return "Good performance with minor issues"
        case .fair:
            return "Performance concerns detected"
        case .poor:
            return "Performance issues affecting quality"
        case .critical:
            return "Critical issues requiring attention"
        }
    }
    
    /// Priority issues that need immediate attention
    public var priorityIssues: [DiagnosticIssue] {
        return activeIssues.filter { $0.severity == .critical || $0.severity == .major }
            .sorted { (issue1: DiagnosticIssue, issue2: DiagnosticIssue) in issue1.severity.sortOrder > issue2.severity.sortOrder }
    }
    
    /// High-impact recommendations
    public var highImpactRecommendations: [PerformanceRecommendation] {
        return recommendations.filter { $0.priority == .critical || $0.priority == .high }
            .sorted { $0.priority.sortOrder > $1.priority.sortOrder }
    }
    
    /// Overall system score (0-100)
    public var systemScore: Int {
        let healthScore = systemHealth.score
        let metricsScore = Int(currentMetrics.performanceScore * 100)
        let issuesPenalty = min(50, activeIssues.count * 10)
        
        return max(0, min(100, (healthScore + metricsScore) / 2 - issuesPenalty))
    }
    
    /// Whether diagnostics indicate system needs attention
    public var needsAttention: Bool {
        return !priorityIssues.isEmpty || 
               systemHealth.rawValue == "critical" || 
               systemHealth.rawValue == "poor" ||
               systemScore < 60
    }
    
    /// Quick status for dashboard display
    public var dashboardStatus: DashboardStatus {
        if systemScore >= 90 && priorityIssues.isEmpty {
            return .excellent
        } else if systemScore >= 75 && priorityIssues.count <= 1 {
            return .good
        } else if systemScore >= 60 {
            return .warning
        } else {
            return .critical
        }
    }
    
    // MARK: - Report Generation
    
    /// Generate executive summary for non-technical users
    public func generateExecutiveSummary() -> String {
        var summary = "Audio System Diagnostics Report\n"
        summary += "Generated: \(DateFormatter.diagnosticFormatter.string(from: timestamp))\n"
        summary += "Session Duration: \(sessionDuration.formattedDuration)\n\n"
        
        summary += "Overall Status: \(healthSummary)\n"
        summary += "System Score: \(systemScore)/100\n\n"
        
        if !priorityIssues.isEmpty {
            summary += "Priority Issues (\(priorityIssues.count)):\n"
            for issue in priorityIssues.prefix(3) {
                summary += "• \(issue.title)\n"
            }
            summary += "\n"
        }
        
        if !highImpactRecommendations.isEmpty {
            summary += "Key Recommendations:\n"
            for recommendation in highImpactRecommendations.prefix(3) {
                summary += "• \(recommendation.title)\n"
            }
        }
        
        return summary
    }
    
    /// Generate technical report for debugging
    public func generateTechnicalReport() -> String {
        var report = generateExecutiveSummary()
        
        report += "\n\nTechnical Details:\n"
        report += "Engine: \(engineInfo.type) v\(engineInfo.version)\n"
        report += "Audio Format: \(currentMetrics.formatDescription)\n"
        report += "Buffer: \(currentMetrics.bufferSize) frames\n"
        report += "Latency: \(String(format: "%.1f", currentMetrics.renderLatency * 1000))ms\n"
        report += "CPU Usage: \(String(format: "%.1f", currentMetrics.cpuUsage))%\n"
        report += "Memory: \(currentMetrics.formattedMemoryUsage)\n\n"
        
        if !activeIssues.isEmpty {
            report += "Active Issues:\n"
            for issue in activeIssues {
                report += "[\(issue.severity.rawValue.uppercased())] \(issue.title): \(issue.description)\n"
            }
            report += "\n"
        }
        
        report += "Performance Trends:\n"
        report += "CPU: \(performanceTrends.cpuTrend.description)\n"
        report += "Memory: \(performanceTrends.memoryTrend.description)\n"
        report += "Quality: \(performanceTrends.qualityTrend.description)\n"
        
        return report
    }
    
    /// Export diagnostics data for analysis
    public func exportForAnalysis() -> [String: Any] {
        return [
            "timestamp": timestamp.timeIntervalSince1970,
            "sessionDuration": sessionDuration,
            "systemHealth": systemHealth.rawValue,
            "systemScore": systemScore,
            "metrics": [
                "cpuUsage": currentMetrics.cpuUsage,
                "memoryUsage": currentMetrics.memoryUsage,
                "bufferUnderruns": currentMetrics.bufferUnderruns,
                "latency": currentMetrics.renderLatency,
                "performanceScore": currentMetrics.performanceScore
            ],
            "issues": activeIssues.map { [
                "type": $0.type.rawValue,
                "severity": $0.severity.rawValue,
                "title": $0.title,
                "description": $0.description
            ]},
            "recommendations": recommendations.map { [
                "type": $0.type.rawValue,
                "priority": $0.priority.rawValue,
                "title": $0.title,
                "description": $0.description
            ]},
            "sessionStats": [
                "uptime": sessionStatistics.totalUptime,
                "averagePerformance": sessionStatistics.averagePerformanceScore,
                "totalAlerts": sessionStatistics.totalAlerts,
                "errorRate": sessionStatistics.errorRate
            ]
        ]
    }
}

// MARK: - Supporting Types

/// Diagnostic health status levels
public enum DiagnosticHealthStatus: String, Sendable, CaseIterable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
    case critical = "critical"
    
    /// Numeric score for calculations
    public var score: Int {
        switch self {
        case .excellent: return 100
        case .good: return 80
        case .fair: return 60
        case .poor: return 40
        case .critical: return 20
        }
    }
}

/// Dashboard status indicators
public enum DashboardStatus: String, Sendable {
    case excellent = "excellent"
    case good = "good"
    case warning = "warning"
    case critical = "critical"
    
    /// Color for UI display
    public var color: String {
        switch self {
        case .excellent: return "green"
        case .good: return "blue"
        case .warning: return "orange"
        case .critical: return "red"
        }
    }
}

/// Audio engine information for diagnostics
public struct AudioEngineInfo: Sendable {
    /// Engine type identifier
    public let type: String
    
    /// Engine version
    public let version: String
    
    /// Engine capabilities
    public let capabilities: [String]
    
    /// Current configuration
    public let configuration: [String: String]
    
    /// Performance characteristics
    public let performanceProfile: String
    
    /// Last initialization time
    public let lastInitialized: Date
    
    public init(
        type: String,
        version: String,
        capabilities: [String],
        configuration: [String: String],
        performanceProfile: String,
        lastInitialized: Date
    ) {
        self.type = type
        self.version = version
        self.capabilities = capabilities
        self.configuration = configuration
        self.performanceProfile = performanceProfile
        self.lastInitialized = lastInitialized
    }
}

/// Audio session information for diagnostics
public struct AudioSessionInfo: Sendable {
    /// Session category
    public let category: String
    
    /// Session mode
    public let mode: String
    
    /// Session options
    public let options: [String]
    
    /// Current sample rate
    public let sampleRate: Double
    
    /// I/O buffer duration
    public let ioBufferDuration: TimeInterval
    
    /// Whether session is active
    public let isActive: Bool
    
    /// Other audio playing
    public let isOtherAudioPlaying: Bool
    
    public init(
        category: String,
        mode: String,
        options: [String],
        sampleRate: Double,
        ioBufferDuration: TimeInterval,
        isActive: Bool,
        isOtherAudioPlaying: Bool
    ) {
        self.category = category
        self.mode = mode
        self.options = options
        self.sampleRate = sampleRate
        self.ioBufferDuration = ioBufferDuration
        self.isActive = isActive
        self.isOtherAudioPlaying = isOtherAudioPlaying
    }
}

/// Performance trend summary
public struct PerformanceTrendSummary: Sendable {
    /// CPU usage trend
    public let cpuTrend: TrendIndicator
    
    /// Memory usage trend
    public let memoryTrend: TrendIndicator
    
    /// Latency trend
    public let latencyTrend: TrendIndicator
    
    /// Quality trend
    public let qualityTrend: TrendIndicator
    
    /// Buffer health trend
    public let bufferTrend: TrendIndicator
    
    /// Overall trend direction
    public let overallTrend: TrendDirection
    
    public init(
        cpuTrend: TrendIndicator,
        memoryTrend: TrendIndicator,
        latencyTrend: TrendIndicator,
        qualityTrend: TrendIndicator,
        bufferTrend: TrendIndicator,
        overallTrend: TrendDirection
    ) {
        self.cpuTrend = cpuTrend
        self.memoryTrend = memoryTrend
        self.latencyTrend = latencyTrend
        self.qualityTrend = qualityTrend
        self.bufferTrend = bufferTrend
        self.overallTrend = overallTrend
    }
}

/// Individual trend indicator
public struct TrendIndicator: Sendable {
    /// Current value
    public let currentValue: Double
    
    /// Change from previous measurement
    public let changePercent: Double
    
    /// Trend direction
    public let direction: TrendDirection
    
    /// Trend stability
    public let stability: TrendStability
    
    public init(currentValue: Double, changePercent: Double, direction: TrendDirection, stability: TrendStability) {
        self.currentValue = currentValue
        self.changePercent = changePercent
        self.direction = direction
        self.stability = stability
    }
    
    /// Human-readable description
    public var description: String {
        let change = changePercent >= 0 ? "+\(String(format: "%.1f", changePercent))" : String(format: "%.1f", changePercent)
        return "\(direction.symbol) \(change)% (\(stability.description))"
    }
}

/// Trend stability indicators
public enum TrendStability: String, Sendable {
    case stable = "stable"
    case fluctuating = "fluctuating"
    case volatile = "volatile"
    
    public var description: String {
        switch self {
        case .stable: return "Stable"
        case .fluctuating: return "Fluctuating"
        case .volatile: return "Volatile"
        }
    }
}

/// Resource utilization summary
public struct ResourceUtilizationSummary: Sendable {
    /// CPU utilization analysis
    public let cpuUtilization: ResourceUsageAnalysis
    
    /// Memory utilization analysis
    public let memoryUtilization: ResourceUsageAnalysis
    
    /// Battery utilization analysis
    public let batteryUtilization: ResourceUsageAnalysis
    
    /// Network utilization analysis
    public let networkUtilization: ResourceUsageAnalysis
    
    /// Overall efficiency rating
    public let overallEfficiency: EfficiencyRating
    
    public init(
        cpuUtilization: ResourceUsageAnalysis,
        memoryUtilization: ResourceUsageAnalysis,
        batteryUtilization: ResourceUsageAnalysis,
        networkUtilization: ResourceUsageAnalysis,
        overallEfficiency: EfficiencyRating
    ) {
        self.cpuUtilization = cpuUtilization
        self.memoryUtilization = memoryUtilization
        self.batteryUtilization = batteryUtilization
        self.networkUtilization = networkUtilization
        self.overallEfficiency = overallEfficiency
    }
}

/// Resource usage analysis
public struct ResourceUsageAnalysis: Sendable {
    /// Current usage level
    public let currentUsage: Double
    
    /// Average usage over session
    public let averageUsage: Double
    
    /// Peak usage observed
    public let peakUsage: Double
    
    /// Usage efficiency score
    public let efficiencyScore: Double
    
    /// Usage classification
    public let classification: UsageClassification
    
    public init(
        currentUsage: Double,
        averageUsage: Double,
        peakUsage: Double,
        efficiencyScore: Double,
        classification: UsageClassification
    ) {
        self.currentUsage = currentUsage
        self.averageUsage = averageUsage
        self.peakUsage = peakUsage
        self.efficiencyScore = efficiencyScore
        self.classification = classification
    }
}

/// Usage classification levels
public enum UsageClassification: String, Sendable {
    case minimal = "minimal"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case excessive = "excessive"
}

/// Quality assessment summary
public struct QualityAssessmentSummary: Sendable {
    /// Audio quality score (0-100)
    public let qualityScore: Int
    
    /// Bit-perfect status
    public let bitPerfectStatus: BitPerfectStatus
    
    /// Signal integrity assessment
    public let signalIntegrity: SignalIntegrityAssessment
    
    /// Detected quality issues
    public let qualityIssues: [QualityIssue]
    
    /// Quality improvement suggestions
    public let improvements: [QualityImprovement]
    
    public init(
        qualityScore: Int,
        bitPerfectStatus: BitPerfectStatus,
        signalIntegrity: SignalIntegrityAssessment,
        qualityIssues: [QualityIssue],
        improvements: [QualityImprovement]
    ) {
        self.qualityScore = qualityScore
        self.bitPerfectStatus = bitPerfectStatus
        self.signalIntegrity = signalIntegrity
        self.qualityIssues = qualityIssues
        self.improvements = improvements
    }
}

/// Bit-perfect playback status
public enum BitPerfectStatus: String, Sendable {
    case active = "active"
    case available = "available"
    case limited = "limited"
    case unavailable = "unavailable"
    
    public var description: String {
        switch self {
        case .active: return "Bit-perfect playback active"
        case .available: return "Bit-perfect available but not active"
        case .limited: return "Bit-perfect limited by device/format"
        case .unavailable: return "Bit-perfect not supported"
        }
    }
}

/// Signal integrity assessment
public struct SignalIntegrityAssessment: Sendable {
    /// Integrity score (0-100)
    public let integrityScore: Int
    
    /// Detected signal issues
    public let issues: [SignalIssue]
    
    /// Signal path analysis
    public let pathAnalysis: String
    
    /// Jitter measurement
    public let jitterLevel: JitterLevel
    
    public init(integrityScore: Int, issues: [SignalIssue], pathAnalysis: String, jitterLevel: JitterLevel) {
        self.integrityScore = integrityScore
        self.issues = issues
        self.pathAnalysis = pathAnalysis
        self.jitterLevel = jitterLevel
    }
}

/// Signal integrity issues
public enum SignalIssue: String, Sendable {
    case noise = "noise"
    case distortion = "distortion"
    case clipping = "clipping"
    case dropout = "dropout"
    case jitter = "jitter"
}

/// Jitter level assessment
public enum JitterLevel: String, Sendable {
    case minimal = "minimal"
    case low = "low"
    case moderate = "moderate"
    case high = "high"
    case excessive = "excessive"
}

/// Quality issue identification
public struct QualityIssue: Sendable {
    /// Issue type
    public let type: QualityIssueType
    
    /// Issue description
    public let description: String
    
    /// Impact on listening experience
    public let impact: QualityImpact
    
    /// Suggested resolution
    public let resolution: String
    
    public init(type: QualityIssueType, description: String, impact: QualityImpact, resolution: String) {
        self.type = type
        self.description = description
        self.impact = impact
        self.resolution = resolution
    }
}

/// Types of quality issues
public enum QualityIssueType: String, Sendable {
    case format = "format"
    case processing = "processing"
    case device = "device"
    case environment = "environment"
}

/// Quality improvement suggestions
public struct QualityImprovement: Sendable {
    /// Improvement title
    public let title: String
    
    /// Detailed description
    public let description: String
    
    /// Expected quality gain
    public let expectedGain: Int
    
    /// Implementation difficulty
    public let difficulty: ImprovementDifficulty
    
    public init(title: String, description: String, expectedGain: Int, difficulty: ImprovementDifficulty) {
        self.title = title
        self.description = description
        self.expectedGain = expectedGain
        self.difficulty = difficulty
    }
}

/// Implementation difficulty levels
public enum ImprovementDifficulty: String, Sendable {
    case easy = "easy"
    case moderate = "moderate"
    case advanced = "advanced"
}

/// Efficiency analysis summary
public struct EfficiencyAnalysisSummary: Sendable {
    /// Overall efficiency score (0-100)
    public let efficiencyScore: Int
    
    /// Power efficiency rating
    public let powerEfficiency: EfficiencyRating
    
    /// Performance efficiency rating
    public let performanceEfficiency: EfficiencyRating
    
    /// Resource optimization opportunities
    public let optimizationOpportunities: [EfficiencyOptimization]
    
    public init(
        efficiencyScore: Int,
        powerEfficiency: EfficiencyRating,
        performanceEfficiency: EfficiencyRating,
        optimizationOpportunities: [EfficiencyOptimization]
    ) {
        self.efficiencyScore = efficiencyScore
        self.powerEfficiency = powerEfficiency
        self.performanceEfficiency = performanceEfficiency
        self.optimizationOpportunities = optimizationOpportunities
    }
}

/// Efficiency ratings
public enum EfficiencyRating: String, Sendable {
    case excellent = "excellent"
    case good = "good"
    case fair = "fair"
    case poor = "poor"
}

/// Efficiency optimization suggestions
public struct EfficiencyOptimization: Sendable {
    /// Optimization title
    public let title: String
    
    /// Expected efficiency gain
    public let expectedGain: Int
    
    /// Resource impact
    public let resourceImpact: String
    
    /// Implementation steps
    public let steps: [String]
    
    public init(title: String, expectedGain: Int, resourceImpact: String, steps: [String]) {
        self.title = title
        self.expectedGain = expectedGain
        self.resourceImpact = resourceImpact
        self.steps = steps
    }
}

/// Diagnostic issue identification
public struct DiagnosticIssue: Sendable {
    /// Issue type
    public let type: DiagnosticIssueType
    
    /// Issue severity
    public let severity: IssueSeverity
    
    /// Issue title
    public let title: String
    
    /// Issue description
    public let description: String
    
    /// Technical details
    public let technicalDetails: String
    
    /// Suggested resolution
    public let resolution: String
    
    /// Whether auto-resolution is possible
    public let canAutoResolve: Bool
    
    /// Issue first detected time
    public let firstDetected: Date
    
    public init(
        type: DiagnosticIssueType,
        severity: IssueSeverity,
        title: String,
        description: String,
        technicalDetails: String,
        resolution: String,
        canAutoResolve: Bool,
        firstDetected: Date
    ) {
        self.type = type
        self.severity = severity
        self.title = title
        self.description = description
        self.technicalDetails = technicalDetails
        self.resolution = resolution
        self.canAutoResolve = canAutoResolve
        self.firstDetected = firstDetected
    }
}

/// Types of diagnostic issues
public enum DiagnosticIssueType: String, Sendable {
    case performance = "performance"
    case compatibility = "compatibility"
    case configuration = "configuration"
    case hardware = "hardware"
    case software = "software"
}

/// Issue severity levels
// IssueSeverity is defined in DACCompatibilityInfo.swift

/// Session statistics summary
public struct SessionStatisticsSummary: Sendable {
    /// Total uptime
    public let totalUptime: TimeInterval
    
    /// Average performance score
    public let averagePerformanceScore: Double
    
    /// Total alerts triggered
    public let totalAlerts: Int
    
    /// Error rate (errors per hour)
    public let errorRate: Double
    
    /// Buffer underrun incidents
    public let bufferUnderrunIncidents: Int
    
    /// Quality drops count
    public let qualityDropCount: Int
    
    /// Recovery success rate
    public let recoverySuccessRate: Double
    
    public init(
        totalUptime: TimeInterval,
        averagePerformanceScore: Double,
        totalAlerts: Int,
        errorRate: Double,
        bufferUnderrunIncidents: Int,
        qualityDropCount: Int,
        recoverySuccessRate: Double
    ) {
        self.totalUptime = totalUptime
        self.averagePerformanceScore = averagePerformanceScore
        self.totalAlerts = totalAlerts
        self.errorRate = errorRate
        self.bufferUnderrunIncidents = bufferUnderrunIncidents
        self.qualityDropCount = qualityDropCount
        self.recoverySuccessRate = recoverySuccessRate
    }
}

/// Error history summary
public struct ErrorHistorySummary: Sendable {
    /// Total errors encountered
    public let totalErrors: Int
    
    /// Errors by category
    public let errorsByCategory: [ErrorCategory: Int]
    
    /// Most recent error
    public let mostRecentError: DiagnosticError?
    
    /// Most common error type
    public let mostCommonErrorType: ErrorCategory?
    
    /// Error frequency trend
    public let errorFrequencyTrend: TrendDirection
    
    public init(
        totalErrors: Int,
        errorsByCategory: [ErrorCategory: Int],
        mostRecentError: DiagnosticError?,
        mostCommonErrorType: ErrorCategory?,
        errorFrequencyTrend: TrendDirection
    ) {
        self.totalErrors = totalErrors
        self.errorsByCategory = errorsByCategory
        self.mostRecentError = mostRecentError
        self.mostCommonErrorType = mostCommonErrorType
        self.errorFrequencyTrend = errorFrequencyTrend
    }
}

/// Error categories for tracking
public enum ErrorCategory: String, Sendable {
    case buffer = "buffer"
    case decoding = "decoding"
    case session = "session"
    case device = "device"
    case network = "network"
    case unknown = "unknown"
}

/// Diagnostic error information
public struct DiagnosticError: Sendable {
    /// Error code
    public let code: String
    
    /// Error category
    public let category: ErrorCategory
    
    /// Error description
    public let description: String
    
    /// Error timestamp
    public let timestamp: Date
    
    /// Recovery attempted
    public let recoveryAttempted: Bool
    
    /// Recovery successful
    public let recoverySuccessful: Bool
    
    public init(
        code: String,
        category: ErrorCategory,
        description: String,
        timestamp: Date,
        recoveryAttempted: Bool,
        recoverySuccessful: Bool
    ) {
        self.code = code
        self.category = category
        self.description = description
        self.timestamp = timestamp
        self.recoveryAttempted = recoveryAttempted
        self.recoverySuccessful = recoverySuccessful
    }
}

/// Performance milestone tracking
public struct PerformanceMilestone: Sendable {
    /// Milestone type
    public let type: MilestoneType
    
    /// Achievement timestamp
    public let achievedAt: Date
    
    /// Milestone description
    public let description: String
    
    /// Performance value achieved
    public let value: Double
    
    public init(type: MilestoneType, achievedAt: Date, description: String, value: Double) {
        self.type = type
        self.achievedAt = achievedAt
        self.description = description
        self.value = value
    }
}

/// Types of performance milestones
public enum MilestoneType: String, Sendable {
    case uptime = "uptime"
    case quality = "quality"
    case efficiency = "efficiency"
    case stability = "stability"
}

/// OS compatibility information
public struct OSCompatibilityInfo: Sendable {
    /// iOS version
    public let iosVersion: String
    
    /// Device model
    public let deviceModel: String
    
    /// Compatibility status
    public let compatibilityStatus: CompatibilityStatus
    
    /// Known issues for this OS version
    public let knownIssues: [String]
    
    /// Recommended settings
    public let recommendedSettings: [String]
    
    public init(
        iosVersion: String,
        deviceModel: String,
        compatibilityStatus: CompatibilityStatus,
        knownIssues: [String],
        recommendedSettings: [String]
    ) {
        self.iosVersion = iosVersion
        self.deviceModel = deviceModel
        self.compatibilityStatus = compatibilityStatus
        self.knownIssues = knownIssues
        self.recommendedSettings = recommendedSettings
    }
}

/// Hardware compatibility information
public struct HardwareCompatibilityInfo: Sendable {
    /// Device capabilities assessment
    public let deviceCapabilities: DeviceCapabilityAssessment
    
    /// Audio hardware details
    public let audioHardware: AudioHardwareInfo
    
    /// Performance limitations
    public let performanceLimitations: [PerformanceLimitation]
    
    /// Upgrade recommendations
    public let upgradeRecommendations: [UpgradeRecommendation]
    
    public init(
        deviceCapabilities: DeviceCapabilityAssessment,
        audioHardware: AudioHardwareInfo,
        performanceLimitations: [PerformanceLimitation],
        upgradeRecommendations: [UpgradeRecommendation]
    ) {
        self.deviceCapabilities = deviceCapabilities
        self.audioHardware = audioHardware
        self.performanceLimitations = performanceLimitations
        self.upgradeRecommendations = upgradeRecommendations
    }
}

/// Compatibility status levels
public enum CompatibilityStatus: String, Sendable {
    case excellent = "excellent"
    case good = "good"
    case limited = "limited"
    case problematic = "problematic"
}

/// Device capability assessment
public struct DeviceCapabilityAssessment: Sendable {
    /// Overall capability score
    public let capabilityScore: Int
    
    /// CPU performance rating
    public let cpuRating: PerformanceRating
    
    /// Memory capacity rating
    public let memoryRating: PerformanceRating
    
    /// Audio processing capability
    public let audioProcessingCapability: AudioProcessingCapability
    
    public init(
        capabilityScore: Int,
        cpuRating: PerformanceRating,
        memoryRating: PerformanceRating,
        audioProcessingCapability: AudioProcessingCapability
    ) {
        self.capabilityScore = capabilityScore
        self.cpuRating = cpuRating
        self.memoryRating = memoryRating
        self.audioProcessingCapability = audioProcessingCapability
    }
}

/// Performance ratings for device components
public enum PerformanceRating: String, Sendable {
    case excellent = "excellent"
    case good = "good"
    case adequate = "adequate"
    case limited = "limited"
}

/// Audio processing capability assessment
public enum AudioProcessingCapability: String, Sendable {
    case professional = "professional"
    case enthusiast = "enthusiast"
    case standard = "standard"
    case basic = "basic"
}

/// Audio hardware information
public struct AudioHardwareInfo: Sendable {
    /// Built-in audio capabilities
    public let builtInAudio: BuiltInAudioInfo
    
    /// Connected external devices
    public let externalDevices: [ExternalAudioDevice]
    
    /// Supported formats matrix
    public let supportedFormats: [AudioFormatSupport]
    
    public init(
        builtInAudio: BuiltInAudioInfo,
        externalDevices: [ExternalAudioDevice],
        supportedFormats: [AudioFormatSupport]
    ) {
        self.builtInAudio = builtInAudio
        self.externalDevices = externalDevices
        self.supportedFormats = supportedFormats
    }
}

/// Built-in audio capabilities
public struct BuiltInAudioInfo: Sendable {
    /// DAC quality rating
    public let dacQuality: QualityRating
    
    /// Maximum sample rate
    public let maxSampleRate: Int
    
    /// Maximum bit depth
    public let maxBitDepth: Int
    
    /// Signal-to-noise ratio
    public let snr: Double?
    
    public init(dacQuality: QualityRating, maxSampleRate: Int, maxBitDepth: Int, snr: Double?) {
        self.dacQuality = dacQuality
        self.maxSampleRate = maxSampleRate
        self.maxBitDepth = maxBitDepth
        self.snr = snr
    }
}

/// Quality rating for audio components
public enum QualityRating: String, Sendable {
    case reference = "reference"
    case excellent = "excellent"
    case good = "good"
    case adequate = "adequate"
    case basic = "basic"
}

/// External audio device information
public struct ExternalAudioDevice: Sendable {
    /// Device name
    public let name: String
    
    /// Device type
    public let type: ExternalDeviceType
    
    /// Connection interface
    public let interface: DeviceInterface
    
    /// Capabilities
    public let capabilities: ExternalDeviceCapabilities
    
    public init(name: String, type: ExternalDeviceType, interface: DeviceInterface, capabilities: ExternalDeviceCapabilities) {
        self.name = name
        self.type = type
        self.interface = interface
        self.capabilities = capabilities
    }
}

/// Types of external audio devices
public enum ExternalDeviceType: String, Sendable {
    case dac = "dac"
    case headphones = "headphones"
    case speakers = "speakers"
    case interface = "interface"
}

/// Device interface types
public enum DeviceInterface: String, Sendable {
    case usb = "usb"
    case bluetooth = "bluetooth"
    case headphoneJack = "headphone_jack"
    case lightning = "lightning"
}

/// External device capabilities
public struct ExternalDeviceCapabilities: Sendable {
    /// Maximum sample rate supported
    public let maxSampleRate: Int
    
    /// Maximum bit depth supported
    public let maxBitDepth: Int
    
    /// Supports bit-perfect playback
    public let supportsBitPerfect: Bool
    
    /// Quality rating
    public let qualityRating: QualityRating
    
    public init(maxSampleRate: Int, maxBitDepth: Int, supportsBitPerfect: Bool, qualityRating: QualityRating) {
        self.maxSampleRate = maxSampleRate
        self.maxBitDepth = maxBitDepth
        self.supportsBitPerfect = supportsBitPerfect
        self.qualityRating = qualityRating
    }
}

/// Audio format support information
public struct AudioFormatSupport: Sendable {
    /// Format identifier
    public let format: String
    
    /// Support level
    public let supportLevel: FormatSupportLevel
    
    /// Maximum quality supported
    public let maxQuality: FormatQuality
    
    /// Engine recommendations
    public let recommendedEngine: String?
    
    public init(format: String, supportLevel: FormatSupportLevel, maxQuality: FormatQuality, recommendedEngine: String?) {
        self.format = format
        self.supportLevel = supportLevel
        self.maxQuality = maxQuality
        self.recommendedEngine = recommendedEngine
    }
}

/// Format support levels
public enum FormatSupportLevel: String, Sendable {
    case native = "native"
    case converted = "converted"
    case limited = "limited"
    case unsupported = "unsupported"
}

/// Format quality capabilities
public struct FormatQuality: Sendable {
    /// Maximum sample rate
    public let maxSampleRate: Int
    
    /// Maximum bit depth
    public let maxBitDepth: Int
    
    /// Maximum channels
    public let maxChannels: Int
    
    public init(maxSampleRate: Int, maxBitDepth: Int, maxChannels: Int) {
        self.maxSampleRate = maxSampleRate
        self.maxBitDepth = maxBitDepth
        self.maxChannels = maxChannels
    }
}

/// Performance limitation identification
public struct PerformanceLimitation: Sendable {
    /// Limitation type
    public let type: LimitationType
    
    /// Description
    public let description: String
    
    /// Impact on performance
    public let impact: PerformanceImpact
    
    /// Workaround suggestions
    public let workarounds: [String]
    
    public init(type: LimitationType, description: String, impact: PerformanceImpact, workarounds: [String]) {
        self.type = type
        self.description = description
        self.impact = impact
        self.workarounds = workarounds
    }
}

/// Types of performance limitations
// LimitationType is defined in BitPerfectValidatorService.swift

/// Performance impact levels
// PerformanceImpact is defined in AudioEngineType.swift

/// Upgrade recommendation
public struct UpgradeRecommendation: Sendable {
    /// Recommendation type
    public let type: UpgradeType
    
    /// Description
    public let description: String
    
    /// Expected improvement
    public let expectedImprovement: String
    
    /// Priority level
    public let priority: UpgradePriority
    
    public init(type: UpgradeType, description: String, expectedImprovement: String, priority: UpgradePriority) {
        self.type = type
        self.description = description
        self.expectedImprovement = expectedImprovement
        self.priority = priority
    }
}

/// Types of upgrade recommendations
public enum UpgradeType: String, Sendable {
    case hardware = "hardware"
    case software = "software"
    case configuration = "configuration"
    case accessory = "accessory"
}

/// Upgrade priority levels
public enum UpgradePriority: String, Sendable {
    case essential = "essential"
    case recommended = "recommended"
    case optional = "optional"
}

/// Format support matrix
public struct FormatSupportMatrix: Sendable {
    /// Supported formats with details
    public let supportedFormats: [AudioFormatSupport]
    
    /// Overall format compatibility score
    public let compatibilityScore: Int
    
    /// Format recommendations
    public let recommendations: [FormatRecommendation]
    
    public init(supportedFormats: [AudioFormatSupport], compatibilityScore: Int, recommendations: [FormatRecommendation]) {
        self.supportedFormats = supportedFormats
        self.compatibilityScore = compatibilityScore
        self.recommendations = recommendations
    }
}

/// Format recommendation
public struct FormatRecommendation: Sendable {
    /// Recommended format
    public let format: String
    
    /// Reason for recommendation
    public let reason: String
    
    /// Quality benefit
    public let qualityBenefit: String
    
    /// Performance impact
    public let performanceImpact: String
    
    public init(format: String, reason: String, qualityBenefit: String, performanceImpact: String) {
        self.format = format
        self.reason = reason
        self.qualityBenefit = qualityBenefit
        self.performanceImpact = performanceImpact
    }
}

/// Debug information for troubleshooting
public struct DebugInformation: Sendable {
    /// Debug session ID
    public let sessionID: String
    
    /// System information
    public let systemInfo: SystemDebugInfo
    
    /// Audio stack information
    public let audioStackInfo: AudioStackDebugInfo
    
    /// Performance counters
    public let performanceCounters: [String: Double]
    
    /// Debug flags and settings
    public let debugFlags: [String: Bool]
    
    public init(
        sessionID: String,
        systemInfo: SystemDebugInfo,
        audioStackInfo: AudioStackDebugInfo,
        performanceCounters: [String: Double],
        debugFlags: [String: Bool]
    ) {
        self.sessionID = sessionID
        self.systemInfo = systemInfo
        self.audioStackInfo = audioStackInfo
        self.performanceCounters = performanceCounters
        self.debugFlags = debugFlags
    }
}

/// System debug information
public struct SystemDebugInfo: Sendable {
    /// Device identifier
    public let deviceIdentifier: String
    
    /// System version
    public let systemVersion: String
    
    /// Available memory
    public let availableMemory: Int64
    
    /// CPU architecture
    public let cpuArchitecture: String
    
    /// Thermal state
    public let thermalState: String
    
    public init(deviceIdentifier: String, systemVersion: String, availableMemory: Int64, cpuArchitecture: String, thermalState: String) {
        self.deviceIdentifier = deviceIdentifier
        self.systemVersion = systemVersion
        self.availableMemory = availableMemory
        self.cpuArchitecture = cpuArchitecture
        self.thermalState = thermalState
    }
}

/// Audio stack debug information
public struct AudioStackDebugInfo: Sendable {
    /// Active audio units
    public let activeAudioUnits: [String]
    
    /// Audio session details
    public let sessionDetails: [String: String]
    
    /// Engine configuration
    public let engineConfiguration: [String: String]
    
    /// Buffer information
    public let bufferInfo: BufferDebugInfo
    
    public init(activeAudioUnits: [String], sessionDetails: [String: String], engineConfiguration: [String: String], bufferInfo: BufferDebugInfo) {
        self.activeAudioUnits = activeAudioUnits
        self.sessionDetails = sessionDetails
        self.engineConfiguration = engineConfiguration
        self.bufferInfo = bufferInfo
    }
}

/// Buffer debug information
public struct BufferDebugInfo: Sendable {
    /// Buffer sizes
    public let bufferSizes: [String: Int]
    
    /// Buffer utilization
    public let bufferUtilization: [String: Float]
    
    /// Buffer allocation history
    public let allocationHistory: [BufferAllocation]
    
    public init(bufferSizes: [String: Int], bufferUtilization: [String: Float], allocationHistory: [BufferAllocation]) {
        self.bufferSizes = bufferSizes
        self.bufferUtilization = bufferUtilization
        self.allocationHistory = allocationHistory
    }
}

/// Buffer allocation information
public struct BufferAllocation: Sendable {
    /// Allocation timestamp
    public let timestamp: Date
    
    /// Buffer size
    public let size: Int
    
    /// Allocation reason
    public let reason: String
    
    public init(timestamp: Date, size: Int, reason: String) {
        self.timestamp = timestamp
        self.size = size
        self.reason = reason
    }
}

/// Diagnostic log entry
public struct DiagnosticLogEntry: Sendable {
    /// Log timestamp
    public let timestamp: Date
    
    /// Log level
    public let level: LogLevel
    
    /// Log category
    public let category: String
    
    /// Log message
    public let message: String
    
    /// Additional context
    public let context: [String: String]
    
    public init(timestamp: Date, level: LogLevel, category: String, message: String, context: [String: String]) {
        self.timestamp = timestamp
        self.level = level
        self.category = category
        self.message = message
        self.context = context
    }
}

/// Log levels for diagnostics
public enum LogLevel: String, Sendable {
    case debug = "debug"
    case info = "info"
    case warning = "warning"
    case error = "error"
    case critical = "critical"
}

/// Configuration dump for support
public struct ConfigurationDump: Sendable {
    /// Audio engine configuration
    public let engineConfig: [String: String]
    
    /// Audio session configuration
    public let sessionConfig: [String: String]
    
    /// Device configuration
    public let deviceConfig: [String: String]
    
    /// User preferences
    public let userPreferences: [String: String]
    
    /// System settings
    public let systemSettings: [String: String]
    
    public init(
        engineConfig: [String: String],
        sessionConfig: [String: String],
        deviceConfig: [String: String],
        userPreferences: [String: String],
        systemSettings: [String: String]
    ) {
        self.engineConfig = engineConfig
        self.sessionConfig = sessionConfig
        self.deviceConfig = deviceConfig
        self.userPreferences = userPreferences
        self.systemSettings = systemSettings
    }
}

// MARK: - Utility Extensions

extension TrendDirection {
    /// Symbol for trend direction
    public var symbol: String {
        switch self {
        case .improving: return "↗"
        case .degrading: return "↘"
        case .stable: return "→"
        case .volatile: return "↕"
        }
    }
}

extension TimeInterval {
    /// Format duration for display
    public var formattedDuration: String {
        let hours = Int(self) / 3600
        let minutes = Int(self) % 3600 / 60
        let seconds = Int(self) % 60
        
        if hours > 0 {
            return String(format: "%dh %dm %ds", hours, minutes, seconds)
        } else if minutes > 0 {
            return String(format: "%dm %ds", minutes, seconds)
        } else {
            return String(format: "%ds", seconds)
        }
    }
}

extension DateFormatter {
    /// Formatter for diagnostic timestamps
    public static var diagnosticFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }
} 