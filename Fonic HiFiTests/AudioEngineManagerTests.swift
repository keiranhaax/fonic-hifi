@testable import Fonic_HiFi
import os
import XCTest

@MainActor
final class AudioEngineManagerTests: XCTestCase {
    private let metricsDefaultsKey = "com.fonichifi.metrics.enabled"

    override func tearDown() {
        Metrics.setSinkForTesting(nil)
        Metrics.enable(false)
        UserDefaults.standard.removeObject(forKey: metricsDefaultsKey)
        super.tearDown()
    }

    func testEnsureEngineReusesExistingEngineWhenTypeMatches() async throws {
        let factory = RecordingEngineFactory(typeForFormat: [
            .flac: .audioKitEngine,
            .wav: .avAudioEngine,
        ])
        let monitor = AudioMonitor()
        let manager = AudioEngineManager(
            configuration: .default,
            engineFactory: factory,
            monitor: monitor,
        )

        let flacInfo = makeInfo(format: .flac)
        let first = try await manager.ensureEngine(for: flacInfo)
        let second = try await manager.ensureEngine(for: flacInfo)

        let recordedFirst = try XCTUnwrap(first as? RecordingAudioEngine)
        let recordedSecond = try XCTUnwrap(second as? RecordingAudioEngine)
        XCTAssertTrue(recordedFirst === recordedSecond)
        XCTAssertEqual(recordedFirst.configureCount, 2)
        XCTAssertEqual(factory.makeEngineCallCount, 1)
        XCTAssertEqual(manager.currentEngineType, .audioKitEngine)

        let wavInfo = makeInfo(format: .wav)
        let third = try await manager.ensureEngine(for: wavInfo)
        let recordedThird = try XCTUnwrap(third as? RecordingAudioEngine)
        XCTAssertFalse(recordedFirst === recordedThird)
        XCTAssertEqual(factory.makeEngineCallCount, 2)
        XCTAssertEqual(manager.currentEngineType, .avAudioEngine)
    }

    func testPlaybackSettingsApplyOnEngineCreationAndSwitch() async throws {
        let factory = RecordingEngineFactory(typeForFormat: [
            .flac: .audioKitEngine,
            .wav: .avAudioEngine,
        ])
        let initialConfiguration = AudioEngineConfiguration(
            enableGapless: false,
            crossfadeDuration: 3,
            replayGainMode: .track,
        )
        let manager = AudioEngineManager(
            configuration: initialConfiguration,
            engineFactory: factory,
            monitor: AudioMonitor(),
        )

        let first = try await manager.ensureEngine(for: makeInfo(format: .flac))
        let firstEngine = try XCTUnwrap(first as? RecordingAudioEngine)
        assertPlaybackSettings(firstEngine.configurations.last, equal: initialConfiguration)

        let switchedConfiguration = initialConfiguration
            .with(enableGapless: true)
            .with(crossfadeDuration: 6)
            .with(replayGainMode: .album)
        await manager.updateConfiguration(switchedConfiguration)

        let second = try await manager.ensureEngine(for: makeInfo(format: .wav))
        let secondEngine = try XCTUnwrap(second as? RecordingAudioEngine)

        XCTAssertFalse(firstEngine === secondEngine)
        XCTAssertEqual(factory.makeEngineCallCount, 2)
        XCTAssertEqual(factory.makeConfigurations.count, 2)
        assertPlaybackSettings(factory.makeConfigurations.last, equal: switchedConfiguration)
        assertPlaybackSettings(secondEngine.configurations.last, equal: switchedConfiguration)
    }

    func testEqualizerConfigurationReappliesAcrossSupportedAndUnsupportedEngineSwitches() async throws {
        let factory = RecordingEngineFactory(
            typeForFormat: [
                .wav: .avAudioEngine,
                .flac: .audioKitEngine,
            ],
            equalizerSupport: [
                .avAudioEngine: true,
                .audioKitEngine: false,
            ]
        )
        let manager = AudioEngineManager(
            configuration: .default,
            engineFactory: factory,
            monitor: AudioMonitor()
        )
        let persistedConfiguration = try XCTUnwrap(EqualizerConfiguration.presets["Bass Boost"])

        let initialResult = await manager.updateEqualizerConfiguration(persistedConfiguration)
        XCTAssertEqual(initialResult, .waitingForEngine)
        XCTAssertTrue(manager.configuration.equalizerEnabled)

        let initialEngine = try await manager.ensureEngine(for: makeInfo(format: .wav))
        let nativeEngine = try XCTUnwrap(initialEngine as? RecordingAudioEngine)
        XCTAssertEqual(nativeEngine.equalizerConfigurations, [persistedConfiguration])
        XCTAssertEqual(
            manager.equalizerApplicationResult,
            .applied(engine: .avAudioEngine)
        )

        let switchedEngine = try await manager.ensureEngine(for: makeInfo(format: .flac))
        let unsupportedEngine = try XCTUnwrap(switchedEngine as? RecordingAudioEngine)
        XCTAssertTrue(unsupportedEngine.equalizerConfigurations.isEmpty)
        XCTAssertEqual(
            manager.equalizerApplicationResult,
            .unsupported(engine: .audioKitEngine)
        )
        XCTAssertEqual(manager.equalizerConfiguration, persistedConfiguration)

        let replacementEngine = try await manager.ensureEngine(for: makeInfo(format: .wav))
        let replacementNativeEngine = try XCTUnwrap(replacementEngine as? RecordingAudioEngine)
        XCTAssertFalse(nativeEngine === replacementNativeEngine)
        XCTAssertEqual(replacementNativeEngine.equalizerConfigurations, [persistedConfiguration])
        XCTAssertEqual(
            manager.equalizerApplicationResult,
            .applied(engine: .avAudioEngine)
        )
    }

