//
//  HomeView.swift
//  Fonic HiFi
//
//  iOS 26+ Home tab with data-driven sections
//

import SwiftData
import SwiftUI

@MainActor
struct SurpriseMeRequestGate {
    private(set) var isRunning = false

    mutating func begin() -> Bool {
        guard !isRunning else { return false }
        isRunning = true
        return true
    }

    mutating func finish() {
        isRunning = false
    }
}

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

    // History-based sections
    @State private var continueListening: [Track] = []
    @State private var rediscoverTracks: [Track] = []

    // AI recommendations
    private let recommendationService = RecommendationService()
    @State private var timeBasedGreeting: TimeBasedGreeting?
    @State private var greetingTracks: [Track] = []
    @State private var surpriseMeRequestGate = SurpriseMeRequestGate()

    // UI state
    @State private var isLoading = true
    @State private var hasLoadedOnce = false
    @State private var selectedArtist: Artist?
    @State private var selectedGenre: String?
    @State private var selectedAlbum: Album?

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
                guard !hasLoadedOnce else { return }
                await loadData(showLoading: true)
                hasLoadedOnce = true
            }
            .onAppear {
                guard hasLoadedOnce else { return }
                Task {
                    await loadData(showLoading: false)
                }
            }
            .sheet(item: $selectedArtist) { artist in
                ArtistDetailView(artist: artist)
            }
            .sheet(item: $selectedAlbum) { album in
                AlbumSheetView(
                    album: album,
                    onTrackTap: { track in
                        playTrack(track)
                    }
                )
            }
        }
    }

    private var isEmpty: Bool {
        recentlyAdded.isEmpty && artists.isEmpty && genres.isEmpty && albums.isEmpty &&
        recentlyPlayed.isEmpty && mostListened.isEmpty && favoriteAlbums.isEmpty &&
        continueListening.isEmpty && rediscoverTracks.isEmpty
    }

    @ViewBuilder
    private var contentView: some View {
        ScrollView {
            VStack(spacing: DesignTokens.Spacing.xLarge) {
                // Quick Actions
                QuickActionsSection(
                    isGeneratingRecommendations: surpriseMeRequestGate.isRunning,
                    onShuffleAll: shuffleAll,
                    onSurpriseMe: surpriseMe
                )

                // Time-based greeting (AI-powered)
                if let greeting = timeBasedGreeting, !greetingTracks.isEmpty {
                    TimeBasedGreetingSection(
                        greeting: greeting,
                        tracks: greetingTracks,
                        onTrackTap: { track in
                            playTrack(track)
                        }
                    )
                }

                // Continue Listening (if has incomplete sessions)
                if !continueListening.isEmpty {
                    ContinueListeningSection(tracks: continueListening) { track in
                        playTrack(track)
                    }
                }

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
                        onAlbumTap: { album in
                            selectedAlbum = album
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

                // Rediscover (if has neglected tracks)
                if !rediscoverTracks.isEmpty {
                    RediscoverSection(tracks: rediscoverTracks) { track in
                        playTrack(track)
                    }
                }

                // Favorite Albums
                if !favoriteAlbums.isEmpty {
                    AlbumsSection(
                        title: "Favorite Albums",
                        albums: favoriteAlbums,
                        onAlbumTap: { album in
                            selectedAlbum = album
                        }
                    )
                }
            }
            .padding(.top, DesignTokens.Spacing.vertical)
            .padding(.bottom, DesignTokens.Spacing.small)
        }
    }

    private func loadData(showLoading: Bool) async {
        if showLoading {
            isLoading = true
        }

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

            // Pre-cache visible album artwork colors for smoother overlay theming work.
            let albumsToPrewarm = Array((albums + favoriteAlbums).prefix(12))
            Task(priority: .utility) {
                await DominantColorService.shared.prewarmColorCache(for: albumsToPrewarm)
            }

            // History-based sections
            continueListening = try await dataManager.getContinueListeningTracks(limit: 3)
            rediscoverTracks = try await dataManager.getRediscoverTracks(limit: 10)

            // Generate AI greeting if we have history
            if !recentlyPlayed.isEmpty {
                let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
                let trackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)

                let greeting = await recommendationService.generateTimeBasedGreeting(
                    sessions: sessions,
                    availableTrackIDs: trackIDs,
                    genres: genres
                )
                timeBasedGreeting = greeting

                // Load the actual tracks for the greeting using mainContext
                greetingTracks = try dataManager.fetchTracks(by: greeting.trackIDs)
            }
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
        guard let dataManager, let audioEngine else { return }
        guard surpriseMeRequestGate.begin() else { return }

        Task {
            defer { surpriseMeRequestGate.finish() }

            do {
                // Gather context
                let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
                let trackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)

                // Generate surprise mix
                let result = await recommendationService.generateSurpriseMix(
                    sessions: sessions,
                    availableTrackIDs: trackIDs,
                    genres: genres
                )

                // Fetch actual tracks from IDs using mainContext
                let tracks = try dataManager.fetchTracks(by: result.trackIDs)

                guard !tracks.isEmpty else {
                    // Fallback to shuffle if no tracks resolved
                    shuffleAll()
                    return
                }

                // Queue and play
                let audioTracks = tracks.map { $0.toAudioTrack() }
                audioEngine.queueManager.replaceQueue(with: audioTracks, startIndex: 0)
                if let firstTrack = tracks.first {
                    try await audioEngine.play(track: firstTrack)
                    showingNowPlaying.wrappedValue = true
                }
            } catch {
                // Fallback to shuffle on any error
                shuffleAll()
            }
        }
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

}

// MARK: - Supporting Views

private struct HomeSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.medium) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)

            content
        }
    }
}

private struct EmptyHomeView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.large) {
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

private struct CarouselView: View {
    let tracks: [Track]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.medium) {
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
        HStack(spacing: DesignTokens.Spacing.medium) {
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
        .padding(DesignTokens.Spacing.small)
        .glassSurface(style: .standard, cornerRadius: DesignTokens.CornerRadius.medium)
    }
}

#Preview {
    HomeView()
}
