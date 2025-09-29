//
//  ArtistListView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftData
import SwiftUI

/// List view for artists
struct ArtistListView: View {
    let artists: [Artist]
    @Binding var searchText: String

    @State private var sortOrder = ArtistSortOrder.name
    @State private var selectedArtist: Artist?

    enum ArtistSortOrder: String, CaseIterable {
        case name = "Name"
        case trackCount = "Track Count"
        case albumCount = "Album Count"
    }

    var sortedArtists: [Artist] {
        artists.sorted { artist1, artist2 in
            switch sortOrder {
            case .name:
                artist1.name < artist2.name
            case .trackCount:
                artist1.trackCount > artist2.trackCount
            case .albumCount:
                artist1.albumCount > artist2.albumCount
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Sort options
            HStack {
                Text("Sort by:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("Sort", selection: $sortOrder) {
                    ForEach(ArtistSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)

                Spacer()

                Text("\(artists.count) artists")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            List(sortedArtists) { artist in
                ArtistRowView(artist: artist)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .onTapGesture {
                        selectedArtist = artist
                    }
            }
            .listStyle(.plain)
        }
        .sheet(item: $selectedArtist) { artist in
            ArtistDetailView(artist: artist)
        }
    }
}

/// Individual artist row
struct ArtistRowView: View {
    let artist: Artist

    var body: some View {
        HStack(spacing: 12) {
            // Artist image placeholder
            Circle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: "person.fill")
                        .foregroundColor(.secondary),
                )

            // Artist info
            VStack(alignment: .leading, spacing: 4) {
                Text(artist.name)
                    .font(.body)
                    .lineLimit(1)

                HStack(spacing: 8) {
                    if artist.albumCount > 0 {
                        Label("\(artist.albumCount)", systemImage: "square.stack")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Label("\(artist.trackCount)", systemImage: "music.note")
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

/// Artist detail view
struct ArtistDetailView: View {
    let artist: Artist
    @Environment(\.dismiss) private var dismiss
    @Query private var albums: [Album]
    @Query private var tracks: [Track]

    @State private var selectedView = ArtistViewMode.albums

    enum ArtistViewMode: String, CaseIterable {
        case albums = "Albums"
        case tracks = "All Tracks"
    }

    var artistAlbums: [Album] {
        albums.filter { $0.albumArtist == artist.name }
            .sorted { ($0.year ?? 0) > ($1.year ?? 0) }
    }

    var artistTracks: [Track] {
        tracks.filter { $0.artist == artist.name || $0.albumArtist == artist.name }
            .sorted { $0.title < $1.title }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Artist header
                VStack(spacing: 12) {
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 100, height: 100)
                        .overlay(
                            Image(systemName: "person.fill")
                                .font(.system(size: 40))
                                .foregroundColor(.secondary),
                        )

                    Text(artist.name)
                        .font(.title2)
                        .fontWeight(.semibold)

                    HStack(spacing: 16) {
                        Label("\(artist.albumCount) Albums", systemImage: "square.stack")
                        Label("\(artist.trackCount) Tracks", systemImage: "music.note")
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .padding()

                // View mode picker
                Picker("View Mode", selection: $selectedView) {
                    ForEach(ArtistViewMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Content
                Group {
                    switch selectedView {
                    case .albums:
                        ArtistAlbumsView(albums: artistAlbums)
                    case .tracks:
                        ArtistTracksView(tracks: artistTracks)
                    }
                }
            }
            .navigationTitle("Artist")
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

/// Artist's albums view
struct ArtistAlbumsView: View {
    let albums: [Album]

    var body: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                ForEach(albums) { album in
                    HStack(spacing: 12) {
                        // Album artwork
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .overlay(
                                Image(systemName: "square.stack")
                                    .foregroundColor(.secondary),
                            )

                        // Album info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(album.title)
                                .font(.body)
                                .lineLimit(1)

                            if let year = album.year {
                                Text(String(year))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.vertical)
        }
    }
}

/// Artist's tracks view
struct ArtistTracksView: View {
    let tracks: [Track]

    var body: some View {
        List(tracks) { track in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body)
                        .lineLimit(1)

                    Text(track.album)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(track.formattedDuration)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .listStyle(.plain)
    }
}

#Preview {
    ArtistListView(artists: [], searchText: .constant(""))
}
