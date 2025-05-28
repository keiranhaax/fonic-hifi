//
//  AudioMonitoringService.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation
import Combine

/// Protocol defining comprehensive audio monitoring and metrics tracking API
@MainActor
public protocol AudioMonitoringService: AnyObject, Sendable {
    
    // MARK: - Publishers for Real-time Monitoring
    
    /// Publisher that emits updated metrics at regular intervals
    var metricsPublisher: AnyPublisher<AudioMetrics, Never> { get }
    
    /// Publisher that emits playback health status changes
    var healthStatusPublisher: AnyPublisher<PlaybackHealthStatus, Never> { get }
    
    /// Publisher that emits critical alerts (buffer underruns, high CPU, etc.)
    var alertsPublisher: AnyPublisher<PlaybackAlert, Never> { get }
    
    // MARK: - Monitoring Control
    
    /// Start monitoring with specified update interval
    /// - Parameter interval: Update interval in seconds (default: 1.0)
    func startMonitoring(updateInterval: TimeInterval) async
    
    /// Stop all monitoring activities
    func stopMonitoring() async
    
    /// Check if monitoring is currently active
    var isMonitoring: Bool { get async }
    
    /// Update monitoring interval while running
    /// - Parameter interval: New update interval in seconds
    func updateMonitoringInterval(_ interval: TimeInterval) async
    
    // MARK: - Metrics Retrieval
    
    /// Get current metrics snapshot
    /// - Returns: Current audio performance metrics
    func getCurrentMetrics() async -> AudioMetrics
    
    /// Get historical metrics for a time range
    /// - Parameters:
    ///   - startTime: Start of time range
    ///   - endTime: End of time range
    /// - Returns: Array of metrics within the time range
    func getHistoricalMetrics(from startTime: Date, to endTime: Date) async -> [AudioMetrics]
    
    /// Get aggregated metrics for a session
    /// - Returns: Summary statistics for the current monitoring session
    func getSessionSummary() async -> AudioSessionSummary
    
    /// Clear historical metrics data
    func clearHistory() async
    
    // MARK: - Engine Integration
    
    /// Associate monitoring with a specific audio engine
    /// - Parameter engine: Audio engine to monitor
    func attachToEngine(_ engine: AudioEngineService) async
    
    /// Remove association with current audio engine
    func detachFromEngine() async
    
    /// Get the currently monitored engine
    var currentEngine: AudioEngineService? { get async }
    
    // MARK: - Diagnostics & Health
    
    /// Perform comprehensive diagnostics check
    /// - Returns: Detailed diagnostics report
    func performDiagnosticsCheck() async -> PlaybackDiagnostics
    
    /// Check current playback health status
    /// - Returns: Overall health assessment
    func checkPlaybackHealth() async -> PlaybackHealthStatus
    
    /// Get recommendations for improving performance
    /// - Returns: Array of performance improvement suggestions
    func getPerformanceRecommendations() async -> [PerformanceRecommendation]
    
    // MARK: - Alerting & Thresholds
    
    /// Configure alert thresholds for various metrics
    /// - Parameter configuration: Alert threshold configuration
    func configureAlerts(_ configuration: AlertConfiguration) async
    
    /// Get current alert configuration
    /// - Returns: Current alert thresholds
    func getAlertConfiguration() async -> AlertConfiguration
    
    /// Manually trigger alert evaluation
    func evaluateAlerts() async
    
    // MARK: - System Resource Monitoring
    
    /// Get system-wide audio resource usage
    /// - Returns: System audio resource metrics
    func getSystemAudioMetrics() async -> SystemAudioMetrics
    
    /// Monitor device thermal state impact on audio
    /// - Returns: Thermal monitoring information
    func getThermalState() async -> ThermalMonitoringInfo
    
    /// Get audio session interruption statistics
    /// - Returns: Information about audio interruptions
    func getInterruptionStatistics() async -> InterruptionStatistics
    
    // MARK: - Performance Profiling
    
