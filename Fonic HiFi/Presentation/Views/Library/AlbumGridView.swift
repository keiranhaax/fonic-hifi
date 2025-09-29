//
//  AlbumGridView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftData
import SwiftUI

/// Grid view for albums
struct AlbumGridView: View {
    let albums: [Album]
    @Binding var searchText: String

    @State private var sortOrder = AlbumSortOrder.title
    @State private var selectedAlbum: Album?

    enum AlbumSortOrder: String, CaseIterable {
        case title = "Title"
        case artist = "Artist"
        case year = "Year"
        case dateAdded = "Date Added"
    }

    private let columns = [
        GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16),
    ]

    var sortedAlbums: [Album] {
        albums.sorted { album1, album2 in
            switch sortOrder {
            case .title:
                album1.title < album2.title
            case .artist:
                album1.albumArtist < album2.albumArtist
            case .year:
                (album1.year ?? 0) > (album2.year ?? 0)
            case .dateAdded:
                album1.dateAdded > album2.dateAdded
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
                    ForEach(AlbumSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)

                Spacer()

                Text("\(albums.count) albums")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            ScrollView {
                LazyVGrid(columns: columns, spacing: 20) {
                    ForEach(sortedAlbums) { album in
                        AlbumGridItem(album: album)
                            .onTapGesture {
                                selectedAlbum = album
                            }
                    }
                }
                .padding()
            }
        }
        .sheet(item: $selectedAlbum) { album in
            AlbumDetailView(album: album)
        }
    }
}

/// Individual album grid item
struct AlbumGridItem: View {
    let album: Album

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Artwork
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .overlay(
                    Image(systemName: "square.stack")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary),
                )
                .shadow(radius: 4)

            // Album info
            VStack(alignment: .leading, spacing: 2) {
                Text(album.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                Text(album.albumArtist)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)

                if let year = album.year {
                    Text(String(year))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .contentShape(Rectangle())
    }
}

/// Album detail view
struct AlbumDetailView: View {
    let album: Album
    @Environment(\.dismiss) private var dismiss
    @Query private var tracks: [Track]

    var albumTracks: [Track] {
        tracks.filter { $0.album == album.title && $0.albumArtist == album.albumArtist }
            .sorted {
                if let disc1 = $0.discNumber, let disc2 = $1.discNumber, disc1 != disc2 {
                    return disc1 < disc2
                }
                return ($0.trackNumber ?? 0) < ($1.trackNumber ?? 0)
            }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Album header
                    HStack(alignment: .top, spacing: 16) {
                        // Artwork
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 120, height: 120)
                            .overlay(
                                Image(systemName: "square.stack")
                                    .font(.system(size: 40))
                                    .foregroundColor(.secondary),
                            )

                        // Album info
                        VStack(alignment: .leading, spacing: 8) {
                            Text(album.title)
                                .font(.title3)
                                .fontWeight(.semibold)
                                .lineLimit(2)

                            Text(album.albumArtist)
                                .font(.body)
                                .foregroundColor(.secondary)

                            if let year = album.year {
                                Text(String(year))
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            HStack(spacing: 4) {
                                Text("\(albumTracks.count) tracks")
                                Text("•")
                                Text(formattedDuration)
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal)

                    // Track list
                    if !albumTracks.isEmpty {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("Tracks")
                                .font(.headline)
                                .padding(.horizontal)
                                .padding(.bottom, 8)

                            ForEach(albumTracks) { track in
                                AlbumTrackRow(track: track)
                                    .padding(.horizontal)
                                    .padding(.vertical, 8)

                                if track != albumTracks.last {
                                    Divider()
                                        .padding(.leading, 40)
                                }
                            }
                        }
                    }

                    // Album details
                    if album.primaryGenre != nil || album.label != nil {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Album Details")
                                .font(.headline)

                            if let genre = album.primaryGenre {
                                DetailRow(label: "Genre", value: genre)
                            }
                            if let label = album.label {
                                DetailRow(label: "Label", value: label)
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .navigationTitle("Album")
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

    private var formattedDuration: String {
        let totalSeconds = albumTracks.reduce(0) { $0 + $1.duration }
        let hours = Int(totalSeconds) / 3600
        let minutes = (Int(totalSeconds) % 3600) / 60

        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes) min"
        }
    }
}

/// Track row for album view
struct AlbumTrackRow: View {
    let track: Track

    var body: some View {
        HStack(spacing: 12) {
            // Track number
            if let trackNumber = track.trackNumber {
                Text("\(trackNumber)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .lineLimit(1)

                if track.artist != track.albumArtist, track.albumArtist != nil {
                    Text(track.artist)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Duration
            Text(track.formattedDuration)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

#Preview {
    AlbumGridView(albums: [], searchText: .constant(""))
}
