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

    /// Crossfade duration between tracks (0 = gapless fallback)
    public let crossfadeDuration: TimeInterval

    /// Replay gain mode for loudness normalization
    public let replayGainMode: ReplayGainMode

    /// Playback rate multiplier (1.0 = normal speed)
    public let playbackRate: Double

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
        fadeDuration: TimeInterval = 0.1,
        crossfadeDuration: TimeInterval = 0,
        replayGainMode: ReplayGainMode = .off,
        playbackRate: Double = 1.0,
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
        self.crossfadeDuration = crossfadeDuration
        self.replayGainMode = replayGainMode
        self.playbackRate = playbackRate
    }

    /// Default configuration with balanced settings
    public static var `default`: AudioEngineConfiguration {
        AudioEngineConfiguration()
    }

    /// Create configuration optimized for bit-perfect playback
    public static var bitPerfect: AudioEngineConfiguration {
        AudioEngineConfiguration(
            bufferSize: 2048,
            enableBitPerfect: true,
            performanceMode: .quality,
            fadeDuration: 0,
        )
    }

    /// Create configuration optimized for battery life
    public static var batterySaver: AudioEngineConfiguration {
        AudioEngineConfiguration(
            bufferSize: 4096,
            enableBitPerfect: false,
            performanceMode: .efficiency,
            maxBufferMemoryMB: 50,
            enableHardwareAcceleration: false,
        )
    }

    /// Create a copy with modified performance mode
    public func with(performanceMode: PerformanceMode) -> AudioEngineConfiguration {
        AudioEngineConfiguration(
            bufferSize: bufferSize,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            enableBitPerfect: enableBitPerfect,
            enableGapless: enableGapless,
            performanceMode: performanceMode,
            maxBufferMemoryMB: maxBufferMemoryMB,
            enableHardwareAcceleration: enableHardwareAcceleration,
            fadeDuration: fadeDuration,
            crossfadeDuration: crossfadeDuration,
            replayGainMode: replayGainMode,
            playbackRate: playbackRate,
        )
    }

    /// Create a copy with modified crossfade duration
    public func with(crossfadeDuration: TimeInterval) -> AudioEngineConfiguration {
        AudioEngineConfiguration(
            bufferSize: bufferSize,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            enableBitPerfect: enableBitPerfect,
            enableGapless: enableGapless,
            performanceMode: performanceMode,
            maxBufferMemoryMB: maxBufferMemoryMB,
            enableHardwareAcceleration: enableHardwareAcceleration,
            fadeDuration: fadeDuration,
            crossfadeDuration: crossfadeDuration,
            replayGainMode: replayGainMode,
            playbackRate: playbackRate,
        )
    }

    /// Create a copy with modified replay gain mode
    public func with(replayGainMode: ReplayGainMode) -> AudioEngineConfiguration {
        AudioEngineConfiguration(
            bufferSize: bufferSize,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            enableBitPerfect: enableBitPerfect,
            enableGapless: enableGapless,
            performanceMode: performanceMode,
            maxBufferMemoryMB: maxBufferMemoryMB,
            enableHardwareAcceleration: enableHardwareAcceleration,
            fadeDuration: fadeDuration,
            crossfadeDuration: crossfadeDuration,
            replayGainMode: replayGainMode,
            playbackRate: playbackRate,
        )
    }

    /// Create a copy with modified playback rate
    public func with(playbackRate: Double) -> AudioEngineConfiguration {
        AudioEngineConfiguration(
            bufferSize: bufferSize,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            enableBitPerfect: enableBitPerfect,
            enableGapless: enableGapless,
            performanceMode: performanceMode,
            maxBufferMemoryMB: maxBufferMemoryMB,
            enableHardwareAcceleration: enableHardwareAcceleration,
            fadeDuration: fadeDuration,
            crossfadeDuration: crossfadeDuration,
            replayGainMode: replayGainMode,
            playbackRate: playbackRate,
        )
    }

    /// Create a copy with modified gapless playback setting
    public func with(enableGapless: Bool) -> AudioEngineConfiguration {
        AudioEngineConfiguration(
            bufferSize: bufferSize,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            enableBitPerfect: enableBitPerfect,
            enableGapless: enableGapless,
            performanceMode: performanceMode,
            maxBufferMemoryMB: maxBufferMemoryMB,
            enableHardwareAcceleration: enableHardwareAcceleration,
            fadeDuration: fadeDuration,
            crossfadeDuration: crossfadeDuration,
            replayGainMode: replayGainMode,
            playbackRate: playbackRate,
        )
    }
}

/// Replay gain configuration options
public enum ReplayGainMode: String, CaseIterable, Sendable {
    /// Replay gain disabled
    case off

    /// Use track-level metadata
    case track

    /// Use album-level metadata when available
    case album
}

/// Performance modes affecting quality vs resource usage
public enum PerformanceMode: String, CaseIterable, Sendable {
    /// Balanced performance and quality (default)
    case balanced

    /// Maximum quality, higher resource usage
    case quality

    /// Maximum battery life, reduced features
    case efficiency

    /// Display name for UI
    public var displayName: String {
        switch self {
        case .balanced:
            "Balanced"
        case .quality:
            "Maximum Quality"
        case .efficiency:
            "Battery Saver"
        }
    }

    /// Description of what this mode does
    public var description: String {
        switch self {
        case .balanced:
            "Optimal balance between quality and battery life"
        case .quality:
            "Bit-perfect priority, full resolution waveforms"
        case .efficiency:
            "Extended battery life, reduced visual effects"
        }
    }
}
