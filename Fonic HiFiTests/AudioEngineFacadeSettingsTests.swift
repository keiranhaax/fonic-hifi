@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioEngineFacadeSettingsTests: XCTestCase {
    func testUpdatePlaybackRatePersistsAndUpdatesEngine() async {
        let store = AudioPlaybackSettingsStore(defaults: makeAudioEngineFacadeDefaults())
        let facade = AudioEngineFacade(
            sessionManager: AudioSessionManager(),
            formatDetectionManager: AudioFormatDetectionManager(),
            stateManager: PlaybackStateManager(),
            queueManager: AudioQueueManager(),
            validator: BitPerfectValidator(),
            monitor: AudioMonitor(),
            playbackSettingsStore: store,
        )

        let engine = MockAudioEngineService()
        facade.setCurrentEngine(engine)

        await facade.updatePlaybackRate(1.25)

        XCTAssertEqual(facade.playbackRate, 1.25, accuracy: 0.0001)
        let storedPlaybackRate = await store.playbackRate()
        XCTAssertEqual(storedPlaybackRate, 1.25, accuracy: 0.0001)
        XCTAssertEqual(engine.playbackRates.last, 1.25)
    }

    func testUpdateReplayGainAppliesToEngine() async {
        let store = AudioPlaybackSettingsStore(defaults: makeAudioEngineFacadeDefaults())
        let facade = AudioEngineFacade(
            sessionManager: AudioSessionManager(),
            formatDetectionManager: AudioFormatDetectionManager(),
            stateManager: PlaybackStateManager(),
            queueManager: AudioQueueManager(),
            validator: BitPerfectValidator(),
            monitor: AudioMonitor(),
            playbackSettingsStore: store,
        )

        let engine = MockAudioEngineService()
        facade.setCurrentEngine(engine)

        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("test.flac")
        let track = Track(url: tempURL, title: "Test", artist: "Tester", album: "Album", audioFormat: "FLAC", duration: 180)
        track.replayGainTrack = -6.0
        facade.setCurrentTrack(track)

        await facade.updateReplayGainMode(.track)

        XCTAssertEqual(facade.replayGainMode, .track)
        let storedReplayGainMode = await store.replayGainMode()
        XCTAssertEqual(storedReplayGainMode, .track)
        if let lastGain = engine.replayGains.last {
            XCTAssertEqual(lastGain, -6.0 as Float, accuracy: 0.0001 as Float)
        } else {
            XCTFail("Expected replay gain value to be recorded")
        }
    }

    func testRefreshDiagnosticsUpdatesStatus() async {
        let store = AudioPlaybackSettingsStore(defaults: makeAudioEngineFacadeDefaults())
        let facade = AudioEngineFacade(
            sessionManager: AudioSessionManager(),
            formatDetectionManager: AudioFormatDetectionManager(),
            stateManager: PlaybackStateManager(),
            queueManager: AudioQueueManager(),
            validator: BitPerfectValidator(),
            monitor: AudioMonitor(),
            playbackSettingsStore: store,
        )

        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("diagnostics-test.flac")
        let track = Track(url: url, title: "Diagnostics", artist: "Tester", album: "Album", audioFormat: "FLAC", duration: 120)
        let info = AudioFileInfo(
            url: url,
            format: .flac,
            duration: 120,
            bitDepth: 16,
            sampleRate: 44100,
            channels: 2,
            fileSize: 1024,
        )

        await facade.refreshDiagnostics(for: track, formatInfo: info)

        XCTAssertEqual(facade.diagnosticsStatus.track?.title, track.title)
        XCTAssertNotNil(facade.diagnosticsStatus.metrics)
    }

    func testPlayNextTriggersCrossfadeWithConfiguredParameters() async throws {
        let store = AudioPlaybackSettingsStore(defaults: makeAudioEngineFacadeDefaults("crossfade"))
        let queueManager = AudioQueueManager()
        let stateManager = PlaybackStateManager()
        let configuration = AudioEngineConfiguration(crossfadeDuration: 3.5, playbackRate: 1.15)
        let facade = AudioEngineFacade(
            configuration: configuration,
            sessionManager: AudioSessionManager(),
            formatDetectionManager: AudioFormatDetectionManager(),
            stateManager: stateManager,
            queueManager: queueManager,
            validator: BitPerfectValidator(),
            monitor: AudioMonitor(),
            playbackSettingsStore: store,
        )

        let engine = MockAudioEngineService()
        facade.setCurrentEngine(engine)

        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let firstURL = baseURL.appendingPathComponent("crossfade-first.flac")
        let secondURL = baseURL.appendingPathComponent("crossfade-second.flac")

        let firstTrack = LegacyTrack(id: UUID(), title: "First", artist: "Artist", album: "Album", url: firstURL, duration: 180, audioFormat: "FLAC")
        let secondTrack = LegacyTrack(id: UUID(), title: "Second", artist: "Artist", album: "Album", url: secondURL, duration: 200, audioFormat: "FLAC")

        queueManager.enqueue(tracks: [firstTrack, secondTrack])
        queueManager.setCurrentTrack(firstTrack)

        let uiTrack = Track(url: firstURL, title: "First", artist: "Artist", album: "Album", audioFormat: "FLAC", duration: 180)
        facade.setCurrentTrack(uiTrack)
        stateManager.forceUpdateState(.playing(currentTime: 0, duration: 180))

        try await facade.playNext()

        let call = engine.crossfadeCalls.last
        XCTAssertNotNil(call)
        if let call {
            XCTAssertEqual(call.url, secondURL)
            XCTAssertEqual(call.duration, configuration.crossfadeDuration, accuracy: 0.0001)
            XCTAssertEqual(call.playbackRate, configuration.playbackRate, accuracy: 0.0001)
            XCTAssertEqual(call.gainDB, 0, accuracy: 0.0001)
        }
    }

    func testReplayGainDefaultsToZeroWhenMetadataMissing() async {
        let store = AudioPlaybackSettingsStore(defaults: makeAudioEngineFacadeDefaults())
        let facade = AudioEngineFacade(
            sessionManager: AudioSessionManager(),
            formatDetectionManager: AudioFormatDetectionManager(),
            stateManager: PlaybackStateManager(),
            queueManager: AudioQueueManager(),
            validator: BitPerfectValidator(),
            monitor: AudioMonitor(),
            playbackSettingsStore: store,
        )

        let engine = MockAudioEngineService()
        facade.setCurrentEngine(engine)

        let url = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("replaygain-default.flac")
        let track = Track(url: url, title: "No Gain", artist: "Tester", album: "Album", audioFormat: "FLAC", duration: 100)
        facade.setCurrentTrack(track)

        await facade.updateReplayGainMode(.track)

        if let lastGain = engine.replayGains.last {
            XCTAssertEqual(lastGain, 0 as Float, accuracy: 0.0001 as Float)
        } else {
            XCTFail("Expected replay gain value to be recorded")
        }
    }
}

