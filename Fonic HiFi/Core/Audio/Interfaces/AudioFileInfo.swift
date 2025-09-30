//
//  AudioFileInfo.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import Foundation

/// Comprehensive metadata and format information for an audio file
@frozen
public struct AudioFileInfo: Sendable, Equatable, Hashable, Codable {
    // MARK: - Core Properties

    /// File URL location
    public let url: URL

    /// Audio format type (FLAC, MP3, etc.)
    public let format: AudioFormat

    /// Track duration in seconds
    public let duration: TimeInterval

    /// Bit depth (16, 24, 32 bits)
    public let bitDepth: UInt16

    /// Sample rate in Hz (44100, 96000, etc.)
    public let sampleRate: Double

    /// Number of audio channels (1=mono, 2=stereo, etc.)
    public let channels: UInt8

    /// File size in bytes
    public let fileSize: UInt64

    /// Bitrate in bits per second (optional for lossless formats)
    public let bitrate: UInt64?

    // MARK: - Metadata

    /// Key-value metadata extracted from the file
    public let metadata: [String: String]

    /// Audio codec used for encoding
    public let codec: String?

    /// Container format information
    public let container: String?

    /// Whether the file supports gapless playback
    public let supportsGapless: Bool

    /// File creation/modification timestamp
    public let timestamp: Date

    // MARK: - Computed Properties

    /// Whether this is a lossless audio format
    public var isLossless: Bool {
        format.isLossless
    }

    /// Whether this is a high-resolution audio file (>16-bit or >48kHz)
    public var isHighResolution: Bool {
        bitDepth > 16 || sampleRate > 48000
    }

    /// Formatted file size string (e.g., "45.2 MB")
    public var formattedFileSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }

    /// Formatted duration string (e.g., "3:45")
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// Formatted sample rate string (e.g., "96 kHz")
    public var formattedSampleRate: String {
        if sampleRate >= 1000 {
            String(format: "%.0f kHz", sampleRate / 1000)
        } else {
            String(format: "%.0f Hz", sampleRate)
        }
    }

    /// Formatted bit depth string (e.g., "24-bit")
    public var formattedBitDepth: String {
        "\(bitDepth)-bit"
    }

    /// Technical format description (e.g., "FLAC 96kHz/24-bit")
    public var technicalDescription: String {
        "\(format.displayName) \(formattedSampleRate)/\(formattedBitDepth)"
    }

    /// Quality rating based on format and resolution
    public var qualityRating: AudioQuality {
        if !isLossless {
            .standard
        } else if isHighResolution {
            .highResolution
        } else {
            .cd
        }
    }

    // MARK: - Metadata Accessors

    /// Track title from metadata
    public var title: String? {
        metadata["title"] ?? metadata["TIT2"]
    }

    /// Artist name from metadata
    public var artist: String? {
        metadata["artist"] ?? metadata["TPE1"]
    }

    /// Album name from metadata
    public var album: String? {
        metadata["album"] ?? metadata["TALB"]
    }

    /// Album artist from metadata
    public var albumArtist: String? {
        metadata["albumArtist"] ?? metadata["TPE2"]
    }

    /// Track number from metadata
    public var trackNumber: Int? {
        if let trackStr = metadata["trackNumber"] ?? metadata["TRCK"] {
            // Handle formats like "1" or "1/12"
            let components = trackStr.components(separatedBy: "/")
            return Int(components.first ?? "")
        }
        return nil
    }

    /// Total tracks from metadata
    public var totalTracks: Int? {
        if let trackStr = metadata["trackNumber"] ?? metadata["TRCK"] {
            let components = trackStr.components(separatedBy: "/")
            if components.count > 1 {
                return Int(components[1])
            }
        }
        return Int(metadata["totalTracks"] ?? "")
    }

    /// Disc number from metadata
    public var discNumber: Int? {
        Int(metadata["discNumber"] ?? metadata["TPOS"] ?? "")
    }

    /// Release year from metadata
    public var year: Int? {
        Int(metadata["year"] ?? metadata["TYER"] ?? metadata["TDRC"] ?? "")
    }

    /// Genre from metadata
    public var genre: String? {
        metadata["genre"] ?? metadata["TCON"]
    }

    /// Composer from metadata
    public var composer: String? {
        metadata["composer"] ?? metadata["TCOM"]
    }

    /// Comment from metadata
    public var comment: String? {
        metadata["comment"] ?? metadata["COMM"]
    }

    /// Artwork data (if embedded)
    public var hasArtwork: Bool {
        metadata.keys.contains { $0.lowercased().contains("artwork") || $0.lowercased().contains("picture") }
    }

    // MARK: - Initialization

    public init(
        url: URL,
        format: AudioFormat,
        duration: TimeInterval,
        bitDepth: UInt16,
        sampleRate: Double,
        channels: UInt8,
        fileSize: UInt64,
        bitrate: UInt64? = nil,
        metadata: [String: String] = [:],
        codec: String? = nil,
        container: String? = nil,
        supportsGapless: Bool = false,
        timestamp: Date = Date(),
    ) {
        self.url = url
        self.format = format
        self.duration = duration
        self.bitDepth = bitDepth
        self.sampleRate = sampleRate
        self.channels = channels
        self.fileSize = fileSize
        self.bitrate = bitrate
        self.metadata = metadata
        self.codec = codec
        self.container = container
        self.supportsGapless = supportsGapless
        self.timestamp = timestamp
    }

    // MARK: - Factory Methods

    /// Create AudioFileInfo for unknown/failed files
    public static func unknown(url: URL) -> AudioFileInfo {
        AudioFileInfo(
            url: url,
            format: .unknown,
            duration: 0,
            bitDepth: 0,
            sampleRate: 0,
            channels: 0,
            fileSize: 0,
            metadata: [:],
        )
    }

    /// Create AudioFileInfo with minimal information
    public static func minimal(
        url: URL,
        format: AudioFormat,
        duration: TimeInterval,
    ) -> AudioFileInfo {
        AudioFileInfo(
            url: url,
            format: format,
            duration: duration,
            bitDepth: 16,
            sampleRate: 44100,
            channels: 2,
            fileSize: 0,
            metadata: [:],
        )
    }
}

