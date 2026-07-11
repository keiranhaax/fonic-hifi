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
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 5), "Mini player not visible")
        XCTAssertTrue(
            app.staticTexts["Impulse Response"].waitForExistence(timeout: 3),
            "Preview track was not exposed in the mini player"
        )
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

    func testSmartSearchModeIsReachable() throws {
        let app = launchPreviewApp()

        let searchTab = app.buttons["Search"]
        XCTAssertTrue(searchTab.waitForExistence(timeout: 10), "Search tab not found")
        searchTab.tap()

        let searchMode = app.buttons["Search Mode"]
        XCTAssertTrue(searchMode.waitForExistence(timeout: 5), "Search mode control is not reachable")
        searchMode.tap()

        let smartSearch = app.buttons["Smart Search"]
        XCTAssertTrue(smartSearch.waitForExistence(timeout: 3), "Smart Search mode is not exposed")
        if smartSearch.isEnabled {
            smartSearch.tap()
            XCTAssertEqual(searchMode.value as? String, "Smart Search")
        } else {
            XCTAssertTrue(
                app.staticTexts["Smart Search is unavailable on this device."].waitForExistence(timeout: 3),
                "Unavailable Smart Search state is not explained"
            )
        }
    }

    func testEqualizerBandHasAccessibleAdjustmentTarget() throws {
        let app = launchPreviewApp()

        app.buttons["Settings"].tap()
        let equalizerLink = app.staticTexts["Equalizer"]
        XCTAssertTrue(equalizerLink.waitForExistence(timeout: 5), "Equalizer setting not found")
        equalizerLink.tap()

        let enableSwitch = app.switches["Enable Equalizer"]
        XCTAssertTrue(enableSwitch.waitForExistence(timeout: 5), "Equalizer enable switch not found")
        if enableSwitch.value as? String == "0" { enableSwitch.tap() }

        let band = app.descendants(matching: .any)["32 Hz"]
        XCTAssertTrue(band.waitForExistence(timeout: 5), "32 Hz band is not an adjustable control")
        XCTAssertGreaterThanOrEqual(band.frame.width, 44)
        XCTAssertGreaterThanOrEqual(band.frame.height, 44)
        XCTAssertTrue((band.value as? String)?.contains("decibels") == true)
    }

    func testAudioSettingsSlidersExposeLabelsAndUnits() throws {
        let app = launchPreviewApp()

        app.buttons["Settings"].tap()
        let audioSettingsLink = app.staticTexts["Audio Engine"]
        XCTAssertTrue(audioSettingsLink.waitForExistence(timeout: 5))
        audioSettingsLink.tap()
        app.swipeUp()

        let bufferSize = app.sliders["BufferSizeSlider"]
        XCTAssertTrue(bufferSize.waitForExistence(timeout: 5), "Buffer Size slider is not labeled")
        XCTAssertEqual(bufferSize.label, "Buffer Size")
        XCTAssertTrue((bufferSize.value as? String)?.contains("samples") == true)

        let crossfade = app.sliders["CrossfadeDurationSlider"]
        app.swipeUp()
        XCTAssertTrue(crossfade.waitForExistence(timeout: 5), "Crossfade slider is not labeled")
        XCTAssertEqual(crossfade.label, "Crossfade Duration")
        let crossfadeValue = crossfade.value as? String
        XCTAssertTrue(crossfadeValue == "Off" || crossfadeValue?.contains("seconds") == true)
    }

    func testNowPlayingSlidersExposeLabelsAndUnits() throws {
        let app = launchPreviewApp()

        let miniPlayer = app.otherElements["MiniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10))
        miniPlayer.tap()

        let volume = app.sliders["PlaybackVolumeSlider"]
        XCTAssertTrue(volume.waitForExistence(timeout: 5), "Playback volume slider is not labeled")
        XCTAssertEqual(volume.label, "Playback Volume")
        XCTAssertTrue((volume.value as? String)?.contains("percent") == true)

        app.buttons["More options"].tap()
        let sleepTimer = app.buttons["Sleep Timer"]
        XCTAssertTrue(sleepTimer.waitForExistence(timeout: 3))
        sleepTimer.tap()
        app.swipeUp()

        let fadeDuration = app.sliders["FadeOutDurationSlider"]
        XCTAssertTrue(fadeDuration.waitForExistence(timeout: 5), "Fade duration slider is not labeled")
        XCTAssertEqual(fadeDuration.label, "Fade Out Duration")
        XCTAssertTrue((fadeDuration.value as? String)?.contains("seconds") == true)
    }

    func testFavoriteAndLoopControlsMeetMinimumTargetSize() throws {
        let app = launchPreviewApp()
        let miniPlayer = app.otherElements["MiniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10))
        miniPlayer.tap()

        let favorite = app.buttons["Add to favorites"]
        XCTAssertTrue(favorite.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(favorite.frame.width, 44)
        XCTAssertGreaterThanOrEqual(favorite.frame.height, 44)

        let loop = app.buttons["Set loop point A"]
        XCTAssertTrue(loop.waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(loop.frame.width, 44)
        XCTAssertGreaterThanOrEqual(loop.frame.height, 44)
    }

    func testShuffleAndRepeatExposeStateValues() throws {
        let app = launchPreviewApp()
        let miniPlayer = app.otherElements["MiniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10))
        miniPlayer.tap()

        let shuffle = app.buttons["ShuffleButton"]
        XCTAssertTrue(shuffle.waitForExistence(timeout: 5))
        XCTAssertEqual(shuffle.label, "Shuffle")
        if shuffle.value as? String == "On" { shuffle.tap() }
        XCTAssertEqual(shuffle.value as? String, "Off")
        shuffle.tap()
        XCTAssertEqual(shuffle.value as? String, "On")

        let repeatButton = app.buttons["RepeatButton"]
        XCTAssertTrue(repeatButton.waitForExistence(timeout: 5))
        XCTAssertEqual(repeatButton.label, "Repeat")
        for _ in 0..<3 where repeatButton.value as? String != "Off" { repeatButton.tap() }
        XCTAssertEqual(repeatButton.value as? String, "Off")
        repeatButton.tap()
        XCTAssertEqual(repeatButton.value as? String, "All")
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
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 5), "Mini player not visible")
        XCTAssertTrue(
            app.staticTexts["Impulse Response"].waitForExistence(timeout: 3),
            "Preview track was not exposed in the mini player"
        )
        miniPlayer.tap()

        XCTAssertTrue(app.staticTexts["Now Playing"].waitForExistence(timeout: 5), "Now Playing did not present")

        let controlLabels = ["Previous track", "Next track"]
        for label in controlLabels {
            let control = app.buttons[label]
            XCTAssertTrue(control.waitForExistence(timeout: 3), "\(label) control is missing")
            control.tap()
        }
        XCTAssertTrue(app.buttons["Show queue"].waitForExistence(timeout: 3), "Show queue control is missing")
    }
}
