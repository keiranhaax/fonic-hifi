//
//  DataManager+Maintenance.swift
//  Fonic HiFi
//
//  Created by Droid on 10/07/25.
//

import Foundation

@MainActor
public extension DataManager {
    private static let albumArtistBackfillDefaultsKey = "library.relationshipBackfill.v1.completed"

    func cleanupMissingFiles() async throws -> Int {
        do {
            let removedCount = try await trackDataActor.cleanupMissingFiles()
            logger.info("Cleanup completed: removed \(removedCount, privacy: .public) missing files")
            if removedCount > 0 {
                invalidateLibrary()
            }
            return removedCount
        } catch {
            logger.error("Failed to cleanup missing files: \(error.localizedDescription, privacy: .private)")
            throw DataManagerError.cleanupFailed(error)
        }
    }

    func backfillAlbumArtistRelationshipsIfNeeded() async {
        guard !UserDefaults.standard.bool(forKey: Self.albumArtistBackfillDefaultsKey) else {
            return
        }

        do {
            let result = try await trackDataActor.backfillAlbumArtistRelationships()
            if result.updatedTracks > 0 || result.createdAlbums > 0 || result.createdArtists > 0 {
                invalidateLibrary()
            }
            UserDefaults.standard.set(true, forKey: Self.albumArtistBackfillDefaultsKey)
            logger.info(
                """
                Relationship backfill complete
                scanned=\(result.scannedTracks, privacy: .public)
                updated=\(result.updatedTracks, privacy: .public)
                albumsCreated=\(result.createdAlbums, privacy: .public)
                artistsCreated=\(result.createdArtists, privacy: .public)
                """
            )
        } catch {
            logger.error("Relationship backfill failed: \(error.localizedDescription, privacy: .private)")
        }
    }
}
