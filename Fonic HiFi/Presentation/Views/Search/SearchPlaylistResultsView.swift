//
//  SearchPlaylistResultsView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftUI

/// Dedicated view for displaying playlist search results
/// This avoids double-filtering issues that can occur with PlaylistListView
struct SearchPlaylistResultsView: View {
    let playlists: [Playlist] // Pre-filtered, no internal filtering

    var body: some View {
        List(playlists) { playlist in
            NavigationLink(value: playlist) {
                SearchPlaylistRow(playlist: playlist)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            }
        }
        .listStyle(.plain)
        .navigationDestination(for: Playlist.self) { playlist in
            PlaylistDetailView(playlist: playlist)
        }
    }
}

/// Individual playlist row for search results
private struct SearchPlaylistRow: View {
    let playlist: Playlist

    var body: some View {
        HStack(spacing: 12) {
            // Playlist icon
            Image(systemName: playlist.systemIcon ?? "music.note.list")
                .font(.title2)
                .foregroundStyle(.tint)
                .frame(width: 44, height: 44)
                .background(.tint.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.headline)
                    .foregroundStyle(.primary)

                HStack(spacing: 8) {
                    if let description = playlist.playlistDescription {
                        Text(description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Text("\(playlist.trackCount) tracks")
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if playlist.isSmart {
                        Label("Smart", systemImage: "sparkles")
                            .font(.caption2)
                            .foregroundStyle(.tint)
                    }
                }
            }

            Spacer()

            // Favorite indicator
            if playlist.isFavorite {
                Image(systemName: "heart.fill")
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            // Chevron
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .contentShape(Rectangle())
    }
}
