//
//  AudioPerformanceMonitoring.swift
//  Fonic HiFi
//
//  Focused interface for runtime monitoring, metrics, and profiling.
//

import Combine
import Foundation

@MainActor
public protocol AudioPerformanceMonitoring: AnyObject, Sendable {
    var metricsPublisher: AnyPublisher<AudioMetrics, Never> { get }

    func startMonitoring(updateInterval: TimeInterval) async
    func stopMonitoring() async
    var isMonitoring: Bool { get async }
    func updateMonitoringInterval(_ interval: TimeInterval) async

    func getCurrentMetrics() async -> AudioMetrics
    func getSystemAudioMetrics() async -> SystemAudioMetrics

    func attachToEngine(_ engine: AudioEngineService) async
    func detachFromEngine() async
    var currentEngine: AudioEngineService? { get async }

    func startProfiling(duration: TimeInterval?) async
    func stopProfiling() async
    func getProfilingResults() async -> PerformanceProfile?
    var isProfiling: Bool { get async }
}
