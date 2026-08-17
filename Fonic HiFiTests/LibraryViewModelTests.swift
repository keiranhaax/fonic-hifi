import XCTest
@testable import Fonic_HiFi

@MainActor
final class LibraryViewModelTests: XCTestCase {
    func testRefreshLoadsInitialTrackPage() async {
        let repository = MockLibraryRepository()
        let firstPage = Page(
            items: [makeTrackEntity(index: 0), makeTrackEntity(index: 1)],
            hasMore: true,
            nextPage: 1,
            totalCount: 4
        )
        await repository.configureTrackPages([firstPage])

        let viewModel = LibraryViewModel(
            repository: repository,
            configuration: .init(pageSize: 2, prefetchThreshold: 1)
        )

        await viewModel.refresh(section: .tracks, query: nil)

        XCTAssertEqual(viewModel.tracks.count, 2)
        XCTAssertNil(viewModel.lastError)
    }

    func testLoadNextPageWhenThresholdReached() async {
        let repository = MockLibraryRepository()
        let firstPage = Page(
            items: [makeTrackEntity(index: 0)],
            hasMore: true,
            nextPage: 1,
            totalCount: 3
        )
        let secondPage = Page(
            items: [makeTrackEntity(index: 1), makeTrackEntity(index: 2)],
            hasMore: false,
            nextPage: 2,
            totalCount: 3
        )
        await repository.configureTrackPages([firstPage, secondPage])

        let viewModel = LibraryViewModel(
            repository: repository,
            configuration: .init(pageSize: 1, prefetchThreshold: 1)
        )

        await viewModel.refresh(section: .tracks, query: nil)
        XCTAssertEqual(viewModel.tracks.count, 1)

        await viewModel.loadNextPageIfNeeded(section: .tracks, currentItemIndex: 0, query: nil)
        XCTAssertEqual(viewModel.tracks.count, 3)
    }

    func testRefreshErrorSetsLastError() async {
        let repository = MockLibraryRepository()
        await repository.configureTrackError(page: 0, error: MockError.expected)

        let viewModel = LibraryViewModel(
            repository: repository,
            configuration: .init(pageSize: 1, prefetchThreshold: 1)
        )

        await viewModel.refresh(section: .tracks, query: nil)

        XCTAssertEqual(viewModel.tracks.count, 0)
        XCTAssertEqual(viewModel.lastError, .fetchFailed(section: .tracks, reason: MockError.expected.localizedDescription))
    }

    func testRefreshWithNewQueryResetsPagination() async {
        let repository = MockLibraryRepository()
        let firstPage = Page(
            items: [makeTrackEntity(index: 0)],
            hasMore: true,
            nextPage: 1,
            totalCount: 3
        )
        let secondPage = Page(
            items: [makeTrackEntity(index: 1), makeTrackEntity(index: 2)],
            hasMore: false,
            nextPage: 2,
            totalCount: 3
        )
        await repository.configureTrackPages([firstPage, secondPage])

        let viewModel = LibraryViewModel(
            repository: repository,
            configuration: .init(pageSize: 1, prefetchThreshold: 1)
        )

        await viewModel.refresh(section: .tracks, query: nil)
        await viewModel.loadNextPageIfNeeded(section: .tracks, currentItemIndex: 0, query: nil)
        XCTAssertEqual(viewModel.tracks.count, 3)

        await viewModel.refresh(section: .tracks, query: "ambient")
        XCTAssertEqual(viewModel.tracks.count, 1)
        XCTAssertNil(viewModel.lastError)
    }

    func testNewQueryRejectsOutOfOrderCompletionFromCancelledRequest() async {
        let repository = ControlledLibraryRepository()
        let viewModel = LibraryViewModel(
            repository: repository,
            configuration: .init(pageSize: 1, prefetchThreshold: 1)
        )

        let originalRequest = Task {
            await viewModel.refresh(section: .tracks, query: nil)
        }
        await repository.waitForTrackRequestCount(1)
        XCTAssertEqual(viewModel.loadPhase(for: .tracks), .initial)

        let replacementRequest = Task {
            await viewModel.refresh(section: .tracks, query: "ambient")
        }
        await repository.waitForTrackRequestCount(2)

        let replacementTrack = makeTrackEntity(index: 2)
        await repository.completeTrackRequest(
            page: 0,
            query: "ambient",
            with: Page(items: [replacementTrack], hasMore: false, nextPage: 1, totalCount: 1)
        )
        await replacementRequest.value

        XCTAssertEqual(viewModel.tracks.map(\.id), [replacementTrack.id])
        XCTAssertEqual(viewModel.loadPhase(for: .tracks), .idle)

        let staleTrack = makeTrackEntity(index: 1)
        await repository.completeTrackRequest(
            page: 0,
            query: nil,
            with: Page(items: [staleTrack], hasMore: false, nextPage: 1, totalCount: 1)
        )
        await originalRequest.value

        XCTAssertEqual(viewModel.tracks.map(\.id), [replacementTrack.id])
    }

