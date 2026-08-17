//
//  AudioPerformanceMonitoring.swift
//  Fonic HiFi
//
//  Focused interface for runtime monitoring, metrics, and profiling.
//

import Foundation

@MainActor
public protocol AudioPerformanceMonitoring: AnyObject, Sendable {
    func startMonitoring(updateInterval: TimeInterval) async
    func stopMonitoring() async
    func updateMonitoringInterval(_ interval: TimeInterval) async

    func getCurrentMetrics() async -> AudioMetrics

    func attachToEngine(_ engine: AudioEngineService) async
    func detachFromEngine() async
}
