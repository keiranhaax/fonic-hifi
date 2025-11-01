//
//  DebugTrackRowView.swift
//  Fonic HiFi
//
//  Debug version with extensive logging
//

import SwiftUI

/// Debug version of TrackRowView with extensive logging
@MainActor
struct DebugTrackRowView: View {
    let track: Track
    @Environment(\.audioEngine) private var audioService

    private let logger = Log.logger(.diagnostics)

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(track.title)
                    .font(.body)
                Text(track.artist)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            debugPlayTrack()
        }
    }

    private func debugPlayTrack() {
        logger.debug("\n=== DEBUG TRACK TAP START ===")
        logger.debug("1. Tap gesture triggered")
        logger.debug("   isMainThread: \(Thread.isMainThread, privacy: .public)")
        let initialQueuePointer = __dispatch_queue_get_label(nil)
        let initialQueueLabel = String(cString: initialQueuePointer)
        logger.debug("   Queue: \(initialQueueLabel)")

        Task { @MainActor in
            logger.debug("\n2. Inside Task block")
            let taskQueuePointer = __dispatch_queue_get_label(nil)
            let taskQueueLabel = String(cString: taskQueuePointer)
            logger.debug("   Queue: \(taskQueueLabel)")

            // Verify precondition
            dispatchPrecondition(condition: .onQueue(.main))
            logger.debug("3. Dispatch precondition passed - we are on main queue")

            // Update app state
            guard let audioService else {
                logger.error("4. ❌ No audioService available")
                return
            }

            logger.debug("\n4. About to update audioService.currentTrack")
            let currentTrackBefore = audioService.currentTrack?.title ?? "nil"
            logger.debug("   Current track before: \(currentTrackBefore)")
            audioService.setCurrentTrack(track)
            let currentTrackAfter = audioService.currentTrack?.title ?? "nil"
            logger.debug("   Current track after: \(currentTrackAfter)")

            // Show Now Playing
            logger.debug("\n5. About to set showingNowPlaying = true")
            // Try different approaches to see which crashes

            // Approach 1: Direct set
            // audioService.showingNowPlaying = true

            // Approach 2: Via method
            // audioService.showNowPlaying() // Method removed - showingNowPlaying moved to local view state

            // Approach 3: With animation
            // withAnimation {
            //     audioService.showingNowPlaying = true
            // }

            // Play audio
            logger.debug("\n6. About to call audioService.play")
            do {
                try await audioService.play(track: track)
                logger.debug("7. audioService.play completed successfully")
            } catch {
                let errorDescription = error.localizedDescription
                logger.error("7. audioService.play failed: \(errorDescription)")
            }

            logger.debug("\n=== DEBUG TRACK TAP END ===\n")
        }
    }
}

#Preview {
    DebugTrackRowView(track: Track(
        url: URL(fileURLWithPath: "/Music/Classical/Beethoven/moonlight.flac"),
        title: "Moonlight Sonata",
        artist: "Ludwig van Beethoven",
        album: "Classical Collection",
        audioFormat: "FLAC",
        duration: 335.0,
        sampleRate: 44100,
        bitDepth: 16,
        channels: 2,
        isLossless: true,
    ))
    .audioEngine(AudioEngineFacade())
}
