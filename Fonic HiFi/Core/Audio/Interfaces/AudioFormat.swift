//
//  AudioFormat.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Represents all audio formats supported by Fonic HiFi
public enum AudioFormat: String, CaseIterable, Sendable {
    // MARK: - Lossy Formats
    case mp3 = "mp3"
    case aac = "aac"
    
    // MARK: - Lossless Formats
    case alac = "alac"
    case flac = "flac"
    case wav = "wav"
    case aiff = "aiff"
    
    // MARK: - High-Resolution Formats
    case ape = "ape"
    case dsd = "dsd"
    
    /// File extension for this format
    public var fileExtension: String {
        return rawValue
    }
    
    /// Display name for UI presentation
    public var displayName: String {
        switch self {
        case .mp3: return "MP3"
        case .aac: return "AAC"
        case .alac: return "Apple Lossless"
        case .flac: return "FLAC"
        case .wav: return "WAV"
        case .aiff: return "AIFF"
        case .ape: return "Monkey's Audio"
        case .dsd: return "DSD"
        }
    }
    
    /// Indicates if this format requires a specialized audio engine
    public var requiresSpecialEngine: Bool {
        switch self {
        case .flac, .ape, .dsd:
            return true
        default:
            return false
        }
    }
    
    /// Indicates if this is a lossless format
    public var isLossless: Bool {
        switch self {
        case .mp3, .aac:
            return false
        default:
            return true
        }
    }
    
    /// Indicates if this format supports high-resolution audio
    public var isHighResolution: Bool {
        switch self {
        case .flac, .wav, .aiff, .ape, .dsd:
            return true
        default:
            return false
        }
    }
    
    /// Maximum supported bit depth for this format
    public var maxBitDepth: Int {
        switch self {
        case .mp3, .aac:
            return 16
        case .alac, .flac, .wav, .aiff:
            return 32
        case .ape:
            return 24
        case .dsd:
            return 1 // DSD uses 1-bit samples
        }
    }
    
    /// Create AudioFormat from file URL
    /// - Parameter url: File URL to analyze
    /// - Returns: AudioFormat if recognized, nil otherwise
    public static func from(url: URL) -> AudioFormat? {
        let ext = url.pathExtension.lowercased()
        return AudioFormat(rawValue: ext)
    }
    
    /// All supported file extensions
    public static var supportedExtensions: [String] {
        return allCases.map { $0.fileExtension }
    }
}