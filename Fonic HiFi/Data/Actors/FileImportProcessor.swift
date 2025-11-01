//
//  FileImportProcessor.swift
//  Fonic HiFi
//
//  Created by Claude on 2025-09-30.
//

import Foundation
import OSLog
import SwiftData

protocol SecurityScopedAccessing: Sendable {
    func startAccessing(_ url: URL) -> Bool
    func stopAccessing(_ url: URL)
}

struct DefaultSecurityScopedAccessor: SecurityScopedAccessing {
    func startAccessing(_ url: URL) -> Bool {
        url.startAccessingSecurityScopedResource()
    }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

/// Actor responsible for file I/O operations during import
/// Runs off main thread to prevent UI blocking
actor FileImportProcessor {
    struct DiscoveredAudioFile: Sendable {
        let originalURL: URL
        let securityScopedBookmark: Data?
    }

    struct ProcessedFileError: Error, Sendable, LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    struct ProcessedFileResult: Sendable {
        let file: DiscoveredAudioFile
        let identifier: PersistentIdentifier?
        let error: ProcessedFileError?
        let duration: TimeInterval

        var succeeded: Bool { identifier != nil }
        var errorDescription: String? { error?.message }
    }

    // MARK: - Properties

    private let logger = Log.logger(.dataFileImportProcessor)
    private let trackDataActor: TrackDataActor
    private let metadataExtractor: MetadataExtracting
    private let securityAccessor: SecurityScopedAccessing

    private let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "alac", "wav", "aiff", "aif", "ape", "wv", "ogg", "opus"
    ]

    /// App container directory for storing copied music files
    private lazy var musicContainerURL: URL = {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsURL.appendingPathComponent("Music", isDirectory: true)
        }