// MARK: - Supporting Types

/// Audio quality classification
public enum AudioQuality: String, Sendable, CaseIterable {
    case standard = "Standard"
    case cd = "CD Quality"
    case highResolution = "High Resolution"

    public var description: String {
        switch self {
        case .standard:
            "Standard quality (compressed)"
        case .cd:
            "CD quality (16-bit/44.1kHz lossless)"
        case .highResolution:
            "High resolution (>16-bit or >48kHz lossless)"
        }
    }

    public var shortDescription: String {
        switch self {
        case .standard:
            "Standard"
        case .cd:
            "CD"
        case .highResolution:
            "Hi-Res"
        }
    }
}

// MARK: - Extensions

// AudioFormat.isLossless is already defined in AudioFormat.swift

public extension AudioFileInfo {
    /// Create a copy with updated metadata
    func withMetadata(_ newMetadata: [String: String]) -> AudioFileInfo {
        AudioFileInfo(
            url: url,
            format: format,
            duration: duration,
            bitDepth: bitDepth,
            sampleRate: sampleRate,
            channels: channels,
            fileSize: fileSize,
            bitrate: bitrate,
            metadata: newMetadata,
            codec: codec,
            container: container,
            supportsGapless: supportsGapless,
            timestamp: timestamp,
        )
    }

    /// Create a copy with additional metadata
    func addingMetadata(_ additionalMetadata: [String: String]) -> AudioFileInfo {
        var newMetadata = metadata
        newMetadata.merge(additionalMetadata) { _, new in new }
        return withMetadata(newMetadata)
    }

    /// Validate that the file info contains essential data
    var isValid: Bool {
        !url.path.isEmpty &&
            format != .unknown &&
            duration > 0 &&
            bitDepth > 0 &&
            sampleRate > 0 &&
            channels > 0
    }

    /// Get a summary description suitable for debugging
    var debugDescription: String {
        """
        AudioFileInfo:
          URL: \(url.lastPathComponent)
          Format: \(technicalDescription)
          Duration: \(formattedDuration)
          Size: \(formattedFileSize)
          Quality: \(qualityRating.rawValue)
          Valid: \(isValid)
        """
    }
}
