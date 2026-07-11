//
//  SearchView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftData
import SwiftUI

/// Main search interface for Fonic HiFi
@MainActor
struct SearchView: View {
    @Binding var searchText: String
    @Environment(\.audioEngine) private var audioService
    @Environment(\.dataManager) private var dataManager
    @State private var searchResults = SearchResults()
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var recentSearches: [RecentSearchData] = []
    @State private var showingRecentSearches = true

    // Smart search
    @State private var smartSearchViewModel = SmartSearchViewModel()
    @State private var smartSearchPlaybackState = SmartSearchPlaybackState()
    @State private var useSmartSearch = false

    private let logger = Log.logger(.search)

    var body: some View {
        Group {
            if searchText.isEmpty, showingRecentSearches {
                // Show recent searches when search is empty
                RecentSearchesView(
                    recentSearches: recentSearches,
                    onSelectSearch: { query in
                        searchText = query
                    },
                    onClearSearches: {
                        Task {
                            try? await dataManager?.clearRecentSearches()
                            recentSearches = []
                        }
                    }
                )
            } else if useSmartSearch, case .results = smartSearchViewModel.searchState {
                // Smart search results
                SmartSearchResultsView(
                    result: smartSearchViewModel.smartSearchResult ?? SmartSearchResult(
                        trackIDs: [],
                        matchReasons: [],
                        searchStrategy: "",
                        suggestions: []
                    ),
                    trackIDs: smartSearchViewModel.smartSearchResult?.trackIDs ?? []
                ) { track in
                    playTrack(track)
                }
            } else if useSmartSearch, case .noResults = smartSearchViewModel.searchState {
                // Smart search no results
                NoResultsView(query: searchText, isSmartSearch: true)
            } else if useSmartSearch, case let .error(message) = smartSearchViewModel.searchState {
                ContentUnavailableView {
                    Label("Smart Search Failed", systemImage: "exclamationmark.magnifyingglass")
                } description: {
                    Text(message)
                } actions: {
                    Button("Try Again") { scheduleSearch(searchText) }
                        .buttonStyle(.borderedProminent)
                }
            } else if searchResults.isEmpty, !searchText.isEmpty, !isSearching {
                // Show no results message
                NoResultsView(query: searchText, isSmartSearch: false)
            } else if !searchResults.isEmpty {
                // Show search results
                SearchResultsListView(results: searchResults)
            } else if isSearching || smartSearchViewModel.searchState == .searching {
                // Show loading state
                ProgressView(useSmartSearch ? "Searching with AI..." : "Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Empty state before search
                EmptySearchView(
                    useSmartSearch: $useSmartSearch,
                    isSmartSearchAvailable: smartSearchViewModel.isSmartSearchEnabled
                )
            }
        }
        .navigationTitle("Search")
        .onChange(of: searchText) { _, newValue in
            scheduleSearch(newValue)
        }
        .onChange(of: useSmartSearch) { _, _ in
            guard !searchText.isEmpty else { return }
            scheduleSearch(searchText)
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Standard Search", systemImage: "magnifyingglass") {
                        useSmartSearch = false
                    }
                    Button("Smart Search", systemImage: "sparkles") {
                        useSmartSearch = true
                    }
                    .disabled(!smartSearchViewModel.isSmartSearchEnabled)
                } label: {
                    Label("Search Mode", systemImage: useSmartSearch ? "sparkles" : "magnifyingglass")
                }
                .accessibilityValue(useSmartSearch ? "Smart Search" : "Standard Search")
            }
        }
        .safeAreaInset(edge: .top) {
            VStack(spacing: 0) {
                if case let .unavailable(message) = smartSearchViewModel.availabilityState {
                    searchStatusBanner(message, systemImage: "sparkles")
                }
                if let message = smartSearchPlaybackState.errorMessage {
                    HStack {
                        searchStatusBanner(message, systemImage: "exclamationmark.triangle")
                        Button("Dismiss") { smartSearchPlaybackState.clearError() }
                            .padding(.trailing)
                    }
                    .background(.thinMaterial)
                }
            }
        }
        .task {
            // Load recent searches on appear
            await loadRecentSearches()
            // Check smart search availability
            await smartSearchViewModel.checkSmartSearchAvailability()
        }
    }

    private func scheduleSearch(_ query: String) {
        searchTask?.cancel()
        searchTask = Task {
            if query.isEmpty {
                showingRecentSearches = true
                searchResults = SearchResults()
                smartSearchViewModel.clearSearch()
                isSearching = false
                return
            }

            showingRecentSearches = false
            isSearching = true
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            if useSmartSearch, let dataManager {
                await smartSearchViewModel.performSmartSearch(query: query, dataManager: dataManager)
                isSearching = false
            } else {
                await performSearch(query)
            }
        }
    }

    private func searchStatusBanner(_ message: String, systemImage: String) -> some View {
        Label(message, systemImage: systemImage)
            .font(.footnote)
            .foregroundStyle(.secondary)
            .padding(.horizontal)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.thinMaterial)
    }

    private func performSearch(_ query: String) async {
        guard let dataManager else {
            isSearching = false
            return
        }

        do {
            let results = try await searchAllContent(query, dataManager: dataManager)

            // Update UI on main actor
            await MainActor.run {
                searchResults = results
                isSearching = false

                // Add to recent searches and update count
                Task {
                    try? await dataManager.addRecentSearch(query)
                    try? await dataManager.updateSearchResultCount(
                        query: query,
                        count: results.totalCount,
                    )
                }
            }
        } catch {
            logger.error("Search failed: \(error.localizedDescription, privacy: .public)")
            await MainActor.run {
                searchResults = SearchResults()
                isSearching = false
            }
        }
    }

    // Helper function to aggregate all searches
    private func searchAllContent(_ query: String, dataManager: DataManager) async throws -> SearchResults {
        let tracks = try await dataManager.searchTracks(query)
        let albums = try await dataManager.searchAlbums(query)
        let artists = try await dataManager.searchArtists(query)
        let playlists = try await dataManager.searchPlaylists(query)

        return SearchResults(
            tracks: tracks,
            albums: albums,
            artists: artists,
            playlists: playlists,
        )
    }

    private func loadRecentSearches() async {
        guard let dataManager else { return }
        do {
            recentSearches = try await dataManager.getRecentSearches()
        } catch {
            logger.error("Failed to load recent searches: \(error.localizedDescription, privacy: .public)")
            recentSearches = []
        }
    }

    private func playTrack(_ track: Track) {
        logger.info("Starting Smart Search result playback")
        Task { @MainActor in
            guard let audioService else {
                smartSearchPlaybackState.reportUnavailable()
                return
            }
            await smartSearchPlaybackState.play(track) { selectedTrack in
                try await audioService.play(track: selectedTrack)
            }
        }
    }
}

