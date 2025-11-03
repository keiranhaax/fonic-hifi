//
//  RecentSearchMigrationPlan.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData

/// Schema V1: Original schema before sourceURLHash/sourceBookmarkHash were added
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            TrackV1.self,
            Artist.self,
            Album.self,
            Playlist.self
        ]
    }

    /// V1 Track model snapshot - matches deployed schema before hash fields were added
    @Model
    final class TrackV1 {
        // MARK: - Identity
        var id: UUID
        var url: URL
        var fileName: String
        var fileExtension: String
        var fileSize: Int64
        var dateAdded: Date
        var dateModified: Date

        // MARK: - Source Tracking (original fields only - NO hash fields)
        var sourceURLBookmark: Data?
        var sourceURLString: String?

        // MARK: - Basic Metadata
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

        // MARK: - Extended Metadata
        var composer: String?
        var conductor: String?
        var label: String?
        var catalogNumber: String?
        var releaseDate: Date?
        var originalArtist: String?
        var comments: String?
        var lyrics: String?
        var artwork: Data?

        // MARK: - Technical Metadata
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

        // MARK: - User Data
        var rating: Int?
        var playCount: Int
        var lastPlayed: Date?
        var isFavorite: Bool
        var userTags: [String] = []
        var bpm: Int?
        var musicalKey: String?
        var replayGainTrack: Float?
        var replayGainAlbum: Float?

        // MARK: - Relationships
        @Relationship(deleteRule: .nullify)
        var albumRelation: Album?

        @Relationship(deleteRule: .nullify)
        var artistRelation: Artist?

        @Relationship(deleteRule: .nullify, inverse: \Playlist.tracks)
        var playlists: [Playlist] = []

        // MARK: - Initialization
        init(
            url: URL,
            title: String = "",
            artist: String = "",
            album: String = "",
            audioFormat: String,
            duration: TimeInterval = 0,
            sampleRate: Double = 44100,
            bitDepth: Int = 16,
            channels: Int = 2,
            isLossless: Bool = false
        ) {
            // Compute derived values BEFORE using them
            let computedFileName = url.deletingPathExtension().lastPathComponent
            let computedFileExtension = url.pathExtension.lowercased()

            // Initialize all stored properties
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
            userTags = []
            supportsGapless = false
            replayGainTrack = nil
            replayGainAlbum = nil
        }
    }
}

/// Schema V2: Current schema with sourceURLHash/sourceBookmarkHash and RecentSearch
enum SchemaV2: VersionedSchema {
    static let versionIdentifier = Schema.Version(2, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Track.self,          // Live Track with hash fields
            Artist.self,
            Album.self,
            Playlist.self,
            RecentSearch.self   // Added in V2
        ]
    }
}

/// Migration plan for adding RecentSearch to the schema
enum RecentSearchMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self, SchemaV2.self]
    }

    static var stages: [MigrationStage] {
        [
            .custom(
                fromVersion: SchemaV1.self,
                toVersion: SchemaV2.self,
                willMigrate: { context in
                    try migrateTrackBookmarkHashes(in: context)
                },
                didMigrate: { _ in }
            )
        ]
    }

    static func migrateTrackBookmarkHashes(in context: ModelContext) throws {
        let fetchDescriptor = FetchDescriptor<Track>()
        let tracks = try context.fetch(fetchDescriptor)

        guard !tracks.isEmpty else { return }

        for track in tracks {
            if track.sourceURLHash == nil,
               let source = track.sourceURLString,
               let url = URL(string: source) {
                track.sourceURLHash = url.librarySourceHash()
            }

            if track.sourceBookmarkHash == nil,
               let bookmark = track.sourceURLBookmark {
                track.sourceBookmarkHash = bookmark.sha256Hex()
            }
        }

        if context.hasChanges {
            try context.save()
        }
    }
}