    func testEqualizerGraphFailureIsReportedAsNotApplied() async throws {
        let manager = AudioEngineManager(
            configuration: .default,
            engineFactory: RecordingEngineFactory(typeForFormat: [:]),
            monitor: AudioMonitor()
        )
        let engine = RecordingAudioEngine(
            supportsEqualizer: true,
            shouldFailEqualizerApplication: true
        )
        manager.overrideCurrentEngine(engine, type: .avAudioEngine)
        let configuration = try XCTUnwrap(EqualizerConfiguration.presets["Rock"])

        let result = await manager.updateEqualizerConfiguration(configuration)

        XCTAssertEqual(result, .failed(engine: .avAudioEngine))
        XCTAssertTrue(engine.equalizerConfigurations.isEmpty)
        XCTAssertNotNil(result.unavailableMessage)
    }

    func testMediaServicesResetRebuildsWithoutCallingInvalidEngine() async throws {
        let factory = RecordingEngineFactory(
            typeForFormat: [.wav: .avAudioEngine],
            equalizerSupport: [.avAudioEngine: true]
        )
        let manager = AudioEngineManager(
            configuration: .default.with(playbackRate: 1.25),
            engineFactory: factory,
            monitor: AudioMonitor()
        )
        let equalizer = try XCTUnwrap(EqualizerConfiguration.presets["Rock"])
        _ = await manager.updateEqualizerConfiguration(equalizer)
        let info = makeInfo(format: .wav)

        let original = try await manager.ensureEngine(for: info)
        let originalEngine = try XCTUnwrap(original as? RecordingAudioEngine)
        let replacement = try await manager.rebuildEngineAfterMediaServicesReset(for: info)
        let replacementEngine = try XCTUnwrap(replacement as? RecordingAudioEngine)

        XCTAssertFalse(originalEngine === replacementEngine)
        XCTAssertEqual(factory.makeEngineCallCount, 2)
        XCTAssertEqual(originalEngine.isPlayingReadCount, 0)
        XCTAssertEqual(originalEngine.stopCallCount, 0)
        XCTAssertEqual(replacementEngine.equalizerConfigurations, [equalizer])
        XCTAssertEqual(manager.currentEngineType, .avAudioEngine)
        XCTAssertEqual(manager.currentFormat, .wav)
    }

    func testEngineSwitchEmitsMetricsForNewConfiguration() async throws {
        let factory = RecordingEngineFactory(typeForFormat: [
            .flac: .audioKitEngine,
            .wav: .avAudioEngine,
        ])
        let monitor = AudioMonitor()
        let manager = AudioEngineManager(
            configuration: .default,
            engineFactory: factory,
            monitor: monitor
        )

        let recorder = OSAllocatedUnfairLock<
            [(counter: MetricsCounter, amount: Int, metadata: [String: String])]
        >(initialState: [])
        Metrics.enable(true)
        Metrics.setSinkForTesting { counter, amount, _, metadata in
            guard counter == .engineSwitch else { return }
            recorder.withLock { events in
                events.append((counter, amount, metadata))
            }
        }

        let flacInfo = makeInfo(format: .flac)
        _ = try await manager.ensureEngine(for: flacInfo)
        var events = recorder.withLock { storedEvents in
            defer { storedEvents.removeAll() }
            return storedEvents
        }
        XCTAssertEqual(events.count, 1)
        if let event = events.first {
            XCTAssertEqual(event.counter, .engineSwitch)
            XCTAssertEqual(event.amount, 1)
            XCTAssertEqual(event.metadata["type"], AudioEngineType.audioKitEngine.rawValue)
            XCTAssertEqual(event.metadata["format"], "FLAC")
        }

        let wavInfo = makeInfo(format: .wav)
        _ = try await manager.ensureEngine(for: wavInfo)
        events = recorder.withLock { storedEvents in
            defer { storedEvents.removeAll() }
            return storedEvents
        }
        XCTAssertEqual(events.count, 1)
        if let event = events.first {
            XCTAssertEqual(event.metadata["type"], AudioEngineType.avAudioEngine.rawValue)
            XCTAssertEqual(event.metadata["format"], "WAV")
        }
    }

