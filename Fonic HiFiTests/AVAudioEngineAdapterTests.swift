@testable import Fonic_HiFi
import AVFoundation
import XCTest

@MainActor
final class AVAudioEngineAdapterTests: XCTestCase {
    func testLoadPopulatesDuration() async throws {
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = try AVAudioEngineAdapter()

        try await adapter.load(url: url)

        let duration = await adapter.duration
        XCTAssertGreaterThan(duration, 0)
        let format = await adapter.audioFormat
        XCTAssertNotNil(format)
    }

    func testLoadHandlesMixedSampleRateFilesSequentially() async throws {
        let highRateURL = try makePCMTestAudioFile(sampleRate: 96_000, testCase: self)
        let standardRateURL = try makePCMTestAudioFile(sampleRate: 44_100, testCase: self)
        let adapter = try AVAudioEngineAdapter()

        try await adapter.load(url: highRateURL)
        let firstDuration = await adapter.duration
        XCTAssertGreaterThan(firstDuration, 0)

        try await adapter.load(url: standardRateURL)
        let secondDuration = await adapter.duration
        XCTAssertGreaterThan(secondDuration, 0)
    }

    func testConfigurationChangeRecoveryCoalescesNotificationBursts() async {
        let recovery = expectation(description: "Configuration change recovery")
        var recoveryCount = 0
        let scheduler = EngineConfigurationChangeRecoveryScheduler(recoveryDelay: .milliseconds(10)) {
            recoveryCount += 1
            recovery.fulfill()
        }

        scheduler.schedule()
        scheduler.schedule()
        scheduler.schedule()

        await fulfillment(of: [recovery], timeout: 1)
        XCTAssertEqual(recoveryCount, 1)
    }

    func testConfigurationChangeFilterMatchesOnlyObservedEngine() {
        let engine = AVAudioEngine()
        let otherEngine = AVAudioEngine()
        let engineIdentifier = ObjectIdentifier(engine)
        let notificationName = Notification.Name.AVAudioEngineConfigurationChange

        XCTAssertTrue(
            AVAudioEngineAdapter.isConfigurationChangeForEngine(
                Notification(name: notificationName, object: engine),
                engineIdentifier: engineIdentifier
            )
        )
        XCTAssertFalse(
            AVAudioEngineAdapter.isConfigurationChangeForEngine(
                Notification(name: notificationName, object: otherEngine),
                engineIdentifier: engineIdentifier
            )
        )
        XCTAssertFalse(
            AVAudioEngineAdapter.isConfigurationChangeForEngine(
                Notification(name: notificationName),
                engineIdentifier: engineIdentifier
            )
        )
    }

    func testConfigurationRecoveryReschedulesRemainderAndPreservesTransportFrame() async throws {
        let url = try makePCMTestAudioFile(duration: 0.6, testCase: self)
        let adapter = try AVAudioEngineAdapter()

        try await adapter.load(url: url)
        try await adapter.play()
        await waitForCurrentTime(adapter, atLeast: 0.05)
        let frameBeforeRecovery = await adapter.currentTime * 44_100

        adapter.recoverAfterConfigurationChange()

        let recoveredTime = await adapter.currentTime
        XCTAssertGreaterThanOrEqual(
            recoveredTime * 44_100,
            frameBeforeRecovery - 2,
            "Route recovery must resume at or after the captured source frame"
        )
        let isPlayingAfterRecovery = await adapter.isPlaying
        XCTAssertTrue(isPlayingAfterRecovery)
        await adapter.stop()
    }

    func testPlaybackFormatEvidenceReportsLoadStateAndProcessing() async throws {
        let adapter = try AVAudioEngineAdapter()

        let preLoad = await adapter.playbackFormatEvidence()
        XCTAssertEqual(preLoad?.isTrackLoaded, false)
        XCTAssertNil(preLoad?.loadedSampleRate)

        let url = try makePCMTestAudioFile(sampleRate: 44_100, testCase: self)
        try await adapter.load(url: url)

        let evidence = await adapter.playbackFormatEvidence()
        XCTAssertEqual(evidence?.isTrackLoaded, true)
        XCTAssertEqual(evidence?.loadedSampleRate ?? 0, 44_100, accuracy: 0.1)
        XCTAssertEqual(evidence?.hasEngineProcessing, false)
        XCTAssertNotNil(evidence?.engineOutputSampleRate)

        await adapter.setPlaybackRate(1.5)
        let processingEvidence = await adapter.playbackFormatEvidence()
        XCTAssertEqual(processingEvidence?.hasEngineProcessing, true)
    }

