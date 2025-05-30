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
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var audioService: AudioEngineFacade
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    
    @Namespace private var animationNamespace
    
    var body: some View {
        TabView {
            // Library Tab
            LibraryView()
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
        .sheet(isPresented: $appState.showingNowPlaying) {
            NowPlayingView(animationNamespace: animationNamespace)
                .environmentObject(appState)
                .environmentObject(audioService)
                .interactiveDismissDisabled(false)
        }
        // Mini player at bottom when track is playing but Now Playing is not shown
        .safeAreaInset(edge: .bottom) {
            if appState.showMiniPlayer && !appState.showingNowPlaying {
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
        .environmentObject(AppState())
        .environmentObject(AudioEngineFacade())
}