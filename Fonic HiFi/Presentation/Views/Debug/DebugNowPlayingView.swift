//
//  DebugNowPlayingView.swift
//  Fonic HiFi
//
//  Debug version to isolate crash cause
//

import SwiftUI

/// Minimal debug version of Now Playing view to isolate crash
@MainActor
struct DebugNowPlayingView: View {
    @EnvironmentObject private var audioService: AudioEngineFacade
    @State private var debugLog: [String] = []

    var body: some View {
        VStack(spacing: 20) {
            Text("Debug Now Playing View")
                .font(.title)
                .onAppear {
                    addLog("View appeared")
                    // Verify we're on main actor
                    dispatchPrecondition(condition: .onQueue(.main))
                    addLog("Dispatch queue: \(String(cString: __dispatch_queue_get_label(nil)))")
                }

            if let track = audioService.currentTrack {
                Text("Playing: \(track.title)")
                Text("by \(track.artist)")
            } else {
                Text("No track selected")
            }

            Button("Close") {
                addLog("Close button tapped")
                // audioService.hideNowPlaying() // Method removed - showingNowPlaying moved to local view state
            }

            Divider()

            Text("Debug Log:")
                .font(.headline)

            ScrollView {
                VStack(alignment: .leading) {
                    ForEach(debugLog, id: \.self) { log in
                        Text(log)
                            .font(.caption)
                            .monospaced()
                    }
                }
            }
            .frame(maxHeight: 200)
        }
        .padding()
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
            addLog("App became active")
        }
    }

    private func addLog(_ message: String) {
        let timestamp = Date().timeIntervalSince1970
        let logEntry = "\(String(format: "%.3f", timestamp)): \(message)"
        print("[DEBUG NOW PLAYING] \(logEntry)")
        debugLog.append(logEntry)
    }
}

#Preview {
    DebugNowPlayingView()
        .environmentObject(AudioEngineFacade())
}
