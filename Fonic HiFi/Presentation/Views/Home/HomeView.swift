//
//  HomeView.swift
//  Fonic HiFi
//
//  iOS 26+ Home tab with data-driven sections
//

import SwiftData
import SwiftUI

@MainActor
struct HomeView: View {
    @Environment(\.dataManager) private var dataManager
    @Environment(\.audioEngine) private var audioEngine
    @Environment(\.showingNowPlaying) private var showingNowPlaying

    // Fresh library state
    @State private var recentlyAdded: [Track] = []
    @State private var artists: [Artist] = []
    @State private var genres: [String] = []
    @State private var albums: [Album] = []

    // Active library state (existing)
    @State private var recentlyPlayed: [Track] = []
    @State private var mostListened: [Track] = []
    @State private var favoriteAlbums: [Album] = []

    // UI state
    @State private var isLoading = true
    @State private var selectedArtist: Artist?
    @State private var selectedGenre: String?
    @State private var selectedAlbum: Album?

    // Album morph state
    @Namespace private var albumMorphNamespace
    @State private var expandedAlbum: Album?
    @State private var expandedAlbumColor: Color = .accentColor

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your music...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if isEmpty {
                    EmptyHomeView()
                } else {
                    contentView
                }
            }
            .navigationTitle("Home")
            .task {
                await loadData()
            }
            .sheet(item: $selectedArtist) { artist in
                ArtistDetailView(artist: artist)
            }
            .sheet(item: $selectedAlbum) { album in
                AlbumDetailView(album: album)
            }
        }
    }

    private var isEmpty: Bool {
        recentlyAdded.isEmpty && artists.isEmpty && genres.isEmpty && albums.isEmpty &&
        recentlyPlayed.isEmpty && mostListened.isEmpty && favoriteAlbums.isEmpty
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Quick Actions
                QuickActionsSection(
                    onShuffleAll: shuffleAll,
                    onSurpriseMe: surpriseMe
                )

                // Recently Added (hero section)
                if !recentlyAdded.isEmpty {
                    RecentlyAddedSection(tracks: recentlyAdded) { track in
                        playTrack(track)
                    }
                }

                // Your Artists
                if !artists.isEmpty {
                    ArtistsSection(artists: artists) { artist in
                        selectedArtist = artist
                    }
                }

                // Browse by Genre
                if !genres.isEmpty {
                    GenresSection(genres: genres) { genre in
                        selectedGenre = genre
                    }
                }

                // Albums
                if !albums.isEmpty {
                    AlbumsSection(
                        title: "Albums",
                        albums: albums,
                        expandedAlbumID: expandedAlbum?.id,
                        namespace: albumMorphNamespace,
                        onAlbumTap: { album in
                            expandAlbum(album)
                        }
                    )
                }

                // Recently Played (if user has history)
                if !recentlyPlayed.isEmpty {
                    HomeSection(title: "Recently Played") {
                        CarouselView(tracks: recentlyPlayed)
                    }
                }

                // Most Listened (if user has history)
                if !mostListened.isEmpty {
                    HomeSection(title: "Most Listened") {
                        CarouselView(tracks: mostListened)
                    }
                }

                // Favorite Albums
                if !favoriteAlbums.isEmpty {
                    AlbumsSection(
                        title: "Favorite Albums",
                        albums: favoriteAlbums,
                        expandedAlbumID: expandedAlbum?.id,
                        namespace: albumMorphNamespace,
                        onAlbumTap: { album in
                            expandAlbum(album)
                        }
                    )
                }
            }
            .padding(.vertical)
        }
        .overlay {
            if let album = expandedAlbum {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        collapseAlbum()
                    }

                GlassEffectContainer {
                    ExpandedAlbumOverlay(
                        album: album,
                        namespace: albumMorphNamespace,
                        accentColor: expandedAlbumColor,
                        onTrackTap: { track in
                            playTrackFromAlbum(track)
                        },
                        onDismiss: {
                            collapseAlbum()
                        }
                    )
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.85), value: expandedAlbum?.id)
    }

    private func loadData() async {
        isLoading = true

        guard let dataManager else {
            isLoading = false
            return
        }

        do {
            // Fresh library data
            recentlyAdded = try await dataManager.getRecentlyAddedTracks(limit: 10)
            artists = try await dataManager.getAllArtists(limit: 15)
            genres = try await dataManager.getUniqueGenres()
            albums = try await dataManager.getAllAlbums(limit: 10)

            // Active library data
            recentlyPlayed = try await dataManager.getRecentlyPlayedTracks(limit: 10)
            mostListened = try await dataManager.getMostListenedTracks(limit: 10)
            favoriteAlbums = try await dataManager.getFavoriteAlbums(limit: 10)
        } catch {
            // Silently handle errors - home screen shows empty state gracefully
        }

        isLoading = false
    }

    private func shuffleAll() {
        guard let dataManager, let audioEngine else { return }
        Task {
            do {
                let allTracks = try await dataManager.getRecentlyAddedTracks(limit: 1000)
                guard !allTracks.isEmpty else { return }

                let shuffledTracks = allTracks.shuffled()
                let audioTracks = shuffledTracks.map { $0.toAudioTrack() }
                audioEngine.queueManager.replaceQueue(with: audioTracks, startIndex: 0)
                if let firstTrack = shuffledTracks.first {
                    try await audioEngine.play(track: firstTrack)
                    showingNowPlaying.wrappedValue = true
                }
            } catch {
                // Handle error silently
            }
        }
    }

    private func surpriseMe() {
        // Phase 4: Will use Foundation Models
        // For now: same as shuffle
        shuffleAll()
    }

    private func playTrack(_ track: Track) {
        guard let audioEngine else { return }
        Task {
            do {
                try await audioEngine.play(track: track)
                showingNowPlaying.wrappedValue = true
            } catch {
                // Handle error silently
            }
        }
    }

    private func expandAlbum(_ album: Album) {
        Task {
            await DominantColorService.shared.extractColor(for: album)
            expandedAlbumColor = DominantColorService.shared.palette.glassTint
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                expandedAlbum = album
            }
        }
    }

    private func collapseAlbum() {
        withAnimation(.spring(response: 0.4, dampingFraction: 0.9)) {
            expandedAlbum = nil
        }
    }

    private func playTrackFromAlbum(_ track: Track) {
        guard let audioEngine else { return }

        // First collapse, then play
        collapseAlbum()

        Task {
            // Small delay to let animation complete
            try? await Task.sleep(for: .milliseconds(150))

            do {
                try await audioEngine.play(track: track)
                // Don't show NowPlaying - play in mini player only
            } catch {
                // Handle error silently
            }
        }
    }
}

// MARK: - Supporting Views

private struct HomeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)

            content
        }
    }
}

private struct EmptyHomeView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note.house")
                .font(.system(size: 60))
                .foregroundStyle(.tertiary)
            Text("Welcome to Fonic HiFi")
                .font(.title3.bold())
            Text("Import music to see your library here")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .frame(minHeight: 300)
    }
}

private struct AlbumCardView: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyArtworkView(album: album, size: 160, cornerRadius: 8)

            Text(album.title)
                .font(.callout.bold())
                .lineLimit(1)

            Text(album.albumArtist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 160)
    }
}

private struct CarouselView: View {
    let tracks: [Track]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(tracks) { track in
                    TrackCardView(track: track)
                }
            }
            .padding(.horizontal)
        }
    }
}

private struct TrackCardView: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            LazyArtworkView(track: track, size: 50, cornerRadius: 6)

            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.callout.bold())
                    .lineLimit(1)

                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(width: 250)
        .padding(8)
        .glassSurface(style: .standard, cornerRadius: 12)
    }
}

#Preview {
    HomeView()
}
