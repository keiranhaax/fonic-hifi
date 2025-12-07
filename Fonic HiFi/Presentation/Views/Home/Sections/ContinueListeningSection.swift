// Fonic HiFi/Presentation/Views/Home/Sections/ContinueListeningSection.swift
import SwiftUI

/// Displays tracks with incomplete listening sessions
@MainActor
struct ContinueListeningSection: View {
    let tracks: [Track]
    let onPlay: (Track) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Continue Listening")
                .font(.title2.bold())
                .padding(.horizontal)

            VStack(spacing: 8) {
                ForEach(tracks.prefix(3)) { track in
                    ContinueListeningRow(track: track) {
                        onPlay(track)
                    }
                }
            }
            .padding(.horizontal)
        }
    }
}

/// Individual row for a continue listening track
private struct ContinueListeningRow: View {
    let track: Track
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                LazyArtworkView(track: track, size: 56, cornerRadius: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "play.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.primary)
            }
            .padding(12)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ContinueListeningSection(
        tracks: [],
        onPlay: { _ in }
    )
}
