@testable import Fonic_HiFi
import XCTest

@MainActor
final class QueueStateTests: XCTestCase {
    func testComputedPropertiesForPopulatedQueue() {
        let tracks = makeTracks(titles: ["One", "Two", "Three"])
        let state = QueueState(
            tracks: tracks,
            currentIndex: 1,
            shuffleMode: .off,
            repeatMode: .none,
            hasNext: true,
            hasPrevious: true,
            history: [tracks[0]],
            shuffleSequence: nil
        )

        XCTAssertFalse(state.isEmpty)
        XCTAssertEqual(state.count, 3)
        XCTAssertEqual(state.currentTrack?.id, tracks[1].id)
        XCTAssertEqual(state.remainingTracks.map(\.id), [tracks[2].id])
        XCTAssertEqual(state.remainingCount, 1)
        XCTAssertGreaterThan(state.totalDuration, 0)
        XCTAssertGreaterThan(state.remainingDuration, 0)
        XCTAssertEqual(state.position, 2)
        XCTAssertEqual(state.progress, Double(1) / Double(3))
        XCTAssertEqual(state.track(at: 1)?.id, tracks[1].id)
        XCTAssertEqual(state.index(of: tracks[2]), 2)
    }

    func testShuffleAccessorsFollowSequence() {
        let tracks = makeTracks(titles: ["A", "B", "C"])
        let shuffleSequence = [2, 1, 0]
        let state = QueueState(
            tracks: tracks,
            currentIndex: 1,
            shuffleMode: .random,
            repeatMode: .none,
            hasNext: true,
            hasPrevious: true,
            history: [],
            shuffleSequence: shuffleSequence
        )

        XCTAssertEqual(
            state.shuffledTracks.map(\.id),
            shuffleSequence.compactMap { tracks[$0].id }
        )

        let expectedNextIndex = QueueShuffleMode.random.nextIndex(
            currentIndex: state.currentIndex,
            shuffleSequence: shuffleSequence,
            repeatMode: .none
        )
        XCTAssertEqual(
            state.nextTrack?.id,
            expectedNextIndex.flatMap { tracks[$0].id }
        )

        let expectedPreviousIndex = QueueShuffleMode.random.previousIndex(
            currentIndex: state.currentIndex,
            shuffleSequence: shuffleSequence,
            repeatMode: .none
        )
        XCTAssertEqual(
            state.previousTrack?.id,
            expectedPreviousIndex.flatMap { tracks[$0].id }
        )
    }

    func testNextTrackWrapsWithRepeatAll() {
        let tracks = makeTracks(titles: ["Lead", "Bridge"])
        let state = QueueState(
            tracks: tracks,
            currentIndex: 1,
            shuffleMode: .off,
            repeatMode: .all,
            hasNext: true,
            hasPrevious: true,
            history: [],
            shuffleSequence: nil
        )

        XCTAssertEqual(state.nextTrack?.id, tracks.first?.id)
    }

    func testPositionAndDurationText() {
        let tracks = makeTracks(titles: ["Intro", "Verse"])
        let state = QueueState(
            tracks: tracks,
            currentIndex: 0,
            shuffleMode: .off,
            repeatMode: .none,
            hasNext: true,
            hasPrevious: false,
            history: [],
            shuffleSequence: nil
        )

        XCTAssertEqual(state.positionText, "1 of 2")
        XCTAssertFalse(state.remainingText.isEmpty)
        XCTAssertTrue(state.durationText.contains(":"))
    }

    func testValidateForPersistenceFiltersMissingFiles() throws {
        let tempDir = FileManager.default.temporaryDirectory
        let existingURL = tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("flac")
        FileManager.default.createFile(atPath: existingURL.path, contents: Data("audio".utf8), attributes: nil)

        defer {
            try? FileManager.default.removeItem(at: existingURL)
        }

        let existingTrack = makeTrack(title: "Keep", url: existingURL)
        let missingTrack = makeTrack(title: "Drop", url: tempDir.appendingPathComponent(UUID().uuidString).appendingPathExtension("flac"))

        let state = QueueState(
            tracks: [existingTrack, missingTrack],
            currentIndex: 1,
            shuffleMode: .off,
            repeatMode: .none,
            hasNext: false,
            hasPrevious: true,
            history: [missingTrack],
            shuffleSequence: nil
        )

        let validated = state.validateForPersistence()

        XCTAssertEqual(validated.tracks.map(\.id), [existingTrack.id])
        XCTAssertNil(validated.currentIndex)
        XCTAssertTrue(validated.history.isEmpty)
    }

    func testDebugDescriptionMentionsKeyElements() {
        let tracks = makeTracks(titles: ["Alpha"])
        let state = QueueState(
            tracks: tracks,
            currentIndex: 0,
            shuffleMode: .off,
            repeatMode: .none,
            hasNext: false,
            hasPrevious: false,
            history: [],
            shuffleSequence: nil
        )

        let description = state.debugDescription

        XCTAssertTrue(description.contains("tracks:"))
        XCTAssertTrue(description.contains("current:"))
    }

    // MARK: - Helpers

    private func makeTracks(titles: [String]) -> [AudioTrack] {
        titles.map { makeTrack(title: $0) }
    }

    private func makeTrack(title: String, url: URL? = nil) -> AudioTrack {
        AudioTrack(
            title: title,
            artist: "Artist",
            album: "Album",
            url: url ?? URL(fileURLWithPath: "/tmp/\(UUID().uuidString).flac"),
            duration: 180,
            audioFormat: "FLAC"
        )
    }
}
