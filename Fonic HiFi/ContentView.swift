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
    
    @Namespace private var miniPlayerNamespace
    @State private var showingNowPlaying = false
    
    var body: some View {
        if #available(iOS 26, *) {
            NavigationStack {
                TabView {
                    LibraryView()
                        .environment(\.showingNowPlaying, $showingNowPlaying)
                        .tabItem {
                            Label("Library", systemImage: "music.note.list")
                        }

                    Text("Now Playing")
                        .tabItem {
                            Label("Now Playing", systemImage: "play.circle.fill")
                        }

                    SettingsView()
                        .tabItem {
                            Label("Settings", systemImage: "gear")
                        }
                }
                .preferredColorScheme(.dark)
                .tabBarMinimizeBehavior(.onScrollDown)
                .tabViewBottomAccessory {
                    LiquidGlassMiniPlayer(
                        namespace: miniPlayerNamespace,
                        showingNowPlaying: $showingNowPlaying
                    )
                }
                .navigationDestination(isPresented: $showingNowPlaying) {
                    NowPlayingView(animationNamespace: miniPlayerNamespace)
                        .toolbar(.hidden, for: .navigationBar)
                        .navigationBarBackButtonHidden()
                }
            }
        } else {
            // iOS 26 only - no fallback needed
            EmptyView()
        }
    }
}

#Preview {
    ContentView()
        .importService(DataManager.makePreviewImportService())
        .audioEngine(AudioEngineFacade())
}
