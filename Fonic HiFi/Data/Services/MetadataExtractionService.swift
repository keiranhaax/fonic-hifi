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

/// Sendable metadata values captured in one pass from an AVAsset.
/// Keeping the snapshot value-only makes metadata loading injectable in tests
/// without sharing AVFoundation objects across concurrency domains.
struct MetadataItemSnapshot: Sendable {
    let commonKey: String?
    let identifier: String?
    let key: String?
    let stringValue: String?
    let dataValue: Data?
}

struct MetadataAssetSnapshot: Sendable {
    let duration: TimeInterval
    let metadata: [MetadataItemSnapshot]
    let commonMetadata: [MetadataItemSnapshot]
}

protocol MetadataAssetLoading: Sendable {
    func load(from url: URL) async throws -> MetadataAssetSnapshot
}

private struct AVAssetMetadataLoader: MetadataAssetLoading {
    func load(from url: URL) async throws -> MetadataAssetSnapshot {
        let asset = AVURLAsset(url: url)
        let duration = try await asset.load(.duration)
        let metadata = try await asset.load(.metadata)
        let commonMetadata = try await asset.load(.commonMetadata)

        return MetadataAssetSnapshot(
            duration: duration.seconds,
            metadata: await Self.snapshots(for: metadata),
            commonMetadata: await Self.snapshots(for: commonMetadata),
        )
    }

    private static func snapshots(for items: [AVMetadataItem]) async -> [MetadataItemSnapshot] {
        var snapshots: [MetadataItemSnapshot] = []
        snapshots.reserveCapacity(items.count)

        for item in items {
            let commonKey = item.commonKey?.rawValue
            let identifier = item.identifier?.rawValue
            let key = (item.key as? String) ?? (item.key as? NSString).map(String.init)
            let lowerKeys = [key, identifier]
                .compactMap { $0?.lowercased() }
            let needsStringValue = commonKey != nil || lowerKeys.contains { $0.contains("replaygain") }
            let needsDataValue = commonKey == AVMetadataKey.commonKeyArtwork.rawValue ||
                identifier == AVMetadataIdentifier.iTunesMetadataTrackNumber.rawValue ||
                identifier == AVMetadataIdentifier.iTunesMetadataDiscNumber.rawValue

            let stringValue = needsStringValue ? await Self.loadStringValue(from: item) : nil
            let dataValue = needsDataValue ? await Self.loadDataValue(from: item) : nil
            snapshots.append(MetadataItemSnapshot(
                commonKey: commonKey,
                identifier: identifier,
                key: key,
                stringValue: stringValue,
                dataValue: dataValue,
            ))
        }

        return snapshots
    }

    private static func loadStringValue(from item: AVMetadataItem) async -> String? {
        guard let value = try? await item.load(.value) else { return nil }
        if let string = value as? String { return string }
        if let string = value as? NSString { return String(string) }
        if let number = value as? NSNumber { return number.stringValue }
        if let date = value as? Date { return ISO8601DateFormatter().string(from: date) }
        return nil
    }

    private static func loadDataValue(from item: AVMetadataItem) async -> Data? {
        try? await item.load(.dataValue)
    }
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
    private let metadataLoader: any MetadataAssetLoading

    // MARK: - Initialization

    public convenience init(formatDetectionService: any FormatDetectionService) {
        self.init(
            formatDetectionService: formatDetectionService,
            metadataLoader: AVAssetMetadataLoader(),
        )
    }

