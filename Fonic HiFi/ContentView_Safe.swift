//
//  ContentView_Safe.swift
//  Fonic HiFi
//
//  Safer version using sheet presentation instead of overlay
//

import SwiftUI

@MainActor
struct ContentView_Safe: View {
    @EnvironmentObject private var importService: LibraryImportService
    @EnvironmentObject private var audioService: AudioEngineFacade
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Namespace private var animationNamespace
    @State private var showingNowPlaying = false
    
    var body: some View {
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
            NavigationStack {
                Text("Settings")
                    .navigationTitle("Settings")
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
        }
        .preferredColorScheme(.dark) // Dark mode by default
        // Use sheet presentation instead of overlay
        .sheet(isPresented: $showingNowPlaying) {
            NowPlayingView(animationNamespace: animationNamespace)
                .environmentObject(appState)
                .environmentObject(audioService)
                .interactiveDismissDisabled(false)
        }
        // Mini player at bottom when track is playing but Now Playing is not shown
        .safeAreaInset(edge: .bottom) {
            if appState.showMiniPlayer && !showingNowPlaying {
                MiniPlayerView(animationNamespace: animationNamespace)
                    .environmentObject(appState)
                    .environmentObject(audioService)
            }
        }
    }
}

#Preview {
    ContentView_Safe()
        .environmentObject(DataManager.makePreviewImportService())
        .environmentObject(AudioEngineFacade())
}