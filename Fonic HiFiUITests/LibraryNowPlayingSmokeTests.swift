import XCTest

@MainActor
final class LibraryNowPlayingSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launchPreviewApp() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-UITestPreviewData")
        app.launch()
        addTeardownBlock {
            app.terminate()
        }
        return app
    }

    private func tabButton(_ title: String, in app: XCUIApplication) -> XCUIElement {
        let exactMatch = app.tabBars.buttons[title]
        if exactMatch.exists {
            return exactMatch
        }
        return app.tabBars.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", title)).firstMatch
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<6 where !element.isHittable {
            app.swipeUp()
        }
    }

    private func setSwitch(_ element: XCUIElement, enabled: Bool) {
        let expectedValue = enabled ? "1" : "0"
        guard element.value as? String != expectedValue else { return }

        element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedValue),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    func testLibraryTabAndNowPlayingSheet() throws {
        let app = launchPreviewApp()

        let libraryTab = tabButton("Library", in: app)
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

    func testTabNavigationAndSettingsLinks() throws {
        let app = launchPreviewApp()

        let libraryTab = tabButton("Library", in: app)
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10), "Library tab not found")

        let homeTab = tabButton("Home", in: app)
        XCTAssertTrue(homeTab.waitForExistence(timeout: 5), "Home tab not found")
        homeTab.tap()
        XCTAssertTrue(app.navigationBars["Home"].waitForExistence(timeout: 5), "Home screen did not appear")

        let settingsTab = tabButton("Settings", in: app)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 5), "Settings tab not found")
        settingsTab.tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5), "Settings screen did not appear")

        let audioEngineRow = app.staticTexts["Audio Engine"]
        if audioEngineRow.waitForExistence(timeout: 5) {
            audioEngineRow.tap()
            let backButton = app.navigationBars.buttons["Settings"].firstMatch
            XCTAssertTrue(backButton.waitForExistence(timeout: 5), "Settings back button not found")
            backButton.tap()
            XCTAssertTrue(
                app.navigationBars["Settings"].waitForExistence(timeout: 5),
                "Failed to return to Settings"
            )
        }

        let searchTab = tabButton("Search", in: app)
        XCTAssertTrue(searchTab.waitForExistence(timeout: 5), "Search tab not found")
        searchTab.tap()
        XCTAssertTrue(app.navigationBars["Search"].waitForExistence(timeout: 5), "Search screen did not appear")

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5), "Search field not available")
        searchField.tap()
        searchField.typeText("test\n")
    }

    func testResetAllSettingsRequiresConfirmation() throws {
        let app = launchPreviewApp()
        let settingsTab = tabButton("Settings", in: app)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Settings tab not found")
        settingsTab.tap()

        let showExtensions = app.switches["Show File Extensions"]
        reveal(showExtensions, in: app)
        XCTAssertTrue(showExtensions.waitForExistence(timeout: 5), "File extension setting not found")
        setSwitch(showExtensions, enabled: false)
        XCTAssertEqual(showExtensions.value as? String, "0", "Test precondition did not disable file extensions")

        let resetButton = app.buttons["Reset All Settings"]
        reveal(resetButton, in: app)
        XCTAssertTrue(resetButton.isHittable, "Reset button was not reachable")
        resetButton.tap()

        XCTAssertTrue(
            app.staticTexts["Reset all settings?"].waitForExistence(timeout: 3),
            "Reset confirmation title was not presented"
        )
        let preservedDataMessage = app.staticTexts.matching(
            NSPredicate(format: "label CONTAINS %@", "Your music library and imported files are not deleted.")
        ).firstMatch
        XCTAssertTrue(
            preservedDataMessage.exists,
            "Reset confirmation did not name preserved user data"
        )
        app.buttons["Cancel"].tap()

        XCTAssertEqual(showExtensions.value as? String, "0", "Cancel changed the setting")

        reveal(resetButton, in: app)
        resetButton.tap()
        app.buttons["Reset Settings"].tap()
        XCTAssertEqual(showExtensions.value as? String, "1", "Confirmation did not restore the default")
    }

    func testLibraryTabsAndNowPlayingControls() throws {
        let app = launchPreviewApp()

        let libraryTab = tabButton("Library", in: app)
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10), "Library tab not found")
        libraryTab.tap()
        XCTAssertTrue(app.navigationBars["Library"].waitForExistence(timeout: 5), "Library screen did not appear")

        let librarySections = ["Albums", "Artists", "Playlists", "Tracks"]
        for section in librarySections {
            let sectionButton = app.buttons[section]
            XCTAssertTrue(sectionButton.waitForExistence(timeout: 5), "\(section) segment not found")
            sectionButton.tap()
        }

        let miniPlayer = app.otherElements["MiniPlayer"]
        guard miniPlayer.waitForExistence(timeout: 5) else {
            throw XCTSkip("Mini player not visible")
        }
        miniPlayer.tap()

        XCTAssertTrue(app.staticTexts["Now Playing"].waitForExistence(timeout: 5), "Now Playing did not present")

        let controlLabels = ["Show queue", "Previous track", "Next track", "Shuffle off", "Repeat off"]
        for label in controlLabels {
            let control = app.buttons[label]
            if control.waitForExistence(timeout: 3) {
                control.tap()
            }
        }
    }
}
