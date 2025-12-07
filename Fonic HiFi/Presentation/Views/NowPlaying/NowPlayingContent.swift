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
    @Environment(\.dataManager) private var dataManager: DataManager?
    @Environment(\.sizeCategory) private var sizeCategory
    @Environment(\.themePalette) private var theme

    let namespace: Namespace.ID
    let dismiss: () -> Void

    // UI State
    @State private var showingQueue = false
    @State private var trackDetailItem: TrackDetailItem?
    @State private var isFavorite = false
    @State private var showSleepTimerSheet = false
    @State private var showingLyrics = false
    @State private var playbackSpeed: Double = 1.0

    // Sleep Timer
    @StateObject private var sleepTimerManager = SleepTimerManager()

    // Shared color service for gradient
    @ObservedObject private var colorService = DominantColorService.shared

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

    // Dynamic artwork sizing
    @State private var artworkSize: CGFloat = 280

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator

            headerBar
                .padding(.horizontal, 24)

            Color.clear.frame(height: 6)

            VStack(spacing: 0) {
                albumArtworkView

                Spacer()
                    .frame(minHeight: 24, maxHeight: 40)

                trackInfoView

                Spacer()
                    .frame(minHeight: 16, maxHeight: 32)

                progressView

                Spacer()
                    .frame(minHeight: 20, maxHeight: 36)

                playbackControlsView

                Spacer()
                    .frame(minHeight: 24, maxHeight: 48)

                volumeView

                Spacer()
                    .frame(minHeight: 20, maxHeight: 60)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 16)
            .onGeometryChange(for: CGFloat.self) { proxy in
                // 24pt padding each side, max 400pt
                min(proxy.size.width - 48, 400)
            } action: { newSize in
                artworkSize = newSize
            }
        }
        .background(
            LinearGradient(
                colors: [
                    theme.dominant.opacity(0.6),
                    theme.dominant.opacity(0.3),
                    Color.black.opacity(0.8),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        .overlay {
            if showingLyrics {
                LyricsView(
                    lyrics: audioService?.currentTrack?.lyrics,
                    isPresented: $showingLyrics
                )
            }
        }
        .animation(.easeInOut(duration: 0.25), value: showingLyrics)
        .task {
            await colorService.extractColor(for: audioService?.currentTrack)
            // Sync favorite state on appear
            isFavorite = audioService?.currentTrack?.isFavorite ?? false
        }
        .onChange(of: audioService?.currentTrack?.id) { _, _ in
            // Sync favorite state on track change
            isFavorite = audioService?.currentTrack?.isFavorite ?? false
        }
        .sheet(item: $trackDetailItem) { item in
            NavigationStack {
                TrackDetailView(track: item.track)
            }
        }
        .sheet(isPresented: $showSleepTimerSheet) {
            SleepTimerSheet(timerManager: sleepTimerManager)
                .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingQueue) {
            QueueView()
        }
        .onAppear {
            // Wire sleep timer to audio engine
            sleepTimerManager.onComplete = { [weak audioService] in
                Task { @MainActor in
                    await audioService?.pause()
                }
            }
            sleepTimerManager.onVolumeChange = { [weak audioService] volume in
                Task { @MainActor in
                    await audioService?.setVolume(volume)
                }
            }
        }
        .accessibilityAction(.escape) {
            dismiss()
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
        HStack(spacing: 12) {
            // Sleep timer button
            Button {
                showSleepTimerSheet = true
            } label: {
                ZStack {
                    Image(systemName: sleepTimerManager.isActive ? "moon.zzz.fill" : "moon.zzz")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(sleepTimerManager.isActive ? .orange : .white)

                    // Badge showing remaining time
                    if sleepTimerManager.isActive {
                        Text(formatTimerBadge(sleepTimerManager.remainingSeconds))
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 2)
                            .background(.orange, in: Capsule())
                            .offset(x: 12, y: -10)
                    }
                }
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(sleepTimerManager.isActive ? "Sleep timer active" : "Set sleep timer")

            // Playback speed button
            playbackSpeedMenu

            Spacer()

            Text("Now Playing")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.white)

            Spacer()

            // Queue button
            Button {
                showingQueue = true
            } label: {
                Image(systemName: "list.bullet")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show queue")

            AirPlayRouteButton()
                .frame(width: 44, height: 44)
                .tint(.white)
        }
        .padding(.vertical, 4)
    }

    private var playbackSpeedMenu: some View {
        Menu {
            ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                Button {
                    playbackSpeed = speed
                    Task {
                        await audioService?.updatePlaybackRate(speed)
                    }
                } label: {
                    HStack {
                        Text(formatSpeed(speed))
                        if playbackSpeed == speed {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 2) {
                Image(systemName: "speedometer")
                    .font(.system(size: 14, weight: .medium))
                if playbackSpeed != 1.0 {
                    Text(formatSpeed(playbackSpeed))
                        .font(.system(size: 10, weight: .semibold))
                }
            }
            .foregroundStyle(playbackSpeed != 1.0 ? .orange : .white)
            .frame(width: 44, height: 44)
        }
        .accessibilityLabel("Playback speed: \(formatSpeed(playbackSpeed))")
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == 1.0 {
            return "1×"
        } else if speed.truncatingRemainder(dividingBy: 1.0) == 0 {
            return "\(Int(speed))×"
        } else {
            return String(format: "%.2g×", speed)
        }
    }

    // MARK: - Album Artwork

    private var albumArtworkView: some View {
        MorphableArtwork(size: artworkSize, namespace: namespace)
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
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isFavorite ? .red : .white)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                Button {
                    showingLyrics.toggle()
                    logger.info("Lyrics toggled: \(showingLyrics)")
                } label: {
                    Image(systemName: "text.quote")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(hasLyrics ? .white : .white.opacity(0.4))
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .disabled(!hasLyrics)
                .accessibilityLabel(hasLyrics ? "Show lyrics" : "No lyrics available")

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
            CustomProgressSlider(
                progress: $sliderProgress,
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
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                // A-B Loop button
                Button {
                    handleLoopTap()
                } label: {
                    Image(systemName: loopButtonIcon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(loopButtonTint)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(loopAccessibilityLabel)

                Spacer()

                Text(formatTime(audioService?.duration ?? 0))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.8))
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
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(isShuffleEnabled ? 1.0 : 0.6))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isShuffleEnabled ? "Shuffle on" : "Shuffle off")

            Spacer()

            // Previous
            Button(action: playPrevious) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Previous track")

            Spacer()

            // Play/Pause
            Button(action: togglePlayPause) {
                ZStack {
                    Circle()
                        .fill(theme.accent)
                        .shadow(color: theme.accent.opacity(0.3), radius: 6, x: 0, y: 2)
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
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Next track")

            Spacer()

            // Repeat
            Button(action: cycleRepeatMode) {
                Image(systemName: repeatModeIcon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(.white.opacity(repeatMode != .none ? 1.0 : 0.6))
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
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
            .tint(theme.accent)

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

    private var hasLyrics: Bool {
        guard let lyrics = audioService?.currentTrack?.lyrics else { return false }
        return !lyrics.isEmpty
    }

    // MARK: - A-B Loop Helpers

    private var loopButtonIcon: String {
        guard let state = audioService?.abLoopState else { return "a.square" }
        if state.isEnabled { return "repeat.circle.fill" }
        if state.pointA != nil { return "b.square" }
        return "a.square"
    }

    private var loopButtonTint: Color {
        guard let state = audioService?.abLoopState else { return .white.opacity(0.6) }
        if state.isEnabled { return .orange }
        if state.pointA != nil { return .orange.opacity(0.8) }
        return .white.opacity(0.6)
    }

    private var loopAccessibilityLabel: String {
        guard let state = audioService?.abLoopState else { return "Set loop point A" }
        if state.isEnabled { return "Clear loop" }
        if state.pointA != nil { return "Set loop point B" }
        return "Set loop point A"
    }

    private func handleLoopTap() {
        guard let service = audioService else { return }

        if service.abLoopState.isEnabled {
            service.clearLoop()
        } else if service.abLoopState.pointA != nil {
            service.setLoopPointB()
        } else {
            service.setLoopPointA()
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func formatTimerBadge(_ seconds: Int) -> String {
        let minutes = seconds / 60
        if minutes >= 60 {
            return "\(minutes / 60)h"
        } else {
            return "\(minutes)m"
        }
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

    private func toggleFavorite() {
        guard let track = audioService?.currentTrack,
              let trackDataActor = dataManager?.trackDataActor else { return }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        Task {
            do {
                try await trackDataActor.toggleFavorite(trackId: track.persistentModelID)
                isFavorite.toggle()
                logger.info("Favorite toggled: \(isFavorite)")
            } catch {
                logger.error("Failed to toggle favorite: \(error.localizedDescription)")
            }
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
