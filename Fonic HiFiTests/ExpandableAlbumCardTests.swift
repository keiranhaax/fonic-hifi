//
//  ExpandableAlbumCardTests.swift
//  Fonic HiFiTests
//
//  Tests for ExpandableAlbumCard and AlbumSheetView components
//

@testable import Fonic_HiFi
import SwiftUI
import Testing

@MainActor
struct ExpandableAlbumCardTests {
    @Test("Album card initializes with correct album data")
    func albumCardInitializesWithCorrectData() {
        let album = Album(title: "Test Album", albumArtist: "Test Artist", year: 2024)

        // Verify album properties are accessible
        #expect(album.title == "Test Album")
        #expect(album.albumArtist == "Test Artist")
        #expect(album.year == 2024)
    }

    @Test("ExpandableAlbumCard stores its album and conforms to View")
    func expandableAlbumCardIsView() {
        let album = Album(title: "Test", albumArtist: "Artist")

        let card = ExpandableAlbumCard(
            album: album,
            onTap: {}
        )

        #expect(isView(card))
        #expect(card.album.id == album.id)
    }

    @Test("AlbumSheetView stores its album and conforms to View")
    func albumSheetViewIsView() {
        let album = Album(title: "Test", albumArtist: "Artist")

        let sheet = AlbumSheetView(
            album: album,
            onTrackTap: { _ in }
        )

        #expect(isView(sheet))
        #expect(sheet.album.id == album.id)
    }

    @Test("DominantColorService can extract color for album")
    func dominantColorServiceExtractsAlbumColor() async {
        let service = DominantColorService.shared
        let album = Album(title: "Test", albumArtist: "Artist")

        // Should be able to call extractColor for album
        await service.extractColor(for: album)

        // Service should track the active album after extraction
        #expect(service.currentTrackID == album.id)
    }

    private func isView<Content: View>(_: Content) -> Bool {
        true
    }
}
