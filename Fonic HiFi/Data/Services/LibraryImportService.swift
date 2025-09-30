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
@MainActor
public final class LibraryImportService: ObservableObject {
    // MARK: - Published Properties

    /// Current import progress (0.0 to 1.0)
    @MainActor @Published public private(set) var importProgress: Double = 0.0

    /// Whether an import is currently in progress
    @MainActor @Published public private(set) var isImporting: Bool = false

    /// Current status message
    @MainActor @Published public private(set) var statusMessage: String = ""

    /// Number of files processed
    @MainActor @Published public private(set) var filesProcessed: Int = 0

    /// Total number of files to process
    @MainActor @Published public private(set) var totalFiles: Int = 0

    /// Import errors encountered
    @MainActor @Published public private(set) var importErrors: [ImportError] = []

    /// Recently imported track identifiers
    @MainActor @Published public private(set) var recentlyImported: [PersistentIdentifier] = []

    // MARK: - Dependencies

    private let trackDataActor: TrackDataActor
    private let metadataExtractor: MetadataExtractionService
    private let logger = Logger(subsystem: "com.fonichifi.library", category: "LibraryImportService")

    // MARK: - Private Properties

    private var importTask: Task<Void, Never>?
    private let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "alac", "wav", "aiff", "aif", "ape", "wv", "ogg", "opus",
    ]

    // Transaction tracking
    private var currentTransaction: ImportTransaction?

    /// App container directory for storing copied music files
    private lazy var musicContainerURL: URL = {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("Music", isDirectory: true)
    }()

    // MARK: - Initialization

    public init(
        trackDataActor: TrackDataActor,
        metadataExtractor: MetadataExtractionService,
    ) {
        self.trackDataActor = trackDataActor
        self.metadataExtractor = metadataExtractor
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
        do {
            let existingTrackId = try await trackDataActor.trackExists(for: url)
            return existingTrackId != nil
        } catch {
            logger.error("Error checking if file exists: \(error.localizedDescription)")
            return false
        }
    }

    /// Import a single file (for testing or manual import)
    public func importSingleFile(_ url: URL) async -> PersistentIdentifier? {
        do {
            return try await processAudioFile(url)
        } catch {
            logger.error("Failed to import single file: \(error.localizedDescription)")
            await MainActor.run {
                importErrors.append(ImportError(
                    url: url,
                    error: error,
                    message: "Failed to import file",
                ))
            }
            return nil
        }
    }

    // MARK: - Private Methods

    private func executeImportPipeline(urls: [URL]) async {
        let audioFiles = await discoverAudioFilesWithSecurityScope(from: urls)

        await MainActor.run {
            totalFiles = audioFiles.count
        }

        logger.info("Found \(audioFiles.count) audio files to import")

        guard !audioFiles.isEmpty else {
            await MainActor.run {
                statusMessage = "No audio files found"
                isImporting = false
            }
            return
        }

        let batchSize = 10
        let batches = audioFiles.chunked(into: batchSize)

        for batch in batches {
            await processBatch(batch)

            if Task.isCancelled {
                await MainActor.run {
                    statusMessage = "Import cancelled"
                    isImporting = false
                }
                logger.info("Import task cancelled")
                return
            }
        }

        await MainActor.run {
            statusMessage = "Import completed: \(filesProcessed) files imported"
            isImporting = false
        }
        logger.info("Import completed successfully")
    }

    /// Discover all audio files from the provided URLs (including subdirectories)
    private func discoverAudioFiles(from urls: [URL]) async -> [URL] {
        var audioFiles: [URL] = []

        for url in urls {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                continue
            }

            if isDirectory.boolValue {
                // Recursively scan directory
                await audioFiles.append(contentsOf: scanDirectory(url))
            } else if isSupportedAudioFile(url) {
                audioFiles.append(url)
            }
        }

        return audioFiles
    }

    /// Discover audio files with proper security-scoped resource handling
    private func discoverAudioFilesWithSecurityScope(from urls: [URL]) async -> [URL] {
        var audioFiles: [URL] = []

        for url in urls {
            // Start accessing security-scoped resource
            let startedAccessing = url.startAccessingSecurityScopedResource()
            defer {
                if startedAccessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                logger.warning("File does not exist: \(url.path)")
                continue
            }

            if isDirectory.boolValue {
                // Recursively scan directory with security scope
                await audioFiles.append(contentsOf: scanDirectoryWithSecurityScope(url))
            } else if isSupportedAudioFile(url) {
                audioFiles.append(url)
            }
        }

        return audioFiles
    }

    /// Scan a directory for audio files
    private func scanDirectory(_ directoryURL: URL) async -> [URL] {
        var audioFiles: [URL] = []

        do {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
            let contents = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles],
            )

            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))

                if resourceValues.isDirectory == true {
                    // Recursively scan subdirectory
                    let nested = await scanDirectory(url)
                    audioFiles.append(contentsOf: nested)
                } else if resourceValues.isRegularFile == true, isSupportedAudioFile(url) {
                    audioFiles.append(url)
                }
            }
        } catch {
            logger.error("Error scanning directory \(directoryURL.path): \(error.localizedDescription)")
        }

        return audioFiles
    }

    /// Scan a directory with security-scoped resource handling
    private func scanDirectoryWithSecurityScope(_ directoryURL: URL) async -> [URL] {
        var audioFiles: [URL] = []

        let startedAccessing = directoryURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccessing {
                directoryURL.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
            let contents = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles],
            )

            for url in contents {
                // Each subdirectory/file needs its own security scope
                let childStartedAccessing = url.startAccessingSecurityScopedResource()
                defer {
                    if childStartedAccessing {
                        url.stopAccessingSecurityScopedResource()
                    }
                }

                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))

                if resourceValues.isDirectory == true {
                    // Recursively scan subdirectory
                    let nested = await scanDirectoryWithSecurityScope(url)
                    audioFiles.append(contentsOf: nested)
                } else if resourceValues.isRegularFile == true, isSupportedAudioFile(url) {
                    audioFiles.append(url)
                }
            }
        } catch {
            logger.error("Error scanning directory \(directoryURL.path): \(error.localizedDescription)")
        }

        return audioFiles
    }

    /// Check if a file is a supported audio format
    private func isSupportedAudioFile(_ url: URL) -> Bool {
        let pathExtension = url.pathExtension.lowercased()
        return supportedExtensions.contains(pathExtension)
    }

    // MARK: - File Management

    /// Ensure the music container directory exists
    private func setupMusicContainer() throws {
        guard !FileManager.default.fileExists(atPath: musicContainerURL.path) else {
            return
        }

        try FileManager.default.createDirectory(
            at: musicContainerURL,
            withIntermediateDirectories: true,
            attributes: nil,
        )
        logger.info("Created music container directory at: \(self.musicContainerURL.path)")
    }

    /// Copy an imported file to the app container
    private func copyImportedFile(_ sourceURL: URL) throws -> URL {
        // Start accessing security-scoped resource before copying
        let startedAccessing = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccessing {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        // Ensure music container exists
        try setupMusicContainer()

        // Generate destination URL with unique name if needed
        let destinationURL = generateUniqueDestinationURL(for: sourceURL)

        // Copy file to app container
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        logger.debug("✅ Copied file: \(sourceURL.lastPathComponent) -> \(destinationURL.lastPathComponent)")

        return destinationURL
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

    /// Verify that a track file is accessible for playback
    public func verifyTrackAccess(_ track: Track) -> Bool {
        let fileExists = FileManager.default.fileExists(atPath: track.url.path)

        if !fileExists {
            logger.warning("Track file not found: \(track.url.lastPathComponent)")
        }

        return fileExists
    }

    /// Get the total size of the music container directory
    public func getMusicContainerSize() -> Int64 {
        do {
            try setupMusicContainer()
            let resourceKeys: [URLResourceKey] = [.fileSizeKey]
            let enumerator = FileManager.default.enumerator(
                at: musicContainerURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles],
                errorHandler: nil,
            )

            var totalSize: Int64 = 0
            while let url = enumerator?.nextObject() as? URL {
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                totalSize += Int64(resourceValues.fileSize ?? 0)
            }

            return totalSize
        } catch {
            logger.error("Failed to calculate music container size: \(error.localizedDescription)")
            return 0
        }
    }

    /// Process a batch of audio files
    private func processBatch(_ urls: [URL]) async {
        // Process files sequentially to avoid concurrency issues with @MainActor properties
        for url in urls {
            await processSingleFile(url)
        }
    }

    /// Process a single audio file
    private func processSingleFile(_ url: URL) async {
        do {
            // Check if file already exists
            if await isFileInLibrary(url) {
                logger.debug("File already in library: \(url.lastPathComponent)")
                await updateProgress()
                return
            }

            // Import the file
            if let trackId = try await processAudioFile(url) {
                await MainActor.run {
                    recentlyImported.append(trackId)
                }
                logger.debug("Successfully imported track with ID: \(String(describing: trackId))")
            }

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

    /// Process an audio file and create a Track via TrackDataActor
    private func processAudioFile(_ url: URL) async throws -> PersistentIdentifier? {
        await MainActor.run {
            statusMessage = "Processing \(url.lastPathComponent)..."
        }

        // Start accessing security-scoped resource
        let startedAccessing = url.startAccessingSecurityScopedResource()
        defer {
            if startedAccessing {
                url.stopAccessingSecurityScopedResource()
            }
        }

        // Copy file to app container for persistent access
        let copiedFileURL: URL
        do {
            copiedFileURL = try copyImportedFile(url)
            logger.debug("File copied to app container: \(copiedFileURL.lastPathComponent)")
        } catch {
            logger.error("Failed to copy file \(url.lastPathComponent): \(error.localizedDescription)")
            throw error
        }

        // Extract metadata using MetadataExtractionService (use copied file)
        let trackMetadata = try await metadataExtractor.extractTrackMetadata(from: copiedFileURL)

        // Create Track via TrackDataActor (handles persistence)
        let trackId = try await trackDataActor.createTrack(from: trackMetadata)

        return trackId
    }

    /// Update import progress
    private func updateProgress() async {
        await MainActor.run {
            filesProcessed += 1
            importProgress = totalFiles > 0 ? Double(filesProcessed) / Double(totalFiles) : 0.0
            statusMessage = "Processed \(filesProcessed) of \(totalFiles) files"
        }
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
