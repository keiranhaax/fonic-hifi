// Fonic HiFiTests/Presentation/SmartSearchViewModelTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("SmartSearchViewModel Tests")
struct SmartSearchViewModelTests {

    @Test("Initial state is idle")
    @MainActor
    func initialStateIsIdle() {
        let viewModel = SmartSearchViewModel()

        #expect(viewModel.searchState == .idle)
        #expect(viewModel.smartSearchResult == nil)
        #expect(!viewModel.isSmartSearchEnabled)
        #expect(viewModel.availabilityState == .checking)
    }

    @Test("Available smart search is enabled deterministically")
    @MainActor
    func availableSearchUpdatesState() async {
        let viewModel = SmartSearchViewModel(availabilityCheck: { true })

        await viewModel.checkSmartSearchAvailability()

        #expect(viewModel.isSmartSearchEnabled)
        #expect(viewModel.availabilityState == .available)
    }

    @Test("Unavailable smart search exposes an explanation")
    @MainActor
    func unavailableSearchUpdatesState() async {
        let viewModel = SmartSearchViewModel(availabilityCheck: { false })

        await viewModel.checkSmartSearchAvailability()

        #expect(!viewModel.isSmartSearchEnabled)
        #expect(viewModel.availabilityState == .unavailable("Smart Search is unavailable on this device."))
    }

    @Test("Search result operation publishes authoritative IDs")
    @MainActor
    func searchOperationPublishesResults() async throws {
        let trackID = UUID()
        let dataManager = try #require(DataManager.makePreviewDataManager())
        let viewModel = SmartSearchViewModel(
            availabilityCheck: { true },
            searchOperation: { _, _ in
                SmartSearchResult(
                    trackIDs: [trackID],
                    matchReasons: ["Match"],
                    searchStrategy: "Fallback",
                    suggestions: []
                )
            }
        )

        await viewModel.performSmartSearch(query: "test", dataManager: dataManager)

        #expect(viewModel.searchState == .results)
        #expect(viewModel.resultTrackIDs == [trackID])
    }

    @Test("Search operation failure publishes retryable error")
    @MainActor
    func searchOperationFailurePublishesError() async throws {
        let dataManager = try #require(DataManager.makePreviewDataManager())
        let viewModel = SmartSearchViewModel(
            availabilityCheck: { true },
            searchOperation: { _, _ in throw SmartSearchTestError.failed }
        )

        await viewModel.performSmartSearch(query: "test", dataManager: dataManager)

        #expect(viewModel.searchState == .error("Search unavailable"))
        #expect(viewModel.resultTrackIDs.isEmpty)
    }

    @Test("Clear search resets state")
    @MainActor
    func clearSearchResetsState() {
        let viewModel = SmartSearchViewModel()

        viewModel.clearSearch()

        #expect(viewModel.searchState == .idle)
        #expect(viewModel.smartSearchResult == nil)
        #expect(viewModel.resultTrackIDs.isEmpty)
    }
}

private enum SmartSearchTestError: LocalizedError {
    case failed

    var errorDescription: String? { "Search unavailable" }
}
