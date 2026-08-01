//
//  LibraryView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Combine
import OSLog
import SwiftUI

@MainActor
struct LibraryView: View {
    enum LibraryTab: String, CaseIterable {
        case tracks = "Tracks"
        case albums = "Albums"
        case artists = "Artists"
        case playlists = "Playlists"

        var icon: String {
            switch self {
            case .tracks: "music.note"
            case .albums: "square.stack"
            case .artists: "person.2"
            case .playlists: "music.note.list"
            }
        }

        var loadingDescription: String {
            switch self {
            case .tracks: "Loading tracks…"
            case .albums: "Loading albums…"
            case .artists: "Loading artists…"
            case .playlists: "Loading playlists…"
            }
        }

        var section: LibraryViewModel.Section {
            switch self {
            case .tracks: .tracks
            case .albums: .albums
            case .artists: .artists
            case .playlists: .playlists
            }
        }
    }

    @StateObject private var viewModel: LibraryViewModel
    @EnvironmentObject private var importService: LibraryImportService
    @EnvironmentObject private var audioEngine: AudioEngineFacade
    @Environment(\.dataManager) private var dataManager
    @Environment(\.showingNowPlaying) private var showingNowPlaying
    @Environment(\.artworkService) private var artworkService
    @Environment(\.themePalette) private var theme

    @State private var selectedTab = LibraryTab.tracks
    @State private var searchText = ""
    @State private var importSheet: ImportSheetDestination?
    @State private var showingCreatePlaylist = false
    @State private var selectedTrack: TrackEntity?
    @State private var selectedAlbum: AlbumEntity?
    @State private var selectedArtist: ArtistEntity?
    @State private var selectedPlaylist: PlaylistEntity?
    @State private var searchTask: Task<Void, Never>?
    @State private var showingErrorAlert = false

    init(viewModel: LibraryViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }

