//
//  FileImportProcessor.swift
//  Fonic HiFi
//
//  Created by Claude on 2025-09-30.
//

import Foundation
import OSLog
import SwiftData

/// Actor responsible for file I/O operations during import
/// Runs off main thread to prevent UI blocking
actor FileImportProcessor {
    // MARK: - Properties

    private let logger = Logger(subsystem: "com.fonichifi.library", category: "FileImportProcessor")
    private let trackDataActor: TrackDataActor
    private let metadataExtractor: MetadataExtractionService

    private let supportedExtensions: Set<String> = [
        "mp3", "m4a", "aac", "flac", "alac", "wav", "aiff", "aif", "ape", "wv", "ogg", "opus",
    ]

    /// App container directory for storing copied music files
    private lazy var musicContainerURL: URL = {
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return documentsURL.appendingPathComponent("Music", isDirectory: true)
    }()

    // MARK: - Initialization

    init(
        trackDataActor: TrackDataActor,
        metadataExtractor: MetadataExtractionService
    ) {
        self.trackDataActor = trackDataActor
        self.metadataExtractor = metadataExtractor
    }

    // MARK: - Public Methods

    /// Discover all audio files from URLs (handles directories recursively)
    func discoverAudioFiles(from urls: [URL]) async -> [(URL, Bool)] {
        var audioFiles: [(URL, Bool)] = []

        for url in urls {
            var isDirectory: ObjCBool = false
            let accessed = url.startAccessingSecurityScopedResource()

            guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
                continue
            }

            if isDirectory.boolValue {
                // Recursively scan directory
                let discovered = await scanDirectory(url)
                audioFiles.append(contentsOf: discovered.map { ($0, accessed) })
            } else if supportedExtensions.contains(url.pathExtension.lowercased()) {
                audioFiles.append((url, accessed))
            } else {
                if accessed {
                    url.stopAccessingSecurityScopedResource()
                }
            }
        }

        return audioFiles
    }

    /// Process a single audio file (extract metadata, copy to container, create Track)
    func processAudioFile(_ url: URL, hasSecurityScope: Bool) async throws -> PersistentIdentifier {
        // Ensure music container exists
        try ensureMusicContainerExists()

        // Copy file to app container
        let copiedFileURL = try copyFileToContainer(url, hasSecurityScope: hasSecurityScope)

        // Extract metadata using MetadataExtractionService (use copied file)
        let trackMetadata = try await metadataExtractor.extractTrackMetadata(from: copiedFileURL)

        // Create track in database via TrackDataActor
        let trackId = try await trackDataActor.createTrack(from: trackMetadata)

        return trackId
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

    private func scanDirectory(_ directoryURL: URL) async -> [URL] {
        var audioFiles: [URL] = []
        let fileManager = FileManager.default

        guard let enumerator = fileManager.enumerator(
            at: directoryURL,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            return audioFiles
        }

        while let fileURL = enumerator.nextObject() as? URL {
            guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                  let isRegularFile = resourceValues.isRegularFile,
                  isRegularFile
            else {
                continue
            }

            if supportedExtensions.contains(fileURL.pathExtension.lowercased()) {
                audioFiles.append(fileURL)
            }
        }

        return audioFiles
    }

    private func ensureMusicContainerExists() throws {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: self.musicContainerURL.path) {
            try fileManager.createDirectory(
                at: self.musicContainerURL,
                withIntermediateDirectories: true,
                attributes: nil
            )
            logger.info("Created music container at: \(self.musicContainerURL.path)")
        }
    }

    private func copyFileToContainer(_ url: URL, hasSecurityScope: Bool) throws -> URL {
        let fileManager = FileManager.default
        let filename = url.lastPathComponent
        let destinationURL = musicContainerURL.appendingPathComponent(filename)

        // Handle duplicates
        var finalDestination = destinationURL
        var counter = 1
        while fileManager.fileExists(atPath: finalDestination.path) {
            let nameWithoutExtension = url.deletingPathExtension().lastPathComponent
            let ext = url.pathExtension
            let newFilename = "\(nameWithoutExtension) (\(counter)).\(ext)"
            finalDestination = musicContainerURL.appendingPathComponent(newFilename)
            counter += 1
        }

        // Copy file
        if hasSecurityScope {
            try fileManager.copyItem(at: url, to: finalDestination)
        } else {
            try fileManager.copyItem(at: url, to: finalDestination)
        }

        logger.debug("Copied file to: \(finalDestination.path)")
        return finalDestination
    }
}
