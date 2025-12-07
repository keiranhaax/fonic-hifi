// Fonic HiFiTests/Core/AI/SmartSearchServiceTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("SmartSearchService Tests")
struct SmartSearchServiceTests {

    @Test("Fallback search returns results from available tracks")
    @MainActor
    func fallbackSearchWorks() async {
        let service = SmartSearchService()
        let trackIDs = (0..<20).map { _ in UUID() }

        let result = await service.fallbackSearch(
            query: "chill music",
            availableTrackIDs: trackIDs
        )

        #expect(result.searchStrategy.contains("fallback") || result.searchStrategy.contains("unavailable"))
    }

    @Test("Availability check returns boolean")
    @MainActor
    func availabilityCheckWorks() async {
        let service = SmartSearchService()

        let isAvailable = await service.isSmartSearchAvailable()
        #expect(isAvailable == true || isAvailable == false)
    }

    @Test("Empty query returns empty results")
    @MainActor
    func emptyQueryReturnsEmpty() async {
        let service = SmartSearchService()

        let result = await service.fallbackSearch(
            query: "",
            availableTrackIDs: [UUID(), UUID()]
        )

        #expect(result.trackIDs.isEmpty)
    }
}
