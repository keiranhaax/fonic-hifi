//
//  NowPlayingView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//  iOS 26+ Liquid Glass Implementation with Morphing Animations
//  Fixed layout issues with proper safe area handling and dynamic type support
//

import OSLog
import SwiftUI

// iOS 26+ Liquid Glass Design System with Enhanced Layout

@MainActor
struct NowPlayingView: View {
    private let logger = Log.logger(.nowPlaying)
    @Environment(\.audioEngine) private var audioService: AudioEngineFacade?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.sizeCategory) private var sizeCategory // Dynamic Type support

    // Animation namespace from parent
    let animationNamespace: Namespace.ID

    // Drag gesture state
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    // UI State (moved from AppState to local state)
    @State private var showingQueue = false
    @State private var dominantColor: Color = .accentColor
    @State private var trackDetailItem: TrackDetailItem?
    @State private var isFavorite = false

    // Color extraction state
    @State private var colorCache: [UUID: Color] = [:]
    @State private var isExtractingColor = false

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

    // Constants - Adaptive sizing based on accessibility settings
    private let dismissThreshold: CGFloat = 150
    private let playAccentColor = Color(red: 0.0, green: 0.94, blue: 0.52)

    // Adaptive spacing computed properties - Fixed button hierarchy
    private var adaptiveHorizontalPadding: CGFloat {
        sizeCategory.isAccessibilityCategory ? 16 : 24
    }

    private var adaptiveVerticalSpacing: CGFloat {
        sizeCategory.isAccessibilityCategory ? 40 : 32
    }

    // Fixed: Proper button size hierarchy following Apple Music standards
    private var smallControlSize: CGFloat {
        sizeCategory.isAccessibilityCategory ? 40 : 32 // shuffle, repeat
    }

    private var mediumControlSize: CGFloat {
        sizeCategory.isAccessibilityCategory ? 48 : 40 // prev/next
    }

    private var primaryControlSize: CGFloat {
        sizeCategory.isAccessibilityCategory ? 56 : 48 // play/pause
    }

    // Compact layout for no-scroll design
    private func compactArtworkSize(for geometry: GeometryProxy) -> CGFloat {
        let screenHeight = geometry.size.height
        // 160pt on SE (667pt), 180pt on standard (844pt), 200pt on Max (932pt)
        // Increased +20pt per tier after removing glass padding from track info/progress
        let base: CGFloat = screenHeight < 700 ? 160 : (screenHeight < 900 ? 180 : 200)
        return sizeCategory.isAccessibilityCategory ? max(140, base - 20) : base
    }

    private var compactSpacing: CGFloat {
        sizeCategory.isAccessibilityCategory ? 12 : 8
    }

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
        // Fixed: Use GeometryReader for proper safe area handling
        GeometryReader { geometry in
            GlassEffectContainer(spacing: 0) {
                ZStack {
                    // Background gradient with proper safe area handling
                    LinearGradient(
                        colors: [
                            dominantColor.opacity(0.6),
                            dominantColor.opacity(0.3),
                            Color.black.opacity(0.8),
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .ignoresSafeArea(edges: [.horizontal, .bottom])
                    .clearGlassFix() // iOS 26 Beta 6 fix
                    .glassPerformanceProfiled("NowPlayingBackground")

                    VStack(spacing: 0) {
                        // Fixed: Proper drag handle positioning with safe area
                        VStack(spacing: 0) {
                            Capsule()
                                .fill(Color.white.opacity(0.5))
                                .frame(width: 36, height: 5)
                                .padding(.top, max(12, geometry.safeAreaInsets.top + 8)) // Dynamic safe area padding
                                .glassEffect(.clear)
                                .glassPerformanceProfiled("DragHandle")
                        }
                        .frame(maxWidth: .infinity)

                        Color.clear.frame(height: 4)

                        // Compact header
                        headerBar
                            .padding(.horizontal, adaptiveHorizontalPadding)
                            .glassPerformanceProfiled("HeaderBar")

                        Color.clear.frame(height: 6)

                        // Compact fixed layout for standard size categories (no scrolling)
                        // Accessibility fallback uses ScrollView for XXXLarge+ text
                        if sizeCategory >= .accessibilityExtraExtraExtraLarge {
                            // Keep ScrollView for extreme accessibility sizes
                            ScrollView(.vertical, showsIndicators: false) {
                                LazyVStack(spacing: adaptiveVerticalSpacing) {
                                    albumArtworkView(size: compactArtworkSize(for: geometry))
                                        .glassPerformanceProfiled("AlbumArtwork")
                                    trackInfoView
                                        .glassPerformanceProfiled("TrackInfo")
                                    progressView
                                        .glassPerformanceProfiled("ProgressBar")
                                    playbackControlsView
                                        .glassPerformanceProfiled("PlaybackControls")
                                    volumeView
                                        .glassPerformanceProfiled("VolumeControl")
                                }
                                .padding(.horizontal, adaptiveHorizontalPadding)
                                .padding(.bottom, max(40, geometry.safeAreaInsets.bottom + 20))
                            }
                            .scrollContentBackground(.hidden)
                        } else {
                            // Fixed compact layout - no scrolling required
                            VStack(spacing: compactSpacing) {
                                albumArtworkView(size: compactArtworkSize(for: geometry))
                                    .glassPerformanceProfiled("AlbumArtwork")

                                compactTrackInfoView
                                    .glassPerformanceProfiled("CompactTrackInfo")

                                compactProgressView
                                    .glassPerformanceProfiled("CompactProgress")

                                unifiedControlsView
                                    .glassPerformanceProfiled("UnifiedControls")
                            }
                            .padding(.horizontal, adaptiveHorizontalPadding)
                            .padding(.bottom, max(16, geometry.safeAreaInsets.bottom + 4))
                        }

                        // Absorbs extra space in full-screen (.large detent)
                        // Keeps content anchored to top in both branches
                        Spacer()
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
        guard audioService != nil else { return }

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

    private var headerBar: some View {
        HStack(spacing: sizeCategory.isAccessibilityCategory ? 20 : 16) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.down")
                    .font(.system(size: sizeCategory.isAccessibilityCategory ? 24 : 20,
                                  weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .frame(width: 44, height: 44)
                    .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close Now Playing")

            Spacer()

            Text("Now Playing")
                .font(.headline)
                .fontWeight(.medium)
                .foregroundStyle(.white)
                .scaledToFit() // Dynamic Type support
                .minimumScaleFactor(0.7)
                .shadow(color: .black.opacity(0.5), radius: 2, x: 0, y: 1)

            Spacer()

            AirPlayRouteButton()
                .frame(width: 44, height: 44)
                .tint(.white)
        }
        .padding(.vertical, sizeCategory.isAccessibilityCategory ? 8 : 4)
        .padding(.horizontal, 16)
        // Glass removed for lighter visual weight - text shadows provide contrast
        .glassEffectID("headerBar", in: animationNamespace)
        .shadow(color: .black.opacity(0.35), radius: 6, x: 0, y: 2)
    }

    @ViewBuilder
    private func albumArtworkView(size: CGFloat) -> some View {
        ZStack {
            // Display actual artwork if available
            if let artworkData = audioService?.currentTrack?.artwork,
               let uiImage = UIImage(data: artworkData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    // Compact sizing for no-scroll layout
                    .frame(width: size, height: size)
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .glassEffect(.regular.tint(dominantColor.opacity(0.8)))
                    .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)
            } else {
                // Fallback placeholder with compact sizing
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        // Compact sizing for no-scroll layout
                        .frame(width: size, height: size)
                        .glassEffect(.regular.tint(dominantColor.opacity(0.8)))
                        .shadow(color: .black.opacity(0.3), radius: 16, x: 0, y: 8)

                    Image(systemName: "music.note")
                        .font(.system(size: size * 0.35))
                        .foregroundColor(.white.opacity(0.5))
                }
            }
        }
        .glassEffectID("artwork", in: animationNamespace)
        .playingParticles(isPlaying: isPlayingParticles, particleCount: 15)
        .glassTransition(isActive: isPlayingParticles)
        .enhancedAccessibility(
            label: "Album artwork",
            hint: "Current track album artwork"
        )
        .preferredFrameRate(
            BatteryOptimizedGlassUtilities.optimalFrameRate(
                for: isPlayingParticles ? .interactive : .decorative
            )
        )
        .onTapGesture {
            guard let track = audioService?.currentTrack else { return }
            // Present detailed metadata sheet for the active track
            trackDetailItem = TrackDetailItem(track: track)
        }
    }

    private var trackInfoView: some View {
        VStack(spacing: sizeCategory.isAccessibilityCategory ? 20 : 16) {
            HStack {
                Button {
                    isFavorite.toggle()
                    logger.debug("Favorite toggled: \(isFavorite, privacy: .public)")
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: sizeCategory.isAccessibilityCategory ? 20 : 17, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(isFavorite ? 0.2 : 0.12)))
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                Spacer()

                Button {
                    guard let track = audioService?.currentTrack else { return }
                    trackDetailItem = TrackDetailItem(track: track)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: sizeCategory.isAccessibilityCategory ? 20 : 17, weight: .medium))
                        .rotationEffect(.degrees(90))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Circle().fill(.white.opacity(0.12)))
                        .clipShape(Circle())
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show track options")
            }
            .contentShape(Rectangle())

            // Fixed: Proper text spacing and Dynamic Type support
            VStack(spacing: sizeCategory.isAccessibilityCategory ? 8 : 6) {
                Text(audioService?.currentTrack?.title ?? "Not Playing")
                    .font(sizeCategory.isAccessibilityCategory ? .title3 : .title2)
                    .fontWeight(.semibold)
                    .lineLimit(sizeCategory.isAccessibilityCategory ? 2 : 1)
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .scaledToFit()
                    .minimumScaleFactor(0.8)
                    .enhancedAccessibility(
                        label: "Track title",
                        value: audioService?.currentTrack?.title ?? "Not Playing"
                    )

                Text(audioService?.currentTrack?.artist ?? "No Artist")
                    .font(sizeCategory.isAccessibilityCategory ? .body : .body)
                    .foregroundStyle(.secondary)
                    .lineLimit(sizeCategory.isAccessibilityCategory ? 2 : 1)
                    .multilineTextAlignment(.center)
                    .scaledToFit()
                    .minimumScaleFactor(0.8)
                    .enhancedAccessibility(
                        label: "Artist name",
                        value: audioService?.currentTrack?.artist ?? "No Artist"
                    )

                if let album = audioService?.currentTrack?.album {
                    Text(album)
                        .font(sizeCategory.isAccessibilityCategory ? .caption : .caption)
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(sizeCategory.isAccessibilityCategory ? 2 : 1)
                        .multilineTextAlignment(.center)
                        .scaledToFit()
                        .minimumScaleFactor(0.8)
                        .enhancedAccessibility(
                            label: "Album name",
                            value: album
                        )
                }
            }
        }
        .padding(.horizontal, adaptiveHorizontalPadding)
        .padding(.vertical, sizeCategory.isAccessibilityCategory ? 32 : 28)
        .a11yAwareGlass(style: .thick, tint: dominantColor.opacity(0.32), cornerRadius: 20)
        .glassEffectID("trackInfo", in: animationNamespace)
        .audioContextAccessibility(
            isPlaying: audioService?.isPlaying ?? false,
            trackTitle: audioService?.currentTrack?.title,
            artist: audioService?.currentTrack?.artist,
            progress: audioService?.playbackProgress,
            duration: audioService?.duration
        )
    }

    // MARK: - Compact Track Info (for no-scroll layout)

    private var compactTrackInfoView: some View {
        HStack(alignment: .center, spacing: 12) {
            // Text on left
            VStack(alignment: .leading, spacing: 2) {
                Text(audioService?.currentTrack?.title ?? "Not Playing")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.4), radius: 2, x: 0, y: 1)

                Text(audioService?.currentTrack?.artist ?? "No Artist")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }

            Spacer()

            // Buttons on right (horizontal)
            HStack(spacing: 8) {
                Button {
                    isFavorite.toggle()
                    logger.debug("Favorite toggled: \(isFavorite, privacy: .public)")
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(isFavorite ? 0.2 : 0.12)))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")

                Button {
                    guard let track = audioService?.currentTrack else { return }
                    trackDetailItem = TrackDetailItem(track: track)
                } label: {
                    Image(systemName: "ellipsis")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(width: 36, height: 36)
                        .background(Circle().fill(.white.opacity(0.12)))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Show track options")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4) // Reduced from 12pt - saves ~16pt
        // Glass removed for lighter visual weight - text shadows provide contrast
        .glassEffectID("compactTrackInfo", in: animationNamespace)
    }

    private var progressView: some View {
        VStack(spacing: sizeCategory.isAccessibilityCategory ? 16 : 12) {
            Slider(
                value: Binding(
                    get: { sliderProgress },
                    set: { newValue in
                        sliderProgress = newValue
                    }
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
            .frame(height: sizeCategory.isAccessibilityCategory ? 40 : 32) // Larger touch target for accessibility
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
                isUserInteracting: isUserDragging
            ))

            // Fixed: Time labels with proper spacing and Dynamic Type
            HStack {
                Text(formatTime(audioService?.currentTime ?? 0))
                    .font(sizeCategory.isAccessibilityCategory ? .body : .caption)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
                    .scaledToFit()
                    .minimumScaleFactor(0.8)
                    .enhancedAccessibility(
                        label: "Current time",
                        value: formatTime(audioService?.currentTime ?? 0)
                    )

                Spacer()

                Text(formatTime(audioService?.duration ?? 0))
                    .font(sizeCategory.isAccessibilityCategory ? .body : .caption)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.75))
                    .scaledToFit()
                    .minimumScaleFactor(0.8)
                    .enhancedAccessibility(
                        label: "Total duration",
                        value: formatTime(audioService?.duration ?? 0)
                    )
            }
        }
        .padding(sizeCategory.isAccessibilityCategory ? 20 : 16)
        .a11yAwareGlass(style: .standard, tint: dominantColor.opacity(0.08), cornerRadius: 16)
    }

    private var playbackControlsView: some View {
        // Fixed: Simplified layout with proper button hierarchy
        HStack(spacing: 0) {
            // Shuffle button (small)
            playbackControlButton(
                systemName: "shuffle",
                size: smallControlSize,
                isActive: isShuffleEnabled,
                glassID: "shuffle",
                accessibilityType: .shuffle,
                accessibilityEnabled: true,
                action: toggleShuffle
            )

            Spacer()

            // Previous button (medium)
            playbackControlButton(
                systemName: "backward.fill",
                size: mediumControlSize,
                fontSize: sizeCategory.isAccessibilityCategory ? 16 : 18,
                glassID: "previous",
                accessibilityType: .previous,
                action: playPrevious
            )

            Spacer()

            // Fixed: Play/pause button with proper hierarchy sizing
            Button {
                togglePlayPause()
            } label: {
                ZStack {
                    Circle()
                        .fill(playAccentColor)
                        .shadow(color: playAccentColor.opacity(0.3), radius: 8, x: 0, y: 2)
                    Image(systemName: audioService?.isPlaying == true ? "pause.fill" : "play.fill")
                        .font(.system(size: sizeCategory.isAccessibilityCategory ? 20 : 24,
                                      weight: .bold, design: .rounded))
                        .foregroundStyle(Color.black.opacity(0.85))
                }
                .frame(width: primaryControlSize, height: primaryControlSize)
            }
            .buttonStyle(.plain)
            .glassEffectID("playPause", in: animationNamespace)
            .glassTransition(isActive: audioService?.isPlaying ?? false)
            .modifier(PlaybackControlAccessibility(
                isPlaying: audioService?.isPlaying ?? false,
                controlType: .playPause,
                isEnabled: true
            ))
            .preferredFrameRate(
                BatteryOptimizedGlassUtilities.optimalFrameRate(for: .interactive)
            )

            Spacer()

            // Next button (medium)
            playbackControlButton(
                systemName: "forward.fill",
                size: mediumControlSize,
                fontSize: sizeCategory.isAccessibilityCategory ? 16 : 18,
                glassID: "next",
                accessibilityType: .next,
                action: playNext
            )

            Spacer()

            // Repeat button (small)
            playbackControlButton(
                systemName: repeatModeIcon,
                size: smallControlSize,
                isActive: repeatMode != .none,
                glassID: "repeat",
                accessibilityType: .repeat,
                action: cycleRepeatMode
            )
        }
        .frame(height: sizeCategory.isAccessibilityCategory ? 70 : 60) // Reduced container height
        .padding(.horizontal, adaptiveHorizontalPadding + 8) // Slightly more padding for better spacing
        .padding(.vertical, sizeCategory.isAccessibilityCategory ? 20 : 16) // Reduced vertical padding
        .a11yAwareGlass(style: .thick, tint: dominantColor.opacity(0.45), cornerRadius: 24) // Smaller corner radius
    }

    private func playbackControlButton(
        systemName: String,
        size: CGFloat? = nil,
        fontSize: CGFloat? = nil,
        isActive: Bool = false,
        glassID: String,
        accessibilityType: PlaybackControlAccessibility.PlaybackControlType,
        accessibilityEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        let buttonSize = size ?? smallControlSize // Default to small size
        // Fixed: Icon sizes proportional to button sizes with proper hierarchy
        let iconSize = fontSize ?? {
            if buttonSize <= smallControlSize {
                return sizeCategory.isAccessibilityCategory ? 14 : 12 // Small buttons get small icons
            } else if buttonSize <= mediumControlSize {
                return sizeCategory.isAccessibilityCategory ? 16 : 18 // Medium buttons get medium icons
            } else {
                return sizeCategory.isAccessibilityCategory ? 20 : 24 // Large buttons get large icons
            }
        }()

        return Button(action: action) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(isActive ? 0.24 : 0.12))
                Image(systemName: systemName)
                    .font(.system(size: iconSize, weight: .medium, design: .rounded)) // Reduced font weight
                    .foregroundStyle(.white.opacity(isActive ? 1.0 : 0.85))
                    .scaledToFit()
            }
            .frame(width: buttonSize, height: buttonSize)
        }
        .buttonStyle(.plain)
        .glassEffectID(glassID, in: animationNamespace)
        .modifier(
            PlaybackControlAccessibility(
                isPlaying: audioService?.isPlaying ?? false,
                controlType: accessibilityType,
                isEnabled: accessibilityEnabled
            )
        )
        .preferredFrameRate(
            BatteryOptimizedGlassUtilities.optimalFrameRate(for: .interactive)
        )
    }

    private var volumeView: some View {
        HStack(spacing: sizeCategory.isAccessibilityCategory ? 20 : 16) {
            Image(systemName: "speaker.fill")
                .font(sizeCategory.isAccessibilityCategory ? .body : .caption)
                .foregroundStyle(.secondary)
                .scaledToFit()
                .enhancedAccessibility(
                    label: "Volume control",
                    hint: "Adjust playback volume"
                )

            Slider(
                value: Binding(
                    get: { volume },
                    set: { newValue in
                        volumeStorage = Double(newValue)
                        Task {
                            guard let audioService else { return }
                            await audioService.setVolume(Float(newValue))
                            logger.debug("Volume updated to \(newValue, privacy: .public)")
                        }
                    }
                ),
                in: 0 ... 1
            ) { editing in
                if editing {
                    logger.debug("Volume slider editing began")
                } else {
                    logger.debug("Volume slider editing ended at \(volumeStorage, privacy: .public)")
                }
            }
            .tint(.white)
            .frame(height: sizeCategory.isAccessibilityCategory ? 32 : 24) // Larger touch target for accessibility
            .modifier(PlaybackControlAccessibility(
                isPlaying: audioService?.isPlaying ?? false,
                controlType: .volume,
                isEnabled: true
            ))

            Image(systemName: "speaker.wave.3.fill")
                .font(sizeCategory.isAccessibilityCategory ? .body : .caption)
                .foregroundStyle(.secondary)
                .scaledToFit()
                .enhancedAccessibility(
                    label: "Volume level indicator",
                    value: "\(Int(volume * 100)) percent"
                )
        }
        .padding(sizeCategory.isAccessibilityCategory ? 24 : 20)
        .frame(maxWidth: .infinity)
        .a11yAwareGlass(style: .thick, tint: dominantColor.opacity(0.18), cornerRadius: 20)
    }

    // MARK: - Compact Progress View (for no-scroll layout)

    private var compactProgressView: some View {
        VStack(spacing: 6) {
            Slider(
                value: Binding(
                    get: { sliderProgress },
                    set: { newValue in
                        sliderProgress = newValue
                    }
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
            .frame(height: 28)

            HStack {
                Text(formatTime(audioService?.currentTime ?? 0))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                Spacer()
                Text(formatTime(audioService?.duration ?? 0))
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.white.opacity(0.7))
                    .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
            }
        }
        .padding(.horizontal, 16) // Match track info
        .padding(.vertical, 0) // Removed vertical padding - saves ~16pt
        // Glass removed for lighter visual weight - text shadows provide contrast
    }

    // MARK: - Unified Controls + Volume (for no-scroll layout)

    private var unifiedControlsView: some View {
        VStack(spacing: 8) {
            // Transport row
            HStack(spacing: 0) {
                // Shuffle button
                Button(action: toggleShuffle) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(isShuffleEnabled ? 0.24 : 0.12))
                        Image(systemName: "shuffle")
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(isShuffleEnabled ? 1.0 : 0.85))
                    }
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isShuffleEnabled ? "Shuffle on" : "Shuffle off")

                Spacer()

                // Previous button
                Button(action: playPrevious) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                        Image(systemName: "backward.fill")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Previous track")

                Spacer()

                // Play/pause (keep at 48pt - primary action)
                Button { togglePlayPause() } label: {
                    ZStack {
                        Circle()
                            .fill(playAccentColor)
                            .shadow(color: playAccentColor.opacity(0.3), radius: 6, x: 0, y: 2)
                        Image(systemName: audioService?.isPlaying == true ? "pause.fill" : "play.fill")
                            .font(.system(size: 20, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.black.opacity(0.85))
                    }
                    .frame(width: 48, height: 48)
                }
                .buttonStyle(.plain)
                .glassEffectID("compactPlayPause", in: animationNamespace)
                .accessibilityLabel(audioService?.isPlaying == true ? "Pause" : "Play")

                Spacer()

                // Next button
                Button(action: playNext) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.12))
                        Image(systemName: "forward.fill")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(width: 36, height: 36)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Next track")

                Spacer()

                // Repeat button
                Button(action: cycleRepeatMode) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(repeatMode != .none ? 0.24 : 0.12))
                        Image(systemName: repeatModeIcon)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(repeatMode != .none ? 1.0 : 0.85))
                    }
                    .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(repeatMode == .none ? "Repeat off" : (repeatMode == .one ? "Repeat one" : "Repeat all"))
            }
            .frame(height: 48)

            // Volume row (compact)
            HStack(spacing: 8) {
                Image(systemName: "speaker.fill")
                    .font(.caption2)
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
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .frame(height: 20)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .a11yAwareGlass(style: .thick, tint: dominantColor.opacity(0.4), cornerRadius: 16)
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
        Task { @MainActor in
            await extractDominantColorAsync()
        }
    }

    private func extractDominantColorAsync() async {
        guard let track = audioService?.currentTrack else {
            await MainActor.run {
                dominantColor = .accentColor
            }
            return
        }

        // Check cache first
        if let cached = colorCache[track.id] {
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.5)) {
                    dominantColor = cached
                }
            }
            return
        }

        // Guard concurrent extractions
        guard !isExtractingColor else { return }

        await MainActor.run {
            isExtractingColor = true
        }

        defer {
            Task { @MainActor in
                isExtractingColor = false
            }
        }

        // Extract color from artwork (if available)
        guard let artworkData = track.artwork else {
            await MainActor.run {
                dominantColor = .accentColor
            }
            return
        }

        // Perform extraction on background thread (rebuild UIImage inside detached task)
        let extractedColor = await Task.detached {
            guard let uiImage = UIImage(data: artworkData) else {
                return Color.accentColor
            }
            return uiImage.fastAverageColor ?? .accentColor
        }.value

        // Cache result
        colorCache[track.id] = extractedColor
        maintainColorCache()

        // Update UI with animation
        await MainActor.run {
            withAnimation(.easeInOut(duration: 0.5)) {
                dominantColor = extractedColor
            }
        }
    }

    /// Limits cache to 50 entries
    private func maintainColorCache() {
        let maxCacheSize = 50
        guard colorCache.count > maxCacheSize else { return }

        let overflow = colorCache.count - maxCacheSize
        let keysToRemove = Array(colorCache.keys.prefix(overflow))
        keysToRemove.forEach { colorCache.removeValue(forKey: $0) }
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

// MARK: - iOS 26 Testing & Debug Guidelines

/*
 ## Key Fixes Applied:

 ✅ **Safe Area Handling**
 - Added GeometryReader for proper safe area calculations
 - Dynamic top padding: `max(12, geometry.safeAreaInsets.top + 8)`
 - Dynamic bottom padding: `max(40, geometry.safeAreaInsets.bottom + 20)`
 - Fixed drag handle positioning with proper safe area consideration

 ✅ **Dynamic Type Support**
 - Added @Environment(\.sizeCategory) for Dynamic Type detection
 - Adaptive sizing: `sizeCategory.isAccessibilityCategory ? largerValue : standardValue`
 - .scaledToFit() and .minimumScaleFactor() for text scaling
 - Larger touch targets (40pt vs 32pt) for accessibility categories

 ✅ **Adaptive Spacing & Layout**
 - Computed properties for responsive spacing based on accessibility settings
 - GeometryReader-based responsive button spacing in playback controls
 - LazyVStack for performance with large accessibility text
 - .scrollContentBackground(.hidden) for proper iOS 16+ background handling

 ✅ **Text Spacing & Alignment**
 - Removed hardcoded negative padding (.padding(.top, -2))
 - Proper VStack spacing with accessibility-aware values
 - .multilineTextAlignment(.center) for better accessibility
 - Line limit increases (1→2) for accessibility categories

 ## Testing on Different Device Sizes:

 ### iPhone Testing:
 ```swift
 #Preview("iPhone 15 Pro") {
     @Previewable @Namespace var namespace
     NowPlayingView(animationNamespace: namespace)
         .previewDevice("iPhone 15 Pro")
         .previewDisplayName("Standard iPhone")
 }

 #Preview("iPhone 15 Pro Max") {
     @Previewable @Namespace var namespace
     NowPlayingView(animationNamespace: namespace)
         .previewDevice("iPhone 15 Pro Max")
 }
 ```

 ### Accessibility Testing:
 ```swift
 #Preview("Large Text") {
     @Previewable @Namespace var namespace
     NowPlayingView(animationNamespace: namespace)
         .environment(\.sizeCategory, .accessibilityExtraExtraExtraLarge)
 }

 #Preview("Reduce Motion") {
     @Previewable @Namespace var namespace
     NowPlayingView(animationNamespace: namespace)
         .environment(\.accessibilityReduceMotion, true)
 }
 ```

 ### Dark Mode Testing:
 ```swift
 #Preview("Dark Mode") {
     @Previewable @Namespace var namespace
     NowPlayingView(animationNamespace: namespace)
         .preferredColorScheme(.dark)
 }
 ```

 ## iOS 26-Specific Updates:

 ### Deprecated APIs to Watch:
 - `.ignoresSafeArea()` → `.ignoresSafeArea(edges:)` (more specific)
 - `.padding(.top, 8)` → `.safeAreaPadding(.top, 8)` for safe area-relative padding
 - Manual VStack spacing → Adaptive spacing based on @Environment(\.sizeCategory)

 ### New iOS 26 APIs Utilized:
 - `.scrollContentBackground(.hidden)` for proper background control
 - Enhanced `.containerRelativeFrame` with minimum size constraints
 - `.glassPerformanceProfiled()` for Liquid Glass performance monitoring
 - `.adaptiveGlassPerformance()` for battery-optimized glass effects

 ## Debug View Hierarchy in Xcode:

 ### Visual Debugging:
 1. Run on device/simulator
 2. Pause execution in Xcode
 3. Click "Debug View Hierarchy" button (📱 icon)
 4. Inspect layers, especially:
    - Safe area constraints
    - Glass effect boundaries
    - Text truncation/scaling
    - Button touch targets

 ### UIViewRepresentable Wrapper (if needed):
 ```swift
 struct DebugViewWrapper<Content: View>: UIViewRepresentable {
     let content: Content

     func makeUIView(context: Context) -> UIView {
         let hostingController = UIHostingController(rootView: content)
         hostingController.view.backgroundColor = .clear
         return hostingController.view
     }

     func updateUIView(_ uiView: UIView, context: Context) {}
 }

 // Usage for specific problematic views:
 DebugViewWrapper(content: trackInfoView)
 ```

 ### Accessibility Inspector:
 - Enable in Xcode: Developer Tools → Accessibility Inspector
 - Test with real accessibility settings enabled on device
 - Verify VoiceOver navigation paths
 - Check contrast ratios with Liquid Glass backgrounds

 ## Performance Monitoring:

 The `.glassPerformanceProfiled()` modifiers help identify performance bottlenecks:
 - Watch for excessive glass effect rendering
 - Monitor frame rates during animations
 - Check memory usage with large artwork images
 - Use `.adaptiveGlassPerformance()` to automatically optimize based on device capabilities
 */
