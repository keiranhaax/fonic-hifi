//
//  AudioMetrics.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Describes how much of an engine metrics snapshot is backed by measurements.
public enum AudioMetricsAvailability: String, Sendable, Equatable, Codable {
    /// The engine exposes all fields represented by the snapshot.
    case available

    /// The engine exposes only a documented subset of fields.
    case partial

    /// The engine does not expose a metrics API.
    case unavailable

    public var supportsCollection: Bool {
        self != .unavailable
    }
}

/// Comprehensive performance metrics for audio playback monitoring
public struct AudioMetrics: Sendable, Equatable {
    /// Whether engine-specific values are fully, partially, or not measured.
    public let engineMetricsAvailability: AudioMetricsAvailability

    // MARK: - Core Performance Metrics

    /// CPU usage percentage (0-100)
    public let cpuUsage: Float

    /// Memory usage in bytes
    public let memoryUsage: Int64

    /// Number of buffer underruns since playback started
    public let bufferUnderruns: Int

    /// Average decoding latency in seconds
    public let decodingLatency: TimeInterval

    /// Current buffer fill level (0.0-1.0)
    public let bufferFillLevel: Float

    /// Number of frames dropped
    public let droppedFrames: Int

    /// Audio render latency in seconds
    public let renderLatency: TimeInterval

    /// Timestamp when metrics were captured
    public let timestamp: Date

    // MARK: - Extended Metrics

    /// Current bitrate in bits per second
    public let currentBitrate: Int64

    /// Average latency over measurement period
    public let averageLatency: TimeInterval

    /// Peak latency observed in this session
    public let peakLatency: TimeInterval

    /// Number of audio glitches detected
    public let glitchCount: Int

    /// Current sample rate in Hz
    public let sampleRate: Double

    /// Current bit depth
    public let bitDepth: Int

    /// Number of active channels
    public let channelCount: Int

    /// Engine type currently in use
    public let engineType: String

    /// Audio format being processed
    public let audioFormat: String

    /// Whether the engine's software state is bit-perfect eligible. This is not
    /// measured physical-output proof.
    public let isBitPerfect: Bool

    // MARK: - Buffer Management Metrics

    /// Size of audio buffer in frames
    public let bufferSize: Int

    /// Number of buffer resets/flushes
    public let bufferResets: Int

    /// Average buffer fill over time
    public let averageBufferFill: Float

    /// Buffer underrun rate (underruns per minute)
    public let underrunRate: Float

    /// Time since last buffer underrun
    public let timeSinceLastUnderrun: TimeInterval?

    // MARK: - System Resource Metrics

    /// Disk I/O operations per second
    public let diskIOPS: Float

    /// Network bandwidth usage (if streaming)
    public let networkBandwidth: Int64

    /// Thermal state impact on performance
    public let thermalPressure: Float

    /// Battery usage rate (mAh per hour)
    public let batteryUsageRate: Float?

    /// Thread utilization metrics
    public let threadUtilization: ThreadUtilization

    // MARK: - Quality Metrics

    /// Signal-to-noise ratio estimate
    public let estimatedSNR: Float?

    /// Dynamic range measurement
    public let dynamicRange: Float?

    /// Frequency response flatness score
    public let frequencyResponseScore: Float?

    /// Jitter measurement in samples
    public let jitter: Float

    /// Clock drift measurement
    public let clockDrift: Float

    // MARK: - Error and Recovery Metrics

    /// Number of recoverable errors
    public let recoverableErrors: Int

    /// Number of critical errors
    public let criticalErrors: Int

    /// Recovery success rate (0.0-1.0)
    public let recoverySuccessRate: Float

    /// Time to recover from last error
    public let lastRecoveryTime: TimeInterval?

    // MARK: - Performance Scores

    /// Overall performance score (0.0-1.0)
    public let performanceScore: Float

    /// Quality score (0.0-1.0)
    public let qualityScore: Float

    /// Reliability score (0.0-1.0)
    public let reliabilityScore: Float

    /// Efficiency score (0.0-1.0)
    public let efficiencyScore: Float

    // MARK: - Initialization

