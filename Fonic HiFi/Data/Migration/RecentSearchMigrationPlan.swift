//
//  RecentSearchMigrationPlan.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData

/// Immutable snapshot of the original store before source hashes and RecentSearch.
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TrackV1.self,
            SchemaV1.Artist.self,
            SchemaV1.Album.self,
            SchemaV1.Playlist.self
        ]
    }

    @Model
    final class TrackV1 {
        var id: UUID
        var url: URL
        var fileName: String
        var fileExtension: String
        var fileSize: Int64
        var dateAdded: Date
        var dateModified: Date

        var sourceURLBookmark: Data?
        var sourceURLString: String?

        var title: String
        var artist: String
        var album: String
        var albumArtist: String?
        var genre: String?
        var year: Int?
        var trackNumber: Int?
        var totalTracks: Int?
        var discNumber: Int?
        var totalDiscs: Int?

        var composer: String?
        var conductor: String?
        var label: String?
        var catalogNumber: String?
        var releaseDate: Date?
        var originalArtist: String?
        var comments: String?
        var lyrics: String?
        var artwork: Data?

        var audioFormat: String
        var duration: TimeInterval
        var sampleRate: Double
        var bitDepth: Int
        var channels: Int
        var bitrate: Int?
        var isLossless: Bool
        var codec: String?
        var container: String?
        var supportsGapless: Bool

        var rating: Int?
        var playCount: Int
        var lastPlayed: Date?
        var isFavorite: Bool
        var userTags: [String] = []
        var bpm: Int?
        var musicalKey: String?
        var replayGainTrack: Float?
        var replayGainAlbum: Float?

        @Relationship(deleteRule: .nullify)
        var albumRelation: SchemaV1.Album?

        @Relationship(deleteRule: .nullify)
        var artistRelation: SchemaV1.Artist?

        @Relationship(deleteRule: .nullify, inverse: \SchemaV1.Playlist.tracks)
        var playlists: [SchemaV1.Playlist] = []

        init(
            url: URL,
            title: String = "",
            artist: String = "",
            album: String = "",
            audioFormat: String,
            duration: TimeInterval = 0,
            sampleRate: Double = 44_100,
            bitDepth: Int = 16,
            channels: Int = 2,
            isLossless: Bool = false
        ) {
            let computedFileName = url.deletingPathExtension().lastPathComponent
            let computedFileExtension = url.pathExtension.lowercased()

            id = UUID()
            self.url = url
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

            let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey])
            fileSize = Int64(resourceValues?.fileSize ?? 0)
            dateModified = resourceValues?.contentModificationDate ?? Date()
            dateAdded = Date()

            playCount = 0
            isFavorite = false
            supportsGapless = false
            replayGainTrack = nil
            replayGainAlbum = nil
        }
    }

    @Model
    final class Artist {
        var id: UUID
        var name: String
        var sortName: String
        var biography: String?
        var primaryGenre: String?
        var genres: [String] = []
        var country: String?
        var formationYear: Int?
        var isActive: Bool
        var externalUrls: [String: String] = [:]
        var artwork: Data?
        var artworkUrl: URL?

        @Relationship(deleteRule: .nullify)
        var albums: [SchemaV1.Album] = []

        @Relationship(deleteRule: .nullify, inverse: \SchemaV1.TrackV1.artistRelation)
        var tracks: [SchemaV1.TrackV1] = []

        init(name: String) {
            id = UUID()
            self.name = name
            sortName = name
            isActive = true
        }
    }

    @Model
    final class Album {
        var id: UUID
        var title: String
        var sortTitle: String
        var albumArtist: String
        var sortArtist: String
        var year: Int?
        var releaseDate: Date?
        var originalReleaseDate: Date?
        var label: String?
        var catalogNumber: String?
        var barcode: String?
        var releaseCountry: String?
        var releaseType: AlbumType
        var primaryGenre: String?
        var genres: [String]
        var producer: String?
        var studio: String?
        var copyright: String?
        var notes: String?
        var totalDiscs: Int
        var totalTracks: Int
        var isCompilation: Bool
        var isSoundtrack: Bool
        var artwork: Data?
        var artworkUrl: URL?
        var hasEmbeddedArtwork: Bool
        var primaryAudioFormat: String?
        var hasLosslessTracks: Bool
        var hasHiResTracks: Bool
        var supportsGapless: Bool

        @Relationship(deleteRule: .nullify, inverse: \SchemaV1.TrackV1.albumRelation)
        var tracks: [SchemaV1.TrackV1] = []

        @Relationship(deleteRule: .nullify, inverse: \SchemaV1.Artist.albums)
        var artistRelation: SchemaV1.Artist?

        var rating: Int?
        var isFavorite: Bool
        var playCount: Int
        var lastPlayed: Date?
        var userTags: [String]
        var dateAdded: Date

        init(title: String, albumArtist: String, totalTracks: Int = 0) {
            id = UUID()
            self.title = title
            sortTitle = title
            self.albumArtist = albumArtist
            sortArtist = albumArtist
            releaseType = .album
            genres = []
            totalDiscs = 1
            self.totalTracks = totalTracks
            isCompilation = false
            isSoundtrack = false
            hasEmbeddedArtwork = false
            hasLosslessTracks = false
            hasHiResTracks = false
            supportsGapless = false
            isFavorite = false
            playCount = 0
            userTags = []
            dateAdded = Date()
        }
    }

    @Model
    final class Playlist {
        var id: UUID
        var name: String
        var playlistDescription: String?
        var type: PlaylistType
        var smartFilters: [SmartPlaylistRule]
        var maxTracks: Int?
        var sortOrder: PlaylistSortOrder
        var autoUpdate: Bool
        var artwork: Data?
        var systemIcon: String?
        var colorTheme: String?
        var dateCreated: Date
        var dateModified: Date
        var lastPlayed: Date?
        var playCount: Int
        var isFavorite: Bool
        var trackIds: [UUID]
        var userTags: [String]

        @Relationship(deleteRule: .nullify)
        var tracks: [SchemaV1.TrackV1] = []

        init(name: String) {
            id = UUID()
            self.name = name
            type = .static
            smartFilters = []
            sortOrder = .dateAdded
            autoUpdate = false
            dateCreated = Date()
            dateModified = Date()
            playCount = 0
            isFavorite = false
            trackIds = []
            userTags = []
        }
    }
}

