// Fonic HiFi/Presentation/ViewModels/SmartSearchViewModel.swift
import Foundation
import SwiftUI

/// ViewModel for smart search functionality
@MainActor
@Observable
public final class SmartSearchViewModel {

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

    private let smartSearchService: SmartSearchService
    @ObservationIgnored private let availabilityCheck: @MainActor () async -> Bool
    private let logger = Log.logger(.smartSearch)

    // MARK: - Initialization

    public init() {
        let service = SmartSearchService()
        smartSearchService = service
        availabilityCheck = { await service.isSmartSearchAvailable() }
    }

    init(
        smartSearchService: SmartSearchService = SmartSearchService(),
        availabilityCheck: @escaping @MainActor () async -> Bool
    ) {
        self.smartSearchService = smartSearchService
        self.availabilityCheck = availabilityCheck
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
        logger.info("Smart search available: \(enabled)")
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
            searchState = .idle
            smartSearchResult = nil
            resultTrackIDs = []
            return
        }

        searchState = .searching

        do {
            // Gather context
            let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
            let allTrackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)
            let metadata = try await dataManager.trackDataActor.getTrackMetadataForSearch(limit: 100)

            // Convert metadata to tuple format expected by service
            let metadataTuples = metadata.map { ($0.id, $0.title, $0.artist, $0.genre) }

            // Perform smart search
            let result = await smartSearchService.smartSearch(
                query: query,
                sessions: sessions,
                availableTrackIDs: allTrackIDs,
                trackMetadata: metadataTuples
            )

            smartSearchResult = result
            resultTrackIDs = result.trackIDs

            if result.trackIDs.isEmpty {
                searchState = .noResults
            } else {
                searchState = .results
            }

            logger.info("Smart search completed: \(result.trackIDs.count) track IDs")

        } catch {
            logger.error("Smart search failed: \(error.localizedDescription)")
            searchState = .error(error.localizedDescription)
            smartSearchResult = nil
            resultTrackIDs = []
        }
    }

    /// Clear search state
    public func clearSearch() {
        searchState = .idle
        smartSearchResult = nil
        resultTrackIDs = []
    }
}
