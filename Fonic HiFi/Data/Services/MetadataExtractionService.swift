//
//  MetadataExtractionService.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import AVFoundation
import Foundation
import OSLog

/// Service for extracting metadata from audio files into Sendable data structures
public protocol MetadataExtracting: Sendable {
    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata
    func extractMetadata(from urls: [URL], maxConcurrentTasks: Int) async throws -> [TrackMetadata]
}

extension MetadataExtracting {
    /// Extract metadata with default concurrency based on CPU cores
    func extractMetadata(from urls: [URL]) async throws -> [TrackMetadata] {
        try await extractMetadata(from: urls, maxConcurrentTasks: max(4, ProcessInfo.processInfo.activeProcessorCount))
    }
}

/// Service for extracting metadata from audio files into Sendable data structures
public final class MetadataExtractionService: ObservableObject, Sendable {
    private let logger = Log.logger(.dataMetadataExtraction)

    // MARK: - Properties

    /// Audio format detection service
    private let formatDetectionService: any FormatDetectionService

    // MARK: - Initialization

    public init(formatDetectionService: any FormatDetectionService) {
        self.formatDetectionService = formatDetectionService
    }

    // MARK: - Public Methods

    /// Extract metadata from an audio file into a Sendable struct
    /// - Parameter url: URL of the audio file
    /// - Returns: TrackMetadata with extracted information
    /// - Throws: MetadataExtractionError if extraction fails
    public func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        // Start security-scoped access if needed (returns false for app container files)
        let startedAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if startedAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw MetadataExtractionError.fileNotFound(url)
        }

        // Create AVAsset for metadata extraction
        let asset = AVURLAsset(url: url)

        // Extract duration
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)

        // Extract metadata
        let metadata = try await asset.load(.metadata)
        let commonMetadata = try await asset.load(.commonMetadata)

        // Extract audio format information
        let audioFormat = try await extractAudioFormat(from: asset, url: url)

        // Parse metadata items
        let metadataValues = try await parseMetadata(metadata: commonMetadata + metadata)

        // Extract replay gain from all metadata (includes ID3v2 TXXX frames)
        let replayGain = try await extractReplayGain(from: metadata)
        let artwork = try await extractArtwork(from: asset)

        // Create TrackMetadata with extracted information
        let trackMetadata = TrackMetadata(
            url: url,
            title: metadataValues.title ?? url.deletingPathExtension().lastPathComponent,
            artist: metadataValues.artist ?? "Unknown Artist",
            album: metadataValues.album ?? "Unknown Album",
            albumArtist: metadataValues.albumArtist,
            genre: metadataValues.genre,
            year: metadataValues.year,
            trackNumber: metadataValues.trackNumber,
            totalTracks: metadataValues.trackCount,
            discNumber: metadataValues.discNumber,
            totalDiscs: metadataValues.discCount,
            composer: metadataValues.composer,
            conductor: metadataValues.conductor,
            audioFormat: audioFormat.format,
            duration: durationInSeconds,
            sampleRate: audioFormat.sampleRate,
            bitDepth: audioFormat.bitDepth,
            bitrate: audioFormat.bitrate,
            channels: audioFormat.channels,
            isLossless: audioFormat.isLossless,
            artwork: artwork,
            lyrics: metadataValues.lyrics,
            comment: metadataValues.comment,
            replayGainTrack: replayGain.track,
            replayGainAlbum: replayGain.album,
        )

        return trackMetadata
    }

    /// Extract metadata from multiple files with bounded concurrency
    /// - Parameters:
    ///   - urls: Array of file URLs
    ///   - maxConcurrentTasks: Maximum concurrent extractions (scales with CPU cores)
    /// - Returns: Array of TrackMetadata
    public func extractMetadata(
        from urls: [URL],
        maxConcurrentTasks: Int = max(4, ProcessInfo.processInfo.activeProcessorCount)
    ) async throws -> [TrackMetadata] {
        try await withThrowingTaskGroup(of: TrackMetadata?.self) { group in
            var trackMetadata: [TrackMetadata] = []
            var iterator = urls.makeIterator()
            let concurrency = max(1, maxConcurrentTasks)

            // Launch initial batch
            for _ in 0..<concurrency {
                guard let url = iterator.next() else { break }
                group.addTask { [self] in
                    do {
                        return try await self.extractTrackMetadata(from: url)
                    } catch {
                        let filename = url.lastPathComponent
                        let details = error.localizedDescription
                        self.logger.error(
                            """
                            Failed to extract metadata from \(filename, privacy: .private(mask: .hash)):
                            \(details, privacy: .private)
                            """
                        )
                        return nil
                    }
                }
            }

            // Process results and launch more as slots free up
            for try await metadata in group {
                if let metadata {
                    trackMetadata.append(metadata)
                }

                // Launch next task if available
                if let url = iterator.next() {
                    group.addTask { [self] in
                        do {
                            return try await self.extractTrackMetadata(from: url)
                        } catch {
                            let filename = url.lastPathComponent
                            let details = error.localizedDescription
                            self.logger.error(
                                """
                                Failed to extract metadata from \(filename, privacy: .private(mask: .hash)):
                                \(details, privacy: .private)
                                """
                            )
                            return nil
                        }
                    }
                }
            }

            return trackMetadata
        }
    }

    // MARK: - Private Methods

    private func extractAudioFormat(from asset: AVAsset, url: URL) async throws -> AudioFormatInfo {
        // Try to get format from our format detection service first
        if let detectedFormat = try? await formatDetectionService.detectFormat(at: url) {
            return AudioFormatInfo(
                format: detectedFormat.format.rawValue,
                sampleRate: Double(detectedFormat.sampleRate),
                bitDepth: Int(detectedFormat.bitDepth),
                bitrate: Int(detectedFormat.bitrate ?? 0),
                channels: Int(detectedFormat.channels),
                isLossless: detectedFormat.isLossless,
            )
        }

        // Fallback to AVAsset track information
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard let firstTrack = audioTracks.first else {
            throw MetadataExtractionError.noAudioTrack(url)
        }

        let formatDescriptions = try await firstTrack.load(.formatDescriptions)
        guard let formatDescription = formatDescriptions.first else {
            throw MetadataExtractionError.invalidFormat(url)
        }

        let audioStreamBasicDescription = CMAudioFormatDescriptionGetStreamBasicDescription(formatDescription)

        let sampleRate = audioStreamBasicDescription?.pointee.mSampleRate ?? 44100.0
        let channels = audioStreamBasicDescription?.pointee.mChannelsPerFrame ?? 2
        let bitsPerChannel = audioStreamBasicDescription?.pointee.mBitsPerChannel ?? 16

        // Estimate bitrate
        let estimatedBitrate = try await firstTrack.load(.estimatedDataRate)

        // Determine format from file extension
        let fileExtension = url.pathExtension.lowercased()
        let format = AudioFormatType.from(fileExtension: fileExtension)

        return AudioFormatInfo(
            format: format.rawValue,
            sampleRate: sampleRate,
            bitDepth: Int(bitsPerChannel),
            bitrate: Int(estimatedBitrate),
            channels: Int(channels),
            isLossless: format.isLossless,
        )
    }

    private func parseMetadata(metadata: [AVMetadataItem]) async throws -> MetadataValues {
        var values = MetadataValues()
        var customMetadata: [String: String] = [:]

        for item in metadata {
            guard let key = item.commonKey?.rawValue else { continue }
            guard let value = await loadValue(from: item) else { continue }

            switch key {
            case "title":
                values.title = value as? String
            case "artist":
                values.artist = value as? String
            case "albumName":
                values.album = value as? String
            case "albumArtist":
                values.albumArtist = value as? String
            case "type": // Genre
                values.genre = value as? String
            case "creationDate":
                if let dateString = value as? String {
                    values.year = extractYear(from: dateString)
                }
            case "composer":
                values.composer = value as? String
            case "conductor":
                values.conductor = value as? String
            case "lyricist":
                values.lyricist = value as? String
            case "copyrights":
                values.copyright = value as? String
            case "encodedBy":
                values.encodedBy = value as? String
            case "description":
                values.comment = value as? String
            default:
                // Store unknown metadata as custom metadata
                if let stringValue = value as? String {
                    customMetadata[key] = stringValue
                }
            }
        }

        // Try to extract track/disc numbers from iTunes-style metadata
        for item in metadata {
            if let identifier = item.identifier {
                switch identifier {
                case .iTunesMetadataTrackNumber:
                    if let data = await loadDataValue(from: item) {
                        let tuple = parseITunesNumberTuple(data)
                        values.trackNumber = tuple.number
                        values.trackCount = tuple.total
                    }
                case .iTunesMetadataDiscNumber:
                    if let data = await loadDataValue(from: item) {
                        let tuple = parseITunesNumberTuple(data)
                        values.discNumber = tuple.number
                        values.discCount = tuple.total
                    }
                default:
                    break
                }
            }
        }

        values.customMetadata = customMetadata
        return values
    }

    private func extractArtwork(from asset: AVAsset) async throws -> Data? {
        guard let metadata = try? await asset.load(.commonMetadata) else { return nil }

        for item in metadata {
            guard item.commonKey == .commonKeyArtwork,
                  let data = await loadDataValue(from: item)
            else { continue }

                // Compress before returning (thread-safe CoreGraphics)
                return ArtworkCompressor.compress(data)
        }

        return nil
    }

    private func extractYear(from dateString: String) -> Int? {
        // Try to extract year from various date formats
        let yearRegex = try? NSRegularExpression(pattern: "\\b(19|20)\\d{2}\\b")
        let range = NSRange(location: 0, length: dateString.count)

        if let match = yearRegex?.firstMatch(in: dateString, options: [], range: range),
           let matchRange = Range(match.range, in: dateString) {
            let yearString = String(dateString[matchRange])
            return Int(yearString)
        }

        return nil
    }

    func parseITunesNumberTuple(_ data: Data) -> (number: Int?, total: Int?) {
        (
            number: bigEndianUInt16(in: data, at: 2),
            total: bigEndianUInt16(in: data, at: 4)
        )
    }

    private func loadValue(from item: AVMetadataItem) async -> Any? {
        do {
            return try await item.load(.value)
        } catch {
            return nil
        }
    }

    private func loadDataValue(from item: AVMetadataItem) async -> Data? {
        do {
            return try await item.load(.dataValue)
        } catch {
            return nil
        }
    }

    private func bigEndianUInt16(in data: Data, at offset: Int) -> Int? {
        guard offset >= 0, data.count >= offset + MemoryLayout<UInt16>.size else {
            return nil
        }

        let rawValue = data.withUnsafeBytes { bytes in
            bytes.loadUnaligned(fromByteOffset: offset, as: UInt16.self)
        }
        let value = UInt16(bigEndian: rawValue)
        return value == 0 ? nil : Int(value)
    }

    /// Parses replay gain value from tag string (e.g., "-6.5 dB" -> -6.5)
    public func parseReplayGainValue(_ string: String?) -> Float? {
        guard let string = string else { return nil }

        // Remove "dB" suffix and whitespace
        let cleaned = string
            .replacingOccurrences(of: "dB", with: "", options: .caseInsensitive)
            .trimmingCharacters(in: .whitespaces)

        return Float(cleaned)
    }

    /// Extract replay gain tags from all metadata (ID3v2 TXXX, Vorbis comments, etc.)
    func extractReplayGain(from metadata: [AVMetadataItem]) async throws -> (track: Float?, album: Float?) {
        var trackGain: Float?
        var albumGain: Float?

        for item in metadata {
            // Check for ID3v2 TXXX frames and Vorbis comments
            if let key = item.key as? String {
                let keyLower = key.lowercased()
                let value = await loadValue(from: item) as? String

                if keyLower.contains("replaygain_track_gain") {
                    if let value {
                        trackGain = parseReplayGainValue(value)
                    }
                } else if keyLower.contains("replaygain_album_gain") {
                    if let value {
                        albumGain = parseReplayGainValue(value)
                    }
                }
            }

            // Check string value of key for identifiers
            if let identifier = item.identifier?.rawValue {
                let identifierLower = identifier.lowercased()
                let value = await loadValue(from: item) as? String

                if identifierLower.contains("replaygain_track_gain") {
                    if let value {
                        trackGain = parseReplayGainValue(value)
                    }
                } else if identifierLower.contains("replaygain_album_gain") {
                    if let value {
                        albumGain = parseReplayGainValue(value)
                    }
                }
            }
        }

        return (trackGain, albumGain)
    }
}