    /// Start detailed performance profiling
    /// - Parameter duration: How long to profile (nil = until stopped)
    func startProfiling(duration: TimeInterval?) async
    
    /// Stop performance profiling
    func stopProfiling() async
    
    /// Get profiling results
    /// - Returns: Detailed performance profile
    func getProfilingResults() async -> PerformanceProfile?
    
    /// Check if profiling is active
    var isProfiling: Bool { get async }
    
    // MARK: - Export & Reporting
    
    /// Export metrics data for analysis
    /// - Parameters:
    ///   - format: Export format (JSON, CSV, etc.)
    ///   - timeRange: Time range to export (nil = all data)
    /// - Returns: Exported data
    func exportMetrics(format: ExportFormat, timeRange: DateInterval?) async -> Data
    
    /// Generate comprehensive monitoring report
    /// - Parameter timeRange: Time range for the report
    /// - Returns: Formatted monitoring report
    func generateReport(for timeRange: DateInterval) async -> MonitoringReport
}

// MARK: - Supporting Types

// PlaybackHealthStatus is defined in AudioMetrics.swift

/// Critical playback alerts
public struct PlaybackAlert: Sendable, Equatable {
    /// Type of alert
    public let type: AlertType
    
    /// Alert severity level
    public let severity: AlertSeverity
    
    /// Human-readable message
    public let message: String
    
    /// Technical details for debugging
    public let technicalDetails: String
    
    /// Timestamp when alert was triggered
    public let timestamp: Date
    
    /// Associated metric values that triggered the alert
    public let triggerValues: [String: Double]
    
    /// Suggested actions to resolve the issue
    public let suggestedActions: [String]
    
    public init(
        type: AlertType,
        severity: AlertSeverity,
        message: String,
        technicalDetails: String,
        timestamp: Date = Date(),
        triggerValues: [String: Double] = [:],
        suggestedActions: [String] = []
    ) {
        self.type = type
        self.severity = severity
        self.message = message
        self.technicalDetails = technicalDetails
        self.timestamp = timestamp
        self.triggerValues = triggerValues
        self.suggestedActions = suggestedActions
    }
}

/// Types of monitoring alerts
public enum AlertType: String, Sendable, CaseIterable {
    case bufferUnderrun = "buffer_underrun"
    case highCPUUsage = "high_cpu_usage"
    case highMemoryUsage = "high_memory_usage"
    case lowBufferFill = "low_buffer_fill"
    case audioDropout = "audio_dropout"
    case latencySpike = "latency_spike"
    case thermalThrottling = "thermal_throttling"
    case audioInterruption = "audio_interruption"
    case formatMismatch = "format_mismatch"
    case engineError = "engine_error"
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .bufferUnderrun:
            return "Buffer Underrun"
        case .highCPUUsage:
            return "High CPU Usage"
        case .highMemoryUsage:
            return "High Memory Usage"
        case .lowBufferFill:
            return "Low Buffer Fill"
        case .audioDropout:
            return "Audio Dropout"
        case .latencySpike:
            return "Latency Spike"
        case .thermalThrottling:
            return "Thermal Throttling"
        case .audioInterruption:
            return "Audio Interruption"
        case .formatMismatch:
            return "Format Mismatch"
        case .engineError:
            return "Engine Error"
        }
    }
}

/// Alert severity levels
public enum AlertSeverity: String, Sendable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    /// Priority level for handling
    public var priority: Int {
        switch self {
        case .low: return 1
        case .medium: return 2
        case .high: return 3
        case .critical: return 4
        }
    }
}

/// Session summary statistics
public struct AudioSessionSummary: Sendable {
    /// Session start time
    public let sessionStart: Date
    
    /// Session duration
    public let duration: TimeInterval
    
    /// Average metrics over the session
    public let averageMetrics: AudioMetrics
    
    /// Peak metrics observed
    public let peakMetrics: AudioMetrics
    
    /// Total number of alerts triggered
    public let totalAlerts: Int
    
    /// Breakdown of alerts by type
    public let alertsByType: [AlertType: Int]
    
