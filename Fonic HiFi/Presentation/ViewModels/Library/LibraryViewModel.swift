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
import OSLog
import SwiftUI

@MainActor
final class LibraryViewModel: ObservableObject {
    enum Section: Hashable, Sendable {
        case tracks
        case albums
        case artists
        case playlists
    }

    enum LoadPhase: Equatable, Sendable {
        case idle
        case initial
        case pagination
    }

    @Published private(set) var tracks: [TrackEntity] = []
    @Published private(set) var albums: [AlbumEntity] = []
    @Published private(set) var artists: [ArtistEntity] = []
    @Published private(set) var playlists: [PlaylistEntity] = []
    @Published private(set) var statistics: LibraryStatisticsEntity?
    @Published var lastError: LibraryViewModelError?
    @Published private var loadPhases: [Section: LoadPhase] = [:]

    private struct PaginationState<Item: Sendable> {
        var items: [Item] = []
        var nextPage: Int = 0
        var hasMore: Bool = true
        var lastQuery: String?
    }

    private var trackState = PaginationState<TrackEntity>()
    private var albumState = PaginationState<AlbumEntity>()
    private var artistState = PaginationState<ArtistEntity>()
    private var playlistState = PaginationState<PlaylistEntity>()
    private var requestGenerations: [Section: UInt] = [:]
    private var requestTasks: [Section: Task<Void, Never>] = [:]

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
        guard loadPhase(for: section) == .idle else { return }
        guard state.lastQuery == normalized(query) else { return }

