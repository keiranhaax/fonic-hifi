//
//  AudioSessionMonitoring.swift
//  Fonic HiFi
//
//  Focused interface for monitoring session history and summaries.
//

import Foundation

@MainActor
public protocol AudioSessionMonitoring: AnyObject, Sendable {
    func getHistoricalMetrics(from startTime: Date, to endTime: Date) async -> [AudioMetrics]
    func getSessionSummary() async -> AudioSessionSummary
    func clearHistory() async
}
