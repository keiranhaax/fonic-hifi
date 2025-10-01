//
//  LiquidGlassMiniPlayer.swift
//  Fonic HiFi
//
//  iOS 26+ Simplified Liquid Glass Mini Player matching Apple Music's clean approach
//

import SwiftUI

/// iOS 26+ Simplified Liquid Glass Mini Player
/// Compact-only design with matched transition support for morphing
@MainActor
struct LiquidGlassMiniPlayer: View {
    @Environment(\.audioEngine) private var audioService
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let namespace: Namespace.ID
    @Binding var showingNowPlaying: Bool

    // Animation state for interactions
    @State private var isPressed = false

    // Constants for compact design
    private let compactHeight: CGFloat = 74
    private let cornerRadius: CGFloat = 16

    var body: some View {
        compactPlayerContent
            .frame(height: compactHeight)
            .a11yAwareGlass(style: .thick, cornerRadius: cornerRadius)
            .clearGlassFix()
            .adaptiveGlass(cornerRadius: cornerRadius)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.1), .clear],
                            startPoint: .top,
                            endPoint: .bottom,
                        ),
                        lineWidth: 0.5,
                    ),
            )
            .shadow(color: .black.opacity(0.15), radius: 16, x: 0, y: -3)
            .scaleEffect(isPressed ? 0.98 : 1.0)
            .matchedTransitionSource(id: "miniplayer", in: namespace)
            .animation(.liquidBouncy, value: isPressed)
            .onTapGesture { expandWithHaptics() }
            .onLongPressGesture(
                minimumDuration: 0,
                maximumDistance: .infinity,
                pressing: { pressing in
                    withAnimation(.easeInOut(duration: 0.1)) {
                        isPressed = pressing
                    }
                },
                perform: {},
            )
    }

    // MARK: - Compact Content

    private var compactPlayerContent: some View {
        HStack(spacing: 12) {
            albumArtwork(size: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(audioService?.currentTrack?.title ?? "Not Playing")
                    .font(.body)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .foregroundColor(.primary)

                Text(audioService?.currentTrack?.artist ?? "No Artist")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 16) {
                playPauseButton
                    .frame(minWidth: 44, minHeight: 44)

                nextButton
                    .frame(minWidth: 44, minHeight: 44)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 13)
    }

    // MARK: - Shared Components

    private func albumArtwork(size: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing,
                ),
            )
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white.opacity(0.6)),
            )
    }

    private var playPauseButton: some View {
        Button(action: togglePlayPause) {
            Image(systemName: audioService?.isPlaying == true ? "pause.fill" : "play.fill")
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(audioService?.currentTrack == nil)
        .opacity(audioService?.currentTrack == nil ? 0.4 : 1.0)
        .accessibilityLabel(audioService?.isPlaying == true ? "Pause" : "Play")
    }

    private var nextButton: some View {
        Button(action: playNext) {
            Image(systemName: "forward.fill")
                .font(.body)
                .foregroundStyle(.primary)
                .frame(width: 32, height: 32)
        }
        .buttonStyle(PlainButtonStyle())
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

    private func expandWithHaptics() {
        showingNowPlaying = true

        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred(intensity: 0.9)
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Namespace var namespace
    @Previewable @State var audioService = AudioEngineFacade()
    @Previewable @State var showingNowPlaying = false

    VStack {
        Spacer()
        LiquidGlassMiniPlayer(
            namespace: namespace,
            showingNowPlaying: $showingNowPlaying,
        )
        .environment(\.audioEngine, audioService)
        .padding()
    }
    .background(
        LinearGradient(
            colors: [.black, .blue.opacity(0.3), .purple.opacity(0.2)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing,
        ),
    )
    .preferredColorScheme(.dark)
}
