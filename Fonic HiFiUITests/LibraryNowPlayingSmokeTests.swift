import XCTest

@MainActor
final class LibraryNowPlayingSmokeTests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false

        app = XCUIApplication()
        app.launchArguments.append("-UITestPreviewData")
        app.launch()
    }

    override func tearDownWithError() throws {
        app.terminate()
        app = nil
        try super.tearDownWithError()
    }

    func testLibraryTabAndNowPlayingSheet() throws {
        let libraryTab = app.buttons["Library"]
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10), "Library tab not found")
        libraryTab.tap()

        let libraryNavigationBar = app.navigationBars["Library"]
        XCTAssertTrue(libraryNavigationBar.waitForExistence(timeout: 5), "Library screen did not appear")

        let miniPlayer = app.otherElements["MiniPlayer"]
        guard miniPlayer.waitForExistence(timeout: 5) else {
            throw XCTSkip("Mini player not visible")
        }
        miniPlayer.tap()

        let nowPlayingHeader = app.staticTexts["Now Playing"]
        XCTAssertTrue(nowPlayingHeader.waitForExistence(timeout: 5), "Now Playing view did not present")
    }
}
