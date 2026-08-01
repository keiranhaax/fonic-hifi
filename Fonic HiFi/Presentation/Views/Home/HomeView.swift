//
//  HomeView.swift
//  Fonic HiFi
//
//  iOS 26+ Home tab with data-driven sections
//

import OSLog
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
struct HomeLoadRequestGate {
    private(set) var generation: UInt = 0

    mutating func begin() -> UInt {
        generation &+= 1
        return generation
    }

    func isCurrent(_ request: UInt) -> Bool {
        request == generation
    }

    mutating func invalidate() {
        generation &+= 1
    }
}

struct HomeLoadFailure: Equatable {
    enum Context: Equatable {
        case initial
        case refresh
    }

    let context: Context

    var title: String {
        switch context {
        case .initial:
            "Couldn't Load Home"
        case .refresh:
            "Home Couldn't Refresh"
        }
    }

    var message: String {
        switch context {
        case .initial:
            "Your library couldn't be loaded. Try again."
        case .refresh:
            "Your existing music is still available. Try refreshing again."
        }
    }
}

struct HomeLoadPresentationState: Equatable {
    private(set) var failure: HomeLoadFailure?

    mutating func beginRequest() {
        failure = nil
    }

    mutating func recordFailure(hasContent: Bool) {
        failure = HomeLoadFailure(context: hasContent ? .refresh : .initial)
    }

    mutating func clearFailure() {
        failure = nil
    }
}

struct HomeLoadPhase: Equatable {
    enum Phase: Equatable {
        case idle
        case loading
        case ready
    }

    private(set) var library: Phase = .loading
    private(set) var greeting: Phase = .idle

    var blocksHomeContent: Bool {
        library == .loading
    }

    mutating func beginLibraryLoad(showLoading: Bool) {
        if showLoading {
            library = .loading
        }
    }

    mutating func finishLibraryLoad() {
        library = .ready
    }

    mutating func beginGreetingLoad() {
        greeting = .loading
    }

    mutating func finishGreetingLoad() {
        greeting = .ready
    }
}

private enum HomeActionError: LocalizedError {
    case libraryUnavailable
    case noPlayableTracks

    var errorDescription: String? {
        switch self {
        case .libraryUnavailable:
            "Your music library is unavailable."
        case .noPlayableTracks:
            "No music is available to play."
        }
    }
}

@MainActor
struct HomeView: View {
    @Environment(\.dataManager) private var dataManager
    @EnvironmentObject private var audioEngine: AudioEngineFacade
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
    @State private var greetingTask: Task<Void, Never>?

    // UI state
    @State private var loadPhase = HomeLoadPhase()
    @State private var hasLoadedOnce = false
    @State private var loadPresentation = HomeLoadPresentationState()
    @State private var loadRequestGate = HomeLoadRequestGate()
    @State private var refreshTask: Task<Void, Never>?
    @State private var selectedArtist: Artist?
    @State private var selectedAlbum: Album?
    @State private var selectedGenre: GenreSelection?

    private let logger = Log.logger(.presentation)

