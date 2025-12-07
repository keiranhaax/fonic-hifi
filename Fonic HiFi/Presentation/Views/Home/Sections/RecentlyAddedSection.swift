//
//  RecentlyAddedSection.swift
//  Fonic HiFi
//
//  Hero section showing recently added tracks with large artwork
//

import SwiftUI

@MainActor
struct RecentlyAddedSection: View {
    let tracks: [Track]
    let onTrackTap: (Track) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recently Added")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 16) {
                    ForEach(tracks) { track in
                        RecentlyAddedCardView(track: track)
                            .onTapGesture {
                                onTrackTap(track)
                            }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct RecentlyAddedCardView: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyArtworkView(track: track, size: 160, cornerRadius: 12)

            Text(track.title)
                .font(.callout.bold())
                .lineLimit(1)

            Text(track.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 160)
    }
}

#Preview {
    RecentlyAddedSection(
        tracks: [],
        onTrackTap: { _ in }
    )
}
