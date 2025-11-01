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

        let merged = await store.configuration(merging: AudioEngineConfiguration.default)

        XCTAssertEqual(merged.crossfadeDuration, 4.5, accuracy: 0.0001)
        XCTAssertEqual(merged.replayGainMode, .album)
        XCTAssertEqual(merged.playbackRate, 1.15, accuracy: 0.0001)
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
}
