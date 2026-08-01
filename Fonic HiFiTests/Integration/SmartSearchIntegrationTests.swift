// Fonic HiFiTests/Integration/SmartSearchIntegrationTests.swift
import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("Smart Search Integration Tests")
struct SmartSearchIntegrationTests {

    @Test("SmartSearchService handles various query types")
    @MainActor
    func handlesVariousQueries() async throws {
        let service = SmartSearchService()
        let trackIDs = (0..<20).map { _ in UUID() }
        let metadata: [(id: UUID, title: String, artist: String, genre: String?)] = trackIDs.map {
            ($0, "Track \($0.uuidString.prefix(4))", "Artist", "Rock")
        }

        // Exact query
        let exactResult = try await service.smartSearch(
            query: "Track",
            sessions: [],
            availableTrackIDs: trackIDs,
            trackMetadata: metadata
        )
        #expect(exactResult.searchStrategy.isEmpty == false)

        // Descriptive query
        let descriptiveResult = try await service.smartSearch(
            query: "something chill for the evening",
            sessions: [],
            availableTrackIDs: trackIDs,
            trackMetadata: metadata
        )
        #expect(descriptiveResult.searchStrategy.isEmpty == false)

        // Empty query
        let emptyResult = try await service.smartSearch(
            query: "",
            sessions: [],
            availableTrackIDs: trackIDs,
            trackMetadata: metadata
        )
        #expect(emptyResult.trackIDs.isEmpty)
    }

    @Test("SmartSearchViewModel state transitions correctly")
    @MainActor
    func viewModelStateTransitions() async {
        let viewModel = SmartSearchViewModel()

        #expect(viewModel.searchState == .idle)

        viewModel.clearSearch()
        #expect(viewModel.searchState == .idle)
        #expect(viewModel.resultTrackIDs.isEmpty)
    }

    @Test("Schema types are Sendable")
    func schemaTypesAreSendable() {
        let result = SmartSearchResult(
            trackIDs: [UUID()],
            matchReasons: ["Test"],
            searchStrategy: "Test",
            suggestions: []
        )

        // Verify Sendable conformance by passing across concurrency boundary
        Task {
            _ = result.trackIDs
        }
    }
}
