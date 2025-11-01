//
//  DataManager+Maintenance.swift
//  Fonic HiFi
//
//  Created by Droid on 10/07/25.
//

import Foundation

@MainActor
public extension DataManager {
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
}