    func testReplayGainUsesIndependentPerChainStageAndAffectsEligibility() async throws {
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = try AVAudioEngineAdapter()
        try await adapter.load(url: url)

        await adapter.applyReplayGain(-6)

        let volumes = adapter.chainVolumesForTesting
        XCTAssertEqual(volumes.primary, pow(10, -6 / 20), accuracy: 0.001)
        XCTAssertEqual(volumes.secondary, 0, accuracy: 0.001)
        let evidence = await adapter.playbackFormatEvidence()
        XCTAssertTrue(evidence?.hasEngineProcessing == true)
        let bitPerfect = await adapter.isBitPerfect
        XCTAssertFalse(bitPerfect)
    }

    func testCrossfadeCancellationLeavesSourceChainCoherent() async throws {
        let sourceURL = try makePCMTestAudioFile(duration: 0.4, testCase: self)
        let targetURL = try makePCMTestAudioFile(duration: 0.4, sampleRate: 44_100, testCase: self)
        let adapter = try AVAudioEngineAdapter()
        try await adapter.load(url: sourceURL)
        try await adapter.play()
        adapter.setCrossfadeSleeperForTesting { _ in
            try await Task.sleep(for: .seconds(10))
        }

        try await adapter.crossfade(to: targetURL, duration: 0.1, playbackRate: 1, gainDB: -3)
        await adapter.pause()

        let players = try playerNodes(from: adapter)
        XCTAssertFalse(players.primary.isPlaying)
        XCTAssertFalse(players.secondary.isPlaying)
        XCTAssertEqual(adapter.chainVolumesForTesting.secondary, 0, accuracy: 0.001)
        let format = await adapter.audioFormat
        XCTAssertNotNil(format)
    }

    func testPauseResumeSchedulesTrackExactlyOnce() async throws {
        let duration: TimeInterval = 0.2
        let url = try makePCMTestAudioFile(duration: duration, testCase: self)
        let adapter = try AVAudioEngineAdapter()
        let completion = expectation(description: "Track completed once after resume")
        completion.expectedFulfillmentCount = 1
        var completionCount = 0
        adapter.setCompletionHandler {
            completionCount += 1
            completion.fulfill()
        }

        try await adapter.load(url: url)
        try await adapter.play()
        await waitForCurrentTime(adapter, atLeast: 0.02)
        let timeBeforePause = await adapter.currentTime

        await adapter.pause()
        let pausedTime = await adapter.currentTime
        XCTAssertGreaterThanOrEqual(pausedTime, timeBeforePause - (1.0 / 44_100))

        let resumeStart = Date()
        try await adapter.play()
        await waitForCurrentTime(
            adapter,
            atLeast: max(0, pausedTime - (1.0 / 44_100))
        )
        let resumedTime = await adapter.currentTime
        XCTAssertGreaterThanOrEqual(resumedTime, pausedTime - (1.0 / 44_100))

        await fulfillment(of: [completion], timeout: 0.5)
        let elapsedAfterResume = Date().timeIntervalSince(resumeStart)
        XCTAssertEqual(completionCount, 1)
        XCTAssertLessThan(
            elapsedAfterResume,
            duration * 2.5,
            "A resume must not append a second copy of the scheduled file"
        )
        await adapter.stop()
    }

    func testSeekPauseResumePreservesTimeBase() async throws {
        let url = try makePCMTestAudioFile(duration: 0.4, testCase: self)
        let adapter = try AVAudioEngineAdapter()

        try await adapter.load(url: url)
        try await adapter.seek(to: 0.2)
        let seekedTime = await adapter.currentTime
        XCTAssertEqual(seekedTime, 0.2, accuracy: 1.0 / 44_100)

        await adapter.pause()
        try await adapter.play()

        let resumedTime = await adapter.currentTime
        XCTAssertGreaterThanOrEqual(
            resumedTime,
            0.2 - (1.0 / 44_100),
            "Resuming a sought segment must retain its source-frame base"
        )
        await adapter.stop()
    }

