//
//  ContentView.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            // Library Tab
            NavigationStack {
                Text("Library")
                    .navigationTitle("Library")
            }
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
    }
}

#Preview {
    ContentView()
}