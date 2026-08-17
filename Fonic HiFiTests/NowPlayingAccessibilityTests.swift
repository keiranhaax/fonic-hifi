@testable import Fonic_HiFi
import SwiftUI
import XCTest

@MainActor
final class NowPlayingAccessibilityTests: XCTestCase {
    func testLyricsTransitionAnimationRespectsReduceMotion() {
        XCTAssertNil(NowPlayingContent.lyricsTransitionAnimation(reduceMotion: true))
        XCTAssertNotNil(NowPlayingContent.lyricsTransitionAnimation(reduceMotion: false))
    }

    func testArtworkUsesAvailableHeightAndAccessibilityTextSize() {
        let portrait = NowPlayingContent.adaptiveArtworkSize(
            for: CGSize(width: 390, height: 844),
            accessibilityText: false
        )
        let landscape = NowPlayingContent.adaptiveArtworkSize(
            for: CGSize(width: 844, height: 390),
            accessibilityText: false
        )
        let accessibility = NowPlayingContent.adaptiveArtworkSize(
            for: CGSize(width: 390, height: 844),
            accessibilityText: true
        )

        XCTAssertGreaterThan(portrait, landscape)
        XCTAssertLessThan(accessibility, portrait)
        XCTAssertGreaterThanOrEqual(landscape, 120)
        XCTAssertLessThanOrEqual(portrait, 400)
    }

    func testArtworkNeverExceedsNarrowContainerContentWidth() {
        let containerWidth: CGFloat = 140
        let artwork = NowPlayingContent.adaptiveArtworkSize(
            for: CGSize(width: containerWidth, height: 300),
            accessibilityText: true
        )
        let availableWidth = containerWidth - (DesignTokens.Spacing.xLarge * 2)

        XCTAssertGreaterThanOrEqual(artwork, 0)
        XCTAssertLessThanOrEqual(artwork, availableWidth)
    }

    func testActivePlaybackModesHaveNonColorCue() {
        let active = NowPlayingContent.playbackModeVisualState(
            isActive: true,
            differentiateWithoutColor: false
        )
        let inactive = NowPlayingContent.playbackModeVisualState(
            isActive: false,
            differentiateWithoutColor: false
        )
        let differentiatedInactive = NowPlayingContent.playbackModeVisualState(
            isActive: false,
            differentiateWithoutColor: true
        )

        XCTAssertTrue(active.showsBadge)
        XCTAssertTrue(active.showsOutline)
        XCTAssertGreaterThan(active.outlineWidth, inactive.outlineWidth)
        XCTAssertFalse(inactive.showsBadge)
        XCTAssertFalse(inactive.showsOutline)
        XCTAssertTrue(differentiatedInactive.showsOutline)
    }
}
