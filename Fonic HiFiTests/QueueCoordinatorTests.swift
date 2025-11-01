@testable import Fonic_HiFi
import XCTest

@MainActor
final class QueueCoordinatorTests: XCTestCase {
    func testPlayNextCrossfadesWhenEnabled() async throws {
        let queueManager = AudioQueueManager()
        let stateManager = PlaybackStateManager()
        stateManager.forceUpdateState(.playing(currentTime: 0, duration: 180))

        let coordination = makeCoordinator(
            queueManager: queueManager,
            stateManager: stateManager,
            crossfadeDuration: 1.5,
        )

        let tracks = makeQueue()
        queueManager.enqueue(tracks: tracks)
        _ = queueManager.setCurrentTrack(tracks[0])

        try await coordination.coordinator.playNext()

        XCTAssertEqual(coordination.playback.crossfadeCalls.count, 1)
        XCTAssertTrue(coordination.playback.playCalls.isEmpty)
        XCTAssertEqual(queueManager.currentTrack?.id, tracks[1].id)
    }

    func testPlayNextUsesPlayWhenCrossfadeDisabled() async throws {
        let queueManager = AudioQueueManager()
        let stateManager = PlaybackStateManager()
        stateManager.forceUpdateState(.playing(currentTime: 0, duration: 200))

        let coordination = makeCoordinator(
            queueManager: queueManager,
            stateManager: stateManager,
            crossfadeDuration: 0,
        )

        let tracks = makeQueue()
        queueManager.enqueue(tracks: tracks)
        _ = queueManager.setCurrentTrack(tracks[0])

        try await coordination.coordinator.playNext()

        XCTAssertEqual(coordination.playback.playCalls.count, 1)
        XCTAssertTrue(coordination.playback.crossfadeCalls.isEmpty)
    }

    func testPlayNextStopsWhenNoUpcomingTrack() async {
        let queueManager = AudioQueueManager()
        let stateManager = PlaybackStateManager()
        stateManager.forceUpdateState(.playing(currentTime: 0, duration: 120))

        let coordination = makeCoordinator(
            queueManager: queueManager,
            stateManager: stateManager,
            crossfadeDuration: 1,
        )

        try? await coordination.coordinator.playNext()

        XCTAssertEqual(coordination.playback.stopCalls, 1)
        XCTAssertTrue(coordination.playback.playCalls.isEmpty)
        XCTAssertTrue(coordination.playback.crossfadeCalls.isEmpty)
    }

    // MARK: - Helpers

    private func makeCoordinator(
        queueManager: AudioQueueManager,
        stateManager: PlaybackStateManager,
        crossfadeDuration: TimeInterval,
    ) -> (coordinator: QueueCoordinator, playback: MockPlaybackQueueHandler) {
        let playback = MockPlaybackQueueHandler()
        let factory = AudioEngineFactory()
        let monitor = AudioMonitor()
        let configuration = AudioEngineConfiguration.default.with(crossfadeDuration: crossfadeDuration)
        let engineManager = AudioEngineManager(
            configuration: configuration,
            engineFactory: factory,
            monitor: monitor,
        )

        let coordinator = QueueCoordinator(
            queueManager: queueManager,
            stateManager: stateManager,
            engineManager: engineManager,
            playbackController: playback,
        )

        return (coordinator, playback)
    }

    private func makeQueue() -> [AudioTrack] {
        let baseURL = URL(fileURLWithPath: NSTemporaryDirectory())
        let first = LegacyTrack(
            title: "First",
            artist: "Artist",
            album: "Album",
            url: baseURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("flac"),
            duration: 180,
            format: .flac,
        )
        let second = LegacyTrack(
            title: "Second",
            artist: "Artist",
            album: "Album",
            url: baseURL.appendingPathComponent(UUID().uuidString).appendingPathExtension("flac"),
            duration: 200,
            format: .flac,
        )
        return [first, second]
    }
}

// MARK: - Test Doubles

@MainActor
private final class MockPlaybackQueueHandler: PlaybackQueueHandling {
    struct PlayCall {
        let track: Track
        let queueEntry: AudioTrack?
    }

    struct CrossfadeCall {
        let audioTrack: AudioTrack
        let displayTrack: Track
    }

    private(set) var playCalls: [PlayCall] = []
    private(set) var crossfadeCalls: [CrossfadeCall] = []
    private(set) var stopCalls = 0

    func play(track: Track, queueEntry: AudioTrack?) async throws {
        playCalls.append(PlayCall(track: track, queueEntry: queueEntry))
    }

    func crossfade(to audioTrack: AudioTrack, displayTrack: Track) async throws {
        crossfadeCalls.append(CrossfadeCall(audioTrack: audioTrack, displayTrack: displayTrack))
    }

    func stop() async {
        stopCalls += 1
    }
}
