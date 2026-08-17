//
//  AudioFormatDetectionManager.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import AudioToolbox
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
        guard fileSize > 0 else {
            throw DetectionError.invalidFile(reason: "Audio file is empty")
        }

        // Detect format from file extension
        guard let format = AudioFormat.from(url: url) else {
            throw DetectionError.unknownFormat(url)
        }

        let adapter = findAdapter(for: format)
        let manager = self

        return try await coordinator.performDetection(for: url) {
            try Task.checkCancellation()

            if let adapter {
                let info = try await adapter.detectFormat(at: url)
                guard info.isValid else {
                    throw DetectionError.invalidFile(reason: "Audio file contains invalid format metadata")
                }
                return info
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
        case .mp3, .aac, .alac, .flac, .wav, .aiff:
            true // AVAsset supports these
        case .ape, .dsd:
            false
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
            let detectedFormat = detectCodec(
                from: audioDescription,
                extensionFormat: format,
            )
            let bitDepth = estimateBitDepth(
                at: url,
                from: audioDescription,
                format: detectedFormat
            )

            // Calculate bitrate if possible
            let bitrate = try? await calculateBitrate(from: audioTrack, duration: duration, fileSize: fileSize)
            let normalizedBitrate = bitrate.map { UInt64($0) }

            let info = AudioFileInfo(
                url: url,
                format: detectedFormat,
                duration: duration.seconds,
                bitDepth: UInt16(bitDepth),
                sampleRate: Double(sampleRate),
                channels: UInt8(channels),
                fileSize: UInt64(fileSize),
                bitrate: normalizedBitrate,
                codec: detectedFormat.displayName,
                container: url.pathExtension.lowercased(),
            )

            guard info.isValid else {
                throw DetectionError.invalidFile(reason: "Audio file contains invalid format metadata")
            }

            return info

        } catch {
            logger.error("avasset.load_failed url=\(url.lastPathComponent, privacy: .private(mask: .hash)) error=\(error.localizedDescription, privacy: .private)")
            if error is CancellationError {
                throw error
            }
            if let detectionError = error as? DetectionError,
               case .invalidFile = detectionError {
                throw detectionError
            }
            throw DetectionError.invalidFile(reason: "Audio file could not be decoded")
        }
    }

    private func detectCodec(
        from description: UnsafePointer<AudioStreamBasicDescription>?,
        extensionFormat: AudioFormat,
    ) -> AudioFormat {
        guard let formatID = description?.pointee.mFormatID else {
            return extensionFormat
        }

        switch formatID {
        case kAudioFormatAppleLossless:
            return .alac
        case kAudioFormatMPEG4AAC,
             kAudioFormatMPEG4AAC_HE,
             kAudioFormatMPEG4AAC_HE_V2,
             kAudioFormatMPEG4AAC_LD,
             kAudioFormatMPEG4AAC_ELD:
            return .aac
        default:
            return extensionFormat
        }
    }

    private func estimateBitDepth(
        at url: URL,
        from description: UnsafePointer<AudioStreamBasicDescription>?,
        format: AudioFormat
    ) -> Int {
        if format == .flac || format == .alac,
           let sourceBitDepth = sourceBitDepth(at: url) {
            return sourceBitDepth
        }

        guard let desc = description?.pointee else {
            return fallbackBitDepth(for: format)
        }

        if desc.mFormatID == kAudioFormatLinearPCM, desc.mBitsPerChannel > 0 {
            return Int(desc.mBitsPerChannel)
        }

        if format == .flac, desc.mBitsPerChannel > 0 {
            return Int(desc.mBitsPerChannel)
        }

        if format == .alac {
            if desc.mBitsPerChannel > 0 {
                return Int(desc.mBitsPerChannel)
            }
            switch desc.mFormatFlags {
            case kAppleLosslessFormatFlag_16BitSourceData:
                return 16
            case kAppleLosslessFormatFlag_20BitSourceData:
                return 20
            case kAppleLosslessFormatFlag_24BitSourceData:
                return 24
            case kAppleLosslessFormatFlag_32BitSourceData:
                return 32
            default:
                break
            }
        }

        return fallbackBitDepth(for: format)
    }

    private func sourceBitDepth(at url: URL) -> Int? {
        var audioFile: AudioFileID?
        guard AudioFileOpenURL(url as CFURL, .readPermission, 0, &audioFile) == noErr,
              let audioFile else {
            return nil
        }
        defer { AudioFileClose(audioFile) }

        var sourceBitDepth: Int32 = 0
        var propertySize = UInt32(MemoryLayout.size(ofValue: sourceBitDepth))
        guard AudioFileGetProperty(
            audioFile,
            kAudioFilePropertySourceBitDepth,
            &propertySize,
            &sourceBitDepth
        ) == noErr else {
            return nil
        }

        let normalizedBitDepth = Int(sourceBitDepth.magnitude)
        return normalizedBitDepth > 0 ? normalizedBitDepth : nil
    }

    private func fallbackBitDepth(for format: AudioFormat) -> Int {
        switch format {
        case .mp3, .aac:
            return 16
        case .alac:
            // Source depth is normally available through the AudioFile property
            // or the Apple Lossless ASBD flags. Stay conservative if neither is present.
            return 16
        case .flac:
            // A format family's maximum is not evidence of the encoded source depth.
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