/// Immutable snapshot of the five-model store shipped before ListeningSession.
///
/// The deployed fixture and its checksum are preserved by the V2 test schema.
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Track.self,
            Artist.self,
            Album.self,
            Playlist.self,
            RecentSearch.self
        ]
    }

    /// Immutable V2 snapshot. These models intentionally duplicate the
    /// persisted shape instead of reusing the live V3 model classes.
    @Model
    final class Track {
        var id: UUID
        var url: URL
        var fileName: String
        var fileExtension: String
        var fileSize: Int64
        var dateAdded: Date
        var dateModified: Date

        var sourceURLBookmark: Data?
        var sourceURLString: String?
        var sourceURLHash: String?
        var sourceBookmarkHash: String?

        var title: String
        var artist: String
        var album: String
        var albumArtist: String?
        var genre: String?
        var year: Int?
        var trackNumber: Int?
        var totalTracks: Int?
        var discNumber: Int?
        var totalDiscs: Int?

        var composer: String?
        var conductor: String?
        var label: String?
        var catalogNumber: String?
        var releaseDate: Date?
        var originalArtist: String?
        var comments: String?
        var lyrics: String?
        var artwork: Data?

        var audioFormat: String
        var duration: TimeInterval
        var sampleRate: Double
        var bitDepth: Int
        var channels: Int
        var bitrate: Int?
        var isLossless: Bool
        var codec: String?
        var container: String?
        var supportsGapless: Bool

        var rating: Int?
        var playCount: Int
        var lastPlayed: Date?
        var isFavorite: Bool
        var userTags: [String] = []
        var bpm: Int?
        var musicalKey: String?
        var replayGainTrack: Float?
        var replayGainAlbum: Float?

        @Relationship(deleteRule: .nullify)
        var albumRelation: Album?

        @Relationship(deleteRule: .nullify)
        var artistRelation: Artist?

        @Relationship(deleteRule: .nullify, inverse: \Playlist.tracks)
        var playlists: [Playlist] = []

        init(
            url: URL,
            title: String = "",
            artist: String = "",
            album: String = "",
            audioFormat: String,
            duration: TimeInterval = 0,
            sampleRate: Double = 44_100,
            bitDepth: Int = 16,
            channels: Int = 2,
            isLossless: Bool = false
        ) {
            let computedFileName = url.deletingPathExtension().lastPathComponent
            id = UUID()
            self.url = url
            fileName = computedFileName
            fileExtension = url.pathExtension.lowercased()
            fileSize = 0
            dateAdded = Date()
            dateModified = Date()
            self.title = title.isEmpty ? computedFileName : title
            self.artist = artist
            self.album = album
            self.audioFormat = audioFormat
            self.duration = duration
            self.sampleRate = sampleRate
            self.bitDepth = bitDepth
            self.channels = channels
            self.isLossless = isLossless
            supportsGapless = false
            playCount = 0
            isFavorite = false
        }
    }

    @Model
    final class Artist {
        var id: UUID
        var name: String
        var sortName: String
        var biography: String?
        var primaryGenre: String?
        var genres: [String] = []
        var country: String?
        var formationYear: Int?
        var isActive: Bool
        var externalUrls: [String: String] = [:]
        var artwork: Data?
        var artworkUrl: URL?

        @Relationship(deleteRule: .nullify)
        var albums: [Album] = []

        @Relationship(deleteRule: .nullify, inverse: \Track.artistRelation)
        var tracks: [Track] = []

        init(name: String) {
            id = UUID()
            self.name = name
            sortName = name
            isActive = true
        }
    }

    @Model
    final class Album {
        var id: UUID
        var title: String
        var sortTitle: String
        var albumArtist: String
        var sortArtist: String
        var year: Int?
        var releaseDate: Date?
        var originalReleaseDate: Date?
        var label: String?
        var catalogNumber: String?
        var barcode: String?
        var releaseCountry: String?
        var releaseType: AlbumType
        var primaryGenre: String?
        var genres: [String]
        var producer: String?
        var studio: String?
        var copyright: String?
        var notes: String?
        var totalDiscs: Int
        var totalTracks: Int
        var isCompilation: Bool
        var isSoundtrack: Bool
        var artwork: Data?
        var artworkUrl: URL?
        var hasEmbeddedArtwork: Bool
        var primaryAudioFormat: String?
        var hasLosslessTracks: Bool
        var hasHiResTracks: Bool
        var supportsGapless: Bool

        @Relationship(deleteRule: .nullify, inverse: \Track.albumRelation)
        var tracks: [Track] = []

        @Relationship(deleteRule: .nullify, inverse: \Artist.albums)
        var artistRelation: Artist?

        var rating: Int?
        var isFavorite: Bool
        var playCount: Int
        var lastPlayed: Date?
        var userTags: [String]
        var dateAdded: Date

        init(title: String, albumArtist: String, totalTracks: Int = 0) {
            id = UUID()
            self.title = title
            sortTitle = title
            self.albumArtist = albumArtist
            sortArtist = albumArtist
            releaseType = .album
            genres = []
            totalDiscs = 1
            self.totalTracks = totalTracks
            isCompilation = false
            isSoundtrack = false
            hasEmbeddedArtwork = false
            hasLosslessTracks = false
            hasHiResTracks = false
            supportsGapless = false
            isFavorite = false
            playCount = 0
            userTags = []
            dateAdded = Date()
        }
    }

    @Model
    final class Playlist {
        var id: UUID
        var name: String
        var playlistDescription: String?
        var type: PlaylistType
        var smartFilters: [SmartPlaylistRule]
        var maxTracks: Int?
        var sortOrder: PlaylistSortOrder
        var autoUpdate: Bool
        var artwork: Data?
        var systemIcon: String?
        var colorTheme: String?
        var dateCreated: Date
        var dateModified: Date
        var lastPlayed: Date?
        var playCount: Int
        var isFavorite: Bool
        var trackIds: [UUID]
        var userTags: [String]

        @Relationship(deleteRule: .nullify)
        var tracks: [Track] = []

        init(name: String) {
            id = UUID()
            self.name = name
            type = .static
            smartFilters = []
            sortOrder = .dateAdded
            autoUpdate = false
            dateCreated = Date()
            dateModified = Date()
            playCount = 0
            isFavorite = false
            trackIds = []
            userTags = []
        }
    }

    @Model
    final class RecentSearch {
        var query: String
        var timestamp: Date
        var resultCount: Int

        init(query: String, timestamp: Date = Date(), resultCount: Int = 0) {
            self.query = query
            self.timestamp = timestamp
            self.resultCount = resultCount
        }
    }
}

/// Current schema. Every model persisted by a data actor must be declared here.
enum SchemaV3: VersionedSchema {
    static let versionIdentifier = Schema.Version(3, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Track.self,
            Artist.self,
            Album.self,
            Playlist.self,
            RecentSearch.self,
            ListeningSession.self
        ]
    }
}

/// Ordered production migration plan for every shipped library schema.
enum FonicHiFiMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self, SchemaV3.self]
    }

    static var stages: [MigrationStage] {
        [
            .lightweight(fromVersion: SchemaV1.self, toVersion: SchemaV2.self),
            .lightweight(fromVersion: SchemaV2.self, toVersion: SchemaV3.self)
        ]
    }
}
