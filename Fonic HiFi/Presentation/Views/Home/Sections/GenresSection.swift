//
//  GenresSection.swift
//  Fonic HiFi
//
//  Horizontal scrolling genre pills section
//

import SwiftData
import SwiftUI

@MainActor
struct GenresSection: View {
    let genres: [String]
    let onGenreTap: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Genre")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(genres, id: \.self) { genre in
                        Button {
                            onGenreTap(genre)
                        } label: {
                            GenrePillView(genre: genre)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(genre)
                        .accessibilityHint("Shows tracks in this genre")
                    }
                }
                .padding(.horizontal)
            }
        }
    }
}

private struct GenrePillView: View {
    let genre: String

    var body: some View {
        Text(genre)
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(.rect)
            .glassEffect(.regular)
    }
}

@MainActor
struct GenreTracksView: View {
    let genre: String

    @Environment(\.dismiss) private var dismiss
    @Query private var tracks: [Track]

    init(genre: String) {
        self.genre = genre

        let selectedGenre = genre
        _tracks = Query(
            filter: #Predicate<Track> { track in
                track.genre == selectedGenre
            },
            sort: [SortDescriptor(\Track.title)]
        )
    }

    var body: some View {
        NavigationStack {
            TrackListView(tracks: tracks, searchText: .constant(""))
                .navigationTitle(genre)
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
}

#Preview {
    GenresSection(
        genres: ["Rock", "Jazz", "Electronic", "Classical", "Hip-Hop"],
        onGenreTap: { _ in }
    )
}
