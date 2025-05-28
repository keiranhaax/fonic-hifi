//
//  Album.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData

/// Album model representing a collection of tracks released together
@Model
public final class Album {
    
    // MARK: - Identity
    
    /// Unique identifier for the album
    public var id: UUID
    
    /// Album title
    public var title: String
    
    /// Sort title (for alphabetical ordering)
    public var sortTitle: String
    
    /// Album artist (may be different from individual track artists)
    public var albumArtist: String
    
    /// Sort artist name
    public var sortArtist: String
    
    // MARK: - Release Information
    
    /// Release year
    public var year: Int?
    
    /// Specific release date
    public var releaseDate: Date?
    
    /// Original release date (for reissues)
    public var originalReleaseDate: Date?
    
    /// Record label
    public var label: String?
    
    /// Catalog number
    public var catalogNumber: String?
    
    /// Barcode/UPC
    public var barcode: String?
    
    /// Country of release
    public var releaseCountry: String?
    
    /// Release type (album, EP, single, compilation, etc.)
    public var releaseType: AlbumType
    
    // MARK: - Musical Information
    
    /// Primary genre
    public var primaryGenre: String?
    
    /// All genres associated with this album
    public var genres: [String]
    
    /// Album producer(s)
    public var producer: String?
    
    /// Recording studio
    public var studio: String?
    
    /// Copyright information
    public var copyright: String?
    
    /// Album notes or description
    public var notes: String?
    
    // MARK: - Physical Information
    
    /// Total number of discs
    public var totalDiscs: Int
    
    /// Total number of tracks across all discs
    public var totalTracks: Int
    
    /// Whether this is a compilation album
    public var isCompilation: Bool
    
    /// Whether this is a soundtrack
    public var isSoundtrack: Bool
    
    // MARK: - Artwork
    
    /// Album artwork
    public var artwork: Data?
    
    /// URL to album artwork (if stored externally)
    public var artworkUrl: URL?
    
    /// Whether artwork is embedded in track files
    public var hasEmbeddedArtwork: Bool
    
    // MARK: - Technical Information
    
    /// Primary audio format of tracks on this album
    public var primaryAudioFormat: String?
    
    /// Whether the album contains lossless tracks
    public var hasLosslessTracks: Bool
    
    /// Whether the album contains hi-res tracks
    public var hasHiResTracks: Bool
    
    /// Whether the album supports gapless playback
    public var supportsGapless: Bool
    
    // MARK: - User Data
    
    /// User rating (1-5 stars)
    public var rating: Int?
    
    /// Whether the album is marked as favorite
    public var isFavorite: Bool
    
    /// Number of times the album has been played (complete plays)
    public var playCount: Int
    
    /// Date last played
    public var lastPlayed: Date?
    
    /// User-defined tags
    public var userTags: [String]
    
    /// Date added to library
    public var dateAdded: Date
    
    // MARK: - Computed Properties
    
    /// Total duration of all tracks on the album
    public var totalDuration: TimeInterval {
        // This would be calculated from related tracks
        return 0
    }
    
    /// Total file size of the album
    public var totalFileSize: Int64 {
        // This would be calculated from related tracks
        return 0
    }
    
    /// Number of tracks currently in the library for this album
    public var trackCount: Int {
        // This would be calculated from Track relationships
        return 0
    }
    
    /// Whether the album is complete (all tracks present)
    public var isComplete: Bool {
        return trackCount == totalTracks
    }
    
    /// Quality description based on audio formats
    public var qualityDescription: String {
        if hasHiResTracks {
            return "Hi-Res"
        } else if hasLosslessTracks {
            return "Lossless"
        } else {
            return "Lossy"
        }
    }
    
    /// Formatted total duration
    public var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    /// First letter for section indexing
    public var firstLetter: String {
        let effectiveTitle = sortTitle.isEmpty ? title : sortTitle
        return String(effectiveTitle.prefix(1).uppercased())
    }
    
    // MARK: - Initialization
    
