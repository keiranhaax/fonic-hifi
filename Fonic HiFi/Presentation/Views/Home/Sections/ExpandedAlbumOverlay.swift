//
//  ExpandedAlbumOverlay.swift
//  Fonic HiFi
//
//  Expanded album view with track list, shown when album card is tapped on Home
//

import SwiftData
import SwiftUI

@MainActor
struct ExpandedAlbumOverlay: View {
    let album: Album
    let namespace: Namespace.ID
    let accentColor: Color
    let onTrackTap: (Track) -> Void
    let onDismiss: () -> Void

    @Query private var tracks: [Track]

    init(
        album: Album,
        namespace: Namespace.ID,
        accentColor: Color,
        onTrackTap: @escaping (Track) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.album = album
        self.namespace = namespace
        self.accentColor = accentColor
        self.onTrackTap = onTrackTap
        self.onDismiss = onDismiss

        // Filter tracks by album
        let albumTitle = album.title
        let albumArtist = album.albumArtist
        _tracks = Query(
            filter: #Predicate<Track> { track in
                track.album == albumTitle && track.albumArtist == albumArtist
            },
            sort: [
                SortDescriptor(\Track.discNumber),
                SortDescriptor(\Track.trackNumber)
            ]
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with artwork and album info
            headerView

            // Track list
            trackListView
        }
        .frame(maxWidth: 360)
        .glassEffect(.regular.tint(accentColor))
        .glassEffectID(album.id, in: namespace)
        .glassEffectTransition(.matchedGeometry)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.3), radius: 30, y: 10)
        .onTapGesture {
            // Tap outside track list dismisses
        }
    }

    private var headerView: some View {
        HStack(spacing: 16) {
            LazyArtworkView(album: album, size: 80, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(album.title)
                    .font(.headline)
                    .lineLimit(2)

                Text(album.albumArtist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                if let year = album.year {
                    Text(String(year))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
    }

    private var trackListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(tracks) { track in
                    OverlayTrackRowView(track: track) {
                        onTrackTap(track)
                    }

                    if track.id != tracks.last?.id {
                        Divider()
                            .padding(.leading, 52)
                    }
                }
            }
        }
        .frame(maxHeight: 300)
    }
}

private struct OverlayTrackRowView: View {
    let track: Track
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("\(track.trackNumber ?? 0)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body)
                        .lineLimit(1)

                    if track.artist != track.albumArtist {
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(track.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    @Previewable @Namespace var namespace
    ExpandedAlbumOverlay(
        album: Album(title: "Sample Album", albumArtist: "Sample Artist", year: 2024),
        namespace: namespace,
        accentColor: .blue,
        onTrackTap: { _ in },
        onDismiss: {}
    )
}
