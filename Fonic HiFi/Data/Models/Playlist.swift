//
//  Playlist.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData

/// Playlist model representing user-created collections of tracks
@Model
public final class Playlist {
    // MARK: - Identity

    /// Unique identifier for the playlist
    public var id: UUID

    /// Playlist name
    public var name: String

    /// Optional description
    public var playlistDescription: String?

    // MARK: - Type and Behavior

    /// Type of playlist (static or smart)
    public var type: PlaylistType

    /// For smart playlists, the filter rules
    public var smartFilters: [SmartPlaylistRule]

    /// Maximum number of tracks (for smart playlists)
    public var maxTracks: Int?

    /// How smart playlists should sort tracks
    public var sortOrder: PlaylistSortOrder

    /// Whether the playlist should automatically update
    public var autoUpdate: Bool

    // MARK: - Visual Appearance

    /// Custom artwork for the playlist
    public var artwork: Data?

    /// System icon name for the playlist
    public var systemIcon: String?

    /// Custom color theme
    public var colorTheme: String?

    // MARK: - Metadata

    /// Date the playlist was created
    public var dateCreated: Date

    /// Date the playlist was last modified
    public var dateModified: Date

    /// Date the playlist was last played
    public var lastPlayed: Date?

    /// Number of times the playlist has been played
    public var playCount: Int

    /// Whether the playlist is marked as favorite
    public var isFavorite: Bool

    /// Track IDs in order (for static playlists)
    public var trackIds: [UUID]

    /// User-defined tags
    public var userTags: [String]

    // MARK: - Relationships

    /// Tracks in this playlist
    @Relationship(deleteRule: .nullify)
    public var tracks: [Track] = []

    // MARK: - Computed Properties

    /// Number of tracks in the playlist
    public var trackCount: Int {
        tracks.count
    }

    /// Whether the playlist is empty
    public var isEmpty: Bool {
        tracks.isEmpty
    }

    /// Total duration of all tracks (would be calculated from actual tracks)
    public var totalDuration: TimeInterval {
        tracks.reduce(0) { $0 + $1.duration }
    }

    /// Formatted duration string
    public var formattedDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60

        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }

    /// Whether this is a smart (automatically updating) playlist
    public var isSmart: Bool {
        type == .smart
    }

    // MARK: - Initialization

    public init(
        name: String,
        playlistDescription: String? = nil,
        type: PlaylistType = .static,
    ) {
        id = UUID()
        self.name = name
        self.playlistDescription = playlistDescription
        self.type = type
        smartFilters = []
        sortOrder = .dateAdded
        autoUpdate = type == .smart
        dateCreated = Date()
        dateModified = Date()
        playCount = 0
        isFavorite = false
        trackIds = []
        userTags = []
    }

    // MARK: - Track Management

    /// Add a track to the playlist (for static playlists)
    public func addTrack(_ trackId: UUID) {
        guard type == .static else { return }
        if !trackIds.contains(trackId) {
            trackIds.append(trackId)
            dateModified = Date()
        }
    }

    /// Add multiple tracks to the playlist
    public func addTracks(_ trackIds: [UUID]) {
        guard type == .static else { return }
        for trackId in trackIds {
            addTrack(trackId)
        }
    }

    /// Remove a track from the playlist
    public func removeTrack(_ trackId: UUID) {
        guard type == .static else { return }
        if let index = trackIds.firstIndex(of: trackId) {
            trackIds.remove(at: index)
            dateModified = Date()
        }
    }

    /// Remove track at specific index
    public func removeTrack(at index: Int) {
        guard type == .static, index >= 0, index < trackIds.count else { return }
        trackIds.remove(at: index)
        dateModified = Date()
    }

    /// Move track from one position to another
    public func moveTrack(from sourceIndex: Int, to destinationIndex: Int) {
        guard type == .static,
              sourceIndex >= 0, sourceIndex < trackIds.count,
              destinationIndex >= 0, destinationIndex < trackIds.count else { return }

        let trackId = trackIds.remove(at: sourceIndex)
        trackIds.insert(trackId, at: destinationIndex)
        dateModified = Date()
    }

    /// Clear all tracks from the playlist
    public func clearTracks() {
        guard type == .static else { return }
        trackIds.removeAll()
        dateModified = Date()
    }

    // MARK: - Smart Playlist Management

    /// Add a smart filter rule
    public func addSmartFilter(_ rule: SmartPlaylistRule) {
        guard type == .smart else { return }
        smartFilters.append(rule)
        dateModified = Date()
    }

    /// Remove a smart filter rule
    public func removeSmartFilter(at index: Int) {
        guard type == .smart, index >= 0, index < smartFilters.count else { return }
        smartFilters.remove(at: index)
        dateModified = Date()
    }

    /// Clear all smart filter rules
    public func clearSmartFilters() {
        guard type == .smart else { return }
        smartFilters.removeAll()
        dateModified = Date()
    }
}

// MARK: - Playlist Types

public enum PlaylistType: String, CaseIterable, Codable {
    case `static`
    case smart

    public var displayName: String {
        switch self {
        case .static: "Playlist"
        case .smart: "Smart Playlist"
        }
    }
}

// MARK: - Sort Orders

public enum PlaylistSortOrder: String, CaseIterable, Codable {
    case manual
    case dateAdded
    case dateModified
    case title
    case artist
    case album
    case duration
    case playCount
    case rating
    case sampleRate
    case random

