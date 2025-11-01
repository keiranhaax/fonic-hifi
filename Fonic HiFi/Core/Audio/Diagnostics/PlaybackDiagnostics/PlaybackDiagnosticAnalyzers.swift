//
//  PlaybackDiagnosticAnalyzers.swift
//  Fonic HiFi
//

import Foundation

public extension PlaybackDiagnostics {
    // MARK: - Computed Properties

    /// Quick health summary for UI
    var healthSummary: String {
        switch systemHealth {
        case .excellent:
            "System performing optimally"
        case .good:
            "Good performance with minor issues"
        case .fair:
            "Performance concerns detected"
        case .poor:
            "Performance issues affecting quality"
        case .critical:
            "Critical issues requiring attention"
        }
    }

    /// Priority issues that need immediate attention
    var priorityIssues: [DiagnosticIssue] {
        activeIssues.filter { $0.severity == .critical || $0.severity == .major }
            .sorted { (issue1: DiagnosticIssue, issue2: DiagnosticIssue) in issue1.severity.sortOrder > issue2.severity.sortOrder }
    }

    /// High-impact recommendations
    var highImpactRecommendations: [PerformanceRecommendation] {
        recommendations.filter { $0.priority == .critical || $0.priority == .high }
            .sorted { $0.priority.sortOrder > $1.priority.sortOrder }
    }

    /// Overall system score (0-100)
    var systemScore: Int {
        let healthScore = systemHealth.score
        let metricsScore = Int(currentMetrics.performanceScore * 100)
        let issuesPenalty = min(50, activeIssues.count * 10)

        return max(0, min(100, (healthScore + metricsScore) / 2 - issuesPenalty))
    }

    /// Whether diagnostics indicate system needs attention
    var needsAttention: Bool {
        !priorityIssues.isEmpty ||
            systemHealth.rawValue == "critical" ||
            systemHealth.rawValue == "poor" ||
            systemScore < 60
    }

    /// Quick status for dashboard display
    var dashboardStatus: DashboardStatus {
        if systemScore >= 90, priorityIssues.isEmpty {
            .excellent
        } else if systemScore >= 75, priorityIssues.count <= 1 {
            .good
        } else if systemScore >= 60 {
            .warning
        } else {
            .critical
        }
    }
}