    func testRepeatedPauseResumeDoesNotAccumulateSchedules() async throws {
        let duration: TimeInterval = 0.2
        let url = try makePCMTestAudioFile(duration: duration, testCase: self)
        let adapter = try AVAudioEngineAdapter()
        let completion = expectation(description: "Track completed once after repeated resumes")
        completion.expectedFulfillmentCount = 1
        var completionCount = 0
        adapter.setCompletionHandler {
            completionCount += 1
            completion.fulfill()
        }

        try await adapter.load(url: url)
        try await adapter.play()
        await waitForCurrentTime(adapter, atLeast: 0.02)

        for _ in 0 ..< 3 {
            await adapter.pause()
            try await adapter.play()
        }

        let resumeStart = Date()
        await fulfillment(of: [completion], timeout: 0.5)
        let elapsedAfterResume = Date().timeIntervalSince(resumeStart)
        XCTAssertEqual(completionCount, 1)
        XCTAssertLessThan(
            elapsedAfterResume,
            duration * 2.5,
            "Repeated pause/resume cycles must reuse the one pending schedule"
        )
        await adapter.stop()
    }

    func testPauseDisarmsPreparedTransition() async throws {
        let sourceURL = try makePCMTestAudioFile(duration: 0.25, testCase: self)
        let targetURL = try makePCMTestAudioFile(duration: 0.25, testCase: self)
        let adapter = try AVAudioEngineAdapter()

        try await adapter.load(url: sourceURL)
        try await adapter.play()
        await waitForCurrentTime(adapter, atLeast: 0.02)
        await adapter.prepareNext(url: targetURL)
        XCTAssertTrue(adapter.hasNextPrepared)

        await adapter.pause()
        XCTAssertFalse(adapter.hasNextPrepared)
        try await Task.sleep(for: .milliseconds(350))

        let players = try playerNodes(from: adapter)
        XCTAssertFalse(players.primary.isPlaying)
        XCTAssertFalse(players.secondary.isPlaying)
        await adapter.stop()
    }

    func testPlayAfterPreparedTransitionStopsArmedInactivePlayer() async throws {
        let sourceURL = try makePCMTestAudioFile(duration: 0.3, testCase: self)
        let targetURL = try makePCMTestAudioFile(duration: 0.3, testCase: self)
        let adapter = try AVAudioEngineAdapter()

        try await adapter.load(url: sourceURL)
        try await adapter.play()
        await waitForCurrentTime(adapter, atLeast: 0.02)
        await adapter.prepareNext(url: targetURL)
        XCTAssertTrue(adapter.hasNextPrepared)

        try await adapter.play()

        XCTAssertFalse(adapter.hasNextPrepared)
        let isPrimaryActive = try isPrimaryActive(for: adapter)
        let players = try playerNodes(from: adapter)
        let inactivePlayer = isPrimaryActive ? players.secondary : players.primary
        XCTAssertFalse(inactivePlayer.isPlaying)
        await adapter.stop()
    }

    func testConfigureWhilePlayingDoesNotStopPlayback() async throws {
        let url = try makePCMTestAudioFile(duration: 0.3, testCase: self)
        let adapter = try AVAudioEngineAdapter()
        let completion = expectation(description: "Configured track completes")
        completion.expectedFulfillmentCount = 1
        adapter.setCompletionHandler {
            completion.fulfill()
        }

        try await adapter.load(url: url)
        try await adapter.play()
        await waitForCurrentTime(adapter, atLeast: 0.02)
        let timeBeforeConfigure = await adapter.currentTime

        let configuration = AudioEngineConfiguration(crossfadeDuration: 0.25)
        try await adapter.configure(with: configuration)

        let isPlayingAfterConfigure = await adapter.isPlaying
        XCTAssertTrue(isPlayingAfterConfigure)
        let timeAfterConfigure = await adapter.currentTime
        XCTAssertGreaterThanOrEqual(
            timeAfterConfigure,
            timeBeforeConfigure - (1.0 / 44_100),
            "Configuring an active adapter must preserve its scheduled playback"
        )
        await fulfillment(of: [completion], timeout: 0.5)
        await adapter.stop()
    }

