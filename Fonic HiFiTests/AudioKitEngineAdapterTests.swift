@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioKitEngineAdapterTests: XCTestCase {
    func testSupportsEqualizerReportsUnavailable() async {
        let adapter = AudioKitEngineAdapter()

        let supportsEqualizer = await adapter.supportsEQ

        XCTAssertFalse(
            supportsEqualizer,
            "AudioKit must report EQ as unsupported until its engine graph implements the DSP path"
        )
    }

    func testSetVolumeClampsBetweenZeroAndOne() async {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        await adapter.setVolume(1.5)
        let highVolume = await adapter.volume
        XCTAssertEqual(highVolume, 1.0, accuracy: 0.0001)

        await adapter.setVolume(-0.5)
        let lowVolume = await adapter.volume
        XCTAssertEqual(lowVolume, 0.0, accuracy: 0.0001)
    }

    func testIsBitPerfectRequiresLoadedTrackAndUnityGain() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        try await adapter.configure(with: .bitPerfect)

        let noTrackLoaded = await adapter.isBitPerfect
        XCTAssertFalse(noTrackLoaded, "Eligibility requires a loaded track, not just a quality-mode preference")

        guard let outputSampleRate = await adapter.playbackFormatEvidence()?.engineOutputSampleRate else {
            throw XCTSkip("Engine output format unavailable in this test environment")
        }
        let url = try makePCMTestAudioFile(sampleRate: outputSampleRate, testCase: self)
        try await adapter.load(url: url)

        await adapter.applyReplayGain(0)
        let bitPerfect = await adapter.isBitPerfect
        XCTAssertTrue(bitPerfect)

        await adapter.applyReplayGain(-6)
        let notBitPerfect = await adapter.isBitPerfect
        XCTAssertFalse(notBitPerfect)
    }

    func testPlaybackFormatEvidenceReportsLoadedFormat() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        let preLoad = await adapter.playbackFormatEvidence()
        XCTAssertEqual(preLoad?.isTrackLoaded, false)
        XCTAssertNil(preLoad?.loadedSampleRate)

        let url = try makePCMTestAudioFile(sampleRate: 44_100, testCase: self)
        try await adapter.load(url: url)

        let evidence = await adapter.playbackFormatEvidence()
        XCTAssertEqual(evidence?.isTrackLoaded, true)
        XCTAssertEqual(evidence?.loadedSampleRate ?? 0, 44_100, accuracy: 0.1)
        XCTAssertEqual(evidence?.hasEngineProcessing, false)

        await adapter.applyReplayGain(-3)
        let processingEvidence = await adapter.playbackFormatEvidence()
        XCTAssertEqual(processingEvidence?.hasEngineProcessing, true)
    }

    func testLoadInitializesDurationAndResetsTime() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
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
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        do {
            try await adapter.seek(to: 1.0)
            XCTFail("Expected seek without loaded file to throw")
        } catch let AudioError.playbackFailed(reason) {
            XCTAssertEqual(reason, "No file loaded")
        } catch {
            XCTFail("Expected AudioError.playbackFailed, received \(error)")
        }
    }

    func testPrepareNextLoadsFileIntoInactivePlayer() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        let url = try makePCMTestAudioFile(testCase: self)

        await adapter.prepareNext(url: url)

        let transition = await adapter.consumePreparedTransition(to: url)
        let isPlaying = await adapter.isPlaying
        let duration = await adapter.duration
        let secondTransition = await adapter.consumePreparedTransition(to: url)
        XCTAssertEqual(transition, .preloadedFallback)
        XCTAssertTrue(isPlaying)
        XCTAssertGreaterThan(duration, 0)
        XCTAssertEqual(secondTransition, .none)
    }

    func testInvalidatePreparedTransitionStopsInactiveAndClearsPendingURL() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized)
        guard adapter.isInitialized else { return }

        let sourceURL = try makePCMTestAudioFile(testCase: self)
        let targetURL = try makePCMTestAudioFile(testCase: self)
        try await adapter.load(url: sourceURL)
        try await adapter.play()
        await adapter.prepareNext(url: targetURL)
        await adapter.invalidatePreparedTransition()

        let transition = await adapter.consumePreparedTransition(to: targetURL)
        XCTAssertEqual(transition, .none)
        XCTAssertEqual(adapter.activePlayerCountForTesting, 1)
        XCTAssertEqual(adapter.currentFileURLForTesting, sourceURL)
    }

    func testCrossfadeTransitionsToNewTrack() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
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
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
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
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        try await adapter.configure(with: .bitPerfect)

        guard let outputSampleRate = await adapter.playbackFormatEvidence()?.engineOutputSampleRate else {
            throw XCTSkip("Engine output format unavailable in this test environment")
        }
        let url = try makePCMTestAudioFile(sampleRate: outputSampleRate, testCase: self)
        try await adapter.load(url: url)

        // Zero gain should maintain bit-perfect
        await adapter.applyReplayGain(0)
        let bitPerfect = await adapter.isBitPerfect
        XCTAssertTrue(bitPerfect, "Zero replay gain should maintain bit-perfect status")
    }

    func testNaturalFinishDeliversCompletionExactlyOnce() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        let firstCompletion = expectation(description: "Natural playback completes")
        let duplicateCompletion = expectation(description: "Natural playback does not complete twice")
        duplicateCompletion.isInverted = true
        var completionCount = 0
        adapter.setCompletionHandler {
            completionCount += 1
            if completionCount == 1 {
                firstCompletion.fulfill()
            } else {
                duplicateCompletion.fulfill()
            }
        }

        let url = try makePCMTestAudioFile(duration: 0.05, testCase: self)
        try await adapter.load(url: url)
        try await adapter.play()

        await fulfillment(of: [firstCompletion], timeout: 1)
        await fulfillment(of: [duplicateCompletion], timeout: 0.1)
        XCTAssertEqual(completionCount, 1)
    }

    func testSeekNearEndDeliversCompletionExactlyOnce() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        let firstCompletion = expectation(description: "Seeked playback completes")
        let duplicateCompletion = expectation(description: "Seeked playback does not complete twice")
        duplicateCompletion.isInverted = true
        var completionCount = 0
        adapter.setCompletionHandler {
            completionCount += 1
            if completionCount == 1 {
                firstCompletion.fulfill()
            } else {
                duplicateCompletion.fulfill()
            }
        }

        let url = try makePCMTestAudioFile(duration: 0.2, testCase: self)
        try await adapter.load(url: url)
        try await adapter.play()
        try await adapter.seek(to: 0.18)

        await fulfillment(of: [firstCompletion], timeout: 1)
        await fulfillment(of: [duplicateCompletion], timeout: 0.1)
        XCTAssertEqual(completionCount, 1)
    }

    func testStopDoesNotDeliverCompletion() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        let completion = expectation(description: "Stopped playback does not complete")
        completion.isInverted = true
        adapter.setCompletionHandler {
            completion.fulfill()
        }

        let url = try makePCMTestAudioFile(duration: 0.1, testCase: self)
        try await adapter.load(url: url)
        try await adapter.play()
        await adapter.stop()

        await fulfillment(of: [completion], timeout: 0.2)
    }

    func testPauseCancelsPendingCompletion() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        let completion = expectation(description: "Paused playback does not complete")
        completion.isInverted = true
        adapter.setCompletionHandler {
            completion.fulfill()
        }

        let url = try makePCMTestAudioFile(duration: 0.1, testCase: self)
        try await adapter.load(url: url)
        try await adapter.play()
        await adapter.pause()

        await fulfillment(of: [completion], timeout: 0.2)
    }

    func testTrackTransitionIgnoresSupersededCompletion() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        let firstCompletion = expectation(description: "Replacement track completes")
        let duplicateCompletion = expectation(description: "Superseded track does not complete")
        duplicateCompletion.isInverted = true
        var completionCount = 0
        adapter.setCompletionHandler {
            completionCount += 1
            if completionCount == 1 {
                firstCompletion.fulfill()
            } else {
                duplicateCompletion.fulfill()
            }
        }

        let firstURL = try makePCMTestAudioFile(duration: 0.05, testCase: self)
        let replacementURL = try makePCMTestAudioFile(duration: 0.1, testCase: self)
        try await adapter.load(url: firstURL)
        try await adapter.play()
        try await adapter.load(url: replacementURL)
        try await adapter.play()

        await fulfillment(of: [firstCompletion], timeout: 1)
        await fulfillment(of: [duplicateCompletion], timeout: 0.1)
        XCTAssertEqual(completionCount, 1)
    }

    func testImmediateCrossfadeCompletesOnlyForReplacementTrack() async throws {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(adapter.isInitialized, "AudioKit engine should initialize in the standard test environment")
        guard adapter.isInitialized else {
            return
        }

        let firstCompletion = expectation(description: "Crossfaded track completes")
        let duplicateCompletion = expectation(description: "Outgoing track does not complete")
        duplicateCompletion.isInverted = true
        var completionCount = 0
        adapter.setCompletionHandler {
            completionCount += 1
            if completionCount == 1 {
                firstCompletion.fulfill()
            } else {
                duplicateCompletion.fulfill()
            }
        }

        let firstURL = try makePCMTestAudioFile(duration: 0.05, testCase: self)
        let replacementURL = try makePCMTestAudioFile(duration: 0.1, testCase: self)
        try await adapter.load(url: firstURL)
        try await adapter.play()
        try await adapter.crossfade(
            to: replacementURL,
            duration: 0,
            playbackRate: 1,
            gainDB: 0
        )

        await fulfillment(of: [firstCompletion], timeout: 1)
        await fulfillment(of: [duplicateCompletion], timeout: 0.1)
        XCTAssertEqual(completionCount, 1)
    }

    func testCrossfadeCancelledAtStartByPauseReconcilesToPausedSource() async throws {
        let clock = ControlledTestClock()
        let adapter = try makeCrossfadeHarness(clock: clock)
        let sourceURL = try makePCMTestAudioFile(duration: 1, testCase: self)
        let targetURL = try makePCMTestAudioFile(duration: 1, testCase: self)
        try await adapter.load(url: sourceURL)
        try await adapter.play()

        try await adapter.crossfade(
            to: targetURL,
            duration: 0.4,
            playbackRate: 1,
            gainDB: 0
        )
        try await clock.waitUntilSleeperCount()
        await adapter.pause()

        XCTAssertEqual(adapter.activePlayerCountForTesting, 0)
        XCTAssertEqual(adapter.currentFileURLForTesting, sourceURL)
        XCTAssertEqual(adapter.playerVolumesForTesting.active, 1, accuracy: 0.001)
        XCTAssertEqual(adapter.playerVolumesForTesting.inactive, 0, accuracy: 0.001)
        let isPlaying = await adapter.isPlaying
        XCTAssertFalse(isPlaying)
    }

    func testCrossfadeCancelledMidFadeBySeekReconcilesToPlayingSource() async throws {
        let clock = ControlledTestClock()
        let adapter = try makeCrossfadeHarness(clock: clock)
        let sourceURL = try makePCMTestAudioFile(duration: 1, testCase: self)
        let targetURL = try makePCMTestAudioFile(duration: 1, testCase: self)
        try await adapter.load(url: sourceURL)
        try await adapter.play()

        try await adapter.crossfade(
            to: targetURL,
            duration: 0.4,
            playbackRate: 1,
            gainDB: 0
        )
        try await clock.waitUntilSleeperCount()
        clock.advance(by: .milliseconds(20))
        try await clock.waitUntilSleeperCount()
        try await adapter.seek(to: 0.25)

        XCTAssertEqual(adapter.activePlayerCountForTesting, 1)
        XCTAssertEqual(adapter.currentFileURLForTesting, sourceURL)
        XCTAssertEqual(adapter.playerVolumesForTesting.active, 1, accuracy: 0.001)
        XCTAssertEqual(adapter.playerVolumesForTesting.inactive, 0, accuracy: 0.001)
        let isPlaying = await adapter.isPlaying
        XCTAssertTrue(isPlaying)
    }

    func testCrossfadeCancelledByReplacementLeavesOnlyReplacementPlaying() async throws {
        let clock = ControlledTestClock()
        let adapter = try makeCrossfadeHarness(clock: clock)
        let sourceURL = try makePCMTestAudioFile(duration: 1, testCase: self)
        let abandonedURL = try makePCMTestAudioFile(duration: 1, testCase: self)
        let replacementURL = try makePCMTestAudioFile(duration: 1, testCase: self)
        try await adapter.load(url: sourceURL)
        try await adapter.play()

        try await adapter.crossfade(
            to: abandonedURL,
            duration: 0.4,
            playbackRate: 1,
            gainDB: 0
        )
        try await clock.waitUntilSleeperCount()
        try await adapter.load(url: replacementURL)
        try await adapter.play()

        XCTAssertEqual(adapter.activePlayerCountForTesting, 1)
        XCTAssertEqual(adapter.currentFileURLForTesting, replacementURL)
        XCTAssertEqual(adapter.playerVolumesForTesting.active, 1, accuracy: 0.001)
        XCTAssertEqual(adapter.playerVolumesForTesting.inactive, 0, accuracy: 0.001)
        let isPlaying = await adapter.isPlaying
        XCTAssertTrue(isPlaying)
    }

    func testCompletedCrossfadeLeavesOnlyTargetPlaying() async throws {
        let clock = ControlledTestClock()
        let adapter = try makeCrossfadeHarness(clock: clock)
        let sourceURL = try makePCMTestAudioFile(duration: 1, testCase: self)
        let targetURL = try makePCMTestAudioFile(duration: 1, testCase: self)
        try await adapter.load(url: sourceURL)
        try await adapter.play()

        try await adapter.crossfade(
            to: targetURL,
            duration: 0.04,
            playbackRate: 1,
            gainDB: 0
        )
        try await clock.waitUntilSleeperCount()
        clock.advance(by: .milliseconds(20))
        try await clock.waitUntilSleeperCount()
        clock.advance(by: .milliseconds(20))
        await Task.yield()

        XCTAssertEqual(adapter.activePlayerCountForTesting, 1)
        XCTAssertEqual(adapter.currentFileURLForTesting, targetURL)
        XCTAssertEqual(adapter.playerVolumesForTesting.active, 1, accuracy: 0.001)
        XCTAssertEqual(adapter.playerVolumesForTesting.inactive, 0, accuracy: 0.001)
        let isPlaying = await adapter.isPlaying
        XCTAssertTrue(isPlaying)
    }

    private func makeCrossfadeHarness(
        clock: ControlledTestClock
    ) throws -> AudioKitEngineAdapter {
        let adapter = AudioKitEngineAdapter()
        XCTAssertTrue(
            adapter.isInitialized,
            "AudioKit engine should initialize in the standard test environment"
        )
        guard adapter.isInitialized else {
            throw AudioError.engineInitializationFailed(
                reason: "AudioKit unavailable in the standard test environment"
            )
        }
        adapter.setCrossfadeSleeperForTesting { duration in
            try await clock.sleep(for: duration)
        }
        return adapter
    }
}
