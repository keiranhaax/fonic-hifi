//
//  ImportSession.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import OSLog
import SwiftData

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
            case let .metadataExtractionFailed(error):
                "Failed to extract metadata: \(error.localizedDescription)"
            case let .fileCopyFailed(error):
                "Failed to copy file: \(error.localizedDescription)"
            case let .databaseSaveFailed(error):
                "Failed to save to database: \(error.localizedDescription)"
            case .transactionRolledBack:
                "Import transaction was rolled back"
            }
        }
    }

    // MARK: - Properties

    private var items: [ImportItem] = []
    private var progressTracker = Progress(totalUnitCount: 0)
    private let logger = Log.logger(.dataImportSession)

    // Track successful operations for rollback
    private var copiedFiles: [URL] = []
    private var savedTrackIds: [PersistentIdentifier] = []

    // Dependencies
    private let trackDataActor: TrackDataActor
    private let metadataExtractor: any MetadataExtracting
    private let fileManager: FileManager

    /// App container directory for storing copied music files
    private let musicContainerURL: URL

    // MARK: - Initialization

    public init(
        trackDataActor: TrackDataActor,
        metadataExtractor: any MetadataExtracting,
        musicContainerURL: URL? = nil
    ) {
        self.trackDataActor = trackDataActor
        self.metadataExtractor = metadataExtractor
        self.fileManager = FileManager()

        // Setup music container URL
        if let musicContainerURL {
            self.musicContainerURL = musicContainerURL
        } else if let documentsURL = self.fileManager.urls(for: .documentDirectory, in: .userDomainMask).first {
            self.musicContainerURL = documentsURL.appendingPathComponent("Music", isDirectory: true)
        } else {
            let fallback = self.fileManager.temporaryDirectory.appendingPathComponent("Music", isDirectory: true)
            self.logger.error(
                """
                Documents directory unavailable; using temporary directory fallback at:
                \(fallback.path, privacy: .public)
                """
            )
            self.musicContainerURL = fallback
        }

        // Ensure directory exists
        try? self.fileManager.createDirectory(
            at: self.musicContainerURL,
            withIntermediateDirectories: true,
            attributes: nil,
        )
    }

    // MARK: - Public Methods

    /// Add an item to the import session
    public func addItem(_ url: URL) async throws {
        self.logger.info("Adding item to import session: \(url.lastPathComponent)")

        // Generate destination URL
        let destinationURL = self.generateUniqueDestinationURL(for: url)

        // Extract metadata first
        let metadata = try await self.metadataExtractor.extractTrackMetadata(from: url)

        let item = ImportItem(
            sourceURL: url,
            destinationURL: destinationURL,
            metadata: metadata,
            status: .pending,
        )

        self.items.append(item)
        self.progressTracker.totalUnitCount = Int64(self.items.count)

        self.logger.debug("Item added to session. Total items: \(self.items.count)")
    }

    /// Commit the import transaction
    public func commit() async throws {
        self.logger.info("Committing import session with \(self.items.count) items")

        for index in self.items.indices {
            self.items[index].status = .extractingMetadata

            do {
                // Already have metadata from addItem

                // Copy file
                self.items[index].status = .copying
                try await self.copyFile(from: self.items[index].sourceURL, to: self.items[index].destinationURL)
                self.copiedFiles.append(self.items[index].destinationURL)

                // Save to database
                self.items[index].status = .savingToDatabase
                let trackId = try await self.trackDataActor.createTrack(from: self.items[index].metadata)
                self.savedTrackIds.append(trackId)

                // Mark complete
                self.items[index].status = .complete
                self.progressTracker.completedUnitCount = Int64(index + 1)

                self.logger.debug("Successfully imported: \(self.items[index].sourceURL.lastPathComponent)")

            } catch {
                self.items[index].status = .failed(ImportError.databaseSaveFailed(error))
                self.logger.error("Failed to import item: \(error.localizedDescription)")

                // Rollback on failure
                await rollback()
                throw ImportError.transactionRolledBack
            }
        }

        self.logger.info("Import session committed successfully")

        // Clear session after successful commit
        self.items.removeAll()
        self.copiedFiles.removeAll()
        self.savedTrackIds.removeAll()
        self.progressTracker = Progress(totalUnitCount: 0)
    }

    /// Rollback the import transaction
    public func rollback() async {
        self.logger.warning("Rolling back import session")

        // Delete saved tracks from database
        for trackId in self.savedTrackIds {
            do {
                try await self.trackDataActor.deleteTrack(trackId)
                self.logger.debug("Rolled back track")
            } catch {
                self.logger.error("Failed to rollback track: \(error.localizedDescription)")
            }
        }

        // Delete copied files
        for fileURL in self.copiedFiles {
            do {
                if self.fileManager.fileExists(atPath: fileURL.path) {
                    try self.fileManager.removeItem(at: fileURL)
                    self.logger.debug("Deleted copied file: \(fileURL.lastPathComponent)")
                }
            } catch {
                self.logger.error("Failed to delete file \(fileURL.lastPathComponent): \(error.localizedDescription)")
            }
        }

        // Clear session
        self.items.removeAll()
        self.copiedFiles.removeAll()
        self.savedTrackIds.removeAll()
        self.progressTracker = Progress(totalUnitCount: 0)

        self.logger.info("Import session rolled back")
    }

    /// Get current progress
    public func getProgress() -> (completed: Int, total: Int, currentItem: String?) {
        let completed = Int(self.progressTracker.completedUnitCount)
        let total = self.items.count
        let currentItem = self.items.first(where: {
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

        try self.fileManager.copyItem(at: sourceURL, to: destinationURL)
    }

    /// Generate a unique destination URL, handling duplicate file names
    private func generateUniqueDestinationURL(for sourceURL: URL) -> URL {
        let fileName = sourceURL.deletingPathExtension().lastPathComponent
        let fileExtension = sourceURL.pathExtension
        var destinationURL = self.musicContainerURL.appendingPathComponent("\(fileName).\(fileExtension)")

        // Handle duplicates by appending a number
        var counter = 1
        while self.fileManager.fileExists(atPath: destinationURL.path) {
            let uniqueFileName = "\(fileName) (\(counter)).\(fileExtension)"
            destinationURL = self.musicContainerURL.appendingPathComponent(uniqueFileName)
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
        guard !self.transactionStarted else {
            throw ImportSessionError.transactionAlreadyStarted
        }

        self.transactionStarted = true
        self.items.removeAll()
        self.copiedFiles.removeAll()
        self.savedTrackIds.removeAll()
        self.fileIdMap.removeAll()
        self.sessionErrors.removeAll()
        self.currentPhase = .idle
        self.progressTracker = Progress(totalUnitCount: 0)

        self.logger.info("Import transaction started")
    }

    /// Add a single file to the import session
    public func addFile(_ url: URL) async throws -> UUID {
        guard self.transactionStarted else {
            throw ImportSessionError.transactionNotStarted
        }

        guard self.fileManager.fileExists(atPath: url.path) else {
            throw ImportSessionError.fileNotFound(url)
        }

        // Use existing addItem logic
        try await addItem(url)

        // Generate and track ID for this item
        let id = UUID()
        if let lastItem = self.items.last {
            self.fileIdMap[id] = lastItem
        }

        return id
    }

    /// Add multiple files to the import session
    public func addFiles(_ urls: [URL]) async throws -> [UUID] {
        guard self.transactionStarted else {
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
        guard self.transactionStarted else {
            throw ImportSessionError.transactionNotStarted
        }

        if let item = self.fileIdMap[id],
           let index = self.items.firstIndex(where: { $0.sourceURL == item.sourceURL }) {
            self.items.remove(at: index)
            self.fileIdMap.removeValue(forKey: id)
            self.progressTracker.totalUnitCount = Int64(self.items.count)
        }
    }

    /// Get current import progress
    public var progress: ImportProgress {
        get async {
            let (completed, total, currentFile) = self.getProgress()
            return ImportProgress(
                totalFiles: total,
                processedFiles: completed,
                currentFile: currentFile,
                phase: self.currentPhase,
                errors: self.sessionErrors,
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
        guard self.fileManager.fileExists(atPath: url.path) else {
            throw ImportSessionError.fileNotFound(url)
        }

        // Check file size
        let attributes = try self.fileManager.attributesOfItem(atPath: url.path)
        if let fileSize = attributes[.size] as? Int64 {
            if fileSize > 500_000_000 { // 500MB limit
                issues.append(ImportValidationIssue.fileTooLarge(size: fileSize))
            }
        }

        // Check duplicate
        let isDuplicate = await checkDuplicate(url)
        if isDuplicate {
            // Try to find existing track ID
            if await (try? self.trackDataActor.trackExists(for: url)) != nil {
                issues.append(ImportValidationIssue.duplicateFile(existingId: UUID()))
            }
        }

        // Try to extract metadata to validate format
        do {
            _ = try await self.metadataExtractor.extractTrackMetadata(from: url)
            let format = AudioFormat.from(url: url)

            return ValidationResult(
                isValid: issues.isEmpty,
                format: format,
                issues: issues,
            )
        } catch {
            issues.append(ImportValidationIssue.corruptedFile)
            return ValidationResult(
                isValid: false,
                format: nil,
                issues: issues,
            )
        }
    }

    /// Check if a file is a duplicate
    public func checkDuplicate(_ url: URL) async -> Bool {
        do {
            let existingTrack = try await self.trackDataActor.trackExists(for: url)
            return existingTrack != nil
        } catch {
            return false
        }
    }
}
