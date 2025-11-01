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
    private let logger = Log.logger(.importService)
    private let statisticsInvalidator: () -> Void
    private let fileProcessingConcurrency: Int

    // MARK: - Private Properties

    private var importTask: Task<Void, Never>?

    // Transaction tracking
    private var currentTransaction: ImportTransaction?

    // MARK: - Initialization

    public init(
        trackDataActor: TrackDataActor,
        metadataExtractor: MetadataExtracting,
        fileProcessingConcurrency: Int = 4,
        statisticsInvalidator: @escaping () -> Void = {},
    ) {
        self.fileProcessor = FileImportProcessor(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor,
        )
        self.statisticsInvalidator = statisticsInvalidator
        self.fileProcessingConcurrency = max(1, fileProcessingConcurrency)
    }

    // MARK: - Public Methods

    /// Import files from selected URLs (handles security-scoped resources)
    public func importFiles(from urls: [URL]) {
        Task(priority: .userInitiated) { [weak self] in
            guard let self else { return }

            let alreadyImporting = await MainActor.run { self.isImporting }
            guard !alreadyImporting else {
                self.logger.warning("Import already in progress")
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
                self.logger.info("Starting import of \(urls.count) URLs")
                Metrics.increment(.importsDiscovered, by: urls.count, metadata: [
                    "phase": "requested"
                ])
                await self.executeImportPipeline(urls: urls)
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
            self.importTask?.cancel()
            self.importTask = nil
            self.isImporting = false
            self.statusMessage = "Import cancelled"
        }

        self.logger.info("Import operation cancelled")
    }

    /// Check if a file is already in the library
    public func isFileInLibrary(_ url: URL) async -> Bool {
        await self.fileProcessor.fileExists(url)
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

            let bookmark = hasSecurityScope ? try? url.bookmarkData(
                options: [],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) : nil

            let file = FileImportProcessor.DiscoveredAudioFile(originalURL: url, securityScopedBookmark: bookmark)
            let identifier = try await self.fileProcessor.processAudioFile(file)
            self.recentlyImported.append(identifier)
            statisticsInvalidator()
            return identifier
        } catch {
            self.logger.error("Failed to import single file: \(error.localizedDescription)")
            self.importErrors.append(ImportError(
                url: url,
                error: error,
                message: "Failed to import file",
            ))
            return nil
        }
    }

    // MARK: - Private Methods

    func executeImportPipeline(urls: [URL]) async {
        let concurrency = fileProcessingConcurrency
        let discoveryStarted = Date()
        var successes = 0
        var failures = 0
        var accumulatedDuration: TimeInterval = 0
        var totalDiscovered = 0

        self.statusMessage = "Scanning for audio files..."

        let (queueStream, queueContinuation) = AsyncStream<FileImportProcessor.DiscoveredAudioFile>.makeStream(
            bufferingPolicy: .bufferingOldest(concurrency * 4)
        )

        @Sendable
        func enqueue(_ file: FileImportProcessor.DiscoveredAudioFile) async -> Bool {
            var pending = file

            while true {
                switch queueContinuation.yield(pending) {
                case .enqueued:
                    return true
                case let .dropped(dropped):
                    pending = dropped
                    await Task.yield()
                case .terminated:
                    return false
                @unknown default:
                    return false
                }
            }
        }

        let discoveryTask = Task(priority: .userInitiated) {
            let discoveryStream = await self.fileProcessor.discoverAudioFilesStream(from: urls)

            for await file in discoveryStream {
                if Task.isCancelled { break }

                guard await enqueue(file) else { break }

                await MainActor.run {
                    totalDiscovered += 1
                    self.totalFiles = totalDiscovered
                    if totalDiscovered == 1 {
                        self.statusMessage = "Importing 1 file (concurrency \(concurrency))"
                    } else {
                        self.statusMessage = "Importing \(totalDiscovered) files (concurrency \(concurrency))"
                        if totalDiscovered % 25 == 0 {
                            self.logger.info("import.discovery.progress discovered=\(totalDiscovered) concurrency=\(concurrency)")
                        }
                    }
                }

                Metrics.increment(.importsDiscovered, metadata: [
                    "file": LogPrivacy.filename(file.originalURL)
                ])
            }

            queueContinuation.finish()

            let discoveryElapsed = Date().timeIntervalSince(discoveryStarted)
            await MainActor.run {
                self.logger.info("import.discovery.summary discovered=\(totalDiscovered) elapsed=\(String(format: "%.2f", discoveryElapsed))")
            }
        }

        let processingStarted = Date()
        let stream = await self.fileProcessor.processFilesStream(
            queueStream,
            maxConcurrentTasks: concurrency
        )

        for await result in stream {
            if Task.isCancelled {
                discoveryTask.cancel()
                queueContinuation.finish()
                _ = await discoveryTask.result
                self.statusMessage = "Import cancelled"
                self.isImporting = false
                self.logger.info("Import task cancelled")
                return
            }

            accumulatedDuration += result.duration

            if let identifier = result.identifier {
                self.recentlyImported.append(identifier)
                successes += 1
                statisticsInvalidator()
                Metrics.increment(.importsCompleted, metadata: [
                    "file": LogPrivacy.filename(result.file.originalURL),
                    "duration": String(format: "%.2f", result.duration)
                ])
            } else {
                failures += 1
                let message = result.errorDescription ?? "Unknown failure"
                let failure: Error = result.error ?? ImportServiceError.processingFailed(message)
                self.importErrors.append(ImportError(
                    url: result.file.originalURL,
                    error: failure,
                    message: message
                ))
                Metrics.increment(.importsFailed, metadata: [
                    "file": LogPrivacy.filename(result.file.originalURL),
                    "reason": LogPrivacy.truncated(message, limit: 60)
                ])
            }

            self.updateProgress()

            let processed = self.filesProcessed
            if processed % 20 == 0 || processed == self.totalFiles {
                let elapsed = Date().timeIntervalSince(processingStarted)
                let throughput = elapsed > 0 ? Double(processed) / elapsed : Double(processed)
                let remaining = self.totalFiles - processed
                let throughputLabel = String(format: "%.2f", throughput)
                self.logger.info(
                    """
                    import.pipeline.progress processed=\(processed) successes=\(successes)
                    failures=\(failures) remaining=\(remaining)
                    discovered=\(self.totalFiles) concurrency=\(concurrency) throughput=\(throughputLabel)
                    """
                )
            }
        }

        await discoveryTask.value

        if Task.isCancelled {
            self.statusMessage = "Import cancelled"
            self.isImporting = false
            self.logger.info("Import task cancelled")
            return
        }

        guard totalDiscovered > 0 else {
            self.statusMessage = "No audio files found"
            self.isImporting = false
            return
        }

        let elapsed = Date().timeIntervalSince(processingStarted)
        let summary = "Import completed: \(successes) of \(self.totalFiles) files imported"
        self.statusMessage = summary
        self.isImporting = false
        let averageDuration = self.totalFiles > 0 ? accumulatedDuration / Double(self.totalFiles) : 0
        self.logger.info(
            """
            Import completed successfully:
            discovered=\(totalDiscovered) imported=\(successes) failed=\(failures)
            avgDuration=\(String(format: "%.2f", averageDuration)) elapsed=\(String(format: "%.2f", elapsed))
            """
        )
    }

    // MARK: - File Management (Delegated to FileImportProcessor)

    // All file I/O operations moved to FileImportProcessor actor

    /// Verify that a track file is accessible for playback
    public func verifyTrackAccess(_ track: Track) -> Bool {
        let fileExists = FileManager.default.fileExists(atPath: track.url.path)

        if !fileExists {
            self.logger.warning("Track file not found: \(LogPrivacy.filename(track.url))")
        }

        return fileExists
    }

    /// Update import progress
    private func updateProgress() {
        self.filesProcessed += 1
        self.importProgress = self.totalFiles > 0 ? Double(self.filesProcessed) / Double(self.totalFiles) : 0.0
        self.statusMessage = "Processed \(self.filesProcessed) of \(self.totalFiles) files"
    }
}

// MARK: - Supporting Types

extension LibraryImportService: @unchecked Sendable {}

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

enum ImportServiceError: Error {
    case serviceUnavailable
    case processingFailed(String)
}
