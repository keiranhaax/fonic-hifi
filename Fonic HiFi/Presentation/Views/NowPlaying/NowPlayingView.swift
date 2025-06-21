//
//  NowPlayingView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import SwiftUI

@MainActor
struct NowPlayingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var audioService: AudioEngineFacade
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Animation namespace from parent
    let animationNamespace: Namespace.ID
    
    // Drag gesture state
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // UI State
    @State private var showingQueue = false
    @State private var dominantColor: Color = .accentColor
    @State private var hasStartedPlayback = false
    
    // Slider state for progress control
    @State private var sliderProgress: Double = 0.0
    @State private var isUserDragging: Bool = false
    
    // Constants
    private let artworkSize: CGFloat = 320
    private let dismissThreshold: CGFloat = 150
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    dominantColor.opacity(0.6),
                    dominantColor.opacity(0.3),
                    Color.black.opacity(0.8)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Drag handle
                Capsule()
                    .fill(Color.white.opacity(0.5))
                    .frame(width: 36, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 20)
                
                // Main content
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 32) {
                        // Album artwork
                        albumArtworkView
                            .padding(.horizontal, 40)
                            .padding(.top, 20)
                        
                        // Track info
                        trackInfoView
                            .padding(.horizontal, 40)
                        
                        // Progress bar
                        progressView
                            .padding(.horizontal, 40)
                        
                        // Playback controls
                        playbackControlsView
                            .padding(.horizontal, 40)
                        
                        // Volume slider
                        volumeView
                            .padding(.horizontal, 40)
                            .padding(.bottom, 40)
                    }
                }
            }
        }
        .offset(y: max(0, dragOffset))
        .scaleEffect(isDragging ? 0.95 : 1.0)
        .animation(reduceMotion ? .none : .interactiveSpring(response: 0.4, dampingFraction: 0.8), value: isDragging)
        .gesture(dismissGesture)
        .task {
            print("=== NOW PLAYING VIEW TASK ===")
            print("Has started playback: \(hasStartedPlayback)")
            print("Current track object: \(appState.currentTrackObject?.title ?? "nil")")
            
            extractDominantColor()
            
            // Start audio playback after the view has loaded
            guard !hasStartedPlayback, let track = appState.currentTrackObject else {
                print("Not starting playback - hasStartedPlayback: \(hasStartedPlayback), track: \(appState.currentTrackObject?.title ?? "nil")")
                return
            }
            
            hasStartedPlayback = true
            
            print("\n=== AUDIO PLAYBACK DEBUG ===")
            print("1. Starting playback for: \(track.title ?? "Unknown")")
            print("2. Track file path: \(track.url.path)")
            print("3. Track artist: \(track.artist ?? "Unknown")")
            print("4. Track duration: \(track.duration)")
            print("5. Track format: \(track.audioFormat ?? "Unknown")")
            
            // Check if file exists
            if FileManager.default.fileExists(atPath: track.url.path) {
                print("6. ✅ File exists at path")
            } else {
                print("6. ❌ File NOT found at path")
            }
            
            // Check audio service state
            print("7. Audio service ready: \(audioService.isReady)")
            print("8. Audio service current track: \(audioService.currentTrack?.title ?? "nil")")
            print("9. Audio service is playing: \(audioService.isPlaying)")
            
            // Ensure audio service is ready
            guard audioService.isReady else {
                print("10. ❌ Audio service not ready yet")
                return
            }
            
            print("11. Calling audioService.play")
            
            // Start audio playback
            do {
                try await audioService.play(track: track)
                print("12. ✅ audioService.play completed successfully")
                
                // Check audio state after play
                print("13. Post-play is playing: \(audioService.isPlaying)")
                print("14. Post-play current track: \(audioService.currentTrack?.title ?? "nil")")
                print("15. Post-play app state is playing: \(appState.isPlaying)")
                
            } catch {
                print("12. ❌ Failed to start audio playback: \(error)")
                print("    Error type: \(type(of: error))")
                print("    Error description: \(error.localizedDescription)")
                
                // Reset state if playback failed
                appState.setCurrentTrack(nil)
                appState.hideNowPlaying()
            }
            
            print("=== END AUDIO PLAYBACK DEBUG ===\n")
        }
    }
    
    // MARK: - Subviews
    
    private var albumArtworkView: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color.gray.opacity(0.3))
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: artworkSize)
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: 80))
                    .foregroundColor(.white.opacity(0.5))
            )
            .matchedGeometryEffect(id: "artwork", in: animationNamespace)
            .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
    }
    
    private var trackInfoView: some View {
        VStack(spacing: 8) {
            Text(appState.currentTrack?.title ?? "Not Playing")
                .font(.title2)
                .fontWeight(.semibold)
                .lineLimit(1)
                .matchedGeometryEffect(id: "title", in: animationNamespace)
            
            Text(appState.currentTrack?.artist ?? "No Artist")
                .font(.body)
                .foregroundColor(.secondary)
                .lineLimit(1)
                .matchedGeometryEffect(id: "artist", in: animationNamespace)
            
            if let album = appState.currentTrack?.album {
                Text(album)
                    .font(.caption)
                    .foregroundColor(.secondary.opacity(0.8))
                    .lineLimit(1)
            }
        }
    }
    
    private var progressView: some View {
        VStack(spacing: 8) {
            // Progress slider
            Slider(value: $sliderProgress, in: 0...1) { isDragging in
                isUserDragging = isDragging
                if !isDragging {
                    // Seek to position when user finishes dragging
                    // Slider callbacks may run on background thread
                    Task { @MainActor in
                        do {
                            let seekTime = sliderProgress * appState.duration
                            try await audioService.seek(to: seekTime)
                        } catch {
                            print("Failed to seek: \(error)")
                        }
                    }
                }
            }
            .tint(.white)
            .onChange(of: appState.playbackProgress) { _, newValue in
                // Update slider only if user is not dragging
                if !isUserDragging {
                    sliderProgress = newValue
                }
            }
            .onAppear {
                // Initialize slider with current progress
                sliderProgress = appState.playbackProgress
            }
            
            // Time labels
            HStack {
                Text(formatTime(appState.currentTime))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
                
                Spacer()
                
                Text(formatTime(appState.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .monospacedDigit()
            }
        }
    }
    
    private var playbackControlsView: some View {
        HStack(spacing: 40) {
            // Shuffle button
            Button(action: toggleShuffle) {
                Image(systemName: "shuffle")
                    .font(.title3)
                    .foregroundColor(appState.isShuffleEnabled ? .accentColor : .white)
            }
            
            // Previous button
            Button(action: playPrevious) {
                Image(systemName: "backward.fill")
                    .font(.title)
            }
            
            // Play/Pause button
            Button(action: togglePlayPause) {
                Image(systemName: appState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 64))
            }
            .matchedGeometryEffect(id: "playButton", in: animationNamespace)
            
            // Next button
            Button(action: playNext) {
                Image(systemName: "forward.fill")
                    .font(.title)
            }
            
            // Repeat button
            Button(action: cycleRepeatMode) {
                Image(systemName: repeatModeIcon)
                    .font(.title3)
                    .foregroundColor(appState.repeatMode != .none ? .accentColor : .white)
            }
        }
        .foregroundColor(.white)
    }
    
    private var volumeView: some View {
        HStack(spacing: 16) {
            Image(systemName: "speaker.fill")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Slider(value: $appState.volume, in: 0...1) { _ in
                // Update volume
                // TODO: Implement volume control when available in AudioEngineFacade
                // Task {
                //     await audioService.setVolume(appState.volume)
                // }
            }
            .tint(.white)
            
            Image(systemName: "speaker.wave.3.fill")
                .font(.caption)
                .foregroundColor(.secondary)
        }
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
                            appState.hideNowPlaying()
                        }
                    }
                }
            }
    }
    
    // MARK: - Helpers
    
    private var repeatModeIcon: String {
        switch appState.repeatMode {
        case .none:
            return "repeat"
        case .all:
            return "repeat"
        case .one:
            return "repeat.1"
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
            do {
                if appState.isPlaying {
                    await audioService.pause()
                } else {
                    try await audioService.resume()
                }
            } catch {
                print("Failed to toggle playback: \(error)")
            }
        }
    }
    
    private func playNext() {
        Task { @MainActor in
            do {
                try await audioService.playNext()
            } catch {
                print("Failed to play next: \(error)")
            }
        }
    }
    
    private func playPrevious() {
        Task { @MainActor in
            do {
                try await audioService.playPrevious()
            } catch {
                print("Failed to play previous: \(error)")
            }
        }
    }
    
    private func toggleShuffle() {
        Task { @MainActor in
            let newMode: QueueShuffleMode = appState.isShuffleEnabled ? .off : .random
            audioService.setShuffleMode(newMode)
            appState.isShuffleEnabled = newMode != .off
        }
    }
    
    private func cycleRepeatMode() {
        Task { @MainActor in
            let newMode: QueueRepeatMode
            switch appState.repeatMode {
            case .none:
                newMode = .all
            case .all:
                newMode = .one
            case .one:
                newMode = .none
            }
            audioService.setRepeatMode(newMode)
            appState.repeatMode = newMode
        }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    return NowPlayingView(animationNamespace: namespace)
        .environmentObject(AppState())
        .environmentObject(AudioEngineFacade())
}