//
//  TrackRowView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import OSLog
import SwiftUI

/// Individual track row component used in track lists
@MainActor
struct TrackRowView: View {
    let track: Track
    @EnvironmentObject private var audioService: AudioEngineFacade
    @Environment(\.showingNowPlaying) private var showingNowPlaying
    @Environment(\.themePalette) private var theme

    private let logger = Log.logger(.library)

    private var isCurrentlyPlaying: Bool {
        audioService.currentTrack?.id == track.id
    }

    private var availabilityPresentation: TrackRowAvailabilityPresentation {
        TrackRowAvailabilityPresentation(availability: track.fileAvailability)
    }

    var body: some View {
        Button(action: playTrack) {
            HStack(spacing: 12) {
                // Track number or playing indicator
                ZStack {
                    if let unavailableSymbol = availabilityPresentation.systemImage {
                        Image(systemName: unavailableSymbol)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if isCurrentlyPlaying, audioService.isPlaying {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.caption)
                            .foregroundColor(theme.accent)
                    } else {
                        Text("\(track.trackNumber ?? 0)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(width: 24)

                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body)
                        .lineLimit(1)

                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)

                    if let statusText = availabilityPresentation.statusText {
                        Text(statusText)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                // Duration
                Text(formatDuration(track.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
            .contentShape(Rectangle())
            .background(isCurrentlyPlaying ? theme.subtle : Color.clear)
        }
        .buttonStyle(.plain)
        .disabled(!availabilityPresentation.isPlaybackEnabled)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(availabilityPresentation.accessibilityLabel(
            title: track.title,
            artist: track.artist
        ))
        .accessibilityHint(availabilityPresentation.accessibilityHint)
        .opacity(audioService.isReady && availabilityPresentation.isPlaybackEnabled ? 1.0 : 0.6)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    @MainActor
    private func playTrack() {
        guard availabilityPresentation.isPlaybackEnabled else {
            logger.info("Unavailable track selection ignored")
            return
        }

        // Diagnostic logging for debugging controls issue
        let serviceID = String(describing: ObjectIdentifier(audioService))
        logger.info("""
            Track selected for playback
            - audioService ID: \(serviceID, privacy: .private(mask: .hash))
            - isReady: \(audioService.isReady, privacy: .public)
            - isPlaying: \(audioService.isPlaying, privacy: .public)
            """)

        audioService.setCurrentTrack(track)
        showingNowPlaying.wrappedValue = true

        Task {
            do {
                try await audioService.play(track: track)
                logger.info("play(track:) succeeded")
            } catch {
                logger.error("play(track:) FAILED: \(error.localizedDescription, privacy: .private)")
                // Clear broken state so user isn't left in non-functional UI
                audioService.setCurrentTrack(nil)
                showingNowPlaying.wrappedValue = false
            }
        }
    }
}

struct TrackRowAvailabilityPresentation: Equatable {
    let isPlaybackEnabled: Bool
    let statusText: String?
    let systemImage: String?
    let accessibilityHint: String

    init(availability: TrackFileAvailability) {
        switch availability {
        case .available:
            isPlaybackEnabled = true
            statusText = nil
            systemImage = nil
            accessibilityHint = "Plays this track"
        case .temporarilyUnavailable:
            isPlaybackEnabled = false
            statusText = "File unavailable"
            systemImage = "exclamationmark.triangle"
            accessibilityHint = "The file is temporarily unavailable. Fonic HiFi will check again later."
        }
    }

    func accessibilityLabel(title: String, artist: String) -> String {
        if isPlaybackEnabled {
            "Play \(title) by \(artist)"
        } else {
            "Unavailable: \(title) by \(artist)"
        }
    }
}

private func makePreviewTrack() -> Track {
    let track = Track(
        url: URL(fileURLWithPath: "/Music/Electronic/SynthwaveArtist/electric_dreams.mp3"),
        title: "Electric Dreams",
        artist: "Synthwave Artist",
        album: "Neon Nights",
        audioFormat: "MP3",
        duration: 245.0,
        sampleRate: 48000,
        bitDepth: 24,
        channels: 2,
        isLossless: false,
    )
    track.trackNumber = 3
    return track
}

#Preview {
    TrackRowView(track: makePreviewTrack())
        .audioEngine(AudioEngineFacade())
}
