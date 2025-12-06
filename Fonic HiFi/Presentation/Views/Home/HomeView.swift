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
    @Environment(\.showingNowPlaying) private var showingNowPlaying

    @State private var recentlyPlayed: [Track] = []
    @State private var mostListened: [Track] = []
    @State private var favoriteAlbums: [Album] = []
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView("Loading your music...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if recentlyPlayed.isEmpty, mostListened.isEmpty, favoriteAlbums.isEmpty {
                    EmptyHomeView()
                } else {
                    ScrollView {
                        VStack(spacing: 32) {
                            if !recentlyPlayed.isEmpty {
                                HomeSection(title: "Recently Played") {
                                    CarouselView(tracks: recentlyPlayed)
                                }
                            }

                            if !mostListened.isEmpty {
                                HomeSection(title: "Most Listened") {
                                    CarouselView(tracks: mostListened)
                                }
                            }

                            if !favoriteAlbums.isEmpty {
                                HomeSection(title: "Favorite Albums") {
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 16) {
                                            ForEach(favoriteAlbums) { album in
                                                AlbumCardView(album: album)
                                            }
                                        }
                                        .padding(.horizontal)
                                    }
                                }
                            }
                        }
                        .padding(.vertical)
                    }
                }
            }
            .navigationTitle("Home")
            .task {
                await loadData()
            }
        }
    }

    private func loadData() async {
        isLoading = true

        guard let dataManager else {
            isLoading = false
            return
        }

        do {
            recentlyPlayed = try await dataManager.getRecentlyPlayedTracks(limit: 10)
            mostListened = try await dataManager.getMostListenedTracks(limit: 10)
            favoriteAlbums = try await dataManager.getFavoriteAlbums(limit: 10)
        } catch {
            // Silently handle errors - home screen shows empty state gracefully
        }

        isLoading = false
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
