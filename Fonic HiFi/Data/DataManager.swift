//
//  DataManager.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import SwiftData
import OSLog

/// Centralized data management for the Fonic HiFi app
@MainActor
public final class DataManager: ObservableObject {
    
    // MARK: - Properties
    
    /// The SwiftData model container
    public let container: ModelContainer
    
    /// The main model context for UI operations
    public let mainContext: ModelContext
    
    /// Background context for import operations
    public let backgroundContext: ModelContext
    
    /// Track data actor for concurrency-safe operations
    public let trackDataActor: TrackDataActor
    
    /// Metadata extraction service
    public let metadataExtractor: MetadataExtractionService
    
    /// Library import service
    public let importService: LibraryImportService
    
    /// Logger for data operations
    private let logger = Logger(subsystem: "com.fonichifi.data", category: "DataManager")
    
    // MARK: - Initialization
    
    public init() throws {
        let schema = Schema([
            Track.self,
            Artist.self,
            Album.self,
            Playlist.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none // Disable CloudKit for now (privacy-first)
        )
        
        do {
            container = try ModelContainer(for: schema, configurations: [modelConfiguration])
            mainContext = container.mainContext
            backgroundContext = ModelContext(container)
            
            // Configure contexts
            mainContext.autosaveEnabled = true
            backgroundContext.autosaveEnabled = false // Manual save control for imports
            
            // Initialize services
            let formatDetectionService = AudioFormatDetectionManager()
            metadataExtractor = MetadataExtractionService(formatDetectionService: formatDetectionService)
            trackDataActor = TrackDataActor(modelContainer: container)
            importService = LibraryImportService(
                trackDataActor: trackDataActor,
                metadataExtractor: metadataExtractor
            )
            
            logger.info("DataManager initialized successfully")
            
        } catch {
            logger.error("Failed to initialize DataManager: \(error.localizedDescription)")
            throw DataManagerError.initializationFailed(error)
        }
    }
    
    // MARK: - Library Statistics
    
    /// Get current library statistics
    public func getLibraryStatistics() async throws -> LibraryStatistics {
        let trackDescriptor = FetchDescriptor<Track>()
        let albumDescriptor = FetchDescriptor<Album>()
        let artistDescriptor = FetchDescriptor<Artist>()
        let playlistDescriptor = FetchDescriptor<Playlist>()
        
        do {
            let tracks = try mainContext.fetch(trackDescriptor)
            let albums = try mainContext.fetch(albumDescriptor)
            let artists = try mainContext.fetch(artistDescriptor)
            let playlists = try mainContext.fetch(playlistDescriptor)
            
            let totalDuration = tracks.reduce(0) { $0 + $1.duration }
            let totalFileSize = tracks.reduce(0) { $0 + $1.fileSize }
            let losslessCount = tracks.filter { $0.isLossless }.count
            let hiResCount = tracks.filter { $0.sampleRate > 48000 || $0.bitDepth > 16 }.count
            
            return LibraryStatistics(
                trackCount: tracks.count,
                albumCount: albums.count,
                artistCount: artists.count,
                playlistCount: playlists.count,
                totalDuration: totalDuration,
                totalFileSize: totalFileSize,
                losslessTrackCount: losslessCount,
                hiResTrackCount: hiResCount
            )
        } catch {
            logger.error("Failed to get library statistics: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }
    
    // MARK: - Search Operations
    
    /// Search tracks by query string
    public func searchTracks(_ query: String, limit: Int = 100) async throws -> [Track] {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }
        
        var descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.title.localizedStandardContains(searchQuery) ||
                track.artist.localizedStandardContains(searchQuery) ||
                track.album.localizedStandardContains(searchQuery) ||
                (track.albumArtist?.localizedStandardContains(searchQuery) ?? false) ||
                (track.genre?.localizedStandardContains(searchQuery) ?? false)
            },
            sortBy: [SortDescriptor(\.title)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to search tracks: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }
    
    /// Search albums by query string
    public func searchAlbums(_ query: String, limit: Int = 50) async throws -> [Album] {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }
        
        var descriptor = FetchDescriptor<Album>(
            predicate: #Predicate<Album> { album in
                album.title.localizedStandardContains(searchQuery) ||
                album.albumArtist.localizedStandardContains(searchQuery)
            },
            sortBy: [SortDescriptor(\.title)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to search albums: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }
    
    /// Search artists by query string
    public func searchArtists(_ query: String, limit: Int = 50) async throws -> [Artist] {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }
        
        var descriptor = FetchDescriptor<Artist>(
            predicate: #Predicate<Artist> { artist in
                artist.name.localizedStandardContains(searchQuery) ||
                artist.sortName.localizedStandardContains(searchQuery)
            },
            sortBy: [SortDescriptor(\.sortName)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to search artists: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }
    
    // MARK: - Recent Items
    
    /// Get recently added tracks
    public func getRecentlyAddedTracks(limit: Int = 50) async throws -> [Track] {
        var descriptor = FetchDescriptor<Track>(
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to get recently added tracks: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }
    
    /// Get recently played tracks
    public func getRecentlyPlayedTracks(limit: Int = 50) async throws -> [Track] {
        var descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.lastPlayed != nil
            },
            sortBy: [SortDescriptor(\.lastPlayed, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        
        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to get recently played tracks: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }
    
    // MARK: - Cleanup Operations
    
    /// Remove tracks whose files no longer exist
    public func cleanupMissingFiles() async throws -> Int {
        do {
            let removedCount = try await trackDataActor.cleanupMissingFiles()
            logger.info("Cleanup completed: removed \(removedCount) missing files")
            return removedCount
        } catch {
            logger.error("Failed to cleanup missing files: \(error.localizedDescription)")
            throw DataManagerError.cleanupFailed(error)
        }
    }
    
    // MARK: - Data Export
    
    /// Export library data to JSON for backup
    public func exportLibraryData() async throws -> Data {
        let tracks = try await getRecentlyAddedTracks(limit: Int.max)
        let exportData = LibraryExportData(
            tracks: tracks.map { track in
                TrackExportData(
                    id: track.id,
                    title: track.title,
                    artist: track.artist,
                    album: track.album,
                    url: track.url,
                    duration: track.duration,
                    audioFormat: track.audioFormat,
                    dateAdded: track.dateAdded,
                    playCount: track.playCount,
                    isFavorite: track.isFavorite
                )
            },
            exportDate: Date(),
            version: "1.0"
        )
        
        do {
            return try JSONEncoder().encode(exportData)
        } catch {
            logger.error("Failed to export library data: \(error.localizedDescription)")
            throw DataManagerError.exportFailed(error)
        }
    }
}

// MARK: - Supporting Types

/// Library statistics summary
public struct LibraryStatistics {
    public let trackCount: Int
    public let albumCount: Int
    public let artistCount: Int
    public let playlistCount: Int
    public let totalDuration: TimeInterval
    public let totalFileSize: Int64
    public let losslessTrackCount: Int
    public let hiResTrackCount: Int
    
    public var formattedTotalDuration: String {
        let hours = Int(totalDuration) / 3600
        let minutes = (Int(totalDuration) % 3600) / 60
        
        if hours > 0 {
            return String(format: "%dh %dm", hours, minutes)
        } else {
            return String(format: "%dm", minutes)
        }
    }
    
    public var formattedTotalFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useGB, .useTB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalFileSize)
    }
    
    public var losslessPercentage: Double {
        guard trackCount > 0 else { return 0 }
        return Double(losslessTrackCount) / Double(trackCount) * 100
    }
    
    public var hiResPercentage: Double {
        guard trackCount > 0 else { return 0 }
        return Double(hiResTrackCount) / Double(trackCount) * 100
    }
}

/// Data export structures
private struct LibraryExportData: Codable {
    let tracks: [TrackExportData]
    let exportDate: Date
    let version: String
}

private struct TrackExportData: Codable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let url: URL
    let duration: TimeInterval
    let audioFormat: String
    let dateAdded: Date
    let playCount: Int
    let isFavorite: Bool
}

/// Data manager errors
public enum DataManagerError: LocalizedError {
    case initializationFailed(Error)
    case fetchFailed(Error)
    case searchFailed(Error)
    case cleanupFailed(Error)
    case exportFailed(Error)
    
    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let error):
            return "Failed to initialize data manager: \(error.localizedDescription)"
        case .fetchFailed(let error):
            return "Failed to fetch data: \(error.localizedDescription)"
        case .searchFailed(let error):
            return "Search operation failed: \(error.localizedDescription)"
        case .cleanupFailed(let error):
            return "Cleanup operation failed: \(error.localizedDescription)"
        case .exportFailed(let error):
            return "Export operation failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview Support

extension DataManager {
    /// Create a preview container for SwiftUI previews
    static var previewContainer: ModelContainer {
        let schema = Schema([
            Track.self,
            Artist.self,
            Album.self,
            Playlist.self
        ])
        
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )
        
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    /// Create a preview import service for SwiftUI previews
    @MainActor
    static func makePreviewImportService() -> LibraryImportService {
        let container = previewContainer
        let trackDataActor = TrackDataActor(modelContainer: container)
        let metadataExtractor = MetadataExtractionService(formatDetectionService: AudioFormatDetectionManager())
        return LibraryImportService(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor
        )
    }
}