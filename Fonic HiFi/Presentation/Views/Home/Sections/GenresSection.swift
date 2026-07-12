//
//  GenresSection.swift
//  Fonic HiFi
//
//  Horizontal scrolling genre pills section
//

import SwiftUI

@MainActor
struct GenresSection: View {
    let genres: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Browse by Genre")
                .font(.title2.bold())
                .padding(.horizontal)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    ForEach(genres, id: \.self) { genre in
                        GenrePillView(genre: genre)
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
            .glassEffect(.regular)
    }
}

#Preview {
    GenresSection(
        genres: ["Rock", "Jazz", "Electronic", "Classical", "Hip-Hop"]
    )
}
