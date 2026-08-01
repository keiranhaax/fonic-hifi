import Combine
import Foundation
import Testing

@testable import Fonic_HiFi

@Suite("AudioEngineManager Coverage Additions")
struct AudioEngineManagerCoverageAdditionsTests {
    @Test("cleanupCurrentEngine stops active engine and detaches monitor")
    @MainActor
    func cleanupStopsAndDetaches() async throws {
        let monitor = EngineManagerMonitorStub()
        let factory = EngineManagerFactoryStub()
        let manager = AudioEngineManager(
            configuration: .default,
            engineFactory: factory,
            monitor: monitor
        )

        let info = makeInfo(format: .flac)
        let created = try await manager.ensureEngine(for: info)
        let engine = try #require(created as? EngineManagerEngineStub)
        engine.isPlayingValue = true

        await manager.cleanupCurrentEngine()

        #expect(engine.stopCallCount == 1)
        #expect(monitor.detachCount >= 1)
        #expect(manager.currentEngine == nil)
        #expect(manager.currentEngineType == nil)
        #expect(manager.currentFormat == nil)
    }

    @Test("pending engine switch recreates engine on next ensure call")
    @MainActor
    func pendingSwitchRecreatesEngine() async throws {
        let monitor = EngineManagerMonitorStub()
        let factory = EngineManagerFactoryStub()
        let manager = AudioEngineManager(
            configuration: .default,
            engineFactory: factory,
            monitor: monitor
        )

        let info = makeInfo(format: .flac)
        let first = try await manager.ensureEngine(for: info)
        let firstEngine = try #require(first as? EngineManagerEngineStub)
        firstEngine.isPlayingValue = true

        manager.setPendingEngineSwitch()
        let second = try await manager.ensureEngine(for: info)
        let secondEngine = try #require(second as? EngineManagerEngineStub)

        #expect(firstEngine !== secondEngine)
        #expect(firstEngine.stopCallCount == 1)
        #expect(monitor.attachCount >= 2)
        #expect(monitor.detachCount >= 1)
    }

    @Test("updateConfiguration forwards config to active engine")
    @MainActor
    func updateConfigurationForwardsToActiveEngine() async throws {
        let monitor = EngineManagerMonitorStub()
        let factory = EngineManagerFactoryStub()
        let manager = AudioEngineManager(
            configuration: .default,
            engineFactory: factory,
            monitor: monitor
        )

        let info = makeInfo(format: .wav)
        let created = try await manager.ensureEngine(for: info)
        let engine = try #require(created as? EngineManagerEngineStub)

        let updated = AudioEngineConfiguration.default
            .with(crossfadeDuration: 2.0)
            .with(playbackRate: 1.4)

        await manager.updateConfiguration(updated)

        #expect(engine.configureCallCount >= 2)
        #expect(engine.lastConfiguration?.crossfadeDuration == 2.0)
        #expect(engine.lastConfiguration?.playbackRate == 1.4)
    }

    private func makeInfo(format: AudioFormat) -> AudioFileInfo {
        AudioFileInfo(
            url: URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(format.fileExtension),
            format: format,
            duration: 180,
            bitDepth: 16,
            sampleRate: 44_100,
            channels: 2,
            fileSize: 8_192
        )
    }
}

@MainActor
private final class EngineManagerMonitorStub: AudioPerformanceMonitoring {
    var metricsPublisher: AnyPublisher<AudioMetrics, Never> { Empty(completeImmediately: false).eraseToAnyPublisher() }
    private(set) var attachCount = 0
    private(set) var detachCount = 0
    var current: AudioEngineService?

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

    func attachToEngine(_ engine: AudioEngineService) async {
        attachCount += 1
        current = engine
    }

    func detachFromEngine() async {
        detachCount += 1
        current = nil
    }

    var currentEngine: AudioEngineService? { get async { current } }

    func startProfiling(duration _: TimeInterval?) async {}
    func stopProfiling() async {}
    func getProfilingResults() async -> PerformanceProfile? { nil }
    var isProfiling: Bool { get async { false } }
}

@MainActor
private final class EngineManagerFactoryStub: AudioEngineFactoring {
    private(set) var makeCalls = 0

    func selectEngineType(for format: AudioFormat, configuration _: AudioEngineConfiguration) -> AudioEngineType {
        switch format {
        case .flac:
            .audioKitEngine
        default:
            .avAudioEngine
        }
    }

    func makeEngine(for _: AudioFormat, configuration: AudioEngineConfiguration) async throws -> AudioEngineService {
        makeCalls += 1
        let engine = EngineManagerEngineStub()
        try await engine.configure(with: configuration)
        return engine
    }
}

@MainActor
private final class EngineManagerEngineStub: AudioEngineService {
    var currentTimeValue: TimeInterval = 0
    var durationValue: TimeInterval = 0
    var isPlayingValue = false
    var stopCallCount = 0
    var configureCallCount = 0
    var lastConfiguration: AudioEngineConfiguration?

    var currentTime: TimeInterval { get async { currentTimeValue } }
    var duration: TimeInterval { get async { durationValue } }
    var isPlaying: Bool { get async { isPlayingValue } }
    var volume: Float { get async { 1.0 } }
    var audioFormat: AudioFormat? { get async { .flac } }

    func load(url _: URL) async throws {}
    func play() async throws { isPlayingValue = true }
    func pause() async { isPlayingValue = false }
    func stop() async {
        stopCallCount += 1
        isPlayingValue = false
    }

    func seek(to _: TimeInterval) async throws {}
    func setVolume(_: Float) async {}
    func setPlaybackRate(_: Double) async {}
    func applyReplayGain(_: Float) async {}

    func configure(with configuration: AudioEngineConfiguration) async throws {
        configureCallCount += 1
        lastConfiguration = configuration
    }

    func prepareNext(url _: URL) async {}
    func crossfade(to _: URL, duration _: TimeInterval, playbackRate _: Double, gainDB _: Float) async throws {}
    var metricsAvailability: AudioMetricsAvailability { .available }
    func availableMetrics() async -> AudioMetrics? { .empty }
    func collectMetrics() async {}
}
