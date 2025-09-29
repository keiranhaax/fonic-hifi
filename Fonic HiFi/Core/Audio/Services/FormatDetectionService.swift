//
//  FormatDetectionService.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Errors that can occur during format detection
public enum DetectionError: LocalizedError, Sendable {
    /// File does not exist at the given URL
    case fileNotFound(URL)

    /// Cannot read file due to permissions
    case accessDenied(URL)

    /// File format is not recognized
    case unknownFormat(URL)

    /// File is corrupted or invalid
    case invalidFile(reason: String)

    /// Detection timed out
    case timeout

    /// AVAsset loading failed
    case assetLoadingFailed(Error)

    /// Metadata extraction failed
    case metadataExtractionFailed(reason: String)

    public var errorDescription: String? {
        switch self {
        case let .fileNotFound(url):
            "File not found: \(url.lastPathComponent)"
        case let .accessDenied(url):
            "Access denied: \(url.lastPathComponent)"
        case let .unknownFormat(url):
            "Unknown format: \(url.lastPathComponent)"
        case let .invalidFile(reason):
            "Invalid file: \(reason)"
        case .timeout:
            "Format detection timed out"
        case let .assetLoadingFailed(error):
            "Asset loading failed: \(error.localizedDescription)"
        case let .metadataExtractionFailed(reason):
            "Metadata extraction failed: \(reason)"
        }
    }
}

/// Protocol for audio format detection services
@MainActor
public protocol FormatDetectionService: Sendable {
    /// Detect format information from a file URL
    /// - Parameter url: Local file URL to analyze
    /// - Returns: Detailed audio format information
    /// - Throws: DetectionError if analysis fails
    func detectFormat(at url: URL) async throws -> AudioFileInfo

    /// Validate if a file is a valid audio file
    /// - Parameter url: Local file URL to validate
    /// - Returns: true if file is valid audio
    func validateFile(at url: URL) async -> Bool

    /// Check if a format is supported for detection
    /// - Parameter format: Audio format to check
    /// - Returns: true if format can be detected
    func isFormatSupported(_ format: AudioFormat) -> Bool

    /// Get detailed format capabilities
    /// - Parameter format: Audio format to query
    /// - Returns: Format capabilities or nil if unsupported
    func getFormatCapabilities(_ format: AudioFormat) -> FormatCapabilities?
}

/// Capabilities of a specific audio format
public struct FormatCapabilities: Sendable {
    /// Maximum supported sample rate in Hz
    public let maxSampleRate: Int

    /// Maximum supported bit depth
    public let maxBitDepth: Int

    /// Whether format supports multiple channels
    public let supportsMultiChannel: Bool

    /// Whether format supports embedded artwork
    public let supportsArtwork: Bool

    /// Whether format supports chapter markers
    public let supportsChapters: Bool

    /// Whether detection requires specialized decoder
    public let requiresSpecializedDecoder: Bool

    public init(
        maxSampleRate: Int,
        maxBitDepth: Int,
        supportsMultiChannel: Bool,
        supportsArtwork: Bool,
        supportsChapters: Bool,
        requiresSpecializedDecoder: Bool,
    ) {
        self.maxSampleRate = maxSampleRate
        self.maxBitDepth = maxBitDepth
        self.supportsMultiChannel = supportsMultiChannel
        self.supportsArtwork = supportsArtwork
        self.supportsChapters = supportsChapters
        self.requiresSpecializedDecoder = requiresSpecializedDecoder
    }
}

/// Protocol for format-specific detection adapters
public protocol FormatDetectionAdapter: Sendable {
    /// Formats this adapter can handle
    var supportedFormats: [AudioFormat] { get }

    /// Detect format using specialized decoder
    /// - Parameter url: File URL to analyze
    /// - Returns: Audio file information
    /// - Throws: DetectionError if detection fails
    func detectFormat(at url: URL) async throws -> AudioFileInfo
}

/// Extended audio format information for detection results
public extension AudioFileInfo {
    /// Create AudioFileInfo with common defaults
    static func create(
        url: URL,
        format: AudioFormat,
        sampleRate: Int = 44100,
        bitDepth: Int = 16,
        channels: Int = 2,
        bitrate: Int? = nil,
        duration: TimeInterval = 0,
        fileSize: Int64 = 0,
    ) -> AudioFileInfo {
        AudioFileInfo(
            url: url,
            format: format,
            duration: duration,
            bitDepth: UInt16(bitDepth),
            sampleRate: Double(sampleRate),
            channels: UInt8(channels),
            fileSize: UInt64(fileSize),
            bitrate: bitrate != nil ? UInt64(bitrate!) : nil,
        )
    }

    /// Human-readable format description
    var formatDescription: String {
        let formatName = format.displayName
        let quality = isHighResolution ? "Hi-Res" : "Standard"
        let details = "\(sampleRate / 1000)kHz/\(bitDepth)-bit"
        return "\(formatName) \(quality) (\(details))"
    }

    /// Estimated memory usage for decoding
    var estimatedMemoryUsage: Int64 {
        // Rough estimate: sample rate * bit depth * channels * duration
        let bytesPerSample = Int64(bitDepth) / 8
        let samplesPerSecond = sampleRate * Double(channels)
        let totalSamples = Int64(samplesPerSecond) * Int64(duration)
        return totalSamples * bytesPerSample
    }
}
