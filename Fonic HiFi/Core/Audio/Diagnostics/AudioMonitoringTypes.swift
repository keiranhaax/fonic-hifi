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
    var isProfiling: Bool { get }

    func startMonitoring(updateInterval: TimeInterval, engine: AudioEngineService?) async
    func stopMonitoring() async
    func updateMonitoringInterval(to interval: TimeInterval)
    func collectCurrentMetrics() async -> AudioMetrics
    func evaluateAlerts() async
    func startProfiling(duration: TimeInterval?) async
    func stopProfiling() async
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

@MainActor
protocol AudioMonitorDiagnosticsBuilding: AnyObject {
    func makeDiagnostics(
        currentMetrics: AudioMetrics,
        latestMetric: AudioMetrics?,
        sessionSummary: AudioSessionSummary,
        alertHistory: [PlaybackAlert],
        runtime: AudioMonitorDiagnosticsBuilder.RuntimeSnapshot,
        engine: AudioEngineService?,
        metricsSampleCount: Int,
        systemHealth: DiagnosticHealthStatus
    ) async -> PlaybackDiagnostics
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
        EngineMetrics(
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

@MainActor
final class ProfilingData {
    var cpuSamples: [Float] = []
    var memorySamples: [Int64] = []
    var latencySamples: [TimeInterval] = []
    var bufferFillSamples: [Float] = []
    var sampleTimestamps: [Date] = []
    var underrunCount: Int = 0
    var lastKnownBufferUnderrunTotal: Int?

    var cpuProfile: CPUProfile {
        let avg = cpuSamples.isEmpty ? 0 : cpuSamples.reduce(0, +) / Float(cpuSamples.count)
        let peak = cpuSamples.max() ?? 0

        return CPUProfile(
            averageUsage: avg,
            peakUsage: peak,
            usageDistribution: cpuSamples,
            performanceStates: [:],
        )
    }

    var memoryProfile: MemoryProfile {
        let avg = memorySamples.isEmpty ? 0 : memorySamples.reduce(0, +) / Int64(memorySamples.count)
        let peak = memorySamples.max() ?? 0

        return MemoryProfile(
            averageUsage: avg,
            peakUsage: peak,
            allocationPatterns: [],
            leakIndicators: [],
        )
    }

    var latencyProfile: LatencyProfile {
        let avg = latencySamples.isEmpty ? 0 : latencySamples.reduce(0, +) / Double(latencySamples.count)
        let maxLatency = latencySamples.max() ?? 0
        let threshold = max(avg * 1.5, avg + 0.01)

        var spikes: [LatencySpike] = []
        for index in latencySamples.indices where latencySamples[index] > threshold {
            let timestamp = sampleTimestamps.indices.contains(index) ? sampleTimestamps[index] : Date()
            let previousTimestamp = index > 0 && sampleTimestamps.indices.contains(index - 1) ? sampleTimestamps[index - 1] : timestamp
            let duration = max(timestamp.timeIntervalSince(previousTimestamp), 0.1)
            let latency = latencySamples[index]
            let possibleCause: String? = if latency > 0.08 {
                "Decoder back-pressure"
            } else if latency > 0.05 {
                "Render scheduling delay"
            } else {
                nil
            }
            spikes.append(
                LatencySpike(
                    timestamp: timestamp,
                    duration: duration,
                    peakLatency: latency,
                    possibleCause: possibleCause,
                ),
            )
        }

        return LatencyProfile(
            averageLatency: avg,
            maxLatency: maxLatency,
            latencyDistribution: latencySamples,
            spikes: spikes,
        )
    }

    var bufferProfile: BufferProfile {
        let avg = bufferFillSamples.isEmpty ? 1.0 : bufferFillSamples.reduce(0, +) / Float(bufferFillSamples.count)
        let min = bufferFillSamples.min() ?? 1.0

        return BufferProfile(
            averageBufferFill: avg,
            minBufferFill: min,
            underrunCount: underrunCount,
            fillDistribution: bufferFillSamples,
        )
    }
}
