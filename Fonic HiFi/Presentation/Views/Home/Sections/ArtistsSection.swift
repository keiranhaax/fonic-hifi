//
//  ArtistsSection.swift
//  Fonic HiFi
//
//  Horizontal scrolling artist avatars section
//

import SwiftUI

@MainActor
struct ArtistsSection: View {
    let artists: [Artist]
    let onArtistTap: (Artist) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Your Artists")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(artists) { artist in
                        Button { onArtistTap(artist) } label: {
                            ArtistAvatarView(artist: artist)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Open artist \(artist.name)")
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct ArtistAvatarView: View {
    let artist: Artist

    var body: some View {
        VStack(spacing: 8) {
            artistImage
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .overlay {
                    Circle()
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                }

            Text(artist.name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 80)
        }
    }

    @ViewBuilder
    private var artistImage: some View {
        if let artworkData = artist.artwork,
           let uiImage = UIImage(data: artworkData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
        } else if let firstAlbum = artist.albums.first {
            LazyArtworkView(albumId: firstAlbum.id, size: 80, cornerRadius: 40, placeholderIcon: "music.mic")
        } else {
            Circle()
                .fill(.ultraThinMaterial)
                .overlay {
                    Image(systemName: "music.mic")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
        }
    }
}

#Preview {
    ArtistsSection(
        artists: [],
        onArtistTap: { _ in }
    )
}
