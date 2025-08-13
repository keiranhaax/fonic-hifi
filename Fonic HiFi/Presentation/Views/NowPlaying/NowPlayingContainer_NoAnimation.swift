//
//  NowPlayingContainer_NoAnimation.swift
//  Fonic HiFi
//
//  Version without matched geometry effects to test if that's the issue
//

import SwiftUI

/// Container without animations to test if matched geometry is the issue
@MainActor
struct NowPlayingContainer_NoAnimation: View {
    @Environment(\.audioEngine) private var audioService: AudioEngineFacade?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Binding var showingNowPlaying: Bool
    
    var body: some View {
        ZStack(alignment: .bottom) {
            // Mini player
            if audioService?.showMiniPlayer == true && !showingNowPlaying {
                MiniPlayerView_NoAnimation(showingNowPlaying: $showingNowPlaying)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1)
            }
            
            // Full Now Playing view
            if showingNowPlaying {
                NowPlayingView_NoAnimation(showingNowPlaying: $showingNowPlaying)
                    .transition(.opacity)
                    .zIndex(2)
                    .onAppear {
                        print("=== NOW PLAYING CONTAINER APPEARED ===")
                        print("App state showingNowPlaying: \(showingNowPlaying)")
                        print("Current track: \(audioService?.currentTrack?.title ?? "nil")")
                    }
            }
        }
        .animation(
            reduceMotion ? .none : .easeInOut(duration: 0.3),
            value: showingNowPlaying
        )
    }
}

/// Mini player without matched geometry
@MainActor
struct MiniPlayerView_NoAnimation: View {
    @Environment(\.audioEngine) private var audioService: AudioEngineFacade?
    @Binding var showingNowPlaying: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator pill
            Capsule()
                .fill(Color.primary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 6)
                .padding(.bottom, 4)
            
            // Main content
            HStack(spacing: 12) {
                // Album artwork - NO MATCHED GEOMETRY
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "music.note")
                            .foregroundColor(.secondary)
                    )
                
                // Track info - NO MATCHED GEOMETRY
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioService?.currentTrack?.title ?? "Not Playing")
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                    
                    Text(audioService?.currentTrack?.artist ?? "No Artist")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // Playback controls
                HStack(spacing: 20) {
                    // Play/Pause button - NO MATCHED GEOMETRY
                    Button(action: togglePlayPause) {
                        Image(systemName: audioService?.isPlaying == true ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 24, height: 24)
                    }
                    
                    // Next button
                    Button(action: playNext) {
                        Image(systemName: "forward.fill")
                            .font(.body)
                    }
                }
                .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 10)
        }
        .frame(height: 74)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
        .onTapGesture {
            print("Mini player tapped - showing Now Playing")
            showingNowPlaying = true
        }
    }
    
    private func togglePlayPause() {
        Task { @MainActor in
            guard let audioService = audioService else { return }
            if audioService.isPlaying {
                await audioService.pause()
            } else {
                try? await audioService.resume()
            }
        }
    }
    
    private func playNext() {
        Task { @MainActor in
            guard let audioService = audioService else { return }
            try? await audioService.playNext()
        }
    }
}

/// Now Playing view without matched geometry
@MainActor
struct NowPlayingView_NoAnimation: View {
    @Environment(\.audioEngine) private var audioService: AudioEngineFacade?
    @Binding var showingNowPlaying: Bool
    @State private var hasStartedPlayback = false
    
    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(0.9)
                .ignoresSafeArea()
            
            VStack(spacing: 32) {
                // Header with close button
                HStack {
                    Button("Close") {
                        showingNowPlaying = false
                    }
                    .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                // Album artwork - NO MATCHED GEOMETRY
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.gray.opacity(0.3))
                    .aspectRatio(1, contentMode: .fit)
                    .frame(maxWidth: 300)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 80))
                            .foregroundColor(.white.opacity(0.5))
                    )
                
                // Track info - NO MATCHED GEOMETRY
                VStack(spacing: 8) {
                    Text(audioService?.currentTrack?.title ?? "Not Playing")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    Text(audioService?.currentTrack?.artist ?? "No Artist")
                        .font(.body)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                // Play button - NO MATCHED GEOMETRY
                Button(action: togglePlayPause) {
                    Image(systemName: audioService?.isPlaying == true ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 64))
                        .foregroundColor(.white)
                }
                
                Spacer()
            }
            .padding()
        }
        .onAppear {
            print("=== NOW PLAYING VIEW NO ANIMATION APPEARED ===")
            print("Has started playback: \(hasStartedPlayback)")
            print("Current track: \(audioService?.currentTrack?.title ?? "nil")")
            
            // Start audio playback after the view has appeared
            if !hasStartedPlayback, let audioService = audioService, let track = audioService.currentTrack {
                hasStartedPlayback = true
                
                Task { @MainActor in
                    print("\n=== AUDIO PLAYBACK DEBUG (NO ANIMATION) ===")
                    print("1. Starting playback for: \(track.title)")
                    print("2. Track file path: \(track.url.path)")
                    print("3. Track artist: \(track.artist)")
                    print("4. Track duration: \(track.duration)")
                    print("5. Track format: \(track.audioFormat)")
                    
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
                        print("15. Post-play audio service is playing: \(audioService.isPlaying)")
                        
                    } catch {
                        print("12. ❌ Failed to start audio playback: \(error)")
                        print("    Error type: \(type(of: error))")
                        print("    Error description: \(error.localizedDescription)")
                        
                        // Reset state if playback failed
                        audioService.setCurrentTrack(nil)
                        showingNowPlaying = false
                    }
                    
                    print("=== END AUDIO PLAYBACK DEBUG (NO ANIMATION) ===\n")
                }
            } else {
                print("Not starting playback - hasStartedPlayback: \(hasStartedPlayback), track: \(audioService?.currentTrack?.title ?? "nil")")
            }
        }
    }
    
    private func togglePlayPause() {
        Task { @MainActor in
            guard let audioService = audioService else { return }
            if audioService.isPlaying {
                await audioService.pause()
            } else {
                try? await audioService.resume()
            }
        }
    }
}

#Preview {
    @Previewable @State var showingNowPlaying = false
    return NowPlayingContainer_NoAnimation(showingNowPlaying: $showingNowPlaying)
        .audioEngine(AudioEngineFacade())
}