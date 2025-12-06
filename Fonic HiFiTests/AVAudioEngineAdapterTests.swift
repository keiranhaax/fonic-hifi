@testable import Fonic_HiFi
import XCTest

@MainActor
final class AVAudioEngineAdapterTests: XCTestCase {
    func testLoadPopulatesDuration() async throws {
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = AVAudioEngineAdapter()

        try await adapter.load(url: url)

        let duration = await adapter.duration
        XCTAssertGreaterThan(duration, 0)
        let format = await adapter.audioFormat
        XCTAssertNotNil(format)
    }

    func testPlayAndStopUpdatePlaybackState() async throws {
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = AVAudioEngineAdapter()

        try await adapter.load(url: url)
        do {
            try await adapter.play()
        } catch {
            throw XCTSkip("Audio engine unavailable: \(error)")
        }

        let playing = await adapter.isPlaying
        XCTAssertTrue(playing)

        await adapter.stop()

        let stopped = await adapter.isPlaying
        XCTAssertFalse(stopped)
        let currentTime = await adapter.currentTime
        XCTAssertEqual(currentTime, 0, accuracy: 0.01)
    }

    func testSeekWithoutLoadedFileThrows() async {
        let adapter = AVAudioEngineAdapter()

        do {
            try await adapter.seek(to: 1.0)
            XCTFail("Expected seek(to:) to throw when no file loaded")
        } catch {
            // Expected path
        }
    }

    func testSeekRejectsInvalidPosition() async throws {
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = AVAudioEngineAdapter()

        try await adapter.load(url: url)

        do {
            try await adapter.seek(to: -1.0)
            XCTFail("Expected negative seek to throw")
        } catch {
            // Expected
        }

        let duration = await adapter.duration
        do {
            try await adapter.seek(to: duration + 5.0)
            XCTFail("Expected seek beyond duration to throw")
        } catch {
            // Expected
        }
    }

    func testSetVolumeClampsBetweenZeroAndOne() async throws {
        let adapter = AVAudioEngineAdapter()

        await adapter.setVolume(1.5)
        let highVolume = await adapter.volume
        XCTAssertEqual(highVolume, 1.0, accuracy: 0.0001)

        await adapter.setVolume(-0.5)
        let lowVolume = await adapter.volume
        XCTAssertEqual(lowVolume, 0.0, accuracy: 0.0001)
    }

    func testGetMetricsReturnsNonNegativeValues() async {
        let adapter = AVAudioEngineAdapter()

        let metrics = await adapter.getMetrics()
        XCTAssertGreaterThanOrEqual(metrics.cpuUsage, 0)
        XCTAssertGreaterThanOrEqual(metrics.memoryUsage, 0)
        XCTAssertGreaterThanOrEqual(metrics.bufferUnderruns, 0)
        XCTAssertNotNil(metrics.timestamp)
    }

    func testSetPlaybackRate_changesRate() async throws {
        // Given
        let adapter = AVAudioEngineAdapter()

        // When
        await adapter.setPlaybackRate(1.5)

        // Then
        let rate = await adapter.currentPlaybackRate
        XCTAssertEqual(rate, 1.5, accuracy: 0.01)
    }

    func testSetPlaybackRate_clampsBetween0_5And2_0() async throws {
        // Given
        let adapter = AVAudioEngineAdapter()

        // When - too high
        await adapter.setPlaybackRate(3.0)
        let highRate = await adapter.currentPlaybackRate
        XCTAssertEqual(highRate, 2.0, accuracy: 0.01)

        // When - too low
        await adapter.setPlaybackRate(0.25)
        let lowRate = await adapter.currentPlaybackRate
        XCTAssertEqual(lowRate, 0.5, accuracy: 0.01)
    }

    func testPrepareNext_setsHasNextPrepared() async throws {
        // Given
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = AVAudioEngineAdapter()
        try await adapter.load(url: url)

        // When
        await adapter.prepareNext(url: url)

        // Then
        XCTAssertTrue(adapter.hasNextPrepared)
    }

    func testPrepareNext_withoutLoad_stillPrepares() async throws {
        // Given
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = AVAudioEngineAdapter()

        // When - prepareNext without loading a current track first
        await adapter.prepareNext(url: url)

        // Then - should still prepare (engine starts on demand)
        XCTAssertTrue(adapter.hasNextPrepared)
    }

    // MARK: - EQ Tests

    func testApplyEQ_updatesEQState() async throws {
        // Given
        let adapter = AVAudioEngineAdapter()
        var config = EqualizerConfiguration.default
        config.bands[0] = EQBand(frequency: 32, gain: 6.0) // Boost 32Hz
        config.isEnabled = true

        // When
        await adapter.applyEQ(config)

        // Then
        let isEnabled = await adapter.isEQEnabled
        XCTAssertTrue(isEnabled)
    }

    func testApplyEQ_disabledByDefault() async throws {
        // Given
        let adapter = AVAudioEngineAdapter()

        // Then
        let isEnabled = await adapter.isEQEnabled
        XCTAssertFalse(isEnabled)
    }
}
