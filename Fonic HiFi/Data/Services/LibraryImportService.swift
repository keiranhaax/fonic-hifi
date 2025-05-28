//
//  LibraryImportService.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData
import Combine
import OSLog

/// Service responsible for importing audio files into the library
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
    
    private let trackDataActor: TrackDataActor
    private let metadataExtractor: MetadataExtractionService
    private let logger = Logger(subsystem: "com.fonichifi.library", category: "LibraryImportService")
    
    // MARK: - Private Properties
    
    private var importTask: Task<Void, Never>?
    private let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "alac", "wav", "aiff", "aif", "ape", "wv", "ogg", "opus"
    ]
    
    // MARK: - Initialization
    
    public init(
        trackDataActor: TrackDataActor,
        metadataExtractor: MetadataExtractionService
    ) {
        self.trackDataActor = trackDataActor
        self.metadataExtractor = metadataExtractor
    }
    
    // MARK: - Public Methods
    
    /// Import files from selected URLs
    public func importFiles(from urls: [URL]) async {
        guard !isImporting else {
            logger.warning("Import already in progress")
            return
        }
        
        logger.info("Starting import of \(urls.count) URLs")
        
        // Reset state
        importProgress = 0.0
        filesProcessed = 0
        importErrors.removeAll()
        recentlyImported.removeAll()
        isImporting = true
        
        importTask = Task { @MainActor in
            // First, discover all audio files
            self.statusMessage = "Scanning for audio files..."
            let audioFiles = await self.discoverAudioFiles(from: urls)
            
            self.totalFiles = audioFiles.count
            logger.info("Found \(self.totalFiles) audio files to import")
            
            guard self.totalFiles > 0 else {
                self.statusMessage = "No audio files found"
                self.isImporting = false
                return
            }
            
            // Process files in batches for better performance
            let batchSize = 10
            let batches = audioFiles.chunked(into: batchSize)
            
            for batch in batches {
                await self.processBatch(batch)
                
                // Check for cancellation
                if Task.isCancelled {
                    break
                }
            }
            
            // Import completed
            self.statusMessage = "Import completed: \(self.filesProcessed) files imported"
            logger.info("Import completed successfully")
            self.isImporting = false
        }
    }
    
    /// Cancel the current import operation
    public func cancelImport() {
        importTask?.cancel()
        importTask = nil
        isImporting = false
        statusMessage = "Import cancelled"
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
            importErrors.append(ImportError(
                url: url,
                error: error,
                message: "Failed to import file"
            ))
            return nil
        }
    }
    
    // MARK: - Private Methods
    
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
                audioFiles.append(contentsOf: await scanDirectory(url))
            } else if isSupportedAudioFile(url) {
                audioFiles.append(url)
            }
        }
        
        return audioFiles
    }
    
    /// Recursively scan a directory for audio files
    private func scanDirectory(_ directoryURL: URL) async -> [URL] {
        var audioFiles: [URL] = []
        
        do {
            let resourceKeys: [URLResourceKey] = [.isDirectoryKey, .isRegularFileKey]
            let contents = try FileManager.default.contentsOfDirectory(
                at: directoryURL,
                includingPropertiesForKeys: resourceKeys,
                options: [.skipsHiddenFiles]
            )
            
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: Set(resourceKeys))
                
                if resourceValues.isDirectory == true {
                    // Recursively scan subdirectory
                    audioFiles.append(contentsOf: await scanDirectory(url))
                } else if resourceValues.isRegularFile == true && isSupportedAudioFile(url) {
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
    
    /// Process a batch of audio files
    private func processBatch(_ urls: [URL]) async {
        await withTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask { [weak self] in
                    await self?.processSingleFile(url)
                }
            }
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
                self.recentlyImported.append(trackId)
                logger.debug("Successfully imported track with ID: \(String(describing: trackId))")
            }
            
        } catch {
            logger.error("Error processing file \(url.lastPathComponent): \(error.localizedDescription)")
            importErrors.append(ImportError(
                url: url,
                error: error,
                message: "Failed to process audio file"
            ))
        }
        
        await updateProgress()
    }
    
    /// Process an audio file and create a Track via TrackDataActor
    private func processAudioFile(_ url: URL) async throws -> PersistentIdentifier? {
        statusMessage = "Processing \(url.lastPathComponent)..."
        
        // Extract metadata using MetadataExtractionService (returns Sendable data)
        let trackMetadata = try await metadataExtractor.extractTrackMetadata(from: url)
        
        // Create Track via TrackDataActor (handles persistence)
        let trackId = try await trackDataActor.createTrack(from: trackMetadata)
        
        return trackId
    }
    
    /// Update import progress
    private func updateProgress() async {
        filesProcessed += 1
        importProgress = totalFiles > 0 ? Double(filesProcessed) / Double(totalFiles) : 0.0
        statusMessage = "Processed \(filesProcessed) of \(totalFiles) files"
    }
}

// MARK: - Supporting Types

/// Error information for import failures
public struct ImportError: Identifiable, Equatable {
    public let id = UUID()
    public let url: URL?
    public let error: Error
    public let message: String
    public let timestamp: Date = Date()
    
    public static func == (lhs: ImportError, rhs: ImportError) -> Bool {
        lhs.id == rhs.id
    }
}


// MARK: - Extensions

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