    public init(
        engineMetricsAvailability: AudioMetricsAvailability = .available,
        cpuUsage: Float,
        memoryUsage: Int64,
        bufferUnderruns: Int,
        decodingLatency: TimeInterval,
        bufferFillLevel: Float,
        droppedFrames: Int,
        renderLatency: TimeInterval,
        timestamp: Date = Date(),
        currentBitrate: Int64 = 0,
        averageLatency: TimeInterval = 0,
        peakLatency: TimeInterval = 0,
        glitchCount: Int = 0,
        sampleRate: Double = 44100,
        bitDepth: Int = 16,
        channelCount: Int = 2,
        engineType: String = "unknown",
        audioFormat: String = "unknown",
        isBitPerfect: Bool = false,
        bufferSize: Int = 512,
        bufferResets: Int = 0,
        averageBufferFill: Float = 1.0,
        underrunRate: Float = 0,
        timeSinceLastUnderrun: TimeInterval? = nil,
        diskIOPS: Float = 0,
        networkBandwidth: Int64 = 0,
        thermalPressure: Float = 0,
        batteryUsageRate: Float? = nil,
        threadUtilization: ThreadUtilization = ThreadUtilization(),
        estimatedSNR: Float? = nil,
        dynamicRange: Float? = nil,
        frequencyResponseScore: Float? = nil,
        jitter: Float = 0,
        clockDrift: Float = 0,
        recoverableErrors: Int = 0,
        criticalErrors: Int = 0,
        recoverySuccessRate: Float = 1.0,
        lastRecoveryTime: TimeInterval? = nil,
        performanceScore: Float = 1.0,
        qualityScore: Float = 1.0,
        reliabilityScore: Float = 1.0,
        efficiencyScore: Float = 1.0,
    ) {
        self.engineMetricsAvailability = engineMetricsAvailability
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.bufferUnderruns = bufferUnderruns
        self.decodingLatency = decodingLatency
        self.bufferFillLevel = bufferFillLevel
        self.droppedFrames = droppedFrames
        self.renderLatency = renderLatency
        self.timestamp = timestamp
        self.currentBitrate = currentBitrate
        self.averageLatency = averageLatency
        self.peakLatency = peakLatency
        self.glitchCount = glitchCount
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channelCount = channelCount
        self.engineType = engineType
        self.audioFormat = audioFormat
        self.isBitPerfect = isBitPerfect
        self.bufferSize = bufferSize
        self.bufferResets = bufferResets
        self.averageBufferFill = averageBufferFill
        self.underrunRate = underrunRate
        self.timeSinceLastUnderrun = timeSinceLastUnderrun
        self.diskIOPS = diskIOPS
        self.networkBandwidth = networkBandwidth
        self.thermalPressure = thermalPressure
        self.batteryUsageRate = batteryUsageRate
        self.threadUtilization = threadUtilization
        self.estimatedSNR = estimatedSNR
        self.dynamicRange = dynamicRange
        self.frequencyResponseScore = frequencyResponseScore
        self.jitter = jitter
        self.clockDrift = clockDrift
        self.recoverableErrors = recoverableErrors
        self.criticalErrors = criticalErrors
        self.recoverySuccessRate = recoverySuccessRate
        self.lastRecoveryTime = lastRecoveryTime
        self.performanceScore = performanceScore
        self.qualityScore = qualityScore
        self.reliabilityScore = reliabilityScore
        self.efficiencyScore = efficiencyScore
    }

    // MARK: - Factory Methods

    /// Empty metrics for initial state
    public static var empty: AudioMetrics {
        AudioMetrics(
            engineMetricsAvailability: .unavailable,
            cpuUsage: 0,
            memoryUsage: 0,
            bufferUnderruns: 0,
            decodingLatency: 0,
            bufferFillLevel: 1.0,
            droppedFrames: 0,
            renderLatency: 0,
        )
    }

    // MARK: - Computed Properties

    /// Indicates if playback performance is healthy
    public var isHealthy: Bool {
        bufferUnderruns == 0 &&
            droppedFrames == 0 &&
            bufferFillLevel > 0.5 &&
            cpuUsage < 80 &&
            criticalErrors == 0 &&
            performanceScore > 0.7
    }

    /// Overall health status based on metrics
    public var healthStatus: PlaybackHealthStatus {
        let score = performanceScore

        if score >= 0.9, isHealthy {
            return .excellent
        } else if score >= 0.75, bufferUnderruns == 0 {
            return .good
        } else if score >= 0.6, criticalErrors == 0 {
            return .fair
        } else if score >= 0.4 {
            return .poor
        } else {
            return .critical
        }
    }

