//
//  FileImportProcessor.swift
//  Fonic HiFi
//
//  Created by Claude on 2025-09-30.
//

@preconcurrency import Foundation
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
    typealias FormatValidator = @Sendable (URL) async throws -> AudioFileInfo
    typealias Materializer = @Sendable (URL) async throws -> Void
    typealias CoordinatedCopy = @Sendable (URL, URL) throws -> Void
    typealias FileMover = @Sendable (URL, URL) throws -> Void
    typealias FileRemover = @Sendable (URL) throws -> Void

    private static let stagingPrefix = ".staging-"
    private static let maxCollisionRetries = 8

    struct DiscoveredAudioFile: Sendable {
        let originalURL: URL
        let securityScopedBookmark: Data?
    }

    struct ProcessedFileError: Error, Sendable, LocalizedError {
        let message: String

        var errorDescription: String? { message }
    }

    enum ProcessedFileOutcome: Sendable {
        case imported(PersistentIdentifier)
        case duplicate
        case failed(ProcessedFileError)
    }

    struct ProcessedFileResult: Sendable {
        let file: DiscoveredAudioFile
        let outcome: ProcessedFileOutcome
        let duration: TimeInterval

        var identifier: PersistentIdentifier? {
            guard case let .imported(identifier) = outcome else { return nil }
            return identifier
        }

        var error: ProcessedFileError? {
            guard case let .failed(error) = outcome else { return nil }
            return error
        }

        var succeeded: Bool {
            if case .imported = outcome { return true }
            return false
        }

        var isDuplicate: Bool {
            if case .duplicate = outcome { return true }
            return false
        }

        var errorDescription: String? { error?.message }
    }

    // MARK: - Properties

    private let logger = Log.logger(.dataFileImportProcessor)
    private let trackDataActor: TrackDataActor
    private let metadataExtractor: MetadataExtracting
    private let securityAccessor: SecurityScopedAccessing
    private let musicContainerOverride: URL?
    private let discoveryCheckpoint: (@Sendable () async -> Void)?
    private let formatValidator: FormatValidator
    private let materializer: Materializer
    private let coordinatedCopy: CoordinatedCopy
    private let fileMover: FileMover
    private let fileRemover: FileRemover

    private let supportedExtensions = Set(AudioFormat.supportedExtensions)

    /// App container directory for storing copied music files
    private lazy var musicContainerURL: URL = {
        if let musicContainerOverride {
            return musicContainerOverride
        }

        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsURL.appendingPathComponent("Music", isDirectory: true)
        }

        return FileManager.default.temporaryDirectory.appendingPathComponent("Music", isDirectory: true)
    }()

    // MARK: - Initialization

    init(
        trackDataActor: TrackDataActor,
        metadataExtractor: MetadataExtracting,
        securityAccessor: SecurityScopedAccessing = DefaultSecurityScopedAccessor(),
        musicContainerURL: URL? = nil,
        discoveryCheckpoint: (@Sendable () async -> Void)? = nil,
        formatValidator: @escaping FormatValidator = FileImportProcessor.defaultFormatValidator,
        materializer: @escaping Materializer = FileImportProcessor.materializeUbiquitousItem,
        coordinatedCopy: @escaping CoordinatedCopy = FileImportProcessor.coordinateCopy,
        fileMover: @escaping FileMover = FileImportProcessor.moveItem,
        fileRemover: @escaping FileRemover = FileImportProcessor.removeItem,
    ) {
        self.trackDataActor = trackDataActor
        self.metadataExtractor = metadataExtractor
        self.securityAccessor = securityAccessor
        musicContainerOverride = musicContainerURL
        self.discoveryCheckpoint = discoveryCheckpoint
        self.formatValidator = formatValidator
        self.materializer = materializer
        self.coordinatedCopy = coordinatedCopy
        self.fileMover = fileMover
        self.fileRemover = fileRemover
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
            let producer = Task { await self.emitDiscoveredFiles(from: urls, to: continuation) }
            continuation.onTermination = { @Sendable _ in
                producer.cancel()
            }
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

    func processFilesStream(
        _ files: AsyncStream<DiscoveredAudioFile>,
        maxConcurrentTasks: Int = 3
    ) -> AsyncStream<ProcessedFileResult> {
        do {
            try ensureMusicContainerExists()
        } catch {
            logger.error("Failed to prepare music container: \(error.localizedDescription, privacy: .private)")
            return Self.makeContainerPreparationFailureStream(from: files, error: error)
        }

        let baseDirectory = musicContainerURL
        let extractor = metadataExtractor
        let trackActor = trackDataActor
        let accessor = securityAccessor
        let log = logger
        let validate = formatValidator
        let materialize = materializer
        let copy = coordinatedCopy
        let move = fileMover
        let remove = fileRemover

        return AsyncStream<ProcessedFileResult> { continuation in
            let producer = Task {
                await Self.emitProcessedFiles(
                    from: files,
                    maxConcurrentTasks: maxConcurrentTasks,
                    baseDirectory: baseDirectory,
                    metadataExtractor: extractor,
                    trackDataActor: trackActor,
                    securityAccessor: accessor,
                    logger: log,
                    formatValidator: validate,
                    materializer: materialize,
                    coordinatedCopy: copy,
                    fileMover: move,
                    fileRemover: remove,
                    to: continuation,
                )
            }
            continuation.onTermination = { @Sendable _ in
                producer.cancel()
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

        let result = try await Self.importFile(
            file,
            baseDirectory: musicContainerURL,
            metadataExtractor: metadataExtractor,
            trackDataActor: trackDataActor,
            securityAccessor: securityAccessor,
            logger: logger,
            formatValidator: formatValidator,
            materializer: materializer,
            coordinatedCopy: coordinatedCopy,
            fileMover: fileMover,
            fileRemover: fileRemover,
        )

        switch result {
        case let .created(identifier):
            return identifier
        case .duplicate:
            throw ProcessedFileError(message: "Duplicate file already exists")
        }
    }

    /// Check if a file already exists in the library
    func fileExists(_ url: URL) async -> Bool {
        do {
            let existingTrackId = try await trackDataActor.trackExists(for: url)
            return existingTrackId != nil
        } catch {
            logger.error("Error checking if file exists: \(error.localizedDescription, privacy: .private)")
            return false
        }
    }

    // MARK: - Private Methods

    private struct ImportQueueStats {
        let startedAt: Date
        var nextProgressLog: Date
        var completed = 0
        var successes = 0
        var duplicates = 0
        var failures = 0
        var totalDuration: TimeInterval = 0
        var inFlight = 0
        var maxInFlight = 0

        init(startedAt: Date = Date()) {
            self.startedAt = startedAt
            nextProgressLog = startedAt
        }

        mutating func recordLaunch() {
            inFlight += 1
            if inFlight > maxInFlight {
                maxInFlight = inFlight
            }
        }

        mutating func recordCompletion(for result: ProcessedFileResult) {
            inFlight = max(inFlight - 1, 0)
            completed += 1
            totalDuration += result.duration
            if result.succeeded {
                successes += 1
            } else if result.isDuplicate {
                duplicates += 1
            } else {
                failures += 1
            }
        }
    }

    private static func makeContainerPreparationFailureStream(
        from files: AsyncStream<DiscoveredAudioFile>,
        error: Error,
    ) -> AsyncStream<ProcessedFileResult> {
        let message = error.localizedDescription
        return AsyncStream<ProcessedFileResult> { continuation in
            let producer = Task {
                var iterator = files.makeAsyncIterator()
                while !Task.isCancelled, let file = await iterator.next() {
                    let yieldResult = continuation.yield(
                        ProcessedFileResult(
                            file: file,
                            outcome: .failed(ProcessedFileError(message: message)),
                            duration: 0,
                        ),
                    )
                    guard Self.consumerIsActive(after: yieldResult) else { break }
                }
                continuation.finish()
            }
            continuation.onTermination = { @Sendable _ in
                producer.cancel()
            }
        }
    }

    private static func emitProcessedFiles(
        from files: AsyncStream<DiscoveredAudioFile>,
        maxConcurrentTasks: Int,
        baseDirectory: URL,
        metadataExtractor: MetadataExtracting,
        trackDataActor: TrackDataActor,
        securityAccessor: SecurityScopedAccessing,
        logger: Logger,
        formatValidator: @escaping FormatValidator,
        materializer: @escaping Materializer,
        coordinatedCopy: @escaping CoordinatedCopy,
        fileMover: @escaping FileMover,
        fileRemover: @escaping FileRemover,
        to continuation: AsyncStream<ProcessedFileResult>.Continuation
    ) async {
        defer { continuation.finish() }

        var iterator = files.makeAsyncIterator()
        let concurrency = max(1, maxConcurrentTasks)

        var hashCache = await loadSourceHashCache(from: trackDataActor, logger: logger)
        guard !Task.isCancelled else { return }
        var stats = ImportQueueStats()

        await withTaskGroup(of: ProcessedFileResult?.self) { group in
            for _ in 0 ..< concurrency {
                guard !Task.isCancelled else { break }
                guard let discoveredFile = await iterator.next() else { break }

                let currentCache = hashCache
                group.addTask {
                    await Self.processDiscoveredFile(
                        discoveredFile,
                        hashCache: currentCache,
                        baseDirectory: baseDirectory,
                        metadataExtractor: metadataExtractor,
                        trackDataActor: trackDataActor,
                        securityAccessor: securityAccessor,
                        logger: logger,
                        formatValidator: formatValidator,
                        materializer: materializer,
                        coordinatedCopy: coordinatedCopy,
                        fileMover: fileMover,
                        fileRemover: fileRemover,
                    )
                }
                stats.recordLaunch()
            }

            while let next = await group.next() {
                guard let result = next else {
                    group.cancelAll()
                    break
                }

                stats.recordCompletion(for: result)

                if result.succeeded {
                    let urlHash = result.file.originalURL.librarySourceHash()
                    let bookmarkHash = result.file.securityScopedBookmark?.sha256Hex()
                    let urlString = result.file.originalURL.absoluteString
                    hashCache.addEntry(urlHash: urlHash, bookmarkHash: bookmarkHash, urlString: urlString)
                }

                let yieldResult = continuation.yield(result)
                guard Self.consumerIsActive(after: yieldResult) else {
                    group.cancelAll()
                    break
                }

                if Task.isCancelled {
                    group.cancelAll()
                    break
                }

                if let discoveredFile = await iterator.next() {
                    let currentCache = hashCache
                    group.addTask {
                        await Self.processDiscoveredFile(
                            discoveredFile,
                            hashCache: currentCache,
                            baseDirectory: baseDirectory,
                            metadataExtractor: metadataExtractor,
                            trackDataActor: trackDataActor,
                            securityAccessor: securityAccessor,
                            logger: logger,
                            formatValidator: formatValidator,
                            materializer: materializer,
                            coordinatedCopy: coordinatedCopy,
                            fileMover: fileMover,
                            fileRemover: fileRemover,
                        )
                    }
                    stats.recordLaunch()
                }

                logQueueProgressIfNeeded(stats: &stats, logger: logger)
            }

            group.cancelAll()
        }

        logQueueSummary(stats: stats, logger: logger)
    }

    private static func consumerIsActive(
        after result: AsyncStream<some Sendable>.Continuation.YieldResult,
    ) -> Bool {
        switch result {
        case .enqueued, .dropped:
            true
        case .terminated:
            false
        @unknown default:
            false
        }
    }

    private static func loadSourceHashCache(
        from trackDataActor: TrackDataActor,
        logger: Logger
    ) async -> SourceHashCache {
        do {
            return try await trackDataActor.loadSourceHashCache()
        } catch {
            logger.warning("Failed to load hash cache, falling back to per-file checks: \(error.localizedDescription, privacy: .private)")
            return SourceHashCache()
        }
    }

    private static func processDiscoveredFile(
        _ file: DiscoveredAudioFile,
        hashCache: SourceHashCache,
        baseDirectory: URL,
        metadataExtractor: MetadataExtracting,
        trackDataActor: TrackDataActor,
        securityAccessor: SecurityScopedAccessing,
        logger: Logger,
        formatValidator: FormatValidator,
        materializer: Materializer,
        coordinatedCopy: CoordinatedCopy,
        fileMover: FileMover,
        fileRemover: FileRemover,
    ) async -> ProcessedFileResult? {
        let taskStart = Date()

        let urlHash = file.originalURL.librarySourceHash()
        let bookmarkHash = file.securityScopedBookmark?.sha256Hex()
        let urlString = file.originalURL.absoluteString

        do {
            try Task.checkCancellation()

            if hashCache.contains(urlHash: urlHash, bookmarkHash: bookmarkHash, urlString: urlString) {
                logger.notice("Duplicate import skipped (cache hit): \(file.originalURL.lastPathComponent, privacy: .private(mask: .hash))")
                return ProcessedFileResult(
                    file: file,
                    outcome: .duplicate,
                    duration: Date().timeIntervalSince(taskStart),
                )
            }

            let importResult = try await Self.importFile(
                file,
                baseDirectory: baseDirectory,
                metadataExtractor: metadataExtractor,
                trackDataActor: trackDataActor,
                securityAccessor: securityAccessor,
                logger: logger,
                formatValidator: formatValidator,
                materializer: materializer,
                coordinatedCopy: coordinatedCopy,
                fileMover: fileMover,
                fileRemover: fileRemover,
            )
            let duration = Date().timeIntervalSince(taskStart)
            switch importResult {
            case let .created(identifier):
                return ProcessedFileResult(
                    file: file,
                    outcome: .imported(identifier),
                    duration: duration,
                )
            case .duplicate:
                return ProcessedFileResult(
                    file: file,
                    outcome: .duplicate,
                    duration: duration,
                )
            }
        } catch is CancellationError {
            return nil
        } catch {
            let duration = Date().timeIntervalSince(taskStart)
            let filename = file.originalURL.lastPathComponent
            let errorDescription = error.localizedDescription
            logger.error(
                """
                File import failed for \(filename, privacy: .private(mask: .hash)):
                \(errorDescription, privacy: .private)
                """
            )
            return ProcessedFileResult(
                file: file,
                outcome: .failed(ProcessedFileError(message: error.localizedDescription)),
                duration: duration,
            )
        }
    }

    private static func logQueueProgressIfNeeded(
        stats: inout ImportQueueStats,
        logger: Logger
    ) {
        let now = Date()
        guard stats.completed % 10 == 0 || now.timeIntervalSince(stats.nextProgressLog) >= 5 else {
            return
        }

        let completed = stats.completed
        let inFlight = stats.inFlight
        let maxInFlight = stats.maxInFlight
        let successes = stats.successes
        let duplicates = stats.duplicates
        let failures = stats.failures
        let elapsed = now.timeIntervalSince(stats.startedAt)
        let throughput = elapsed > 0 ? Double(completed) / elapsed : Double(completed)
        logger.info(
            """
            import.queue.metrics completed=\(completed, privacy: .public) \
            inFlight=\(inFlight, privacy: .public) \
            maxInFlight=\(maxInFlight, privacy: .public) \
            successes=\(successes, privacy: .public) \
            duplicates=\(duplicates, privacy: .public) \
            failures=\(failures, privacy: .public) \
            throughput=\(throughput, format: .fixed(precision: 2), privacy: .public)
            """
        )
        stats.nextProgressLog = now
    }

    private static func logQueueSummary(stats: ImportQueueStats, logger: Logger) {
        let totalElapsed = Date().timeIntervalSince(stats.startedAt)
        let averageDuration = stats.completed > 0 ? stats.totalDuration / Double(stats.completed) : 0
        logger.info(
            """
            import.queue.summary files=\(stats.completed, privacy: .public) \
            successes=\(stats.successes, privacy: .public) \
            duplicates=\(stats.duplicates, privacy: .public) \
            failures=\(stats.failures, privacy: .public) \
            maxInFlight=\(stats.maxInFlight, privacy: .public) \
            elapsed=\(totalElapsed, format: .fixed(precision: 2), privacy: .public) \
            avgDuration=\(averageDuration, format: .fixed(precision: 2), privacy: .public)
            """
        )
    }

    private func emitDiscoveredFiles(
        from urls: [URL],
        to continuation: AsyncStream<DiscoveredAudioFile>.Continuation,
    ) async {
        var totalYielded = 0

        for url in urls {
            if Task.isCancelled {
                break
            }

            if let discoveryCheckpoint {
                await discoveryCheckpoint()
                if Task.isCancelled {
                    break
                }
            }

            var isDirectory: ObjCBool = false
            let accessed = securityAccessor.startAccessing(url)

            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                if accessed {
                    securityAccessor.stopAccessing(url)
                }
                continue
            }

            if isDirectory.boolValue {
                let completed = await enumerateAudioFiles(in: url, requiresSecurityScope: accessed) { file in
                    let yieldResult = continuation.yield(file)
                    guard Self.consumerIsActive(after: yieldResult) else {
                        return false
                    }
                    totalYielded += 1
                    return true
                }
                if !completed {
                    break
                }
            } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
                let bookmark = bookmarkData(for: url, requiresSecurityScope: accessed, alreadyAccessing: accessed)
                if accessed {
                    securityAccessor.stopAccessing(url)
                }
                let yieldResult = continuation.yield(
                    DiscoveredAudioFile(originalURL: url, securityScopedBookmark: bookmark),
                )
                guard Self.consumerIsActive(after: yieldResult) else {
                    break
                }
                totalYielded += 1
                await Task.yield()
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
        yield: (DiscoveredAudioFile) -> Bool,
    ) async -> Bool {
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
            return true
        }

        while let fileURL = enumerator.nextObject() as? URL {
            if Task.isCancelled {
                return false
            }

            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile
            else {
                continue
            }

            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                let bookmark = bookmarkData(for: fileURL, requiresSecurityScope: requiresSecurityScope)
                guard yield(DiscoveredAudioFile(originalURL: fileURL, securityScopedBookmark: bookmark)) else {
                    return false
                }
                await Task.yield()
            }
        }

        return true
    }

    private func ensureMusicContainerExists() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: self.musicContainerURL.path) {
            try fileManager.createDirectory(
                at: self.musicContainerURL,
                withIntermediateDirectories: true,
                attributes: nil,
            )
        }

        // A cancelled or crashed copy can leave only our uniquely-prefixed
        // staging files behind. Remove those entries before the next import;
        // never touch user-created files in the Music directory.
        let entries = try fileManager.contentsOfDirectory(
            at: self.musicContainerURL,
            includingPropertiesForKeys: nil,
            options: [],
        )
        for entry in entries where entry.lastPathComponent.hasPrefix(Self.stagingPrefix) {
            do {
                try fileManager.removeItem(at: entry)
            } catch {
                logger.warning("Failed to sweep an import staging entry: \(error.localizedDescription, privacy: .private)")
            }
        }
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
            logger.error("Failed to create bookmark for \(url.lastPathComponent, privacy: .private(mask: .hash)): \(error.localizedDescription, privacy: .private)")
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
        formatValidator: FormatValidator,
        materializer: Materializer,
        coordinatedCopy: CoordinatedCopy,
        fileMover: FileMover,
        fileRemover: FileRemover,
    ) async throws -> TrackImportClaimResult {
        let (resolvedURL, stopAccess) = try resolveSecurityScopedURL(
            for: file,
            securityAccessor: securityAccessor,
        )
        defer { stopAccess() }

        if try await trackDataActor.trackExists(for: file.originalURL, bookmark: file.securityScopedBookmark) != nil {
            logger.notice("Duplicate import skipped for: \(file.originalURL.lastPathComponent, privacy: .private(mask: .hash))")
            return .duplicate
        }

        try Task.checkCancellation()

        try await materializer(resolvedURL)
        try Task.checkCancellation()

        guard let attributes = try? FileManager.default.attributesOfItem(atPath: resolvedURL.path),
              let fileSize = (attributes[.size] as? NSNumber)?.int64Value,
              fileSize > 0
        else {
            throw ImportValidationError.emptyFile
        }

        var stagingURL: URL?
        var managedFileURL: URL?
        defer {
            if let stagingURL {
                removeUnclaimedFile(stagingURL, remover: fileRemover, logger: logger)
            }
            if let managedFileURL {
                removeUnclaimedFile(managedFileURL, remover: fileRemover, logger: logger)
            }
        }

        do {
            stagingURL = baseDirectory.appendingPathComponent(
                "\(Self.stagingPrefix)\(UUID().uuidString)-\(resolvedURL.lastPathComponent)",
            )
            guard let currentStagingURL = stagingURL else { throw ImportValidationError.stagingFailed }
            try coordinatedCopy(resolvedURL, currentStagingURL)

            let formatInfo = try await formatValidator(currentStagingURL)
            guard formatInfo.isValid else {
                throw ImportValidationError.invalidFormat
            }

            try Task.checkCancellation()
            let trackMetadata = try await metadataExtractor.extractTrackMetadata(from: currentStagingURL)
            guard Self.isFinite(trackMetadata) else {
                throw ImportValidationError.invalidMetadata
            }
            try Task.checkCancellation()
            let destinationURL = try moveStagedFile(
                currentStagingURL,
                sourceURL: resolvedURL,
                baseDirectory: baseDirectory,
                mover: fileMover,
            )
            managedFileURL = destinationURL
            stagingURL = nil

            let enrichedMetadata = trackMetadata
                .withManagedURL(destinationURL)
                .withSourceInfo(
                sourceURL: file.originalURL,
                sourceBookmark: file.securityScopedBookmark,
            )

            try Task.checkCancellation()
            let claimResult = try await trackDataActor.claimImportedTrack(from: enrichedMetadata)
            if case .duplicate = claimResult {
                managedFileURL = nil
                removeUnclaimedFile(destinationURL, remover: fileRemover, logger: logger)
            }
            if case .created = claimResult {
                managedFileURL = nil
            }
            return claimResult
        } catch {
            throw error
        }
    }

    private static func removeUnclaimedFile(
        _ fileURL: URL,
        remover: FileRemover,
        logger: Logger,
    ) {
        do {
            try remover(fileURL)
        } catch {
            logger.error(
                "Failed to remove an unclaimed import file: \(error.localizedDescription, privacy: .private)",
            )
        }
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

    private static func moveStagedFile(
        _ stagingURL: URL,
        sourceURL: URL,
        baseDirectory: URL,
        mover: FileMover,
    ) throws -> URL {
        var destinationURL = baseDirectory.appendingPathComponent(sourceURL.lastPathComponent)

        for attempt in 0 ..< maxCollisionRetries {
            if FileManager.default.fileExists(atPath: destinationURL.path) {
                destinationURL = uniqueDestinationURL(for: sourceURL, in: baseDirectory, attempt: attempt)
                continue
            }

            do {
                try mover(stagingURL, destinationURL)
                return destinationURL
            } catch let error as NSError where Self.isFileExistsError(error) {
                destinationURL = uniqueDestinationURL(for: sourceURL, in: baseDirectory, attempt: attempt)
            }
        }

        throw ImportValidationError.destinationCollisionLimit
    }

    private static func uniqueDestinationURL(for sourceURL: URL, in baseDirectory: URL, attempt: Int) -> URL {
        let baseName = sourceURL.deletingPathExtension().lastPathComponent
        let ext = sourceURL.pathExtension
        let uniqueSuffix = "\(attempt + 1)-\(UUID().uuidString.prefix(8))"
        let newFileName = ext.isEmpty ? "\(baseName)-\(uniqueSuffix)" : "\(baseName)-\(uniqueSuffix).\(ext)"
        return baseDirectory.appendingPathComponent(newFileName)
    }

    private static func isFileExistsError(_ error: NSError) -> Bool {
        error.domain == NSCocoaErrorDomain && error.code == NSFileWriteFileExistsError
    }

    private static func isFinite(_ metadata: TrackMetadata) -> Bool {
        metadata.duration.isFinite && metadata.duration > 0 &&
            metadata.sampleRate.isFinite && metadata.sampleRate > 0 &&
            metadata.bitDepth > 0 && metadata.channels > 0 &&
            (metadata.bitrate ?? 0) >= 0 &&
            metadata.replayGainTrack.map { $0.isFinite } ?? true &&
            metadata.replayGainAlbum.map { $0.isFinite } ?? true
    }

    private nonisolated static func defaultFormatValidator(_ url: URL) async throws -> AudioFileInfo {
        try await AudioFormatDetectionManager.shared.detectFormat(at: url)
    }

    private nonisolated static func materializeUbiquitousItem(_ url: URL) async throws {
        let keys: Set<URLResourceKey> = [
            .isUbiquitousItemKey,
            .ubiquitousItemDownloadingStatusKey,
            .ubiquitousItemDownloadingErrorKey,
        ]
        let values = try url.resourceValues(forKeys: keys)
        guard values.isUbiquitousItem == true else { return }

        if let error = values.ubiquitousItemDownloadingError {
            throw error
        }
        if values.ubiquitousItemDownloadingStatus == .current ||
            values.ubiquitousItemDownloadingStatus == .downloaded {
            return
        }

        try FileManager.default.startDownloadingUbiquitousItem(at: url)
        for _ in 0 ..< 300 {
            try Task.checkCancellation()
            let currentValues = try url.resourceValues(forKeys: keys)
            if let error = currentValues.ubiquitousItemDownloadingError {
                throw error
            }
            if currentValues.ubiquitousItemDownloadingStatus == .current ||
                currentValues.ubiquitousItemDownloadingStatus == .downloaded {
                return
            }
            try await Task.sleep(for: .milliseconds(100))
        }

        throw ImportValidationError.materializationTimedOut
    }

    private nonisolated static func coordinateCopy(_ sourceURL: URL, _ destinationURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinationError: NSError?
        var copyError: Error?
        coordinator.coordinate(readingItemAt: sourceURL, options: [], error: &coordinationError) { coordinatedURL in
            do {
                try FileManager.default.copyItem(at: coordinatedURL, to: destinationURL)
            } catch {
                copyError = error
            }
        }
        if let coordinationError { throw coordinationError }
        if let copyError { throw copyError }
    }

    private nonisolated static func moveItem(_ sourceURL: URL, _ destinationURL: URL) throws {
        try FileManager.default.moveItem(at: sourceURL, to: destinationURL)
    }

    private nonisolated static func removeItem(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }
}

