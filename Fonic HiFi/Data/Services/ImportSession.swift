//
//  ImportSession.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData
import OSLog

/// Actor for managing transactional import operations
public actor ImportSession {

    // MARK: - Types

    public struct ImportItem: Sendable {
        public var sourceURL: URL
        public var destinationURL: URL
        public var metadata: TrackMetadata
        public var status: ImportStatus
    }

    public enum ImportStatus: Sendable {
        case pending
        case extractingMetadata
        case copying
        case savingToDatabase
        case complete
        case failed(ImportError)
    }

    public enum ImportError: Error, LocalizedError {
        case metadataExtractionFailed(Error)
        case fileCopyFailed(Error)
        case databaseSaveFailed(Error)
        case transactionRolledBack

        public var errorDescription: String? {
            switch self {
            case .metadataExtractionFailed(let error):
                return "Failed to extract metadata: \(error.localizedDescription)"
            case .fileCopyFailed(let error):
                return "Failed to copy file: \(error.localizedDescription)"
            case .databaseSaveFailed(let error):
                return "Failed to save to database: \(error.localizedDescription)"
            case .transactionRolledBack:
                return "Import transaction was rolled back"
            }
        }
    }

    // MARK: - Properties

    private var items: [ImportItem] = []
    private var progress = Progress(totalUnitCount: 0)
    private let logger = Logger(subsystem: "com.fonichifi.data", category: "ImportSession")

    // Track successful operations for rollback
    private var copiedFiles: [URL] = []
    private var savedTrackIds: [PersistentIdentifier] = []

    // Dependencies
    private let trackDataActor: TrackDataActor
    private let metadataExtractor: MetadataExtractionService

    /// App container directory for storing copied music files
    private let musicContainerURL: URL

    // MARK: - Initialization

    public init(
        trackDataActor: TrackDataActor,
        metadataExtractor: MetadataExtractionService
    ) {
        self.trackDataActor = trackDataActor
        self.metadataExtractor = metadataExtractor

        // Setup music container URL
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        self.musicContainerURL = documentsURL.appendingPathComponent("Music", isDirectory: true)

        // Ensure directory exists
        try? FileManager.default.createDirectory(
            at: musicContainerURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
    }

    // MARK: - Public Methods

    /// Add an item to the import session
    public func addItem(_ url: URL) async throws {
        logger.info("Adding item to import session: \(url.lastPathComponent)")

        // Generate destination URL
        let destinationURL = generateUniqueDestinationURL(for: url)

        // Extract metadata first
        let metadata = try await metadataExtractor.extractTrackMetadata(from: url)

        let item = ImportItem(
            sourceURL: url,
            destinationURL: destinationURL,
            metadata: metadata,
            status: .pending
        )

        items.append(item)
        progress.totalUnitCount = Int64(items.count)

        logger.debug("Item added to session. Total items: \(self.items.count)")
    }

    /// Commit the import transaction
    public func commit() async throws {
        logger.info("Committing import session with \(self.items.count) items")

        for index in self.items.indices {
            self.items[index].status = .extractingMetadata

            do {
                // Already have metadata from addItem

                // Copy file
                self.items[index].status = .copying
                try await copyFile(from: self.items[index].sourceURL, to: self.items[index].destinationURL)
                copiedFiles.append(self.items[index].destinationURL)

                // Save to database
                self.items[index].status = .savingToDatabase
                let trackId = try await trackDataActor.createTrack(from: self.items[index].metadata)
                savedTrackIds.append(trackId)

                // Mark complete
                self.items[index].status = .complete
                progress.completedUnitCount = Int64(index + 1)

                logger.debug("Successfully imported: \(self.items[index].sourceURL.lastPathComponent)")

            } catch {
                self.items[index].status = .failed(ImportError.databaseSaveFailed(error))
                logger.error("Failed to import item: \(error.localizedDescription)")

                // Rollback on failure
                await rollback()
                throw ImportError.transactionRolledBack
            }
        }

        logger.info("Import session committed successfully")

        // Clear session after successful commit
        items.removeAll()
        copiedFiles.removeAll()
        savedTrackIds.removeAll()
        progress = Progress(totalUnitCount: 0)
    }

    /// Rollback the import transaction
    public func rollback() async {
        logger.warning("Rolling back import session")

        // Delete saved tracks from database
        for trackId in savedTrackIds {
            do {
                try await trackDataActor.deleteTrack(trackId)
                logger.debug("Rolled back track")
            } catch {
                logger.error("Failed to rollback track: \(error.localizedDescription)")
            }
        }

        // Delete copied files
        for fileURL in copiedFiles {
            do {
                if FileManager.default.fileExists(atPath: fileURL.path) {
                    try FileManager.default.removeItem(at: fileURL)
                    logger.debug("Deleted copied file: \(fileURL.lastPathComponent)")
                }
            } catch {
                logger.error("Failed to delete file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Clear session
        items.removeAll()
        copiedFiles.removeAll()
        savedTrackIds.removeAll()
        progress = Progress(totalUnitCount: 0)

        logger.info("Import session rolled back")
    }

    /// Get current progress
    public func getProgress() -> (completed: Int, total: Int, currentItem: String?) {
        let completed = Int(progress.completedUnitCount)
        let total = items.count
        let currentItem = items.first(where: {
            if case .extractingMetadata = $0.status { return true }
            if case .copying = $0.status { return true }
            if case .savingToDatabase = $0.status { return true }
            return false
        })?.sourceURL.lastPathComponent

        return (completed, total, currentItem)
    }

    // MARK: - Private Methods

    /// Copy a file with security-scoped access
    private func copyFile(from sourceURL: URL, to destinationURL: URL) async throws {
        // Start accessing security-scoped resource
        let startedAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    /// Generate a unique destination URL, handling duplicate file names
    private func generateUniqueDestinationURL(for sourceURL: URL) -> URL {
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        var destinationURL = musicContainerURL.appendingPathComponent("\(fileName).\(fileExtension)")

        // Handle duplicates by appending a number
        var counter = 1
        while FileManager.default.fileExists(atPath: destinationURL.path) {
            let uniqueFileName = "\(fileName) (\(counter)).\(fileExtension)"
            destinationURL = musicContainerURL.appendingPathComponent(uniqueFileName)
            counter += 1
        }

        return destinationURL
    }
}