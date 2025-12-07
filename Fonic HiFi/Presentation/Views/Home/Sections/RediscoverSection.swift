// Fonic HiFi/Presentation/Views/Home/Sections/RediscoverSection.swift
import SwiftUI

/// Displays neglected tracks the user might want to rediscover
@MainActor
struct RediscoverSection: View {
    let tracks: [Track]
    let onPlay: (Track) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Rediscover")
                    .font(.title2.bold())

                Text("You haven't played these in a while")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 16) {
                    ForEach(tracks) { track in
                        RediscoverCard(track: track) {
                            onPlay(track)
                        }
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

/// Card for a rediscover track
private struct RediscoverCard: View {
    let track: Track
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 8) {
                LazyArtworkView(track: track, size: 120, cornerRadius: 12)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                .frame(width: 120, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    RediscoverSection(
        tracks: [],
        onPlay: { _ in }
    )
}
