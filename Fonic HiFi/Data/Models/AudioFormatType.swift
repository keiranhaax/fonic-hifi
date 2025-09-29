//
//  AudioFormatType.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation

/// Enumeration of supported audio format types
public enum AudioFormatType: String, CaseIterable, Codable {
    // Lossless formats
    case flac = "FLAC"
    case alac = "ALAC"
    case aiff = "AIFF"
    case wav = "WAV"
    case ape = "APE"
    case dsd = "DSD"
    case wavpack = "WavPack"

    // Compressed formats
    case mp3 = "MP3"
    case aac = "AAC"
    case ogg = "Ogg Vorbis"
    case opus = "Opus"

    // Unknown/unsupported
    case unknown = "Unknown"

    /// Display name for the format
    public var displayName: String {
        rawValue
    }

    /// File extensions typically associated with this format
    public var fileExtensions: [String] {
        switch self {
        case .flac:
            ["flac"]
        case .alac:
            ["m4a", "alac"]
        case .aiff:
            ["aiff", "aif"]
        case .wav:
            ["wav"]
        case .ape:
            ["ape"]
        case .dsd:
            ["dsd", "dsf", "dff"]
        case .wavpack:
            ["wv"]
        case .mp3:
            ["mp3"]
        case .aac:
            ["aac", "m4a"]
        case .ogg:
            ["ogg"]
        case .opus:
            ["opus"]
        case .unknown:
            []
        }
    }

    /// Whether this format supports lossless compression
    public var isLossless: Bool {
        switch self {
        case .flac, .alac, .aiff, .wav, .ape, .dsd, .wavpack:
            true
        case .mp3, .aac, .ogg, .opus, .unknown:
            false
        }
    }

    /// Whether this format supports high-resolution audio
    public var supportsHighResolution: Bool {
        switch self {
        case .flac, .alac, .aiff, .wav, .dsd:
            true
        case .ape, .wavpack:
            true
        case .mp3, .aac, .ogg, .opus, .unknown:
            false
        }
    }

    /// Maximum supported bit depth for this format
    public var maxBitDepth: Int {
        switch self {
        case .flac, .alac, .aiff, .wav:
            32
        case .dsd:
            1 // DSD uses 1-bit encoding
        case .ape, .wavpack:
            32
        case .mp3, .aac, .ogg, .opus:
            16 // Compressed formats are typically 16-bit equivalent
        case .unknown:
            16
        }
    }

    /// Maximum supported sample rate for this format (in Hz)
    public var maxSampleRate: Int {
        switch self {
        case .flac:
            655_350 // Theoretical limit
        case .alac:
            384_000
        case .aiff, .wav:
            192_000 // Common upper limit
        case .dsd:
            11_289_600 // DSD256
        case .ape:
            192_000
        case .wavpack:
            4_294_967_295 // Theoretical limit
        case .mp3:
            48000
        case .aac:
            96000
        case .ogg:
            192_000
        case .opus:
            48000
        case .unknown:
            48000
        }
    }

    /// Create AudioFormatType from file extension
    /// - Parameter extension: File extension (without dot)
    /// - Returns: Corresponding AudioFormatType or .unknown
    public static func from(fileExtension: String) -> AudioFormatType {
        let lowercased = fileExtension.lowercased()

        for format in AudioFormatType.allCases {
            if format.fileExtensions.contains(lowercased) {
                return format
            }
        }

        return .unknown
    }

    /// Get all lossless formats
    public static var losslessFormats: [AudioFormatType] {
        allCases.filter(\.isLossless)
    }

    /// Get all compressed formats
    public static var compressedFormats: [AudioFormatType] {
        allCases.filter { !$0.isLossless && $0 != .unknown }
    }

    /// Get all high-resolution capable formats
    public static var highResolutionFormats: [AudioFormatType] {
        allCases.filter(\.supportsHighResolution)
    }
}

// MARK: - CustomStringConvertible

extension AudioFormatType: CustomStringConvertible {
    public var description: String {
        displayName
    }
}

// MARK: - Comparable

extension AudioFormatType: Comparable {
    public static func < (lhs: AudioFormatType, rhs: AudioFormatType) -> Bool {
        // Sort by quality: lossless first, then by max bit depth, then alphabetically
        if lhs.isLossless != rhs.isLossless {
            return lhs.isLossless && !rhs.isLossless
        }

        if lhs.maxBitDepth != rhs.maxBitDepth {
            return lhs.maxBitDepth > rhs.maxBitDepth
        }

        return lhs.displayName < rhs.displayName
    }
}
