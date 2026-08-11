//
//  MorphableArtwork.swift
//  Fonic HiFi
//
//  Shared artwork component used by both mini player and expanded NowPlayingView.
//  The system zoom transition (matchedTransitionSource/navigationTransition)
//  owns the morph between the two placements; matchedGeometryEffect cannot
//  pair views across the fullScreenCover boundary and only causes artifacts.
//

import SwiftUI
import UIKit

/// Shared artwork view rendered at mini (30pt) and expanded (280pt+) sizes.
@MainActor
struct MorphableArtwork: View {
    let size: CGFloat
    @EnvironmentObject private var audioService: AudioEngineFacade
    @State private var image: UIImage?
    @State private var isLoading = false

    init(size: CGFloat) {
        self.size = size
    }

    /// Corner radius scales proportionally (size / 4), matching Apple Music's approach
    private var cornerRadius: CGFloat {
        size / 4
    }

    var body: some View {
        artworkContent
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: audioService.currentTrack?.id) {
                await loadArtwork()
            }
    }

    @ViewBuilder
    private var artworkContent: some View {
        if let image {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Placeholder when no artwork available
            placeholderArtwork
        }
    }

    private func loadArtwork() async {
        image = nil
        guard let data = audioService.currentTrack?.artwork else { return }
        isLoading = true
        defer { isLoading = false }
        let decoded = await Task.detached(priority: .utility) {
            UIImage(data: data)
        }.value
        guard !Task.isCancelled else { return }
        image = decoded
    }

    private var placeholderArtwork: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(
                LinearGradient(
                    colors: [Color.gray.opacity(0.4), Color.gray.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .overlay(
                Image(systemName: "music.note")
                    .font(.system(size: size * 0.4))
                    .foregroundStyle(.white.opacity(0.6))
            )
    }
}

// MARK: - Preview

#Preview("Mini Size") {
    @Previewable @State var audioService = AudioEngineFacade()

    MorphableArtwork(size: 30)
        .audioEngine(audioService)
        .padding()
        .background(Color.black)
}

#Preview("Expanded Size") {
    @Previewable @State var audioService = AudioEngineFacade()

    MorphableArtwork(size: 280)
        .audioEngine(audioService)
        .padding()
        .background(Color.black)
}
