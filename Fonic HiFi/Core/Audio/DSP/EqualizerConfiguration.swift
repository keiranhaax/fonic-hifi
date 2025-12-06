//
//  EqualizerConfiguration.swift
//  Fonic HiFi
//
//  10-band parametric equalizer configuration model
//

import Foundation

/// Represents a single band in a parametric equalizer
public struct EQBand: Codable, Equatable, Sendable {
    /// Center frequency in Hz
    public let frequency: Float

    /// Gain in dB (-12 to +12)
    public var gain: Float

    /// Bandwidth in octaves (typically 1.0)
    public var bandwidth: Float

    public init(frequency: Float, gain: Float = 0, bandwidth: Float = 1.0) {
        self.frequency = max(20, min(20000, frequency))  // Audible range
        self.gain = max(-12, min(12, gain))
        self.bandwidth = max(0.05, min(5.0, bandwidth))  // Apple's valid range [Verified-Apple]
    }
}

/// Configuration for a 10-band parametric equalizer
public struct EqualizerConfiguration: Codable, Equatable, Sendable {
    /// The EQ bands (10 bands at standard frequencies)
    public var bands: [EQBand]

    /// Whether the equalizer is enabled
    public var isEnabled: Bool

    /// Name of the current preset (if any)
    public var presetName: String?

    public init(bands: [EQBand], isEnabled: Bool, presetName: String? = nil) {
        self.bands = bands
        self.isEnabled = isEnabled
        self.presetName = presetName
    }

    /// Automatic preamp reduction to prevent clipping when boosting
    public var preampGain: Float {
        let maxBoost = bands.map { $0.gain }.max() ?? 0
        return maxBoost > 0 ? -maxBoost : 0
    }

    /// Default flat configuration with all bands at 0 dB
    public static let `default` = EqualizerConfiguration(
        bands: [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000].map {
            EQBand(frequency: $0)
        },
        isEnabled: false,
        presetName: "Flat"
    )

    /// Standard EQ presets
    public static let presets: [String: EqualizerConfiguration] = [
        "Flat": .default,
        "Bass Boost": EqualizerConfiguration(
            bands: [
                EQBand(frequency: 32, gain: 6),
                EQBand(frequency: 64, gain: 5),
                EQBand(frequency: 125, gain: 4),
                EQBand(frequency: 250, gain: 2),
                EQBand(frequency: 500, gain: 0),
                EQBand(frequency: 1000, gain: 0),
                EQBand(frequency: 2000, gain: 0),
                EQBand(frequency: 4000, gain: 0),
                EQBand(frequency: 8000, gain: 0),
                EQBand(frequency: 16000, gain: 0),
            ],
            isEnabled: true,
            presetName: "Bass Boost"
        ),
        "Treble Boost": EqualizerConfiguration(
            bands: [
                EQBand(frequency: 32, gain: 0),
                EQBand(frequency: 64, gain: 0),
                EQBand(frequency: 125, gain: 0),
                EQBand(frequency: 250, gain: 0),
                EQBand(frequency: 500, gain: 0),
                EQBand(frequency: 1000, gain: 0),
                EQBand(frequency: 2000, gain: 2),
                EQBand(frequency: 4000, gain: 4),
                EQBand(frequency: 8000, gain: 5),
                EQBand(frequency: 16000, gain: 6),
            ],
            isEnabled: true,
            presetName: "Treble Boost"
        ),
        "Vocal": EqualizerConfiguration(
            bands: [
                EQBand(frequency: 32, gain: -2),
                EQBand(frequency: 64, gain: -1),
                EQBand(frequency: 125, gain: 0),
                EQBand(frequency: 250, gain: 2),
                EQBand(frequency: 500, gain: 4),
                EQBand(frequency: 1000, gain: 4),
                EQBand(frequency: 2000, gain: 3),
                EQBand(frequency: 4000, gain: 2),
                EQBand(frequency: 8000, gain: 0),
                EQBand(frequency: 16000, gain: -1),
            ],
            isEnabled: true,
            presetName: "Vocal"
        ),
        "Rock": EqualizerConfiguration(
            bands: [
                EQBand(frequency: 32, gain: 4),
                EQBand(frequency: 64, gain: 3),
                EQBand(frequency: 125, gain: 2),
                EQBand(frequency: 250, gain: 0),
                EQBand(frequency: 500, gain: -2),
                EQBand(frequency: 1000, gain: -1),
                EQBand(frequency: 2000, gain: 1),
                EQBand(frequency: 4000, gain: 3),
                EQBand(frequency: 8000, gain: 4),
                EQBand(frequency: 16000, gain: 4),
            ],
            isEnabled: true,
            presetName: "Rock"
        ),
    ]
}