    init(
        formatDetectionService: any FormatDetectionService,
        metadataLoader: any MetadataAssetLoading,
    ) {
        self.formatDetectionService = formatDetectionService
        self.metadataLoader = metadataLoader
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

        // Create AVAsset for format fallback. Metadata properties are loaded by
        // the value-only loader below so each property is requested once.
        let asset = AVURLAsset(url: url)

        let metadataSnapshot = try await metadataLoader.load(from: url)
        let durationInSeconds = metadataSnapshot.duration
        guard durationInSeconds.isFinite, durationInSeconds > 0 else {
            throw MetadataExtractionError.invalidFormat(url)
        }

        // Extract audio format information
        let audioFormat = try await extractAudioFormat(from: asset, url: url)

        // Parse metadata items
        let allMetadata = metadataSnapshot.commonMetadata + metadataSnapshot.metadata
        let metadataValues = parseMetadata(metadata: allMetadata)

        // Extract replay gain from all metadata (includes ID3v2 TXXX frames)
        let replayGain = extractReplayGain(from: allMetadata)
        let artwork = extractArtwork(from: metadataSnapshot.commonMetadata)

        guard audioFormat.sampleRate.isFinite, audioFormat.sampleRate > 0,
              audioFormat.bitrate >= 0, audioFormat.channels > 0,
              audioFormat.bitDepth > 0
        else {
            throw MetadataExtractionError.invalidFormat(url)
        }

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
        do {
            let detectedFormat = try await formatDetectionService.detectFormat(at: url)
            return AudioFormatInfo(
                format: detectedFormat.format.rawValue,
                sampleRate: Double(detectedFormat.sampleRate),
                bitDepth: Int(detectedFormat.bitDepth),
                bitrate: Int(detectedFormat.bitrate ?? 0),
                channels: Int(detectedFormat.channels),
                isLossless: detectedFormat.isLossless,
            )
        } catch {
            logger.warning(
                "Format detection failed for \(url.lastPathComponent, privacy: .private(mask: .hash)); using AVAsset fallback: \(error.localizedDescription, privacy: .private)"
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

    private func parseMetadata(metadata: [MetadataItemSnapshot]) -> MetadataValues {
        var values = MetadataValues()

        for item in metadata {
            guard let key = item.commonKey, let value = item.stringValue else { continue }

            switch key {
            case "title":
                values.title = value
            case "artist":
                values.artist = value
            case "albumName":
                values.album = value
            case "albumArtist":
                values.albumArtist = value
            case "type": // Genre
                values.genre = value
            case "creationDate":
                values.year = extractYear(from: value)
            case "composer":
                values.composer = value
            case "conductor":
                values.conductor = value
            case "description":
                values.comment = value
            default:
                break
            }
        }

        // Try to extract track/disc numbers from iTunes-style metadata
        for item in metadata {
            if let identifier = item.identifier {
                switch identifier {
                case AVMetadataIdentifier.iTunesMetadataTrackNumber.rawValue:
                    if let data = item.dataValue {
                        let tuple = parseITunesNumberTuple(data)
                        values.trackNumber = tuple.number
                        values.trackCount = tuple.total
                    }
                case AVMetadataIdentifier.iTunesMetadataDiscNumber.rawValue:
                    if let data = item.dataValue {
                        let tuple = parseITunesNumberTuple(data)
                        values.discNumber = tuple.number
                        values.discCount = tuple.total
                    }
                default:
                    break
                }
            }
        }

        return values
    }

    private func extractArtwork(from metadata: [MetadataItemSnapshot]) -> Data? {
        for item in metadata {
            guard item.commonKey == AVMetadataKey.commonKeyArtwork.rawValue,
                  let data = item.dataValue
            else { continue }

            // Compress before returning (thread-safe CoreGraphics)
            return ArtworkCompressor.compress(data)
        }

        return nil
    }

    private func extractYear(from dateString: String) -> Int? {
        // Try to extract year from various date formats
        let yearRegex = try? NSRegularExpression(pattern: "\\b(19|20)\\d{2}\\b")
        let range = NSRange(location: 0, length: dateString.utf16.count)

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
            let key = (item.key as? String) ?? (item.key as? NSString).map(String.init)
            let identifier = item.identifier?.rawValue
            let candidates = [key, identifier].compactMap { $0?.lowercased() }
            guard candidates.contains(where: { $0.contains("replaygain") }) else { continue }
            guard let value = await loadValue(from: item) as? String else { continue }

            if candidates.contains(where: { $0.contains("replaygain_track_gain") }) {
                trackGain = parseReplayGainValue(value)
            } else if candidates.contains(where: { $0.contains("replaygain_album_gain") }) {
                albumGain = parseReplayGainValue(value)
            }
        }

        return (trackGain, albumGain)
    }

    private func extractReplayGain(from metadata: [MetadataItemSnapshot]) -> (track: Float?, album: Float?) {
        var trackGain: Float?
        var albumGain: Float?

        for item in metadata {
            let candidates = [item.key, item.identifier].compactMap { $0?.lowercased() }
            guard let value = item.stringValue else { continue }
            if candidates.contains(where: { $0.contains("replaygain_track_gain") }) {
                trackGain = parseReplayGainValue(value)
            } else if candidates.contains(where: { $0.contains("replaygain_album_gain") }) {
                albumGain = parseReplayGainValue(value)
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
    var lyrics: String?
    var comment: String?
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
