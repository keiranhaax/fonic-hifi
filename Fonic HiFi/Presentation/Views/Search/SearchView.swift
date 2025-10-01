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
    @Environment(\.dataManager) private var dataManager
    @State private var searchResults = SearchResults()
    @State private var searchTask: Task<Void, Never>?
    @State private var isSearching = false
    @State private var recentSearches: [RecentSearchData] = []
    @State private var showingRecentSearches = true

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
                    },
                )
            } else if searchResults.isEmpty, !searchText.isEmpty, !isSearching {
                // Show no results message
                NoResultsView(query: searchText)
            } else if !searchResults.isEmpty {
                // Show search results
                SearchResultsListView(results: searchResults)
            } else if isSearching {
                // Show loading state
                ProgressView("Searching...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // Empty state before search
                EmptySearchView()
            }
        }
        .navigationTitle("Search")
        .onChange(of: searchText) { _, newValue in
            // Cancel previous search task
            searchTask?.cancel()

            // Debounce search with 300ms delay
            searchTask = Task {
                // Show recent searches if search is cleared
                if newValue.isEmpty {
                    showingRecentSearches = true
                    searchResults = SearchResults()
                    isSearching = false
                    return
                }

                showingRecentSearches = false
                isSearching = true

                // Wait for debounce delay
                try? await Task.sleep(for: .milliseconds(300))

                // Check if task was cancelled
                guard !Task.isCancelled else { return }

                // Perform search
                await performSearch(newValue)
            }
        }
        .task {
            // Load recent searches on appear
            await loadRecentSearches()
        }
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
            print("Search failed: \(error)")
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
            print("Failed to load recent searches: \(error)")
            recentSearches = []
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
            // Album artwork placeholder
            RoundedRectangle(cornerRadius: 8)
                .fill(.tint.opacity(0.15))
                .frame(width: 50, height: 50)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.tint)
                }

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
                ForEach(recentSearches, id: \.query) { search in
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
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("Search your library")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Find tracks, albums, artists, and playlists")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct NoResultsView: View {
    let query: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("No results for \"\(query)\"")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text("Try searching for something else")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
