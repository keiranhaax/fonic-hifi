//
//  ExpandableAlbumCard.swift
//  Fonic HiFi
//
//  Album card that supports glass morphing for Home screen expansion
//

import SwiftUI

@MainActor
struct ExpandableAlbumCard: View {
    let album: Album
    let namespace: Namespace.ID
    let isExpanded: Bool
    let onTap: () -> Void

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
        .glassEffect()
        .glassEffectID(album.id, in: namespace)
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    ExpandableAlbumCard(
        album: Album(title: "Sample Album", albumArtist: "Sample Artist"),
        namespace: namespace,
        isExpanded: false,
        onTap: {}
    )
}
