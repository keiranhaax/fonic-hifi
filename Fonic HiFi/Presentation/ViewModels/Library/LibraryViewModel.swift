//
//  LibraryViewModel.swift
//  Fonic HiFi
//
//  Created by Codex on 3/6/26.
//
//  SwiftUI view model that fronts the library views. This replaces the
//  @Query-driven approach that eagerly loaded entire tables on the main actor
//  and introduces real pagination via the LibraryRepository boundary.
//

import Foundation
import Observation
import SwiftUI

@MainActor
final class LibraryViewModel: ObservableObject {
    enum Section {
        case tracks
        case albums
        case artists
        case playlists
    }

    @Published private(set) var tracks: [TrackEntity] = []
    @Published private(set) var albums: [AlbumEntity] = []
    @Published private(set) var artists: [ArtistEntity] = []
    @Published private(set) var playlists: [PlaylistEntity] = []
    @Published private(set) var statistics: LibraryStatisticsEntity?
    @Published var lastError: LibraryViewModelError?
    @Published private(set) var isLoadingSection: Section?

    private struct PaginationState<Item: Sendable> {
        var items: [Item] = []
        var nextPage: Int = 0
        var hasMore: Bool = true
        var isLoading: Bool = false
        var lastQuery: String?
    }

    private var trackState = PaginationState<TrackEntity>()
    private var albumState = PaginationState<AlbumEntity>()
    private var artistState = PaginationState<ArtistEntity>()
    private var playlistState = PaginationState<PlaylistEntity>()

    private let configuration: LibraryPaginationConfiguration
    private let tracksUseCase: FetchTracksPageUseCase
    private let albumsUseCase: FetchAlbumsPageUseCase
    private let artistsUseCase: FetchArtistsPageUseCase
    private let playlistsUseCase: FetchPlaylistsPageUseCase
    private let statsUseCase: LoadLibraryStatisticsUseCase
    private let logger = Log.logger(.library)

    init(repository: LibraryRepository, configuration: LibraryPaginationConfiguration = .init()) {
        let useCases = DefaultLibraryUseCases(repository: repository, configuration: configuration)
        self.configuration = configuration
        tracksUseCase = useCases
        albumsUseCase = useCases
        artistsUseCase = useCases
        playlistsUseCase = useCases
        statsUseCase = useCases
    }

    // MARK: - Public API

    func refresh(section: Section, query: String?) async {
        await fetch(section: section, query: normalized(query), reset: true)
    }

    func loadNextPageIfNeeded(section: Section, currentItemIndex: Int, query: String?) async {
        let state = state(for: section)
        guard state.hasMore else { return }
        guard state.isLoading == false else { return }

        let thresholdIndex = max(0, state.count - configuration.prefetchThreshold)
        if currentItemIndex >= thresholdIndex {
            await fetch(section: section, query: normalized(query), reset: false)
        }
    }

    func ensureStatisticsLoaded() async {
        guard statistics == nil else { return }
        do {
            statistics = try await statsUseCase.libraryStatistics()
        } catch {
            let wrapped = LibraryViewModelError.statistics(error.localizedDescription)
            lastError = wrapped
            logger.error("Failed to load library statistics: \(error.localizedDescription)")
        }
    }

    func resetErrors() {
        lastError = nil
    }

    // MARK: - Internal Fetching

    private func fetch(section: Section, query: String?, reset: Bool) async {
        switch section {
        case .tracks:
            trackState = await fetchPage(
                state: trackState,
                section: .tracks,
                query: query,
                reset: reset,
            ) { page, searchQuery in
                try await tracksUseCase.tracksPage(page: page, query: searchQuery)
            }
            tracks = trackState.items
        case .albums:
            albumState = await fetchPage(
                state: albumState,
                section: .albums,
                query: query,
                reset: reset,
            ) { page, searchQuery in
                try await albumsUseCase.albumsPage(page: page, query: searchQuery)
            }
            albums = albumState.items
        case .artists:
            artistState = await fetchPage(
                state: artistState,
                section: .artists,
                query: query,
                reset: reset,
            ) { page, searchQuery in
                try await artistsUseCase.artistsPage(page: page, query: searchQuery)
            }
            artists = artistState.items
        case .playlists:
            playlistState = await fetchPage(
                state: playlistState,
                section: .playlists,
                query: query,
                reset: reset,
            ) { page, searchQuery in
                try await playlistsUseCase.playlistsPage(page: page, query: searchQuery)
            }
            playlists = playlistState.items
        }
    }

    private func fetchPage<Item>(
        state: PaginationState<Item>,
        section: Section,
        query: String?,
        reset: Bool,
        loader: (Int, String?) async throws -> Page<Item>,
    ) async -> PaginationState<Item> where Item: Sendable {
        if state.isLoading { return state }

        let effectiveQuery = query?.isEmpty == true ? nil : query
        var nextState = state

        if reset || nextState.lastQuery != effectiveQuery {
            nextState.items = []
            nextState.nextPage = 0
            nextState.hasMore = true
            nextState.lastQuery = effectiveQuery
        }

        guard nextState.hasMore else { return nextState }

        nextState.isLoading = true
        isLoadingSection = section

        do {
            let targetPage = nextState.nextPage
            let page = try await loader(targetPage, effectiveQuery)
            if targetPage == 0 {
                nextState.items = page.items
            } else {
                nextState.items.append(contentsOf: page.items)
            }
            nextState.nextPage = page.nextPage
            nextState.hasMore = page.hasMore
        } catch {
            let wrapped = LibraryViewModelError.fetchFailed(section: section, reason: error.localizedDescription)
            lastError = wrapped
            logger.error("Failed to fetch section \(String(describing: section)): \(error.localizedDescription)")
        }

        nextState.isLoading = false
        if isLoadingSection == section {
            isLoadingSection = nil
        }

        return nextState
    }

    private func state(for section: Section) -> (count: Int, hasMore: Bool, isLoading: Bool) {
        switch section {
        case .tracks:
            (trackState.items.count, trackState.hasMore, trackState.isLoading)
        case .albums:
            (albumState.items.count, albumState.hasMore, albumState.isLoading)
        case .artists:
            (artistState.items.count, artistState.hasMore, artistState.isLoading)
        case .playlists:
            (playlistState.items.count, playlistState.hasMore, playlistState.isLoading)
        }
    }

    private func normalized(_ query: String?) -> String? {
        guard let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Error Handling

enum LibraryViewModelError: LocalizedError, Equatable {
    case fetchFailed(section: LibraryViewModel.Section, reason: String)
    case statistics(String)

    var errorDescription: String? {
        switch self {
        case let .fetchFailed(section, reason):
            "Failed to load \(section.displayName) – \(reason)"
        case let .statistics(reason):
            "Failed to load library statistics – \(reason)"
        }
    }
}

private extension LibraryViewModel.Section {
    var displayName: String {
        switch self {
        case .tracks: "tracks"
        case .albums: "albums"
        case .artists: "artists"
        case .playlists: "playlists"
        }
    }
}
