//
//  Track.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData

/// Core track model representing a single audio file in the library
@Model
public final class Track: TrackProtocol {
    // MARK: - Identity

    /// Unique identifier for the track
    public var id: UUID

    /// File URL where the audio file is stored
    public var url: URL

    /// File name without extension
    public var fileName: String

    /// File extension (e.g., "flac", "mp3")
    public var fileExtension: String

    /// File size in bytes
    public var fileSize: Int64

    /// Date the file was added to the library
    public var dateAdded: Date

    /// Date the file was last modified
    public var dateModified: Date

    // MARK: - Source Tracking

    /// Original security-scoped bookmark for imported file
    public var sourceURLBookmark: Data?

    /// Original external URL string for duplicate detection and migrations
    public var sourceURLString: String?

    /// Normalized hash of the original source URL
    public var sourceURLHash: String?

    /// Hash of the original security-scoped bookmark for resilient duplicate detection
    public var sourceBookmarkHash: String?

    // MARK: - Basic Metadata

    /// Track title
    public var title: String

    /// Artist name
    public var artist: String

    /// Album name
    public var album: String

    /// Album artist (may differ from track artist)
    public var albumArtist: String?

    /// Genre
    public var genre: String?

    /// Release year
    public var year: Int?

    /// Track number within the album
    public var trackNumber: Int?

    /// Total number of tracks on the album
    public var totalTracks: Int?

    /// Disc number for multi-disc albums
    public var discNumber: Int?

    /// Total number of discs
    public var totalDiscs: Int?

    // MARK: - Extended Metadata

    /// Composer
    public var composer: String?

    /// Conductor
    public var conductor: String?

    /// Record label
    public var label: String?

    /// Catalog number
    public var catalogNumber: String?

    /// Release date (more specific than year)
    public var releaseDate: Date?

    /// Original artist (for covers)
    public var originalArtist: String?

    /// Comments or notes
    public var comments: String?

    /// Lyrics
    public var lyrics: String?

    /// Album artwork (stored as Data)
    public var artwork: Data?

    // MARK: - Technical Metadata

    /// Audio format (e.g., "FLAC", "ALAC", "MP3")
    public var audioFormat: String

    /// Duration in seconds
    public var duration: TimeInterval

    /// Sample rate in Hz
    public var sampleRate: Double

    /// Bit depth
    public var bitDepth: Int

    /// Number of audio channels
    public var channels: Int

    /// Bitrate in kbps (for lossy formats)
    public var bitrate: Int?

    /// Whether the track is lossless
    public var isLossless: Bool

    /// Codec used for encoding
    public var codec: String?

    /// Container format
    public var container: String?

    /// Whether the track supports gapless playback
    public var supportsGapless: Bool

    // MARK: - User Data

    /// User rating (1-5 stars)
    public var rating: Int?

    /// Number of times played
    public var playCount: Int

    /// Date last played
    public var lastPlayed: Date?

    /// Whether the track is marked as favorite
    public var isFavorite: Bool

    /// User-defined tags
    public var userTags: [String]

    /// BPM (beats per minute) for rhythm analysis
    public var bpm: Int?

    /// Musical key
    public var musicalKey: String?

    /// Track-level replay gain adjustment in decibels
    public var replayGainTrack: Float?

    /// Album-level replay gain adjustment in decibels
    public var replayGainAlbum: Float?

    // MARK: - Relationships

    /// Relationship to the album this track belongs to
    @Relationship(deleteRule: .nullify)
    public var albumRelation: Album?

    /// Relationship to the artist of this track
    @Relationship(deleteRule: .nullify)
    public var artistRelation: Artist?

    /// Playlists containing this track
    @Relationship(deleteRule: .nullify, inverse: \Playlist.tracks)
    public var playlists: [Playlist] = []

    // MARK: - Computed Properties

    /// Full file path as string
    public var filePath: String {
        url.path
    }

    /// File name with extension
    public var fullFileName: String {
        fileName + "." + fileExtension
    }

    /// Quality description based on technical specs
    public var qualityDescription: String {
        if isLossless {
            if sampleRate > 48000 || bitDepth > 16 {
                "Hi-Res Lossless"
            } else {
                "Lossless"
            }
        } else {
            "Lossy"
        }
    }

    /// Duration formatted as MM:SS
    public var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// File size formatted for display
    public var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    // MARK: - Initialization

    public init(
        url: URL,
        title: String = "",
        artist: String = "",
        album: String = "",
        audioFormat: String,
        duration: TimeInterval = 0,
        sampleRate: Double = 44100,
        bitDepth: Int = 16,
        channels: Int = 2,
        isLossless: Bool = false,
    ) {
        // Initialize basic properties first
        id = UUID()
        self.url = url

        // Compute derived values
        let computedFileName = url.deletingPathExtension().lastPathComponent
        let computedFileExtension = url.pathExtension.lowercased()

        // Initialize all properties in order
        fileName = computedFileName
        fileExtension = computedFileExtension
        self.title = title.isEmpty ? computedFileName : title
        self.artist = artist
        self.album = album
        self.audioFormat = audioFormat
        self.duration = duration
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.isLossless = isLossless

        sourceURLBookmark = nil
        sourceURLString = nil
        sourceURLHash = nil

        // File attributes
        let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
        fileSize = Int64(resourceValues?.fileSize ?? 0)
        dateModified = resourceValues?.contentModificationDate ?? Date()
        dateAdded = Date()

        // Initialize user data
        playCount = 0
        isFavorite = false
        userTags = []
        supportsGapless = false
        replayGainTrack = nil
        replayGainAlbum = nil
    }
}

// MARK: - Hashable Conformance

extension Track: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Track, rhs: Track) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Search and Filtering

public extension Track {
    /// Check if track matches search query (searches multiple fields)
    func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased()
        return title.lowercased().contains(query) ||
            artist.lowercased().contains(query) ||
            album.lowercased().contains(query) ||
            (albumArtist?.lowercased().contains(query) ?? false) ||
            (genre?.lowercased().contains(query) ?? false) ||
            (composer?.lowercased().contains(query) ?? false)
    }

    /// Check if track matches specific filter criteria
    func matches(filter: TrackFilter) -> Bool {
        switch filter {
        case .lossless:
            return isLossless
        case .hiRes:
            return isLossless && (sampleRate > 48000 || bitDepth > 16)
        case .favorites:
            return isFavorite
        case let .recentlyAdded(days):
            return dateAdded > Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        case let .recentlyPlayed(days):
            guard let lastPlayed else { return false }
            return lastPlayed > Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        case let .genre(genreName):
            return genre?.lowercased() == genreName.lowercased()
        case let .year(yearValue):
            return year == yearValue
        case let .artist(artistName):
            return artist.lowercased() == artistName.lowercased()
        case let .album(albumName):
            return album.lowercased() == albumName.lowercased()
        }
    }
}

// MARK: - Filter Types

public enum TrackFilter {
    case lossless
    case hiRes
    case favorites
    case recentlyAdded(days: Int)
    case recentlyPlayed(days: Int)
    case genre(String)
    case year(Int)
    case artist(String)
    case album(String)
}

// MARK: - AudioTrack Conversion

public extension Track {
    /// Convert Track to AudioTrack for compatibility with audio engine
    func toAudioTrack() -> AudioTrack {
        var track = LegacyTrack(
            id: id,
            title: title,
            artist: artist,
            album: album,
            url: url,
            duration: duration,
            audioFormat: audioFormat,
        )
        track.replayGainTrack = replayGainTrack
        track.replayGainAlbum = replayGainAlbum
        return track
    }
}
