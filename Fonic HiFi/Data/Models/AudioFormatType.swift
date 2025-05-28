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
        return rawValue
    }
    
    /// File extensions typically associated with this format
    public var fileExtensions: [String] {
        switch self {
        case .flac:
            return ["flac"]
        case .alac:
            return ["m4a", "alac"]
        case .aiff:
            return ["aiff", "aif"]
        case .wav:
            return ["wav"]
        case .ape:
            return ["ape"]
        case .dsd:
            return ["dsd", "dsf", "dff"]
        case .wavpack:
            return ["wv"]
        case .mp3:
            return ["mp3"]
        case .aac:
            return ["aac", "m4a"]
        case .ogg:
            return ["ogg"]
        case .opus:
            return ["opus"]
        case .unknown:
            return []
        }
    }
    
    /// Whether this format supports lossless compression
    public var isLossless: Bool {
        switch self {
        case .flac, .alac, .aiff, .wav, .ape, .dsd, .wavpack:
            return true
        case .mp3, .aac, .ogg, .opus, .unknown:
            return false
        }
    }
    
    /// Whether this format supports high-resolution audio
    public var supportsHighResolution: Bool {
        switch self {
        case .flac, .alac, .aiff, .wav, .dsd:
            return true
        case .ape, .wavpack:
            return true
        case .mp3, .aac, .ogg, .opus, .unknown:
            return false
        }
    }
    
    /// Maximum supported bit depth for this format
    public var maxBitDepth: Int {
        switch self {
        case .flac, .alac, .aiff, .wav:
            return 32
        case .dsd:
            return 1  // DSD uses 1-bit encoding
        case .ape, .wavpack:
            return 32
        case .mp3, .aac, .ogg, .opus:
            return 16  // Compressed formats are typically 16-bit equivalent
        case .unknown:
            return 16
        }
    }
    
    /// Maximum supported sample rate for this format (in Hz)
    public var maxSampleRate: Int {
        switch self {
        case .flac:
            return 655350  // Theoretical limit
        case .alac:
            return 384000
        case .aiff, .wav:
            return 192000  // Common upper limit
        case .dsd:
            return 11289600  // DSD256
        case .ape:
            return 192000
        case .wavpack:
            return 4294967295  // Theoretical limit
        case .mp3:
            return 48000
        case .aac:
            return 96000
        case .ogg:
            return 192000
        case .opus:
            return 48000
        case .unknown:
            return 48000
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
        return allCases.filter { $0.isLossless }
    }
    
    /// Get all compressed formats
    public static var compressedFormats: [AudioFormatType] {
        return allCases.filter { !$0.isLossless && $0 != .unknown }
    }
    
    /// Get all high-resolution capable formats
    public static var highResolutionFormats: [AudioFormatType] {
        return allCases.filter { $0.supportsHighResolution }
    }
}

// MARK: - CustomStringConvertible

extension AudioFormatType: CustomStringConvertible {
    public var description: String {
        return displayName
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