@MainActor
private final class MockAudioEngineService: AudioEngineService {
    var playbackRates: [Double] = []
    var replayGains: [Float] = []
    var crossfadeCalls: [(url: URL, duration: TimeInterval, playbackRate: Double, gainDB: Float)] = []

    var currentTime: TimeInterval { get async { 0 } }
    var duration: TimeInterval { get async { 0 } }
    var isPlaying: Bool { get async { false } }
    var volume: Float { get async { 1 } }
    var audioFormat: AudioFormat? { get async { .flac } }

    func load(url _: URL) async throws {}
    func play() async throws {}
    func pause() async {}
    func stop() async {}
    func seek(to _: TimeInterval) async throws {}
    func setVolume(_: Float) async {}
    func configure(with _: AudioEngineConfiguration) async throws {}
    func prepareNext(url _: URL) async {}
    func crossfade(to url: URL, duration: TimeInterval, playbackRate: Double, gainDB: Float) async throws {
        crossfadeCalls.append((url, duration, playbackRate, gainDB))
        await setPlaybackRate(playbackRate)
        await applyReplayGain(gainDB)
    }

    func getMetrics() async -> AudioMetrics { AudioMetrics.empty }
    func collectMetrics() async {}

    func setPlaybackRate(_ rate: Double) async {
        playbackRates.append(rate)
    }

    func applyReplayGain(_ gainDB: Float) async {
        replayGains.append(gainDB)
    }
}

private func makeAudioEngineFacadeDefaults(_ suffix: String = "shared") -> UserDefaults {
    let name = "AudioEngineFacadeSettingsTests.\(suffix)"
    if let defaults = UserDefaults(suiteName: name) {
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    let fallback = UserDefaults.standard
    fallback.removePersistentDomain(forName: name)
    return fallback
}
