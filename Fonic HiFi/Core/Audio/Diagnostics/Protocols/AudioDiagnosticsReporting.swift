//
//  AudioDiagnosticsReporting.swift
//  Fonic HiFi
//
//  Focused interface for diagnostics generation and export.
//

import Foundation

@MainActor
public protocol AudioDiagnosticsReporting: AnyObject, Sendable {
    func performDiagnosticsCheck() async -> PlaybackDiagnostics
    func getPerformanceRecommendations() async -> [PerformanceRecommendation]

    func exportMetrics(format: ExportFormat, timeRange: DateInterval?) async -> Data
    func generateReport(for timeRange: DateInterval) async -> MonitoringReport
}
