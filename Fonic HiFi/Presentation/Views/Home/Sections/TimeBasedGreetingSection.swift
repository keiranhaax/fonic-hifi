// Fonic HiFi/Presentation/Views/Home/Sections/TimeBasedGreetingSection.swift
import SwiftUI

/// Displays AI-generated time-based greeting with track recommendations
@MainActor
struct TimeBasedGreetingSection: View {
    let greeting: TimeBasedGreeting
    let tracks: [Track]
    let onTrackTap: (Track) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Greeting header
            VStack(alignment: .leading, spacing: 4) {
                Text(greeting.greeting)
                    .font(.largeTitle.bold())

                Text(greeting.moodDescription)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            // Track carousel
            if !tracks.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 16) {
                        ForEach(tracks) { track in
                            Button { onTrackTap(track) } label: {
                                GreetingTrackCard(track: track)
                            }
                            .buttonStyle(.plain)
                            .accessibilityElement(children: .combine)
                            .accessibilityLabel("Play \(track.title) by \(track.artist)")
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
    }
}

private struct GreetingTrackCard: View {
    let track: Track

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            LazyArtworkView(track: track, size: 140, cornerRadius: 12)

            Text(track.title)
                .font(.callout.bold())
                .lineLimit(1)

            Text(track.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(width: 140)
    }
}

#Preview {
    TimeBasedGreetingSection(
        greeting: TimeBasedGreeting(
            greeting: "Good Morning",
            trackIDs: [],
            moodDescription: "Start your day with energy"
        ),
        tracks: [],
        onTrackTap: { _ in }
    )
}
