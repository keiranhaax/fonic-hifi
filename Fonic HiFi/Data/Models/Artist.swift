//
//  Artist.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData

/// Artist model representing a musical artist or band
@Model
public final class Artist {
    // MARK: - Identity

    /// Unique identifier for the artist
    public var id: UUID

    /// Artist name
    public var name: String

    /// Sort name (for alphabetical ordering)
    public var sortName: String

    // MARK: - Metadata

    /// Artist biography or description
    public var biography: String?

    /// Primary genre associated with the artist
    public var primaryGenre: String?

    /// All genres associated with this artist
    public var genres: [String]

    /// Country of origin
    public var country: String?

    /// Formation year (for bands) or birth year (for solo artists)
    public var formationYear: Int?

    /// Whether the artist is currently active
    public var isActive: Bool

    /// External URLs (website, social media, etc.)
    public var externalUrls: [String: String]

    // MARK: - Artwork

    /// Artist photo or logo
    public var artwork: Data?

    /// URL to artist artwork (if stored externally)
    public var artworkUrl: URL?

    // MARK: - Relationships

    /// Albums by this artist
    @Relationship(deleteRule: .nullify)
    public var albums: [Album] = []

    /// Tracks by this artist
    @Relationship(deleteRule: .nullify, inverse: \Track.artistRelation)
    public var tracks: [Track] = []

    // MARK: - Computed Properties

    /// Number of tracks by this artist (calculated from relationships)
    public var trackCount: Int {
        tracks.count
    }

    /// Number of albums by this artist
    public var albumCount: Int {
        albums.count
    }

    /// Total duration of all tracks by this artist
    public var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    /// First letter for section indexing
    public var firstLetter: String {
        let effectiveName = sortName.isEmpty ? name : sortName
        return String(effectiveName.prefix(1).uppercased())
    }

    // MARK: - Initialization

    public init(
        name: String,
        sortName: String? = nil,
        primaryGenre: String? = nil,
        country: String? = nil,
        formationYear: Int? = nil,
    ) {
        id = UUID()
        self.name = name
        self.sortName = sortName ?? name
        self.primaryGenre = primaryGenre
        self.country = country
        self.formationYear = formationYear
        isActive = true
        genres = []
        externalUrls = [:]
    }
}

// MARK: - Hashable Conformance

extension Artist: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Artist, rhs: Artist) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Search and Filtering

public extension Artist {
    /// Check if artist matches search query
    func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased()
        return name.lowercased().contains(query) ||
            sortName.lowercased().contains(query) ||
            genres.contains { $0.lowercased().contains(query) } ||
            (country?.lowercased().contains(query) ?? false)
    }

    /// Check if artist matches specific filter criteria
    func matches(filter: ArtistFilter) -> Bool {
        switch filter {
        case let .genre(genreName):
            return genres.contains { $0.lowercased() == genreName.lowercased() }
        case let .country(countryName):
            return country?.lowercased() == countryName.lowercased()
        case let .decade(decade):
            guard let year = formationYear else { return false }
            return year >= decade && year < decade + 10
        case .active:
            return isActive
        case .hasArtwork:
            return artwork != nil || artworkUrl != nil
        }
    }
}

// MARK: - Filter Types

public enum ArtistFilter {
    case genre(String)
    case country(String)
    case decade(Int) // e.g., 1990 for 1990s
    case active
    case hasArtwork
}

// MARK: - Artist Statistics

public extension Artist {
    /// Statistics about the artist's music in the library
    struct Statistics {
        public let trackCount: Int
        public let albumCount: Int
        public let totalDuration: TimeInterval
        public let averageTrackLength: TimeInterval
        public let totalFileSize: Int64
        public let genres: [String]
        public let yearRange: ClosedRange<Int>?
        public let audioFormats: Set<String>
        public let qualityDistribution: [String: Int] // e.g., ["Lossless": 50, "Hi-Res": 30]

        public var formattedTotalDuration: String {
            let hours = Int(totalDuration) / 3600
            let minutes = (Int(totalDuration) % 3600) / 60

            if hours > 0 {
                return String(format: "%dh %dm", hours, minutes)
            } else {
                return String(format: "%dm", minutes)
            }
        }

        public var formattedTotalFileSize: String {
            let formatter = ByteCountFormatter()
            formatter.allowedUnits = [.useMB, .useGB]
            formatter.countStyle = .file
            return formatter.string(fromByteCount: totalFileSize)
        }
    }
}