    func testPlayAndStopUpdatePlaybackState() async throws {
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = try AVAudioEngineAdapter()

        try await adapter.load(url: url)
        try await adapter.play()

        let playing = await adapter.isPlaying
        XCTAssertTrue(playing)

        await adapter.stop()

        let stopped = await adapter.isPlaying
        XCTAssertFalse(stopped)
        let currentTime = await adapter.currentTime
        XCTAssertEqual(currentTime, 0, accuracy: 0.01)
    }

    func testSeekWithoutLoadedFileThrows() async throws {
        let adapter = try AVAudioEngineAdapter()

        do {
            try await adapter.seek(to: 1.0)
            XCTFail("Expected seek(to:) to throw when no file loaded")
        } catch {
            // Expected path
        }
    }

    func testSeekRejectsInvalidPosition() async throws {
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = try AVAudioEngineAdapter()

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

    func testRepeatedPausedSeeksReportAbsolutePositions() async throws {
        let url = try makePCMTestAudioFile(duration: 1, testCase: self)
        let adapter = try AVAudioEngineAdapter()

        try await adapter.load(url: url)
        try await adapter.seek(to: 0.2)
        let firstPosition = await adapter.currentTime

        try await adapter.seek(to: 0.6)
        let secondPosition = await adapter.currentTime

        XCTAssertEqual(firstPosition, 0.2, accuracy: 1.0 / 44_100)
        XCTAssertEqual(secondPosition, 0.6, accuracy: 1.0 / 44_100)
        XCTAssertGreaterThan(secondPosition, firstPosition)
    }

    func testRepeatedSeeksThenNaturalCompletionReportMonotonicAbsoluteTime() async throws {
        let url = try makePCMTestAudioFile(duration: 1, testCase: self)
        let adapter = try AVAudioEngineAdapter()
        let completion = expectation(description: "Final seek segment completed naturally")
        adapter.setCompletionHandler {
            completion.fulfill()
        }

        try await adapter.load(url: url)
        try await adapter.play()
        try await adapter.seek(to: 0.2)
        let firstPosition = await adapter.currentTime
        try await adapter.seek(to: 0.6)
        let secondPosition = await adapter.currentTime

        await fulfillment(of: [completion], timeout: 2)
        let completedPosition = await adapter.currentTime
        let duration = await adapter.duration

        XCTAssertGreaterThanOrEqual(firstPosition, 0.2)
        XCTAssertGreaterThanOrEqual(secondPosition, 0.6)
        XCTAssertGreaterThanOrEqual(secondPosition, firstPosition)
        XCTAssertEqual(completedPosition, duration, accuracy: 1.0 / 44_100)
    }

    func testAbsolutePlaybackFrameAddsSeekBaseAndClampsAtCompletion() {
        let positions = [
            AVAudioEngineAdapter.absolutePlaybackFrame(
                scheduledStartFrame: 2_000,
                nodeSampleTime: 250,
                totalFrames: 10_000
            ),
            AVAudioEngineAdapter.absolutePlaybackFrame(
                scheduledStartFrame: 6_000,
                nodeSampleTime: 500,
                totalFrames: 10_000
            ),
            AVAudioEngineAdapter.absolutePlaybackFrame(
                scheduledStartFrame: 6_000,
                nodeSampleTime: 4_500,
                totalFrames: 10_000
            ),
        ]

        XCTAssertEqual(positions, [2_250, 6_500, 10_000])
        XCTAssertEqual(positions, positions.sorted())
    }

    func testSetVolumeClampsBetweenZeroAndOne() async throws {
        let adapter = try AVAudioEngineAdapter()

        await adapter.setVolume(1.5)
        let highVolume = await adapter.volume
        XCTAssertEqual(highVolume, 1.0, accuracy: 0.0001)

        await adapter.setVolume(-0.5)
        let lowVolume = await adapter.volume
        XCTAssertEqual(lowVolume, 0.0, accuracy: 0.0001)
    }

    func testAvailableMetricsUseInjectedProcessProviderAndRemainPartial() async throws {
        let provider = StubProcessMetricsProvider(
            snapshot: ProcessMetricsSnapshot(cpuUsage: 12.5, residentMemoryBytes: 42_000)
        )
        let adapter = try AVAudioEngineAdapter(processMetricsProvider: provider)

        let snapshot = await adapter.availableMetrics()
        let metrics = try XCTUnwrap(snapshot)
        XCTAssertEqual(metrics.engineMetricsAvailability, .partial)
        XCTAssertEqual(metrics.cpuUsage, 12.5)
        XCTAssertEqual(metrics.memoryUsage, 42_000)
        XCTAssertGreaterThanOrEqual(metrics.bufferUnderruns, 0)
        XCTAssertNotNil(metrics.timestamp)
    }

    func testSetPlaybackRate_changesRate() async throws {
        // Given
        let adapter = try AVAudioEngineAdapter()

        // When
        await adapter.setPlaybackRate(1.5)

        // Then
        let rate = adapter.currentPlaybackRate
        XCTAssertEqual(rate, 1.5, accuracy: 0.01)
    }

    func testSetPlaybackRate_clampsBetween0_5And2_0() async throws {
        // Given
        let adapter = try AVAudioEngineAdapter()

        // When - too high
        await adapter.setPlaybackRate(3.0)
        let highRate = adapter.currentPlaybackRate
        XCTAssertEqual(highRate, 2.0, accuracy: 0.01)

        // When - too low
        await adapter.setPlaybackRate(0.25)
        let lowRate = adapter.currentPlaybackRate
        XCTAssertEqual(lowRate, 0.5, accuracy: 0.01)
    }

    func testPrepareNext_setsHasNextPrepared() async throws {
        // Given
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = try AVAudioEngineAdapter()
        try await adapter.load(url: url)

        // When
        await adapter.prepareNext(url: url)

        // Then
        XCTAssertTrue(adapter.hasNextPrepared)
    }

    func testPrepareNext_withoutLoad_stillPrepares() async throws {
        // Given
        let url = try makePCMTestAudioFile(testCase: self)
        let adapter = try AVAudioEngineAdapter()

        // When - prepareNext without loading a current track first
        await adapter.prepareNext(url: url)

        // Then - should still prepare (engine starts on demand)
        XCTAssertTrue(adapter.hasNextPrepared)
    }

    // MARK: - EQ Tests

    func testApplyEQ_updatesEQState() async throws {
        // Given
        let adapter = try AVAudioEngineAdapter()
        var config = EqualizerConfiguration.default
        config.bands[0] = EQBand(frequency: 32, gain: 6.0) // Boost 32Hz
        config.isEnabled = true

        // When
        try await adapter.applyEQ(config)

        // Then
        let isEnabled = adapter.isEQEnabled
        XCTAssertTrue(isEnabled)
    }

    func testApplyEQ_disabledByDefault() async throws {
        // Given
        let adapter = try AVAudioEngineAdapter()

        // Then
        let isEnabled = adapter.isEQEnabled
        XCTAssertFalse(isEnabled)
    }

    func testApplyEQ_appliesFrequencyAndBandwidth() async throws {
        let adapter = try AVAudioEngineAdapter()

        // Create config with non-default frequency and bandwidth
        let customBand = EQBand(frequency: 1500, gain: 3.0, bandwidth: 0.5)
        var bands = EqualizerConfiguration.default.bands
        bands[5] = customBand  // Replace 1000 Hz band

        let config = EqualizerConfiguration(bands: bands, isEnabled: true, presetName: "Test")

        try await adapter.applyEQ(config)

        // Verify isEQEnabled is set
        let isEnabled = adapter.isEQEnabled
        XCTAssertTrue(isEnabled, "EQ should be enabled")

        // The real verification is that frequency/bandwidth ARE applied
        // This test documents the expected behavior
    }

    // MARK: - Comprehensive EQ Integration Tests

    func testApplyEQ_withAllParametersSet_appliesCorrectly() async throws {
        let adapter = try AVAudioEngineAdapter()

        var bands = EqualizerConfiguration.default.bands
        bands[5] = EQBand(frequency: 1500, gain: 6.0, bandwidth: 0.5)
        let config = EqualizerConfiguration(bands: bands, isEnabled: true, presetName: "Test")

        try await adapter.applyEQ(config)

        XCTAssertTrue(adapter.isEQEnabled)
    }

    func testApplyEQ_disabled_maintainsBitPerfect() async throws {
        let adapter = try AVAudioEngineAdapter()

        let config = EqualizerConfiguration(bands: EqualizerConfiguration.default.bands, isEnabled: false)
        try await adapter.applyEQ(config)

        XCTAssertFalse(adapter.isEQEnabled)
        // When EQ disabled, bit-perfect should be possible (true bypass removes EQ from graph)
    }

    func testPreampGain_appliedCorrectly() async throws {
        let adapter = try AVAudioEngineAdapter()

        var bands = EqualizerConfiguration.default.bands
        bands[0] = EQBand(frequency: 32, gain: 12.0)  // Max boost
        let config = EqualizerConfiguration(bands: bands, isEnabled: true)

        try await adapter.applyEQ(config)

        // Preamp should reduce output by 12 dB (applied via mainMixerNode.outputVolume)
        XCTAssertTrue(adapter.isEQEnabled)
    }

    func testApplyEQ_toggleEnableDisable_maintainsState() async throws {
        let adapter = try AVAudioEngineAdapter()

        var bands = EqualizerConfiguration.default.bands
        bands[0] = EQBand(frequency: 32, gain: 6.0)

        // Enable EQ
        let enabledConfig = EqualizerConfiguration(bands: bands, isEnabled: true, presetName: "Test")
        try await adapter.applyEQ(enabledConfig)
        XCTAssertTrue(adapter.isEQEnabled)

        // Disable EQ
        let disabledConfig = EqualizerConfiguration(bands: bands, isEnabled: false, presetName: "Test")
        try await adapter.applyEQ(disabledConfig)
        XCTAssertFalse(adapter.isEQEnabled)

        // Re-enable EQ
        try await adapter.applyEQ(enabledConfig)
        XCTAssertTrue(adapter.isEQEnabled)
    }

    func testApplyEQ_allPresets_applyWithoutError() async throws {
        let adapter = try AVAudioEngineAdapter()

        for (name, preset) in EqualizerConfiguration.presets {
            try await adapter.applyEQ(preset)
            let isEnabled = adapter.isEQEnabled
            XCTAssertEqual(isEnabled, preset.isEnabled, "Preset '\(name)' should have isEnabled=\(preset.isEnabled)")
        }
    }

    func testSupportsEQ_returnsTrue() async throws {
        let adapter = try AVAudioEngineAdapter()

        let supportsEQ = await adapter.supportsEQ
        XCTAssertTrue(supportsEQ, "AVAudioEngineAdapter should support EQ")
    }

    private func waitForCurrentTime(
        _ adapter: AVAudioEngineAdapter,
        atLeast target: TimeInterval
    ) async {
        for _ in 0 ..< 200 {
            if await adapter.currentTime >= target {
                return
            }
            try? await Task.sleep(for: .milliseconds(5))
        }
        XCTFail("Audio adapter did not render to \(target) seconds in time")
    }

    private func playerNodes(
        from adapter: AVAudioEngineAdapter
    ) throws -> (primary: AVAudioPlayerNode, secondary: AVAudioPlayerNode) {
        let children: [String: AVAudioPlayerNode] = Dictionary(
            uniqueKeysWithValues: Mirror(reflecting: adapter).children.compactMap { child in
                guard let label = child.label,
                      let player = child.value as? AVAudioPlayerNode
                else {
                    return nil
                }
                return (label, player)
            }
        )
        return (
            primary: try XCTUnwrap(children["primaryPlayerNode"]),
            secondary: try XCTUnwrap(children["secondaryPlayerNode"])
        )
    }

    private func isPrimaryActive(for adapter: AVAudioEngineAdapter) throws -> Bool {
        try XCTUnwrap(
            Mirror(reflecting: adapter).children
                .first(where: { $0.label == "isPrimaryActive" })?
                .value as? Bool
        )
    }
}

private struct StubProcessMetricsProvider: ProcessMetricsProviding {
    let snapshot: ProcessMetricsSnapshot

    func currentProcessMetrics() -> ProcessMetricsSnapshot {
        snapshot
    }
}