    /// Overall session health rating
    public let healthRating: PlaybackHealthStatus
    
    /// Number of metric samples collected
    public let sampleCount: Int
    
    /// Session performance score (0.0 to 1.0)
    public let performanceScore: Double
    
    public init(
        sessionStart: Date,
        duration: TimeInterval,
        averageMetrics: AudioMetrics,
        peakMetrics: AudioMetrics,
        totalAlerts: Int,
        alertsByType: [AlertType: Int],
        healthRating: PlaybackHealthStatus,
        sampleCount: Int,
        performanceScore: Double
    ) {
        self.sessionStart = sessionStart
        self.duration = duration
        self.averageMetrics = averageMetrics
        self.peakMetrics = peakMetrics
        self.totalAlerts = totalAlerts
        self.alertsByType = alertsByType
        self.healthRating = healthRating
        self.sampleCount = sampleCount
        self.performanceScore = performanceScore
    }
}

/// Performance improvement recommendations
public struct PerformanceRecommendation: Sendable, Equatable {
    /// Type of recommendation
    public let type: RecommendationType
    
    /// Priority level
    public let priority: RecommendationPriority
    
    /// User-friendly title
    public let title: String
    
    /// Detailed description
    public let description: String
    
    /// Expected performance improvement
    public let expectedImprovement: String
    
    /// Technical implementation details
    public let technicalDetails: String
    
    /// Whether this can be automatically applied
    public let canAutoApply: Bool
    
    public init(
        type: RecommendationType,
        priority: RecommendationPriority,
        title: String,
        description: String,
        expectedImprovement: String,
        technicalDetails: String,
        canAutoApply: Bool = false
    ) {
        self.type = type
        self.priority = priority
        self.title = title
        self.description = description
        self.expectedImprovement = expectedImprovement
        self.technicalDetails = technicalDetails
        self.canAutoApply = canAutoApply
    }
}

/// Types of performance recommendations
public enum RecommendationType: String, Sendable {
    case bufferSizeOptimization = "buffer_size_optimization"
    case audioSessionConfiguration = "audio_session_configuration"
    case performanceModeAdjustment = "performance_mode_adjustment"
    case backgroundAppManagement = "background_app_management"
    case thermalManagement = "thermal_management"
    case memoryOptimization = "memory_optimization"
    case engineSelection = "engine_selection"
    case formatOptimization = "format_optimization"
}

/// Recommendation priority levels
public enum RecommendationPriority: String, Sendable, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case critical = "critical"
    
    /// Sorting order
    public var sortOrder: Int {
        switch self {
        case .critical: return 4
        case .high: return 3
        case .medium: return 2
        case .low: return 1
        }
    }
}

/// Alert threshold configuration
public struct AlertConfiguration: Sendable, Equatable {
    /// CPU usage threshold (percentage)
    public let cpuThreshold: Float
    
    /// Memory usage threshold (bytes)
    public let memoryThreshold: Int64
    
    /// Buffer fill level threshold
    public let bufferFillThreshold: Float
    
    /// Maximum allowed buffer underruns
    public let maxBufferUnderruns: Int
    
    /// Latency spike threshold (seconds)
    public let latencyThreshold: TimeInterval
    
    /// Whether to enable thermal monitoring
    public let enableThermalMonitoring: Bool
    
    /// Alert cooldown period to prevent spam
    public let alertCooldownSeconds: TimeInterval
    
    public init(
        cpuThreshold: Float = 80.0,
        memoryThreshold: Int64 = 100_000_000, // 100MB
        bufferFillThreshold: Float = 0.3,
        maxBufferUnderruns: Int = 0,
        latencyThreshold: TimeInterval = 0.050, // 50ms
        enableThermalMonitoring: Bool = true,
        alertCooldownSeconds: TimeInterval = 30.0
    ) {
        self.cpuThreshold = cpuThreshold
        self.memoryThreshold = memoryThreshold
        self.bufferFillThreshold = bufferFillThreshold
        self.maxBufferUnderruns = maxBufferUnderruns
        self.latencyThreshold = latencyThreshold
        self.enableThermalMonitoring = enableThermalMonitoring
        self.alertCooldownSeconds = alertCooldownSeconds
    }
    