    var body: some View {
        NavigationStack {
            Group {
                if loadPhase.blocksHomeContent {
                    ProgressView("Loading your music...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if let loadFailure = loadPresentation.failure,
                          loadFailure.context == .initial {
                    HomeLoadFailureView(failure: loadFailure) {
                        retryLoad()
                    }
                } else if isEmpty {
                    EmptyHomeView()
                } else {
                    contentView
                }
            }
            .navigationTitle("Home")
            .safeAreaInset(edge: .top) {
                if let loadFailure = loadPresentation.failure,
                   loadFailure.context == .refresh,
                   !isEmpty {
                    HomeRefreshFailureBanner(
                        failure: loadFailure,
                        onRetry: retryLoad,
                        onDismiss: dismissLoadFailure
                    )
                }
            }
            .task {
                guard !hasLoadedOnce else { return }
                await loadData(showLoading: true)
                hasLoadedOnce = true
            }
            .onAppear {
                guard hasLoadedOnce else { return }
                refreshTask?.cancel()
                refreshTask = Task {
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
            .sheet(item: $selectedGenre) { selection in
                GenreTracksView(genre: selection.name)
            }
        }
        .onDisappear {
            refreshTask?.cancel()
            refreshTask = nil
            greetingTask?.cancel()
            greetingTask = nil
            loadRequestGate.invalidate()
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
                        selectedGenre = GenreSelection(name: genre)
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
                        CarouselView(tracks: recentlyPlayed, onTrackTap: playTrack)
                    }
                }

                // Most Listened (if user has history)
                if !mostListened.isEmpty {
                    HomeSection(title: "Most Listened") {
                        CarouselView(tracks: mostListened, onTrackTap: playTrack)
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
        let request = loadRequestGate.begin()
        let hasContent = !isEmpty

        loadPhase.beginLibraryLoad(showLoading: showLoading)
        loadPresentation.beginRequest()

        defer {
            if loadRequestGate.isCurrent(request) {
                loadPhase.finishLibraryLoad()
            }
        }

        guard let dataManager else {
            if loadRequestGate.isCurrent(request) {
                loadPresentation.recordFailure(hasContent: hasContent)
            }
            return
        }

        do {
            // Fresh library data
            let loadedRecentlyAdded = try await dataManager.getRecentlyAddedTracks(limit: 10)
            let loadedArtists = try await dataManager.getAllArtists(limit: 15)
            let loadedGenres = try await dataManager.getUniqueGenres()
            let loadedAlbums = try await dataManager.getAllAlbums(limit: 10)

            // Active library data
            let loadedRecentlyPlayed = try await dataManager.getRecentlyPlayedTracks(limit: 10)
            let loadedMostListened = try await dataManager.getMostListenedTracks(limit: 10)
            let loadedFavoriteAlbums = try await dataManager.getFavoriteAlbums(limit: 10)

            // History-based sections
            let loadedContinueListening = try await dataManager.getContinueListeningTracks(limit: 3)
            let loadedRediscoverTracks = try await dataManager.getRediscoverTracks(limit: 10)

            guard !Task.isCancelled, loadRequestGate.isCurrent(request) else { return }

            recentlyAdded = loadedRecentlyAdded
            artists = loadedArtists
            genres = loadedGenres
            albums = loadedAlbums
            recentlyPlayed = loadedRecentlyPlayed
            mostListened = loadedMostListened
            favoriteAlbums = loadedFavoriteAlbums
            continueListening = loadedContinueListening
            rediscoverTracks = loadedRediscoverTracks

            scheduleGreetingLoad(
                request: request,
                recentlyPlayed: loadedRecentlyPlayed,
                genres: loadedGenres,
                dataManager: dataManager
            )

            // Pre-cache visible album artwork colors for smoother overlay theming work.
            let albumsToPrewarm = Array((loadedAlbums + loadedFavoriteAlbums).prefix(12))
            Task(priority: .utility) {
                await DominantColorService.shared.prewarmColorCache(for: albumsToPrewarm)
            }
        } catch is CancellationError {
            return
        } catch {
            logger.error("Home library load failed: \(error.localizedDescription, privacy: .private)")
            guard loadRequestGate.isCurrent(request) else { return }
            loadPresentation.recordFailure(hasContent: hasContent)
        }
    }

    private func scheduleGreetingLoad(
        request: UInt,
        recentlyPlayed: [Track],
        genres: [String],
        dataManager: DataManager
    ) {
        greetingTask?.cancel()
        greetingTask = nil

        guard !recentlyPlayed.isEmpty else {
            timeBasedGreeting = nil
            greetingTracks = []
            loadPhase.finishGreetingLoad()
            return
        }

        loadPhase.beginGreetingLoad()
        greetingTask = Task { @MainActor in
            defer {
                if loadRequestGate.isCurrent(request) {
                    loadPhase.finishGreetingLoad()
                }
            }

            do {
                let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
                let trackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)
                let greeting = try await recommendationService.generateTimeBasedGreeting(
                    sessions: sessions,
                    availableTrackIDs: trackIDs,
                    genres: genres
                )
                try Task.checkCancellation()
                let tracks = try dataManager.fetchTracks(by: greeting.trackIDs)
                guard loadRequestGate.isCurrent(request) else { return }
                timeBasedGreeting = greeting
                greetingTracks = tracks
            } catch is CancellationError {
                return
            } catch {
                logger.error(
                    "Home greeting load failed: \(error.localizedDescription, privacy: .private)"
                )
            }
        }
    }

    private func shuffleAll() {
        Task {
            do {
                try await playShuffledLibrary()
            } catch {
                logger.error("Shuffle All failed: \(error.localizedDescription, privacy: .private)")
                audioEngine.reportPlaybackControlError(error)
            }
        }
    }

    private func surpriseMe() {
        guard surpriseMeRequestGate.begin() else { return }

        Task {
            defer { surpriseMeRequestGate.finish() }

            let tracks: [Track]
            do {
                guard let dataManager else {
                    throw HomeActionError.libraryUnavailable
                }

                // Gather context
                let sessions = try await dataManager.trackDataActor.getListeningSessions(limit: 50)
                let trackIDs = try await dataManager.trackDataActor.getAllTrackIDs(limit: 200)

                // Generate surprise mix
                let result = try await recommendationService.generateSurpriseMix(
                    sessions: sessions,
                    availableTrackIDs: trackIDs,
                    genres: genres
                )

                // Fetch actual tracks from IDs using mainContext
                tracks = try dataManager.fetchTracks(by: result.trackIDs)
            } catch {
                await playSurpriseFallback(after: error)
                return
            }

            guard let firstTrack = tracks.first else {
                await playSurpriseFallback(after: nil)
                return
            }

            do {
                let audioTracks = tracks.map { $0.toAudioTrack() }
                audioEngine.queueManager.replaceQueue(with: audioTracks, startIndex: 0)
                try await audioEngine.play(track: firstTrack)
                showingNowPlaying.wrappedValue = true
            } catch {
                await playSurpriseFallback(after: error)
            }
        }
    }

    private func playSurpriseFallback(after surpriseError: Error?) async {
        if let surpriseError {
            logger.error(
                "Surprise Me failed; trying Shuffle All: \(surpriseError.localizedDescription, privacy: .private)"
            )
        } else {
            logger.info("Surprise Me resolved no tracks; trying Shuffle All")
        }

        do {
            try await playShuffledLibrary()
        } catch {
            logger.error(
                "Surprise Me fallback failed: \(error.localizedDescription, privacy: .private)"
            )
            audioEngine.reportPlaybackControlError(error)
        }
    }

    private func playShuffledLibrary() async throws {
        guard let dataManager else {
            throw HomeActionError.libraryUnavailable
        }

        let allTracks = try await dataManager.getRecentlyAddedTracks(limit: 1000)
        let shuffledTracks = allTracks.shuffled()
        guard let firstTrack = shuffledTracks.first else {
            throw HomeActionError.noPlayableTracks
        }

        audioEngine.queueManager.replaceQueue(
            with: shuffledTracks.map { $0.toAudioTrack() },
            startIndex: 0
        )
        try await audioEngine.play(track: firstTrack)
        showingNowPlaying.wrappedValue = true
    }

    private func playTrack(_ track: Track) {
        Task {
            do {
                try await audioEngine.play(track: track)
                showingNowPlaying.wrappedValue = true
            } catch {
                logger.error("Home track playback failed: \(error.localizedDescription, privacy: .private)")
                audioEngine.reportPlaybackControlError(error)
            }
        }
    }

    private func retryLoad() {
        refreshTask?.cancel()
        refreshTask = Task {
            await loadData(showLoading: isEmpty)
        }
    }

    private func dismissLoadFailure() {
        loadPresentation.clearFailure()
    }
}

private struct GenreSelection: Identifiable {
    let name: String

    var id: String {
        name
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

private struct HomeLoadFailureView: View {
    let failure: HomeLoadFailure
    let onRetry: () -> Void

    var body: some View {
        ContentUnavailableView {
            Label(failure.title, systemImage: "exclamationmark.triangle")
        } description: {
            Text(failure.message)
        } actions: {
            Button("Try Again", action: onRetry)
                .buttonStyle(.borderedProminent)
        }
        .accessibilityIdentifier("HomeLoadError")
    }
}

private struct HomeRefreshFailureBanner: View {
    let failure: HomeLoadFailure
    let onRetry: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.small) {
            Label(failure.title, systemImage: "exclamationmark.triangle")
                .font(.headline)

            Text(failure.message)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: DesignTokens.Spacing.small) {
                Button("Try Again", action: onRetry)
                    .buttonStyle(.borderedProminent)
                    .frame(minHeight: 44)

                Button("Dismiss", action: onDismiss)
                    .buttonStyle(.bordered)
                    .frame(minHeight: 44)
            }
        }
        .padding(DesignTokens.Spacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassSurface(style: .standard, cornerRadius: DesignTokens.CornerRadius.medium)
        .padding(.horizontal)
        .padding(.top, DesignTokens.Spacing.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("HomeRefreshError")
    }
}

private struct CarouselView: View {
    let tracks: [Track]
    let onTrackTap: (Track) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.medium) {
                ForEach(tracks) { track in
                    Button { onTrackTap(track) } label: {
                        TrackCardView(track: track)
                    }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Play \(track.title) by \(track.artist)")
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
        .audioEngine(AudioEngineFacade())
}
