//
//  LibraryView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftUI
import SwiftData

/// Main library view with tabs for different browse modes
@MainActor
struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var tracks: [Track]
    @Query private var albums: [Album]
    @Query private var artists: [Artist]
    @Query private var playlists: [Playlist]
    
    @State private var selectedTab = LibraryTab.tracks
    @State private var searchText = ""
    @State private var showingImportView = false
    @State private var showingImportProgress = false
    @State private var showingCreatePlaylist = false
    
    @Environment(\.importService) private var importService
    
    enum LibraryTab: String, CaseIterable {
        case tracks = "Tracks"
        case albums = "Albums"
        case artists = "Artists"
        case playlists = "Playlists"
        
        var icon: String {
            switch self {
            case .tracks: return "music.note"
            case .albums: return "square.stack"
            case .artists: return "person.2"
            case .playlists: return "music.note.list"
            }
        }
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab selector
                Picker("Library View", selection: $selectedTab) {
                    ForEach(LibraryTab.allCases, id: \.self) { tab in
                        Label(tab.rawValue, systemImage: tab.icon)
                            .tag(tab)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.vertical, 8)
                
                // Content
                Group {
                    switch selectedTab {
                    case .tracks:
                        TrackListView(tracks: filteredTracks, searchText: $searchText)
                    case .albums:
                        AlbumGridView(albums: filteredAlbums, searchText: $searchText)
                    case .artists:
                        ArtistListView(artists: filteredArtists, searchText: $searchText)
                    case .playlists:
                        PlaylistListView(playlists: playlists, searchText: $searchText, showingCreatePlaylist: $showingCreatePlaylist)
                    }
                }
                .searchable(text: $searchText, prompt: "Search \(selectedTab.rawValue)")
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: {
                        if selectedTab == .playlists {
                            showingCreatePlaylist = true
                        } else {
                            showingImportView = true
                        }
                    }) {
                        Image(systemName: selectedTab == .playlists ? "plus" : "plus.circle.fill")
                    }
                }
            }
            .sheet(isPresented: $showingImportView) {
                FileImportView()
                    .importService(importService!)
            }
            .sheet(isPresented: $showingImportProgress) {
                ImportProgressView()
                    .importService(importService!)
                    .interactiveDismissDisabled(importService?.isImporting ?? false)
            }
            .sheet(isPresented: $showingCreatePlaylist) {
                CreatePlaylistView()
            }
            .onChange(of: importService?.isImporting) { _, isImporting in
                if isImporting == true {
                    showingImportView = false
                    showingImportProgress = true
                }
            }
            .overlay {
                if tracks.isEmpty && albums.isEmpty && artists.isEmpty && selectedTab != .playlists {
                    EmptyLibraryView(showingImportView: $showingImportView)
                }
            }
        }
    }
    
    // MARK: - Filtered Data
    
    private var filteredTracks: [Track] {
        if searchText.isEmpty {
            return tracks
        } else {
            return tracks.filter { $0.matches(searchQuery: searchText) }
        }
    }
    
    private var filteredAlbums: [Album] {
        if searchText.isEmpty {
            return albums
        } else {
            return albums.filter {
                $0.title.localizedCaseInsensitiveContains(searchText) ||
                $0.albumArtist.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    private var filteredArtists: [Artist] {
        if searchText.isEmpty {
            return artists
        } else {
            return artists.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
}

/// Empty library state
struct EmptyLibraryView: View {
    @Binding var showingImportView: Bool
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "music.note")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            
            Text("Your Library is Empty")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Import music to get started")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    LibraryView()
        .importService(DataManager.makePreviewImportService())
}