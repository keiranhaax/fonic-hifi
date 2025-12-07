// Fonic HiFi/Presentation/Views/Search/SmartSearchResultsView.swift
import SwiftData
import SwiftUI

/// Displays smart search results with AI explanations
struct SmartSearchResultsView: View {
    let result: SmartSearchResult
    let trackIDs: [UUID]
    let onTrackTap: (Track) -> Void

    @Environment(\.modelContext) private var modelContext

    var body: some View {
        List {
            // AI indicator
            if !result.searchStrategy.isEmpty {
                Section {
                    HStack(spacing: 8) {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        Text(result.searchStrategy)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Track results
            if !trackIDs.isEmpty {
                Section("Results") {
                    ForEach(Array(trackIDs.enumerated()), id: \.element) { index, trackID in
                        SmartSearchTrackRow(
                            trackID: trackID,
                            matchReason: index < result.matchReasons.count ? result.matchReasons[index] : nil,
                            onTap: onTrackTap
                        )
                    }
                }
            }

            // Suggestions
            if !result.suggestions.isEmpty {
                Section("Try searching for") {
                    ForEach(result.suggestions, id: \.self) { suggestion in
                        Label(suggestion, systemImage: "magnifyingglass")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .listStyle(.grouped)
    }
}

/// Track row that fetches track by ID
private struct SmartSearchTrackRow: View {
    let trackID: UUID
    let matchReason: String?
    let onTap: (Track) -> Void

    @Environment(\.modelContext) private var modelContext
    @State private var track: Track?

    var body: some View {
        Group {
            if let track {
                Button {
                    onTap(track)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            LazyArtworkView(trackId: trackID, size: 50, cornerRadius: 8)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title)
                                    .font(.body)
                                    .lineLimit(1)
                                Text(track.artist)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }

                            Spacer()

                            if matchReason != nil {
                                Image(systemName: "sparkles")
                                    .font(.caption)
                                    .foregroundStyle(.purple.opacity(0.6))
                            }
                        }

                        // Match reason (if available)
                        if let reason = matchReason {
                            Text(reason)
                                .font(.caption2)
                                .foregroundStyle(.purple.opacity(0.8))
                                .padding(.leading, 62)
                        }
                    }
                }
                .buttonStyle(.plain)
            } else {
                HStack(spacing: 12) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.tertiary)
                        .frame(width: 50, height: 50)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Loading...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Text(" ")
                            .font(.caption)
                    }
                    Spacer()
                }
            }
        }
        .task {
            await loadTrack()
        }
    }

    @MainActor
    private func loadTrack() async {
        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.id == trackID
            }
        )
        track = try? modelContext.fetch(descriptor).first
    }
}