    /// Default configuration for production use
    public static var `default`: AlertConfiguration {
        return AlertConfiguration()
    }
    
    /// Sensitive configuration for debugging
    public static var sensitive: AlertConfiguration {
        return AlertConfiguration(
            cpuThreshold: 50.0,
            memoryThreshold: 50_000_000, // 50MB
            bufferFillThreshold: 0.5,
            maxBufferUnderruns: 0,
            latencyThreshold: 0.020, // 20ms
            alertCooldownSeconds: 10.0
        )
    }
}

/// System-wide audio resource metrics
public struct SystemAudioMetrics: Sendable {
    /// Total system audio CPU usage
    public let systemAudioCPU: Float
    
    /// Number of active audio sessions
    public let activeAudioSessions: Int
    
    /// System audio memory usage
    public let systemAudioMemory: Int64
    
    /// Audio device information
    public let deviceInfo: AudioDeviceInfo
    
    /// System audio interruptions count
    public let interruptionCount: Int
    
    /// Audio unit load average
    public let audioUnitLoad: Float
    
    public init(
        systemAudioCPU: Float,
        activeAudioSessions: Int,
        systemAudioMemory: Int64,
        deviceInfo: AudioDeviceInfo,
        interruptionCount: Int,
        audioUnitLoad: Float
    ) {
        self.systemAudioCPU = systemAudioCPU
        self.activeAudioSessions = activeAudioSessions
        self.systemAudioMemory = systemAudioMemory
        self.deviceInfo = deviceInfo
        self.interruptionCount = interruptionCount
        self.audioUnitLoad = audioUnitLoad
    }
}

/// Audio device information for monitoring
public struct AudioDeviceInfo: Sendable {
    /// Device identifier
    public let deviceID: String
    
    /// Device name
    public let name: String
    
    /// Current sample rate
    public let sampleRate: Double
    
    /// Current bit depth
    public let bitDepth: Int
    
    /// Number of channels
    public let channels: Int
    
    /// Device buffer size
    public let bufferSize: Int
    
    /// Device latency
    public let latency: TimeInterval
    
    public init(
        deviceID: String,
        name: String,
        sampleRate: Double,
        bitDepth: Int,
        channels: Int,
        bufferSize: Int,
        latency: TimeInterval
    ) {
        self.deviceID = deviceID
        self.name = name
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.bufferSize = bufferSize
        self.latency = latency
    }
}

/// Thermal monitoring information
public struct ThermalMonitoringInfo: Sendable {
    /// Current thermal state
    public let thermalState: ThermalState
    
    /// CPU temperature (if available)
    public let cpuTemperature: Double?
    
    /// Whether thermal throttling is active
    public let isThrottling: Bool
    
    /// Recommended performance adjustments
    public let recommendedAdjustments: [String]
    
    /// Timestamp of measurement
    public let timestamp: Date
    
    public init(
        thermalState: ThermalState,
        cpuTemperature: Double? = nil,
        isThrottling: Bool,
        recommendedAdjustments: [String],
        timestamp: Date = Date()
    ) {
        self.thermalState = thermalState
        self.cpuTemperature = cpuTemperature
        self.isThrottling = isThrottling
        self.recommendedAdjustments = recommendedAdjustments
        self.timestamp = timestamp
    }
}

/// Device thermal states
public enum ThermalState: String, Sendable, CaseIterable {
    case nominal = "nominal"
    case fair = "fair"
    case serious = "serious"
    case critical = "critical"
    
    /// Impact on audio performance
    public var performanceImpact: String {
        switch self {
        case .nominal:
            return "No impact"
        case .fair:
            return "Minor performance reduction"
        case .serious:
            return "Noticeable performance impact"
        case .critical:
            return "Severe performance throttling"
        }
    }
}

