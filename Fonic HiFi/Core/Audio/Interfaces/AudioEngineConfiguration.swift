//
//  AudioEngineConfiguration.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Configuration settings for audio engine initialization and operation
public struct AudioEngineConfiguration: Sendable {
    /// Buffer size in frames (affects latency vs CPU usage)
    public let bufferSize: Int
    
    /// Preferred sample rate in Hz (nil = use source rate)
    public let sampleRate: Double?
    
    /// Preferred bit depth (nil = use source depth)
    public let bitDepth: Int?
    
    /// Enable bit-perfect playback when possible
    public let enableBitPerfect: Bool
    
    /// Enable gapless playback between tracks
    public let enableGapless: Bool
    
    /// Performance mode affecting quality vs battery life
    public let performanceMode: PerformanceMode
    
    /// Maximum memory usage for buffering (in MB)
    public let maxBufferMemoryMB: Int
    
    /// Enable hardware acceleration when available
    public let enableHardwareAcceleration: Bool
    
    /// Fade duration for play/pause operations (0 = instant)
    public let fadeDuration: TimeInterval
    
    /// Default initializer with sensible defaults
    public init(
        bufferSize: Int = 512,
        sampleRate: Double? = nil,
        bitDepth: Int? = nil,
        enableBitPerfect: Bool = true,
        enableGapless: Bool = true,
        performanceMode: PerformanceMode = .balanced,
        maxBufferMemoryMB: Int = 100,
        enableHardwareAcceleration: Bool = true,
        fadeDuration: TimeInterval = 0.1
    ) {
        self.bufferSize = bufferSize
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.enableBitPerfect = enableBitPerfect
        self.enableGapless = enableGapless
        self.performanceMode = performanceMode
        self.maxBufferMemoryMB = maxBufferMemoryMB
        self.enableHardwareAcceleration = enableHardwareAcceleration
        self.fadeDuration = fadeDuration
    }
    
    /// Default configuration with balanced settings
    public static var `default`: AudioEngineConfiguration {
        return AudioEngineConfiguration()
    }
    
    /// Create configuration optimized for bit-perfect playback
    public static var bitPerfect: AudioEngineConfiguration {
        return AudioEngineConfiguration(
            bufferSize: 2048,
            enableBitPerfect: true,
            performanceMode: .quality,
            fadeDuration: 0
        )
    }
    
    /// Create configuration optimized for battery life
    public static var batterySaver: AudioEngineConfiguration {
        return AudioEngineConfiguration(
            bufferSize: 4096,
            enableBitPerfect: false,
            performanceMode: .efficiency,
            maxBufferMemoryMB: 50,
            enableHardwareAcceleration: false
        )
    }
    
    /// Create a copy with modified performance mode
    public func with(performanceMode: PerformanceMode) -> AudioEngineConfiguration {
        return AudioEngineConfiguration(
            bufferSize: self.bufferSize,
            sampleRate: self.sampleRate,
            bitDepth: self.bitDepth,
            enableBitPerfect: self.enableBitPerfect,
            enableGapless: self.enableGapless,
            performanceMode: performanceMode,
            maxBufferMemoryMB: self.maxBufferMemoryMB,
            enableHardwareAcceleration: self.enableHardwareAcceleration,
            fadeDuration: self.fadeDuration
        )
    }
}

/// Performance modes affecting quality vs resource usage
public enum PerformanceMode: String, CaseIterable, Sendable {
    /// Balanced performance and quality (default)
    case balanced = "balanced"
    
    /// Maximum quality, higher resource usage
    case quality = "quality"
    
    /// Maximum battery life, reduced features
    case efficiency = "efficiency"
    
    /// Display name for UI
    public var displayName: String {
        switch self {
        case .balanced:
            return "Balanced"
        case .quality:
            return "Maximum Quality"
        case .efficiency:
            return "Battery Saver"
        }
    }
    
    /// Description of what this mode does
    public var description: String {
        switch self {
        case .balanced:
            return "Optimal balance between quality and battery life"
        case .quality:
            return "Bit-perfect priority, full resolution waveforms"
        case .efficiency:
            return "Extended battery life, reduced visual effects"
        }
    }
}