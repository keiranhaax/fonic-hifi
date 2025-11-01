@testable import Fonic_HiFi
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

        let recorder = EngineMetricsRecorder()
        Metrics.enable(true)
        Metrics.setSinkForTesting { counter, amount, _, metadata in
            guard counter == .engineSwitch else { return }
            Task {
                await recorder.record(counter: counter, amount: amount, metadata: metadata)
            }
        }

        let flacInfo = makeInfo(format: .flac)
        _ = try await manager.ensureEngine(for: flacInfo)
        var events = await recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        if let event = events.first {
            XCTAssertEqual(event.counter, .engineSwitch)
            XCTAssertEqual(event.amount, 1)
            XCTAssertEqual(event.metadata["type"], AudioEngineType.audioKitEngine.rawValue)
            XCTAssertEqual(event.metadata["format"], "FLAC")
        }

        let wavInfo = makeInfo(format: .wav)
        _ = try await manager.ensureEngine(for: wavInfo)
        events = await recorder.takeEvents()
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
}

// MARK: - Test Doubles

private actor EngineMetricsRecorder {
    private var events: [(counter: MetricsCounter, amount: Int, metadata: [String: String])] = []

    func record(counter: MetricsCounter, amount: Int, metadata: [String: String]) {
        events.append((counter, amount, metadata))
    }

    func takeEvents() -> [(counter: MetricsCounter, amount: Int, metadata: [String: String])] {
        let snapshot = events
        events.removeAll()
        return snapshot
    }
}

@MainActor
private final class RecordingEngineFactory: AudioEngineFactoring {
    private let typeForFormat: [AudioFormat: AudioEngineType]
    private(set) var makeEngineCallCount = 0

    init(typeForFormat: [AudioFormat: AudioEngineType]) {
        self.typeForFormat = typeForFormat
    }

    func selectEngineType(
        for format: AudioFormat,
        configuration _: AudioEngineConfiguration,
    ) -> AudioEngineType {
        typeForFormat[format] ?? .avAudioEngine
    }

    func makeEngine(
        for _: AudioFormat,
        configuration: AudioEngineConfiguration,
    ) async throws -> AudioEngineService {
        makeEngineCallCount += 1
        let engine = RecordingAudioEngine()
        try await engine.configure(with: configuration)
        return engine
    }
}

@MainActor
private final class RecordingAudioEngine: AudioEngineService {
    private(set) var configureCount = 0

    var currentTime: TimeInterval { get async { 0 } }
    var duration: TimeInterval { get async { 0 } }
    var isPlaying: Bool { get async { false } }
    var volume: Float { get async { 1 } }
    var audioFormat: AudioFormat? { get async { nil } }

    func load(url _: URL) async throws {}
    func play() async throws {}
    func pause() async {}
    func stop() async {}
    func seek(to _: TimeInterval) async throws {}
    func setVolume(_: Float) async {}
    func setPlaybackRate(_: Double) async {}
    func applyReplayGain(_: Float) async {}

    func configure(with _: AudioEngineConfiguration) async throws {
        configureCount += 1
    }

    func prepareNext(url _: URL) async {}

    func crossfade(to _: URL, duration _: TimeInterval, playbackRate _: Double, gainDB _: Float) async throws {}

    func getMetrics() async -> AudioMetrics {
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
}
