//
//  DominantColorServiceTests.swift
//  Fonic HiFiTests
//

import SwiftUI
import XCTest

@testable import Fonic_HiFi

@MainActor
final class DominantColorServiceTests: XCTestCase {

    var sut: DominantColorService!

    override func setUp() async throws {
        sut = DominantColorService.shared
        sut.reset()
    }

    // MARK: - Palette Tests

    func testInitialPaletteIsNeutral() {
        // When no track has been processed, palette should be neutral
        XCTAssertFalse(sut.palette.isVibrant)
    }

    func testPaletteUpdatesWhenColorSchemeChanges() {
        // Update color scheme
        sut.updateColorScheme(.light)
        let lightPalette = sut.palette

        sut.updateColorScheme(.dark)
        let darkPalette = sut.palette

        // Palettes should differ in color scheme
        XCTAssertEqual(lightPalette.colorScheme, .light)
        XCTAssertEqual(darkPalette.colorScheme, .dark)
    }

    func testPaletteRespectsThemingDisabled() {
        // Disable theming
        sut.updateThemingEnabled(false)

        // Palette should be neutral even if a color was extracted
        XCTAssertFalse(sut.palette.isVibrant)
    }

    func testResetClearsPaletteToNeutral() {
        // Reset should clear to neutral
        sut.reset()

        XCTAssertFalse(sut.palette.isVibrant)
        XCTAssertNil(sut.currentTrackID)
    }
}
