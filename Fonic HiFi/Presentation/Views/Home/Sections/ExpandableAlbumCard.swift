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
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyArtworkView(album: album, size: 140, cornerRadius: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.callout.bold())
                    .lineLimit(1)

                Text(album.albumArtist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(height: 34, alignment: .topLeading)
        }
        .frame(width: 140, alignment: .leading)
        .padding(8)
        .contentShape(Rectangle())
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .onTapGesture {
            onTap()
        }
    }
}

#Preview {
    ExpandableAlbumCard(
        album: Album(title: "Sample Album", albumArtist: "Sample Artist"),
        onTap: {}
    )
}
