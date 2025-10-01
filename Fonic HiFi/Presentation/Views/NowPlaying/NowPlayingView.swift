//
//  NowPlayingView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//  iOS 26+ Liquid Glass Implementation with Morphing Animations
//

import SwiftUI

// iOS 26+ Liquid Glass Design System

@MainActor
struct NowPlayingView: View {
    @Environment(\.audioEngine) private var audioService: AudioEngineFacade?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Animation namespace from parent
    let animationNamespace: Namespace.ID

    // Drag gesture state
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    // UI State (moved from AppState to local state)
    @State private var showingQueue = false
    @State private var dominantColor: Color = .accentColor
    @State private var trackDetailItem: TrackDetailItem?

    // UI Preferences (now using @AppStorage for persistence)
    @AppStorage("volume") private var volumeStorage: Double = 1.0
    @AppStorage("isShuffleEnabled") private var isShuffleEnabled: Bool = false
    @AppStorage("repeatMode") private var repeatModeRawValue: String = QueueRepeatMode.none.rawValue

    // Computed property for volume (convert Double to Float)
    private var volume: Float {
        get { Float(volumeStorage) }
        set { volumeStorage = Double(newValue) }
    }

    // Computed property for repeat mode
    private var repeatMode: QueueRepeatMode {
        get { QueueRepeatMode(rawValue: repeatModeRawValue) ?? .none }
        set { repeatModeRawValue = newValue.rawValue }
    }

    // Slider state for progress control
    @State private var sliderProgress: Double = 0.0
    @State private var isUserDragging: Bool = false
    @State private var isPlayingParticles = false

    // Constants
    private let artworkSize: CGFloat = 320
    private let dismissThreshold: CGFloat = 150

    var body: some View {
        Group {
            if let audioService {
                nowPlayingContent(audioService: audioService)
            } else {
                EmptyView()
            }
        }
        .onAppear {
            isPlayingParticles = audioService?.isPlaying ?? false
        }
        .sheet(item: $trackDetailItem) { item in
            NavigationStack {
                TrackDetailView(track: item.track)
            }
        }
    }

