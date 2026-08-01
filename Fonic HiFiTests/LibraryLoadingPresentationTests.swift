import XCTest

@testable import Fonic_HiFi

@MainActor
final class LibraryLoadingPresentationTests: XCTestCase {
    func testInitialLoadUsesBlockingMessage() {
        XCTAssertEqual(
            LibraryView.loadingOverlayMessage(
                selectedTab: .tracks,
                phase: .initial
            ),
            "Loading tracks…"
        )
    }

    func testPaginationDoesNotUseBlockingMessage() {
        XCTAssertNil(
            LibraryView.loadingOverlayMessage(
                selectedTab: .tracks,
                phase: .pagination
            )
        )
    }

    func testIdleSectionDoesNotUseBlockingMessage() {
        XCTAssertNil(
            LibraryView.loadingOverlayMessage(
                selectedTab: .albums,
                phase: .idle
            )
        )
    }
}