    func testDuplicatePaginationTriggerStartsOnlyOneRequest() async {
        let repository = ControlledLibraryRepository()
        let viewModel = LibraryViewModel(
            repository: repository,
            configuration: .init(pageSize: 1, prefetchThreshold: 1)
        )

        let initialRequest = Task {
            await viewModel.refresh(section: .tracks, query: nil)
        }
        await repository.waitForTrackRequestCount(1)
        let firstTrack = makeTrackEntity(index: 0)
        await repository.completeTrackRequest(
            page: 0,
            query: nil,
            with: Page(items: [firstTrack], hasMore: true, nextPage: 1, totalCount: 2)
        )
        await initialRequest.value

        let paginationRequest = Task {
            await viewModel.loadNextPageIfNeeded(
                section: .tracks,
                currentItemIndex: 0,
                query: nil
            )
        }
        await repository.waitForTrackRequestCount(2)
        XCTAssertEqual(viewModel.loadPhase(for: .tracks), .pagination)

        await viewModel.loadNextPageIfNeeded(
            section: .tracks,
            currentItemIndex: 0,
            query: nil
        )
        let requestCount = await repository.trackRequestCount()
        XCTAssertEqual(requestCount, 2)

        let secondTrack = makeTrackEntity(index: 1)
        await repository.completeTrackRequest(
            page: 1,
            query: nil,
            with: Page(items: [secondTrack], hasMore: false, nextPage: 2, totalCount: 2)
        )
        await paginationRequest.value

        XCTAssertEqual(viewModel.tracks.map(\.id), [firstTrack.id, secondTrack.id])
        XCTAssertEqual(viewModel.loadPhase(for: .tracks), .idle)
    }

    func testCancellingSectionRequestPreventsCompletionFromCommitting() async {
        let repository = ControlledLibraryRepository()
        let viewModel = LibraryViewModel(repository: repository)

        let request = Task {
            await viewModel.refresh(section: .tracks, query: nil)
        }
        await repository.waitForTrackRequestCount(1)

        viewModel.cancelRequest(for: .tracks)
        XCTAssertEqual(viewModel.loadPhase(for: .tracks), .idle)

        let cancelledTrack = makeTrackEntity(index: 0)
        await repository.completeTrackRequest(
            page: 0,
            query: nil,
            with: Page(items: [cancelledTrack], hasMore: false, nextPage: 1, totalCount: 1)
        )
        await request.value

        XCTAssertTrue(viewModel.tracks.isEmpty)
    }

    // MARK: - Helpers

    private func makeTrackEntity(index: Int) -> TrackEntity {
        TrackEntity(
            id: UUID(),
            title: "Track \(index)",
            artist: "Artist \(index)",
            album: "Album \(index % 2)",
            albumArtist: "Artist \(index % 2)",
            duration: TimeInterval(200 + index),
            trackNumber: index + 1,
            discNumber: 1,
            genre: "Electronic",
            year: 2025,
            audioFormat: "FLAC",
            artworkSha: nil,
            fileURL: URL(fileURLWithPath: "/tmp/track\(index).flac"),
            fileSize: 24_000_000,
            bitDepth: 24,
            sampleRate: 96_000,
            channels: 2,
            bitrate: nil,
            isLossless: true,
            dateAdded: .now
        )
    }
}

