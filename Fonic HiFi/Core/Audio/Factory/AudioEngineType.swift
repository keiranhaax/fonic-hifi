//
//  AudioEngineType.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Types of audio engines available in the system
public enum AudioEngineType: String, CaseIterable, Sendable {
    /// Apple's native AVAudioEngine (default)
    case avAudioEngine = "AVAudioEngine"
    
    /// AudioKit-based engine for enhanced audio features and better scheduling
    case audioKitEngine = "AudioKitEngine"
    
    /// SFBAudioEngine for high-res and specialized formats
    case sfbAudioEngine = "SFBAudioEngine"
    
    /// FFmpeg-based engine for universal format support
    case ffmpegEngine = "FFmpegEngine"
    
    /// Display name for UI and logging
    public var displayName: String {
        switch self {
        case .avAudioEngine:
            return "Native Audio Engine"
        case .audioKitEngine:
            return "AudioKit Engine"
        case .sfbAudioEngine:
            return "High-Resolution Audio Engine"
        case .ffmpegEngine:
            return "Universal Audio Engine"
        }
    }
    
    /// Description of engine capabilities
    public var description: String {
        switch self {
        case .avAudioEngine:
            return "Hardware-accelerated playback for standard formats"
        case .audioKitEngine:
            return "Enhanced audio engine with native scheduling and Combine integration"
        case .sfbAudioEngine:
            return "Bit-perfect playback for FLAC, DSD, and high-res audio"
        case .ffmpegEngine:
            return "Fallback engine supporting all audio formats"
        }
    }
    
    /// Formats this engine excels at
    public var preferredFormats: [AudioFormat] {
        switch self {
        case .avAudioEngine:
            return [.mp3, .aac, .alac, .wav, .aiff]
        case .audioKitEngine:
            return [.mp3, .aac, .alac, .wav, .aiff, .flac] // AudioKit handles most standard formats well
        case .sfbAudioEngine:
            return [.flac, .dsd, .ape]
        case .ffmpegEngine:
            return AudioFormat.allCases // Can handle everything
        }
    }
    
    /// Check if engine can handle a specific format
    public func canHandle(_ format: AudioFormat) -> Bool {
        switch self {
        case .avAudioEngine:
            return AVAudioEngineConfig.isFormatNativelySupported(format)
        case .audioKitEngine:
            return [.mp3, .aac, .alac, .wav, .aiff, .flac].contains(format)
        case .sfbAudioEngine:
            return [.flac, .dsd, .ape, .wav, .aiff].contains(format)
        case .ffmpegEngine:
            return true // FFmpeg can handle all formats
        }
    }
    
    /// Performance characteristics
    public var performanceImpact: PerformanceImpact {
        switch self {
        case .avAudioEngine:
            return .low
        case .audioKitEngine:
            return .low // AudioKit is optimized and runs on audio thread
        case .sfbAudioEngine:
            return .medium
        case .ffmpegEngine:
            return .high
        }
    }
}

/// Performance impact of using a specific engine
public enum PerformanceImpact: String, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    
    /// CPU usage expectation
    public var cpuUsageRange: ClosedRange<Float> {
        switch self {
        case .low:
            return 1...5
        case .medium:
            return 5...15
        case .high:
            return 15...30
        }
    }
    
    /// Battery impact description
    public var batteryImpactDescription: String {
        switch self {
        case .low:
            return "Minimal battery impact"
        case .medium:
            return "Moderate battery usage"
        case .high:
            return "Higher battery consumption"
        }
    }
}