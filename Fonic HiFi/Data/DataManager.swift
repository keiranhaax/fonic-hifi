//
//  DataManager.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import OSLog
import SwiftData

/// Centralized data management for the Fonic HiFi app
@MainActor
public final class DataManager: ObservableObject {
    // MARK: - Properties

    public let isFallback: Bool

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
    private static let initLogger = Logger(subsystem: "com.fonichifi.data", category: "DataManager.init")

    // MARK: - Initialization

    public convenience init() throws {
        let schema = Schema(SchemaV1.models)
        // Use versioned schema for consistency with migration plan
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            allowsSave: true,
            cloudKitDatabase: .none, // Disable CloudKit for now (privacy-first)
        )

        do {
            let container = try DataManager.buildContainer(
                schema: schema,
                configuration: modelConfiguration,
                logger: DataManager.initLogger,
            )
            self.init(container: container, isFallback: false)
            logger.info("DataManager initialized successfully")
        } catch {
            DataManager.initLogger.error("Failed to initialize DataManager: \(error.localizedDescription)")
            throw DataManagerError.initializationFailed(error)
        }
    }

    private init(container: ModelContainer, isFallback: Bool) {
        self.container = container
        mainContext = container.mainContext
        backgroundContext = ModelContext(container)
        self.isFallback = isFallback

        mainContext.autosaveEnabled = true
        backgroundContext.autosaveEnabled = false

        let formatDetectionService = AudioFormatDetectionManager()
        metadataExtractor = MetadataExtractionService(formatDetectionService: formatDetectionService)
        trackDataActor = TrackDataActor(modelContainer: container)
        recentSearchesActor = RecentSearchesActor(modelContainer: container)
        importService = LibraryImportService(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor,
        )

        logger.info("DataManager initialized\(isFallback ? " in fallback mode" : "") successfully")
    }

    private static func buildContainer(
        schema: Schema,
        configuration: ModelConfiguration,
        logger: Logger,
    ) throws -> ModelContainer {
        do {
            return try ModelContainer(
                for: schema,
                migrationPlan: RecentSearchMigrationPlan.self,
                configurations: [configuration],
            )
        } catch let migrationError {
            logger.error("Failed to create ModelContainer with migration plan: \(migrationError.localizedDescription)")
            do {
                return try ModelContainer(
                    for: schema,
                    configurations: [configuration],
                )
            } catch let fallbackError {
                logger.critical("Failed to create fallback ModelContainer: \(fallbackError.localizedDescription)")
                throw fallbackError
            }
        }
    }

    // MARK: - Library Statistics

    /// Get current library statistics
    public func getLibraryStatistics() async throws -> LibraryStatistics {
        let trackDescriptor = FetchDescriptor<Track>(
            sortBy: [SortDescriptor(\.id)],
        )

        do {
            let albumCount = try mainContext.fetchCount(FetchDescriptor<Album>())
            let artistCount = try mainContext.fetchCount(FetchDescriptor<Artist>())
            let playlistCount = try mainContext.fetchCount(FetchDescriptor<Playlist>())

            var trackCount = 0
            var totalDuration: TimeInterval = 0
            var totalFileSize: Int64 = 0
            var losslessCount = 0
            var hiResCount = 0

            let processor = BatchProcessor<Track>(context: mainContext, batchSize: 200)
            try processor.processBatches(descriptor: trackDescriptor) { batch in
                trackCount += batch.count

                for track in batch {
                    totalDuration += track.duration
                    totalFileSize += track.fileSize

                    if track.isLossless {
                        losslessCount += 1
                    }

                    if track.sampleRate > 48000 || track.bitDepth > 16 {
                        hiResCount += 1
                    }
                }
            }

            return LibraryStatistics(
                trackCount: trackCount,
                albumCount: albumCount,
                artistCount: artistCount,
                playlistCount: playlistCount,
                totalDuration: totalDuration,
                totalFileSize: totalFileSize,
                losslessTrackCount: losslessCount,
                hiResTrackCount: hiResCount,
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
        pageSize: Int = defaultPageSize,
    ) async throws -> (tracks: [Track], hasMore: Bool) {
        var descriptor = FetchDescriptor<Track>(
            predicate: predicate,
            sortBy: sortBy,
        )

        // Calculate offset and limit for pagination
        let offset = page * pageSize
        descriptor.fetchLimit = pageSize + 1 // Fetch one extra to check if more exist

        do {
            // SwiftData doesn't have direct offset support, so we'll simulate it
            let allTracks = try mainContext.fetch(descriptor)
            let startIndex = min(offset, allTracks.count)
            let endIndex = min(startIndex + pageSize, allTracks.count)

            let tracks = Array(allTracks[startIndex ..< endIndex])
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
        pageSize: Int = defaultPageSize,
    ) async throws -> (albums: [Album], hasMore: Bool) {
        var descriptor = FetchDescriptor<Album>(
            predicate: predicate,
            sortBy: sortBy,
        )

        let offset = page * pageSize
        descriptor.fetchLimit = pageSize + 1

        do {
            let allAlbums = try mainContext.fetch(descriptor)
            let startIndex = min(offset, allAlbums.count)
            let endIndex = min(startIndex + pageSize, allAlbums.count)

            let albums = Array(allAlbums[startIndex ..< endIndex])
            let hasMore = allAlbums.count > endIndex

            return (albums, hasMore)
        } catch {
            logger.error("Failed to fetch albums with pagination: \(error.localizedDescription)")
            throw DataManagerError.fetchFailed(error)
        }
    }

    /// Fetch all tracks in batches (for large operations like export)
    public func fetchAllTracksInBatches(
        batchSize: Int = defaultPageSize,
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
            pageSize: pageSize,
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
            sortBy: [SortDescriptor(\.title)],
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
            pageSize: pageSize,
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
            sortBy: [SortDescriptor(\.title)],
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
            sortBy: [SortDescriptor(\.sortName)],
        )

        // Calculate offset and limit for pagination
        let offset = page * pageSize
        descriptor.fetchLimit = pageSize + 1 // Fetch one extra to check if more exist

        do {
            let allArtists = try mainContext.fetch(descriptor)
            let startIndex = min(offset, allArtists.count)
            let endIndex = min(startIndex + pageSize, allArtists.count)

            let artists = Array(allArtists[startIndex ..< endIndex])
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
            sortBy: [SortDescriptor(\.sortName)],
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
            sortBy: [SortDescriptor(\.name)],
        )

        let offset = page * pageSize
        descriptor.fetchLimit = pageSize + 1

        do {
            let allPlaylists = try mainContext.fetch(descriptor)
            let startIndex = min(offset, allPlaylists.count)
            let endIndex = min(startIndex + pageSize, allPlaylists.count)

            let playlists = Array(allPlaylists[startIndex ..< endIndex])
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
            sortBy: [SortDescriptor(\.name)],
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
            sortBy: [SortDescriptor(\.dateAdded, order: .reverse)],
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
            sortBy: [SortDescriptor(\.lastPlayed, order: .reverse)],
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
                    isFavorite: track.isFavorite,
                )
            },
            exportDate: Date(),
            version: "1.0",
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
        case let .initializationFailed(error):
            "Failed to initialize data manager: \(error.localizedDescription)"
        case let .fetchFailed(error):
            "Failed to fetch data: \(error.localizedDescription)"
        case let .searchFailed(error):
            "Search operation failed: \(error.localizedDescription)"
        case let .cleanupFailed(error):
            "Cleanup operation failed: \(error.localizedDescription)"
        case let .exportFailed(error):
            "Export operation failed: \(error.localizedDescription)"
        }
    }
}

