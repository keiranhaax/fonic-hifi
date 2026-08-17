import Combine
@testable import Fonic_HiFi
import Foundation
import XCTest

@MainActor
final class AudioQueueStatePublisherTests: XCTestCase {
    func testCompoundMutationsEmitOneFinalSnapshot() {
        let queue = AudioQueueManager()
        let recorder = QueueStateRecorder(queue.queueStatePublisher)
        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")
        let third = makeTrack(title: "Third")

        XCTAssertTrue(queue.setCurrentTrack(first))

        var events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.map(\.id), [first.id])
        XCTAssertEqual(events.first?.currentTrack?.id, first.id)

        queue.enqueueNext(tracks: [second, third])

        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.map(\.id), [first.id, second.id, third.id])
        XCTAssertEqual(events.first?.currentTrack?.id, first.id)

        queue.shuffleMode = .random
        XCTAssertEqual(recorder.takeEvents().count, 1)
        let shuffledCurrentTrackID = queue.currentTrack?.id

        queue.restoreOrder()

        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.map(\.id), [first.id, second.id, third.id])
        XCTAssertEqual(events.first?.currentTrack?.id, shuffledCurrentTrackID)
        XCTAssertEqual(events.first?.shuffleMode, .off)
    }

    func testCollectionMutationFamiliesEachEmitOneFinalSnapshot() {
        let queue = AudioQueueManager()
        let recorder = QueueStateRecorder(queue.queueStatePublisher)
        let tracks = ["A", "B", "C", "D", "E", "F"].map { makeTrack(title: $0) }

        queue.enqueue(tracks: Array(tracks[0 ... 2]))
        XCTAssertEqual(recorder.takeEvents().count, 1)

        queue.enqueueLater(tracks: [tracks[3]])
        XCTAssertEqual(recorder.takeEvents().count, 1)

        XCTAssertTrue(queue.setCurrentIndex(0))
        XCTAssertEqual(recorder.takeEvents().count, 1)

        queue.insert(tracks: [tracks[4]], at: queue.tracks.count)
        XCTAssertEqual(recorder.takeEvents().count, 1)

        queue.move(from: 4, to: 1)
        var events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.map(\.id), [tracks[0].id, tracks[4].id, tracks[1].id, tracks[2].id, tracks[3].id])

        XCTAssertNotNil(queue.remove(at: 1))
        XCTAssertEqual(recorder.takeEvents().count, 1)

        XCTAssertTrue(queue.remove(track: tracks[3]))
        XCTAssertEqual(recorder.takeEvents().count, 1)

        queue.enqueue(tracks: [tracks[3], tracks[4], tracks[5]])
        XCTAssertEqual(recorder.takeEvents().count, 1)

        queue.removeRemaining(at: IndexSet(integer: 1))
        XCTAssertEqual(recorder.takeEvents().count, 1)

        queue.moveRemaining(fromOffsets: IndexSet(integer: 0), toOffset: queue.tracks.count - 1)
        XCTAssertEqual(recorder.takeEvents().count, 1)

        let replacement = [tracks[5], tracks[0]]
        queue.replaceQueue(with: replacement, startIndex: 1)
        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.map(\.id), replacement.map(\.id))
        XCTAssertEqual(events.first?.currentIndex, 1)

        queue.clear()
        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events.first?.isEmpty == true)
        XCTAssertNil(events.first?.currentIndex)
    }

    func testSameCountReorderAndModeChangesAreNotLost() {
        let queue = AudioQueueManager()
        let recorder = QueueStateRecorder(queue.queueStatePublisher)
        let tracks = ["A", "B", "C"].map { makeTrack(title: $0) }
        queue.enqueue(tracks: tracks)
        _ = recorder.takeEvents()

        let updatedFirstTrack = AudioTrack(
            id: tracks[0].id,
            title: "A updated",
            artist: tracks[0].artist,
            album: tracks[0].album,
            url: tracks[0].url,
            duration: tracks[0].duration,
            audioFormat: tracks[0].audioFormat
        )
        queue.replaceQueue(with: [updatedFirstTrack, tracks[1], tracks[2]], startIndex: nil)

        var events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.first?.title, "A updated")

        queue.move(from: 0, to: 2)

        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.map(\.id), [tracks[1].id, tracks[2].id, tracks[0].id])

        queue.repeatMode = .all

        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.count, tracks.count)
        XCTAssertEqual(events.first?.repeatMode, .all)

        queue.shuffleMode = .random

        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.count, tracks.count)
        XCTAssertEqual(events.first?.shuffleMode, .random)

        queue.shuffleMode = .smart

        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.count, tracks.count)
        XCTAssertEqual(events.first?.shuffleMode, .smart)
    }

    func testSelectionNavigationAndHistoryMutationsEmitFinalState() {
        let queue = AudioQueueManager()
        let recorder = QueueStateRecorder(queue.queueStatePublisher)
        let tracks = ["A", "B", "C"].map { makeTrack(title: $0) }
        queue.enqueue(tracks: tracks)
        XCTAssertTrue(queue.setCurrentIndex(0))
        _ = recorder.takeEvents()

        XCTAssertEqual(queue.next()?.id, tracks[1].id)

        var events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.currentTrack?.id, tracks[1].id)
        XCTAssertEqual(events.first?.history.map(\.id), [tracks[0].id])

        XCTAssertEqual(queue.previous()?.id, tracks[0].id)
        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.currentTrack?.id, tracks[0].id)

        queue.repeatMode = .one
        _ = recorder.takeEvents()

        XCTAssertEqual(queue.nextManually()?.id, tracks[1].id)
        XCTAssertEqual(recorder.takeEvents().count, 1)

        XCTAssertEqual(queue.previousManually()?.id, tracks[0].id)
        XCTAssertEqual(recorder.takeEvents().count, 1)

        XCTAssertTrue(queue.setCurrentTrack(tracks[2]))
        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.currentTrack?.id, tracks[2].id)

        XCTAssertTrue(queue.setCurrentTrack(nil))
        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertNil(events.first?.currentTrack)

        queue.clearHistory()
        events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertTrue(events.first?.history.isEmpty == true)
    }

    func testRestoreStateEmitsOneFinalSnapshot() async throws {
        let suiteName = "AudioQueueStatePublisherTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let source = AudioQueueManager(queueStateSuiteName: suiteName)
        await source.clearSavedState()

        let firstURL = try makePCMTestAudioFile(testCase: self)
        let secondURL = try makePCMTestAudioFile(testCase: self)
        let tracks = [
            makeTrack(title: "Persisted A", url: firstURL),
            makeTrack(title: "Persisted B", url: secondURL),
        ]
        source.enqueue(tracks: tracks)
        XCTAssertTrue(source.setCurrentIndex(1))
        source.repeatMode = .all
        source.shuffleMode = .random
        await source.saveState()

        let restored = AudioQueueManager(queueStateSuiteName: suiteName)
        let recorder = QueueStateRecorder(restored.queueStatePublisher)

        let didRestore = await restored.restoreState()
        XCTAssertTrue(didRestore)

        let events = recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events.first?.tracks.map(\.id), source.tracks.map(\.id))
        XCTAssertEqual(events.first?.currentTrack?.id, source.currentTrack?.id)
        XCTAssertEqual(events.first?.repeatMode, .all)
        XCTAssertEqual(events.first?.shuffleMode, .random)
    }

    func testEachLogicalMutationRequestsOnePersistenceSnapshot() {
        let persister = RecordingQueueStatePersister()
        let queue = AudioQueueManager(queueStatePersister: persister)
        let first = makeTrack(title: "First")
        let second = makeTrack(title: "Second")
        let next = makeTrack(title: "Next")

        queue.enqueue(tracks: [first, second])
        XCTAssertEqual(persister.takeRequestedStates().count, 1)

        XCTAssertTrue(queue.setCurrentIndex(0))
        XCTAssertEqual(persister.takeRequestedStates().count, 1)

        queue.enqueueNext(tracks: [next])
        XCTAssertEqual(persister.takeRequestedStates().count, 1)

        queue.shuffleMode = .random
        XCTAssertEqual(persister.takeRequestedStates().count, 1)

        queue.restoreOrder()
        let states = persister.takeRequestedStates()
        XCTAssertEqual(states.count, 1)
        XCTAssertEqual(states.first?.tracks.map(\.id), [first.id, second.id, next.id])
        XCTAssertEqual(states.first?.shuffleMode, .off)
    }

    func testNoOpsAndCancelledSubscriptionDoNotDeliver() {
        let queue = AudioQueueManager()
        let recorder = QueueStateRecorder(queue.queueStatePublisher)

        queue.enqueue(tracks: [])
        queue.enqueueNext(tracks: [])
        queue.insert(tracks: [], at: 0)
        XCTAssertNil(queue.remove(at: 0))
        XCTAssertFalse(queue.remove(track: makeTrack(title: "Missing")))
        queue.removeRemaining(at: IndexSet(integer: 0))
        queue.move(from: 0, to: 0)
        queue.moveRemaining(fromOffsets: IndexSet(integer: 0), toOffset: 0)
        XCTAssertTrue(queue.setCurrentIndex(nil))
        queue.repeatMode = .none
        queue.shuffleMode = .off
        queue.shuffleMode = .off
        queue.restoreOrder()
        queue.clearHistory()
        queue.clear()

        XCTAssertTrue(recorder.takeEvents().isEmpty)

        recorder.cancel()
        queue.enqueue(track: makeTrack(title: "After cancellation"))

        XCTAssertTrue(recorder.takeEvents().isEmpty)
    }
}

