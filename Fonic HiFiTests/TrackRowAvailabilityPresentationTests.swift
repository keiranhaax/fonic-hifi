@testable import Fonic_HiFi
import Foundation
import XCTest

final class TrackRowAvailabilityPresentationTests: XCTestCase {
    func testAvailableTrackUsesPlayablePresentation() {
        let presentation = TrackRowAvailabilityPresentation(availability: .available)

        XCTAssertTrue(presentation.isPlaybackEnabled)
        XCTAssertNil(presentation.statusText)
        XCTAssertNil(presentation.systemImage)
        XCTAssertEqual(
            presentation.accessibilityLabel(title: "Signal", artist: "Artist"),
            "Play Signal by Artist"
        )
    }

    func testUnavailableTrackHasVisibleAndAccessibleDistinction() {
        let checkedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let presentation = TrackRowAvailabilityPresentation(
            availability: .temporarilyUnavailable(
                consecutiveMisses: 1,
                since: checkedAt,
                lastCheckedAt: checkedAt
            )
        )

        XCTAssertFalse(presentation.isPlaybackEnabled)
        XCTAssertEqual(presentation.statusText, "File unavailable")
        XCTAssertEqual(presentation.systemImage, "exclamationmark.triangle")
        XCTAssertEqual(
            presentation.accessibilityLabel(title: "Signal", artist: "Artist"),
            "Unavailable: Signal by Artist"
        )
        XCTAssertTrue(presentation.accessibilityHint.contains("check again"))
    }
}