    @ViewBuilder
    private func nowPlayingContent(audioService _: AudioEngineFacade) -> some View {
        GlassEffectContainer(spacing: 0) {
            ZStack {
                // Background gradient with glass effect
                LinearGradient(
                    colors: [
                        dominantColor.opacity(0.6),
                        dominantColor.opacity(0.3),
                        Color.black.opacity(0.8),
                    ],
                    startPoint: .top,
                    endPoint: .bottom,
                )
                .ignoresSafeArea()
                .clearGlassFix() // iOS 26 Beta 6 fix

                VStack(spacing: 0) {
                    // Drag handle with glass effect
                    Capsule()
                        .fill(Color.white.opacity(0.5))
                        .frame(width: 36, height: 5)
                        .padding(.top, 8)
                        .padding(.bottom, 20)
                        .glassEffect(.clear)

                    // Main content with glass container
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(spacing: 32) {
                            // Album artwork with glass effect
                            albumArtworkView
                                .padding(.horizontal, 40)
                                .padding(.top, 20)

                            // Track info with glass effect
                            trackInfoView
                                .padding(.horizontal, 40)

                            // Progress bar with fluid glass effect
                            progressView
                                .padding(.horizontal, 40)

                            // Playback controls with glass effect
                            playbackControlsView
                                .padding(.horizontal, 40)

                            // Volume slider with glass effect
                            volumeView
                                .padding(.horizontal, 40)
                                .padding(.bottom, 40)
                        }
                    }
                }
            }
        }
        .offset(y: max(0, dragOffset))
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .animation(reduceMotion ? .none : .interactiveSpring(response: 0.4, dampingFraction: 0.8), value: isDragging)
        .gesture(dismissGesture)
        .adaptiveGlassPerformance()
        .task {
            await performInitialSetup()
        }
    }

    private func performInitialSetup() async {
        guard let audioService else { return }

        // Extract dominant color for UI aesthetics
        extractDominantColor()

        // ✅ This view is a passive observer of playback state
        // Playback is initiated from:
        // - LibraryView (when user taps a track row)
        // - MiniPlayerView (when user taps play button)
        // - Remote commands (Control Center, AirPods, lock screen)
        //
        // NowPlayingView ONLY observes and displays the current playback state.
        // It should NEVER call audioService.play() as this causes 2-9 second delays
        // when the sheet opens due to re-initializing already-playing audio.
    }

    // MARK: - Subviews

    private var albumArtworkView: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .frame(maxWidth: artworkSize)
                .glassEffect(.regular.tint(.white.opacity(0.8)))
                .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)

            Image(systemName: "music.note")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.5))
        }
        .glassEffectID("artwork", in: animationNamespace)
        .playingParticles(isPlaying: isPlayingParticles, particleCount: 15)
        .glassTransition(isActive: isPlayingParticles)
        .enhancedAccessibility(
            label: "Album artwork",
            hint: "Current track album artwork",
        )
        .preferredFrameRate(
            BatteryOptimizedGlassUtilities.optimalFrameRate(
                for: isPlayingParticles ? .interactive : .decorative,
            ),
        )
        .onTapGesture {
            guard let track = audioService?.currentTrack else { return }
            // Present detailed metadata sheet for the active track
            trackDetailItem = TrackDetailItem(track: track)
        }
    }

    private var trackInfoView: some View {
        VStack(spacing: 8) {
            Text(audioService?.currentTrack?.title ?? "Not Playing")
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(1)
                .glassEffectID("title", in: animationNamespace)
                .foregroundColor(.white)
                .enhancedAccessibility(
                    label: "Track title",
                    value: audioService?.currentTrack?.title ?? "Not Playing",
                )

            Text(audioService?.currentTrack?.artist ?? "No Artist")
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .glassEffectID("artist", in: animationNamespace)
                .enhancedAccessibility(
                    label: "Artist name",
                    value: audioService?.currentTrack?.artist ?? "No Artist",
                )

            if let album = audioService?.currentTrack?.album {
                Text(album)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
                    .enhancedAccessibility(
                        label: "Album name",
                        value: album,
                    )
            }
        }
        .padding()
        .glassEffect(.regular)
        .a11yAwareGlass(style: .thick, cornerRadius: 16)
        .glassEffectID("trackInfo", in: animationNamespace)
        .audioContextAccessibility(
            isPlaying: audioService?.isPlaying ?? false,
            trackTitle: audioService?.currentTrack?.title,
            artist: audioService?.currentTrack?.artist,
            progress: audioService?.playbackProgress,
            duration: audioService?.duration,
        )
    }

    private var progressView: some View {
        VStack(spacing: 8) {
            // Progress slider with fluid glass effect
            FluidProgressView(progress: sliderProgress)
                .frame(height: 6)
                .onAppear {
                    sliderProgress = audioService?.playbackProgress ?? 0.0
                }
                .onChange(of: audioService?.playbackProgress) { _, newValue in
                    if !isUserDragging, let newValue {
                        sliderProgress = newValue
                    }
                }
                .modifier(ProgressControlAccessibility(
                    progress: sliderProgress,
                    duration: audioService?.duration ?? 0,
                    isUserInteracting: isUserDragging,
                ))

            // Time labels
            HStack {
                Text(formatTime(audioService?.currentTime ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .enhancedAccessibility(
                        label: "Current time",
                        value: formatTime(audioService?.currentTime ?? 0),
                    )

                Spacer()

                Text(formatTime(audioService?.duration ?? 0))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                    .enhancedAccessibility(
                        label: "Total duration",
                        value: formatTime(audioService?.duration ?? 0),
                    )
            }
        }
        .padding()
        .glassEffect(.regular)
    }

    private var playbackControlsView: some View {
        HStack(spacing: 40) {
            // Shuffle button with glass effect
            Button {
                toggleShuffle()
            } label: {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundColor(isShuffleEnabled ? .accentColor : .white)
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(.glass)
            .glassEffectID("shuffle", in: animationNamespace)
            .modifier(PlaybackControlAccessibility(
                isPlaying: audioService?.isPlaying ?? false,
                controlType: .shuffle,
                isEnabled: isShuffleEnabled,
            ))
            .preferredFrameRate(
                BatteryOptimizedGlassUtilities.optimalFrameRate(for: .interactive),
            )

            // Previous button
            Button {
                playPrevious()
            } label: {
                Image(systemName: "backward.fill")
                    .font(.title)
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(.glass)
            .glassEffectID("previous", in: animationNamespace)
            .modifier(PlaybackControlAccessibility(
                isPlaying: audioService?.isPlaying ?? false,
                controlType: .previous,
                isEnabled: true,
            ))
            .preferredFrameRate(
                BatteryOptimizedGlassUtilities.optimalFrameRate(for: .interactive),
            )

            // Play/Pause button with morphing effect
            Button {
                togglePlayPause()
            } label: {
                Image(systemName: audioService?.isPlaying == true ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
                    .frame(width: 80, height: 80)
            }
            .buttonStyle(.glass)
            .glassEffectID("playPause", in: animationNamespace)
            .glassTransition(isActive: audioService?.isPlaying ?? false)
            .modifier(PlaybackControlAccessibility(
                isPlaying: audioService?.isPlaying ?? false,
                controlType: .playPause,
                isEnabled: true,
            ))
            .preferredFrameRate(
                BatteryOptimizedGlassUtilities.optimalFrameRate(for: .interactive),
            )

            // Next button
            Button {
                playNext()
            } label: {
                Image(systemName: "forward.fill")
                    .font(.title)
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(.glass)
            .glassEffectID("next", in: animationNamespace)
            .modifier(PlaybackControlAccessibility(
                isPlaying: audioService?.isPlaying ?? false,
                controlType: .next,
                isEnabled: true,
            ))
            .preferredFrameRate(
                BatteryOptimizedGlassUtilities.optimalFrameRate(for: .interactive),
            )

            // Repeat button
            Button {
                cycleRepeatMode()
            } label: {
                Image(systemName: repeatModeIcon)
                    .font(.title3)
                    .foregroundColor(repeatMode != .none ? .accentColor : .white)
                    .frame(width: 50, height: 50)
            }
            .buttonStyle(.glass)
            .glassEffectID("repeat", in: animationNamespace)
            .modifier(PlaybackControlAccessibility(
                isPlaying: audioService?.isPlaying ?? false,
                controlType: .repeat,
                isEnabled: true,
            ))
            .preferredFrameRate(
                BatteryOptimizedGlassUtilities.optimalFrameRate(for: .interactive),
            )
        }
        .foregroundColor(.white)
    }

    private var volumeView: some View {
        HStack(spacing: 16) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundColor(.secondary)
                .enhancedAccessibility(
                    label: "Volume control",
                    hint: "Adjust playback volume",
                )

            Slider(value: Binding(
                get: { volume },
                set: { newValue in volumeStorage = Double(newValue) },
            ), in: 0 ... 1) { _ in
                // Update volume
            }
            .tint(.white)
            .glassEffect(.clear)
            .modifier(PlaybackControlAccessibility(
                isPlaying: audioService?.isPlaying ?? false,
                controlType: .volume,
                isEnabled: true,
            ))

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundColor(.secondary)
                .enhancedAccessibility(
                    label: "Volume level indicator",
                    value: "\(Int(volume * 100)) percent",
                )
        }
        .padding()
        .glassEffect(.regular)
    }

    // MARK: - Gestures

    private var dismissGesture: some Gesture {
        DragGesture()
            .updating($dragOffset) { value, state, _ in
                if value.translation.height > 0 {
                    state = value.translation.height
                }
            }
            .onChanged { _ in
                // Gesture callbacks may run on background thread
                Task { @MainActor in
                    isDragging = true
                }
            }
            .onEnded { value in
                // Gesture callbacks may run on background thread
                Task { @MainActor in
                    isDragging = false

                    let shouldDismiss = value.translation.height > dismissThreshold ||
                        (value.translation.height > 50 && value.predictedEndTranslation.height > 200)

                    if shouldDismiss {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()

                        withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
                            dismiss()
                        }
                    }
                }
            }
    }

    // MARK: - Helpers

    private var repeatModeIcon: String {
        switch repeatMode {
        case .none:
            "repeat"
        case .all:
            "repeat"
        case .one:
            "repeat.1"
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func extractDominantColor() {
        // For now, use a default color
        // In production, extract from album artwork
        dominantColor = .purple
    }

    // MARK: - Actions

    private func togglePlayPause() {
        Task { @MainActor in
            guard let audioService else { return }
            do {
                if audioService.isPlaying {
                    await audioService.pause()
                    isPlayingParticles = false
                } else {
                    try await audioService.resume()
                    isPlayingParticles = true
                }
            } catch {
                print("Failed to toggle playback: \(error)")
            }
        }
    }

    private func playNext() {
        Task { @MainActor in
            guard let audioService else { return }
            do {
                try await audioService.playNext()
            } catch {
                print("Failed to play next: \(error)")
            }
        }
    }

    private func playPrevious() {
        Task { @MainActor in
            guard let audioService else { return }
            do {
                try await audioService.playPrevious()
            } catch {
                print("Failed to play previous: \(error)")
            }
        }
    }

    private func toggleShuffle() {
        Task { @MainActor in
            guard let audioService else { return }
            let newMode: QueueShuffleMode = isShuffleEnabled ? .off : .random
            audioService.setShuffleMode(newMode)
            isShuffleEnabled = newMode != .off
        }
    }

    private func cycleRepeatMode() {
        Task { @MainActor in
            guard let audioService else { return }
            let newMode: QueueRepeatMode = switch repeatMode {
            case .none:
                .all
            case .all:
                .one
            case .one:
                .none
            }
            audioService.setRepeatMode(newMode)
            repeatModeRawValue = newMode.rawValue
        }
    }
}

private struct TrackDetailItem: Identifiable {
    let id: UUID
    let track: Track

    init(track: Track) {
        id = track.id
        self.track = track
    }
}

#Preview {
    @Previewable @Namespace var namespace
    NowPlayingView(animationNamespace: namespace)
        .audioEngine(AudioEngineFacade())
}
