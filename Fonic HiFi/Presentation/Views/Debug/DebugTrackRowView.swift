//
//  DebugTrackRowView.swift
//  Fonic HiFi
//
//  Debug version with extensive logging
//

import SwiftUI

/// Debug version of TrackRowView with extensive logging
@MainActor
struct DebugTrackRowView: View {
    let track: Track
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var audioService: AudioEngineFacade
    
    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(track.title)
                    .font(.body)
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            debugPlayTrack()
        }
    }
    
    private func debugPlayTrack() {
        print("\n=== DEBUG TRACK TAP START ===")
        print("1. Tap gesture triggered")
        print("   isMainThread: \(Thread.isMainThread)")
        print("   Queue: \(String(cString: __dispatch_queue_get_label(nil)))")
        
        Task { @MainActor in
            print("\n2. Inside Task block")
            print("   Queue: \(String(cString: __dispatch_queue_get_label(nil)))")
            
            // Verify precondition
            dispatchPrecondition(condition: .onQueue(.main))
            print("3. Dispatch precondition passed - we are on main queue")
            
            // Update app state
            print("\n4. About to update appState.currentTrack")
            print("   Current track before: \(appState.currentTrack?.title ?? "nil")")
            appState.setCurrentTrack(track)
            print("   Current track after: \(appState.currentTrack?.title ?? "nil")")
            
            // Show Now Playing
            print("\n5. About to set showingNowPlaying = true")
            print("   showingNowPlaying before: \(appState.showingNowPlaying)")
            
            // Try different approaches to see which crashes
            
            // Approach 1: Direct set
            // appState.showingNowPlaying = true
            
            // Approach 2: Via method
            appState.showNowPlaying()
            
            // Approach 3: With animation
            // withAnimation {
            //     appState.showingNowPlaying = true
            // }
            
            print("   showingNowPlaying after: \(appState.showingNowPlaying)")
            
            // Play audio
            print("\n6. About to call audioService.play")
            do {
                try await audioService.play(track: track)
                print("7. audioService.play completed successfully")
            } catch {
                print("7. audioService.play failed: \(error)")
            }
            
            print("\n=== DEBUG TRACK TAP END ===\n")
        }
    }
}

#Preview {
    DebugTrackRowView(track: Track(
        url: URL(fileURLWithPath: "/test.mp3"),
        title: "Test Track",
        artist: "Test Artist",
        album: "Test Album",
        audioFormat: "MP3",
        duration: 180
    ))
    .environmentObject(AppState())
    .environmentObject(AudioEngineFacade())
}