private actor ControlledLibraryRepository: LibraryRepository {
    private struct TrackRequestKey: Hashable {
        let page: Int
        let query: String?
    }

    private var trackContinuations:
        [TrackRequestKey: [CheckedContinuation<Page<TrackEntity>, any Error>]] = [:]
    private var trackRequests: [TrackRequestKey] = []
    private var requestCountWaiters: [
        (count: Int, continuation: CheckedContinuation<Void, Never>)
    ] = []

    func tracks(page: Int, pageSize _: Int, searchQuery: String?) async throws -> Page<TrackEntity> {
        let key = TrackRequestKey(page: page, query: searchQuery)
        trackRequests.append(key)
        resumeSatisfiedWaiters()

        return try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                trackContinuations[key, default: []].append(continuation)
            }
        } onCancel: {
            // The controlled boundary intentionally completes cancelled work so
            // the view model's generation check is exercised.
        }
    }

    func waitForTrackRequestCount(_ count: Int) async {
        guard trackRequests.count < count else { return }
        await withCheckedContinuation { continuation in
            requestCountWaiters.append((count, continuation))
        }
    }

    func trackRequestCount() -> Int {
        trackRequests.count
    }

    func completeTrackRequest(
        page: Int,
        query: String?,
        with result: Page<TrackEntity>
    ) {
        let key = TrackRequestKey(page: page, query: query)
        guard var continuations = trackContinuations[key], !continuations.isEmpty else { return }

        let continuation = continuations.removeFirst()
        trackContinuations[key] = continuations.isEmpty ? nil : continuations
        continuation.resume(returning: result)
    }

    func albums(page: Int, pageSize _: Int, searchQuery _: String?) async throws -> Page<AlbumEntity> {
        Page(items: [], hasMore: false, nextPage: page + 1, totalCount: 0)
    }

    func artists(page: Int, pageSize _: Int, searchQuery _: String?) async throws -> Page<ArtistEntity> {
        Page(items: [], hasMore: false, nextPage: page + 1, totalCount: 0)
    }

    func playlists(page: Int, pageSize _: Int, searchQuery _: String?) async throws -> Page<PlaylistEntity> {
        Page(items: [], hasMore: false, nextPage: page + 1, totalCount: 0)
    }

    func recentAdditions(limit _: Int) async throws -> [TrackEntity] {
        []
    }

    func libraryStatistics() async throws -> LibraryStatisticsEntity {
        LibraryStatisticsEntity(
            trackCount: 0,
            albumCount: 0,
            artistCount: 0,
            playlistCount: 0,
            totalDuration: 0,
            totalFileSize: 0,
            losslessTrackCount: 0,
            hiResTrackCount: 0
        )
    }

    private func resumeSatisfiedWaiters() {
        var pending: [(count: Int, continuation: CheckedContinuation<Void, Never>)] = []
        for waiter in requestCountWaiters {
            if trackRequests.count >= waiter.count {
                waiter.continuation.resume()
            } else {
                pending.append(waiter)
            }
        }
        requestCountWaiters = pending
    }
}

private actor MockLibraryRepository: LibraryRepository {
    private var trackPages: [Page<TrackEntity>] = []
    private var trackErrors: [Int: Error] = [:]

    func configureTrackPages(_ pages: [Page<TrackEntity>]) {
        trackPages = pages
    }

    func configureTrackError(page: Int, error: Error) {
        trackErrors[page] = error
    }

    func tracks(page: Int, pageSize: Int, searchQuery _: String?) async throws -> Page<TrackEntity> {
        if let error = trackErrors[page] {
            throw error
        }
        guard page < trackPages.count else {
            return Page(items: [], hasMore: false, nextPage: page + 1, totalCount: 0)
        }
        return trackPages[page]
    }

    func albums(page: Int, pageSize _: Int, searchQuery _: String?) async throws -> Page<AlbumEntity> {
        Page(items: [], hasMore: false, nextPage: page + 1, totalCount: 0)
    }

    func artists(page: Int, pageSize _: Int, searchQuery _: String?) async throws -> Page<ArtistEntity> {
        Page(items: [], hasMore: false, nextPage: page + 1, totalCount: 0)
    }

    func playlists(page: Int, pageSize _: Int, searchQuery _: String?) async throws -> Page<PlaylistEntity> {
        Page(items: [], hasMore: false, nextPage: page + 1, totalCount: 0)
    }

    func recentAdditions(limit _: Int) async throws -> [TrackEntity] { [] }

    func libraryStatistics() async throws -> LibraryStatisticsEntity {
        LibraryStatisticsEntity(
            trackCount: trackPages.first?.items.count ?? 0,
            albumCount: 0,
            artistCount: 0,
            playlistCount: 0,
            totalDuration: 0,
            totalFileSize: 0,
            losslessTrackCount: 0,
            hiResTrackCount: 0
        )
    }
}

private enum MockError: LocalizedError {
    case expected

    var errorDescription: String? {
        "expected failure"
    }
}