/// Audio session interruption statistics
public struct InterruptionStatistics: Sendable {
    /// Total number of interruptions
    public let totalInterruptions: Int
    
    /// Interruptions by type
    public let interruptionsByType: [InterruptionType: Int]
    
    /// Average interruption duration
    public let averageInterruptionDuration: TimeInterval
    
    /// Longest interruption duration
    public let longestInterruptionDuration: TimeInterval
    
    /// Recovery success rate
    public let recoverySuccessRate: Double
    
    /// Last interruption time
    public let lastInterruptionTime: Date?
    
    public init(
        totalInterruptions: Int,
        interruptionsByType: [InterruptionType: Int],
        averageInterruptionDuration: TimeInterval,
        longestInterruptionDuration: TimeInterval,
        recoverySuccessRate: Double,
        lastInterruptionTime: Date?
    ) {
        self.totalInterruptions = totalInterruptions
        self.interruptionsByType = interruptionsByType
        self.averageInterruptionDuration = averageInterruptionDuration
        self.longestInterruptionDuration = longestInterruptionDuration
        self.recoverySuccessRate = recoverySuccessRate
        self.lastInterruptionTime = lastInterruptionTime
    }
}

// InterruptionType is defined in AudioSessionInterruption.swift

/// Detailed performance profile from profiling session
public struct PerformanceProfile: Sendable {
    /// Profiling session start time
    public let startTime: Date
    
    /// Profiling duration
    public let duration: TimeInterval
    
    /// Detailed CPU usage breakdown
    public let cpuProfile: CPUProfile
    
    /// Memory allocation patterns
    public let memoryProfile: MemoryProfile
    
    /// Audio latency analysis
    public let latencyProfile: LatencyProfile
    
    /// Buffer management analysis
    public let bufferProfile: BufferProfile
    
    /// Performance bottlenecks identified
    public let bottlenecks: [PerformanceBottleneck]
    
    /// Optimization opportunities
    public let optimizations: [OptimizationOpportunity]
    
    public init(
        startTime: Date,
        duration: TimeInterval,
        cpuProfile: CPUProfile,
        memoryProfile: MemoryProfile,
        latencyProfile: LatencyProfile,
        bufferProfile: BufferProfile,
        bottlenecks: [PerformanceBottleneck],
        optimizations: [OptimizationOpportunity]
    ) {
        self.startTime = startTime
        self.duration = duration
        self.cpuProfile = cpuProfile
        self.memoryProfile = memoryProfile
        self.latencyProfile = latencyProfile
        self.bufferProfile = bufferProfile
        self.bottlenecks = bottlenecks
        self.optimizations = optimizations
    }
}

/// CPU usage profiling information
public struct CPUProfile: Sendable {
    /// Average CPU usage
    public let averageUsage: Float
    
    /// Peak CPU usage
    public let peakUsage: Float
    
    /// CPU usage distribution
    public let usageDistribution: [Float]
    
    /// Time spent in different performance states
    public let performanceStates: [PerformanceState: TimeInterval]
    
    public init(
        averageUsage: Float,
        peakUsage: Float,
        usageDistribution: [Float],
        performanceStates: [PerformanceState: TimeInterval]
    ) {
        self.averageUsage = averageUsage
        self.peakUsage = peakUsage
        self.usageDistribution = usageDistribution
        self.performanceStates = performanceStates
    }
}

/// Memory usage profiling information
public struct MemoryProfile: Sendable {
    /// Average memory usage
    public let averageUsage: Int64
    
    /// Peak memory usage
    public let peakUsage: Int64
    
    /// Memory allocation patterns
    public let allocationPatterns: [MemoryAllocation]
    
    /// Memory leak indicators
    public let leakIndicators: [MemoryLeakIndicator]
    
    public init(
        averageUsage: Int64,
        peakUsage: Int64,
        allocationPatterns: [MemoryAllocation],
        leakIndicators: [MemoryLeakIndicator]
    ) {
        self.averageUsage = averageUsage
        self.peakUsage = peakUsage
        self.allocationPatterns = allocationPatterns
        self.leakIndicators = leakIndicators
    }
}

