//
//  LiquidGlassMiniPlayer.swift
//  Fonic HiFi
//
//  Simplified mini player matching Apple Music's clean approach
//

import OSLog
import SwiftUI

/// Simplified Mini Player matching Apple Music's design
/// Compact layout with artwork, title/artist, and playback controls
@MainActor
struct LiquidGlassMiniPlayer: View {
    struct AccessoryPresentation: Equatable {
        let isInline: Bool

        var showsArtwork: Bool { !isInline }
        var showsArtist: Bool { !isInline }
        var showsNextButton: Bool { !isInline }
        var horizontalSpacing: CGFloat { isInline ? 8 : 15 }
        var infoSpacing: CGFloat { isInline ? 6 : 12 }
        var horizontalPadding: CGFloat { isInline ? 8 : 15 }
    }

    private let logger = Log.logger(.nowPlaying)
    @EnvironmentObject private var audioService: AudioEngineFacade
    @Environment(\.tabViewBottomAccessoryPlacement) private var accessoryPlacement

    let namespace: Namespace.ID
    let onOpen: () -> Void

    static func accessoryPresentation(
        for placement: TabViewBottomAccessoryPlacement?
    ) -> AccessoryPresentation {
        AccessoryPresentation(isInline: placement == .inline)
    }

    private var presentation: AccessoryPresentation {
        Self.accessoryPresentation(for: accessoryPlacement)
    }

    var body: some View {
        HStack(spacing: presentation.horizontalSpacing) {
            Button(action: onOpen) {
                playerInfo
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Open Now Playing")
            .accessibilityValue(nowPlayingAccessibilityValue)

            Spacer(minLength: 0)

            playPauseButton
                .padding(.trailing, presentation.isInline ? 0 : 10)

            if presentation.showsNextButton {
                nextButton
            }
        }
        .contentShape(.rect)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("MiniPlayer")
        .foregroundStyle(Color.primary)
        .padding(.horizontal, presentation.horizontalPadding)
    }

    // MARK: - Player Info

    private var playerInfo: some View {
        HStack(spacing: presentation.infoSpacing) {
            if presentation.showsArtwork {
                MorphableArtwork(size: 30, namespace: namespace)
            }

            VStack(alignment: .leading, spacing: presentation.isInline ? 0 : 6) {
                Text(audioService.currentTrack?.title ?? "Not Playing")
                    .font(.callout)
                    .lineLimit(1)

                if presentation.showsArtist {
                    Text(audioService.currentTrack?.artist ?? "No Artist")
                        .font(.caption2)
                        .foregroundStyle(.gray)
                        .lineLimit(1)
                }
            }
        }
    }

    private var nowPlayingAccessibilityValue: String {
        guard let track = audioService.currentTrack else { return "Not playing" }
        return "\(track.title), \(track.artist)"
    }

    // MARK: - Controls

    private var playPauseButton: some View {
        Button(action: togglePlayPause) {
            Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                .contentShape(.rect)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(audioService.currentTrack == nil)
        .opacity(audioService.currentTrack == nil ? 0.4 : 1.0)
        .accessibilityLabel(audioService.isPlaying ? "Pause" : "Play")
    }

    private var nextButton: some View {
        Button(action: playNext) {
            Image(systemName: "forward.fill")
                .contentShape(.rect)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .disabled(audioService.currentTrack == nil)
        .opacity(audioService.currentTrack == nil ? 0.4 : 1.0)
        .accessibilityLabel("Next Track")
    }

    // MARK: - Actions

    private func togglePlayPause() {
        Task { @MainActor in
            do {
                if audioService.isPlaying {
                    await audioService.pause()
                } else {
                    try await audioService.resume()
                }

                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred(intensity: 1.0)
            } catch {
                logger.error("Mini player toggle failed: \(error.localizedDescription, privacy: .private)")
                audioService.reportPlaybackControlError(error)
            }
        }
    }

    private func playNext() {
        Task { @MainActor in
            do {
                try await audioService.playNext()

                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred(intensity: 0.8)
            } catch {
                logger.error("Mini player next-track failed: \(error.localizedDescription, privacy: .private)")
                audioService.reportPlaybackControlError(error)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Namespace var namespace
    @Previewable @State var audioService = AudioEngineFacade()

    VStack {
        Spacer()
        LiquidGlassMiniPlayer(namespace: namespace, onOpen: {})
            .audioEngine(audioService)
            .padding()
    }
    .background(Color.black)
    .preferredColorScheme(.dark)
}
