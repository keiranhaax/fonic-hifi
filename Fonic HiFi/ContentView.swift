//
//  ContentView.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.importService) private var importService
    @Environment(\.audioEngine) private var audioService
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    // Now Playing presentation state managed locally
    @State private var showingNowPlaying = false
    
    var body: some View {
        ZStack {
            // Main content with scaling effect
            TabView {
            // Library Tab
            LibraryView()
                .environment(\.showingNowPlaying, $showingNowPlaying)
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }
            
            // Now Playing Tab
            NavigationStack {
                Text("Now Playing")
                    .navigationTitle("Now Playing")
            }
            .tabItem {
                Label("Now Playing", systemImage: "play.circle.fill")
            }
            
            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .preferredColorScheme(.dark) // Dark mode by default
        .scaleEffect(showingNowPlaying ? 0.95 : 1.0)
        .animation(
            reduceMotion ? .none : .interactiveSpring(response: 0.6, dampingFraction: 0.8),
            value: showingNowPlaying
        )
        .disabled(showingNowPlaying)
        
        // Now Playing overlay
        // TEMPORARY: Using no-animation version to debug crash
        NowPlayingContainer_NoAnimation(showingNowPlaying: $showingNowPlaying)
        // NowPlayingContainer(showingNowPlaying: $showingNowPlaying)
        }
    }
}

#Preview {
    ContentView()
        .importService(DataManager.makePreviewImportService())
        .audioEngine(AudioEngineFacade())
}