/// Latency profiling information
public struct LatencyProfile: Sendable {
    /// Average latency
    public let averageLatency: TimeInterval
    
    /// Maximum latency observed
    public let maxLatency: TimeInterval
    
    /// Latency distribution
    public let latencyDistribution: [TimeInterval]
    
    /// Latency spikes (above threshold)
    public let spikes: [LatencySpike]
    
    public init(
        averageLatency: TimeInterval,
        maxLatency: TimeInterval,
        latencyDistribution: [TimeInterval],
        spikes: [LatencySpike]
    ) {
        self.averageLatency = averageLatency
        self.maxLatency = maxLatency
        self.latencyDistribution = latencyDistribution
        self.spikes = spikes
    }
}

/// Buffer management profiling information
public struct BufferProfile: Sendable {
    /// Average buffer fill level
    public let averageBufferFill: Float
    
    /// Minimum buffer fill observed
    public let minBufferFill: Float
    
    /// Number of buffer underruns
    public let underrunCount: Int
    
    /// Buffer fill distribution
    public let fillDistribution: [Float]
    
    public init(
        averageBufferFill: Float,
        minBufferFill: Float,
        underrunCount: Int,
        fillDistribution: [Float]
    ) {
        self.averageBufferFill = averageBufferFill
        self.minBufferFill = minBufferFill
        self.underrunCount = underrunCount
        self.fillDistribution = fillDistribution
    }
}

/// Performance bottleneck identification
public struct PerformanceBottleneck: Sendable {
    /// Type of bottleneck
    public let type: BottleneckType
    
    /// Description of the issue
    public let description: String
    
    /// Severity of the bottleneck
    public let severity: BottleneckSeverity
    
    /// Performance impact percentage
    public let impactPercentage: Float
    
    public init(type: BottleneckType, description: String, severity: BottleneckSeverity, impactPercentage: Float) {
        self.type = type
        self.description = description
        self.severity = severity
        self.impactPercentage = impactPercentage
    }
}

/// Types of performance bottlenecks
public enum BottleneckType: String, Sendable {
    case cpu = "cpu"
    case memory = "memory"
    case io = "io"
    case thermal = "thermal"
    case buffer = "buffer"
}

/// Bottleneck severity levels
public enum BottleneckSeverity: String, Sendable {
    case minor = "minor"
    case moderate = "moderate"
    case major = "major"
    case critical = "critical"
}

/// Optimization opportunity identification
public struct OptimizationOpportunity: Sendable {
    /// Type of optimization
    public let type: OptimizationType
    
    /// Description of the opportunity
    public let description: String
    
    /// Expected performance gain
    public let expectedGain: Float
    
    /// Implementation complexity
    public let complexity: OptimizationComplexity
    
    public init(type: OptimizationType, description: String, expectedGain: Float, complexity: OptimizationComplexity) {
        self.type = type
        self.description = description
        self.expectedGain = expectedGain
        self.complexity = complexity
    }
}

/// Types of optimization opportunities
public enum OptimizationType: String, Sendable {
    case bufferSizing = "buffer_sizing"
    case engineSelection = "engine_selection"
    case formatOptimization = "format_optimization"
    case resourceManagement = "resource_management"
}

/// Optimization implementation complexity
public enum OptimizationComplexity: String, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
}

/// Performance states for profiling
public enum PerformanceState: String, Sendable {
    case idle = "idle"
    case decoding = "decoding"
    case rendering = "rendering"
    case buffering = "buffering"
}

/// Memory allocation information
public struct MemoryAllocation: Sendable {
    /// Allocation size
    public let size: Int64
    
    /// Allocation timestamp
    public let timestamp: Date
    
    /// Allocation type
    public let type: MemoryAllocationType
    
    public init(size: Int64, timestamp: Date, type: MemoryAllocationType) {
        self.size = size
        self.timestamp = timestamp
        self.type = type
    }
}

