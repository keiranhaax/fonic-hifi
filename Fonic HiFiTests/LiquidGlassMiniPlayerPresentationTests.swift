@testable import Fonic_HiFi
import XCTest

@MainActor
final class LiquidGlassMiniPlayerPresentationTests: XCTestCase {
    func testExpandedAccessoryShowsFullMiniPlayerContent() {
        let presentation = LiquidGlassMiniPlayer.accessoryPresentation(for: .expanded)

        XCTAssertFalse(presentation.isInline)
        XCTAssertTrue(presentation.showsArtwork)
        XCTAssertTrue(presentation.showsArtist)
        XCTAssertTrue(presentation.showsNextButton)
        XCTAssertEqual(presentation.horizontalSpacing, 15)
        XCTAssertEqual(presentation.infoSpacing, 12)
        XCTAssertEqual(presentation.horizontalPadding, 15)
    }

    func testInlineAccessoryUsesCompactMiniPlayerContent() {
        let presentation = LiquidGlassMiniPlayer.accessoryPresentation(for: .inline)

        XCTAssertTrue(presentation.isInline)
        XCTAssertFalse(presentation.showsArtwork)
        XCTAssertFalse(presentation.showsArtist)
        XCTAssertFalse(presentation.showsNextButton)
        XCTAssertEqual(presentation.horizontalSpacing, 8)
        XCTAssertEqual(presentation.infoSpacing, 6)
        XCTAssertEqual(presentation.horizontalPadding, 8)
    }

    func testMissingAccessoryPlacementFallsBackToExpandedContent() {
        let presentation = LiquidGlassMiniPlayer.accessoryPresentation(for: nil)

        XCTAssertFalse(presentation.isInline)
        XCTAssertTrue(presentation.showsArtwork)
        XCTAssertTrue(presentation.showsArtist)
        XCTAssertTrue(presentation.showsNextButton)
    }
}
