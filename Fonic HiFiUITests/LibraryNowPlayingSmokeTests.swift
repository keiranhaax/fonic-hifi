import XCTest

@MainActor
final class LibraryNowPlayingSmokeTests: XCTestCase {
    override func setUpWithError() throws {
        try super.setUpWithError()
        continueAfterFailure = false
    }

    private func launchPreviewApp(arguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments.append("-UITestPreviewData")
        app.launchArguments.append(contentsOf: arguments)
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

        XCTAssertTrue(element.isHittable)
        element.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.5)).tap()
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "value == %@", expectedValue),
            object: element
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
    }

    private func assertMinimumTouchTarget(
        _ element: XCUIElement,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let measurementTolerance = 0.01
        XCTAssertGreaterThanOrEqual(
            element.frame.width,
            44 - measurementTolerance,
            file: file,
            line: line
        )
        XCTAssertGreaterThanOrEqual(
            element.frame.height,
            44 - measurementTolerance,
            file: file,
            line: line
        )
    }

    private func attachScreenshot(
        of _: XCUIApplication,
        named name: String
    ) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private func waitForOrientation(
        _ orientation: UIDeviceOrientation,
        in app: XCUIApplication
    ) {
        let window = app.windows.firstMatch
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate { object, _ in
                guard let element = object as? XCUIElement else { return false }
                let frame = element.frame
                return orientation.isLandscape
                    ? frame.width > frame.height
                    : frame.height > frame.width
            },
            object: window
        )
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
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

        let dismissNowPlaying = app.buttons["DismissNowPlayingButton"]
        XCTAssertTrue(dismissNowPlaying.waitForExistence(timeout: 3))
        XCTAssertTrue(dismissNowPlaying.isHittable)
        assertMinimumTouchTarget(dismissNowPlaying)
        dismissNowPlaying.tap()
        XCTAssertFalse(nowPlayingHeader.waitForExistence(timeout: 1))
    }

    func testNowPlayingAX5SmallPhoneInitialViewports() throws {
        addTeardownBlock {
            XCUIDevice.shared.orientation = .portrait
        }

        let orientations: [(name: String, value: UIDeviceOrientation)] = [
            ("portrait", .portrait),
            ("landscape", .landscapeLeft),
        ]

        for orientation in orientations {
            XCUIDevice.shared.orientation = orientation.value
            let app = launchPreviewApp()
            waitForOrientation(orientation.value, in: app)

            let miniPlayer = app.otherElements["MiniPlayer"]
            XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10))
            miniPlayer.tap()

            let nowPlayingHeader = app.staticTexts["Now Playing"]
            XCTAssertTrue(nowPlayingHeader.waitForExistence(timeout: 5))

            let dismiss = app.buttons["DismissNowPlayingButton"]
            XCTAssertTrue(dismiss.isHittable)
            assertMinimumTouchTarget(dismiss)

            XCTAssertTrue(app.buttons["ShuffleButton"].exists)
            XCTAssertTrue(app.buttons["Previous track"].exists)
            XCTAssertTrue(app.buttons["Next track"].exists)
            XCTAssertTrue(app.buttons["RepeatButton"].exists)
            XCTAssertTrue(app.sliders["PlaybackVolumeSlider"].exists)

            attachScreenshot(
                of: app,
                named: "Now Playing - iPhone 17e - AX5 - \(orientation.name) - initial viewport"
            )
            app.terminate()
        }
    }

    func testDoubleLengthAndRightToLeftInitialViewports() throws {
        let configurations: [(name: String, arguments: [String])] = [
            (
                "double-length",
                ["-UITestLibraryData", "-NSDoubleLocalizedStrings", "YES"]
            ),
            (
                "right-to-left",
                [
                    "-UITestLibraryData",
                    "-AppleTextDirection",
                    "YES",
                    "-NSForceRightToLeftWritingDirection",
                    "YES",
                    "-NSForceRightToLeftLocalizedStrings",
                    "YES",
                ]
            ),
        ]

        for configuration in configurations {
            let app = launchPreviewApp(arguments: configuration.arguments)
            let tabBar = app.tabBars.firstMatch
            XCTAssertTrue(tabBar.waitForExistence(timeout: 10))

            if configuration.name == "double-length" {
                for title in ["Home", "Library", "Settings", "Search"] {
                    let button = tabButton(title, in: app)
                    XCTAssertTrue(button.exists, "\(title) tab lost its semantic label")
                    XCTAssertTrue(
                        button.label.localizedCaseInsensitiveContains(title),
                        "\(title) tab exposed an icon name instead of localized text"
                    )
                }

                for title in ["Shuffle All", "Surprise Me"] {
                    let button = app.buttons
                        .matching(NSPredicate(format: "label CONTAINS[c] %@", title))
                        .firstMatch
                    XCTAssertTrue(button.waitForExistence(timeout: 5))
                    XCTAssertTrue(button.isHittable)
                    assertMinimumTouchTarget(button)
                }
            }

            attachScreenshot(
                of: app,
                named: "Localization - \(configuration.name) - Home"
            )

            tabBar.buttons.element(boundBy: 1).tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(
                of: app,
                named: "Localization - \(configuration.name) - Library"
            )

            tabBar.buttons.element(boundBy: 2).tap()
            XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 5))
            attachScreenshot(
                of: app,
                named: "Localization - \(configuration.name) - Settings"
            )

            let miniPlayer = app.otherElements["MiniPlayer"]
            XCTAssertTrue(miniPlayer.waitForExistence(timeout: 5))
            miniPlayer.tap()
            let dismiss = app.buttons["DismissNowPlayingButton"]
            XCTAssertTrue(dismiss.waitForExistence(timeout: 5))
            XCTAssertTrue(dismiss.isHittable)
            XCTAssertFalse(dismiss.label.isEmpty)
            attachScreenshot(
                of: app,
                named: "Localization - \(configuration.name) - Now Playing"
            )

            app.terminate()
        }
    }

    func testMiniPlayerIsHiddenWithoutCurrentTrack() throws {
        let app = launchPreviewApp(arguments: [
            "-UITestNoCurrentTrack",
            "-UITestResetQueuePersistence",
        ])

        XCTAssertTrue(tabButton("Home", in: app).waitForExistence(timeout: 10))
        XCTAssertFalse(
            app.otherElements["MiniPlayer"].waitForExistence(timeout: 1),
            "Mini player rendered without an authoritative current track"
        )
    }

    func testRootPlaybackErrorHasSemanticDismissal() throws {
        let app = launchPreviewApp(arguments: ["-UITestPlaybackError"])

        let banner = app.otherElements["RootPlaybackErrorBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 10), "Root playback error did not appear")
        XCTAssertTrue(
            app.staticTexts["Playback failed: UI testing."].exists,
            "Playback error text was not exposed"
        )

        let dismissButton = app.buttons["Dismiss playback error"]
        XCTAssertTrue(dismissButton.isHittable, "Playback error dismissal was not semantic")
        XCTAssertGreaterThanOrEqual(dismissButton.frame.width, 44)
        XCTAssertGreaterThanOrEqual(dismissButton.frame.height, 44)
        dismissButton.tap()

        XCTAssertFalse(banner.waitForExistence(timeout: 1), "Dismissed root playback error remained visible")
    }

    func testNowPlayingPlaybackErrorHasSemanticDismissal() throws {
        let app = launchPreviewApp(arguments: ["-UITestPlaybackError"])

        let miniPlayer = app.otherElements["MiniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10), "Mini player not visible")
        miniPlayer.tap()

        let banner = app.otherElements["NowPlayingPlaybackErrorBanner"]
        XCTAssertTrue(banner.waitForExistence(timeout: 5), "Now Playing playback error did not appear")
        let dismissButton = banner.buttons["Dismiss playback error"]
        XCTAssertTrue(dismissButton.isHittable, "Now Playing error dismissal was not semantic")
        dismissButton.tap()

        XCTAssertFalse(banner.waitForExistence(timeout: 1), "Dismissed Now Playing error remained visible")
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

        let searchMode = app.buttons["SearchModeMenu"]
        XCTAssertTrue(searchMode.waitForExistence(timeout: 5), "Search mode control is not reachable")
        XCTAssertEqual(searchMode.label, "Search Mode, Standard Search")
        searchMode.tap()

        let smartSearch = app.buttons["Smart Search"]
        XCTAssertTrue(smartSearch.waitForExistence(timeout: 3), "Smart Search mode is not exposed")
        if smartSearch.isEnabled {
            smartSearch.tap()
            let selectedMode = app.buttons["SearchModeMenu"]
            let expectation = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "Search Mode, Smart Search"),
                object: selectedMode
            )
            XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 3), .completed)
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

    func testAudioSettingsExposeOnlyAppliedPlaybackControls() throws {
        let app = launchPreviewApp()

        app.buttons["Settings"].tap()
        XCTAssertFalse(app.switches["Bit-Perfect Mode"].exists)
        let audioSettingsLink = app.staticTexts["Audio Engine"]
        XCTAssertTrue(audioSettingsLink.waitForExistence(timeout: 5))
        audioSettingsLink.tap()
        app.swipeUp()

        XCTAssertFalse(app.switches["Enable Bit-Perfect Playback"].exists)
        XCTAssertFalse(app.sliders["BufferSizeSlider"].exists)
        XCTAssertFalse(app.buttons["Sample Rate"].exists)

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
        assertMinimumTouchTarget(favorite)

        let loop = app.buttons["Set loop point A"]
        XCTAssertTrue(loop.waitForExistence(timeout: 5))
        assertMinimumTouchTarget(loop)
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

    func testLyricsOverlayProvidesModalAccessibility() throws {
        let app = launchPreviewApp()
        let miniPlayer = app.otherElements["MiniPlayer"]
        XCTAssertTrue(miniPlayer.waitForExistence(timeout: 10))
        miniPlayer.tap()

        app.buttons["More options"].tap()
        let lyrics = app.buttons["Lyrics"]
        XCTAssertTrue(lyrics.waitForExistence(timeout: 3))
        XCTAssertTrue(lyrics.isEnabled)
        lyrics.tap()

        let lyricsModal = app.descendants(matching: .any)["LyricsModal"]
        XCTAssertTrue(lyricsModal.waitForExistence(timeout: 3))
        let closeLyrics = app.buttons["Close lyrics"]
        XCTAssertTrue(closeLyrics.waitForExistence(timeout: 3))
        XCTAssertTrue(closeLyrics.isHittable)
        XCTAssertEqual(closeLyrics.frame.width, 44, accuracy: 0.01)
        XCTAssertEqual(closeLyrics.frame.height, 44, accuracy: 0.01)
        XCTAssertTrue(app.staticTexts["Reference lyrics for accessibility testing."].exists)
        XCTAssertFalse(app.buttons["More options"].exists)

        closeLyrics.tap()
        XCTAssertFalse(lyricsModal.exists)
        XCTAssertFalse(closeLyrics.exists)
        XCTAssertTrue(app.buttons["More options"].waitForExistence(timeout: 3))
    }

    func testResetAllSettingsRequiresConfirmation() throws {
        let app = launchPreviewApp()
        let settingsTab = tabButton("Settings", in: app)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10), "Settings tab not found")
        settingsTab.tap()

        let showExtensions = app.switches["Show File Extensions"]
        reveal(showExtensions, in: app)
        let miniPlayer = app.otherElements["MiniPlayer"]
        for _ in 0..<6 where showExtensions.frame.maxY > miniPlayer.frame.minY {
            app.swipeUp()
        }
        XCTAssertTrue(showExtensions.waitForExistence(timeout: 5), "File extension setting not found")
        XCTAssertLessThanOrEqual(showExtensions.frame.maxY, miniPlayer.frame.minY)
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

    func testFileManagerExposesTouchSelectionMode() throws {
        let app = launchPreviewApp(arguments: ["-UITestFileManagerData"])
        let settingsTab = tabButton("Settings", in: app)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()

        let fileManager = app.staticTexts["File Manager"]
        reveal(fileManager, in: app)
        XCTAssertTrue(fileManager.waitForExistence(timeout: 5))
        fileManager.tap()

        let edit = app.buttons["Edit"]
        XCTAssertTrue(edit.waitForExistence(timeout: 5))
        edit.tap()
        XCTAssertTrue(app.buttons["Done"].waitForExistence(timeout: 3))

        let fixtures = [
            app.staticTexts["UI Test Track.mp3"],
            app.staticTexts["UI Test Album.flac"],
            app.staticTexts["UI Test Folder"],
        ]
        for fixture in fixtures {
            XCTAssertTrue(fixture.waitForExistence(timeout: 5))
            fixture.tap()
        }

        let importSelected = app.buttons["Import Selected"]
        XCTAssertTrue(importSelected.waitForExistence(timeout: 3))
        XCTAssertTrue(importSelected.isEnabled)
        let deleteSelected = app.buttons["DeleteSelectedFilesButton"]
        XCTAssertTrue(deleteSelected.waitForExistence(timeout: 3))
        XCTAssertEqual(deleteSelected.label, "Delete 3 files")
        deleteSelected.tap()
        XCTAssertTrue(app.staticTexts["Delete Files"].waitForExistence(timeout: 3))
        app.buttons["Cancel"].tap()

        importSelected.tap()
        let importProgress = app.otherElements["ImportProgressView"]
        XCTAssertTrue(importProgress.waitForExistence(timeout: 5))

        let progressDone = app.navigationBars["Importing Music"].buttons["Done"]
        XCTAssertTrue(progressDone.waitForExistence(timeout: 10))
        progressDone.tap()

        let finishEditing = app.buttons["Done"]
        XCTAssertTrue(finishEditing.waitForExistence(timeout: 3))
        finishEditing.tap()
        XCTAssertTrue(app.buttons["Edit"].waitForExistence(timeout: 3))
    }

    func testFileDetailsImportShowsObservedProgress() throws {
        let app = launchPreviewApp(arguments: ["-UITestFileManagerData"])
        let settingsTab = tabButton("Settings", in: app)
        XCTAssertTrue(settingsTab.waitForExistence(timeout: 10))
        settingsTab.tap()

        let fileManager = app.staticTexts["File Manager"]
        reveal(fileManager, in: app)
        XCTAssertTrue(fileManager.waitForExistence(timeout: 5))
        fileManager.tap()

        let track = app.staticTexts["UI Test Track.mp3"]
        XCTAssertTrue(track.waitForExistence(timeout: 5))
        track.tap()

        let importButton = app.buttons["Import to Library"]
        XCTAssertTrue(importButton.waitForExistence(timeout: 5))
        importButton.tap()

        let importProgress = app.otherElements["ImportProgressView"]
        XCTAssertTrue(importProgress.waitForExistence(timeout: 5))
        XCTAssertTrue(app.navigationBars["Importing Music"].buttons["Done"].waitForExistence(timeout: 10))
    }

    func testMiniPlayerExposesSeparateSemanticActions() throws {
        let app = launchPreviewApp()

        let openNowPlaying = app.buttons["Open Now Playing"]
        XCTAssertTrue(openNowPlaying.waitForExistence(timeout: 10))
        let play = app.buttons["Play"]
        let next = app.buttons["Next Track"]
        XCTAssertTrue(play.exists)
        XCTAssertTrue(next.exists)

        openNowPlaying.tap()
        let nowPlaying = app.staticTexts["Now Playing"]
        XCTAssertTrue(nowPlaying.waitForExistence(timeout: 5))
        app.buttons["DismissNowPlayingButton"].tap()
        XCTAssertFalse(nowPlaying.waitForExistence(timeout: 1))

        play.tap()
        XCTAssertFalse(nowPlaying.exists)
        next.tap()
        XCTAssertFalse(nowPlaying.exists)
    }

    func testLibraryTrackExposesSeparatePlayAndInformationActions() throws {
        let app = launchPreviewApp(arguments: ["-UITestLibraryData"])
        let libraryTab = tabButton("Library", in: app)
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10))
        libraryTab.tap()

        XCTAssertTrue(app.staticTexts["Semantic Track"].waitForExistence(timeout: 5))
        let play = app.buttons["Play Semantic Track by Semantic Artist"]
        let information = app.buttons["Track information for Semantic Track"]
        XCTAssertTrue(play.exists)
        XCTAssertTrue(information.exists)

        information.tap()
        XCTAssertTrue(app.navigationBars["Track Details"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        play.tap()
        XCTAssertTrue(app.staticTexts["Now Playing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Semantic Track"].exists)
    }

    func testQueueRestoresAfterBackgroundTerminationAndRelaunch() throws {
        let app = launchPreviewApp(arguments: [
            "-UITestLibraryData",
            "-UITestNoCurrentTrack",
            "-UITestResetQueuePersistence",
        ])

        let libraryTab = tabButton("Library", in: app)
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10))
        libraryTab.tap()

        let play = app.buttons["Play Semantic Track by Semantic Artist"]
        XCTAssertTrue(play.waitForExistence(timeout: 5))
        play.tap()
        XCTAssertTrue(app.staticTexts["Now Playing"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Semantic Track"].exists)

        XCUIDevice.shared.press(.home)
        let backgrounded = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "state == %d", XCUIApplication.State.runningBackground.rawValue),
            object: app
        )
        XCTAssertEqual(XCTWaiter.wait(for: [backgrounded], timeout: 5), .completed)
        app.terminate()

        app.launchArguments = [
            "-UITestPreviewData",
            "-UITestLibraryData",
            "-UITestNoCurrentTrack",
        ]
        app.launch()

        XCTAssertTrue(app.otherElements["MiniPlayer"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts["Semantic Track"].exists)
    }

    func testLibraryCollectionsExposeSemanticDetailActions() throws {
        let app = launchPreviewApp(arguments: ["-UITestLibraryData"])
        let libraryTab = tabButton("Library", in: app)
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10))
        libraryTab.tap()

        app.buttons["Albums"].tap()
        let album = app.buttons.matching(
            NSPredicate(format: "label == %@", "Open album Semantic Album by Semantic Artist")
        ).firstMatch
        XCTAssertTrue(album.waitForExistence(timeout: 5))
        album.tap()
        XCTAssertTrue(app.navigationBars["Album"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        app.buttons["Artists"].tap()
        let artist = app.buttons["Open artist Semantic Artist"]
        XCTAssertTrue(artist.waitForExistence(timeout: 5))
        artist.tap()
        XCTAssertTrue(app.navigationBars["Artist"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        app.buttons["Playlists"].tap()
        let playlist = app.buttons["Open playlist Semantic Playlist"]
        XCTAssertTrue(playlist.waitForExistence(timeout: 5))
        playlist.tap()
        XCTAssertTrue(app.navigationBars["Semantic Playlist"].waitForExistence(timeout: 3))
    }

    func testStandardSearchResultsExposeSemanticActions() throws {
        let app = launchPreviewApp(arguments: ["-UITestLibraryData"])
        let searchTab = tabButton("Search", in: app)
        XCTAssertTrue(searchTab.waitForExistence(timeout: 10))
        searchTab.tap()

        let searchField = app.searchFields.firstMatch
        XCTAssertTrue(searchField.waitForExistence(timeout: 5))
        searchField.tap()
        searchField.typeText("Semantic")
        app.keyboards.buttons["search"].tap()

        XCTAssertTrue(app.buttons["Play Semantic Track by Semantic Artist"].waitForExistence(timeout: 5))
        let album = app.buttons["Open album Semantic Album by Semantic Artist"]
        let artist = app.buttons["Open artist Semantic Artist"]
        let playlist = app.buttons["Open playlist Semantic Playlist"]
        XCTAssertTrue(album.exists)
        XCTAssertTrue(artist.exists)
        XCTAssertTrue(playlist.exists)

        album.tap()
        XCTAssertTrue(app.navigationBars["Semantic Album"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        artist.tap()
        XCTAssertTrue(app.navigationBars["Artist"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        playlist.tap()
        XCTAssertTrue(app.navigationBars["Semantic Playlist"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        let play = app.buttons["Play Semantic Track by Semantic Artist"]
        for _ in 0..<4 where !play.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(play.isHittable)
        play.tap()
        XCTAssertTrue(app.staticTexts["Now Playing"].waitForExistence(timeout: 5))
    }

    func testHomeBrowseSectionsExposeWorkingSemanticActions() throws {
        let app = launchPreviewApp(arguments: ["-UITestLibraryData"])

        let playActions = app.buttons.matching(
            NSPredicate(format: "label == %@", "Play Semantic Track by Semantic Artist")
        )
        let play = playActions.firstMatch
        XCTAssertTrue(play.waitForExistence(timeout: 10))
        XCTAssertGreaterThanOrEqual(playActions.count, 3)
        let artist = app.buttons["Open artist Semantic Artist"]
        let album = app.buttons.matching(
            NSPredicate(format: "label == %@", "Open album Semantic Album by Semantic Artist")
        ).firstMatch
        let genre = app.buttons["Electronic"]
        XCTAssertTrue(artist.exists)
        XCTAssertTrue(album.exists)
        XCTAssertTrue(genre.exists)

        reveal(artist, in: app)
        artist.tap()
        XCTAssertTrue(app.navigationBars["Artist"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        reveal(genre, in: app)
        let miniPlayer = app.otherElements["MiniPlayer"]
        for _ in 0 ..< 6 where genre.frame.maxY > miniPlayer.frame.minY {
            app.swipeUp()
        }
        XCTAssertTrue(genre.isHittable)
        XCTAssertLessThanOrEqual(genre.frame.maxY, miniPlayer.frame.minY)
        assertMinimumTouchTarget(genre)
        genre.tap()
        XCTAssertTrue(app.navigationBars["Electronic"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.staticTexts["1 track"].waitForExistence(timeout: 3))
        XCTAssertTrue(app.buttons["Play Semantic Track by Semantic Artist"].exists)
        app.buttons["Done"].tap()

        reveal(album, in: app)
        album.tap()
        XCTAssertTrue(app.navigationBars["Semantic Album"].waitForExistence(timeout: 3))
        app.buttons["Done"].tap()

        for _ in 0..<6 where !play.isHittable {
            app.swipeDown()
        }
        XCTAssertTrue(play.isHittable)
        play.tap()
        XCTAssertTrue(app.staticTexts["Now Playing"].waitForExistence(timeout: 5))
    }

    func testEmptyLibraryImportActionOpensImporter() throws {
        let app = launchPreviewApp()
        let libraryTab = tabButton("Library", in: app)
        XCTAssertTrue(libraryTab.waitForExistence(timeout: 10))
        libraryTab.tap()

        let importMusic = app.buttons["Import Music"]
        XCTAssertTrue(importMusic.waitForExistence(timeout: 5))
        importMusic.tap()
        XCTAssertTrue(app.navigationBars["Import Music"].waitForExistence(timeout: 3))
    }

    func testNowPlayingArtworkExposesTrackInformationAction() throws {
        let app = launchPreviewApp()
        let openNowPlaying = app.buttons["Open Now Playing"]
        XCTAssertTrue(openNowPlaying.waitForExistence(timeout: 10))
        openNowPlaying.tap()

        let trackInformation = app.buttons["Track information for Impulse Response"]
        XCTAssertTrue(trackInformation.waitForExistence(timeout: 5))
        trackInformation.tap()
        XCTAssertTrue(app.navigationBars["Track Details"].waitForExistence(timeout: 3))
    }
}
