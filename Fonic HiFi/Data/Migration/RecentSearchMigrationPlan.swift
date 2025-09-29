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
            RecentSearch.self,
        ]
    }
}

/// Migration plan for adding RecentSearch to the schema
enum RecentSearchMigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] {
        [SchemaV1.self]
    }

    static var stages: [MigrationStage] {
        // Empty stages = lightweight migration
        // SwiftData will automatically handle adding the new model
        []
    }
}
