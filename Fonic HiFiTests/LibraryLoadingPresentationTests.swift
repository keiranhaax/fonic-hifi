import XCTest

@testable import Fonic_HiFi

@MainActor
final class LibraryLoadingPresentationTests: XCTestCase {
    func testInitialLoadUsesBlockingMessage() {
        XCTAssertEqual(
            LibraryView.loadingOverlayMessage(
                selectedTab: .tracks,
                loadingSection: .tracks,
                itemCount: 0
            ),
            "Loading tracks…"
        )
    }

    func testPaginationDoesNotUseBlockingMessage() {
        XCTAssertNil(
            LibraryView.loadingOverlayMessage(
                selectedTab: .tracks,
                loadingSection: .tracks,
                itemCount: 25
            )
        )
    }

    func testBackgroundSectionLoadDoesNotBlockSelectedTab() {
        XCTAssertNil(
            LibraryView.loadingOverlayMessage(
                selectedTab: .albums,
                loadingSection: .tracks,
                itemCount: 0
            )
        )
    }
}
