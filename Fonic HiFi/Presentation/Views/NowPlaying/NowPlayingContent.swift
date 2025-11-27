//
//  NowPlayingContent.swift
//  Fonic HiFi
//
//  Simplified iOS 26+ Now Playing content matching Apple Music's clean approach.
//  Used directly inside fullScreenCover's safeAreaInset for proper zoom transition.
//

import OSLog
import SwiftUI

@MainActor
struct NowPlayingContent: View {
    private let logger = Log.logger(.nowPlaying)
    @Environment(\.audioEngine) private var audioService: AudioEngineFacade?
    @Environment(\.sizeCategory) private var sizeCategory

    let namespace: Namespace.ID
    let dismiss: () -> Void

    // UI State
    @State private var showingQueue = false
    @State private var trackDetailItem: TrackDetailItem?
    @State private var isFavorite = false

    // Shared color service for gradient
    @ObservedObject private var colorService = DominantColorService.shared

    private var dominantColor: Color {
        colorService.dominantColor
    }

    // Persistence
    @AppStorage("volume") private var volumeStorage: Double = 1.0
    @AppStorage("isShuffleEnabled") private var isShuffleEnabled: Bool = false
    @AppStorage("repeatMode") private var repeatModeRawValue: String = QueueRepeatMode.none.rawValue

    private var volume: Float {
        get { Float(volumeStorage) }
        set { volumeStorage = Double(newValue) }
    }

    private var repeatMode: QueueRepeatMode {
        get { QueueRepeatMode(rawValue: repeatModeRawValue) ?? .none }
        set { repeatModeRawValue = newValue.rawValue }
    }

    // Slider state
    @State private var sliderProgress: Double = 0.0
    @State private var isUserDragging: Bool = false

    // Accent color for play button
    private let playAccentColor = Color(red: 0.0, green: 0.94, blue: 0.52)

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator

            headerBar
                .padding(.horizontal, 24)

            Color.clear.frame(height: 6)

            VStack(spacing: 16) {
                albumArtworkView
                trackInfoView
                progressView
                playbackControlsView
                volumeView
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
        }
        .background(
            LinearGradient(
                colors: [
                    dominantColor.opacity(0.6),
                    dominantColor.opacity(0.3),
                    Color.black.opacity(0.8),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .task {
            await colorService.extractColor(for: audioService?.currentTrack)
        }
        .sheet(item: $trackDetailItem) { item in
            NavigationStack {
                TrackDetailView(track: item.track)
            }
        }
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        Capsule()
            .fill(.primary.secondary)
            .frame(width: 35, height: 3)
            .padding(.top, 8)
            .padding(.bottom, 4)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 16) {
            Button(action: dismiss) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Now Playing")

            Spacer()

            Text("Now Playing")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.white)

            Spacer()

            AirPlayRouteButton()
                .frame(width: 44, height: 44)
                .tint(.white)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Album Artwork

    private var albumArtworkView: some View {
        MorphableArtwork(size: 280, namespace: namespace)
            .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
            .onTapGesture {
                guard let track = audioService?.currentTrack else { return }
                trackDetailItem = TrackDetailItem(track: track)
            }
            .accessibilityLabel("Album artwork")
            .accessibilityHint("Current track album artwork")
    }

    // MARK: - Track Info

    private var trackInfoView: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(audioService?.currentTrack?.title ?? "Not Playing")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.white)

                Text(audioService?.currentTrack?.artist ?? "No Artist")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    isFavorite.toggle()
                    logger.debug("Favorite toggled: \(isFavorite, privacy: .public)")
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                Button {
                    guard let track = audioService?.currentTrack else { return }
                    trackDetailItem = TrackDetailItem(track: track)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(.white)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show track options")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { sliderProgress },
                    set: { sliderProgress = $0 }
                ),
                in: 0 ... 1,
                onEditingChanged: { editing in
                    isUserDragging = editing
                    guard !editing,
                          let audioService,
                          audioService.duration > 0 else { return }

                    let targetTime = sliderProgress * audioService.duration
                    Task {
                        do {
                            try await audioService.seek(to: targetTime)
                            logger.debug("Seek committed at \(targetTime, privacy: .public)s")
                        } catch {
                            logger.error("Seek failed: \(error.localizedDescription, privacy: .public)")
                        }
                    }
                }
            )
            .tint(.white)
            .onAppear {
                sliderProgress = audioService?.playbackProgress ?? 0.0
            }
            .onChange(of: audioService?.playbackProgress) { _, newValue in
                if !isUserDragging, let newValue {
                    sliderProgress = newValue
                }
            }

