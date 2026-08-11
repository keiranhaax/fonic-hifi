//
//  QueueView.swift
//  Fonic HiFi
//
//  Queue display with current track and up next section.
//

import OSLog
import SwiftUI

struct QueueView: View {
    @EnvironmentObject private var audioService: AudioEngineFacade
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale

    var body: some View {
        NavigationStack {
            List {
                nowPlayingSection
                upNextSection
                if audioService.queueState.currentTrack == nil,
                   audioService.queueState.remainingTracks.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "Queue is Empty",
                            systemImage: "music.note.list",
                            description: Text("Play a track to start building your queue.")
                        )
                    }
                }
            }
            .navigationTitle("Queue")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.hard, for: .top)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    @ViewBuilder
    private var nowPlayingSection: some View {
        if let current = audioService.queueManager.queueState.currentTrack {
            Section("Now Playing") {
                QueueRowView(track: current, isPlaying: audioService.isPlaying) {
                    Task {
                        try? await audioService.jumpToTrack(current)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var upNextSection: some View {
        let remaining = audioService.queueManager.queueState.remainingTracks
        if !remaining.isEmpty {
                Section {
                    ForEach(Array(remaining.enumerated()), id: \.element.id) { _, track in
                    QueueRowView(track: track, isPlaying: false) {
                        Task {
                            try? await audioService.jumpToTrack(track)
                        }
                    }
                }
                .onMove(perform: moveTrack)
                .onDelete(perform: deleteTrack)
            } header: {
                Text(verbatim: LocalizedFormatters.upNextTrackCount(
                    remaining.count,
                    locale: locale
                ))
            }
        }
    }

    private func moveTrack(from source: IndexSet, to destination: Int) {
        audioService.moveQueueItem(fromOffsets: source, toOffset: destination)
        Log.logger(.audioQueue).info("Moved track in queue")
    }

    private func deleteTrack(at offsets: IndexSet) {
        audioService.removeQueueItems(at: offsets)
        Log.logger(.audioQueue).info("Removed track from queue")
    }
}

#Preview {
    QueueView()
        .audioEngine(AudioEngineFacade())
}
