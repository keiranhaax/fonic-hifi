//
//  LibraryImportService.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Combine
import Foundation
import OSLog
import SwiftData

/// Service responsible for importing audio files into the library
/// UI-bound properties are @MainActor, file I/O delegated to FileImportProcessor actor
@MainActor
public final class LibraryImportService: ObservableObject {
    // MARK: - Published Properties

    /// Current import progress (0.0 to 1.0)
    @Published public private(set) var importProgress: Double = 0.0

    /// Whether an import is currently in progress
    @Published public private(set) var isImporting: Bool = false

    /// Current status message
    @Published public private(set) var statusMessage: String = ""

    /// Number of files processed
    @Published public private(set) var filesProcessed: Int = 0

    /// Total number of files to process
    @Published public private(set) var totalFiles: Int = 0

    /// Import errors encountered
    @Published public private(set) var importErrors: [ImportError] = []

    /// Recently imported track identifiers
    @Published public private(set) var recentlyImported: [PersistentIdentifier] = []

    // MARK: - Dependencies

    private let fileProcessor: FileImportProcessor
    private let logger = Logger(subsystem: "com.fonichifi.library", category: "LibraryImportService")

    // MARK: - Private Properties

    private var importTask: Task<Void, Never>?

    // Transaction tracking
    private var currentTransaction: ImportTransaction?

    // MARK: - Initialization

    public init(
        trackDataActor: TrackDataActor,
        metadataExtractor: MetadataExtractionService
    ) {
        self.fileProcessor = FileImportProcessor(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor
        )
    }

    // MARK: - Public Methods

    /// Import files from selected URLs (handles security-scoped resources)
    public func importFiles(from urls: [URL]) {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let alreadyImporting = await MainActor.run { self.isImporting }
            guard !alreadyImporting else {
                logger.warning("Import already in progress")
                return
            }

            await MainActor.run {
                self.importProgress = 0.0
                self.filesProcessed = 0
                self.totalFiles = 0
                self.importErrors.removeAll()
                self.recentlyImported.removeAll()
                self.isImporting = true
                self.statusMessage = "Scanning for audio files..."
            }

            let task = Task(priority: .userInitiated) { [weak self] in
                guard let self else { return }
                logger.info("Starting import of \(urls.count) URLs")
                await executeImportPipeline(urls: urls)
            }

            await MainActor.run {
                self.importTask?.cancel()
                self.importTask = task
            }

            await task.value

            await MainActor.run {
                self.importTask = nil
            }
        }
    }

    /// Cancel the current import operation
    public func cancelImport() {
        Task { @MainActor [weak self] in
            guard let self else { return }
            importTask?.cancel()
            importTask = nil
            isImporting = false
            statusMessage = "Import cancelled"
        }

        logger.info("Import operation cancelled")
    }

    /// Check if a file is already in the library
    public func isFileInLibrary(_ url: URL) async -> Bool {
        await fileProcessor.fileExists(url)
    }

    /// Import a single file (for testing or manual import)
    public func importSingleFile(_ url: URL) async -> PersistentIdentifier? {
        do {
            let hasSecurityScope = url.startAccessingSecurityScopedResource()
            defer {
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try await fileProcessor.processAudioFile(url, hasSecurityScope: hasSecurityScope)
        } catch {
            logger.error("Failed to import single file: \(error.localizedDescription)")
            importErrors.append(ImportError(
                url: url,
                error: error,
                message: "Failed to import file"
            ))
            return nil
        }
    }

    // MARK: - Private Methods

    private func executeImportPipeline(urls: [URL]) async {
        // Delegate file discovery to background actor
        let audioFilesWithScope = await fileProcessor.discoverAudioFiles(from: urls)

        totalFiles = audioFilesWithScope.count

        logger.info("Found \(audioFilesWithScope.count) audio files to import")

        guard !audioFilesWithScope.isEmpty else {
            statusMessage = "No audio files found"
            isImporting = false
            return
        }

        let batchSize = 10
        let batches = audioFilesWithScope.chunked(into: batchSize)

        for batch in batches {
            await processBatch(batch)

            if Task.isCancelled {
                statusMessage = "Import cancelled"
                isImporting = false
                logger.info("Import task cancelled")
                return
            }
        }

        statusMessage = "Import completed: \(filesProcessed) files imported"
        isImporting = false
        logger.info("Import completed successfully")
    }

    // MARK: - File Management (Delegated to FileImportProcessor)
    // All file I/O operations moved to FileImportProcessor actor

    /// Verify that a track file is accessible for playback
    public func verifyTrackAccess(_ track: Track) -> Bool {
        let fileExists = FileManager.default.fileExists(atPath: track.url.path)

        if !fileExists {
            logger.warning("Track file not found: \(track.url.lastPathComponent)")
        }

        return fileExists
    }

    /// Process a batch of audio files
    private func processBatch(_ filesWithScope: [(URL, Bool)]) async {
        // Process files sequentially to avoid concurrency issues with @MainActor properties
        for (url, hasSecurityScope) in filesWithScope {
            await processSingleFile(url, hasSecurityScope: hasSecurityScope)
        }
    }

    /// Process a single audio file
    private func processSingleFile(_ url: URL, hasSecurityScope: Bool) async {
        do {
            // Check if file already exists (delegated to actor)
            if await fileProcessor.fileExists(url) {
                logger.debug("File already in library: \(url.lastPathComponent)")
                await updateProgress()
                // Clean up security scope if needed
                if hasSecurityScope {
                    url.stopAccessingSecurityScopedResource()
                }
                return
            }

            // Import the file (delegated to actor for heavy I/O)
            let trackId = try await fileProcessor.processAudioFile(url, hasSecurityScope: hasSecurityScope)
            recentlyImported.append(trackId)
            logger.debug("Successfully imported track with ID: \(String(describing: trackId))")

        } catch {
            logger.error("Error processing file \(url.lastPathComponent): \(error.localizedDescription)")
            await MainActor.run {
                importErrors.append(ImportError(
                    url: url,
                    error: error,
                    message: "Failed to process audio file",
                ))
            }
        }

        await updateProgress()
    }

    /// Update import progress
    private func updateProgress() async {
        filesProcessed += 1
        importProgress = totalFiles > 0 ? Double(filesProcessed) / Double(totalFiles) : 0.0
        statusMessage = "Processed \(filesProcessed) of \(totalFiles) files"
    }
}

// MARK: - Supporting Types

/// Track import transaction for rollback support
private final class ImportTransaction {
    var importedFiles: [URL] = []
    var copiedFiles: [URL] = []
    var importedTracks: [PersistentIdentifier] = []
}

/// Error information for import failures
public struct ImportError: Identifiable, Equatable {
    public let id = UUID()
    public let url: URL?
    public let error: Error
    public let message: String
    public let timestamp: Date = .init()

    public static func == (lhs: ImportError, rhs: ImportError) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Extensions

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        stride(from: 0, to: count, by: size).map {
            Array(self[$0 ..< Swift.min($0 + size, count)])
        }
    }
}

enum ImportServiceError: Error {
    case serviceUnavailable
}
