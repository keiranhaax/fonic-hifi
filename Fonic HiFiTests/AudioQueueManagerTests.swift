@testable import Fonic_HiFi
import Foundation
import XCTest

@MainActor
final class AudioQueueManagerTests: XCTestCase {
    private let metricsDefaultsKey = "com.fonichifi.metrics.enabled"

    override func tearDown() {
        Metrics.setSinkForTesting(nil)
        Metrics.enable(false)
        UserDefaults.standard.removeObject(forKey: metricsDefaultsKey)
        super.tearDown()
    }

    func testConvenienceEnqueueAndLookupHelpers() {
        let queue = AudioQueueManager()
        let trackA = makeTrack(title: "Alpha")
        let trackB = makeTrack(title: "Bravo")

        XCTAssertTrue(queue.isEmpty)

        queue.enqueue(track: trackA)

        XCTAssertEqual(queue.count, 1)
        XCTAssertEqual(queue.track(at: 0)?.id, trackA.id)

        XCTAssertTrue(queue.setCurrentIndex(0))
        queue.enqueueNext(track: trackB)

        XCTAssertEqual(queue.tracks.count, 2)
        XCTAssertEqual(queue.index(of: trackB), 1)
        XCTAssertTrue(queue.hasNext)
        XCTAssertFalse(queue.hasPrevious)
    }

    func testQueueMutationsEmitMetricsMetadata() async {
        let recorder = QueueMetricsRecorder()
        Metrics.enable(true)
        Metrics.setSinkForTesting { counter, amount, _, metadata in
            guard counter == .queueMutation else { return }
            Task {
                await recorder.record(counter: counter, amount: amount, metadata: metadata)
            }
        }

        let queue = AudioQueueManager()
        let trackA = makeTrack(title: "Alpha")
        let longTitle = String(repeating: "Z", count: 60)
        let trackB = makeTrack(title: longTitle)

        queue.enqueue(tracks: [trackA, trackB])
        var events = await recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        if let event = events.first {
            XCTAssertEqual(event.counter, .queueMutation)
            XCTAssertEqual(event.amount, 1)
            XCTAssertEqual(event.metadata["action"], "enqueue")
            XCTAssertEqual(event.metadata["delta"], "2")
            XCTAssertEqual(event.metadata["size"], "2")
        }

        XCTAssertTrue(queue.setCurrentIndex(0))
        _ = queue.next()
        events = await recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        if let event = events.first {
            XCTAssertEqual(event.metadata["action"], "next")
            XCTAssertEqual(event.metadata["size"], "2")
            if let track = event.metadata["track"] {
                XCTAssertTrue(track.hasSuffix("…"))
                XCTAssertLessThanOrEqual(track.count, 41)
            } else {
                XCTFail("Expected track metadata for next action")
            }
        }

        XCTAssertNotNil(queue.remove(at: 1))
        events = await recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        if let event = events.first {
            XCTAssertEqual(event.metadata["action"], "remove")
            XCTAssertEqual(event.metadata["index"], "1")
            XCTAssertEqual(event.metadata["size"], "1")
            if let track = event.metadata["track"] {
                XCTAssertTrue(track.hasSuffix("…"))
                XCTAssertLessThanOrEqual(track.count, 41)
            } else {
                XCTFail("Expected truncated track metadata")
            }
        }

        queue.clear()
        events = await recorder.takeEvents()
        XCTAssertEqual(events.count, 1)
        if let event = events.first {
            XCTAssertEqual(event.metadata["action"], "clear")
            XCTAssertEqual(event.metadata["size"], "0")
        }
    }

    func testNextAdvancesHistoryAndRepeatsAll() {
        let queue = AudioQueueManager()
        let tracks = [makeTrack(title: "One"), makeTrack(title: "Two"), makeTrack(title: "Three")]

        queue.enqueue(tracks: tracks)
        XCTAssertTrue(queue.setCurrentIndex(0))
        queue.repeatMode = .all

        // First advance should move to track index 1 and record history
        let firstAdvance = queue.next()
        XCTAssertEqual(firstAdvance?.id, tracks[1].id)
        XCTAssertEqual(queue.history.map(\._id), [tracks[0].id])
        XCTAssertTrue(queue.hasPrevious)

        // Advance to last element then wrap due to repeat-all
        let secondAdvance = queue.next()
        XCTAssertEqual(secondAdvance?.id, tracks[2].id)
        XCTAssertEqual(queue.history.map(\._id), [tracks[1].id, tracks[0].id])

        let wrappedAdvance = queue.next()
        XCTAssertEqual(wrappedAdvance?.id, tracks[0].id)
        XCTAssertEqual(queue.history.map(\._id), [tracks[2].id, tracks[1].id, tracks[0].id])
    }

