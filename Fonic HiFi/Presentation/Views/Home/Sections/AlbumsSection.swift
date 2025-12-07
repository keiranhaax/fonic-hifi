//
//  AlbumsSection.swift
//  Fonic HiFi
//
//  Horizontal scrolling albums carousel section
//

import SwiftUI

@MainActor
struct AlbumsSection: View {
    let title: String
    let albums: [Album]
    let onAlbumTap: (Album) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(albums) { album in
                        HomeAlbumCardView(album: album)
                            .onTapGesture {
                                onAlbumTap(album)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct HomeAlbumCardView: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyArtworkView(album: album, size: 140, cornerRadius: 8)

            Text(album.title)
                .font(.callout.bold())
                .lineLimit(1)

            Text(album.albumArtist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}

#Preview {
    AlbumsSection(
        title: "Albums",
        albums: [],
        onAlbumTap: { _ in }
    )
}
