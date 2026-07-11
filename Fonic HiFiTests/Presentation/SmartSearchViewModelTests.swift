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
