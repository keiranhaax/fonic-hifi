//
//  AlbumSheetView.swift
//  Fonic HiFi
//
//  Full Liquid Glass sheet for album playback and track browsing from Home.
//

import SwiftData
import SwiftUI

@MainActor
struct AlbumSheetView: View {
    let album: Album
    let onTrackTap: (Track) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query private var tracks: [Track]

    init(
        album: Album,
        onTrackTap: @escaping (Track) -> Void
    ) {
        self.album = album
        self.onTrackTap = onTrackTap

        let albumTitle = album.title
        let albumArtist = album.albumArtist
        _tracks = Query(
            filter: #Predicate<Track> { track in
                track.album == albumTitle && track.albumArtist == albumArtist
            },
            sort: [
                SortDescriptor(\Track.discNumber),
                SortDescriptor(\Track.trackNumber)
            ]
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    headerView
                    actionButtons
                    tracksSection
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 24)
            }
            .scrollContentBackground(.hidden)
            .navigationTitle(album.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var headerView: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Spacer()
                LazyArtworkView(album: album, size: 200, cornerRadius: 14)
                Spacer()
            }

            Text(album.title)
                .font(.title2.bold())
                .lineLimit(2)

            Text(album.albumArtist)
                .font(.headline)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                if let year = album.year {
                    Text(String(year))
                }

                Text("•")

                Text("\(tracks.count) tracks")

                if !tracks.isEmpty {
                    Text("•")
                    Text(totalDuration)
                }
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var actionButtons: some View {
        HStack(spacing: 12) {
            Button {
                if let firstTrack = tracks.first {
                    onTrackTap(firstTrack)
                }
            } label: {
                Label("Play", systemImage: "play.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(tracks.isEmpty)

            Button {
                if let randomTrack = tracks.randomElement() {
                    onTrackTap(randomTrack)
                }
            } label: {
                Label("Shuffle", systemImage: "shuffle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(tracks.isEmpty)
        }
    }

    private var tracksSection: some View {
        LazyVStack(spacing: 0) {
            ForEach(Array(tracks.enumerated()), id: \.element.id) { index, track in
                AlbumSheetTrackRowView(track: track) {
                    onTrackTap(track)
                }

                if index < tracks.count - 1 {
                    Divider()
                        .padding(.leading, 44)
                }
            }
        }
    }

    private var totalDuration: String {
        let duration = tracks.reduce(0) { $0 + $1.duration }
        let minutes = Int(duration) / 60
        let hours = minutes / 60
        let remainingMinutes = minutes % 60

        if hours > 0 {
            return "\(hours)h \(remainingMinutes)m"
        }

        return "\(minutes)m"
    }
}

private struct AlbumSheetTrackRowView: View {
    let track: Track
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                Text("\(track.trackNumber ?? 0)")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, alignment: .trailing)

                VStack(alignment: .leading, spacing: 2) {
                    Text(track.title)
                        .font(.body)
                        .lineLimit(1)

                    if track.artist != track.albumArtist {
                        Text(track.artist)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }

                Spacer()

                Text(track.formattedDuration)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    AlbumSheetView(
        album: Album(title: "Sample Album", albumArtist: "Sample Artist", year: 2024),
        onTrackTap: { _ in }
    )
}