/// Types of memory allocations
public enum MemoryAllocationType: String, Sendable {
    case buffer = "buffer"
    case decoder = "decoder"
    case metadata = "metadata"
    case temporary = "temporary"
}

/// Memory leak indicator
public struct MemoryLeakIndicator: Sendable {
    /// Suspected leak location
    public let location: String
    
    /// Leak size estimate
    public let estimatedSize: Int64
    
    /// Confidence level (0.0 to 1.0)
    public let confidence: Double
    
    public init(location: String, estimatedSize: Int64, confidence: Double) {
        self.location = location
        self.estimatedSize = estimatedSize
        self.confidence = confidence
    }
}

/// Latency spike information
public struct LatencySpike: Sendable {
    /// Spike timestamp
    public let timestamp: Date
    
    /// Spike duration
    public let duration: TimeInterval
    
    /// Peak latency during spike
    public let peakLatency: TimeInterval
    
    /// Possible cause
    public let possibleCause: String?
    
    public init(timestamp: Date, duration: TimeInterval, peakLatency: TimeInterval, possibleCause: String?) {
        self.timestamp = timestamp
        self.duration = duration
        self.peakLatency = peakLatency
        self.possibleCause = possibleCause
    }
}

/// Export format options
public enum ExportFormat: String, Sendable, CaseIterable {
    case json = "json"
    case csv = "csv"
    case xml = "xml"
    case binary = "binary"
    
    /// File extension for the format
    public var fileExtension: String {
        switch self {
        case .json: return "json"
        case .csv: return "csv"
        case .xml: return "xml"
        case .binary: return "bin"
        }
    }
    
    /// MIME type for the format
    public var mimeType: String {
        switch self {
        case .json: return "application/json"
        case .csv: return "text/csv"
        case .xml: return "application/xml"
        case .binary: return "application/octet-stream"
        }
    }
}

/// Comprehensive monitoring report
public struct MonitoringReport: Sendable {
    /// Report generation timestamp
    public let generatedAt: Date
    
    /// Time range covered by the report
    public let timeRange: DateInterval
    
    /// Executive summary
    public let summary: String
    
    /// Key findings and insights
    public let keyFindings: [String]
    
    /// Performance trends
    public let trends: [PerformanceTrend]
    
    /// Recommendations for improvement
    public let recommendations: [PerformanceRecommendation]
    
    /// Raw metrics data summary
    public let metricsData: AudioSessionSummary
    
    /// Alert history during the period
    public let alertHistory: [PlaybackAlert]
    
    public init(
        generatedAt: Date,
        timeRange: DateInterval,
        summary: String,
        keyFindings: [String],
        trends: [PerformanceTrend],
        recommendations: [PerformanceRecommendation],
        metricsData: AudioSessionSummary,
        alertHistory: [PlaybackAlert]
    ) {
        self.generatedAt = generatedAt
        self.timeRange = timeRange
        self.summary = summary
        self.keyFindings = keyFindings
        self.trends = trends
        self.recommendations = recommendations
        self.metricsData = metricsData
        self.alertHistory = alertHistory
    }
}

/// Performance trend information
public struct PerformanceTrend: Sendable {
    /// Metric being tracked
    public let metric: String
    
    /// Trend direction
    public let direction: TrendDirection
    
    /// Trend magnitude (percentage change)
    public let magnitude: Double
    
    /// Statistical significance
    public let significance: TrendSignificance
    
    /// Description of the trend
    public let description: String
    
    public init(metric: String, direction: TrendDirection, magnitude: Double, significance: TrendSignificance, description: String) {
        self.metric = metric
        self.direction = direction
        self.magnitude = magnitude
        self.significance = significance
        self.description = description
    }
}

/// Trend direction indicators
public enum TrendDirection: String, Sendable {
    case improving = "improving"
    case degrading = "degrading"
    case stable = "stable"
    case volatile = "volatile"
}

/// Trend statistical significance
public enum TrendSignificance: String, Sendable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
} 