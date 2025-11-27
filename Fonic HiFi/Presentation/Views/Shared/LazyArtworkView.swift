//
//  LazyArtworkView.swift
//  Fonic HiFi
//
//  Lazy-loading artwork component that fetches artwork on-demand via ArtworkService.
//  Supports multiple lookup modes: by track ID, album ID, or album title/artist.
//

import SwiftUI

/// Lazy-loading artwork view that fetches from ArtworkService on demand.
/// Shows placeholder while loading, then transitions to actual artwork.
@MainActor
struct LazyArtworkView: View {
    // MARK: - Lookup Keys

    private let trackId: UUID?
    private let albumId: UUID?
    private let albumTitle: String?
    private let albumArtist: String?

    // MARK: - Appearance

    let size: CGFloat
    var cornerRadius: CGFloat = 8
    var placeholderIcon: String = "music.note"

    // MARK: - Environment & State

    @Environment(\.artworkService) private var artworkService
    @State private var artworkData: Data?
    @State private var isLoading = false

    // MARK: - Convenience Initializers

    /// Initialize with a track ID for lazy loading
    init(trackId: UUID, size: CGFloat, cornerRadius: CGFloat = 8, placeholderIcon: String = "music.note") {
        self.trackId = trackId
        self.albumId = nil
        self.albumTitle = nil
        self.albumArtist = nil
        self.size = size
        self.cornerRadius = cornerRadius
        self.placeholderIcon = placeholderIcon
    }

    /// Initialize with an album ID for lazy loading
    init(albumId: UUID, size: CGFloat, cornerRadius: CGFloat = 8, placeholderIcon: String = "square.stack") {
        self.trackId = nil
        self.albumId = albumId
        self.albumTitle = nil
        self.albumArtist = nil
        self.size = size
        self.cornerRadius = cornerRadius
        self.placeholderIcon = placeholderIcon
    }

    /// Initialize with album title and artist for lazy loading (useful for SwiftData models)
    init(albumTitle: String, albumArtist: String, size: CGFloat, cornerRadius: CGFloat = 8, placeholderIcon: String = "square.stack") {
        self.trackId = nil
        self.albumId = nil
        self.albumTitle = albumTitle
        self.albumArtist = albumArtist
        self.size = size
        self.cornerRadius = cornerRadius
        self.placeholderIcon = placeholderIcon
    }

    /// Initialize with a Track model (uses track.id for lookup)
    init(track: Track, size: CGFloat, cornerRadius: CGFloat = 8) {
        self.trackId = track.id
        self.albumId = nil
        self.albumTitle = nil
        self.albumArtist = nil
        self.size = size
        self.cornerRadius = cornerRadius
        self.placeholderIcon = "music.note"
    }

    /// Initialize with an Album model (uses album.id for lookup)
    init(album: Album, size: CGFloat, cornerRadius: CGFloat = 8) {
        self.trackId = nil
        self.albumId = album.id
        self.albumTitle = nil
        self.albumArtist = nil
        self.size = size
        self.cornerRadius = cornerRadius
        self.placeholderIcon = "square.stack"
    }

    // MARK: - Body

    var body: some View {
        artworkContent
            .frame(width: size, height: size)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .task(id: taskIdentifier) {
                await loadArtwork()
            }
    }

    // MARK: - Task Identifier

    private var taskIdentifier: String {
        if let trackId { return "track:\(trackId)" }
        if let albumId { return "album:\(albumId)" }
        if let title = albumTitle, let artist = albumArtist { return "name:\(title):\(artist)" }
        return "none"
    }

    // MARK: - Content Views

    @ViewBuilder
    private var artworkContent: some View {
        if let data = artworkData, let uiImage = UIImage(data: data) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            placeholder
        }
    }

    private var placeholder: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(Color.gray.opacity(0.3))
            .overlay {
                if isLoading {
                    ProgressView()
                        .scaleEffect(size > 60 ? 1.0 : 0.7)
                } else {
                    Image(systemName: placeholderIcon)
                        .font(.system(size: min(size * 0.4, 40)))
                        .foregroundStyle(.secondary)
                }
            }
    }

    // MARK: - Loading

    private func loadArtwork() async {
        guard let service = artworkService else { return }
        isLoading = true
        defer { isLoading = false }

        if let trackId {
            artworkData = await service.artwork(for: trackId)
        } else if let albumId {
            artworkData = await service.albumArtwork(for: albumId)
        } else if let title = albumTitle, let artist = albumArtist {
            artworkData = await service.albumArtwork(title: title, artist: artist)
        }
    }
}

// MARK: - Previews

#Preview("Track Artwork") {
    LazyArtworkView(trackId: UUID(), size: 60)
        .padding()
}

#Preview("Album Artwork") {
    LazyArtworkView(albumId: UUID(), size: 150)
        .padding()
}

#Preview("Album by Name") {
    LazyArtworkView(albumTitle: "Test Album", albumArtist: "Test Artist", size: 120)
        .padding()
}
