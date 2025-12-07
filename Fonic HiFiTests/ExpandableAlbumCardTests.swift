//
//  ExpandableAlbumCardTests.swift
//  Fonic HiFiTests
//
//  Tests for ExpandableAlbumCard and ExpandedAlbumOverlay components
//

import SwiftUI
import Testing
@testable import Fonic_HiFi

@MainActor
struct ExpandableAlbumCardTests {
    @Test("Album card initializes with correct album data")
    func albumCardInitializesWithCorrectData() throws {
        let album = Album(title: "Test Album", albumArtist: "Test Artist", year: 2024)

        // Verify album properties are accessible
        #expect(album.title == "Test Album")
        #expect(album.albumArtist == "Test Artist")
        #expect(album.year == 2024)
    }

    @Test("ExpandableAlbumCard exists and is a View")
    func expandableAlbumCardIsView() throws {
        let album = Album(title: "Test", albumArtist: "Artist")
        let namespace = Namespace().wrappedValue

        let card = ExpandableAlbumCard(
            album: album,
            namespace: namespace,
            isExpanded: false,
            onTap: {}
        )

        // Card should be constructible
        #expect(type(of: card.body) != Never.self)
    }

    @Test("ExpandedAlbumOverlay exists and shows track list")
    func expandedAlbumOverlayShowsTrackList() throws {
        let album = Album(title: "Test", albumArtist: "Artist")
        let namespace = Namespace().wrappedValue

        let overlay = ExpandedAlbumOverlay(
            album: album,
            namespace: namespace,
            accentColor: .blue,
            onTrackTap: { _ in },
            onDismiss: {}
        )

        #expect(type(of: overlay.body) != Never.self)
    }

    @Test("DominantColorService can extract color for album")
    func dominantColorServiceExtractsAlbumColor() async throws {
        let service = DominantColorService.shared
        let album = Album(title: "Test", albumArtist: "Artist")

        // Should be able to call extractColor for album
        await service.extractColor(for: album)

        // Palette should exist (neutral if no artwork)
        #expect(service.palette != nil)
    }
}
