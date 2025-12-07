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
                        ArtistAvatarView(artist: artist)
                            .onTapGesture {
                                onArtistTap(artist)
                            }
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
            Group {
                if let artworkData = artist.artwork,
                   let uiImage = UIImage(data: artworkData) {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "music.mic")
                        .font(.title)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color(.systemGray5))
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())

            Text(artist.name)
                .font(.caption)
                .lineLimit(1)
                .frame(width: 80)
        }
    }
}

#Preview {
    ArtistsSection(
        artists: [],
        onArtistTap: { _ in }
    )
}