        let fallback = FileManager.default.temporaryDirectory.appendingPathComponent("Music", isDirectory: true)
        self.logger.error(
            """
            Documents directory unavailable; using temporary directory fallback at:
            \(fallback.path, privacy: .public)
            """
        )
        return fallback
    }()

    // MARK: - Initialization

    init(
        trackDataActor: TrackDataActor,
        metadataExtractor: MetadataExtracting,
        securityAccessor: SecurityScopedAccessing = DefaultSecurityScopedAccessor(),
    ) {
        self.trackDataActor = trackDataActor
        self.metadataExtractor = metadataExtractor
        self.securityAccessor = securityAccessor
    }

    // MARK: - Public Methods

    /// Discover all audio files from URLs (handles directories recursively)
    func discoverAudioFiles(from urls: [URL]) async -> [DiscoveredAudioFile] {
        var audioFiles: [DiscoveredAudioFile] = []
        for await file in discoverAudioFilesStream(from: urls) {
            audioFiles.append(file)
        }
        return audioFiles
    }

    /// Discover audio files lazily via streaming sequence
    func discoverAudioFilesStream(from urls: [URL]) -> AsyncStream<DiscoveredAudioFile> {
        AsyncStream { continuation in
            Task { await self.emitDiscoveredFiles(from: urls, to: continuation) }
        }
    }

    /// Process multiple audio files with bounded concurrency as a streaming sequence.
    /// - Parameters:
    ///   - files: Files to import
    ///   - maxConcurrentTasks: Maximum concurrent processing tasks
    /// - Returns: Stream of results in order of completion
    func processFilesStream(
        _ files: [DiscoveredAudioFile],
        maxConcurrentTasks: Int = 3
    ) -> AsyncStream<ProcessedFileResult> {
        let stream = AsyncStream<DiscoveredAudioFile> { continuation in
            for file in files {
                continuation.yield(file)
            }
            continuation.finish()
        }
        return processFilesStream(stream, maxConcurrentTasks: maxConcurrentTasks)
    }

    func processFilesStream<S: AsyncSequence>(
        _ files: S,
        maxConcurrentTasks: Int = 3
    ) -> AsyncStream<ProcessedFileResult> where S.Element == DiscoveredAudioFile {
        AsyncStream { continuation in
            Task {
                var iterator = files.makeAsyncIterator()
                let log = logger

                func nextFile() async -> DiscoveredAudioFile? {
                    do {
                        return try await iterator.next()
                    } catch {
                        log.error(
                            "import.queue.iteratorFailed error=\(error.localizedDescription, privacy: .public)"
                        )
                        return nil
                    }
                }

                do {
                    try ensureMusicContainerExists()
                } catch {
                    logger.error("Failed to prepare music container: \(error.localizedDescription)")
                    while let file = await nextFile() {
                        continuation.yield(
                            ProcessedFileResult(
                                file: file,
                                identifier: nil,
                                error: ProcessedFileError(message: error.localizedDescription),
                                duration: 0
                            )
                        )
                    }
                    continuation.finish()
                    return
                }

                let baseDirectory = musicContainerURL
                let extractor = metadataExtractor
                let trackActor = trackDataActor
                let accessor = securityAccessor
                let startTime = Date()
                var nextProgressLog = startTime
                let concurrency = max(1, maxConcurrentTasks)

                var completed = 0
                var successes = 0
                var failures = 0
                var totalDuration: TimeInterval = 0
                var inFlight = 0
                var maxInFlight = 0

                await withTaskGroup(of: ProcessedFileResult?.self) { group in
                    func launchNext() async {
                        guard !Task.isCancelled else { return }
                        guard let nextFile = await nextFile() else { return }

                        inFlight += 1
                        if inFlight > maxInFlight {
                            maxInFlight = inFlight
                        }

                        group.addTask {
                            let taskStart = Date()
                            do {
                                let identifier = try await Self.importFile(
                                    nextFile,
                                    baseDirectory: baseDirectory,
                                    metadataExtractor: extractor,
                                    trackDataActor: trackActor,
                                    securityAccessor: accessor,
                                    logger: log
                                )
                                let duration = Date().timeIntervalSince(taskStart)
                                return ProcessedFileResult(
                                    file: nextFile,
                                    identifier: identifier,
                                    error: nil,
                                    duration: duration
                                )
                            } catch {
                                let duration = Date().timeIntervalSince(taskStart)
                                let filename = nextFile.originalURL.lastPathComponent
                                let errorDescription = error.localizedDescription
                                log.error(
                                    """
                                    File import failed for \(filename, privacy: .public):
                                    \(errorDescription, privacy: .public)
                                    """
                                )
                                return ProcessedFileResult(
                                    file: nextFile,
                                    identifier: nil,
                                    error: ProcessedFileError(message: error.localizedDescription),
                                    duration: duration
                                )
                            }
                        }
                    }

                    for _ in 0..<concurrency {
                        await launchNext()
                    }

                    while let result = await group.next() {
                        guard let result else { continue }

                        inFlight = max(inFlight - 1, 0)
                        completed += 1
                        totalDuration += result.duration

                        if result.succeeded {
                            successes += 1
                        } else {
                            failures += 1
                        }

                        continuation.yield(result)
                        await launchNext()

                        let now = Date()
                        if completed % 10 == 0 || now.timeIntervalSince(nextProgressLog) >= 5 {
                            let elapsed = now.timeIntervalSince(startTime)
                            let throughput = elapsed > 0 ? Double(completed) / elapsed : Double(completed)
                            log.info(
                                "import.queue.metrics completed=\(completed, privacy: .public) inFlight=\(inFlight, privacy: .public) maxInFlight=\(maxInFlight, privacy: .public) successes=\(successes, privacy: .public) failures=\(failures, privacy: .public) throughput=\(throughput, format: .fixed(precision: 2), privacy: .public)"
                            )
                            nextProgressLog = now
                        }

                        if Task.isCancelled {
                            break
                        }
                    }

                    group.cancelAll()
                }

                let totalElapsed = Date().timeIntervalSince(startTime)
                let averageDuration = completed > 0 ? totalDuration / Double(completed) : 0
                logger.info(
                    "import.queue.summary files=\(completed, privacy: .public) successes=\(successes, privacy: .public) failures=\(failures, privacy: .public) maxInFlight=\(maxInFlight, privacy: .public) elapsed=\(totalElapsed, format: .fixed(precision: 2), privacy: .public) avgDuration=\(averageDuration, format: .fixed(precision: 2), privacy: .public)"
                )

                continuation.finish()
            }
        }
    }

    /// Process multiple audio files with bounded concurrency
    /// - Parameters:
    ///   - files: Files to import
    ///   - maxConcurrentTasks: Maximum concurrent processing tasks
    /// - Returns: Results for each processed file in order of completion
    func processFiles(
        _ files: [DiscoveredAudioFile],
        maxConcurrentTasks: Int = 3,
    ) async -> [ProcessedFileResult] {
        var results: [ProcessedFileResult] = []
        for await result in processFilesStream(files, maxConcurrentTasks: maxConcurrentTasks) {
            results.append(result)
        }
        return results
    }

    /// Process a single audio file (extract metadata, copy to container, create Track)
    func processAudioFile(_ file: DiscoveredAudioFile) async throws -> PersistentIdentifier {
        // Ensure music container exists
        try ensureMusicContainerExists()

        return try await Self.importFile(
            file,
            baseDirectory: musicContainerURL,
            metadataExtractor: metadataExtractor,
            trackDataActor: trackDataActor,
            securityAccessor: securityAccessor,
            logger: logger,
        )
    }

    /// Check if a file already exists in the library
    func fileExists(_ url: URL) async -> Bool {
        do {
            let existingTrackId = try await trackDataActor.trackExists(for: url)
            return existingTrackId != nil
        } catch {
            logger.error("Error checking if file exists: \(error.localizedDescription)")
            return false
        }
    }

    // MARK: - Private Methods

    private func emitDiscoveredFiles(
        from urls: [URL],
        to continuation: AsyncStream<DiscoveredAudioFile>.Continuation
    ) async {
        var totalYielded = 0

        for url in urls {
            if Task.isCancelled { break }

            var isDirectory: ObjCBool = false
            let accessed = securityAccessor.startAccessing(url)

            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                if accessed {
                    securityAccessor.stopAccessing(url)
                }
                continue
            }

            if isDirectory.boolValue {
                enumerateAudioFiles(in: url, requiresSecurityScope: accessed) { file in
                    totalYielded += 1
                    continuation.yield(file)
                }
            } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
                let bookmark = bookmarkData(for: url, requiresSecurityScope: accessed, alreadyAccessing: accessed)
                if accessed {
                    securityAccessor.stopAccessing(url)
                }
                totalYielded += 1
                continuation.yield(DiscoveredAudioFile(originalURL: url, securityScopedBookmark: bookmark))
            } else {
                if accessed {
                    securityAccessor.stopAccessing(url)
                }
            }
        }

        continuation.finish()
        logger.info("import.discovery.summary urls=\(urls.count, privacy: .public) files=\(totalYielded, privacy: .public)")
    }

    private func enumerateAudioFiles(
        in directoryURL: URL,
        requiresSecurityScope: Bool,
        yield: (DiscoveredAudioFile) -> Void
    ) {
        let fileManager = FileManager.default

        defer {
            if requiresSecurityScope {
                securityAccessor.stopAccessing(directoryURL)
            }
        }

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return
        }

        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled { break }

            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile
            else {
                continue
            }

            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                let bookmark = bookmarkData(for: fileURL, requiresSecurityScope: requiresSecurityScope)
                yield(DiscoveredAudioFile(originalURL: fileURL, securityScopedBookmark: bookmark))
            }
        }
    }

    private func scanDirectory(_ directoryURL: URL, requiresSecurityScope: Bool) async -> [DiscoveredAudioFile] {
        var audioFiles: [DiscoveredAudioFile] = []
        enumerateAudioFiles(in: directoryURL, requiresSecurityScope: requiresSecurityScope) { file in
            audioFiles.append(file)
        }
        return audioFiles
    }

    private func ensureMusicContainerExists() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: self.musicContainerURL.path) {
            try fileManager.createDirectory(
                at: self.musicContainerURL,
                withIntermediateDirectories: true,
                attributes: nil,
            )
            self.logger.info("Created music container at: \(self.musicContainerURL.path)")
        }
    }

    private func copyFileToContainer(_ url: URL) throws -> URL {
        let fileManager = FileManager.default
        let filename = url.lastPathComponent
        let destinationURL = self.musicContainerURL.appendingPathComponent(filename)

        // Handle duplicates
        var finalDestination = destinationURL
        var counter = 1
        while fileManager.fileExists(atPath: finalDestination.path) {
            let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let newFilename = "\(nameWithoutExtension) (\(counter)).\(ext)"
            finalDestination = self.musicContainerURL.appendingPathComponent(newFilename)
            counter += 1
        }

        // Copy file
        try fileManager.copyItem(at: url, to: finalDestination)

        logger.debug("Copied file to: \(finalDestination.path)")
        return finalDestination
    }

    private func bookmarkData(
        for url: URL,
        requiresSecurityScope: Bool,
        alreadyAccessing: Bool = false,
    ) -> Data? {
        var started = false
        if requiresSecurityScope, !alreadyAccessing {
            started = securityAccessor.startAccessing(url)
        }

        defer {
            if requiresSecurityScope, !alreadyAccessing, started {
                securityAccessor.stopAccessing(url)
            }
        }

        do {
            return try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        } catch {
            logger.error("Failed to create bookmark for \(url.lastPathComponent): \(error.localizedDescription)")
            return nil
        }
    }

    private static func importFile(
        _ file: DiscoveredAudioFile,
        baseDirectory: URL,
        metadataExtractor: MetadataExtracting,
        trackDataActor: TrackDataActor,
        securityAccessor: SecurityScopedAccessing,
        logger: Logger,
    ) async throws -> PersistentIdentifier {
        let (resolvedURL, stopAccess) = try resolveSecurityScopedURL(
            for: file,
            securityAccessor: securityAccessor,
        )
        defer { stopAccess() }

        if try await trackDataActor.trackExists(for: file.originalURL, bookmark: file.securityScopedBookmark) != nil {
            logger.notice("Duplicate import skipped for: \(file.originalURL.lastPathComponent, privacy: .public)")
            throw ProcessedFileError(message: "Duplicate file already exists")
        }

        let copiedFileURL = try copyFile(
            from: resolvedURL,
            to: baseDirectory,
            logger: logger,
        )

        let trackMetadata = try await metadataExtractor.extractTrackMetadata(from: copiedFileURL)
        let enrichedMetadata = trackMetadata.withSourceInfo(
            sourceURL: file.originalURL,
            sourceBookmark: file.securityScopedBookmark
        )

        return try await trackDataActor.createTrack(from: enrichedMetadata)
    }

    private static func resolveSecurityScopedURL(
        for file: DiscoveredAudioFile,
        securityAccessor: SecurityScopedAccessing,
    ) throws -> (URL, @Sendable () -> Void) {
        var resolvedURL = file.originalURL
        var startedAccessing = false

        if let bookmark = file.securityScopedBookmark {
            var isStale = false
            resolvedURL = try URL(
                resolvingBookmarkData: bookmark,
                options: [],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale,
            )
            startedAccessing = securityAccessor.startAccessing(resolvedURL)
        } else {
            startedAccessing = securityAccessor.startAccessing(resolvedURL)
        }

        let finalURL = resolvedURL
        let didStartAccessing = startedAccessing

        let stopAccess: @Sendable () -> Void = {
            if didStartAccessing {
                securityAccessor.stopAccessing(finalURL)
            }
        }

        return (resolvedURL, stopAccess)
    }

    private static func copyFile(
        from sourceURL: URL,
        to baseDirectory: URL,
        logger: Logger,
    ) throws -> URL {
        let fileManager = FileManager.default
        var destinationURL = baseDirectory.appendingPathComponent(sourceURL.lastPathComponent)

        while true {
            do {
                try fileManager.copyItem(at: sourceURL, to: destinationURL)
                logger.debug("Copied file to: \(destinationURL.path)")
                return destinationURL
            } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError {
                let baseName = sourceURL.deletingPathExtension().lastPathComponent
                let ext = sourceURL.pathExtension
                let uniqueSuffix = UUID().uuidString.prefix(8)
                let newFileName = if ext.isEmpty {
                    "\(baseName)-\(uniqueSuffix)"
                } else {
                    "\(baseName)-\(uniqueSuffix).\(ext)"
                }
                destinationURL = baseDirectory.appendingPathComponent(newFileName)
            } catch {
                throw error
            }
        }
    }
}
