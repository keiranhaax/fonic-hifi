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
    
    /// Display name for UI and logging
    public var displayName: String {
        switch self {
        case .avAudioEngine:
            return "Native Audio Engine"
        case .audioKitEngine:
            return "AudioKit Engine"
        }
    }
    
    /// Description of engine capabilities
    public var description: String {
        switch self {
        case .avAudioEngine:
            return "Hardware-accelerated playback for standard formats"
        case .audioKitEngine:
            return "Enhanced audio engine with native scheduling and Combine integration"
        }
    }
    
    /// Formats this engine excels at
    public var preferredFormats: [AudioFormat] {
        switch self {
        case .avAudioEngine:
            return [.mp3, .aac, .alac, .wav, .aiff]
        case .audioKitEngine:
            return [.mp3, .aac, .alac, .wav, .aiff, .flac] // AudioKit handles most standard formats well
        }
    }
    
    /// Check if engine can handle a specific format
    public func canHandle(_ format: AudioFormat) -> Bool {
        switch self {
        case .avAudioEngine:
            return AVAudioEngineConfig.isFormatNativelySupported(format)
        case .audioKitEngine:
            return [.mp3, .aac, .alac, .wav, .aiff, .flac].contains(format)
        }
    }
    
    /// Performance characteristics
    public var performanceImpact: PerformanceImpact {
        switch self {
        case .avAudioEngine:
            return .low
        case .audioKitEngine:
            return .low // AudioKit is optimized and runs on audio thread
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