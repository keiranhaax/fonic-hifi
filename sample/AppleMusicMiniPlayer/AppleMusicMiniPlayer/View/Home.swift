//
//  Home.swift
//  AppleMusicMiniPlayer
//
//  Created by Balaji Venkatesh on 25/10/24.
//

import SwiftUI

struct Home: View {
    /// Setting true will work on simulator and actual device but on previews!
    @State private var showMiniPlayer: Bool = false
    @State private var hideMiniPlayer: Bool = false
    var body: some View {
        /// Dummy Tab View
        TabView {
            Tab("Home", systemImage: "house") {
                NavigationStack {
                    Button("Hide Mini Player") {
                        withAnimation(.snappy) {
                            hideMiniPlayer.toggle()
                        }
                    }
                    .navigationTitle("Home")
                }
            }

            Tab("Search", systemImage: "magnifyingglass") {
                Text("Search")
            }

            Tab("Notifications", systemImage: "bell") {
                Text("Notifications")
            }

            Tab("Settings", systemImage: "gearshape") {
                Text("Settings")
            }
        }
        .universalOverlay(show: $showMiniPlayer) {
            ExpandableMusicPlayer(show: $showMiniPlayer, hideMiniPlayer: $hideMiniPlayer)
        }
        .onAppear {
            showMiniPlayer = true
        }
    }
}

#Preview {
    RootView {
        Home()
    }
}
