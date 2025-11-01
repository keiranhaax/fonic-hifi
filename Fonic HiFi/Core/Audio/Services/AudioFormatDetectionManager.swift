//
//  AudioFormatDetectionManager.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

@preconcurrency import AVFoundation
import Foundation
import OSLog

/// Concrete implementation of FormatDetectionService using AVAsset
public actor AudioFormatDetectionManager: FormatDetectionService {
    // MARK: - Properties

    /// Shared instance
    public static let shared = AudioFormatDetectionManager()

    /// Registered format detection adapters
    private var adapters: [FormatDetectionAdapter]

    /// File manager for file operations
    private let fileManager = FileManager.default

    private let coordinator: FormatDetectionCoordinator
    private let logger: Logger

    // MARK: - Initialization

    public init(
        maxConcurrentDetections: Int = 4,
        timeout: TimeInterval? = 10.0,
        logger: Logger? = nil,
    ) {
        adapters = Self.defaultAdapters()
        self.logger = logger ?? Log.logger(.audioDetection)
        coordinator = FormatDetectionCoordinator(
            maxConcurrentDetections: maxConcurrentDetections,
            timeout: timeout,
            logger: self.logger,
        )
    }

    // MARK: - FormatDetectionService Implementation

    public func detectFormat(at url: URL) async throws -> AudioFileInfo {
        try Task.checkCancellation()

        // Validate file exists and is accessible
        guard fileManager.fileExists(atPath: url.path) else {
            throw DetectionError.fileNotFound(url)
        }

        guard fileManager.isReadableFile(atPath: url.path) else {
            throw DetectionError.accessDenied(url)
        }

        // Get file size
        let fileSize = try getFileSize(at: url)

        // Detect format from file extension
        guard let format = AudioFormat.from(url: url) else {
            throw DetectionError.unknownFormat(url)
        }

        let adapter = findAdapter(for: format)
        let manager = self

        return try await coordinator.performDetection(for: url) {
            try Task.checkCancellation()

            if let adapter {
                return try await adapter.detectFormat(at: url)
            }

            return try await manager.detectUsingAVAsset(url: url, format: format, fileSize: fileSize)
        }
    }

    public func validateFile(at url: URL) async -> Bool {
        do {
            _ = try await detectFormat(at: url)
            return true
        } catch {
            return false
        }
    }

    public func isFormatSupported(_ format: AudioFormat) -> Bool {
        // Check if AVAsset supports it or we have an adapter
        switch format {
        case .mp3, .aac, .alac, .wav, .aiff:
            true // AVAsset supports these
        case .flac, .ape, .dsd:
            findAdapter(for: format) != nil
        case .unknown:
            false
        }
    }

    public func getFormatCapabilities(_ format: AudioFormat) -> FormatCapabilities? {
        switch format {
        case .mp3:
            FormatCapabilities(
                maxSampleRate: 48000,
                maxBitDepth: 16,
                supportsMultiChannel: true,
                supportsArtwork: true,
                supportsChapters: false,
                requiresSpecializedDecoder: false,
            )

        case .aac:
            FormatCapabilities(
                maxSampleRate: 96000,
                maxBitDepth: 16,
                supportsMultiChannel: true,
                supportsArtwork: true,
                supportsChapters: true,
                requiresSpecializedDecoder: false,
            )

        case .alac:
            FormatCapabilities(
                maxSampleRate: 384_000,
                maxBitDepth: 32,
                supportsMultiChannel: true,
                supportsArtwork: true,
                supportsChapters: false,
                requiresSpecializedDecoder: false,
            )

        case .flac:
            FormatCapabilities(
                maxSampleRate: 655_350,
                maxBitDepth: 32,
                supportsMultiChannel: true,
                supportsArtwork: true,
                supportsChapters: false,
                requiresSpecializedDecoder: true,
            )

        case .wav, .aiff:
            FormatCapabilities(
                maxSampleRate: 384_000,
                maxBitDepth: 32,
                supportsMultiChannel: true,
                supportsArtwork: false,
                supportsChapters: false,
                requiresSpecializedDecoder: false,
            )

        case .ape:
            FormatCapabilities(
                maxSampleRate: 192_000,
                maxBitDepth: 24,
                supportsMultiChannel: true,
                supportsArtwork: true,
                supportsChapters: false,
                requiresSpecializedDecoder: true,
            )

        case .dsd:
            FormatCapabilities(
                maxSampleRate: 11_289_600, // DSD256
                maxBitDepth: 1,
                supportsMultiChannel: true,
                supportsArtwork: true,
                supportsChapters: false,
                requiresSpecializedDecoder: true,
            )

        case .unknown:
            nil
        }
    }

    // MARK: - Adapter Management

    /// Register a format detection adapter
    public func registerAdapter(_ adapter: FormatDetectionAdapter) {
        adapters.append(adapter)
    }

    /// Remove all registered adapters
    public func clearAdapters() {
        adapters.removeAll()
    }

    // MARK: - Private Methods

    private static func defaultAdapters() -> [FormatDetectionAdapter] {
        // Register default adapters here when available, for example:
        // [FLACDetectionAdapter()]
        []
    }

    private func findAdapter(for format: AudioFormat) -> FormatDetectionAdapter? {
        adapters.first { $0.supportedFormats.contains(format) }
    }

    private func detectUsingAVAsset(url: URL, format: AudioFormat, fileSize: Int64) async throws -> AudioFileInfo {
        try Task.checkCancellation()
        let asset = AVURLAsset(url: url)

        // Load required properties
        do {
            let duration = try await asset.load(.duration)
            let tracks = try await asset.load(.tracks)

            // Get audio track
            guard let audioTrack = tracks.first(where: { $0.mediaType == .audio }) else {
                throw DetectionError.invalidFile(reason: "No audio track found")
            }

            // Load audio format descriptions
            let formatDescriptions = try await audioTrack.load(.formatDescriptions)
            guard let formatDescription = formatDescriptions.first else {
                throw DetectionError.metadataExtractionFailed(reason: "No format description found")
            }

            // Extract audio properties
            let audioDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)

            let sampleRate = Int(audioDescription?.pointee.mSampleRate ?? 44100)
            let channels = Int(audioDescription?.pointee.mChannelsPerFrame ?? 2)
            let bitDepth = estimateBitDepth(from: audioDescription, format: format)

            // Calculate bitrate if possible
            let bitrate = try? await calculateBitrate(from: audioTrack, duration: duration, fileSize: fileSize)
            let normalizedBitrate = bitrate.map { UInt64($0) }

            return AudioFileInfo(
                url: url,
                format: format,
                duration: duration.seconds,
                bitDepth: UInt16(bitDepth),
                sampleRate: Double(sampleRate),
                channels: UInt8(channels),
                fileSize: UInt64(fileSize),
                bitrate: normalizedBitrate,
            )

        } catch {
            logger.error("avasset.load_failed url=\(url.lastPathComponent, privacy: .public) error=\(error.localizedDescription, privacy: .public)")
            throw DetectionError.assetLoadingFailed(error)
        }
    }

    private func estimateBitDepth(from description: UnsafePointer<AudioStreamBasicDescription>?, format: AudioFormat) -> Int {
        guard let desc = description?.pointee else {
            return format.maxBitDepth
        }

        // For PCM formats, we can calculate bit depth
        if desc.mFormatID == kAudioFormatLinearPCM {
            return Int(desc.mBitsPerChannel)
        }

        // For compressed formats, return typical bit depth
        switch format {
        case .mp3, .aac:
            return 16
        case .alac:
            // ALAC can be 16, 20, 24, or 32 bit
            let bytesPerFrame = desc.mBytesPerFrame
            let channelsPerFrame = desc.mChannelsPerFrame
            if channelsPerFrame > 0 {
                let bytesPerChannel = bytesPerFrame / channelsPerFrame
                return Int(bytesPerChannel * 8)
            }
            return 16
        default:
            return format.maxBitDepth
        }
    }

    private func calculateBitrate(from track: AVAssetTrack, duration: CMTime, fileSize: Int64) async throws -> Int {
        // For compressed formats, calculate average bitrate
        let durationSeconds = duration.seconds
        guard durationSeconds > 0 else { return 0 }

        // Try to get nominal bitrate first
        if let nominalBitRate = try? await track.load(.estimatedDataRate), nominalBitRate > 0 {
            return Int(nominalBitRate)
        }

        // Otherwise calculate from file size
        let bitsPerSecond = (Double(fileSize) * 8) / durationSeconds
        return Int(bitsPerSecond)
    }

    private func getFileSize(at url: URL) throws -> Int64 {
        let attributes = try fileManager.attributesOfItem(atPath: url.path)
        guard let fileSize = attributes[.size] as? NSNumber else {
            throw DetectionError.invalidFile(reason: "Cannot determine file size")
        }
        return fileSize.int64Value
    }
}
