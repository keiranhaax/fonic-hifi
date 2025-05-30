//
//  TrackRowView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import SwiftUI

/// Individual track row component used in track lists
@MainActor
struct TrackRowView: View {
    let track: Track
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var audioService: AudioEngineFacade
    
    var body: some View {
        HStack(spacing: 12) {
            // Track number or playing indicator
            ZStack {
                if appState.currentTrack?.id == track.id && appState.isPlaying {
                    Image(systemName: "speaker.wave.2.fill")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                } else {
                    Text("\(track.trackNumber ?? 0)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 24)
            
            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .lineLimit(1)
                
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Duration
            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
                .monospacedDigit()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            playTrack()
        }
        .opacity(audioService.isReady ? 1.0 : 0.6) // Visual feedback for initialization state
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
    
    @MainActor
    private func playTrack() {
        print("=== TRACK ROW TAP - UI STATE ONLY ===")
        print("Track to play: \(track.title ?? "Unknown")")
        
        // Only update UI state - let NowPlayingView handle audio playback
        appState.setCurrentTrack(track)
        appState.showingNowPlaying = true
        
        print("currentTrackObject set: \(appState.currentTrackObject != nil)")
        print("showingNowPlaying: \(appState.showingNowPlaying)")
        print("UI state updated - Now Playing view will handle audio playback")
    }
}

private func makePreviewTrack() -> Track {
    let track = Track(
        url: URL(fileURLWithPath: "/sample.mp3"),
        title: "Sample Track",
        artist: "Sample Artist",
        album: "Sample Album",
        audioFormat: "MP3",
        duration: 180
    )
    track.trackNumber = 1
    return track
}

#Preview {
    TrackRowView(track: makePreviewTrack())
        .environmentObject(AppState())
        .environmentObject(AudioEngineFacade())
}