            HStack {
                Text(formatTime(audioService?.currentTime ?? 0))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
                Spacer()
                Text(formatTime(audioService?.duration ?? 0))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Playback Controls

    private var playbackControlsView: some View {
        HStack(spacing: 0) {
            // Shuffle
            Button(action: toggleShuffle) {
                Image(systemName: "shuffle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(isShuffleEnabled ? 1.0 : 0.6))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isShuffleEnabled ? "Shuffle on" : "Shuffle off")

            Spacer()

            // Previous
            Button(action: playPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous track")

            Spacer()

            // Play/Pause
            Button(action: togglePlayPause) {
                ZStack {
                    Circle()
                        .fill(playAccentColor)
                        .shadow(color: playAccentColor.opacity(0.3), radius: 6, x: 0, y: 2)
                    Image(systemName: audioService?.isPlaying == true ? "pause.fill" : "play.fill")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.85))
                }
                .frame(width: 56, height: 56)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(audioService?.isPlaying == true ? "Pause" : "Play")

            Spacer()

            // Next
            Button(action: playNext) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 24, weight: .medium))
                    .foregroundStyle(.white)
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next track")

            Spacer()

            // Repeat
            Button(action: cycleRepeatMode) {
                Image(systemName: repeatModeIcon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(repeatMode != .none ? 1.0 : 0.6))
                    .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(repeatMode == .none ? "Repeat off" : (repeatMode == .one ? "Repeat one" : "Repeat all"))
        }
        .frame(height: 56)
        .padding(.horizontal, 16)
    }

    // MARK: - Volume View

    private var volumeView: some View {
        HStack(spacing: 12) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { volume },
                    set: { newValue in
                        volumeStorage = Double(newValue)
                        Task {
                            guard let audioService else { return }
                            await audioService.setVolume(Float(newValue))
                        }
                    }
                ),
                in: 0 ... 1
            )
            .tint(.white)

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Helpers

    private var repeatModeIcon: String {
        switch repeatMode {
        case .none: "repeat"
        case .all: "repeat"
        case .one: "repeat.1"
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    // MARK: - Actions

    private func togglePlayPause() {
        // Diagnostic logging for debugging controls issue
        if let audioService {
            let serviceID = String(describing: ObjectIdentifier(audioService))
            logger.debug("""
                togglePlayPause called
                - audioService ID: \(serviceID, privacy: .public)
                - isReady: \(audioService.isReady)
                - isPlaying: \(audioService.isPlaying)
                - currentTrack: \(audioService.currentTrack != nil ? "present" : "nil")
                """)
        } else {
            logger.error("togglePlayPause: audioService is NIL")
        }

        Task { @MainActor in
            guard let audioService else { return }
            do {
                if audioService.isPlaying {
                    await audioService.pause()
                } else {
                    try await audioService.resume()
                }
            } catch {
                logger.error("Failed to toggle playback: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func playNext() {
        Task { @MainActor in
            guard let audioService else { return }
            do {
                try await audioService.playNext()
            } catch {
                logger.error("Failed to play next: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    private func playPrevious() {
        Task { @MainActor in
            guard let audioService else { return }
            do {
                try await audioService.playPrevious()
            } catch {
                logger.error("Failed to play previous: \(error.localizedDescription, privacy: .public)")
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
            case .none: .all
            case .all: .one
            case .one: .none
            }
            audioService.setRepeatMode(newMode)
            repeatModeRawValue = newMode.rawValue
        }
    }
}

// MARK: - Supporting Types

private struct TrackDetailItem: Identifiable {
    let id: UUID
    let track: Track

    init(track: Track) {
        id = track.id
        self.track = track
    }
}

// MARK: - Preview

#Preview {
    @Previewable @Namespace var namespace
    NowPlayingContent(namespace: namespace, dismiss: {})
        .audioEngine(AudioEngineFacade())
}
