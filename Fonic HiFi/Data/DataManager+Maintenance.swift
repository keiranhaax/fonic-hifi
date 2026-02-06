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
            logger.info("Cleanup completed: removed \(removedCount) missing files")
            if removedCount > 0 {
                invalidateLibraryStatisticsCache()
            }
            return removedCount
        } catch {
            logger.error("Failed to cleanup missing files: \(error.localizedDescription)")
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
                invalidateLibraryStatisticsCache()
            }
            UserDefaults.standard.set(true, forKey: Self.albumArtistBackfillDefaultsKey)
            logger.info(
                """
                Relationship backfill complete
                scanned=\(result.scannedTracks)
                updated=\(result.updatedTracks)
                albumsCreated=\(result.createdAlbums)
                artistsCreated=\(result.createdArtists)
                """
            )
        } catch {
            logger.error("Relationship backfill failed: \(error.localizedDescription)")
        }
    }
}
