import Combine
import Foundation
import Testing

@testable import Fonic_HiFi

@Suite("PlaybackController Command Routing Tests")
struct PlaybackControllerTests {
    @Test("pause routes to engine and updates paused state")
    @MainActor
    func pauseRoutesToEngine() async throws {
        let harness = makeHarness()
        harness.engine.currentTimeValue = 12
        harness.engine.durationValue = 180
        harness.stateManager.forceUpdateState(.playing(currentTime: 12, duration: 180))

        await harness.controller.pause()

        #expect(harness.engine.pauseCallCount == 1)
        #expect(harness.stateManager.currentState == .paused(currentTime: 12, duration: 180))
    }

    @Test("stop routes to engine, stops state, and clears UI track")
    @MainActor
    func stopRoutesToEngine() async throws {
        let harness = makeHarness()
        let track = makeDisplayTrack(name: "stop-track")
        harness.uiState.currentTrack = track
        harness.uiState.showMiniPlayer = true
        harness.stateManager.forceUpdateState(.playing(currentTime: 3, duration: 120))

        await harness.controller.stop()

        #expect(harness.engine.stopCallCount == 1)
        #expect(harness.stateManager.currentState == .stopped)
        #expect(harness.uiState.currentTrack == nil)
        #expect(harness.uiState.showMiniPlayer == false)
    }

    @Test("seek routes to engine and updates playing state on success")
    @MainActor
    func seekRoutesToEngineOnSuccess() async throws {
        let harness = makeHarness()
        harness.engine.currentTimeValue = 10
        harness.engine.durationValue = 240
        harness.stateManager.forceUpdateState(.playing(currentTime: 10, duration: 240))

        try await harness.controller.seek(to: 42)

        #expect(harness.engine.seekPositions == [42])
        #expect(harness.stateManager.currentState == .playing(currentTime: 42, duration: 240))
    }

    @Test("seek propagates engine failures and restores previous state")
    @MainActor
    func seekPropagatesFailure() async throws {
        let harness = makeHarness()
        harness.engine.currentTimeValue = 15
        harness.engine.durationValue = 200
        harness.engine.seekError = AudioError.playbackFailed(reason: "seek failed")
        harness.stateManager.forceUpdateState(.paused(currentTime: 15, duration: 200))

        await #expect(throws: (any Error).self) {
            try await harness.controller.seek(to: 75)
        }
        #expect(harness.engine.seekPositions == [75])
        #expect(harness.stateManager.currentState == .paused(currentTime: 15, duration: 200))
    }

    @Test("crossfade uses engine configuration and prepares upcoming track")
    @MainActor
    func crossfadeUsesConfigurationAndPreparesNextTrack() async throws {
        let configuration = AudioEngineConfiguration.default
            .with(crossfadeDuration: 3.0)
            .with(playbackRate: 1.25)
            .with(replayGainMode: .track)

        let harness = makeHarness(configuration: configuration)

        let first = makeAudioTrack(name: "first", duration: 180)
        var second = makeAudioTrack(name: "second", duration: 200)
        second.replayGainTrack = -4
        let third = makeAudioTrack(name: "third", duration: 220)

        harness.queueManager.enqueue(tracks: [first, second, third])
        _ = harness.queueManager.setCurrentTrack(second)

        let displayTrack = makeDisplayTrack(from: second)
        try await harness.controller.crossfade(to: second, displayTrack: displayTrack)

        #expect(harness.engine.crossfadeCalls.count == 1)
        let call = try #require(harness.engine.crossfadeCalls.first)
        #expect(call.url == second.url)
        #expect(call.duration == 3.0)
        #expect(call.playbackRate == 1.25)
        #expect(call.gainDB == -4)
        #expect(harness.engine.preparedURLs == [third.url])
        #expect(harness.stateManager.currentState == .playing(currentTime: 0, duration: second.duration))
    }

    // MARK: - Helpers

    @MainActor
    private func makeHarness(
        configuration: AudioEngineConfiguration = .default
    ) -> PlaybackControllerHarness {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let queueManager = AudioQueueManager()
        let uiState = AudioUIState()
        let engine = PlaybackControllerEngineStub()
        let factory = PlaybackControllerEngineFactoryStub(engine: engine)
        let monitor = PlaybackControllerMonitorStub()
        let manager = AudioEngineManager(
            configuration: configuration,
            engineFactory: factory,
            monitor: monitor
        )
        manager.overrideCurrentEngine(engine, type: .avAudioEngine, format: .flac)

        let controller = PlaybackController(
            sessionManager: AudioSessionManager(),
            formatDetectionManager: AudioFormatDetectionManager(),
            validator: BitPerfectValidator(),
            stateManager: stateManager,
            queueManager: queueManager,
            engineManager: manager,
            progressTimer: ProgressTimerManager(),
            uiState: uiState,
            diagnosticsHandler: { _, _ in }
        )

        return PlaybackControllerHarness(
            controller: controller,
            stateManager: stateManager,
            queueManager: queueManager,
            uiState: uiState,
            engine: engine
        )
    }

    @MainActor
    private func makeDisplayTrack(name: String) -> Track {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent(name)
            .appendingPathExtension("flac")
        return Track(
            url: url,
            title: name,
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            duration: 120
        )
    }

    @MainActor
    private func makeDisplayTrack(from audioTrack: AudioTrack) -> Track {
        let track = Track(
            url: audioTrack.url,
            title: audioTrack.title,
            artist: audioTrack.artist,
            album: audioTrack.album,
            audioFormat: audioTrack.audioFormat,
            duration: audioTrack.duration
        )
        track.replayGainTrack = audioTrack.replayGainTrack
        track.replayGainAlbum = audioTrack.replayGainAlbum
        return track
    }

    private func makeAudioTrack(name: String, duration: TimeInterval) -> AudioTrack {
        LegacyTrack(
            title: name,
            artist: "Artist",
            album: "Album",
            url: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(name)
                .appendingPathExtension("flac"),
            duration: duration,
            format: .flac
        )
    }
}