        let thresholdIndex = max(0, state.count - configuration.prefetchThreshold)
        if currentItemIndex >= thresholdIndex {
            await fetch(section: section, query: normalized(query), reset: false)
        }
    }

    func loadPhase(for section: Section) -> LoadPhase {
        loadPhases[section] ?? .idle
    }

    func cancelRequest(for section: Section) {
        requestTasks[section]?.cancel()
        requestTasks[section] = nil
        requestGenerations[section, default: 0] &+= 1
        loadPhases[section] = .idle
    }

    func ensureStatisticsLoaded() async {
        guard statistics == nil else { return }
        do {
            statistics = try await statsUseCase.libraryStatistics()
        } catch {
            let wrapped = LibraryViewModelError.statistics(error.localizedDescription)
            lastError = wrapped
            logger.error("Failed to load library statistics: \(error.localizedDescription, privacy: .private)")
        }
    }

    func resetErrors() {
        lastError = nil
    }

    // MARK: - Internal Fetching

    private func fetch(section: Section, query: String?, reset: Bool) async {
        let effectiveQuery = query?.isEmpty == true ? nil : query
        let currentState = state(for: section)

        if reset || currentState.lastQuery != effectiveQuery {
            cancelRequest(for: section)
            resetState(for: section, query: effectiveQuery)
        } else {
            guard loadPhase(for: section) == .idle else { return }
        }

        guard state(for: section).hasMore else { return }

        let targetPage = state(for: section).nextPage
        let generation = nextRequestGeneration(for: section)
        loadPhases[section] = targetPage == 0 ? .initial : .pagination

        let task: Task<Void, Never>
        switch section {
        case .tracks:
            let useCase = tracksUseCase
            task = Task { [weak self] in
                do {
                    let page = try await useCase.tracksPage(page: targetPage, query: effectiveQuery)
                    guard !Task.isCancelled else { return }
                    self?.commitTracks(
                        page,
                        targetPage: targetPage,
                        query: effectiveQuery,
                        generation: generation
                    )
                } catch is CancellationError {
                    self?.finishCancelledRequest(section: .tracks, generation: generation)
                } catch {
                    self?.finishFailedRequest(section: .tracks, generation: generation, error: error)
                }
            }
        case .albums:
            let useCase = albumsUseCase
            task = Task { [weak self] in
                do {
                    let page = try await useCase.albumsPage(page: targetPage, query: effectiveQuery)
                    guard !Task.isCancelled else { return }
                    self?.commitAlbums(
                        page,
                        targetPage: targetPage,
                        query: effectiveQuery,
                        generation: generation
                    )
                } catch is CancellationError {
                    self?.finishCancelledRequest(section: .albums, generation: generation)
                } catch {
                    self?.finishFailedRequest(section: .albums, generation: generation, error: error)
                }
            }
        case .artists:
            let useCase = artistsUseCase
            task = Task { [weak self] in
                do {
                    let page = try await useCase.artistsPage(page: targetPage, query: effectiveQuery)
                    guard !Task.isCancelled else { return }
                    self?.commitArtists(
                        page,
                        targetPage: targetPage,
                        query: effectiveQuery,
                        generation: generation
                    )
                } catch is CancellationError {
                    self?.finishCancelledRequest(section: .artists, generation: generation)
                } catch {
                    self?.finishFailedRequest(section: .artists, generation: generation, error: error)
                }
            }
        case .playlists:
            let useCase = playlistsUseCase
            task = Task { [weak self] in
                do {
                    let page = try await useCase.playlistsPage(page: targetPage, query: effectiveQuery)
                    guard !Task.isCancelled else { return }
                    self?.commitPlaylists(
                        page,
                        targetPage: targetPage,
                        query: effectiveQuery,
                        generation: generation
                    )
                } catch is CancellationError {
                    self?.finishCancelledRequest(section: .playlists, generation: generation)
                } catch {
                    self?.finishFailedRequest(section: .playlists, generation: generation, error: error)
                }
            }
        }

        requestTasks[section] = task
        await task.value
    }

    private func commitTracks(
        _ page: Page<TrackEntity>,
        targetPage: Int,
        query: String?,
        generation: UInt
    ) {
        guard ownsRequest(section: .tracks, query: query, generation: generation) else { return }
        update(&trackState, with: page, targetPage: targetPage)
        tracks = trackState.items
        finishRequest(section: .tracks, generation: generation)
    }

    private func commitAlbums(
        _ page: Page<AlbumEntity>,
        targetPage: Int,
        query: String?,
        generation: UInt
    ) {
        guard ownsRequest(section: .albums, query: query, generation: generation) else { return }
        update(&albumState, with: page, targetPage: targetPage)
        albums = albumState.items
        finishRequest(section: .albums, generation: generation)
    }

    private func commitArtists(
        _ page: Page<ArtistEntity>,
        targetPage: Int,
        query: String?,
        generation: UInt
    ) {
        guard ownsRequest(section: .artists, query: query, generation: generation) else { return }
        update(&artistState, with: page, targetPage: targetPage)
        artists = artistState.items
        finishRequest(section: .artists, generation: generation)
    }

    private func commitPlaylists(
        _ page: Page<PlaylistEntity>,
        targetPage: Int,
        query: String?,
        generation: UInt
    ) {
        guard ownsRequest(section: .playlists, query: query, generation: generation) else { return }
        update(&playlistState, with: page, targetPage: targetPage)
        playlists = playlistState.items
        finishRequest(section: .playlists, generation: generation)
    }

    private func ownsRequest(section: Section, query: String?, generation: UInt) -> Bool {
        requestGenerations[section] == generation && state(for: section).lastQuery == query
    }

    private func update<Item: Sendable>(
        _ state: inout PaginationState<Item>,
        with page: Page<Item>,
        targetPage: Int
    ) {
        if targetPage == 0 {
            state.items = page.items
        } else {
            state.items.append(contentsOf: page.items)
        }
        state.nextPage = page.nextPage
        state.hasMore = page.hasMore
    }

    private func finishCancelledRequest(section: Section, generation: UInt) {
        finishRequest(section: section, generation: generation)
    }

    private func finishFailedRequest(section: Section, generation: UInt, error: Error) {
        guard requestGenerations[section] == generation else { return }
        let wrapped = LibraryViewModelError.fetchFailed(section: section, reason: error.localizedDescription)
        lastError = wrapped
        logger.error("Failed to fetch section \(String(describing: section), privacy: .public): \(error.localizedDescription, privacy: .private)")
        finishRequest(section: section, generation: generation)
    }

    private func finishRequest(section: Section, generation: UInt) {
        guard requestGenerations[section] == generation else { return }
        requestTasks[section] = nil
        loadPhases[section] = .idle
    }

    private func nextRequestGeneration(for section: Section) -> UInt {
        requestGenerations[section, default: 0] &+= 1
        return requestGenerations[section, default: 0]
    }

    private func resetState(for section: Section, query: String?) {
        switch section {
        case .tracks:
            trackState = PaginationState(lastQuery: query)
            tracks = []
        case .albums:
            albumState = PaginationState(lastQuery: query)
            albums = []
        case .artists:
            artistState = PaginationState(lastQuery: query)
            artists = []
        case .playlists:
            playlistState = PaginationState(lastQuery: query)
            playlists = []
        }
    }

    private func state(for section: Section) -> (count: Int, nextPage: Int, hasMore: Bool, lastQuery: String?) {
        switch section {
        case .tracks:
            (trackState.items.count, trackState.nextPage, trackState.hasMore, trackState.lastQuery)
        case .albums:
            (albumState.items.count, albumState.nextPage, albumState.hasMore, albumState.lastQuery)
        case .artists:
            (artistState.items.count, artistState.nextPage, artistState.hasMore, artistState.lastQuery)
        case .playlists:
            (playlistState.items.count, playlistState.nextPage, playlistState.hasMore, playlistState.lastQuery)
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