// MARK: - Search Results List View

private struct SearchResultsListView: View {
    let results: SearchResults

    var body: some View {
        List {
            // Tracks section
            if results.hasTrackResults {
                Section("Tracks") {
                    ForEach(results.tracks.prefix(10)) { track in
                        TrackRowView(track: track)
                    }
                    if results.tracks.count > 10 {
                        HStack {
                            Text("See all \(results.tracks.count) tracks")
                                .font(.footnote)
                                .foregroundStyle(.tint)
                        }
                    }
                }
            }

            // Albums section
            if results.hasAlbumResults {
                Section("Albums") {
                    ForEach(results.albums.prefix(5)) { album in
                        AlbumRowView(album: album)
                    }
                }
            }

            // Artists section
            if results.hasArtistResults {
                Section("Artists") {
                    ForEach(results.artists.prefix(5)) { artist in
                        SearchArtistRow(artist: artist)
                    }
                }
            }

            // Playlists section
            if results.hasPlaylistResults {
                Section("Playlists") {
                    ForEach(results.playlists) { playlist in
                        PlaylistSearchRowView(playlist: playlist)
                    }
                }
            }
        }
        .listStyle(.grouped)
    }
}

// MARK: - Supporting Row Views

private struct AlbumRowView: View {
    let album: Album

    var body: some View {
        HStack(spacing: 12) {
            LazyArtworkView(album: album, size: 50, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.body)
                Text(album.albumArtist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private struct SearchArtistRow: View {
    let artist: Artist

    var body: some View {
        HStack(spacing: 12) {
            // Artist image placeholder
            Circle()
                .fill(.tint.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "person.fill")
                        .foregroundStyle(.tint)
                }

            Text(artist.name)
                .font(.body)
            Spacer()
        }
    }
}

private struct PlaylistSearchRowView: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: playlist.systemIcon ?? "music.note.list")
                .font(.title3)
                .foregroundStyle(.tint)
                .frame(width: 40, height: 40)
                .background(.tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 2) {
                Text(playlist.name)
                    .font(.body)
                Text("\(playlist.trackCount) tracks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// MARK: - Recent Searches View

private struct RecentSearchesView: View {
    let recentSearches: [RecentSearchData]
    let onSelectSearch: (String) -> Void
    let onClearSearches: () -> Void

    var body: some View {
        List {
            Section {
                ForEach(recentSearches) { search in
                    Button {
                        onSelectSearch(search.query)
                    } label: {
                        HStack {
                            Image(systemName: "clock")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(search.query)
                            Spacer()
                            if search.resultCount > 0 {
                                Text("\(search.resultCount)")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
            } header: {
                HStack {
                    Text("Recent Searches")
                    Spacer()
                    if !recentSearches.isEmpty {
                        Button("Clear") {
                            onClearSearches()
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .listStyle(.grouped)
    }
}

// MARK: - Empty States

private struct EmptySearchView: View {
    @Binding var useSmartSearch: Bool
    let isSmartSearchAvailable: Bool

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: useSmartSearch ? "sparkles" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(useSmartSearch ? .purple : .gray.opacity(0.3))

            Text(useSmartSearch ? "Smart Search" : "Search your library")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text(useSmartSearch
                ? "Try descriptive queries like \"upbeat songs\" or \"chill evening music\""
                : "Find tracks, albums, artists, and playlists")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if isSmartSearchAvailable {
                Toggle(isOn: $useSmartSearch) {
                    Label("Smart Search", systemImage: "sparkles")
                }
                .toggleStyle(.button)
                .buttonStyle(.bordered)
                .tint(.purple)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NoResultsView: View {
    let query: String
    var isSmartSearch = false

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: isSmartSearch ? "sparkles" : "magnifyingglass")
                .font(.system(size: 60))
                .foregroundColor(isSmartSearch ? .purple.opacity(0.5) : .gray.opacity(0.3))
            Text("No results for \"\(query)\"")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(isSmartSearch
                ? "Try a different description or switch to standard search"
                : "Try searching for something else")
                .font(.caption)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
