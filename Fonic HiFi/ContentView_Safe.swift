//
//  ContentView_Safe.swift
//  Fonic HiFi
//
//  Safer version using sheet presentation instead of overlay
//

import SwiftUI

@MainActor
struct ContentView_Safe: View {
    @Environment(\.importService) private var importService
    @Environment(\.audioEngine) private var audioService
    @Environment(\.libraryRepository) private var libraryRepository
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Namespace private var animationNamespace
    @State private var showingNowPlaying = false

    var body: some View {
        TabView {
            // Library Tab
            Group {
                if let repository = libraryRepository {
                    LibraryView(viewModel: LibraryViewModel(repository: repository))
                } else {
                    Text("Library unavailable")
                        .foregroundStyle(.secondary)
                }
            }
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
            if let audioService {
                NowPlayingView(animationNamespace: animationNamespace)
                    .audioEngine(audioService)
                    .interactiveDismissDisabled(false)
            } else {
                Text("Audio engine unavailable.")
            }
        }
        // Mini player at bottom when track is playing but Now Playing is not shown
        .safeAreaInset(edge: .bottom) {
            if let audioService, audioService.currentTrack != nil, !showingNowPlaying {
                MiniPlayerView()
                    .audioEngine(audioService)
            }
        }
    }
}

#Preview {
    if let importService = DataManager.makePreviewImportService() {
        ContentView_Safe()
            .importService(importService)
            .audioEngine(AudioEngineFacade())
    } else {
        ContentView_Safe()
            .audioEngine(AudioEngineFacade())
    }
}
