//
//  MetadataExtractionService.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

@preconcurrency import AVFoundation
import Foundation

/// Service for extracting metadata from audio files into Sendable data structures
public final class MetadataExtractionService: ObservableObject, Sendable {
    // MARK: - Properties

    /// Audio format detection service
    private let formatDetectionService: FormatDetectionService

    // MARK: - Initialization

    public init(formatDetectionService: FormatDetectionService) {
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

        // Extract basic file information
        let fileAttributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = fileAttributes[.size] as? Int64 ?? 0
        let dateAdded = fileAttributes[.creationDate] as? Date ?? Date()
        let dateModified = fileAttributes[.modificationDate] as? Date ?? Date()

        // Create AVAsset for metadata extraction
        let asset = AVAsset(url: url)

        // Extract duration
        let duration = try await asset.load(.duration)
        let durationInSeconds = CMTimeGetSeconds(duration)

        // Extract metadata
        let metadata = try await asset.load(.metadata)
        let commonMetadata = try await asset.load(.commonMetadata)

        // Extract audio format information
        let audioFormat = try await extractAudioFormat(from: asset, url: url)

        // Parse metadata items
        let metadataValues = parseMetadata(metadata: commonMetadata)

        // Create TrackMetadata with extracted information
        let trackMetadata = try await TrackMetadata(
            url: url,
            title: metadataValues.title ?? url.deletingPathExtension().lastPathComponent,
            artist: metadataValues.artist ?? "Unknown Artist",
            album: metadataValues.album ?? "Unknown Album",
            albumArtist: metadataValues.albumArtist,
            genre: metadataValues.genre,
            year: metadataValues.year,
            trackNumber: metadataValues.trackNumber,
            discNumber: metadataValues.discNumber,
            composer: metadataValues.composer,
            conductor: metadataValues.conductor,
            audioFormat: audioFormat.format,
            duration: durationInSeconds,
            sampleRate: audioFormat.sampleRate,
            bitDepth: audioFormat.bitDepth,
            bitrate: audioFormat.bitrate,
            channels: audioFormat.channels,
            isLossless: audioFormat.isLossless,
            artwork: extractArtwork(from: asset),
            lyrics: metadataValues.lyrics,
            comment: metadataValues.comment,
        )

        return trackMetadata
    }

    /// Extract metadata from multiple files concurrently
    /// - Parameter urls: Array of file URLs
    /// - Returns: Array of TrackMetadata
    public func extractMetadata(from urls: [URL]) async throws -> [TrackMetadata] {
        try await withThrowingTaskGroup(of: TrackMetadata?.self) { group in
            var trackMetadata: [TrackMetadata] = []

            for url in urls {
                group.addTask {
                    do {
                        return try await self.extractTrackMetadata(from: url)
                    } catch {
                        print("Failed to extract metadata from \(url): \(error)")
                        return nil
                    }
                }
            }

            for try await metadata in group {
                if let metadata {
                    trackMetadata.append(metadata)
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

    private func parseMetadata(metadata: [AVMetadataItem]) -> MetadataValues {
        var values = MetadataValues()
        var customMetadata: [String: String] = [:]

        for item in metadata {
            guard let key = item.commonKey?.rawValue,
                  let value = item.value else { continue }

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
                    if let data = item.dataValue {
                        values.trackNumber = extractTrackNumber(from: data)
                        values.trackCount = extractTrackCount(from: data)
                    }
                case .iTunesMetadataDiscNumber:
                    if let data = item.dataValue {
                        values.discNumber = extractDiscNumber(from: data)
                        values.discCount = extractDiscCount(from: data)
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
        let metadata = try await asset.load(.commonMetadata)

        for item in metadata {
            if item.commonKey == .commonKeyArtwork,
               let data = item.dataValue
            {
                return data
            }
        }

        return nil
    }

    private func extractYear(from dateString: String) -> Int? {
        // Try to extract year from various date formats
        let yearRegex = try? NSRegularExpression(pattern: "\\b(19|20)\\d{2}\\b")
        let range = NSRange(location: 0, length: dateString.count)

        if let match = yearRegex?.firstMatch(in: dateString, options: [], range: range) {
            let yearString = String(dateString[Range(match.range, in: dateString)!])
            return Int(yearString)
        }

        return nil
    }

    private func extractTrackNumber(from data: Data) -> Int? {
        guard data.count >= 8 else { return nil }
        let trackNumber = data.withUnsafeBytes { $0.load(fromByteOffset: 6, as: UInt16.self) }
        return trackNumber > 0 ? Int(trackNumber.bigEndian) : nil
    }

    private func extractTrackCount(from data: Data) -> Int? {
        guard data.count >= 8 else { return nil }
        let trackCount = data.withUnsafeBytes { $0.load(fromByteOffset: 4, as: UInt16.self) }
        return trackCount > 0 ? Int(trackCount.bigEndian) : nil
    }

    private func extractDiscNumber(from data: Data) -> Int? {
        guard data.count >= 6 else { return nil }
        let discNumber = data.withUnsafeBytes { $0.load(fromByteOffset: 2, as: UInt16.self) }
        return discNumber > 0 ? Int(discNumber.bigEndian) : nil
    }

    private func extractDiscCount(from data: Data) -> Int? {
        guard data.count >= 4 else { return nil }
        let discCount = data.withUnsafeBytes { $0.load(fromByteOffset: 0, as: UInt16.self) }
        return discCount > 0 ? Int(discCount.bigEndian) : nil
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
