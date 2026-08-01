import Combine
import Foundation
import MediaPlayer
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

    @Test("A-B loop seek updates observable progress to point A in the same cycle")
    @MainActor
    func abLoopSeekUpdatesProgressToPointA() async {
        let sessionManager = PlaybackControllerSessionServiceStub()
        let harness = makeHarness(sessionManager: sessionManager)
        harness.engine.currentTimeValue = 20
        harness.engine.durationValue = 120
        harness.stateManager.forceUpdateState(.playing(currentTime: 19, duration: 120))
        harness.controller.loopCheckHandler = { _ in 5 }

        await harness.controller.refreshPlaybackProgress(engine: harness.engine)

        #expect(harness.engine.seekPositions == [5])
        #expect(harness.stateManager.currentState == .playing(currentTime: 5, duration: 120))
        #expect(
            sessionManager.nowPlayingInfos.last?[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval == 5
        )
    }

    @Test("A-B loop seek failure becomes a typed observable playback error")
    @MainActor
    func abLoopSeekFailureBecomesObservableError() async {
        let harness = makeHarness()
        let expectedError = AudioError.invalidSeekPosition(5)
        harness.engine.currentTimeValue = 20
        harness.engine.durationValue = 120
        harness.engine.seekError = expectedError
        harness.stateManager.forceUpdateState(.playing(currentTime: 19, duration: 120))
        harness.controller.loopCheckHandler = { _ in 5 }

        await harness.controller.refreshPlaybackProgress(engine: harness.engine)

        #expect(harness.engine.seekPositions == [5])
        #expect(harness.stateManager.currentState == .error(expectedError, lastKnownTime: 20))
    }

    @Test("crossfade uses engine configuration without arming a gapless transition")
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
        #expect(harness.engine.preparedURLs.isEmpty)
        #expect(harness.stateManager.currentState == .playing(currentTime: 0, duration: second.duration))
    }

    @Test("gapless play prepares the upcoming queue track")
    @MainActor
    func gaplessPlayPreparesUpcomingTrack() async throws {
        let first = makeAudioTrack(name: "gapless-first", duration: 180)
        let second = makeAudioTrack(name: "gapless-second", duration: 200)
        let info = AudioFileInfo(
            url: first.url,
            format: .flac,
            duration: first.duration,
            bitDepth: 24,
            sampleRate: 48_000,
            channels: 2,
            fileSize: 1_024
        )
        let harness = makeHarness(
            sessionManager: PlaybackControllerSessionServiceStub(),
            formatDetectionManager: PlaybackControllerFormatDetectionServiceStub(info: info)
        )
        harness.queueManager.enqueue(tracks: [first, second])
        _ = harness.queueManager.setCurrentTrack(first)

        try await harness.controller.play(
            track: makeDisplayTrack(from: first),
            queueEntry: first
        )

        #expect(harness.engine.preparedURLs == [second.url])
    }

    @Test("play sets preferred sample rate before activating audio session")
    @MainActor
    func playSetsPreferredSampleRateBeforeActivatingSession() async throws {
        let track = makeDisplayTrack(name: "sample-rate")
        let sessionManager = PlaybackControllerSessionServiceStub()
        let detectedInfo = AudioFileInfo(
            url: track.url,
            format: .alac,
            duration: 183,
            bitDepth: 24,
            sampleRate: 96_000,
            channels: 2,
            fileSize: 1_024
        )
        let formatDetectionManager = PlaybackControllerFormatDetectionServiceStub(info: detectedInfo)

        let harness = makeHarness(
            sessionManager: sessionManager,
            formatDetectionManager: formatDetectionManager
        )

        try await harness.controller.play(track: track)

        let detectedURLs = await formatDetectionManager.detectedURLs
        #expect(detectedURLs == [track.url])
        #expect(sessionManager.preferredSampleRates == [96_000])
        #expect(
            Array(sessionManager.eventLog.prefix(2)) == [
                "setPreferredSampleRate",
                "activateAudioSession",
            ]
        )
    }

    @Test("Media-services reset restores track and position in paused state")
    @MainActor
    func mediaServicesResetRestoresPausedPlaybackAndNowPlaying() async throws {
        let replacementEngine = PlaybackControllerEngineStub()
        let sessionManager = PlaybackControllerSessionServiceStub()
        let harness = makeHarness(
            sessionManager: sessionManager,
            replacementEngine: replacementEngine
        )
        let track = makeDisplayTrack(name: "reset-recovery")
        let queueEntry = track.toAudioTrack()
        harness.queueManager.enqueue(tracks: [queueEntry])
        _ = harness.queueManager.setCurrentTrack(queueEntry)
        harness.uiState.currentTrack = track
        harness.uiState.showMiniPlayer = true
        harness.stateManager.forceUpdateState(
            .playing(currentTime: 37, duration: 120)
        )
        let info = AudioFileInfo(
            url: track.url,
            format: .flac,
            duration: 120,
            bitDepth: 24,
            sampleRate: 48_000,
            channels: 2,
            fileSize: 1_024
        )

        try await harness.controller.recoverAfterMediaServicesReset(
            track: track,
            queueEntry: queueEntry,
            info: info,
            preservedPosition: 37
        )

        #expect(replacementEngine.loadedURLs == [track.url])
        #expect(replacementEngine.seekPositions == [37])
        #expect(replacementEngine.pauseCallCount == 1)
        #expect(replacementEngine.isPlayingValue == false)
        #expect(harness.stateManager.currentState == .paused(currentTime: 37, duration: 120))
        #expect(harness.uiState.currentTrack?.id == track.id)
        #expect(harness.uiState.showMiniPlayer)

        let nowPlaying = try #require(sessionManager.nowPlayingInfos.last)
        #expect(nowPlaying[MPNowPlayingInfoPropertyElapsedPlaybackTime] as? TimeInterval == 37)
        #expect(nowPlaying[MPNowPlayingInfoPropertyPlaybackRate] as? Float == 0)
        #expect(nowPlaying[MPMediaItemPropertyPlaybackDuration] as? TimeInterval == 120)
    }

    // MARK: - Helpers

    @MainActor
    private func makeHarness(
        configuration: AudioEngineConfiguration = .default,
        sessionManager: (any AudioSessionService)? = nil,
        formatDetectionManager: (any FormatDetectionService)? = nil,
        replacementEngine: AudioEngineService? = nil
    ) -> PlaybackControllerHarness {
        let stateManager = PlaybackStateManager(enableTransitionValidation: false)
        let queueManager = AudioQueueManager()
        let uiState = AudioUIState()
        let engine = PlaybackControllerEngineStub()
        let factory = PlaybackControllerEngineFactoryStub(
            engine: replacementEngine ?? engine
        )
        let monitor = PlaybackControllerMonitorStub()
        let manager = AudioEngineManager(
            configuration: configuration,
            engineFactory: factory,
            monitor: monitor
        )
        manager.overrideCurrentEngine(engine, type: .avAudioEngine, format: .flac)

        let controller = PlaybackController(
            sessionManager: sessionManager ?? AudioSessionManager(),
            formatDetectionManager: formatDetectionManager ?? AudioFormatDetectionManager(),
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
private final class PlaybackControllerSessionServiceStub: AudioSessionService {
    private(set) var preferredSampleRates: [Double] = []
    private(set) var eventLog: [String] = []
    private(set) var nowPlayingInfos: [[String: Any]] = []
    private var sessionActive = false

    func configureAudioSession() async throws {}

    func activateAudioSession() async throws {
        sessionActive = true
        eventLog.append("activateAudioSession")
    }

    func setPreferredSampleRate(_ sampleRate: Double) async {
        preferredSampleRates.append(sampleRate)
        eventLog.append("setPreferredSampleRate")
    }

    func deactivateAudioSession() async throws {
        sessionActive = false
        eventLog.append("deactivateAudioSession")
    }

    var isSessionActive: Bool { get async { sessionActive } }
    var currentRoute: String { get async { "Stub Route" } }
    var isBackgroundAudioEnabled: Bool { get async { true } }

    func handleInterruption(_: AudioInterruptionType) async {}
    func handleRouteChange(_: AudioRouteChange) async {}

    func updateNowPlayingInfo(_ info: [String: Any]) async {
        nowPlayingInfos.append(info)
        eventLog.append("updateNowPlayingInfo")
    }

    func clearNowPlayingInfo() async {
        eventLog.append("clearNowPlayingInfo")
    }

    func enableRemoteCommands() async {}
    func disableRemoteCommands() async {}

    func getAvailableOutputs() async -> [AudioDevice] { [] }
    func setPreferredOutput(_: AudioDevice) async throws {}
}

private actor PlaybackControllerFormatDetectionServiceStub: FormatDetectionService {
    let info: AudioFileInfo
    private(set) var detectedURLs: [URL] = []

    init(info: AudioFileInfo) {
        self.info = info
    }

    func detectFormat(at url: URL) async throws -> AudioFileInfo {
        detectedURLs.append(url)
        return info
    }

    func validateFile(at _: URL) async -> Bool {
        true
    }

    func isFormatSupported(_: AudioFormat) -> Bool {
        true
    }

    func getFormatCapabilities(_: AudioFormat) -> FormatCapabilities? {
        FormatCapabilities(
            maxSampleRate: 192_000,
            maxBitDepth: 32,
            supportsMultiChannel: true,
            supportsArtwork: true,
            supportsChapters: false,
            requiresSpecializedDecoder: false
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
    var loadedURLs: [URL] = []
    var seekPositions: [TimeInterval] = []
    var preparedURLs: [URL] = []
    var crossfadeCalls: [CrossfadeCall] = []
    var seekError: (any Error)?

    var currentTime: TimeInterval { get async { currentTimeValue } }
    var duration: TimeInterval { get async { durationValue } }
    var isPlaying: Bool { get async { isPlayingValue } }
    var volume: Float { get async { volumeValue } }
    var audioFormat: AudioFormat? { get async { .flac } }

    func load(url: URL) async throws {
        loadedURLs.append(url)
    }

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

    var metricsAvailability: AudioMetricsAvailability { .available }

    func availableMetrics() async -> AudioMetrics? {
        .empty
    }

    func collectMetrics() async {}
}
