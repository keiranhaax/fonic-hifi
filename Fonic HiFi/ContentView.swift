//
//  ContentView.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.dataManager) private var dataManager
    @Environment(\.importService) private var importService
    @Environment(\.audioEngine) private var audioService
    @Environment(\.libraryRepository) private var libraryRepository
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @ObservedObject private var colorService = DominantColorService.shared
    @AppStorage("artworkThemingEnabled") private var artworkThemingEnabled = true
    @AppStorage("artworkThemingLightMode") private var artworkThemingLightMode = true

    @Namespace private var miniPlayerNamespace
    @State private var showingNowPlaying = false
    @State private var searchText = ""

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
                    .environment(\.showingNowPlaying, $showingNowPlaying)
            }

            Tab("Library", systemImage: "music.note.list") {
                if let repository = libraryRepository {
                    LibraryView(viewModel: LibraryViewModel(repository: repository))
                        .environment(\.showingNowPlaying, $showingNowPlaying)
                } else {
                    LibraryUnavailableView()
                }
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack {
                    SearchView(searchText: $searchText)
                        .searchable(text: $searchText, placement: .toolbar, prompt: Text("Search Library"))
                        .environment(\.showingNowPlaying, $showingNowPlaying)
                        .environment(\.audioEngine, audioService)
                        .environment(\.importService, importService)
                }
            }
        }
        .preferredColorScheme(.dark)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if let audioService {
                LiquidGlassMiniPlayer(
                    namespace: miniPlayerNamespace,
                    onOpen: {
                        showingNowPlaying = true
                        let generator = UIImpactFeedbackGenerator(style: .medium)
                        generator.impactOccurred(intensity: 0.9)
                    }
                )
                    .environment(\.audioEngine, audioService)
                    .matchedTransitionSource(id: "miniplayer", in: miniPlayerNamespace)
            }
        }
        .fullScreenCover(isPresented: $showingNowPlaying) {
            ScrollView {}
                .safeAreaInset(edge: .top, spacing: 0) {
                    NowPlayingContent(
                        namespace: miniPlayerNamespace,
                        dismiss: { showingNowPlaying = false }
                    )
                    .environment(\.audioEngine, audioService)
                    .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.background)
        }
        .environment(\.themePalette, colorService.palette)
        .onChange(of: colorScheme) { _, newScheme in
            colorService.updateColorScheme(newScheme)
        }
        .onChange(of: reduceMotion) { _, enabled in
            colorService.updateReduceMotion(enabled)
        }
        .onChange(of: artworkThemingEnabled) { _, enabled in
            colorService.updateThemingEnabled(enabled)
        }
        .onChange(of: artworkThemingLightMode) { _, enabled in
            colorService.updateLightModeThemingEnabled(enabled)
        }
        .onAppear {
            colorService.updateReduceMotion(reduceMotion)
            colorService.updateColorScheme(colorScheme)
            colorService.updateThemingEnabled(artworkThemingEnabled)
            colorService.updateLightModeThemingEnabled(artworkThemingLightMode)
        }
    }
}

private struct LibraryUnavailableView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 40, weight: .regular))
                .foregroundStyle(.secondary)

            Text("Library Unavailable")
                .font(.headline)

            Text("Fonic HiFi could not access the library repository.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct PreviewLibraryRepository: LibraryRepository {
    func tracks(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<TrackEntity> {
        Page(items: sampleTracks, hasMore: false, nextPage: page + 1, totalCount: sampleTracks.count)
    }

    func albums(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<AlbumEntity> {
        Page(items: sampleAlbums, hasMore: false, nextPage: page + 1, totalCount: sampleAlbums.count)
    }

    func artists(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<ArtistEntity> {
        Page(items: sampleArtists, hasMore: false, nextPage: page + 1, totalCount: sampleArtists.count)
    }

    func playlists(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<PlaylistEntity> {
        Page(items: samplePlaylists, hasMore: false, nextPage: page + 1, totalCount: samplePlaylists.count)
    }

    func recentAdditions(limit: Int) async throws -> [TrackEntity] {
        Array(sampleTracks.prefix(limit))
    }

    func libraryStatistics() async throws -> LibraryStatisticsEntity {
        LibraryStatisticsEntity(
            trackCount: sampleTracks.count,
            albumCount: sampleAlbums.count,
            artistCount: sampleArtists.count,
            playlistCount: samplePlaylists.count,
            totalDuration: sampleTracks.reduce(0) { $0 + $1.duration },
            totalFileSize: sampleTracks.reduce(0) { $0 + $1.fileSize },
            losslessTrackCount: sampleTracks.filter(\.isLossless).count,
            hiResTrackCount: sampleTracks.filter { $0.sampleRate > 48_000 || $0.bitDepth > 16 }.count
        )
    }

    private var sampleTracks: [TrackEntity] {
        [
            TrackEntity(
                id: UUID(),
                title: "Impulse Response",
                artist: "Fonic Ensemble",
                album: "Signal Paths",
                albumArtist: "Fonic Ensemble",
                duration: 245,
                trackNumber: 1,
                discNumber: 1,
                genre: "Electronic",
                year: 2025,
                audioFormat: "FLAC",
                artworkSha: nil,
                fileURL: URL(fileURLWithPath: "/tmp/impulse.flac"),
                fileSize: 28_000_000,
                bitDepth: 24,
                sampleRate: 96_000,
                channels: 2,
                bitrate: nil,
                isLossless: true,
                dateAdded: .now
            ),
        ]
    }

    private var sampleAlbums: [AlbumEntity] {
        [
            AlbumEntity(
                id: UUID(),
                title: "Signal Paths",
                albumArtist: "Fonic Ensemble",
                trackCount: 10,
                artworkSha: nil,
                year: 2025,
                dateAdded: .now
            ),
        ]
    }

    private var sampleArtists: [ArtistEntity] {
        [
            ArtistEntity(
                id: UUID(),
                name: "Fonic Ensemble",
                sortName: "Fonic Ensemble",
                albumCount: 2,
                trackCount: 20
            ),
        ]
    }

    private var samplePlaylists: [PlaylistEntity] {
        [
            PlaylistEntity(
                id: UUID(),
                name: "Reference Mixes",
                description: "Test tracks for system calibration",
                trackCount: 12
            ),
        ]
    }
}

#Preview {
    if let importService = DataManager.makePreviewImportService() {
        ContentView()
            .importService(importService)
            .audioEngine(AudioEngineFacade())
            .libraryRepository(PreviewLibraryRepository())
    } else {
        ContentView()
            .audioEngine(AudioEngineFacade())
            .libraryRepository(PreviewLibraryRepository())
    }
}
