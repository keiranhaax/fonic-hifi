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

    @Test("Unavailable generation returns actual standard-search tracks")
    @MainActor
    func unavailableGenerationUsesStandardSearch() async throws {
        let dataManager = try #require(DataManager.makePreviewDataManager())
        let track = Track(
            url: URL(fileURLWithPath: "/tmp/fallback-needle.flac"),
            title: "Fallback Needle",
            artist: "Offline Artist",
            album: "Offline Album",
            audioFormat: "FLAC"
        )
        dataManager.mainContext.insert(track)
        try dataManager.mainContext.save()

        let service = SmartSearchService(
            availabilityCheck: { false },
            generationProviderFactory: {
                UnavailableSmartSearchGenerationProvider()
            }
        )
        let viewModel = SmartSearchViewModel(
            smartSearchService: service,
            availabilityCheck: { false }
        )

        await viewModel.performSmartSearch(query: "Needle", dataManager: dataManager)

        #expect(viewModel.searchState == .results)
        #expect(viewModel.resultTrackIDs == [track.id])
        #expect(viewModel.smartSearchResult?.searchStrategy == "Showing standard search results")
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

    @Test("Cancelled search publishes no stale result")
    @MainActor
    func cancelledSearchPublishesNoResult() async throws {
        let dataManager = try #require(DataManager.makePreviewDataManager())
        let operation = CancellationControlledSearchOperation()
        let viewModel = SmartSearchViewModel(
            availabilityCheck: { true },
            searchOperation: operation.perform
        )

        let task = Task {
            await viewModel.performSmartSearch(query: "cancel me", dataManager: dataManager)
        }
        while !operation.hasStarted {
            await Task.yield()
        }

        task.cancel()
        await task.value

        #expect(viewModel.searchState == .idle)
        #expect(viewModel.smartSearchResult == nil)
        #expect(viewModel.resultTrackIDs.isEmpty)
    }

    @Test("Older completion cannot overwrite the newest query")
    @MainActor
    func staleCompletionIsRejected() async throws {
        let oldTrackID = UUID()
        let newTrackID = UUID()
        let dataManager = try #require(DataManager.makePreviewDataManager())
        let operation = OutOfOrderSearchOperation(
            oldResult: makeResult(trackID: oldTrackID),
            newResult: makeResult(trackID: newTrackID)
        )
        let viewModel = SmartSearchViewModel(
            availabilityCheck: { true },
            searchOperation: operation.perform
        )

        let oldTask = Task {
            await viewModel.performSmartSearch(query: "old", dataManager: dataManager)
        }
        while !operation.oldRequestHasStarted {
            await Task.yield()
        }

        await viewModel.performSmartSearch(query: "new", dataManager: dataManager)
        operation.completeOldRequest()
        await oldTask.value

        #expect(viewModel.searchState == .results)
        #expect(viewModel.resultTrackIDs == [newTrackID])
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

    private func makeResult(trackID: UUID) -> SmartSearchResult {
        SmartSearchResult(
            trackIDs: [trackID],
            matchReasons: [],
            searchStrategy: "Injected",
            suggestions: []
        )
    }
}

private enum SmartSearchTestError: LocalizedError {
    case failed

    var errorDescription: String? { "Search unavailable" }
}

@MainActor
private final class UnavailableSmartSearchGenerationProvider: SmartSearchGenerationProviding {
    func generate(prompt _: String) async throws -> SmartSearchResult {
        Issue.record("Unavailable model must not generate")
        return SmartSearchResult(
            trackIDs: [],
            matchReasons: [],
            searchStrategy: "Unexpected",
            suggestions: []
        )
    }
}

@MainActor
private final class CancellationControlledSearchOperation {
    private var continuation: CheckedContinuation<SmartSearchResult, Error>?
    var hasStarted: Bool { continuation != nil }

    func perform(query _: String, dataManager _: DataManager) async throws -> SmartSearchResult {
        try await withTaskCancellationHandler(
            operation: {
                try await withCheckedThrowingContinuation { continuation in
                    self.continuation = continuation
                }
            },
            onCancel: {
                Task { @MainActor [weak self] in
                    self?.continuation?.resume(throwing: CancellationError())
                    self?.continuation = nil
                }
            }
        )
    }
}

@MainActor
private final class OutOfOrderSearchOperation {
    private let oldResult: SmartSearchResult
    private let newResult: SmartSearchResult
    private var oldContinuation: CheckedContinuation<SmartSearchResult, Error>?

    var oldRequestHasStarted: Bool { oldContinuation != nil }

    init(oldResult: SmartSearchResult, newResult: SmartSearchResult) {
        self.oldResult = oldResult
        self.newResult = newResult
    }

    func perform(query: String, dataManager _: DataManager) async throws -> SmartSearchResult {
        guard query == "old" else { return newResult }
        return try await withCheckedThrowingContinuation { continuation in
            oldContinuation = continuation
        }
    }

    func completeOldRequest() {
        oldContinuation?.resume(returning: oldResult)
        oldContinuation = nil
    }
}
