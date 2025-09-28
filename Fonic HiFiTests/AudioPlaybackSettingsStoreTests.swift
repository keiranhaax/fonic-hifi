@testable import Fonic_HiFi
import XCTest

final class AudioPlaybackSettingsStoreTests: XCTestCase {
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "AudioPlaybackSettingsStoreTests")
        defaults.removePersistentDomain(forName: "AudioPlaybackSettingsStoreTests")
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: "AudioPlaybackSettingsStoreTests")
        defaults = nil
        super.tearDown()
    }

    func testPersistedConfigurationMergesStoredValues() async {
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
        let store = AudioPlaybackSettingsStore(defaults: defaults)
        let merged = await store.configuration(merging: AudioEngineConfiguration.default)

        XCTAssertEqual(merged.crossfadeDuration, AudioEngineConfiguration.default.crossfadeDuration)
        XCTAssertEqual(merged.replayGainMode, .off)
        XCTAssertEqual(merged.playbackRate, 1.0, accuracy: 0.0001)
    }
}