    static func loadingOverlayMessage(
        selectedTab: LibraryTab,
        phase: LibraryViewModel.LoadPhase
    ) -> String? {
        guard phase == .initial else { return nil }
        return selectedTab.loadingDescription
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Library View", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, DesignTokens.Spacing.small)

                ZStack {
                    content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                    if shouldShowEmptyState {
                        EmptyLibraryView {
                            importSheet = .selection
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: primaryToolbarAction) {
                        Image(systemName: selectedTab == .playlists ? "plus" : "plus.circle.fill")
                    }
                }
            }
        }
        .searchable(text: $searchText, prompt: "Search \(selectedTab.rawValue)")
        .sheet(item: $importSheet) { sheet in
            switch sheet {
            case .selection:
                FileImportView()
                    .importService(importService)
            case .progress:
                ImportProgressView()
                    .importService(importService)
                    .interactiveDismissDisabled(importService.isImporting)
            }
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistView { _ in
                Task { @MainActor in
                    await viewModel.refresh(
                        section: .playlists,
                        query: normalized(searchText)
                    )
                }
            }
        }
        .sheet(item: $selectedTrack) { track in
            TrackEntityDetailView(track: track)
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumEntityDetailView(album: album)
        }
        .sheet(item: $selectedArtist) { artist in
            ArtistEntityDetailView(artist: artist)
        }
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistEntityDetailView(playlist: playlist)
        }
        .overlay(alignment: .center) {
            if let loadingMessage {
                LoadingOverlay(message: loadingMessage, isShowing: true)
            }
        }
        .alert(
            "Unable to Load Library",
            isPresented: $showingErrorAlert,
            presenting: viewModel.lastError
        ) { _ in
            Button("Dismiss", role: .cancel) {
                viewModel.resetErrors()
            }
        } message: { error in
            Text(error.errorDescription ?? "An unknown error occurred")
        }
        .onChange(of: importService.isImporting) { _, isImporting in
            importSheet = ImportSheetPresentation.resolve(
                current: importSheet,
                isImporting: isImporting
            )
        }
        .onChange(of: selectedTab) { oldValue, newValue in
            searchTask?.cancel()
            viewModel.cancelRequest(for: oldValue.section)
            Task { @MainActor in
                await refresh(for: newValue)
            }
        }
        .onChange(of: searchText) { _, newValue in
            viewModel.cancelRequest(for: selectedTab.section)
            scheduleSearchRefresh(for: newValue)
        }
        .onReceive(viewModel.$lastError) { error in
            showingErrorAlert = error != nil
        }
        .onReceive(libraryRevisionPublisher) { _ in
            searchTask?.cancel()
            Task { @MainActor in
                await refresh(for: selectedTab, resetExisting: false)
            }
        }
        .task {
            importSheet = ImportSheetPresentation.resolve(
                current: importSheet,
                isImporting: importService.isImporting
            )
            await ensureInitialLoad()
        }
        .onDisappear {
            searchTask?.cancel()
            viewModel.cancelRequest(for: selectedTab.section)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch selectedTab {
        case .tracks:
            tracksSection
        case .albums:
            albumsSection
        case .artists:
            artistsSection
        case .playlists:
            playlistsSection
        }
    }

    private var tracksSection: some View {
        List {
            ForEach(Array(viewModel.tracks.enumerated()), id: \.element.id) { index, track in
                TrackEntityRow(
                    track: track,
                    onPlay: { playTrack(track) },
                    onInfo: { selectedTrack = track }
                )
                .onAppear {
                    loadNextPage(for: .tracks, index: index)
                }
            }

            if viewModel.loadPhase(for: .tracks) == .pagination {
                LoadingListRow()
            }
        }
        .listStyle(.plain)
    }

    private var albumsSection: some View {
        ScrollView {
            LazyVGrid(
                columns: [
                    GridItem(
                        .adaptive(
                            minimum: DesignTokens.Grid.adaptiveMinimum,
                            maximum: DesignTokens.Grid.adaptiveMaximum
                        ),
                        spacing: DesignTokens.Grid.spacing
                    ),
                ],
                spacing: 20
            ) {
                ForEach(Array(viewModel.albums.enumerated()), id: \.element.id) { index, album in
                    Button {
                        selectedAlbum = album
                    } label: {
                        AlbumEntityTile(album: album)
                    }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Open album \(album.title) by \(album.albumArtist)")
                        .onAppear {
                            loadNextPage(for: .albums, index: index)
                        }
                }
            }
            .padding()

            if viewModel.loadPhase(for: .albums) == .pagination {
                ProgressView()
                    .padding(.vertical, DesignTokens.Spacing.xLarge)
            }
        }
    }

    private var artistsSection: some View {
        List {
            ForEach(Array(viewModel.artists.enumerated()), id: \.element.id) { index, artist in
                Button {
                    selectedArtist = artist
                } label: {
                    ArtistEntityRow(artist: artist)
                }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Open artist \(artist.name)")
                    .onAppear {
                        loadNextPage(for: .artists, index: index)
                    }
            }

            if viewModel.loadPhase(for: .artists) == .pagination {
                LoadingListRow()
            }
        }
        .listStyle(.plain)
    }

    private var playlistsSection: some View {
        List {
            ForEach(Array(viewModel.playlists.enumerated()), id: \.element.id) { index, playlist in
                Button {
                    selectedPlaylist = playlist
                } label: {
                    PlaylistEntityRow(playlist: playlist)
                }
                    .buttonStyle(.plain)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("Open playlist \(playlist.name)")
                    .onAppear {
                        loadNextPage(for: .playlists, index: index)
                    }
            }

            if viewModel.loadPhase(for: .playlists) == .pagination {
                LoadingListRow()
            }
        }
        .listStyle(.plain)
    }

    private var shouldShowEmptyState: Bool {
        guard selectedLoadPhase == .idle else { return false }

        switch selectedTab {
        case .tracks: return viewModel.tracks.isEmpty
        case .albums: return viewModel.albums.isEmpty
        case .artists: return viewModel.artists.isEmpty
        case .playlists: return viewModel.playlists.isEmpty
        }
    }

    private var loadingMessage: String? {
        Self.loadingOverlayMessage(
            selectedTab: selectedTab,
            phase: selectedLoadPhase
        )
    }

    private var selectedLoadPhase: LibraryViewModel.LoadPhase {
        viewModel.loadPhase(for: selectedTab.section)
    }

    private var libraryRevisionPublisher: AnyPublisher<UInt64, Never> {
        guard let dataManager else {
            return Empty(completeImmediately: false).eraseToAnyPublisher()
        }
        return dataManager.$libraryRevision
            .dropFirst()
            .eraseToAnyPublisher()
    }

    private func primaryToolbarAction() {
        if selectedTab == .playlists {
            showingCreatePlaylist = true
        } else {
            importSheet = .selection
        }
    }

    private func ensureInitialLoad() async {
        await refresh(for: selectedTab, resetExisting: false)
        await viewModel.ensureStatisticsLoaded()
    }

    private func refresh(for tab: LibraryTab, resetExisting: Bool = true) async {
        let query = normalized(searchText)
        await viewModel.refresh(section: tab.section, query: query)
        if resetExisting {
            selectedTrack = nil
            selectedAlbum = nil
            selectedArtist = nil
            selectedPlaylist = nil
        }
    }

    private func loadNextPage(for section: LibraryViewModel.Section, index: Int) {
        let query = normalized(searchText)
        Task { @MainActor in
            await viewModel.loadNextPageIfNeeded(
                section: section,
                currentItemIndex: index,
                query: query
            )
        }
    }

    private func playTrack(_ track: TrackEntity) {
        Task {
            let artwork = await artworkService?.artwork(for: track.id)
            let playableTrack = track.asTrackRepresentation(artwork: artwork)
            audioEngine.setCurrentTrack(playableTrack)
            showingNowPlaying.wrappedValue = true
            do {
                try await audioEngine.play(track: playableTrack)
            } catch {
                Log.logger(.library).error("Failed to play track: \(error.localizedDescription, privacy: .private)")
            }
        }
    }

    private func scheduleSearchRefresh(for text: String) {
        searchTask?.cancel()
        let tab = selectedTab
        searchTask = Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            await refresh(for: tab)
        }
    }

    private func normalized(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private struct TrackEntityRow: View {
    @Environment(\.locale) private var locale
    let track: TrackEntity
    let onPlay: () -> Void
    let onInfo: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onPlay) {
                HStack(spacing: 12) {
                    LazyArtworkView(trackId: track.id, size: 56, cornerRadius: 8)

                    VStack(alignment: .leading, spacing: 6) {
                        Text(track.title)
                            .font(.headline)
                            .lineLimit(2)

                        Text(verbatim: LocalizedFormatters.artistAlbum(
                            artist: track.artist,
                            album: track.album,
                            locale: locale
                        ))
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)

                        HStack(spacing: 12) {
                            Label(track.qualityDescription, systemImage: "waveform")
                            Label(track.formattedDuration, systemImage: "clock")
                            Label(track.formattedFileSize, systemImage: "internaldrive")
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }

                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Play \(track.title) by \(track.artist)")
            .accessibilityHint("Plays this track")

            Button {
                onInfo()
            } label: {
                Image(systemName: "info.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Track information for \(track.title)")
        }
        .padding(.vertical, 6)
    }
}

private struct AlbumEntityTile: View {
    let album: AlbumEntity

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            GeometryReader { geometry in
                LazyArtworkView(
                    albumTitle: album.title,
                    albumArtist: album.albumArtist,
                    size: geometry.size.width,
                    cornerRadius: 12,
                    placeholderIcon: "square.stack"
                )
                .shadow(radius: 4)
            }
            .aspectRatio(1, contentMode: .fit)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)

                Text(album.albumArtist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let year = album.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct ArtistEntityRow: View {
    @Environment(\.locale) private var locale
    let artist: ArtistEntity

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundStyle(.secondary)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 12) {
                    Label {
                        Text(verbatim: LocalizedFormatters.albumCount(
                            artist.albumCount,
                            locale: locale
                        ))
                    } icon: {
                        Image(systemName: "square.stack")
                    }
                    Label {
                        Text(verbatim: LocalizedFormatters.trackCount(
                            artist.trackCount,
                            locale: locale
                        ))
                    } icon: {
                        Image(systemName: "music.note")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct PlaylistEntityRow: View {
    @Environment(\.locale) private var locale
    let playlist: PlaylistEntity

    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.blue.opacity(0.2))
                .frame(width: 48, height: 48)
                .overlay(
                    Image(systemName: "music.note.list")
                        .foregroundStyle(.blue)
                )

            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.body)
                    .lineLimit(1)

                if let description = playlist.description, !description.isEmpty {
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Text(verbatim: LocalizedFormatters.trackCount(
                    playlist.trackCount,
                    locale: locale
                ))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}

private struct LoadingListRow: View {
    var body: some View {
        HStack {
            Spacer()
            ProgressView()
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

private struct TrackEntityDetailView: View {
    let track: TrackEntity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Spacer()
                        LazyArtworkView(trackId: track.id, size: 200, cornerRadius: 12)
                        Spacer()
                    }
                    .padding(.horizontal, 40)

                    detailSection(title: "Info") {
                        LibraryDetailRow(label: "Title", value: track.title)
                        LibraryDetailRow(label: "Artist", value: track.artist)
                        LibraryDetailRow(label: "Album", value: track.album)
                        if let genre = track.genre {
                        LibraryDetailRow(label: "Genre", value: genre)
                        }
                        if let year = track.year {
                        LibraryDetailRow(label: "Year", value: String(year))
                        }
                    }

                    detailSection(title: "Technical") {
                        LibraryDetailRow(label: "Format", value: track.audioFormat)
                        LibraryDetailRow(label: "Duration", value: track.formattedDuration)
                        LibraryDetailRow(
                            label: "Sample Rate",
                            value: LocalizedFormatters.sampleRate(
                                track.sampleRate,
                                locale: locale
                            )
                        )
                        LibraryDetailRow(label: "Bit Depth", value: "\(track.bitDepth)-bit")
                        LibraryDetailRow(label: "Channels", value: channelDescription)
                        LibraryDetailRow(label: "File Size", value: track.formattedFileSize)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Track Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private func detailSection(title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.headline)
                .padding(.horizontal)
            VStack(spacing: 12) {
                content()
            }
            .padding(.horizontal)
        }
    }

    private var channelDescription: String {
        track.channels == 2 ? "Stereo" : "\(track.channels) channels"
    }
}

private struct AlbumEntityDetailView: View {
    let album: AlbumEntity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                LazyArtworkView(
                    albumTitle: album.title,
                    albumArtist: album.albumArtist,
                    size: 160,
                    cornerRadius: 12,
                    placeholderIcon: "square.stack"
                )
                .padding(.top, 40)

                VStack(spacing: 12) {
                    Text(album.title)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)

                    Text(album.albumArtist)
                        .font(.body)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 12) {
                        Label {
                            Text(verbatim: LocalizedFormatters.trackCount(
                                album.trackCount,
                                locale: locale
                            ))
                        } icon: {
                            Image(systemName: "music.note")
                        }
                        if let year = album.year {
                            Label(String(year), systemImage: "calendar")
                        }
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Album")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct ArtistEntityDetailView: View {
    let artist: ArtistEntity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Circle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 140, height: 140)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                    )
                    .padding(.top, 40)

                Text(artist.name)
                    .font(.title2)
                    .fontWeight(.semibold)

                HStack(spacing: 16) {
                    Label {
                        Text(verbatim: LocalizedFormatters.albumCount(
                            artist.albumCount,
                            locale: locale
                        ))
                    } icon: {
                        Image(systemName: "square.stack")
                    }
                    Label {
                        Text(verbatim: LocalizedFormatters.trackCount(
                            artist.trackCount,
                            locale: locale
                        ))
                    } icon: {
                        Image(systemName: "music.note")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Artist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct PlaylistEntityDetailView: View {
    let playlist: PlaylistEntity
    @Environment(\.dismiss) private var dismiss
    @Environment(\.dataManager) private var dataManager

    var body: some View {
        NavigationStack {
            Group {
                if let trackDataActor = dataManager?.trackDataActor {
                    PlaylistEditorView(
                        playlist: playlist,
                        store: trackDataActor
                    )
                } else {
                    ContentUnavailableView(
                        "Playlist Unavailable",
                        systemImage: "music.note.list",
                        description: Text("Playlist storage is unavailable.")
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct LibraryDetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 110, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .multilineTextAlignment(.leading)
        }
    }
}

/// Empty library state
struct EmptyLibraryView: View {
    let onImport: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundStyle(.secondary)

            Text("Your Library is Empty")
                .font(.title2)
                .fontWeight(.semibold)

            Text("Import music to get started")
                .font(.body)
                .foregroundStyle(.secondary)

            Button("Import Music", systemImage: "square.and.arrow.down", action: onImport)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

/// Loading overlay for long operations
struct LoadingOverlay: View {
    let message: String
    let isShowing: Bool

    var body: some View {
        if isShowing {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()

                VStack(spacing: DesignTokens.Spacing.large) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .scaleEffect(1.5)

                    Text(message)
                        .font(.headline)
                        .foregroundColor(.primary)
                }
                .padding(DesignTokens.Spacing.xLarge)
                .background(Color(UIColor.systemBackground))
                .cornerRadius(DesignTokens.CornerRadius.medium)
                .shadow(radius: 10)
            }
            .transition(.opacity)
            .animation(.easeInOut(duration: DesignTokens.Animation.standardFadeDuration), value: isShowing)
        }
    }
}
