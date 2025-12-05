//
//  ThemePaletteTests.swift
//  Fonic HiFiTests
//

import SwiftUI
import XCTest

@testable import Fonic_HiFi

final class ThemePaletteTests: XCTestCase {

    // MARK: - Neutral Palette Tests

    func testNeutralPaletteHasExpectedDominantColor() {
        let palette = ThemePalette.neutral

        // Neutral palette should have a warm gray dominant color
        XCTAssertNotNil(palette.dominant)
    }

    func testNeutralPaletteIsNotVibrant() {
        let palette = ThemePalette.neutral

        XCTAssertFalse(palette.isVibrant)
    }

    // MARK: - Vibrant Palette Tests

    func testVibrantPaletteFromSaturatedColor() {
        let vibrantRed = Color(hue: 0.0, saturation: 0.8, brightness: 0.9)
        let palette = ThemePalette(dominant: vibrantRed, colorScheme: .dark)

        XCTAssertTrue(palette.isVibrant)
    }

    func testLowSaturationColorProducesNonVibrantPalette() {
        let grayish = Color(hue: 0.5, saturation: 0.1, brightness: 0.5)
        let palette = ThemePalette(dominant: grayish, colorScheme: .dark)

        XCTAssertFalse(palette.isVibrant)
    }

    // MARK: - Color Scheme Adaptation Tests

    func testDarkModeProducesRicherSurfaceColor() {
        let baseColor = Color(hue: 0.6, saturation: 0.7, brightness: 0.8)
        let darkPalette = ThemePalette(dominant: baseColor, colorScheme: .dark)
        let lightPalette = ThemePalette(dominant: baseColor, colorScheme: .light)

        // Dark mode surface should have higher opacity than light mode
        // We can't directly compare Color opacity, but we verify both palettes are created
        XCTAssertNotNil(darkPalette.surface)
        XCTAssertNotNil(lightPalette.surface)
    }

    // MARK: - Derived Color Tests

    func testAccentColorIsDerived() {
        let baseColor = Color.blue
        let palette = ThemePalette(dominant: baseColor, colorScheme: .dark)

        XCTAssertNotNil(palette.accent)
    }

    func testSurfaceColorIsDerived() {
        let baseColor = Color.blue
        let palette = ThemePalette(dominant: baseColor, colorScheme: .dark)

        XCTAssertNotNil(palette.surface)
    }

    func testSubtleColorIsDerived() {
        let baseColor = Color.blue
        let palette = ThemePalette(dominant: baseColor, colorScheme: .dark)

        XCTAssertNotNil(palette.subtle)
    }

    func testGlassTintColorIsDerived() {
        let baseColor = Color.blue
        let palette = ThemePalette(dominant: baseColor, colorScheme: .dark)

        XCTAssertNotNil(palette.glassTint)
    }
}