    func testShuffleAndRestoreOrderPreservesCurrentTrack() {
        let queue = AudioQueueManager()
        let tracks = [makeTrack(title: "A"), makeTrack(title: "B"), makeTrack(title: "C"), makeTrack(title: "D")]

        queue.enqueue(tracks: tracks)
        XCTAssertTrue(queue.setCurrentIndex(1))

        // Enabling shuffle should notify and produce a sequence
        queue.shuffleMode = .random
        queue.shuffle()
        XCTAssertTrue(queue.shuffleMode.isActive)
        XCTAssertEqual(queue.queueState.shuffleSequence?.count, tracks.count)

        queue.restoreOrder()

        XCTAssertEqual(queue.tracks.map(\._id), tracks.map(\._id))
        let restoredIDs = queue.tracks.map(\._id)
        XCTAssertEqual(
            queue.currentIndex,
            1,
            "currentIndex=\(String(describing: queue.currentIndex)); restored=\(restoredIDs) expected=\(tracks.map(\._id))",
        )
        XCTAssertEqual(
            queue.currentTrack?.id,
            tracks[1].id,
            "currentIndex=\(String(describing: queue.currentIndex)); restored=\(restoredIDs)",
        )
        XCTAssertFalse(queue.shuffleMode.isActive)
        XCTAssertNil(queue.queueState.shuffleSequence)
    }

    func testDelegateReceivesNotificationsForQueueMutations() {
        let delegate = QueueDelegateSpy()
        let queue = AudioQueueManager(delegate: delegate)
        let trackA = makeTrack(title: "First")
        let trackB = makeTrack(title: "Second")

        queue.enqueue(tracks: [trackA, trackB])
        XCTAssertEqual(delegate.updatedTracksCount, 1)

        XCTAssertTrue(queue.setCurrentIndex(0))
        XCTAssertEqual(delegate.currentTrackChanges.count, 1)

        queue.shuffleMode = .smart
        XCTAssertEqual(delegate.shuffleModeChanges, [.smart])

        queue.repeatMode = .all
        XCTAssertEqual(delegate.repeatModeChanges, [.all])

        _ = queue.next()
        XCTAssertEqual(delegate.historyAdditions.map(\._id), [trackA.id])

        _ = queue.remove(track: trackB)
        XCTAssertEqual(delegate.updatedTracksCount, 2)

        queue.clear()
        XCTAssertEqual(delegate.updatedTracksCount, 3)
        XCTAssertNil((delegate.currentTrackChanges.last ?? nil)?.id)

        // Switch to passive delegate to execute default extension methods
        let passiveDelegate = PassiveQueueDelegate()
        queue.delegate = passiveDelegate
        queue.enqueue(tracks: [trackA])
        queue.shuffleMode = .random
        queue.repeatMode = .one
        XCTAssertTrue(queue.setCurrentIndex(0))
        _ = queue.next()
    }

    func testPreviousReturnsNilWhenAtBeginningWithoutRepeat() {
        let queue = AudioQueueManager()
        let tracks = [makeTrack(title: "Solo")]
        queue.enqueue(tracks: tracks)
        XCTAssertTrue(queue.setCurrentIndex(0))

        queue.repeatMode = .none
        XCTAssertNil(queue.previous())
    }

    func testEnqueueLaterAppendsAfterCurrentQueue() {
        let queue = AudioQueueManager()
        let trackA = makeTrack(title: "Alpha")
        let trackB = makeTrack(title: "Bravo")

        queue.enqueue(tracks: [trackA])
        queue.enqueueLater(tracks: [trackB])

        XCTAssertEqual(queue.tracks.map(\._id), [trackA.id, trackB.id])
    }

    func testMoveReordersTracksAndAdjustsCurrentIndex() {
        let queue = AudioQueueManager()
        let tracks = ["One", "Two", "Three"].map { makeTrack(title: $0) }
        queue.enqueue(tracks: tracks)
        XCTAssertTrue(queue.setCurrentIndex(2))

        queue.move(from: 2, to: 0)

        XCTAssertEqual(queue.tracks.map(\._id), [tracks[2].id, tracks[0].id, tracks[1].id])
        XCTAssertEqual(queue.currentIndex, 0)
    }

    func testClearHistoryRemovesRecordedTracks() {
        let queue = AudioQueueManager()
        let tracks = [makeTrack(title: "Intro"), makeTrack(title: "Outro")]
        queue.enqueue(tracks: tracks)
        XCTAssertTrue(queue.setCurrentIndex(0))

        _ = queue.next()
        XCTAssertFalse(queue.history.isEmpty)

        queue.clearHistory()
        XCTAssertTrue(queue.history.isEmpty)
    }

    func testReplaceQueueResetsTracksAndCurrentIndex() {
        let queue = AudioQueueManager()
        let original = [makeTrack(title: "A"), makeTrack(title: "B")]
        queue.enqueue(tracks: original)
        XCTAssertTrue(queue.setCurrentIndex(0))

        let replacement = [makeTrack(title: "NewA"), makeTrack(title: "NewB"), makeTrack(title: "NewC")]
        queue.replaceQueue(with: replacement, startIndex: 1)

        XCTAssertEqual(queue.tracks.map(\._id), replacement.map(\._id))
        XCTAssertEqual(queue.currentIndex, 1)
    }

