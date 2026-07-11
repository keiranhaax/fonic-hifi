//
//  QueueView.swift
//  Fonic HiFi
//
//  Queue display with current track and up next section.
//

import SwiftUI

struct QueueView: View {
    @Environment(\.audioEngine) private var audioService: AudioEngineFacade?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                nowPlayingSection
                upNextSection
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
        if let current = audioService?.queueManager.queueState.currentTrack {
            Section("Now Playing") {
                QueueRowView(track: current, isPlaying: true)
            }
        }
    }

    @ViewBuilder
    private var upNextSection: some View {
        let queueState = audioService?.queueManager.queueState
        let remaining = queueState?.remainingTracks ?? []
        if !remaining.isEmpty {
            Section("Up Next \u{2022} \(remaining.count) tracks") {
                ForEach(Array(remaining.enumerated()), id: \.element.id) { _, track in
                    QueueRowView(track: track, isPlaying: false)
                }
                .onMove(perform: moveTrack)
                .onDelete(perform: deleteTrack)
            }
        }
    }

    private func moveTrack(from source: IndexSet, to destination: Int) {
        audioService?.queueManager.moveRemaining(fromOffsets: source, toOffset: destination)
        Log.logger(.audioQueue).info("Moved track in queue")
    }

    private func deleteTrack(at offsets: IndexSet) {
        audioService?.queueManager.removeRemaining(at: offsets)
        Log.logger(.audioQueue).info("Removed track from queue")
    }
}

#Preview {
    QueueView()
}
