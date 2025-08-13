//
//  MiniPlayerView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import SwiftUI

@MainActor
struct MiniPlayerView: View {
    @Environment(\.audioEngine) private var audioService
    @Environment(\.showingNowPlaying) private var showingNowPlaying
    let animationNamespace: Namespace.ID
    
    // Drag gesture state
    @GestureState private var dragOffset: CGFloat = 0
    @State private var isDragging = false
    
    // Constants
    private let miniPlayerHeight: CGFloat = 64
    private let pillHeight: CGFloat = 4
    private let pillWidth: CGFloat = 36
    private let albumArtSize: CGFloat = 48
    private let dragThreshold: CGFloat = 150
    
    var body: some View {
        VStack(spacing: 0) {
            // Drag indicator pill
            Capsule()
                .fill(Color.primary.opacity(0.3))
                .frame(width: pillWidth, height: pillHeight)
                .padding(.top, 6)
                .padding(.bottom, 4)
            
            // Main content
            HStack(spacing: 12) {
                // Album artwork
                if audioService?.currentTrack != nil {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: albumArtSize, height: albumArtSize)
                        .overlay(
                            Image(systemName: "music.note")
                                .foregroundColor(.secondary)
                        )
                        .matchedGeometryEffect(id: "artwork", in: animationNamespace)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: albumArtSize, height: albumArtSize)
                }
                
                // Track info
                VStack(alignment: .leading, spacing: 2) {
                    Text(audioService?.currentTrack?.title ?? "Not Playing")
                        .font(.body)
                        .fontWeight(.medium)
                        .lineLimit(1)
                        .matchedGeometryEffect(id: "title", in: animationNamespace)
                    
                    Text(audioService?.currentTrack?.artist ?? "No Artist")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                        .matchedGeometryEffect(id: "artist", in: animationNamespace)
                }
                
                Spacer()
                
                // Playback controls
                HStack(spacing: 20) {
                    // Play/Pause button
                    Button(action: togglePlayPause) {
                        Image(systemName: audioService?.isPlaying == true ? "pause.fill" : "play.fill")
                            .font(.title3)
                            .frame(width: 24, height: 24)
                    }
                    .matchedGeometryEffect(id: "playButton", in: animationNamespace)
                    
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
        .frame(height: miniPlayerHeight + pillHeight + 10)
        .background(
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()
        )
        .offset(y: dragOffset)
        .gesture(
            DragGesture()
                .updating($dragOffset) { value, state, _ in
                    if value.translation.height < 0 {
                        // Dragging up
                        state = value.translation.height
                    }
                }
                .onChanged { value in
                    // Gesture callbacks may run on background thread
                    Task { @MainActor in
                        isDragging = true
                    }
                }
                .onEnded { value in
                    // Gesture callbacks may run on background thread
                    Task { @MainActor in
                        isDragging = false
                        
                        // Check if we've passed the threshold or have sufficient velocity
                        let shouldExpand = value.translation.height < -dragThreshold ||
                                         (value.translation.height < -50 && value.predictedEndTranslation.height < -200)
                        
                        if shouldExpand {
                            // Haptic feedback
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            
                            // Show full Now Playing view
                            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
                                showingNowPlaying.wrappedValue = true
                            }
                        }
                    }
                }
        )
        .onTapGesture {
            // Tap to expand
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
            
            withAnimation(.interactiveSpring(response: 0.6, dampingFraction: 0.8)) {
                showingNowPlaying.wrappedValue = true
            }
        }
    }
    
    // MARK: - Actions
    
    private func togglePlayPause() {
        Task { @MainActor in
            guard let audioService = audioService else { return }
            do {
                if audioService.isPlaying {
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
            guard let audioService = audioService else { return }
            do {
                try await audioService.playNext()
            } catch {
                print("Failed to play next: \(error)")
            }
        }
    }
}

#Preview {
    @Previewable @Namespace var namespace
    @Previewable @State var showingNowPlaying = false
    return MiniPlayerView(animationNamespace: namespace)
        .environment(\.showingNowPlaying, $showingNowPlaying)
        .audioEngine(AudioEngineFacade())
}