    func testGetNextAndPreviousTrackHelpers() {
        let queue = AudioQueueManager()
        let tracks = [makeTrack(title: "Blue"), makeTrack(title: "Green"), makeTrack(title: "Red")]
        queue.enqueue(tracks: tracks)

        XCTAssertTrue(queue.setCurrentIndex(1))
        XCTAssertEqual(queue.getNextTrack()?.id, tracks[2].id)

        XCTAssertTrue(queue.setCurrentIndex(2))
        XCTAssertEqual(queue.getPreviousTrack()?.id, tracks[1].id)

        queue.repeatMode = .all
        XCTAssertTrue(queue.setCurrentIndex(tracks.count - 1))
        XCTAssertEqual(queue.getNextTrack()?.id, tracks.first?.id)
    }

    func testMoveToNextAndPreviousRespectAvailability() {
        let queue = AudioQueueManager()
        let tracks = [makeTrack(title: "First"), makeTrack(title: "Second")]
        queue.enqueue(tracks: tracks)

        XCTAssertTrue(queue.setCurrentIndex(0))
        XCTAssertTrue(queue.moveToNext())
        XCTAssertEqual(queue.currentIndex, 1)

        XCTAssertFalse(queue.moveToNext())
        XCTAssertTrue(queue.moveToPrevious())
        XCTAssertEqual(queue.currentIndex, 0)

        queue.repeatMode = .none
        XCTAssertFalse(queue.moveToPrevious())
    }

    func testSaveRestoreAndClearState() {
        let queue = AudioQueueManager()
        let tracks = [
            makeTrack(title: "Keep", createFile: true),
            makeTrack(title: "Rotate", createFile: true),
        ]
        queue.enqueue(tracks: tracks)
        XCTAssertTrue(queue.setCurrentIndex(1))

        queue.saveState()

        let restored = AudioQueueManager()
        XCTAssertTrue(restored.restoreState())
        XCTAssertEqual(restored.tracks.map(\._id), tracks.map(\._id))
        XCTAssertEqual(restored.currentIndex, 1)

        restored.clearSavedState()

        let empty = AudioQueueManager()
        XCTAssertFalse(empty.restoreState())
    }

    func testDebugInfoAndValidateState() {
        let queue = AudioQueueManager()
        let tracks = [makeTrack(title: "Live"), makeTrack(title: "Archive")]
        queue.enqueue(tracks: tracks)
        XCTAssertTrue(queue.setCurrentIndex(0))

        let debugText = queue.debugInfo
        XCTAssertTrue(debugText.contains("Tracks:"))

        let issues = queue.validateState()
        XCTAssertTrue(issues.isEmpty)
    }
}

// MARK: - Helpers

private actor QueueMetricsRecorder {
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
private func makeTrack(
    title: String,
    artist: String = "Artist",
    album: String = "Album",
    createFile: Bool = false
) -> AudioTrack {
    let directory = URL(fileURLWithPath: NSTemporaryDirectory())
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileURL = directory.appendingPathComponent("\(title).flac")

    if createFile {
        try? FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        FileManager.default.createFile(
            atPath: fileURL.path,
            contents: Data(title.utf8),
            attributes: nil
        )
    }

    return AudioTrack(
        title: title,
        artist: artist,
        album: album,
        url: fileURL,
        duration: 180,
        audioFormat: "FLAC"
    )
}

@MainActor
private final class QueueDelegateSpy: AudioQueueDelegate {
    private(set) var updatedTracksCount = 0
    private(set) var currentTrackChanges: [AudioTrack?] = []
    private(set) var shuffleModeChanges: [QueueShuffleMode] = []
    private(set) var repeatModeChanges: [QueueRepeatMode] = []
    private(set) var historyAdditions: [AudioTrack] = []

    func audioQueue(_ queue: AudioQueue, didUpdateTracks tracks: [AudioTrack]) {
        updatedTracksCount += 1
        XCTAssertEqual(queue.tracks.count, tracks.count)
    }

    func audioQueue(_ queue: AudioQueue, didChangeCurrentTrack track: AudioTrack?, at index: Int?) {
        XCTAssertEqual(queue.currentIndex, index)
        currentTrackChanges.append(track)
    }

    func audioQueue(_ queue: AudioQueue, didChangeShuffleMode shuffleMode: QueueShuffleMode) {
        XCTAssertTrue(queue.shuffleMode == shuffleMode)
        shuffleModeChanges.append(shuffleMode)
    }

    func audioQueue(_ queue: AudioQueue, didChangeRepeatMode repeatMode: QueueRepeatMode) {
        XCTAssertTrue(queue.repeatMode == repeatMode)
        repeatModeChanges.append(repeatMode)
    }

    func audioQueue(_ queue: AudioQueue, didAddToHistory track: AudioTrack) {
        XCTAssertFalse(queue.history.isEmpty)
        historyAdditions.append(track)
    }
}

@MainActor
private final class PassiveQueueDelegate: AudioQueueDelegate {
    func audioQueue(_: AudioQueue, didUpdateTracks _: [AudioTrack]) {}
}

private extension AudioTrack {
    var _id: UUID { id }
}
