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

    /// Whether the most recent pipeline reached a terminal completion state.
    /// This is independent from the localized status text so presentation code
    /// never has to parse a translated sentence.
    @Published public private(set) var isImportComplete: Bool = false

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
    private let mutationPolicy: DataMutationPolicy

    // MARK: - Private Properties

    private var importTask: Task<Void, Never>?
    private var importGeneration: UUID?

    // MARK: - Initialization

    public init(
        trackDataActor: TrackDataActor,
        metadataExtractor: MetadataExtracting,
        fileProcessingConcurrency: Int = 4,
        mutationPolicy: DataMutationPolicy = .normal,
        statisticsInvalidator: @escaping () -> Void = {},
    ) {
        self.fileProcessor = FileImportProcessor(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor,
        )
        self.statisticsInvalidator = statisticsInvalidator
        self.fileProcessingConcurrency = max(1, fileProcessingConcurrency)
        self.mutationPolicy = mutationPolicy
    }

    init(
        fileProcessor: FileImportProcessor,
        fileProcessingConcurrency: Int = 4,
        mutationPolicy: DataMutationPolicy = .normal,
        statisticsInvalidator: @escaping () -> Void = {},
    ) {
        self.fileProcessor = fileProcessor
        self.statisticsInvalidator = statisticsInvalidator
        self.fileProcessingConcurrency = max(1, fileProcessingConcurrency)
        self.mutationPolicy = mutationPolicy
    }

    // MARK: - Public Methods

    /// Import files from selected URLs (handles security-scoped resources)
    public func importFiles(from urls: [URL]) {
        guard mutationPolicy == .normal else {
            rejectReadOnlyImport(url: urls.first)
            return
        }

        guard !isImporting else {
            logger.warning("Import already in progress")
            return
        }

        importProgress = 0.0
        isImportComplete = false
        filesProcessed = 0
        totalFiles = 0
        importErrors.removeAll()
        recentlyImported.removeAll()
        isImporting = true
        statusMessage = ImportStatus.scanning

        let generation = UUID()
        importGeneration = generation
        let task = Task(priority: .userInitiated) { @MainActor [weak self] in
            guard let self, self.importGeneration == generation else { return }
            self.logger.info("Starting import of \(urls.count, privacy: .public) URLs")
            Metrics.increment(.importsDiscovered, by: urls.count, metadata: [
                "phase": "requested"
            ])
            await self.executeImportPipeline(urls: urls, generation: generation)

            guard self.importGeneration == generation else { return }
            self.importTask = nil
            self.importGeneration = nil
            self.isImporting = false
        }
        importTask = task
    }

    /// Cancel the current import operation
    public func cancelImport() {
        guard let task = importTask else {
            isImporting = false
            isImportComplete = false
            statusMessage = ImportStatus.cancelled
            return
        }

        // Keep the generation and task owned until the cancelled pipeline has
        // drained discovery and worker cleanup. This prevents a retrigger from
        // overlapping the previous import.
        task.cancel()
        isImportComplete = false
        statusMessage = ImportStatus.cancelled

        self.logger.info("Import operation cancelled")
    }

    /// Check if a file is already in the library
    public func isFileInLibrary(_ url: URL) async -> Bool {
        await self.fileProcessor.fileExists(url)
    }

    /// Import a single file (for testing or manual import)
    public func importSingleFile(_ url: URL) async -> PersistentIdentifier? {
        guard mutationPolicy == .normal else {
            rejectReadOnlyImport(url: url)
            return nil
        }

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
            self.logger.error("Failed to import single file: \(error.localizedDescription, privacy: .private)")
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
        await executeImportPipeline(urls: urls, generation: nil)
    }

    private func executeImportPipeline(urls: [URL], generation: UUID?) async {
        guard mutationPolicy == .normal else {
            rejectReadOnlyImport(url: urls.first)
            return
        }

        guard ownsImportState(generation) else { return }

        isImportComplete = false
        let concurrency = fileProcessingConcurrency
        let pipelineLogger = logger
        let discoveryStarted = Date()
        var successes = 0
        defer {
            if successes > 0 {
                statisticsInvalidator()
            }
        }
        var duplicates = 0
        var failures = 0
        var accumulatedDuration: TimeInterval = 0
        var totalDiscovered = 0

        self.statusMessage = ImportStatus.scanning

        let queueCapacity = max(1, concurrency * 4)
        let queueSemaphore = AsyncSemaphore(value: queueCapacity)
        let (queueStream, queueContinuation) = AsyncStream<FileImportProcessor.DiscoveredAudioFile>.makeStream(
            bufferingPolicy: .bufferingOldest(queueCapacity)
        )

        @Sendable
        func enqueue(_ file: FileImportProcessor.DiscoveredAudioFile) async -> Bool {
            do {
                try await queueSemaphore.acquire()
            } catch {
                return false
            }

            switch queueContinuation.yield(file) {
            case .enqueued:
                return true
            case .dropped:
                await queueSemaphore.release()
                pipelineLogger.error("Import queue dropped a discovered file")
                return false
            case .terminated:
                await queueSemaphore.release()
                return false
            @unknown default:
                await queueSemaphore.release()
                return false
            }
        }

        let discoveryTask = Task(priority: .userInitiated) {
            let discoveryStream = await self.fileProcessor.discoverAudioFilesStream(from: urls)

            for await file in discoveryStream {
                if Task.isCancelled { break }

                guard await enqueue(file) else { break }

                await MainActor.run {
                    guard self.ownsImportState(generation) else { return }
                    totalDiscovered += 1
                    self.totalFiles = totalDiscovered
                    if totalDiscovered == 1 {
                        self.statusMessage = ImportStatus.importingSingleFile(concurrency: concurrency)
                    } else {
                        self.statusMessage = ImportStatus.importingFiles(
                            totalDiscovered,
                            concurrency: concurrency
                        )
                        if totalDiscovered % 25 == 0 {
                            self.logger.info("import.discovery.progress discovered=\(totalDiscovered, privacy: .public) concurrency=\(concurrency, privacy: .public)")
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
                guard self.ownsImportState(generation) else { return }
                self.logger.info("import.discovery.summary discovered=\(totalDiscovered, privacy: .public) elapsed=\(String(format: "%.2f", discoveryElapsed), privacy: .public)")
            }
        }

        let processingStarted = Date()
        let stream = await self.fileProcessor.processFilesStream(
            queueStream,
            maxConcurrentTasks: concurrency
        )

        for await result in stream {
            // A permit represents one discovered file waiting for a result.
            // Release it before handling cancellation so discovery cannot
            // remain blocked behind a result that will no longer be consumed.
            await queueSemaphore.release()

            if Task.isCancelled {
                discoveryTask.cancel()
                queueContinuation.finish()
                _ = await discoveryTask.result
                if ownsImportState(generation) {
                    self.isImportComplete = false
                    self.statusMessage = ImportStatus.cancelled
                    if generation == nil {
                        self.isImporting = false
                    }
                    self.logger.info("Import task cancelled")
                }
                return
            }

            guard ownsImportState(generation) else {
                discoveryTask.cancel()
                queueContinuation.finish()
                return
            }

            accumulatedDuration += result.duration

            if let identifier = result.identifier {
                self.recentlyImported.append(identifier)
                successes += 1
                Metrics.increment(.importsCompleted, metadata: [
                    "file": LogPrivacy.filename(result.file.originalURL),
                    "duration": String(format: "%.2f", result.duration)
                ])
            } else if result.isDuplicate {
                duplicates += 1
                self.logger.notice(
                    "Duplicate import skipped: \(result.file.originalURL.lastPathComponent, privacy: .private(mask: .hash))"
                )
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
                    import.pipeline.progress processed=\(processed, privacy: .public) successes=\(successes, privacy: .public)
                    duplicates=\(duplicates, privacy: .public) failures=\(failures, privacy: .public) remaining=\(remaining, privacy: .public)
                    discovered=\(self.totalFiles, privacy: .public) concurrency=\(concurrency, privacy: .public) throughput=\(throughputLabel, privacy: .public)
                    """
                )
            }
        }

        await withTaskCancellationHandler {
            await discoveryTask.value
        } onCancel: {
            discoveryTask.cancel()
            queueContinuation.finish()
        }

        guard ownsImportState(generation) else { return }

        if Task.isCancelled {
            self.isImportComplete = false
            self.statusMessage = ImportStatus.cancelled
            if generation == nil {
                self.isImporting = false
            }
            self.logger.info("Import task cancelled")
            return
        }

        guard totalDiscovered > 0 else {
            self.isImportComplete = false
            self.statusMessage = ImportStatus.noAudioFiles
            self.isImporting = false
            return
        }

        let elapsed = Date().timeIntervalSince(processingStarted)
        let summary = ImportStatus.completed(
            imported: successes,
            skipped: duplicates,
            failed: failures
        )
        self.statusMessage = summary
        self.isImportComplete = true
        self.isImporting = false
        let averageDuration = self.totalFiles > 0 ? accumulatedDuration / Double(self.totalFiles) : 0
        self.logger.info(
            """
            Import completed successfully:
            discovered=\(totalDiscovered, privacy: .public) imported=\(successes, privacy: .public) duplicates=\(duplicates, privacy: .public) failed=\(failures, privacy: .public)
            avgDuration=\(String(format: "%.2f", averageDuration), privacy: .public) elapsed=\(String(format: "%.2f", elapsed), privacy: .public)
            """
        )
    }

    // MARK: - File Management (Delegated to FileImportProcessor)

    // All file I/O operations moved to FileImportProcessor actor

    /// Verify that a track file is accessible for playback
    public func verifyTrackAccess(_ track: Track) -> Bool {
        let fileExists = FileManager.default.fileExists(atPath: track.url.path)

        if !fileExists {
            self.logger.warning("Track file not found: \(LogPrivacy.filename(track.url), privacy: .private(mask: .hash))")
        }

        return fileExists
    }

    /// Update import progress
    private func updateProgress() {
        self.filesProcessed += 1
        self.importProgress = self.totalFiles > 0 ? Double(self.filesProcessed) / Double(self.totalFiles) : 0.0
        self.statusMessage = ImportStatus.processed(
            self.filesProcessed,
            total: self.totalFiles
        )
    }

    private func ownsImportState(_ generation: UUID?) -> Bool {
        guard let generation else { return true }
        return importGeneration == generation
    }

    private func rejectReadOnlyImport(url: URL?) {
        let error = ImportServiceError.readOnly
        importErrors.append(ImportError(
            url: url,
            error: error,
            message: error.localizedDescription
        ))
        isImportComplete = false
        statusMessage = error.localizedDescription
        isImporting = false
    }
}

private enum ImportStatus {
    static let scanning = String(
        localized: "Scanning for audio files...",
        comment: "Import progress status while the app discovers supported audio files"
    )

    static let cancelled = String(
        localized: "Import cancelled",
        comment: "Import progress status after the user cancels an import"
    )

    static let noAudioFiles = String(
        localized: "No audio files found",
        comment: "Import progress status when discovery finds no supported audio files"
    )

    static func importingSingleFile(concurrency: Int) -> String {
        String(
            localized: "Importing 1 file (concurrency \(concurrency))",
            comment: "Import progress status after discovering the first audio file"
        )
    }

    static func importingFiles(_ count: Int, concurrency: Int) -> String {
        String(
            localized: "Importing \(count) files (concurrency \(concurrency))",
            comment: "Import progress status with discovered file and worker counts"
        )
    }

    static func processed(_ count: Int, total: Int) -> String {
        String(
            localized: "Processed \(count) of \(total) files",
            comment: "Import progress status with processed and discovered file counts"
        )
    }

    static func completed(imported: Int, skipped: Int, failed: Int) -> String {
        String(
            localized: "Import completed: \(imported) imported, \(skipped) skipped, \(failed) failed",
            comment: "Import completion summary with imported, duplicate, and failed file counts"
        )
    }
}

// MARK: - Supporting Types

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

public enum ImportServiceError: Error, LocalizedError, Equatable, Sendable {
    case serviceUnavailable
    case processingFailed(String)
    case readOnly

    public var errorDescription: String? {
        switch self {
        case .serviceUnavailable:
            "The library import service is unavailable."
        case let .processingFailed(message):
            message
        case .readOnly:
            "Import is unavailable while Fonic HiFi is in read-only recovery mode."
        }
    }
}
