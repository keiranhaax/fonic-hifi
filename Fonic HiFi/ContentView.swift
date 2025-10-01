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
    @State private var searchText = ""

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house.fill") {
                HomeView()
                    .environment(\.showingNowPlaying, $showingNowPlaying)
            }

            Tab("Library", systemImage: "music.note.list") {
                LibraryView()
                    .environment(\.showingNowPlaying, $showingNowPlaying)
            }

            Tab("Settings", systemImage: "gear") {
                SettingsView()
            }

            Tab("Search", systemImage: "magnifyingglass", role: .search) {
                NavigationStack {
                    SearchView(searchText: $searchText)
                        .searchable(text: $searchText, placement: .toolbar, prompt: Text("Search Library"))
                        .environment(\.showingNowPlaying, $showingNowPlaying)
                        .environment(\.audioEngine, audioService)
                        .environment(\.importService, importService)
                }
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
            NowPlayingView(animationNamespace: miniPlayerNamespace)
                .navigationTransition(.zoom(sourceID: "miniplayer", in: miniPlayerNamespace))
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
