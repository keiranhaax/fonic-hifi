//
//  AudioSettingsServiceTests.swift
//  Fonic HiFiTests
//
//  Created by Claude on 12/6/25.
//

import XCTest
@testable import Fonic_HiFi

@MainActor
final class AudioSettingsServiceTests: XCTestCase {

    func test_syncGaplessEnabled_updatesStore() async throws {
        // Given
        let store = AudioPlaybackSettingsStore()
        let service = AudioSettingsService(settingsStore: store)

        // When
        await service.syncGaplessEnabled(true)

        // Then
        let isEnabled = await store.isGaplessEnabled()
        XCTAssertTrue(isEnabled)
    }

    func test_syncGaplessEnabled_false_updatesStore() async throws {
        // Given
        let store = AudioPlaybackSettingsStore()
        let service = AudioSettingsService(settingsStore: store)

        // When
        await service.syncGaplessEnabled(false)

        // Then
        let isEnabled = await store.isGaplessEnabled()
        XCTAssertFalse(isEnabled)
    }

    func test_syncCrossfadeDuration_updatesStore() async throws {
        // Given
        let store = AudioPlaybackSettingsStore()
        let service = AudioSettingsService(settingsStore: store)

        // When
        await service.syncCrossfadeDuration(5.0)

        // Then
        let duration = await store.crossfadeDuration()
        XCTAssertEqual(duration, 5.0)
    }

    func test_syncReplayGainMode_updatesStore() async throws {
        // Given
        let store = AudioPlaybackSettingsStore()
        let service = AudioSettingsService(settingsStore: store)

        // When
        await service.syncReplayGainMode(.album)

        // Then
        let mode = await store.replayGainMode()
        XCTAssertEqual(mode, .album)
    }

    func test_syncPlaybackRate_updatesStore() async throws {
        // Given
        let store = AudioPlaybackSettingsStore()
        let service = AudioSettingsService(settingsStore: store)

        // When
        await service.syncPlaybackRate(1.5)

        // Then
        let rate = await store.playbackRate()
        XCTAssertEqual(rate, 1.5)
    }
}
