//
//  AudioFormat.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Represents all audio formats supported by Fonic HiFi
public enum AudioFormat: String, CaseIterable, Sendable, Codable {
    // MARK: - Lossy Formats

    case mp3
    case aac

    // MARK: - Lossless Formats

    case alac
    case flac
    case wav
    case aiff

    // MARK: - High-Resolution Formats

    case ape
    case dsd

    // MARK: - Unknown Format

    case unknown

    /// File extension for this format
    public var fileExtension: String {
        rawValue
    }

    /// Display name for UI presentation
    public var displayName: String {
        switch self {
        case .mp3: "MP3"
        case .aac: "AAC"
        case .alac: "Apple Lossless"
        case .flac: "FLAC"
        case .wav: "WAV"
        case .aiff: "AIFF"
        case .ape: "Monkey's Audio"
        case .dsd: "DSD"
        case .unknown: "Unknown"
        }
    }

    /// Indicates if this format requires a specialized audio engine
    public var requiresSpecialEngine: Bool {
        switch self {
        case .flac, .ape, .dsd:
            true
        default:
            false
        }
    }

    /// Indicates if this is a lossless format
    public var isLossless: Bool {
        switch self {
        case .mp3, .aac:
            false
        default:
            true
        }
    }

    /// Indicates if this format supports high-resolution audio
    public var isHighResolution: Bool {
        switch self {
        case .flac, .wav, .aiff, .ape, .dsd:
            true
        default:
            false
        }
    }

    /// Maximum supported bit depth for this format
    public var maxBitDepth: Int {
        switch self {
        case .mp3, .aac:
            16
        case .alac, .flac, .wav, .aiff:
            32
        case .ape:
            24
        case .dsd:
            1 // DSD uses 1-bit samples
        case .unknown:
            16 // Default to 16-bit
        }
    }

    /// Create AudioFormat from file URL
    /// - Parameter url: File URL to analyze
    /// - Returns: AudioFormat if recognized, nil otherwise
    public static func from(url: URL) -> AudioFormat? {
        let ext = url.pathExtension.lowercased()
        switch ext {
        case "m4a": return .alac  // M4A container -> ALAC (matches AudioFormatType)
        case "aif": return .aiff  // Common alternate extension
        default: return AudioFormat(rawValue: ext)
        }
    }

    /// All supported file extensions
    public static var supportedExtensions: [String] {
        allCases.map(\.fileExtension)
    }
}
