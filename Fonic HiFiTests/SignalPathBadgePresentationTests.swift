@testable import Fonic_HiFi
import XCTest

@MainActor
final class SignalPathBadgePresentationTests: XCTestCase {
    func testEligibleBadgeNamesEligibilityWithoutClaimingMeasurement() {
        let presentation = SignalPathBadge.presentation(for: .eligible)

        XCTAssertEqual(presentation.title, "Eligible")
        XCTAssertEqual(presentation.systemImage, "checkmark.seal.fill")
        XCTAssertEqual(
            presentation.accessibilityValue,
            "Eligible based on measured engine evidence. Physical output is not measured."
        )
    }

    func testIneligibleBadgeCommunicatesActionWithoutColorAlone() {
        let presentation = SignalPathBadge.presentation(for: .ineligible)

        XCTAssertEqual(presentation.title, "Needs Changes")
        XCTAssertEqual(presentation.systemImage, "exclamationmark.triangle.fill")
        XCTAssertEqual(
            presentation.accessibilityValue,
            "Not eligible. Open the signal path for details."
        )
    }

    func testUnavailableBadgeDoesNotPresentEligibility() {
        let presentation = SignalPathBadge.presentation(for: .unavailable)

        XCTAssertEqual(presentation.title, "Unverified")
        XCTAssertEqual(presentation.systemImage, "questionmark.circle.fill")
        XCTAssertEqual(
            presentation.accessibilityValue,
            "Signal path has not been verified for the loaded track."
        )
    }
}
