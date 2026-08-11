//
//  AudioMonitoringTypes.swift
//  Fonic HiFi
//
//  Created by Droid on 11/7/25.
//

import Foundation

@MainActor
protocol AudioMonitorRuntimeControlling: AnyObject {
    var updateInterval: TimeInterval { get }
    var isMonitoring: Bool { get }

    func startMonitoring(updateInterval: TimeInterval, engine: AudioEngineService?) async
    func stopMonitoring() async
    func updateMonitoringInterval(to interval: TimeInterval)
    func collectCurrentMetrics() async -> AudioMetrics
    func updateEngine(_ engine: AudioEngineService?)
    func invalidate()
}

@MainActor
protocol AudioMonitorEngineHooking: AnyObject {
    func setEngine(_ engine: AudioEngineService?)
    func startMonitoring(interval: TimeInterval)
    func stopMonitoring()
    func updateMonitoringInterval(to interval: TimeInterval)
}

/// Lightweight container for system resource metrics captured by the audio monitor.
public struct SystemMetrics: Sendable {
    public let cpuUsage: Float
    public let memoryUsage: Int64
    public let diskIOPS: Float
    public let networkBandwidth: Int64
    public let batteryUsageRate: Float?

    public static var baseline: SystemMetrics {
        SystemMetrics(
            cpuUsage: 0,
            memoryUsage: 0,
            diskIOPS: 0,
            networkBandwidth: 0,
            batteryUsageRate: nil,
        )
    }
}

/// Container for engine-specific playback metrics used during monitoring.
public struct EngineMetrics: Sendable {
    public var availability: AudioMetricsAvailability = .available
    public let bufferUnderruns: Int
    public let decodingLatency: TimeInterval
    public let bufferFillLevel: Float
    public let droppedFrames: Int
    public let renderLatency: TimeInterval
    public let currentBitrate: Int64
    public let glitchCount: Int
    public let sampleRate: Double
    public let bitDepth: Int
    public let channelCount: Int
    public let engineType: String
    public let audioFormat: String
    public let isBitPerfect: Bool
    public let bufferSize: Int
    public let bufferResets: Int
    public let threadUtilization: ThreadUtilization
    public let estimatedSNR: Float?
    public let dynamicRange: Float?
    public let frequencyResponseScore: Float?
    public let jitter: Float
    public let clockDrift: Float
    public let recoverableErrors: Int
    public let criticalErrors: Int
    public let recoverySuccessRate: Float
    public let lastRecoveryTime: TimeInterval?

    public static var `default`: EngineMetrics {
        var metrics = EngineMetrics(
            bufferUnderruns: 0,
            decodingLatency: 0,
            bufferFillLevel: 1.0,
            droppedFrames: 0,
            renderLatency: 0,
            currentBitrate: 0,
            glitchCount: 0,
            sampleRate: 44100,
            bitDepth: 16,
            channelCount: 2,
            engineType: "unknown",
            audioFormat: "unknown",
            isBitPerfect: false,
            bufferSize: 512,
            bufferResets: 0,
            threadUtilization: ThreadUtilization(),
            estimatedSNR: nil,
            dynamicRange: nil,
            frequencyResponseScore: nil,
            jitter: 0,
            clockDrift: 0,
            recoverableErrors: 0,
            criticalErrors: 0,
            recoverySuccessRate: 1.0,
            lastRecoveryTime: nil,
        )
        metrics.availability = .unavailable
        return metrics
    }
}

/// Internal interruption record for analytics tracking.
struct InterruptionRecord: Sendable {
    let type: InterruptionType
    let timestamp: Date
    let duration: TimeInterval
    let recoverySuccessful: Bool
}

/// Codable representation used when exporting metrics archives.
struct EncodedMetric: Codable, Sendable {
    let engineMetricsAvailability: AudioMetricsAvailability
    let timestamp: Date
    let cpuUsage: Float
    let memoryUsage: Int64
    let bufferFillLevel: Float
    let renderLatency: Double
    let performanceScore: Float
    let qualityScore: Float
    let isBitPerfect: Bool
    let bufferUnderruns: Int

    init(_ metric: AudioMetrics) {
        engineMetricsAvailability = metric.engineMetricsAvailability
        timestamp = metric.timestamp
        cpuUsage = metric.cpuUsage
        memoryUsage = metric.memoryUsage
        bufferFillLevel = metric.bufferFillLevel
        renderLatency = metric.renderLatency
        performanceScore = metric.performanceScore
        qualityScore = metric.qualityScore
        isBitPerfect = metric.isBitPerfect
        bufferUnderruns = metric.bufferUnderruns
    }
}
