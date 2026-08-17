@testable import Fonic_HiFi
import XCTest

private struct LegacyTrackPersistedPayload: Codable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let url: URL
    let duration: TimeInterval
    let audioFormat: String
    let replayGainTrack: Float?
    let replayGainAlbum: Float?
}

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

    func testLastPlaybackPositionPersistsAndRestores() throws {
        let suiteName = "QueueStateTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        // Given
        let tracks = makeTracks(titles: ["Test Track"])
        let state = QueueState(
            tracks: tracks,
            currentIndex: 0,
            shuffleMode: .off,
            repeatMode: .none,
            hasNext: false,
            hasPrevious: false,
            history: [],
            shuffleSequence: nil,
            lastPlaybackPosition: 42.5
        )

        // When
        try state.save(to: defaults)
        let restored = try XCTUnwrap(QueueState.load(from: defaults))

        // Then
        XCTAssertEqual(restored.lastPlaybackPosition, 42.5, accuracy: 0.001)

        QueueState.clear(from: defaults)
        XCTAssertNil(QueueState.load(from: defaults))
    }

    func testQueueSnapshotDoesNotExpireAfterTwentyFourHours() throws {
        let suiteName = "QueueStateTests.durable.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let track = makeTrack(title: "Still Recent Enough")
        let state = QueueState(
            tracks: [track],
            currentIndex: 0,
            timestamp: Date().addingTimeInterval(-7 * 86_400)
        )

        try state.save(to: defaults)

        let restored = try XCTUnwrap(QueueState.load(from: defaults))
        XCTAssertEqual(restored.currentTrack?.id, track.id)
    }

    func testValidationRebasesManagedTrackIntoCurrentContainer() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let documentsDirectory = root.appendingPathComponent("Documents", isDirectory: true)
        let albumDirectory = documentsDirectory
            .appendingPathComponent("Music", isDirectory: true)
            .appendingPathComponent("Album", isDirectory: true)
        try FileManager.default.createDirectory(at: albumDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }

        let generatedURL = try makePCMTestAudioFile(testCase: self)
        let currentURL = albumDirectory.appendingPathComponent("Song.caf")
        try FileManager.default.copyItem(at: generatedURL, to: currentURL)
        let staleURL = URL(
            fileURLWithPath: "/private/var/mobile/Containers/Data/Application/OLD/Documents/Music/Album/Song.caf"
        )
        var track = makeTrack(title: "Rebased", url: staleURL)
        track.isFavorite = true
        track.isAvailable = false
        let state = QueueState(tracks: [track], currentIndex: 0)

        let validated = state.validateForPersistence(documentsDirectory: documentsDirectory)

        XCTAssertEqual(validated.currentTrack?.url, currentURL.standardizedFileURL)
        XCTAssertEqual(validated.currentTrack?.id, track.id)
        XCTAssertEqual(validated.currentTrack?.isFavorite, true)
        XCTAssertEqual(validated.currentTrack?.isAvailable, false)
    }

    func testFailedValidationDoesNotOverwritePersistedQueue() async throws {
        let suiteName = "QueueStateTests.failed-validation.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let missingTrack = makeTrack(
            title: "Temporarily Missing",
            url: URL(fileURLWithPath: "/unavailable/\(UUID().uuidString).flac")
        )
        let state = QueueState(tracks: [missingTrack], currentIndex: 0)
        try state.save(to: defaults)
        let queue = AudioQueueManager(queueStateSuiteName: suiteName)

        let didRestore = await queue.restoreState()
        await queue.flushPendingPersistence()

        XCTAssertFalse(didRestore)
        let persistedState = try XCTUnwrap(QueueState.load(from: defaults))
        XCTAssertEqual(persistedState.currentTrack?.id, missingTrack.id)
    }

    func testValidationDoesNotRestoreDifferentSurvivingTrack() async throws {
        let suiteName = "QueueStateTests.missing-selection.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let availableURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("caf")
        XCTAssertTrue(FileManager.default.createFile(atPath: availableURL.path, contents: Data()))
        defer { try? FileManager.default.removeItem(at: availableURL) }

        let missingTrack = makeTrack(
            title: "Missing Selection",
            url: URL(fileURLWithPath: "/unavailable/\(UUID().uuidString).flac")
        )
        let availableTrack = makeTrack(title: "Still Available", url: availableURL)
        let state = QueueState(tracks: [missingTrack, availableTrack], currentIndex: 0)
        try state.save(to: defaults)
        let queue = AudioQueueManager(queueStateSuiteName: suiteName)

        let didRestore = await queue.restoreState()

        XCTAssertFalse(didRestore)
        XCTAssertNil(queue.currentTrack)
        XCTAssertEqual(QueueState.load(from: defaults)?.currentTrack?.id, missingTrack.id)
    }

    func testPersistenceStoresRemainIsolated() throws {
        let firstSuiteName = "QueueStateTests.first.\(UUID().uuidString)"
        let secondSuiteName = "QueueStateTests.second.\(UUID().uuidString)"
        let firstDefaults = try XCTUnwrap(UserDefaults(suiteName: firstSuiteName))
        let secondDefaults = try XCTUnwrap(UserDefaults(suiteName: secondSuiteName))
        defer {
            firstDefaults.removePersistentDomain(forName: firstSuiteName)
            secondDefaults.removePersistentDomain(forName: secondSuiteName)
        }

        let firstState = QueueState(lastPlaybackPosition: 12)
        let secondState = QueueState(lastPlaybackPosition: 34)

        try firstState.save(to: firstDefaults)
        try secondState.save(to: secondDefaults)

        XCTAssertEqual(QueueState.load(from: firstDefaults)?.lastPlaybackPosition, 12)
        XCTAssertEqual(QueueState.load(from: secondDefaults)?.lastPlaybackPosition, 34)
    }

    func testLastPlaybackPositionDefaultsToZero() {
        let state = QueueState(
            tracks: [],
            currentIndex: nil,
            shuffleMode: .off,
            repeatMode: .none,
            hasNext: false,
            hasPrevious: false,
            history: [],
            shuffleSequence: nil
        )

        XCTAssertEqual(state.lastPlaybackPosition, 0)
    }

    func testPersistedLegacyTrackPayloadDefaultsNewIdentityFlags() throws {
        let id = UUID()
        let payload = LegacyTrackPersistedPayload(
            id: id,
            title: "Legacy Track",
            artist: "Legacy Artist",
            album: "Legacy Album",
            url: URL(fileURLWithPath: "/tmp/legacy-track.flac"),
            duration: 123,
            audioFormat: "FLAC",
            replayGainTrack: -5.5,
            replayGainAlbum: -6.25
        )
        let persistedData = try JSONEncoder().encode(payload)

        let restored = try JSONDecoder().decode(LegacyTrack.self, from: persistedData)

        XCTAssertEqual(restored.id, id)
        XCTAssertEqual(restored.replayGainTrack, -5.5)
        XCTAssertEqual(restored.replayGainAlbum, -6.25)
        XCTAssertFalse(restored.isFavorite)
        XCTAssertTrue(restored.isAvailable)
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
