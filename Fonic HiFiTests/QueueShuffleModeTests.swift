@testable import Fonic_HiFi
import Foundation
import XCTest

final class QueueShuffleModeTests: XCTestCase {
    func testDescriptionsAndSymbols() {
        XCTAssertEqual(QueueShuffleMode.off.description, "No Shuffle")
        XCTAssertEqual(QueueShuffleMode.random.shortDescription, "Random")
        XCTAssertEqual(QueueShuffleMode.smart.symbolName, "shuffle.circle.fill")
        XCTAssertFalse(QueueShuffleMode.off.isActive)
        XCTAssertTrue(QueueShuffleMode.smart.requiresSmartLogic)
        XCTAssertEqual(QueueShuffleMode.off.next, .random)
        XCTAssertEqual(QueueShuffleMode.smart.previous, .random)
    }

    func testShuffleSequenceOffReturnsOrdered() {
        let sequence = QueueShuffleMode.off.generateShuffleSequence(trackCount: 4, tracks: [TestTrack]())
        XCTAssertEqual(sequence, [0, 1, 2, 3])
    }

    func testRandomShuffleKeepsCurrentTrackFirst() {
        let sequence = QueueShuffleMode.random.generateShuffleSequence(trackCount: 5, currentIndex: 3, tracks: [TestTrack]())
        XCTAssertEqual(sequence.first, 3)
        XCTAssertEqual(sequence.sorted(), [0, 1, 2, 3, 4])
    }

    func testSmartShuffleAvoidsImmediateArtistRepetition() {
        let tracks = makeTracks([
            ("A", "Artist 1", "Album 1"),
            ("B", "Artist 1", "Album 1"),
            ("C", "Artist 2", "Album 2"),
        ])

        let sequence = QueueShuffleMode.smart.generateShuffleSequence(
            trackCount: tracks.count,
            currentIndex: 0,
            tracks: tracks
        )

        XCTAssertEqual(sequence.count, tracks.count)
        XCTAssertEqual(sequence.first, 0)
        XCTAssertEqual(Set(sequence), Set(0 ..< tracks.count))
        XCTAssertNotEqual(sequence.dropFirst().first, 1, "Smart shuffle should avoid repeating the same artist when alternatives exist")
    }

    func testNextIndexWrapsWithRepeatAll() {
        let sequence = [2, 0, 1]
        let next = QueueShuffleMode.random.nextIndex(
            currentIndex: 1,
            shuffleSequence: sequence,
            repeatMode: .all
        )

        XCTAssertEqual(next, 2)

        let noRepeat = QueueShuffleMode.random.nextIndex(
            currentIndex: 1,
            shuffleSequence: sequence,
            repeatMode: .none
        )

        XCTAssertNil(noRepeat)

        let endWrapped = QueueShuffleMode.random.nextIndex(
            currentIndex: 1,
            shuffleSequence: [1],
            repeatMode: .all
        )

        XCTAssertEqual(endWrapped, 1)
    }

    func testPreviousIndexHandlesRepeatModes() {
        let sequence = [0, 2, 1]
        let previous = QueueShuffleMode.random.previousIndex(
            currentIndex: 1,
            shuffleSequence: sequence,
            repeatMode: .none
        )

        XCTAssertEqual(previous, 2)

        let wrapped = QueueShuffleMode.random.previousIndex(
            currentIndex: 0,
            shuffleSequence: sequence,
            repeatMode: .all
        )

        XCTAssertEqual(wrapped, 1)
    }

    func testCodableRoundTrip() throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(QueueShuffleMode.smart)

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(QueueShuffleMode.self, from: data)

        XCTAssertEqual(decoded, .smart)
    }
}

// MARK: - Helpers

private func makeTracks(_ entries: [(title: String, artist: String, album: String)]) -> [TestTrack] {
    entries.enumerated().map { index, entry in
        TestTrack(
            id: UUID(uuidString: "00000000-0000-0000-0000-0000000000\(index + 1)") ?? UUID(),
            title: entry.title,
            artist: entry.artist,
            album: entry.album,
            url: URL(fileURLWithPath: "/tmp/\(entry.title).flac"),
            duration: 240,
            audioFormat: "FLAC"
        )
    }
}

private struct TestTrack: TrackProtocol {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let url: URL
    let duration: TimeInterval
    let audioFormat: String
    var replayGainTrack: Float?
    var replayGainAlbum: Float?
}