@MainActor
private struct PlaybackControllerHarness {
    let controller: PlaybackController
    let stateManager: PlaybackStateManager
    let queueManager: AudioQueueManager
    let uiState: AudioUIState
    let engine: PlaybackControllerEngineStub
}

@MainActor
private final class PlaybackControllerMonitorStub: AudioPerformanceMonitoring {
    var metricsPublisher: AnyPublisher<AudioMetrics, Never> { Empty(completeImmediately: false).eraseToAnyPublisher() }
    var isMonitoring: Bool { get async { false } }
    func startMonitoring(updateInterval _: TimeInterval) async {}
    func stopMonitoring() async {}
    func updateMonitoringInterval(_: TimeInterval) async {}
    func getCurrentMetrics() async -> AudioMetrics { .empty }
    func getSystemAudioMetrics() async -> SystemAudioMetrics {
        SystemAudioMetrics(
            systemAudioCPU: 0,
            activeAudioSessions: 0,
            systemAudioMemory: 0,
            deviceInfo: AudioDeviceInfo(
                deviceID: "stub",
                name: "stub",
                sampleRate: 44_100,
                bitDepth: 16,
                channels: 2,
                bufferSize: 512,
                latency: 0
            ),
            interruptionCount: 0,
            audioUnitLoad: 0
        )
    }

    func attachToEngine(_: AudioEngineService) async {}
    func detachFromEngine() async {}
    var currentEngine: AudioEngineService? { get async { nil } }
    func startProfiling(duration _: TimeInterval?) async {}
    func stopProfiling() async {}
    func getProfilingResults() async -> PerformanceProfile? { nil }
    var isProfiling: Bool { get async { false } }
}

@MainActor
private final class PlaybackControllerEngineFactoryStub: AudioEngineFactoring {
    private let engine: AudioEngineService

    init(engine: AudioEngineService) {
        self.engine = engine
    }

    func selectEngineType(for _: AudioFormat, configuration _: AudioEngineConfiguration) -> AudioEngineType {
        .avAudioEngine
    }

    func makeEngine(for _: AudioFormat, configuration _: AudioEngineConfiguration) async throws -> AudioEngineService {
        engine
    }
}

@MainActor
private final class PlaybackControllerEngineStub: AudioEngineService {
    struct CrossfadeCall: Sendable {
        let url: URL
        let duration: TimeInterval
        let playbackRate: Double
        let gainDB: Float
    }

    var currentTimeValue: TimeInterval = 0
    var durationValue: TimeInterval = 120
    var isPlayingValue = false
    var volumeValue: Float = 1
    var stopCallCount = 0
    var pauseCallCount = 0
    var seekPositions: [TimeInterval] = []
    var preparedURLs: [URL] = []
    var crossfadeCalls: [CrossfadeCall] = []
    var seekError: (any Error)?

    var currentTime: TimeInterval { get async { currentTimeValue } }
    var duration: TimeInterval { get async { durationValue } }
    var isPlaying: Bool { get async { isPlayingValue } }
    var volume: Float { get async { volumeValue } }
    var audioFormat: AudioFormat? { get async { .flac } }

    func load(url _: URL) async throws {}

    func play() async throws {
        isPlayingValue = true
    }

    func pause() async {
        pauseCallCount += 1
        isPlayingValue = false
    }

    func stop() async {
        stopCallCount += 1
        isPlayingValue = false
    }

    func seek(to time: TimeInterval) async throws {
        seekPositions.append(time)
        if let seekError {
            throw seekError
        }
        currentTimeValue = time
    }

    func setVolume(_ volume: Float) async {
        volumeValue = volume
    }

    func setPlaybackRate(_: Double) async {}
    func applyReplayGain(_: Float) async {}
    func configure(with _: AudioEngineConfiguration) async throws {}

    func prepareNext(url: URL) async {
        preparedURLs.append(url)
    }

    func crossfade(to url: URL, duration: TimeInterval, playbackRate: Double, gainDB: Float) async throws {
        crossfadeCalls.append(
            CrossfadeCall(url: url, duration: duration, playbackRate: playbackRate, gainDB: gainDB)
        )
        currentTimeValue = 0
        isPlayingValue = true
    }

    func getMetrics() async -> AudioMetrics {
        .empty
    }

    func collectMetrics() async {}
}
