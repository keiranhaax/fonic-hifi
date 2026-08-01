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
    @EnvironmentObject private var audioService: AudioEngineFacade
    @Environment(\.dataManager) private var dataManager: DataManager?
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.themePalette) private var theme
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiateWithoutColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let namespace: Namespace.ID
    let dismiss: () -> Void

    // UI State
    @State private var showingQueue = false
    @State private var trackDetailItem: TrackDetailItem?
    @State private var showSleepTimerSheet = false
    @State private var showingLyrics = false
    @AccessibilityFocusState private var overflowMenuFocused: Bool

    /// Shared color service for gradient
    @ObservedObject private var colorService = DominantColorService.shared

    /// Persistence
    @AppStorage("volume") private var volumeStorage: Double = 1.0

    private var volume: Float {
        get { Float(volumeStorage) }
        set { volumeStorage = Double(newValue) }
    }

    private var sleepTimerManager: SleepTimerManager {
        audioService.sleepTimerManager
    }

    private var playbackSpeed: Double {
        audioService.playbackRate
    }

    private var shuffleMode: QueueShuffleMode {
        audioService.queueManager.shuffleMode
    }

    private var repeatMode: QueueRepeatMode {
        audioService.queueManager.repeatMode
    }

    private var isFavorite: Bool {
        audioService.currentTrack?.isFavorite ?? false
    }

    static func lyricsTransitionAnimation(reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : .easeInOut(duration: DesignTokens.Animation.quickFadeDuration)
    }

    // Slider state
    @State private var sliderProgress: Double = 0.0
    @State private var isUserDragging: Bool = false

    /// Container-driven artwork sizing
    @State private var artworkSize: CGFloat = 280

    var body: some View {
        VStack(spacing: 0) {
            dragIndicator

            headerBar
                .padding(.horizontal, DesignTokens.Spacing.xLarge)

            Color.clear.frame(height: 6)

            adaptivePlaybackContent
        }
        .onGeometryChange(for: CGSize.self) { proxy in
            proxy.size
        } action: { newSize in
            artworkSize = Self.adaptiveArtworkSize(
                for: newSize,
                accessibilityText: dynamicTypeSize.isAccessibilitySize
            )
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
        .modifier(
            LyricsOverlayModifier(
                lyrics: audioService.currentTrack?.lyrics,
                isPresented: $showingLyrics
            )
        )
        .playbackErrorOverlay(
            audioService.playbackError,
            accessibilityIdentifier: "NowPlayingPlaybackErrorBanner",
            dismiss: { id in audioService.dismissPlaybackControlError(id: id) }
        )
        .animation(Self.lyricsTransitionAnimation(reduceMotion: reduceMotion), value: showingLyrics)
        .task {
            await colorService.extractColor(for: audioService.currentTrack)
        }
        .onChange(of: showingLyrics) { wasShowing, isShowing in
            if wasShowing, !isShowing {
                overflowMenuFocused = true
            }
        }
        .sheet(item: $trackDetailItem) { item in
            NavigationStack {
                TrackDetailView(track: item.track)
            }
        }
        .sheet(isPresented: $showSleepTimerSheet) {
            SleepTimerSheet(
                timerManager: sleepTimerManager,
                startTimer: { seconds, fadeOutDuration in
                    await audioService.startSleepTimer(
                        seconds: seconds,
                        fadeOutDuration: fadeOutDuration
                    )
                }
            )
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $showingQueue) {
            QueueView()
        }
        .accessibilityAction(.escape) {
            dismiss()
        }
    }

    static func adaptiveArtworkSize(
        for containerSize: CGSize,
        accessibilityText: Bool
    ) -> CGFloat {
        let horizontalLimit = max(
            0,
            containerSize.width - (DesignTokens.Spacing.xLarge * 2)
        )
        let verticalFraction = accessibilityText ? 0.28 : 0.42
        let verticalLimit = containerSize.height * verticalFraction
        let minimumSize = min(120, horizontalLimit)
        return max(minimumSize, min(horizontalLimit, verticalLimit, 400))
    }

    static func playbackModeVisualState(
        isActive: Bool,
        differentiateWithoutColor: Bool
    ) -> PlaybackModeVisualState {
        PlaybackModeVisualState(
            showsBadge: isActive,
            showsOutline: isActive || differentiateWithoutColor,
            outlineWidth: isActive ? 2 : 1
        )
    }

    @ViewBuilder
    private var adaptivePlaybackContent: some View {
        if dynamicTypeSize.isAccessibilitySize {
            scrollingPlaybackContent
        } else {
            ViewThatFits(in: .vertical) {
                playbackContent
                    .fixedSize(horizontal: false, vertical: true)

                scrollingPlaybackContent
            }
        }
    }

    private var scrollingPlaybackContent: some View {
        ScrollView {
            playbackContent
        }
        .scrollBounceBehavior(.basedOnSize)
        .accessibilityIdentifier("NowPlayingScrollableContent")
    }

    private var playbackContent: some View {
        VStack(spacing: 0) {
            albumArtworkView

            Color.clear
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 16 : 32)

            trackInfoView

            Color.clear
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 12 : 24)

            progressView

            Color.clear
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 16 : 28)

            playbackControlsView

            Color.clear
                .frame(height: dynamicTypeSize.isAccessibilitySize ? 20 : 36)

            volumeView

            Color.clear
                .frame(height: DesignTokens.Spacing.large)
        }
        .padding(.horizontal, DesignTokens.Spacing.xLarge)
        .padding(.bottom, DesignTokens.Spacing.large)
    }

    // MARK: - Drag Indicator

    private var dragIndicator: some View {
        Capsule()
            .fill(.primary.secondary)
            .frame(width: 35, height: 3)
            .padding(.top, DesignTokens.Spacing.small)
            .padding(.bottom, DesignTokens.Spacing.xSmall)
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.Spacing.small) {
                dismissButton
                Spacer(minLength: DesignTokens.Spacing.small)
                nowPlayingTitle
                    .fixedSize()
                Spacer(minLength: DesignTokens.Spacing.small)
                trailingHeaderControls
            }

            VStack(spacing: 0) {
                HStack(spacing: DesignTokens.Spacing.small) {
                    dismissButton
                    Spacer()
                    trailingHeaderControls
                }
                nowPlayingTitle
            }
        }
        .padding(.vertical, DesignTokens.Spacing.xSmall)
    }

    private var dismissButton: some View {
        Button(action: dismiss) {
            Image(systemName: "chevron.down")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.plain)
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(.rect)
        .accessibilityLabel("Dismiss Now Playing")
        .accessibilityIdentifier("DismissNowPlayingButton")
    }

    private var trailingHeaderControls: some View {
        HStack(spacing: DesignTokens.Spacing.small) {
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
    }

    private var nowPlayingTitle: some View {
        Text("Now Playing")
            .font(.headline)
            .fontWeight(.medium)
            .foregroundStyle(.white)
    }

    private func formatSpeed(_ speed: Double) -> String {
        if speed == 1.0 {
            "1×"
        } else if speed.truncatingRemainder(dividingBy: 1.0) == 0 {
            "\(Int(speed))×"
        } else {
            String(format: "%.2g×", speed)
        }
    }

    // MARK: - Overflow Menu

    private var hasActiveOverflowFeatures: Bool {
        sleepTimerManager.isActive || playbackSpeed != 1.0 || showingLyrics
    }

    private var overflowMenuAccessibilityLabel: String {
        var activeItems: [String] = []
        if sleepTimerManager.isActive {
            activeItems.append("Sleep timer active")
        }
        if playbackSpeed != 1.0 {
            activeItems.append("Speed \(formatSpeed(playbackSpeed))")
        }
        if showingLyrics {
            activeItems.append("Lyrics showing")
        }
        return activeItems.isEmpty ? "More options" : "More options: \(activeItems.joined(separator: ", "))"
    }

    private var overflowMenu: some View {
        Menu {
            // Sleep Timer
            Button {
                showSleepTimerSheet = true
            } label: {
                Label {
                    HStack {
                        Text("Sleep Timer")
                        if sleepTimerManager.isActive {
                            Spacer()
                            Text(formatTimerBadge(sleepTimerManager.remainingSeconds))
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: sleepTimerManager.isActive ? "moon.zzz.fill" : "moon.zzz")
                }
            }

            // Playback Speed Submenu
            Menu {
                ForEach([0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], id: \.self) { speed in
                    Button {
                        Task {
                            await audioService.updatePlaybackRate(speed)
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
                Label {
                    HStack {
                        Text("Playback Speed")
                        if playbackSpeed != 1.0 {
                            Spacer()
                            Text(formatSpeed(playbackSpeed))
                                .foregroundStyle(.secondary)
                        }
                    }
                } icon: {
                    Image(systemName: "speedometer")
                }
            }

            Divider()

            // Lyrics Toggle
            Button {
                showingLyrics.toggle()
                logger.info("Lyrics toggled: \(showingLyrics, privacy: .public)")
            } label: {
                Label {
                    HStack {
                        Text("Lyrics")
                        if showingLyrics {
                            Spacer()
                            Image(systemName: "checkmark")
                        }
                    }
                } icon: {
                    Image(systemName: "text.quote")
                }
            }
            .disabled(!hasLyrics)

            // Track Info
            Button {
                guard let track = audioService.currentTrack else { return }
                trackDetailItem = TrackDetailItem(track: track)
            } label: {
                Label("Track Info", systemImage: "info.circle")
            }
        } label: {
            Image(systemName: hasActiveOverflowFeatures ? "ellipsis.circle.fill" : "ellipsis.circle")
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(hasActiveOverflowFeatures ? .orange : .white)
                .contentShape(.rect)
                .frame(width: 44, height: 44)
        }
        .accessibilityFocused($overflowMenuFocused)
        .accessibilityLabel(overflowMenuAccessibilityLabel)
    }

    // MARK: - Album Artwork

    private var albumArtworkView: some View {
        Button {
            guard let track = audioService.currentTrack else { return }
            trackDetailItem = TrackDetailItem(track: track)
        } label: {
            MorphableArtwork(size: artworkSize, namespace: namespace, isSource: false)
                .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
        }
        .buttonStyle(.plain)
        .disabled(audioService.currentTrack == nil)
        .accessibilityLabel(
            audioService.currentTrack.map { "Track information for \($0.title)" }
                ?? "Track information"
        )
        .accessibilityHint("Shows details for the current track")
    }

    // MARK: - Track Info

    private var trackInfoView: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: DesignTokens.Spacing.small))
            : AnyLayout(HStackLayout(alignment: .center, spacing: DesignTokens.Spacing.medium))

        return layout {
            VStack(alignment: .leading, spacing: 2) {
                Text(audioService.currentTrack?.title ?? "Not Playing")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
                    .foregroundStyle(.white)

                Text(audioService.currentTrack?.artist ?? "No Artist")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            HStack(spacing: DesignTokens.Spacing.small) {
                // Heart button (UNCHANGED)
                Button {
                    toggleFavorite()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundStyle(isFavorite ? .red : .white)
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                // Overflow menu (replaces Lyrics + Ellipsis buttons)
                overflowMenu
            }
            .frame(
                maxWidth: dynamicTypeSize.isAccessibilitySize ? .infinity : nil,
                alignment: .trailing
            )
        }
        .padding(.horizontal, DesignTokens.Spacing.large)
        .padding(.vertical, DesignTokens.Spacing.small)
    }

    // MARK: - Progress View

    private var progressView: some View {
        VStack(spacing: 6) {
            CustomProgressSlider(
                progress: $sliderProgress,
                onEditingChanged: { editing in
                    isUserDragging = editing
                    guard !editing, audioService.duration > 0 else { return }

                    let targetTime = sliderProgress * audioService.duration
                    Task {
                        do {
                            try await audioService.seek(to: targetTime)
                            logger.debug("Seek committed at \(targetTime, privacy: .public)s")
                        } catch {
                            logger.error("Seek failed: \(error.localizedDescription, privacy: .private)")
                        }
                    }
                },
                abLoopState: audioService.abLoopState,
                duration: audioService.duration
            )
            .onAppear {
                sliderProgress = audioService.playbackProgress
            }
            .onChange(of: audioService.playbackProgress) { _, newValue in
                if !isUserDragging {
                    sliderProgress = newValue
                }
            }

            HStack {
                Text(formatTime(audioService.currentTime))
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
                        .frame(width: 44, height: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(loopAccessibilityLabel)

                Spacer()

                Text(formatTime(audioService.duration))
                    .font(.footnote)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.8))
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.large)
    }

    // MARK: - Playback Controls

    private var playbackControlsView: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DesignTokens.Spacing.small) {
                shuffleButton
                previousButton
                playPauseButton
                nextButton
                repeatButton
            }
            .fixedSize(horizontal: true, vertical: false)

            VStack(spacing: DesignTokens.Spacing.small) {
                HStack(spacing: DesignTokens.Spacing.section) {
                    previousButton
                    playPauseButton
                    nextButton
                }

                HStack(spacing: DesignTokens.Spacing.section) {
                    shuffleButton
                    repeatButton
                }
            }
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.horizontal, DesignTokens.Spacing.large)
    }

    private var shuffleButton: some View {
        Button(action: toggleShuffle) {
            playbackModeIcon(
                systemName: "shuffle",
                isActive: shuffleMode.isActive
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Shuffle")
        .accessibilityValue(shuffleMode.isActive ? "On" : "Off")
        .accessibilityIdentifier("ShuffleButton")
    }

    private var previousButton: some View {
        Button(action: playPrevious) {
            Image(systemName: "backward.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Previous track")
    }

    private var playPauseButton: some View {
        Button(action: togglePlayPause) {
            ZStack {
                Circle()
                    .fill(theme.accent)
                    .shadow(color: theme.accent.opacity(0.3), radius: 6, x: 0, y: 2)
                Image(systemName: audioService.isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.black.opacity(0.85))
            }
            .frame(width: 56, height: 56)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(audioService.isPlaying ? "Pause" : "Play")
    }

    private var nextButton: some View {
        Button(action: playNext) {
            Image(systemName: "forward.fill")
                .font(.system(size: 28, weight: .medium))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Next track")
    }

    private var repeatButton: some View {
        Button(action: cycleRepeatMode) {
            playbackModeIcon(
                systemName: repeatModeIcon,
                isActive: repeatMode != .none
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Repeat")
        .accessibilityValue(repeatModeAccessibilityValue)
        .accessibilityIdentifier("RepeatButton")
    }

    private func playbackModeIcon(systemName: String, isActive: Bool) -> some View {
        let visualState = Self.playbackModeVisualState(
            isActive: isActive,
            differentiateWithoutColor: differentiateWithoutColor
        )

        return ZStack(alignment: .topTrailing) {
            Image(systemName: systemName)
                .font(.system(size: 20, weight: .medium))
                .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.6))

            if visualState.showsBadge {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 10, weight: .bold))
                    .symbolRenderingMode(.palette)
                    .foregroundStyle(.black, .white)
                    .offset(x: 7, y: -7)
                    .accessibilityHidden(true)
            }
        }
        .frame(width: 44, height: 44)
        .background {
            if visualState.showsOutline {
                Circle()
                    .strokeBorder(
                        .white.opacity(isActive ? 0.9 : 0.45),
                        lineWidth: visualState.outlineWidth
                    )
                    .padding(4)
                    .accessibilityHidden(true)
            }
        }
        .contentShape(Rectangle())
    }

    // MARK: - Volume View

    private var volumeView: some View {
        HStack(spacing: DesignTokens.Spacing.medium) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundStyle(.secondary)

            Slider(
                value: Binding(
                    get: { volume },
                    set: { newValue in
                        volumeStorage = Double(newValue)
                        Task {
                            await audioService.setVolume(Float(newValue))
                        }
                    }
                ),
                in: 0 ... 1
            )
            .tint(theme.accent)
            .accessibilityLabel("Playback Volume")
            .accessibilityValue("\(Int((volume * 100).rounded())) percent")
            .accessibilityIdentifier("PlaybackVolumeSlider")

            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, DesignTokens.Spacing.large)
    }

    // MARK: - Helpers

    private var repeatModeIcon: String {
        switch repeatMode {
        case .none: "repeat"
        case .all: "repeat"
        case .one: "repeat.1"
        }
    }

    private var repeatModeAccessibilityValue: String {
        switch repeatMode {
        case .none: "Off"
        case .all: "All"
        case .one: "One"
        }
    }

    private var hasLyrics: Bool {
        guard let lyrics = audioService.currentTrack?.lyrics else { return false }
        return !lyrics.isEmpty
    }

    // MARK: - A-B Loop Helpers

    private var loopButtonIcon: String {
        let state = audioService.abLoopState
        if state.isEnabled {
            return "repeat.circle.fill"
        }
        if state.pointA != nil {
            return "b.square"
        }
        return "a.square"
    }

    private var loopButtonTint: Color {
        let state = audioService.abLoopState
        if state.isEnabled {
            return .orange
        }
        if state.pointA != nil {
            return .orange.opacity(0.8)
        }
        return .white.opacity(0.6)
    }

    private var loopAccessibilityLabel: String {
        let state = audioService.abLoopState
        if state.isEnabled {
            return "Clear loop"
        }
        if state.pointA != nil {
            return "Set loop point B"
        }
        return "Set loop point A"
    }

    private func handleLoopTap() {
        if audioService.abLoopState.isEnabled {
            audioService.clearLoop()
        } else if audioService.abLoopState.pointA != nil {
            audioService.setLoopPointB()
        } else {
            audioService.setLoopPointA()
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
        let serviceID = String(describing: ObjectIdentifier(audioService))
        logger.debug("""
        togglePlayPause called
        - audioService ID: \(serviceID, privacy: .private(mask: .hash))
        - isReady: \(audioService.isReady, privacy: .public)
        - isPlaying: \(audioService.isPlaying, privacy: .public)
        - currentTrack: \(audioService.currentTrack != nil ? "present" : "nil", privacy: .public)
        """)

        Task { @MainActor in
            do {
                if audioService.isPlaying {
                    await audioService.pause()
                } else {
                    try await audioService.resume()
                }
            } catch {
                logger.error("Failed to toggle playback: \(error.localizedDescription, privacy: .private)")
                audioService.reportPlaybackControlError(error)
            }
        }
    }

    private func playNext() {
        Task { @MainActor in
            do {
                try await audioService.playNext()
            } catch {
                logger.error("Failed to play next: \(error.localizedDescription, privacy: .private)")
                audioService.reportPlaybackControlError(error)
            }
        }
    }

    private func playPrevious() {
        Task { @MainActor in
            do {
                try await audioService.playPrevious()
            } catch {
                logger.error("Failed to play previous: \(error.localizedDescription, privacy: .private)")
                audioService.reportPlaybackControlError(error)
            }
        }
    }

    private func toggleShuffle() {
        Task { @MainActor in
            let newMode: QueueShuffleMode = shuffleMode.isActive ? .off : .random
            audioService.setShuffleMode(newMode)
        }
    }

    private func cycleRepeatMode() {
        Task { @MainActor in
            let newMode: QueueRepeatMode = switch repeatMode {
            case .none: .all
            case .all: .one
            case .one: .none
            }
            audioService.setRepeatMode(newMode)
        }
    }

    private func toggleFavorite() {
        guard let track = audioService.currentTrack,
              let trackDataActor = dataManager?.trackDataActor else { return }

        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .light)
        generator.impactOccurred()

        Task { @MainActor in
            do {
                let persistedValue = try await trackDataActor.toggleFavorite(trackId: track.persistentModelID)
                guard audioService.currentTrack?.persistentModelID == track.persistentModelID else { return }
                track.isFavorite = persistedValue
                logger.info("Favorite toggled: \(persistedValue, privacy: .public)")
            } catch {
                logger.error("Failed to toggle favorite: \(error.localizedDescription, privacy: .private)")
            }
        }
    }
}

// MARK: - Supporting Types

struct PlaybackModeVisualState: Equatable {
    let showsBadge: Bool
    let showsOutline: Bool
    let outlineWidth: CGFloat
}

private struct LyricsOverlayModifier: ViewModifier {
    let lyrics: String?
    @Binding var isPresented: Bool

    func body(content: Content) -> some View {
        ZStack {
            baseLayer(content)

            if isPresented {
                LyricsView(lyrics: lyrics, isPresented: $isPresented)
            }
        }
    }

    @ViewBuilder
    private func baseLayer(_ content: Content) -> some View {
        if isPresented {
            content
                .accessibilityElement(children: .ignore)
                .accessibilityHidden(true)
        } else {
            content
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

// MARK: - Preview

#Preview {
    @Previewable @Namespace var namespace
    NowPlayingContent(namespace: namespace, dismiss: {})
        .audioEngine(AudioEngineFacade())
}
