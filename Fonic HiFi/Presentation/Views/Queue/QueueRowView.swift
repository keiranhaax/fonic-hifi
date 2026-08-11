//
//  QueueRowView.swift
//  Fonic HiFi
//
//  Row view for displaying a track in the queue.
//

import SwiftUI

struct QueueRowView: View {
    let track: AudioTrack
    let isPlaying: Bool
    var onTap: (() -> Void)?

    init(track: AudioTrack, isPlaying: Bool, onTap: (() -> Void)? = nil) {
        self.track = track
        self.isPlaying = isPlaying
        self.onTap = onTap
    }

    var body: some View {
        Button(action: { onTap?() }) {
            HStack(spacing: 12) {
            // Artwork placeholder (AudioTrack doesn't store artwork)
            RoundedRectangle(cornerRadius: 6)
                .fill(.quaternary)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "music.note")
                        .foregroundStyle(.secondary)
                }

            // Track info
            VStack(alignment: .leading, spacing: 2) {
                Text(track.title)
                    .font(.body)
                    .fontWeight(isPlaying ? .semibold : .regular)
                    .lineLimit(1)

                Text(track.artist)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Playing indicator
            if isPlaying {
                Image(systemName: "waveform")
                    .symbolEffect(.variableColor.iterative)
                    .foregroundStyle(.tint)
            }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .frame(minHeight: 44)
        .accessibilityLabel(Text(track.title))
        .accessibilityValue(Text(isPlaying ? "Playing" : "Paused"))
        .accessibilityHint(onTap == nil ? Text(verbatim: "") : Text("Starts playback"))
    }
}

#Preview {
    List {
        QueueRowView(
            track: AudioTrack(
                title: "Sample Track",
                artist: "Sample Artist",
                album: "Sample Album",
                url: URL(fileURLWithPath: "/sample.mp3"),
                duration: 180,
                audioFormat: "MP3"
            ),
            isPlaying: true
        )
        QueueRowView(
            track: AudioTrack(
                title: "Another Track",
                artist: "Another Artist",
                album: "Another Album",
                url: URL(fileURLWithPath: "/another.mp3"),
                duration: 240,
                audioFormat: "FLAC"
            ),
            isPlaying: false
        )
    }
}