    // MARK: - Helpers

    private func makeInfo(format: AudioFormat) -> AudioFileInfo {
        AudioFileInfo(
            url: URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(format.fileExtension),
            format: format,
            duration: 180,
            bitDepth: 16,
            sampleRate: 44100,
            channels: 2,
            fileSize: 1_048_576,
        )
    }

    private func assertPlaybackSettings(
        _ actual: AudioEngineConfiguration?,
        equal expected: AudioEngineConfiguration,
        file: StaticString = #filePath,
        line: UInt = #line,
    ) {
        guard let actual else {
            XCTFail("Expected an applied audio-engine configuration", file: file, line: line)
            return
        }

        XCTAssertEqual(actual.enableGapless, expected.enableGapless, file: file, line: line)
        XCTAssertEqual(actual.crossfadeDuration, expected.crossfadeDuration, accuracy: 0.0001, file: file, line: line)
        XCTAssertEqual(actual.replayGainMode, expected.replayGainMode, file: file, line: line)
    }
}

// MARK: - Test Doubles

@MainActor
private final class RecordingEngineFactory: AudioEngineFactoring {
    private let typeForFormat: [AudioFormat: AudioEngineType]
    private let equalizerSupport: [AudioEngineType: Bool]
    private(set) var makeEngineCallCount = 0
    private(set) var makeConfigurations: [AudioEngineConfiguration] = []

    init(
        typeForFormat: [AudioFormat: AudioEngineType],
        equalizerSupport: [AudioEngineType: Bool] = [:]
    ) {
        self.typeForFormat = typeForFormat
        self.equalizerSupport = equalizerSupport
    }

    func selectEngineType(
        for format: AudioFormat,
        configuration _: AudioEngineConfiguration,
    ) -> AudioEngineType {
        typeForFormat[format] ?? .avAudioEngine
    }

    func makeEngine(
        for format: AudioFormat,
        configuration: AudioEngineConfiguration,
    ) async throws -> AudioEngineService {
        makeEngineCallCount += 1
        makeConfigurations.append(configuration)
        let type = typeForFormat[format] ?? .avAudioEngine
        let engine = RecordingAudioEngine(supportsEqualizer: equalizerSupport[type] ?? false)
        try await engine.configure(with: configuration)
        return engine
    }
}

@MainActor
private final class RecordingAudioEngine: AudioEngineService {
    private(set) var configureCount = 0
    private(set) var configurations: [AudioEngineConfiguration] = []
    private(set) var equalizerConfigurations: [EqualizerConfiguration] = []
    private(set) var isPlayingReadCount = 0
    private(set) var stopCallCount = 0
    private let supportsEqualizer: Bool
    private let shouldFailEqualizerApplication: Bool

    init(
        supportsEqualizer: Bool = false,
        shouldFailEqualizerApplication: Bool = false
    ) {
        self.supportsEqualizer = supportsEqualizer
        self.shouldFailEqualizerApplication = shouldFailEqualizerApplication
    }

    var currentTime: TimeInterval { get async { 0 } }
    var duration: TimeInterval { get async { 0 } }
    var isPlaying: Bool {
        get async {
            isPlayingReadCount += 1
            return false
        }
    }
    var volume: Float { get async { 1 } }
    var audioFormat: AudioFormat? { get async { nil } }

    func load(url _: URL) async throws {}
    func play() async throws {}
    func pause() async {}
    func stop() async {
        stopCallCount += 1
    }
    func seek(to _: TimeInterval) async throws {}
    func setVolume(_: Float) async {}
    func setPlaybackRate(_: Double) async {}
    func applyReplayGain(_: Float) async {}

    func configure(with configuration: AudioEngineConfiguration) async throws {
        configureCount += 1
        configurations.append(configuration)
    }

    func prepareNext(url _: URL) async {}
    func invalidatePreparedTransition() async {}

    func crossfade(to _: URL, duration _: TimeInterval, playbackRate _: Double, gainDB _: Float) async throws {}

    var metricsAvailability: AudioMetricsAvailability { .available }

    func availableMetrics() async -> AudioMetrics? {
        AudioMetrics(
            cpuUsage: 0,
            memoryUsage: 0,
            bufferUnderruns: 0,
            decodingLatency: 0,
            bufferFillLevel: 1,
            droppedFrames: 0,
            renderLatency: 0,
        )
    }

    func collectMetrics() async {}

    var supportsEQ: Bool {
        get async { supportsEqualizer }
    }

    func applyEQ(_ configuration: EqualizerConfiguration) async throws {
        if shouldFailEqualizerApplication {
            throw RecordingAudioEngineError.equalizerApplicationFailed
        }
        equalizerConfigurations.append(configuration)
    }
}

private enum RecordingAudioEngineError: Error {
    case equalizerApplicationFailed
}
