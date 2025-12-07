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
    let expandedAlbumID: UUID?
    let namespace: Namespace.ID
    let onAlbumTap: (Album) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                GlassEffectContainer {
                    HStack(spacing: 16) {
                        ForEach(albums) { album in
                            ExpandableAlbumCard(
                                album: album,
                                namespace: namespace,
                                isExpanded: expandedAlbumID == album.id,
                                onTap: { onAlbumTap(album) }
                            )
                            .opacity(shouldHideCard(for: album) ? 0 : 1)
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }

    private func shouldHideCard(for album: Album) -> Bool {
        expandedAlbumID == album.id
    }
}

#Preview {
    @Previewable @Namespace var namespace
    AlbumsSection(
        title: "Albums",
        albums: [],
        expandedAlbumID: nil,
        namespace: namespace,
        onAlbumTap: { _ in }
    )
}