    public init(
        title: String,
        albumArtist: String,
        year: Int? = nil,
        releaseType: AlbumType = .album,
        totalDiscs: Int = 1,
        totalTracks: Int = 0
    ) {
        self.id = UUID()
        self.title = title
        self.sortTitle = title
        self.albumArtist = albumArtist
        self.sortArtist = albumArtist
        self.year = year
        self.releaseType = releaseType
        self.totalDiscs = totalDiscs
        self.totalTracks = totalTracks
        self.isCompilation = false
        self.isSoundtrack = false
        self.hasLosslessTracks = false
        self.hasHiResTracks = false
        self.supportsGapless = false
        self.hasEmbeddedArtwork = false
        self.isFavorite = false
        self.playCount = 0
        self.userTags = []
        self.genres = []
        self.dateAdded = Date()
    }
}

// MARK: - Album Types

public enum AlbumType: String, CaseIterable, Codable {
    case album = "Album"
    case ep = "EP"
    case single = "Single"
    case compilation = "Compilation"
    case soundtrack = "Soundtrack"
    case liveAlbum = "Live Album"
    case remix = "Remix"
    case bootleg = "Bootleg"
    case unknown = "Unknown"
    
    public var shortDescription: String {
        switch self {
        case .album: return "LP"
        case .ep: return "EP"
        case .single: return "Single"
        case .compilation: return "Comp"
        case .soundtrack: return "OST"
        case .liveAlbum: return "Live"
        case .remix: return "Remix"
        case .bootleg: return "Boot"
        case .unknown: return "Unknown"
        }
    }
}

// MARK: - Hashable Conformance

extension Album: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    public static func == (lhs: Album, rhs: Album) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Search and Filtering

extension Album {
    
    /// Check if album matches search query
    public func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased()
        return title.lowercased().contains(query) ||
               albumArtist.lowercased().contains(query) ||
               sortTitle.lowercased().contains(query) ||
               sortArtist.lowercased().contains(query) ||
               (label?.lowercased().contains(query) ?? false) ||
               genres.contains { $0.lowercased().contains(query) }
    }
    
    /// Check if album matches specific filter criteria
    public func matches(filter: AlbumFilter) -> Bool {
        switch filter {
        case .releaseType(let type):
            return releaseType == type
        case .decade(let decade):
            guard let year = year else { return false }
            return year >= decade && year < decade + 10
        case .genre(let genreName):
            return genres.contains { $0.lowercased() == genreName.lowercased() }
        case .lossless:
            return hasLosslessTracks
        case .hiRes:
            return hasHiResTracks
        case .complete:
            return isComplete
        case .favorites:
            return isFavorite
        case .recentlyAdded(let days):
            return dateAdded > Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        case .recentlyPlayed(let days):
            guard let lastPlayed = lastPlayed else { return false }
            return lastPlayed > Date().addingTimeInterval(-TimeInterval(days * 24 * 60 * 60))
        case .artist(let artistName):
            return albumArtist.lowercased() == artistName.lowercased()
        case .hasArtwork:
            return artwork != nil || artworkUrl != nil
        }
    }
}

// MARK: - Filter Types

public enum AlbumFilter {
    case releaseType(AlbumType)
    case decade(Int)
    case genre(String)
    case lossless
    case hiRes
    case complete
    case favorites
    case recentlyAdded(days: Int)
    case recentlyPlayed(days: Int)
    case artist(String)
    case hasArtwork
}

// MARK: - Album Statistics

public extension Album {
    
    /// Detailed statistics about the album
    struct Statistics {
        public let trackCount: Int
        public let totalDuration: TimeInterval
        public let averageTrackLength: TimeInterval
        public let totalFileSize: Int64
        public let audioFormats: Set<String>
        public let sampleRates: Set<Double>
        public let bitDepths: Set<Int>
        public let channels: Set<Int>
        public let losslessTrackCount: Int
        public let hiResTrackCount: Int
        
        public var completionPercentage: Double {
            guard trackCount > 0 else { return 0 }
            return Double(trackCount) / Double(trackCount) * 100
        }
        
        public var formattedTotalFileSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalFileSize)
        }
        
        public var qualitySummary: String {
            if hiResTrackCount > 0 && hiResTrackCount == trackCount {
                return "Hi-Res"
            } else if losslessTrackCount > 0 && losslessTrackCount == trackCount {
                return "Lossless"
            } else if losslessTrackCount > 0 {
                return "Mixed Quality"
            } else {
                return "Lossy"
            }
        }
    }
}