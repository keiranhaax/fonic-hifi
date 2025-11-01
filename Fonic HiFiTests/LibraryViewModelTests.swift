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
