//
//  MorphableArtwork.swift
//  Fonic HiFi
//
//  Shared artwork component used by both mini player and expanded NowPlayingView.
//  Uses matchedGeometryEffect for smooth morphing during transitions.
//

import SwiftUI

/// Shared artwork view that morphs between mini (30pt) and expanded (280pt+) sizes.
/// Uses `matchedGeometryEffect` to enable smooth interpolation during zoom transitions.
@MainActor
struct MorphableArtwork: View {
    let size: CGFloat
    let namespace: Namespace.ID
    let isSource: Bool
    @Environment(\.audioEngine) private var audioService

    init(size: CGFloat, namespace: Namespace.ID, isSource: Bool = true) {
        self.size = size
        self.namespace = namespace
        self.isSource = isSource
    }

    /// Corner radius scales proportionally (size / 4), matching Apple Music's approach
    private var cornerRadius: CGFloat {
        size / 4
    }

    var body: some View {
        artworkContent
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .matchedGeometryEffect(id: "artwork", in: namespace, isSource: isSource)
    }

    @ViewBuilder
    private var artworkContent: some View {
        if let artworkData = audioService?.currentTrack?.artwork,
           let uiImage = UIImage(data: artworkData) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            // Placeholder when no artwork available
            placeholderArtwork
        }
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
    @Previewable @Namespace var namespace
    @Previewable @State var audioService = AudioEngineFacade()

    MorphableArtwork(size: 30, namespace: namespace)
        .environment(\.audioEngine, audioService)
        .padding()
        .background(Color.black)
}

#Preview("Expanded Size") {
    @Previewable @Namespace var namespace
    @Previewable @State var audioService = AudioEngineFacade()

    MorphableArtwork(size: 280, namespace: namespace)
        .environment(\.audioEngine, audioService)
        .padding()
        .background(Color.black)
}
