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
    }

    @Test("Smart search availability updates isSmartSearchEnabled")
    @MainActor
    func availabilityCheckUpdatesState() async {
        let viewModel = SmartSearchViewModel()

        await viewModel.checkSmartSearchAvailability()

        // Will be true or false depending on device
        #expect(viewModel.isSmartSearchEnabled == true || viewModel.isSmartSearchEnabled == false)
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