    /// Human-readable memory usage
    public var formattedMemoryUsage: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: memoryUsage)
    }

    /// Human-readable bitrate
    public var formattedBitrate: String {
        let kbps = Float(currentBitrate) / 1000.0
        return String(format: "%.1f kbps", kbps)
    }

    /// Format specification string
    public var formatDescription: String {
        "\(audioFormat) • \(Int(sampleRate / 1000))kHz/\(bitDepth)-bit"
    }

    /// Performance summary string
    public var performanceSummary: String {
        "CPU: \(String(format: "%.1f", cpuUsage))% • Memory: \(formattedMemoryUsage) • Latency: \(String(format: "%.1f", renderLatency * 1000))ms"
    }

    /// Quality indicator based on multiple factors
    public var qualityIndicator: String {
        if isBitPerfect, bufferUnderruns == 0, droppedFrames == 0 {
            "Excellent"
        } else if bufferUnderruns == 0, droppedFrames < 5 {
            "Good"
        } else if bufferUnderruns < 3, droppedFrames < 20 {
            "Fair"
        } else {
            "Poor"
        }
    }

    /// Whether there are any critical issues
    public var hasCriticalIssues: Bool {
        criticalErrors > 0 ||
            cpuUsage > 95 ||
            bufferFillLevel < 0.1 ||
            thermalPressure > 0.8
    }

    /// Efficiency rating based on resource usage
    public var efficiencyRating: String {
        if cpuUsage < 20, (batteryUsageRate ?? 0) < 100 {
            "Excellent"
        } else if cpuUsage < 40, (batteryUsageRate ?? 0) < 200 {
            "Good"
        } else if cpuUsage < 60 {
            "Fair"
        } else {
            "Poor"
        }
    }

    // MARK: - Analysis Methods

    /// Generate performance insights
    public func generateInsights() -> [String] {
        var insights: [String] = []

        if bufferUnderruns > 0 {
            insights.append("Buffer underruns detected - consider increasing buffer size")
        }

        if cpuUsage > 80 {
            insights.append("High CPU usage - consider optimizing settings")
        }

        if thermalPressure > 0.6 {
            insights.append("Thermal pressure detected - performance may be throttled")
        }

        if droppedFrames > 10 {
            insights.append("Audio frames being dropped - check system load")
        }

        if renderLatency > 0.100 {
            insights.append("High render latency - audio processing may be delayed")
        }

        if !isBitPerfect, bitDepth > 16 {
            insights.append("Playback is not bit-perfect eligible for high-resolution audio")
        }

        if performanceScore < 0.7 {
            insights.append("Overall performance below optimal - review system configuration")
        }

        return insights
    }

    /// Compare with another metrics instance
    public func compare(with other: AudioMetrics) -> MetricsComparison {
        MetricsComparison(
            cpuUsageDelta: cpuUsage - other.cpuUsage,
            memoryUsageDelta: memoryUsage - other.memoryUsage,
            latencyDelta: renderLatency - other.renderLatency,
            bufferUnderrunsDelta: bufferUnderruns - other.bufferUnderruns,
            performanceScoreDelta: performanceScore - other.performanceScore,
            qualityScoreDelta: qualityScore - other.qualityScore,
            timeInterval: timestamp.timeIntervalSince(other.timestamp),
        )
    }
}

// MARK: - Supporting Types

/// Thread utilization metrics
public struct ThreadUtilization: Sendable, Equatable {
    /// Audio thread CPU usage
    public let audioThreadCPU: Float

    /// Decoder thread CPU usage
    public let decoderThreadCPU: Float

    /// I/O thread CPU usage
    public let ioThreadCPU: Float

    /// Main thread CPU usage for audio
    public let mainThreadCPU: Float

    /// Number of active audio threads
    public let activeThreadCount: Int

    /// Thread priority settings
    public let threadPriorities: [String: Float]

    public init(
        audioThreadCPU: Float = 0,
        decoderThreadCPU: Float = 0,
        ioThreadCPU: Float = 0,
        mainThreadCPU: Float = 0,
        activeThreadCount: Int = 1,
        threadPriorities: [String: Float] = [:],
    ) {
        self.audioThreadCPU = audioThreadCPU
        self.decoderThreadCPU = decoderThreadCPU
        self.ioThreadCPU = ioThreadCPU
        self.mainThreadCPU = mainThreadCPU
        self.activeThreadCount = activeThreadCount
        self.threadPriorities = threadPriorities
    }

    /// Total CPU usage across all audio threads
    public var totalCPUUsage: Float {
        audioThreadCPU + decoderThreadCPU + ioThreadCPU + mainThreadCPU
    }
}

/// Comparison result between two metrics instances
public struct MetricsComparison: Sendable {
    /// Change in CPU usage
    public let cpuUsageDelta: Float

    /// Change in memory usage
    public let memoryUsageDelta: Int64

    /// Change in latency
    public let latencyDelta: TimeInterval

    /// Change in buffer underruns
    public let bufferUnderrunsDelta: Int

    /// Change in performance score
    public let performanceScoreDelta: Float

    /// Change in quality score
    public let qualityScoreDelta: Float

    /// Time interval between measurements
    public let timeInterval: TimeInterval

    public init(
        cpuUsageDelta: Float,
        memoryUsageDelta: Int64,
        latencyDelta: TimeInterval,
        bufferUnderrunsDelta: Int,
        performanceScoreDelta: Float,
        qualityScoreDelta: Float,
        timeInterval: TimeInterval,
    ) {
        self.cpuUsageDelta = cpuUsageDelta
        self.memoryUsageDelta = memoryUsageDelta
        self.latencyDelta = latencyDelta
        self.bufferUnderrunsDelta = bufferUnderrunsDelta
        self.performanceScoreDelta = performanceScoreDelta
        self.qualityScoreDelta = qualityScoreDelta
        self.timeInterval = timeInterval
    }

    /// Whether performance has improved
    public var hasImproved: Bool {
        performanceScoreDelta > 0 &&
            cpuUsageDelta <= 0 &&
            bufferUnderrunsDelta <= 0
    }

    /// Whether performance has degraded
    public var hasDegraded: Bool {
        performanceScoreDelta < -0.1 ||
            cpuUsageDelta > 20 ||
            bufferUnderrunsDelta > 0
    }
}

/// Import PlaybackHealthStatus if it's in the monitoring service
public enum PlaybackHealthStatus: String, Sendable, CaseIterable {
    case excellent
    case good
    case fair
    case poor
    case critical
}
