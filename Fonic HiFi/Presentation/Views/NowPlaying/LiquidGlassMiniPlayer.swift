//
//  LiquidGlassMiniPlayer.swift
//  Fonic HiFi
//
//  Simplified mini player matching Apple Music's clean approach
//

import SwiftUI

/// Simplified Mini Player matching Apple Music's design
/// Compact layout with artwork, title/artist, and playback controls
@MainActor
struct LiquidGlassMiniPlayer: View {
    @Environment(\.audioEngine) private var audioService

    let namespace: Namespace.ID

    var body: some View {
        HStack(spacing: 15) {
            playerInfo

            Spacer(minLength: 0)

            playPauseButton
                .padding(.trailing, 10)

            nextButton
        }
        .foregroundStyle(Color.primary)
        .padding(.horizontal, 15)
    }

    // MARK: - Player Info

    private var playerInfo: some View {
        HStack(spacing: 12) {
            MorphableArtwork(size: 30, namespace: namespace)

            VStack(alignment: .leading, spacing: 6) {
                Text(audioService?.currentTrack?.title ?? "Not Playing")
                    .font(.callout)
                    .lineLimit(1)

                Text(audioService?.currentTrack?.artist ?? "No Artist")
                    .font(.caption2)
                    .foregroundStyle(.gray)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Controls

    private var playPauseButton: some View {
        Button(action: togglePlayPause) {
            Image(systemName: audioService?.isPlaying == true ? "pause.fill" : "play.fill")
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(audioService?.currentTrack == nil)
        .opacity(audioService?.currentTrack == nil ? 0.4 : 1.0)
        .accessibilityLabel(audioService?.isPlaying == true ? "Pause" : "Play")
    }

    private var nextButton: some View {
        Button(action: playNext) {
            Image(systemName: "forward.fill")
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(audioService?.currentTrack == nil)
        .opacity(audioService?.currentTrack == nil ? 0.4 : 1.0)
        .accessibilityLabel("Next Track")
    }

    // MARK: - Actions

    private func togglePlayPause() {
        Task {
            if audioService?.isPlaying == true {
                await audioService?.pause()
            } else {
                try? await audioService?.resume()
            }
        }

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 1.0)
    }

    private func playNext() {
        Task {
            try? await audioService?.playNext()
        }

        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred(intensity: 0.8)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Namespace var namespace
    @Previewable @State var audioService = AudioEngineFacade()

    VStack {
        Spacer()
        LiquidGlassMiniPlayer(namespace: namespace)
            .environment(\.audioEngine, audioService)
            .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
