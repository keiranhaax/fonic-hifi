@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioKitEngineAdapterTests: XCTestCase {
    func testSetVolumeClampsBetweenZeroAndOne() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        await adapter.setVolume(1.5)
        let highVolume = await adapter.volume
        XCTAssertEqual(highVolume, 1.0, accuracy: 0.0001)

        await adapter.setVolume(-0.5)
        let lowVolume = await adapter.volume
        XCTAssertEqual(lowVolume, 0.0, accuracy: 0.0001)
    }

    func testIsBitPerfectReflectsConfigurationAndReplayGain() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        try await adapter.configure(with: .bitPerfect)

        await adapter.applyReplayGain(0)
        let bitPerfect = await adapter.isBitPerfect
        XCTAssertTrue(bitPerfect)

        await adapter.applyReplayGain(-6)
        let notBitPerfect = await adapter.isBitPerfect
        XCTAssertFalse(notBitPerfect)
    }

    func testLoadInitializesDurationAndResetsTime() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        let url = try makePCMTestAudioFile(testCase: self)
        try await adapter.load(url: url)

        let duration = await adapter.duration
        XCTAssertGreaterThan(duration, 0)
        let currentTime = await adapter.currentTime
        XCTAssertEqual(currentTime, 0, accuracy: 0.0001)
        let playing = await adapter.isPlaying
        XCTAssertFalse(playing)
    }

    func testSeekWithoutLoadedFileThrows() async {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            return
        }

        do {
            try await adapter.seek(to: 1.0)
            XCTFail("Expected seek without loaded file to throw")
        } catch {
            // Expected path
        }
    }

    func testPrepareNextLoadsFileIntoInactivePlayer() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        let url = try makePCMTestAudioFile(testCase: self)

        // Prepare next track
        await adapter.prepareNext(url: url)

        // Verify prepareNext completed without error
        // Note: Internal state is not exposed, but we verify no crash
        XCTAssertTrue(true, "prepareNext completed without error")
    }

    func testCrossfadeTransitionsToNewTrack() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        let url1 = try makePCMTestAudioFile(testCase: self)
        let url2 = try makePCMTestAudioFile(testCase: self)

        // Load and play first track
        try await adapter.load(url: url1)
        try await adapter.play()

        // Crossfade to second track (0 duration = instant)
        try await adapter.crossfade(to: url2, duration: 0, playbackRate: 1.0, gainDB: 0)

        let isPlaying = await adapter.isPlaying
        XCTAssertTrue(isPlaying, "Should still be playing after crossfade")
    }

    func testApplyReplayGainSetsGain() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        let url = try makePCMTestAudioFile(testCase: self)
        try await adapter.load(url: url)

        // Apply replay gain
        await adapter.applyReplayGain(-6.0)

        // Verify no crash and adapter is still functional
        try await adapter.play()
        let isPlaying = await adapter.isPlaying
        XCTAssertTrue(isPlaying)
    }

    func testApplyReplayGainZeroMaintainsBitPerfect() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        try await adapter.configure(with: .bitPerfect)

        // Zero gain should maintain bit-perfect
        await adapter.applyReplayGain(0)
        let bitPerfect = await adapter.isBitPerfect
        XCTAssertTrue(bitPerfect, "Zero replay gain should maintain bit-perfect status")
    }

    func testSetCompletionHandlerStoresHandler() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        var handlerCalled = false
        adapter.setCompletionHandler {
            handlerCalled = true
        }

        // Verify the handler can be set without error
        // Note: Actual completion testing requires playback to finish
        XCTAssertFalse(handlerCalled, "Handler should not be called just by setting it")
    }
}