private enum ImportValidationError: Error, LocalizedError, Sendable {
    case emptyFile
    case invalidFormat
    case invalidMetadata
    case stagingFailed
    case destinationCollisionLimit
    case materializationTimedOut

    var errorDescription: String? {
        switch self {
        case .emptyFile:
            "The audio file is empty."
        case .invalidFormat:
            "The audio file could not be decoded."
        case .invalidMetadata:
            "The audio file contains invalid metadata."
        case .stagingFailed:
            "The audio file could not be staged."
        case .destinationCollisionLimit:
            "The managed file name could not be made unique."
        case .materializationTimedOut:
            "The audio file could not be downloaded in time."
        }
    }
}

private extension TrackMetadata {
    func withManagedURL(_ managedURL: URL) -> TrackMetadata {
        TrackMetadata(
            url: managedURL,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            totalTracks: totalTracks,
            discNumber: discNumber,
            totalDiscs: totalDiscs,
            composer: composer,
            conductor: conductor,
            audioFormat: audioFormat,
            duration: duration,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            bitrate: bitrate,
            channels: channels,
            isLossless: isLossless,
            artwork: artwork,
            lyrics: lyrics,
            comment: comment,
            sourceURL: sourceURL,
            sourceBookmark: sourceBookmark,
            sourceURLHash: sourceURLHash,
            sourceBookmarkHash: sourceBookmarkHash,
            replayGainTrack: replayGainTrack,
            replayGainAlbum: replayGainAlbum,
            isFavorite: isFavorite,
        )
    }
}
