//
//  RecentSearchMigrationPlan.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData

/// Versioned schema that includes all models
enum SchemaV1: VersionedSchema {
    static let versionIdentifier = Schema.Version(1, 0, 0)

    static var models: [any PersistentModel.Type] {
        [
            Track.self,
            Artist.self,
            Album.self,
            Playlist.self,
            RecentSearch.self
        ]
    }
}

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
