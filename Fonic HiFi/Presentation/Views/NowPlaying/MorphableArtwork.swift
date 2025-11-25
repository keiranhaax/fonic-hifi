//
//  MorphableArtwork.swift
//  Fonic HiFi
//
//  Shared artwork component used by both mini player and expanded NowPlayingView.
//  Uses matchedGeometryEffect for smooth morphing during transitions.
//

import SwiftUI

/// Shared artwork view that morphs between mini (48px) and expanded (280px+) sizes.
/// Uses `matchedGeometryEffect` to enable smooth interpolation during zoom transitions.
@MainActor
struct MorphableArtwork: View {
    let size: CGFloat
    let namespace: Namespace.ID
    @Environment(\.audioEngine) private var audioService

    /// Corner radius scales proportionally: 8pt for small, 16pt for large
    private var cornerRadius: CGFloat {
        size > 100 ? 16 : 8
    }

    var body: some View {
        artworkContent
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .matchedGeometryEffect(id: "artwork", in: namespace)
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

    MorphableArtwork(size: 48, namespace: namespace)
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
