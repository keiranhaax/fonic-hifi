//
//  ImportSession.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData
import OSLog

// MARK: - Protocol Definition

public protocol ImportSessionProtocol: Actor {
    // Transaction Management
    func beginTransaction() async throws
    func commit() async throws
    func rollback() async

    // Import Operations
    func addFile(_ url: URL) async throws -> UUID
    func addFiles(_ urls: [URL]) async throws -> [UUID]
    func removeFile(_ id: UUID) async throws

    // Progress Tracking
    var progress: ImportProgress { get async }
    func observeProgress() -> AsyncStream<ImportProgress>

    // Validation
    func validateFile(_ url: URL) async throws -> ValidationResult
    func checkDuplicate(_ url: URL) async -> Bool
}

// MARK: - Import Progress

public struct ImportProgress: Sendable {
    public let totalFiles: Int
    public let processedFiles: Int
    public let currentFile: String?
    public let phase: ImportPhase
    public let errors: [ImportSessionError]

    public var percentComplete: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles) * 100
    }
}

public enum ImportPhase: Sendable {
    case idle
    case validating
    case extractingMetadata
    case copyingFiles
    case savingToDatabase
    case complete
}

public struct ValidationResult: Sendable {
    public let isValid: Bool
    public let format: AudioFormat?
    public let issues: [ImportValidationIssue]
}

public enum ImportValidationIssue: Sendable {
    case unsupportedFormat
    case corruptedFile
    case missingMetadata
    case fileTooLarge(size: Int64)
    case duplicateFile(existingId: UUID)
}

public enum ImportSessionError: Error, Sendable {
    case transactionNotStarted
    case transactionAlreadyStarted
    case fileNotFound(URL)
    case fileAccessDenied(URL)
    case metadataExtractionFailed(URL, String)
    case fileCopyFailed(from: URL, to: URL, String)
    case databaseSaveFailed(String)
    case rollbackFailed(String)
}

/// Actor for managing transactional import operations
public actor ImportSession: ImportSessionProtocol {

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
    private var progressTracker = Progress(totalUnitCount: 0)
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
        progressTracker.totalUnitCount = Int64(items.count)

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
                progressTracker.completedUnitCount = Int64(index + 1)

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
        progressTracker = Progress(totalUnitCount: 0)
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
        progressTracker = Progress(totalUnitCount: 0)

        logger.info("Import session rolled back")
    }

    /// Get current progress
    public func getProgress() -> (completed: Int, total: Int, currentItem: String?) {
        let completed = Int(progressTracker.completedUnitCount)
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

    // MARK: - ImportSessionProtocol Implementation

    private var transactionStarted = false
    private var fileIdMap: [UUID: ImportItem] = [:]
    private var currentPhase = ImportPhase.idle
    private var sessionErrors: [ImportSessionError] = []

    /// Begin a new import transaction
    public func beginTransaction() async throws {
        guard !transactionStarted else {
            throw ImportSessionError.transactionAlreadyStarted
        }

        transactionStarted = true
        items.removeAll()
        copiedFiles.removeAll()
        savedTrackIds.removeAll()
        fileIdMap.removeAll()
        sessionErrors.removeAll()
        currentPhase = .idle
        progressTracker = Progress(totalUnitCount: 0)

        logger.info("Import transaction started")
    }

    /// Add a single file to the import session
    public func addFile(_ url: URL) async throws -> UUID {
        guard transactionStarted else {
            throw ImportSessionError.transactionNotStarted
        }

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportSessionError.fileNotFound(url)
        }

        // Use existing addItem logic
        try await addItem(url)

        // Generate and track ID for this item
        let id = UUID()
        if let lastItem = items.last {
            fileIdMap[id] = lastItem
        }

        return id
    }

    /// Add multiple files to the import session
    public func addFiles(_ urls: [URL]) async throws -> [UUID] {
        guard transactionStarted else {
            throw ImportSessionError.transactionNotStarted
        }

        var ids: [UUID] = []
        for url in urls {
            let id = try await addFile(url)
            ids.append(id)
        }
        return ids
    }

    /// Remove a file from the import session
    public func removeFile(_ id: UUID) async throws {
        guard transactionStarted else {
            throw ImportSessionError.transactionNotStarted
        }

        if let item = fileIdMap[id],
           let index = items.firstIndex(where: { $0.sourceURL == item.sourceURL }) {
            items.remove(at: index)
            fileIdMap.removeValue(forKey: id)
            progressTracker.totalUnitCount = Int64(items.count)
        }
    }

    /// Get current import progress
    public var progress: ImportProgress {
        get async {
            let (completed, total, currentFile) = getProgress()
            return ImportProgress(
                totalFiles: total,
                processedFiles: completed,
                currentFile: currentFile,
                phase: currentPhase,
                errors: sessionErrors
            )
        }
    }

    /// Observe progress changes as a stream
    public func observeProgress() -> AsyncStream<ImportProgress> {
        AsyncStream { continuation in
            Task {
                while !Task.isCancelled {
                    let currentProgress = await self.progress
                    continuation.yield(currentProgress)

                    if currentProgress.phase == .complete {
                        continuation.finish()
                        break
                    }

                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                }
            }
        }
    }

    /// Validate a file before importing
    public func validateFile(_ url: URL) async throws -> ValidationResult {
        var issues: [ImportValidationIssue] = []

        // Check file exists
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ImportSessionError.fileNotFound(url)
        }

        // Check file size
        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? Int64 {
            if fileSize > 500_000_000 { // 500MB limit
                issues.append(ImportValidationIssue.fileTooLarge(size: fileSize))
            }
        }

        // Check duplicate
        let isDuplicate = await checkDuplicate(url)
        if isDuplicate {
            // Try to find existing track ID
            if (try? await trackDataActor.trackExists(for: url)) != nil {
                issues.append(ImportValidationIssue.duplicateFile(existingId: UUID()))
            }
        }

        // Try to extract metadata to validate format
        do {
            let _ = try await metadataExtractor.extractTrackMetadata(from: url)
            let format = AudioFormat.from(url: url)

            return ValidationResult(
                isValid: issues.isEmpty,
                format: format,
                issues: issues
            )
        } catch {
            issues.append(ImportValidationIssue.corruptedFile)
            return ValidationResult(
                isValid: false,
                format: nil,
                issues: issues
            )
        }
    }

    /// Check if a file is a duplicate
    public func checkDuplicate(_ url: URL) async -> Bool {
        do {
            let existingTrack = try await trackDataActor.trackExists(for: url)
            return existingTrack != nil
        } catch {
            return false
        }
    }
}