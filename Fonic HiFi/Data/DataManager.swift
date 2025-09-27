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

    /// Recent searches actor for managing search history
    public let recentSearchesActor: RecentSearchesActor

    /// Metadata extraction service
    public let metadataExtractor: MetadataExtractionService

    /// Library import service
    public let importService: LibraryImportService

    /// Logger for data operations
    private let logger = Logger(subsystem: "com.fonichifi.data", category: "DataManager")
    
    // MARK: - Initialization
    
    public init() throws {
        let schema = Schema(SchemaV1.models)
        // Use versioned schema for consistency with migration plan
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none // Disable CloudKit for now (privacy-first)
        )

        do {
            // Supply an explicit migration plan with versioned schema
            container = try ModelContainer(
                for: schema,
                migrationPlan: RecentSearchMigrationPlan.self,
                configurations: [modelConfiguration]
            )
            mainContext = container.mainContext
            backgroundContext = ModelContext(container)
            
            // Configure contexts
            mainContext.autosaveEnabled = true
            backgroundContext.autosaveEnabled = false // Manual save control for imports
            
            // Initialize services
            let formatDetectionService = AudioFormatDetectionManager()
            metadataExtractor = MetadataExtractionService(formatDetectionService: formatDetectionService)
            trackDataActor = TrackDataActor(modelContainer: container)
            recentSearchesActor = RecentSearchesActor(modelContainer: container)
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
    
    // MARK: - Pagination Support

    /// Page size for paginated queries
    public static let defaultPageSize = 100

    /// Fetch tracks with pagination
    public func fetchTracks(
        predicate: Predicate<Track>? = nil,
        sortBy: [SortDescriptor<Track>] = [SortDescriptor(\.dateAdded, order: .reverse)],
        page: Int = 0,
        pageSize: Int = defaultPageSize
    ) async throws -> (tracks: [Track], hasMore: Bool) {
        var descriptor = FetchDescriptor<Track>(
            predicate: predicate,
            sortBy: sortBy
        )

        // Calculate offset and limit for pagination
        let offset = page * pageSize
        descriptor.fetchLimit = pageSize + 1 // Fetch one extra to check if more exist

        do {
            // SwiftData doesn't have direct offset support, so we'll simulate it
            let allTracks = try mainContext.fetch(descriptor)
            let startIndex = min(offset, allTracks.count)
            let endIndex = min(startIndex + pageSize, allTracks.count)

            let tracks = Array(allTracks[startIndex..<endIndex])
            let hasMore = allTracks.count > endIndex

            return (tracks, hasMore)
        } catch {
            logger.error("Failed to fetch tracks with pagination: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    /// Fetch albums with pagination
    public func fetchAlbums(
        predicate: Predicate<Album>? = nil,
        sortBy: [SortDescriptor<Album>] = [SortDescriptor(\.title)],
        page: Int = 0,
        pageSize: Int = defaultPageSize
    ) async throws -> (albums: [Album], hasMore: Bool) {
        var descriptor = FetchDescriptor<Album>(
            predicate: predicate,
            sortBy: sortBy
        )

        let offset = page * pageSize
        descriptor.fetchLimit = pageSize + 1

        do {
            let allAlbums = try mainContext.fetch(descriptor)
            let startIndex = min(offset, allAlbums.count)
            let endIndex = min(startIndex + pageSize, allAlbums.count)

            let albums = Array(allAlbums[startIndex..<endIndex])
            let hasMore = allAlbums.count > endIndex

            return (albums, hasMore)
        } catch {
            logger.error("Failed to fetch albums with pagination: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    /// Fetch all tracks in batches (for large operations like export)
    public func fetchAllTracksInBatches(
        batchSize: Int = defaultPageSize
    ) async throws -> [Track] {
        var allTracks: [Track] = []
        var page = 0
        var hasMore = true

        while hasMore {
            let result = try await fetchTracks(page: page, pageSize: batchSize)
            allTracks.append(contentsOf: result.tracks)
            hasMore = result.hasMore
            page += 1
        }

        return allTracks
    }

    // MARK: - Search Operations

    /// Search tracks by query string with pagination
    public func searchTracks(_ query: String, page: Int = 0, pageSize: Int = defaultPageSize) async throws -> (tracks: [Track], hasMore: Bool) {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return ([], false) }

        let predicate = #Predicate<Track> { track in
            track.title.localizedStandardContains(searchQuery) ||
            track.artist.localizedStandardContains(searchQuery) ||
            track.album.localizedStandardContains(searchQuery) ||
            (track.albumArtist?.localizedStandardContains(searchQuery) ?? false) ||
            (track.genre?.localizedStandardContains(searchQuery) ?? false)
        }

        return try await fetchTracks(
            predicate: predicate,
            sortBy: [SortDescriptor(\.title)],
            page: page,
            pageSize: pageSize
        )
    }

    /// Legacy search method (for backward compatibility)
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
    
    /// Search albums by query string with pagination
    public func searchAlbums(_ query: String, page: Int = 0, pageSize: Int = defaultPageSize) async throws -> (albums: [Album], hasMore: Bool) {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return ([], false) }

        let predicate = #Predicate<Album> { album in
            album.title.localizedStandardContains(searchQuery) ||
            album.albumArtist.localizedStandardContains(searchQuery)
        }

        return try await fetchAlbums(
            predicate: predicate,
            sortBy: [SortDescriptor(\.title)],
            page: page,
            pageSize: pageSize
        )
    }

    /// Legacy search method for albums (for backward compatibility)
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
    
    /// Search artists by query string with pagination
    public func searchArtists(_ query: String, page: Int = 0, pageSize: Int = defaultPageSize) async throws -> (artists: [Artist], hasMore: Bool) {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return ([], false) }

        var descriptor = FetchDescriptor<Artist>(
            predicate: #Predicate<Artist> { artist in
                artist.name.localizedStandardContains(searchQuery) ||
                artist.sortName.localizedStandardContains(searchQuery)
            },
            sortBy: [SortDescriptor(\.sortName)]
        )

        // Calculate offset and limit for pagination
        let offset = page * pageSize
        descriptor.fetchLimit = pageSize + 1 // Fetch one extra to check if more exist

        do {
            let allArtists = try mainContext.fetch(descriptor)
            let startIndex = min(offset, allArtists.count)
            let endIndex = min(startIndex + pageSize, allArtists.count)

            let artists = Array(allArtists[startIndex..<endIndex])
            let hasMore = allArtists.count > endIndex

            return (artists, hasMore)
        } catch {
            logger.error("Failed to search artists with pagination: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }

    /// Legacy search method for artists (for backward compatibility)
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

    /// Search playlists by query string with pagination
    public func searchPlaylists(_ query: String, page: Int = 0, pageSize: Int = defaultPageSize) async throws -> (playlists: [Playlist], hasMore: Bool) {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return ([], false) }

        var descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate<Playlist> { playlist in
                playlist.name.localizedStandardContains(searchQuery) ||
                playlist.playlistDescription?.localizedStandardContains(searchQuery) ?? false
            },
            sortBy: [SortDescriptor(\.name)]
        )

        let offset = page * pageSize
        descriptor.fetchLimit = pageSize + 1

        do {
            let allPlaylists = try mainContext.fetch(descriptor)
            let startIndex = min(offset, allPlaylists.count)
            let endIndex = min(startIndex + pageSize, allPlaylists.count)

            let playlists = Array(allPlaylists[startIndex..<endIndex])
            let hasMore = allPlaylists.count > endIndex

            return (playlists, hasMore)
        } catch {
            logger.error("Failed to search playlists with pagination: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }

    /// Legacy search method for playlists (for backward compatibility)
    public func searchPlaylists(_ query: String, limit: Int = 50) async throws -> [Playlist] {
        let searchQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !searchQuery.isEmpty else { return [] }

        var descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate<Playlist> { playlist in
                playlist.name.localizedStandardContains(searchQuery) ||
                playlist.playlistDescription?.localizedStandardContains(searchQuery) ?? false
            },
            sortBy: [SortDescriptor(\.name)]
        )
        descriptor.fetchLimit = limit

        do {
            return try mainContext.fetch(descriptor)
        } catch {
            logger.error("Failed to search playlists: \(error.localizedDescription)")
            throw DataManagerError.searchFailed(error)
        }
    }
    
    // MARK: - Recent Search Management

    /// Add a search to recent searches history
    public func addRecentSearch(_ query: String) async throws {
        try await recentSearchesActor.addSearch(query)
    }

    /// Get recent searches
    public func getRecentSearches(limit: Int = 10) async throws -> [RecentSearchData] {
        try await recentSearchesActor.getRecentSearches(limit: limit)
    }

    /// Clear all recent searches
    public func clearRecentSearches() async throws {
        try await recentSearchesActor.clearAllSearches()
    }

    /// Update result count for a search
    public func updateSearchResultCount(query: String, count: Int) async throws {
        try await recentSearchesActor.updateResultCount(for: query, count: count)
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
    
    /// Export library data to JSON for backup with pagination
    public func exportLibraryData() async throws -> Data {
        // Fetch all tracks in batches to avoid memory issues
        let allTracks = try await fetchAllTracksInBatches(batchSize: 100)
        let exportData = LibraryExportData(
            tracks: allTracks.map { track in
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
        let schema = Schema(SchemaV1.models)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true
        )

        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: RecentSearchMigrationPlan.self,
                configurations: [modelConfiguration]
            )
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }
    
    /// Create a preview DataManager for SwiftUI previews
    @MainActor
    static func makePreviewDataManager() -> DataManager {
        do {
            let previewDataManager = try DataManager()
            return previewDataManager
        } catch {
            fatalError("Could not create preview DataManager: \(error)")
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
