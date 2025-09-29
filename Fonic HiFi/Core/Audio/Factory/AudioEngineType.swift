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
            "Native Audio Engine"
        case .audioKitEngine:
            "AudioKit Engine"
        }
    }

    /// Description of engine capabilities
    public var description: String {
        switch self {
        case .avAudioEngine:
            "Hardware-accelerated playback for standard formats"
        case .audioKitEngine:
            "Enhanced audio engine with native scheduling and Combine integration"
        }
    }

    /// Formats this engine excels at
    public var preferredFormats: [AudioFormat] {
        switch self {
        case .avAudioEngine:
            [.mp3, .aac, .alac, .wav, .aiff]
        case .audioKitEngine:
            [.mp3, .aac, .alac, .wav, .aiff, .flac] // AudioKit handles most standard formats well
        }
    }

    /// Check if engine can handle a specific format
    public func canHandle(_ format: AudioFormat) -> Bool {
        switch self {
        case .avAudioEngine:
            AVAudioEngineConfig.isFormatNativelySupported(format)
        case .audioKitEngine:
            [.mp3, .aac, .alac, .wav, .aiff, .flac].contains(format)
        }
    }

    /// Performance characteristics
    public var performanceImpact: PerformanceImpact {
        switch self {
        case .avAudioEngine:
            .low
        case .audioKitEngine:
            .low // AudioKit is optimized and runs on audio thread
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
            1 ... 5
        case .medium:
            5 ... 15
        case .high:
            15 ... 30
        }
    }

    /// Battery impact description
    public var batteryImpactDescription: String {
        switch self {
        case .low:
            "Minimal battery impact"
        case .medium:
            "Moderate battery usage"
        case .high:
            "Higher battery consumption"
        }
    }
}
