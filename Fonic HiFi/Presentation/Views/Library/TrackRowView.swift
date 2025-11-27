//
//  TrackRowView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import SwiftUI

/// Individual track row component used in track lists
@MainActor
struct TrackRowView: View {
    let track: Track
    @Environment(\.audioEngine) private var audioService
    @Environment(\.showingNowPlaying) private var showingNowPlaying

    private let logger = Log.logger(.library)

    var body: some View {
        HStack(spacing: 12) {
            // Track number or playing indicator
            ZStack {
                if audioService?.currentTrack?.id == track.id, audioService?.isPlaying == true {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
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
            }

            Spacer()

            // Duration
            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            playTrack()
        }
        .opacity(audioService?.isReady == true ? 1.0 : 0.6) // Visual feedback for initialization state
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    @MainActor
    private func playTrack() {
        guard let audioService else {
            logger.error("playTrack: audioService is nil")
            return
        }

        // Diagnostic logging for debugging controls issue
        let serviceID = String(describing: ObjectIdentifier(audioService))
        logger.info("""
            Track tapped: \(track.title, privacy: .public)
            - audioService ID: \(serviceID, privacy: .public)
            - isReady: \(audioService.isReady)
            - isPlaying: \(audioService.isPlaying)
            """)

        audioService.setCurrentTrack(track)
        showingNowPlaying.wrappedValue = true

        Task {
            do {
                try await audioService.play(track: track)
                logger.info("play(track:) succeeded for \(track.title, privacy: .public)")
            } catch {
                logger.error("play(track:) FAILED: \(error.localizedDescription, privacy: .public)")
                // Clear broken state so user isn't left in non-functional UI
                audioService.setCurrentTrack(nil)
                showingNowPlaying.wrappedValue = false
            }
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
