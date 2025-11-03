//
//  DataManager.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Combine
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
    public private(set) lazy var importService: LibraryImportService = {
        LibraryImportService(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor,
            statisticsInvalidator: { [weak self] in
                self?.invalidateLibraryStatisticsCache()
            }
        )
    }()

    private var libraryRepositoryCache: LibraryRepository?
    var libraryStatisticsCache = LibraryStatisticsCache()

    var libraryStatisticsComputationCount: Int {
        libraryStatisticsCache.computationCount
    }

    var libraryStatisticsCacheTTL: TimeInterval {
        get { libraryStatisticsCache.ttl }
        set { libraryStatisticsCache.updateTTL(newValue) }
    }

    /// Recovery state surfaced to the UI when operating in limited mode
    @Published public private(set) var importRecoveryState: ImportRecoveryState?

    /// Logger for data operations
    let logger = Log.logger(.dataManager)
    static let initLogger = Log.logger(.dataManagerInit)

    // MARK: - Initialization

    init(
        container: ModelContainer,
        isFallback: Bool,
        importRecoveryState: ImportRecoveryState? = nil,
    ) {
        self.container = container
        mainContext = container.mainContext
        backgroundContext = ModelContext(container)
        self.isFallback = isFallback
        self.importRecoveryState = importRecoveryState

        mainContext.autosaveEnabled = true
        backgroundContext.autosaveEnabled = false

        let formatDetectionService = AudioFormatDetectionManager()
        metadataExtractor = MetadataExtractionService(formatDetectionService: formatDetectionService)
        trackDataActor = TrackDataActor(modelContainer: container)
        recentSearchesActor = RecentSearchesActor(modelContainer: container)
        logger.info("DataManager initialized\(isFallback ? " in fallback mode" : "") successfully")
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

// MARK: - Library Repository Factory

extension DataManager: LibraryRepositoryFactory {
    public func makeLibraryRepository() -> LibraryRepository {
        if let libraryRepositoryCache {
            return libraryRepositoryCache
        }

        let repository = SwiftDataLibraryRepository(container: container)
        libraryRepositoryCache = repository
        return repository
    }

    func invalidateLibraryStatisticsCache() {
        libraryStatisticsCache.invalidate()

        if let repository = libraryRepositoryCache as? SwiftDataLibraryRepository {
            Task {
                await repository.invalidateLibraryStatisticsCache()
            }
        }
    }
}

// MARK: - Supporting Types

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
    case modelValidationFailed(String, Error)
    case fetchFailed(Error)
    case searchFailed(Error)
    case cleanupFailed(Error)
    case exportFailed(Error)
    case emergencyFallbackFailed(Error)

    public var errorDescription: String? {
        switch self {
        case let .initializationFailed(error):
            "Failed to initialize data manager: \(error.localizedDescription)"
        case let .modelValidationFailed(modelName, error):
            "Model '\(modelName)' validation failed: \(error.localizedDescription)"
        case let .fetchFailed(error):
            "Failed to fetch data: \(error.localizedDescription)"
        case let .searchFailed(error):
            "Search operation failed: \(error.localizedDescription)"
        case let .cleanupFailed(error):
            "Cleanup operation failed: \(error.localizedDescription)"
        case let .exportFailed(error):
            "Export operation failed: \(error.localizedDescription)"
        case let .emergencyFallbackFailed(error):
            "Emergency fallback initialization failed: \(error.localizedDescription)"
        }
    }
}
