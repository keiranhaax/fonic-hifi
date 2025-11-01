//
//  PlaybackDiagnosticFormatters.swift
//  Fonic HiFi
//

import Foundation

public extension PlaybackDiagnostics {
    // MARK: - Report Generation

    /// Generate executive summary for non-technical users
    func generateExecutiveSummary() -> String {
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
    func generateTechnicalReport() -> String {
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
    func exportForAnalysis() -> [String: Any] {
        [
            "timestamp": timestamp.timeIntervalSince1970,
            "sessionDuration": sessionDuration,
            "systemHealth": systemHealth.rawValue,
            "systemScore": systemScore,
            "metrics": [
                "cpuUsage": currentMetrics.cpuUsage,
                "memoryUsage": currentMetrics.memoryUsage,
                "bufferUnderruns": currentMetrics.bufferUnderruns,
                "latency": currentMetrics.renderLatency,
                "performanceScore": currentMetrics.performanceScore,
            ],
            "issues": activeIssues.map { [
                "type": $0.type.rawValue,
                "severity": $0.severity.rawValue,
                "title": $0.title,
                "description": $0.description,
            ] },
            "recommendations": recommendations.map { [
                "type": $0.type.rawValue,
                "priority": $0.priority.rawValue,
                "title": $0.title,
                "description": $0.description,
            ] },
            "sessionStats": [
                "uptime": sessionStatistics.totalUptime,
                "averagePerformance": sessionStatistics.averagePerformanceScore,
                "totalAlerts": sessionStatistics.totalAlerts,
                "errorRate": sessionStatistics.errorRate,
            ],
        ]
    }
}
