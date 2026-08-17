//
//  AudioMonitoringService.swift
//  Fonic HiFi
//
//  Live monitoring models shared by the runtime collectors and alert manager.
//

import Foundation

/// Critical playback alert emitted by the monitoring runtime.
public struct PlaybackAlert: Sendable, Equatable {
    public let type: AlertType
    public let severity: AlertSeverity
    public let message: String
    public let technicalDetails: String
    public let timestamp: Date
    public let triggerValues: [String: Double]
    public let suggestedActions: [String]

    public init(
        type: AlertType,
        severity: AlertSeverity,
        message: String,
        technicalDetails: String,
        timestamp: Date = Date(),
        triggerValues: [String: Double] = [:],
        suggestedActions: [String] = []
    ) {
        self.type = type
        self.severity = severity
        self.message = message
        self.technicalDetails = technicalDetails
        self.timestamp = timestamp
        self.triggerValues = triggerValues
        self.suggestedActions = suggestedActions
    }
}

public enum AlertType: String, Sendable, CaseIterable {
    case bufferUnderrun = "buffer_underrun"
    case highCPUUsage = "high_cpu_usage"
    case highMemoryUsage = "high_memory_usage"
    case lowBufferFill = "low_buffer_fill"
    case audioDropout = "audio_dropout"
    case latencySpike = "latency_spike"
    case thermalThrottling = "thermal_throttling"
    case audioInterruption = "audio_interruption"
    case formatMismatch = "format_mismatch"
    case engineError = "engine_error"

    public var displayName: String {
        switch self {
        case .bufferUnderrun: "Buffer Underrun"
        case .highCPUUsage: "High CPU Usage"
        case .highMemoryUsage: "High Memory Usage"
        case .lowBufferFill: "Low Buffer Fill"
        case .audioDropout: "Audio Dropout"
        case .latencySpike: "Latency Spike"
        case .thermalThrottling: "Thermal Throttling"
        case .audioInterruption: "Audio Interruption"
        case .formatMismatch: "Format Mismatch"
        case .engineError: "Engine Error"
        }
    }
}

public enum AlertSeverity: String, Sendable, CaseIterable {
    case low
    case medium
    case high
    case critical

    public var priority: Int {
        switch self {
        case .low: 1
        case .medium: 2
        case .high: 3
        case .critical: 4
        }
    }
}

public struct AlertConfiguration: Sendable, Equatable {
    public let cpuThreshold: Float
    public let memoryThreshold: Int64
    public let bufferFillThreshold: Float
    public let maxBufferUnderruns: Int
    public let latencyThreshold: TimeInterval
    public let enableThermalMonitoring: Bool
    public let alertCooldownSeconds: TimeInterval

    public init(
        cpuThreshold: Float = 80.0,
        memoryThreshold: Int64 = PerformanceThresholds.targetMemoryUsage,
        bufferFillThreshold: Float = 0.3,
        maxBufferUnderruns: Int = 0,
        latencyThreshold: TimeInterval = 0.050,
        enableThermalMonitoring: Bool = true,
        alertCooldownSeconds: TimeInterval = 30.0
    ) {
        self.cpuThreshold = cpuThreshold
        self.memoryThreshold = memoryThreshold
        self.bufferFillThreshold = bufferFillThreshold
        self.maxBufferUnderruns = maxBufferUnderruns
        self.latencyThreshold = latencyThreshold
        self.enableThermalMonitoring = enableThermalMonitoring
        self.alertCooldownSeconds = alertCooldownSeconds
    }

    public static var `default`: AlertConfiguration {
        AlertConfiguration()
    }

    public static var sensitive: AlertConfiguration {
        AlertConfiguration(
            cpuThreshold: 50.0,
            memoryThreshold: 50_000_000,
            bufferFillThreshold: 0.5,
            maxBufferUnderruns: 0,
            latencyThreshold: 0.020,
            alertCooldownSeconds: 10.0
        )
    }
}

public struct SystemAudioMetrics: Sendable {
    public let systemAudioCPU: Float
    public let activeAudioSessions: Int
    public let systemAudioMemory: Int64
    public let deviceInfo: AudioDeviceInfo
    public let interruptionCount: Int
    public let audioUnitLoad: Float

    public init(
        systemAudioCPU: Float,
        activeAudioSessions: Int,
        systemAudioMemory: Int64,
        deviceInfo: AudioDeviceInfo,
        interruptionCount: Int,
        audioUnitLoad: Float
    ) {
        self.systemAudioCPU = systemAudioCPU
        self.activeAudioSessions = activeAudioSessions
        self.systemAudioMemory = systemAudioMemory
        self.deviceInfo = deviceInfo
        self.interruptionCount = interruptionCount
        self.audioUnitLoad = audioUnitLoad
    }
}

public struct AudioDeviceInfo: Sendable {
    public let deviceID: String
    public let name: String
    public let sampleRate: Double
    public let bitDepth: Int
    public let channels: Int
    public let bufferSize: Int
    public let latency: TimeInterval

    public init(
        deviceID: String,
        name: String,
        sampleRate: Double,
        bitDepth: Int,
        channels: Int,
        bufferSize: Int,
        latency: TimeInterval
    ) {
        self.deviceID = deviceID
        self.name = name
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.bufferSize = bufferSize
        self.latency = latency
    }
}

public struct ThermalMonitoringInfo: Sendable {
    public let thermalState: ThermalState
    public let cpuTemperature: Double?
    public let isThrottling: Bool
    public let recommendedAdjustments: [String]
    public let timestamp: Date

    public init(
        thermalState: ThermalState,
        cpuTemperature: Double? = nil,
        isThrottling: Bool,
        recommendedAdjustments: [String],
        timestamp: Date = Date()
    ) {
        self.thermalState = thermalState
        self.cpuTemperature = cpuTemperature
        self.isThrottling = isThrottling
        self.recommendedAdjustments = recommendedAdjustments
        self.timestamp = timestamp
    }
}

public enum ThermalState: String, Sendable, CaseIterable {
    case nominal
    case fair
    case serious
    case critical

    public var performanceImpact: String {
        switch self {
        case .nominal: "No impact"
        case .fair: "Minor performance reduction"
        case .serious: "Noticeable performance impact"
        case .critical: "Severe performance throttling"
        }
    }
}

public struct InterruptionStatistics: Sendable {
    public let totalInterruptions: Int
    public let interruptionsByType: [InterruptionType: Int]
    public let averageInterruptionDuration: TimeInterval
    public let longestInterruptionDuration: TimeInterval
    public let recoverySuccessRate: Double
    public let lastInterruptionTime: Date?

    public init(
        totalInterruptions: Int,
        interruptionsByType: [InterruptionType: Int],
        averageInterruptionDuration: TimeInterval,
        longestInterruptionDuration: TimeInterval,
        recoverySuccessRate: Double,
        lastInterruptionTime: Date?
    ) {
        self.totalInterruptions = totalInterruptions
        self.interruptionsByType = interruptionsByType
        self.averageInterruptionDuration = averageInterruptionDuration
        self.longestInterruptionDuration = longestInterruptionDuration
        self.recoverySuccessRate = recoverySuccessRate
        self.lastInterruptionTime = lastInterruptionTime
    }
}
