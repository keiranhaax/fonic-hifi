//
//  TrackListView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftData
import SwiftUI

/// List view for tracks
@MainActor
struct TrackListView: View {
    let tracks: [Track]
    @Binding var searchText: String

    @State private var sortOrder = TrackSortOrder.title
    @State private var selectedTrack: Track?

    enum TrackSortOrder: String, CaseIterable {
        case title = "Title"
        case artist = "Artist"
        case album = "Album"
        case dateAdded = "Date Added"
        case duration = "Duration"
    }

    var sortedTracks: [Track] {
        tracks.sorted { track1, track2 in
            switch sortOrder {
            case .title:
                track1.title < track2.title
            case .artist:
                track1.artist < track2.artist
            case .album:
                track1.album < track2.album
            case .dateAdded:
                track1.dateAdded > track2.dateAdded
            case .duration:
                track1.duration < track2.duration
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
                    ForEach(TrackSortOrder.allCases, id: \.self) { order in
                        Text(order.rawValue).tag(order)
                    }
                }
                .pickerStyle(.menu)
                .font(.caption)

                Spacer()

                Text("\(tracks.count) tracks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            List(sortedTracks) { track in
                TrackRowView(track: track)
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    .onTapGesture {
                        selectedTrack = track
                    }
            }
            .listStyle(.plain)
        }
        .sheet(item: $selectedTrack) { track in
            TrackDetailView(track: track)
        }
    }
}

/// Track detail view
struct TrackDetailView: View {
    let track: Track
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Artwork
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.3))
                        .aspectRatio(1, contentMode: .fit)
                        .overlay(
                            Image(systemName: "music.note")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary),
                        )
                        .padding(.horizontal, 40)

                    // Basic info
                    VStack(alignment: .leading, spacing: 12) {
                        DetailRow(label: "Title", value: track.title)
                        DetailRow(label: "Artist", value: track.artist)
                        DetailRow(label: "Album", value: track.album)
                        if let genre = track.genre {
                            DetailRow(label: "Genre", value: genre)
                        }
                        if let year = track.year {
                            DetailRow(label: "Year", value: String(year))
                        }
                    }
                    .padding(.horizontal)

                    Divider()

                    // Technical info
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Technical Details")
                            .font(.headline)
                            .padding(.horizontal)

                        DetailRow(label: "Format", value: track.audioFormat)
                        DetailRow(label: "Duration", value: track.formattedDuration)
                        DetailRow(label: "Sample Rate", value: "\(Int(track.sampleRate)) Hz")
                        DetailRow(label: "Bit Depth", value: "\(track.bitDepth)-bit")
                        DetailRow(label: "Channels", value: track.channels == 2 ? "Stereo" : "\(track.channels) channels")
                        if let bitrate = track.bitrate {
                            DetailRow(label: "Bitrate", value: "\(bitrate) kbps")
                        }
                        DetailRow(label: "File Size", value: track.formattedFileSize)
                    }
                    .padding(.horizontal)
                }
                .padding(.vertical)
            }
            .navigationTitle("Track Details")
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

/// Detail row helper
struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .lineLimit(2)
        }
    }
}

#Preview {
    TrackListView(tracks: [], searchText: .constant(""))
}
