//
//  AlbumsSection.swift
//  Fonic HiFi
//
//  Horizontal scrolling albums carousel with glass morph support
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
                        ExpandableAlbumCard(
                            album: album,
                            onTap: { onAlbumTap(album) }
                        )
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

#Preview {
    AlbumsSection(
        title: "Albums",
        albums: [],
        onAlbumTap: { _ in }
    )
}
