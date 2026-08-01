@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

@MainActor
final class ImportPlaybackIntegrationTests: XCTestCase {
    func testRealEncodedImportReachesPlayingThroughProductionFacade() async throws {
        let musicContainer = try makeTemporaryTestDirectory(
            named: "ImportPlaybackIntegrationTests",
            testCase: self
        )
        let formatDetector = AudioFormatDetectionManager()
        let metadataExtractor = MetadataExtractionService(
            formatDetectionService: formatDetector
        )
        let environment = try makeImportTestEnvironment(
            metadataExtractor: metadataExtractor,
            fileProcessingConcurrency: 1,
            musicContainerURL: musicContainer
        )
        let sourceURL = try makePCMTestAudioFile(
            duration: 2,
            sampleRate: 48_000,
            channels: 2,
            fileExtension: "wav",
            testCase: self
        )

        await environment.service.executeImportPipeline(urls: [sourceURL])

        XCTAssertEqual(environment.service.filesProcessed, 1)
        XCTAssertTrue(environment.service.importErrors.isEmpty)

        let importedTracks = try environment.container.mainContext.fetch(FetchDescriptor<Track>())
        let importedTrack = try XCTUnwrap(importedTracks.first)
        XCTAssertEqual(importedTracks.count, 1)
        XCTAssertNotEqual(importedTrack.url, sourceURL)
        XCTAssertTrue(FileManager.default.fileExists(atPath: importedTrack.url.path))
        XCTAssertEqual(importedTrack.audioFormat, AudioFormat.wav.rawValue)
        XCTAssertEqual(importedTrack.sampleRate, 48_000)
        XCTAssertEqual(importedTrack.channels, 2)
        XCTAssertEqual(importedTrack.duration, 2, accuracy: 0.05)

        let defaultsName = "ImportPlaybackIntegrationTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: defaultsName))
        defaults.removePersistentDomain(forName: defaultsName)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: defaultsName)
        }

        let queueManager = AudioQueueManager(queueStateSuiteName: defaultsName)
        let facade = AudioEngineFacade(
            engineFactory: AudioEngineFactory(preferences: defaults),
            queueManager: queueManager,
            playbackSettingsStore: AudioPlaybackSettingsStore(suiteName: defaultsName),
            runtimeMonitoringEnabled: false
        )

        do {
            try await facade.initialize()
            try await facade.play(track: importedTrack)

            XCTAssertEqual(queueManager.currentTrack?.id, importedTrack.id)
            XCTAssertEqual(facade.currentTrack?.id, importedTrack.id)
            XCTAssertTrue(facade.currentState.isPlaying)
        } catch {
            await facade.shutdown()
            throw error
        }

        await facade.shutdown()
    }

    func testImportPipelineFeedsQueueAndStartsPlayback() async throws {
        // Arrange: simulate high-volume import into an in-memory environment
        let environment = try makeImportTestEnvironment(
            metadataExtractor: SlowMetadataExtractor(delay: 0.0005),
            fileProcessingConcurrency: 3
        )

        let scenario = try makeNestedAudioDirectory(
            fileCountPerFolder: 4,
            depth: 2,
            branchingFactor: 2,
            duplicateCount: 0,
            testCase: self
        )

        await environment.service.executeImportPipeline(urls: [scenario.root])

        XCTAssertEqual(environment.service.totalFiles, scenario.totalFiles)
        XCTAssertEqual(environment.service.filesProcessed, scenario.totalFiles)
        XCTAssertTrue(environment.service.importErrors.isEmpty)

        // Fetch imported tracks from SwiftData container
        let context = environment.container.mainContext
        var descriptor = FetchDescriptor<Track>(sortBy: [SortDescriptor(\Track.title)])
        descriptor.fetchLimit = scenario.totalFiles
        let importedTracks = try context.fetch(descriptor)

        XCTAssertEqual(importedTracks.count, scenario.totalFiles)

        // Prepare playback pipeline components (queue + state manager + stub engine)
        let queueManager = AudioQueueManager()
        let stateManager = PlaybackStateManager()
        let engine = TestAudioEngineService()
        let pipeline = TestPlaybackPipeline(
            queueManager: queueManager,
            stateManager: stateManager,
            engine: engine
        )

        pipeline.enqueue(importedTracks)

        XCTAssertEqual(queueManager.tracks.count, scenario.totalFiles)
        XCTAssertNil(queueManager.currentTrack)

        try await pipeline.startPlaybackFromBeginning()

        // Assert: queue selects the first track, engine loads & plays, state transitions to playing
        guard let current = queueManager.currentTrack else {
            return XCTFail("Expected queue to have a current track after playback starts")
        }

        XCTAssertEqual(current.url, importedTracks.first?.url)
        XCTAssertTrue(stateManager.currentState.isPlaying)
        XCTAssertEqual(engine.loadedURLs, [current.url])
        XCTAssertEqual(engine.playInvocations, 1)
        XCTAssertEqual(pipeline.playedTrackIDs, [current.id])
    }
}

// MARK: - Test Support Types

@MainActor
private final class TestPlaybackPipeline {
    private enum PipelineError: Error {
        case emptyQueue
    }

    private let queueManager: AudioQueueManager
    private let stateManager: PlaybackStateManager
    private let engine: TestAudioEngineService
    private var trackMap: [UUID: Track] = [:]

    private(set) var playedTrackIDs: [UUID] = []

    init(queueManager: AudioQueueManager, stateManager: PlaybackStateManager, engine: TestAudioEngineService) {
        self.queueManager = queueManager
        self.stateManager = stateManager
        self.engine = engine
    }

    func enqueue(_ tracks: [Track]) {
        guard !tracks.isEmpty else { return }
        let audioTracks = tracks.map { track -> AudioTrack in
            let legacy = track.toAudioTrack()
            trackMap[legacy.id] = track
            return legacy
        }

        queueManager.enqueue(tracks: audioTracks)
    }

    func startPlaybackFromBeginning() async throws {
        if queueManager.currentTrack == nil, let first = queueManager.tracks.first {
            queueManager.setCurrentTrack(first)
        }

        guard let current = queueManager.currentTrack else {
            throw PipelineError.emptyQueue
        }

        stateManager.updateState(.loading())
        try await engine.load(url: current.url)
        try await engine.play()

        let duration = trackMap[current.id]?.duration ?? current.duration
        stateManager.updateState(.playing(currentTime: 0, duration: duration))

        playedTrackIDs.append(current.id)
    }
}

@MainActor
private final class TestAudioEngineService: AudioEngineService {
    private(set) var loadedURLs: [URL] = []
    private(set) var playInvocations: Int = 0

    var currentTime: TimeInterval { get async { 0 } }
    var duration: TimeInterval { get async { 0 } }
    var isPlaying: Bool { get async { playInvocations > 0 } }
    var volume: Float { get async { 1.0 } }
    var audioFormat: AudioFormat? { get async { .flac } }

    func load(url: URL) async throws {
        loadedURLs.append(url)
    }

    func play() async throws {
        playInvocations += 1
    }

    func pause() async {}

    func stop() async {}

    func seek(to _: TimeInterval) async throws {}

    func setVolume(_: Float) async {}

    func setPlaybackRate(_: Double) async {}

    func applyReplayGain(_: Float) async {}

    func configure(with _: AudioEngineConfiguration) async throws {}

    func prepareNext(url _: URL) async {}

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
            renderLatency: 0
        )
    }

    func collectMetrics() async {}
}