@MainActor
private final class RecordingQueueStatePersister: QueueStatePersisting {
    private var requestedStates: [QueueState] = []

    func requestSave(_ state: QueueState) {
        requestedStates.append(state)
    }

    func save(_ state: QueueState) async {
        requestedStates.append(state)
    }

    func load() async -> QueueState? {
        nil
    }

    func clear() async {
        requestedStates.removeAll()
    }

    func flush() async {}

    func takeRequestedStates() -> [QueueState] {
        let states = requestedStates
        requestedStates.removeAll()
        return states
    }
}

private final class QueueStateRecorder {
    private var events: [QueueState] = []
    private var cancellable: AnyCancellable?

    init(_ publisher: AnyPublisher<QueueState, Never>) {
        cancellable = publisher.sink { [weak self] state in
            self?.events.append(state)
        }
    }

    func takeEvents() -> [QueueState] {
        let snapshot = events
        events.removeAll()
        return snapshot
    }

    func cancel() {
        cancellable?.cancel()
        cancellable = nil
    }
}

@MainActor
private func makeTrack(title: String, url: URL? = nil) -> AudioTrack {
    let fileURL = url ?? FileManager.default.temporaryDirectory
        .appendingPathComponent("\(UUID().uuidString).flac")

    return AudioTrack(
        title: title,
        artist: "Artist",
        album: "Album",
        url: fileURL,
        duration: 180,
        audioFormat: "FLAC"
    )
}
