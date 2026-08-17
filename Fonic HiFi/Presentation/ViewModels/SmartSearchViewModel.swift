// Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift
import Foundation
import OSLog
import SwiftUI

/// ViewModel for smart search functionality
@MainActor
@Observable
public final class SmartSearchViewModel {
    typealias SearchOperation = @MainActor (String, DataManager) async throws -> SmartSearchResult

    // MARK: - Types

    public enum SearchState: Equatable {
        case idle
        case searching
        case results
        case noResults
        case error(String)
    }

    public enum AvailabilityState: Equatable {
        case checking
        case available
        case unavailable(String)
    }

    // MARK: - Properties

    public private(set) var searchState: SearchState = .idle
    public private(set) var smartSearchResult: SmartSearchResult?
    public private(set) var isSmartSearchEnabled = false
    public private(set) var availabilityState: AvailabilityState = .checking

    /// Track IDs from the search result - use these with @Query in views
    public private(set) var resultTrackIDs: [UUID] = []

    @ObservationIgnored private let availabilityCheck: @MainActor () async -> Bool
    @ObservationIgnored private let searchOperation: SearchOperation
    @ObservationIgnored private var requestGeneration: UInt = 0
    private let logger = Log.logger(.smartSearch)

    // MARK: - Initialization

    public init() {
        let service = SmartSearchService()
        availabilityCheck = { await service.isSmartSearchAvailable() }
        searchOperation = Self.makeSearchOperation(service: service)
    }

    init(
        smartSearchService: SmartSearchService = SmartSearchService(),
        availabilityCheck: @escaping @MainActor () async -> Bool,
        searchOperation: SearchOperation? = nil
    ) {
        self.availabilityCheck = availabilityCheck
        self.searchOperation = searchOperation ?? Self.makeSearchOperation(service: smartSearchService)
    }

    // MARK: - Public Methods

    /// Check if smart search is available on this device
    public func checkSmartSearchAvailability() async {
        availabilityState = .checking
        isSmartSearchEnabled = await availabilityCheck()
        availabilityState = isSmartSearchEnabled
            ? .available
            : .unavailable("Smart Search is unavailable on this device.")
        let enabled = isSmartSearchEnabled
        logger.info("Smart search available: \(enabled, privacy: .public)")
    }

    /// Perform smart search with AI enhancement
    /// - Parameters:
    ///   - query: User's search query
    ///   - dataManager: DataManager for fetching context
    public func performSmartSearch(
        query: String,
        dataManager: DataManager
    ) async {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            requestGeneration &+= 1
            searchState = .idle
            smartSearchResult = nil
            resultTrackIDs = []
            return
        }

        requestGeneration &+= 1
        let generation = requestGeneration
        searchState = .searching

        do {
            let result = try await searchOperation(query, dataManager)
            try Task.checkCancellation()
            guard generation == requestGeneration else { return }

            smartSearchResult = result
            resultTrackIDs = result.trackIDs

            if result.trackIDs.isEmpty {
                searchState = .noResults
            } else {
                searchState = .results
            }

            logger.info("Smart search completed: \(result.trackIDs.count, privacy: .public) track IDs")

        } catch is CancellationError {
            guard generation == requestGeneration else { return }
            searchState = .idle
            smartSearchResult = nil
            resultTrackIDs = []
        } catch {
            guard generation == requestGeneration, !Task.isCancelled else { return }
            logger.error("Smart search failed: \(error.localizedDescription, privacy: .private)")
            searchState = .error(error.localizedDescription)
            smartSearchResult = nil
            resultTrackIDs = []
        }
    }

    /// Clear search state
    public func clearSearch() {
        requestGeneration &+= 1
        searchState = .idle
        smartSearchResult = nil
        resultTrackIDs = []
    }

    private static func makeSearchOperation(service: SmartSearchService) -> SearchOperation {
        { query, dataManager in
            let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
            let trackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)
            let metadata = try await dataManager.trackDataActor.getTrackMetadataForSearch(limit: 100)
            let tuples = metadata.map { ($0.id, $0.title, $0.artist, $0.genre) }
            let result = try await service.smartSearch(
                query: query,
                sessions: sessions,
                availableTrackIDs: trackIDs,
                trackMetadata: tuples
            )

            guard result.searchStrategy == SmartSearchService.standardFallbackStrategy else {
                return result
            }

            let standardTracks = try await dataManager.searchTracks(query)
            return SmartSearchResult(
                trackIDs: standardTracks.map(\.id),
                matchReasons: [],
                searchStrategy: "Showing standard search results",
                suggestions: result.suggestions
            )
        }
    }
}