// MARK: - Preview Support

extension DataManager {
    /// Create a preview container for SwiftUI previews
    static func previewContainer() -> ModelContainer? {
        let schema = Schema(SchemaV1.models)
        let modelConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none,
        )

        if let container = try? buildContainer(
            schema: schema,
            configuration: modelConfiguration,
            logger: initLogger,
        ) {
            return container
        }

        initLogger.fault("Falling back to read-only preview container")
        let readOnlyConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: false,
            cloudKitDatabase: .none,
        )

        if let container = try? ModelContainer(
            for: schema,
            configurations: [readOnlyConfiguration],
        ) {
            return container
        }

        initLogger.critical("Unable to create preview container")
        return nil
    }

    /// Create a preview DataManager for SwiftUI previews
    @MainActor
    static func makePreviewDataManager() -> DataManager? {
        if let fallback = makeFallbackDataManager() {
            return fallback
        }

        do {
            return try DataManager()
        } catch {
            initLogger.error("Error creating preview DataManager: \(error.localizedDescription)")
            return nil
        }
    }

    /// Create a preview import service for SwiftUI previews
    @MainActor
    static func makePreviewImportService() -> LibraryImportService? {
        guard let container = previewContainer() else {
            return nil
        }

        let trackDataActor = TrackDataActor(modelContainer: container)
        let metadataExtractor = MetadataExtractionService(
            formatDetectionService: AudioFormatDetectionManager(),
        )
        return LibraryImportService(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor,
        )
    }

    /// Create an in-memory fallback DataManager instance for app launch recovery
    @MainActor
    public static func makeFallbackDataManager() -> DataManager? {
        let schema = Schema(SchemaV1.models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none,
        )

        do {
            let container = try buildContainer(
                schema: schema,
                configuration: configuration,
                logger: initLogger,
            )
            return DataManager(container: container, isFallback: true)
        } catch {
            initLogger.critical("Failed to create fallback DataManager: \(error.localizedDescription)")
            return nil
        }
    }

    /// Ensure a fallback data manager can always be created for emergency scenarios
    @MainActor
    public static func ensureFallbackDataManager() -> DataManager {
        if let fallback = makeFallbackDataManager() {
            return fallback
        }

        if let preview = makePreviewDataManager() {
            return preview
        }

        let schema = Schema(SchemaV1.models)
        let inMemoryConfiguration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: false,
            cloudKitDatabase: .none,
        )

        if let container = try? buildContainer(
            schema: schema,
            configuration: inMemoryConfiguration,
            logger: initLogger,
        ) {
            return DataManager(container: container, isFallback: true)
        }

        if let container = try? ModelContainer(
            for: schema,
            configurations: [inMemoryConfiguration],
        ) {
            return DataManager(container: container, isFallback: true)
        }

        if let container = try? ModelContainer(for: schema) {
            return DataManager(container: container, isFallback: true)
        }

        initLogger.critical("Emergency fallback container creation failed; forcing in-memory initialization")
        guard let container = try? ModelContainer(
            for: schema,
            configurations: [inMemoryConfiguration],
        ) else {
            fatalError("Unable to create fallback DataManager container")
        }

        return DataManager(container: container, isFallback: true)
    }
}
