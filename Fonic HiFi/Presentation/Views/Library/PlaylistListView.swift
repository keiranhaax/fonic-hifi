//
//  PlaylistListView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftUI
import SwiftData

/// List view for playlists
struct PlaylistListView: View {
    let playlists: [Playlist]
    @Binding var searchText: String
    @Binding var showingCreatePlaylist: Bool
    
    @State private var selectedPlaylist: Playlist?
    
    var filteredPlaylists: [Playlist] {
        if searchText.isEmpty {
            return playlists
        } else {
            return playlists.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        Group {
            if playlists.isEmpty {
                EmptyPlaylistView(showingCreatePlaylist: $showingCreatePlaylist)
            } else {
                List(filteredPlaylists) { playlist in
                    PlaylistRowView(playlist: playlist)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .onTapGesture {
                            selectedPlaylist = playlist
                        }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $selectedPlaylist) { playlist in
            PlaylistDetailView(playlist: playlist)
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistView()
        }
    }
}

/// Empty playlists state
struct EmptyPlaylistView: View {
    @Binding var showingCreatePlaylist: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("No Playlists")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create playlists to organize your music")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}

/// Individual playlist row
struct PlaylistRowView: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 12) {
            // Playlist icon
            RoundedRectangle(cornerRadius: 8)
                .fill(playlist.isSmart ? Color.purple.opacity(0.3) : Color.accentColor.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: playlist.isSmart ? "gearshape.fill" : "music.note.list")
                        .foregroundColor(playlist.isSmart ? .purple : .accentColor)
                )
            
            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if playlist.isSmart {
                        Text("Smart Playlist")
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text("\(playlist.trackCount) tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }
}

/// Playlist detail view
struct PlaylistDetailView: View {
    let playlist: Playlist
    @Environment(\.dismiss) private var dismiss
    @Query private var tracks: [Track]
    
    var playlistTracks: [Track] {
        // For now, return empty array as we need to implement playlist track relationships
        []
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Playlist header
                VStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(playlist.isSmart ? Color.purple.opacity(0.3) : Color.accentColor.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: playlist.isSmart ? "gearshape.fill" : "music.note.list")
                                .font(.system(size: 40))
                                .foregroundColor(playlist.isSmart ? .purple : .accentColor)
                        )
                    
                    Text(playlist.name)
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    if let description = playlist.playlistDescription {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    
                    HStack {
                        if playlist.isSmart {
                            Label("Smart Playlist", systemImage: "gearshape.fill")
                                .font(.caption)
                                .foregroundColor(.purple)
                        }
                        
                        Label("\(playlist.trackCount) tracks", systemImage: "music.note")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                
                // Track list or empty state
                if playlistTracks.isEmpty {
                    Spacer()
                    
                    VStack(spacing: 12) {
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        
                        Text(playlist.isSmart ? "No matching tracks" : "Empty playlist")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                } else {
                    List(playlistTracks) { track in
                        TrackRowView(track: track)
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

/// Create playlist view
struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var playlistName = ""
    @State private var playlistDescription = ""
    @State private var isSmartPlaylist = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Playlist Name", text: $playlistName)
                    TextField("Description (optional)", text: $playlistDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Toggle("Smart Playlist", isOn: $isSmartPlaylist)
                        .tint(.purple)
                    
                    if isSmartPlaylist {
                        Text("Smart playlists automatically update based on rules you define")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Create") {
                        createPlaylist()
                    }
                    .disabled(playlistName.isEmpty)
                }
            }
        }
    }
    
    private func createPlaylist() {
        let playlist = Playlist(
            name: playlistName,
            playlistDescription: playlistDescription.isEmpty ? nil : playlistDescription,
            type: isSmartPlaylist ? .smart : .static
        )
        
        modelContext.insert(playlist)
        dismiss()
    }
}

#Preview {
    PlaylistListView(playlists: [], searchText: .constant(""), showingCreatePlaylist: .constant(false))
}