    public var displayName: String {
        switch self {
        case .manual: "Manual Order"
        case .dateAdded: "Date Added"
        case .dateModified: "Date Modified"
        case .title: "Title"
        case .artist: "Artist"
        case .album: "Album"
        case .duration: "Duration"
        case .playCount: "Play Count"
        case .rating: "Rating"
        case .sampleRate: "Sample Rate"
        case .random: "Random"
        }
    }

    public var isAscending: Bool {
        switch self {
        case .manual, .title, .artist, .album: true
        case .dateAdded, .dateModified, .duration, .playCount, .rating, .sampleRate: false
        case .random: true // Random doesn't matter
        }
    }
}

// MARK: - Smart Playlist Rules

public struct SmartPlaylistRule: Codable, Equatable {
    public let field: SmartPlaylistField
    public let `operator`: SmartPlaylistOperator
    public let value: String
    public let logicalOperator: LogicalOperator // AND/OR with next rule

    public init(
        field: SmartPlaylistField,
        operator: SmartPlaylistOperator,
        value: String,
        logicalOperator: LogicalOperator = .and,
    ) {
        self.field = field
        self.operator = `operator`
        self.value = value
        self.logicalOperator = logicalOperator
    }
}

public enum SmartPlaylistField: String, CaseIterable, Codable {
    case title
    case artist
    case album
    case genre
    case year
    case duration
    case playCount
    case rating
    case dateAdded
    case lastPlayed
    case audioFormat
    case sampleRate
    case bitDepth
    case isLossless
    case isFavorite
    case fileSize

    public var displayName: String {
        switch self {
        case .title: "Title"
        case .artist: "Artist"
        case .album: "Album"
        case .genre: "Genre"
        case .year: "Year"
        case .duration: "Duration"
        case .playCount: "Play Count"
        case .rating: "Rating"
        case .dateAdded: "Date Added"
        case .lastPlayed: "Last Played"
        case .audioFormat: "Audio Format"
        case .sampleRate: "Sample Rate"
        case .bitDepth: "Bit Depth"
        case .isLossless: "Is Lossless"
        case .isFavorite: "Is Favorite"
        case .fileSize: "File Size"
        }
    }
}

public enum SmartPlaylistOperator: String, CaseIterable, Codable {
    case equals
    case notEquals
    case contains
    case notContains
    case startsWith
    case endsWith
    case greaterThan
    case lessThan
    case greaterThanOrEqual
    case lessThanOrEqual
    case isTrue
    case isFalse
    case inTheLast
    case notInTheLast

    public var displayName: String {
        switch self {
        case .equals: "is"
        case .notEquals: "is not"
        case .contains: "contains"
        case .notContains: "does not contain"
        case .startsWith: "starts with"
        case .endsWith: "ends with"
        case .greaterThan: "is greater than"
        case .lessThan: "is less than"
        case .greaterThanOrEqual: "is greater than or equal to"
        case .lessThanOrEqual: "is less than or equal to"
        case .isTrue: "is true"
        case .isFalse: "is false"
        case .inTheLast: "in the last"
        case .notInTheLast: "not in the last"
        }
    }
}

public enum LogicalOperator: String, CaseIterable, Codable {
    case and
    case or

    public var displayName: String {
        rawValue.uppercased()
    }
}

// MARK: - Hashable Conformance

extension Playlist: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    public static func == (lhs: Playlist, rhs: Playlist) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Search and Filtering

public extension Playlist {
    /// Check if playlist matches search query
    func matches(searchQuery: String) -> Bool {
        let query = searchQuery.lowercased()
        return name.lowercased().contains(query) ||
            (playlistDescription?.lowercased().contains(query) ?? false) ||
            userTags.contains { $0.lowercased().contains(query) }
    }
}

// MARK: - Built-in Playlists

public extension Playlist {
    /// Create a "Recently Added" smart playlist
    static func recentlyAdded() -> Playlist {
        let playlist = Playlist(name: "Recently Added", type: .smart)
        playlist.systemIcon = "clock"
        playlist.addSmartFilter(SmartPlaylistRule(
            field: .dateAdded,
            operator: .inTheLast,
            value: "30", // 30 days
        ))
        playlist.sortOrder = .dateAdded
        playlist.maxTracks = 100
        return playlist
    }

    /// Create a "Most Played" smart playlist
    static func mostPlayed() -> Playlist {
        let playlist = Playlist(name: "Most Played", type: .smart)
        playlist.systemIcon = "play.circle"
        playlist.addSmartFilter(SmartPlaylistRule(
            field: .playCount,
            operator: .greaterThan,
            value: "0",
        ))
        playlist.sortOrder = .playCount
        playlist.maxTracks = 50
        return playlist
    }

    /// Create a "Hi-Res" smart playlist
    static func hiRes() -> Playlist {
        let playlist = Playlist(name: "Hi-Res Audio", type: .smart)
        playlist.systemIcon = "waveform"
        playlist.addSmartFilter(SmartPlaylistRule(
            field: .sampleRate,
            operator: .greaterThan,
            value: "48000",
            logicalOperator: .or,
        ))
        playlist.addSmartFilter(SmartPlaylistRule(
            field: .bitDepth,
            operator: .greaterThan,
            value: "16",
        ))
        playlist.sortOrder = .sampleRate
        return playlist
    }

    /// Create a "Favorites" smart playlist
    static func favorites() -> Playlist {
        let playlist = Playlist(name: "Favorites", type: .smart)
        playlist.systemIcon = "heart"
        playlist.addSmartFilter(SmartPlaylistRule(
            field: .isFavorite,
            operator: .isTrue,
            value: "true",
        ))
        playlist.sortOrder = .dateAdded
        return playlist
    }
}