// MARK: - Supporting Types

private struct MetadataValues {
    var title: String?
    var artist: String?
    var album: String?
    var albumArtist: String?
    var genre: String?
    var year: Int?
    var trackNumber: Int?
    var trackCount: Int?
    var discNumber: Int?
    var discCount: Int?
    var composer: String?
    var conductor: String?
    var lyricist: String?
    var copyright: String?
    var encodedBy: String?
    var encoderSettings: String?
    var isrc: String?
    var musicBrainzTrackId: String?
    var musicBrainzArtistId: String?
    var musicBrainzAlbumId: String?
    var musicBrainzAlbumArtistId: String?
    var musicBrainzReleaseGroupId: String?
    var acoustidId: String?
    var lyrics: String?
    var comment: String?
    var customMetadata: [String: String] = [:]
}

private struct AudioFormatInfo {
    let format: String
    let sampleRate: Double
    let bitDepth: Int
    let bitrate: Int
    let channels: Int
    let isLossless: Bool
}

// MARK: - Error Types

public enum MetadataExtractionError: Error, LocalizedError {
    case fileNotFound(URL)
    case fileNotAccessible(URL)
    case noAudioTrack(URL)
    case invalidFormat(URL)
    case extractionFailed(URL, Error)

    public var errorDescription: String? {
        switch self {
        case let .fileNotFound(url):
            "File not found: \(url.lastPathComponent)"
        case let .fileNotAccessible(url):
            "Cannot access file: \(url.lastPathComponent)"
        case let .noAudioTrack(url):
            "No audio track found in: \(url.lastPathComponent)"
        case let .invalidFormat(url):
            "Invalid audio format: \(url.lastPathComponent)"
        case let .extractionFailed(url, error):
            "Failed to extract metadata from \(url.lastPathComponent): \(error.localizedDescription)"
        }
    }
}

// MARK: - Protocol Conformance

extension MetadataExtractionService: MetadataExtracting {}
