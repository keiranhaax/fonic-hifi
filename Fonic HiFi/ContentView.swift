//
//  ContentView.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import SwiftUI

@MainActor
struct ContentView: View {
    @Environment(\.dataManager) private var dataManager
    @Environment(\.importService) private var importService
    @Environment(\.audioEngine) private var audioService

    @Namespace private var miniPlayerNamespace
    @State private var showingNowPlaying = false
    @State private var selectedDetent: PresentationDetent = .medium

    var body: some View {
        TabView {
            LibraryView()
                .environment(\.showingNowPlaying, $showingNowPlaying)
                .tabItem {
                    Label("Library", systemImage: "music.note.list")
                }

            SearchView()
                .environment(\.showingNowPlaying, $showingNowPlaying)
                .environment(\.audioEngine, audioService)
                .environment(\.importService, importService)
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
        }
        .preferredColorScheme(.dark)
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory {
            if let audioService, !showingNowPlaying {
                LiquidGlassMiniPlayer(
                    namespace: miniPlayerNamespace,
                    showingNowPlaying: $showingNowPlaying,
                )
                .environment(\.audioEngine, audioService)
            }
        }
        .sheet(isPresented: $showingNowPlaying) {
            NavigationStack {
                NowPlayingView(animationNamespace: miniPlayerNamespace)
                    .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
                    .toolbar(.hidden, for: .navigationBar)
            }
            .environment(\.audioEngine, audioService)
            .presentationDetents([
                .medium,
                .large,
            ], selection: $selectedDetent)
            .presentationBackgroundInteraction(.enabled(upThrough: .medium))
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(20)
        }
    }
}

#Preview {
    if let importService = DataManager.makePreviewImportService() {
        ContentView()
            .importService(importService)
            .audioEngine(AudioEngineFacade())
    } else {
        ContentView()
            .audioEngine(AudioEngineFacade())
    }
}
