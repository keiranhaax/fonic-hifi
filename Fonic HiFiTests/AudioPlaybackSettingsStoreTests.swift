@testable import Fonic_HiFi
import XCTest

final class AudioPlaybackSettingsStoreTests: XCTestCase {
    private let suiteName = "AudioPlaybackSettingsStoreTests"

    override func setUp() {
        super.setUp()
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    func testPersistedConfigurationMergesStoredValues() async {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = AudioPlaybackSettingsStore(defaults: defaults)
        await store.setCrossfadeDuration(4.5)
        await store.setReplayGainMode(.album)
        await store.setPlaybackRate(1.15)
        await store.setGaplessEnabled(false)

        let merged = await store.configuration(merging: AudioEngineConfiguration.default)

        XCTAssertEqual(merged.crossfadeDuration, 4.5, accuracy: 0.0001)
        XCTAssertEqual(merged.replayGainMode, .album)
        XCTAssertEqual(merged.playbackRate, 1.15, accuracy: 0.0001)
        XCTAssertFalse(merged.enableGapless)
    }

    func testDefaultsWhenNoValuesStored() async {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = AudioPlaybackSettingsStore(defaults: defaults)
        let merged = await store.configuration(merging: AudioEngineConfiguration.default)

        XCTAssertEqual(merged.crossfadeDuration, AudioEngineConfiguration.default.crossfadeDuration)
        XCTAssertEqual(merged.replayGainMode, .off)
        XCTAssertEqual(merged.playbackRate, 1.0, accuracy: 0.0001)
    }

    func testConcurrentReadsAndWritesRemainActorIsolated() async {
        let concurrentSuiteName = "\(suiteName).concurrent.\(UUID().uuidString)"
        guard let defaults = UserDefaults(suiteName: concurrentSuiteName) else {
            XCTFail("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: concurrentSuiteName)
        defer {
            UserDefaults(suiteName: concurrentSuiteName)?
                .removePersistentDomain(forName: concurrentSuiteName)
        }

        let store = AudioPlaybackSettingsStore(defaults: defaults)
        let crossfadeDurations = [0.0, 1.5, 3.0, 4.5]
        let playbackRates = [0.75, 1.0, 1.25, 1.5]
        let replayGainModes = ReplayGainMode.allCases

        let validObservations = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for index in 0 ..< 64 {
                group.addTask {
                    let crossfadeDuration = crossfadeDurations[index % crossfadeDurations.count]
                    let playbackRate = playbackRates[index % playbackRates.count]
                    let replayGainMode = replayGainModes[index % replayGainModes.count]
                    let gaplessEnabled = index.isMultiple(of: 2)

                    await store.setCrossfadeDuration(crossfadeDuration)
                    await store.setPlaybackRate(playbackRate)
                    await store.setReplayGainMode(replayGainMode)
                    await store.setGaplessEnabled(gaplessEnabled)

                    let observedCrossfade = await store.crossfadeDuration()
                    let observedRate = await store.playbackRate()
                    let observedReplayGain = await store.replayGainMode()
                    _ = await store.isGaplessEnabled()

                    return crossfadeDurations.contains(observedCrossfade)
                        && playbackRates.contains(observedRate)
                        && replayGainModes.contains(observedReplayGain)
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertEqual(validObservations.count, 64)
        XCTAssertTrue(validObservations.allSatisfy { $0 })

        await store.setCrossfadeDuration(2.75)
        await store.setPlaybackRate(1.1)
        await store.setReplayGainMode(.album)
        await store.setGaplessEnabled(false)

        let finalCrossfade = await store.crossfadeDuration()
        let finalRate = await store.playbackRate()
        let finalReplayGain = await store.replayGainMode()
        let finalGapless = await store.isGaplessEnabled()

        XCTAssertEqual(finalCrossfade, 2.75, accuracy: 0.0001)
        XCTAssertEqual(finalRate, 1.1, accuracy: 0.0001)
        XCTAssertEqual(finalReplayGain, .album)
        XCTAssertFalse(finalGapless)
    }

    // MARK: - EQ Persistence Tests

    func testEqualizerConfiguration_roundTrip() async {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = AudioPlaybackSettingsStore(defaults: defaults)

        // Create custom config
        var bands = EqualizerConfiguration.default.bands
        bands[0] = EQBand(frequency: 32, gain: 6.0, bandwidth: 1.0)
        let config = EqualizerConfiguration(bands: bands, isEnabled: true, presetName: "Bass Boost")

        // Save
        await store.setEqualizerConfiguration(config)

        // Load
        let loaded = await store.equalizerConfiguration()

        XCTAssertEqual(loaded.isEnabled, true)
        XCTAssertEqual(loaded.presetName, "Bass Boost")
        XCTAssertEqual(loaded.bands[0].gain, 6.0, accuracy: 0.01)
    }

    func testEqualizerConfiguration_defaultWhenNone() async {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            XCTFail("Unable to create UserDefaults suite")
            return
        }
        defaults.removePersistentDomain(forName: suiteName)

        let store = AudioPlaybackSettingsStore(defaults: defaults)
        let loaded = await store.equalizerConfiguration()

        XCTAssertFalse(loaded.isEnabled, "Default should be disabled")
        XCTAssertEqual(loaded.presetName, "Flat")
    }
}
