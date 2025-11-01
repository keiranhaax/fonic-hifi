//
//  PlaybackDiagnosticsCore.swift
//  Fonic HiFi
//

import AVFoundation
import Foundation

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
        configurationDump: ConfigurationDump,
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
}
