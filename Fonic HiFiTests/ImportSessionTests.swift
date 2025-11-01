@testable import Fonic_HiFi
import SwiftData
import XCTest

final class ImportSessionTests: XCTestCase {
    func testAddFileWithoutTransactionThrows() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "orphan.flac", testCase: self)

        do {
            _ = try await environment.session.addFile(fileURL)
            XCTFail("Expected transactionNotStarted error")
        } catch let error as ImportSessionError {
            guard case .transactionNotStarted = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testBeginTransactionTwiceThrows() async throws {
        let environment = try makeEnvironment(testCase: self)

        try await environment.session.beginTransaction()

        do {
            try await environment.session.beginTransaction()
            XCTFail("Expected transactionAlreadyStarted error")
        } catch let error as ImportSessionError {
            guard case .transactionAlreadyStarted = error else {
                XCTFail("Unexpected error: \(error)")
                return
            }
        }
    }

    func testCommitImportsTrackAndCopiesFile() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "track.flac", testCase: self)

        try await environment.session.beginTransaction()
        _ = try await environment.session.addFile(fileURL)

        let preCommitProgress = await environment.session.progress
        XCTAssertEqual(preCommitProgress.totalFiles, 1)
        XCTAssertEqual(preCommitProgress.processedFiles, 0)

        try await environment.session.commit()

        let postCommitProgress = await environment.session.progress
        XCTAssertEqual(postCommitProgress.totalFiles, 0)
        XCTAssertEqual(postCommitProgress.processedFiles, 0)

        let storedFiles = try FileManager.default.contentsOfDirectory(at: environment.musicDirectory, includingPropertiesForKeys: nil)
        XCTAssertEqual(storedFiles.count, 1)

        let trackCount = try await environment.trackActor.getTracksCount()
        XCTAssertEqual(trackCount, 1)

        let isDuplicate = await environment.session.checkDuplicate(fileURL)
        XCTAssertTrue(isDuplicate)
    }

    func testRemoveFileReducesTotalCount() async throws {
        let environment = try makeEnvironment(testCase: self)
        let first = try makeTemporaryFile(named: "first.flac", testCase: self)
        let second = try makeTemporaryFile(named: "second.flac", testCase: self)

        try await environment.session.beginTransaction()
        let ids = try await environment.session.addFiles([first, second])

        var progress = await environment.session.progress
        XCTAssertEqual(progress.totalFiles, 2)

        try await environment.session.removeFile(ids[0])

        progress = await environment.session.progress
        XCTAssertEqual(progress.totalFiles, 1)
        XCTAssertEqual(progress.processedFiles, 0)
    }

    func testValidateFileDetectsDuplicate() async throws {
        let environment = try makeEnvironment(testCase: self)
        let fileURL = try makeTemporaryFile(named: "duplicate.flac", testCase: self)

        try await environment.session.beginTransaction()
        _ = try await environment.session.addFile(fileURL)
        try await environment.session.commit()

        let validation = try await environment.session.validateFile(fileURL)

        XCTAssertFalse(validation.isValid)
        XCTAssertTrue(validation.issues.contains { issue in
            if case .duplicateFile = issue {
                return true
            }
            return false
        })
    }
}

// MARK: - Test Utilities

private struct ImportSessionTestEnvironment {
    let session: ImportSession
    let trackActor: TrackDataActor
    let musicDirectory: URL
}

private func makeEnvironment(
    metadataExtractor: MetadataExtracting = StubMetadataExtractor(),
    testCase: XCTestCase
) throws -> ImportSessionTestEnvironment {
    let schema = Schema([Track.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let trackActor = TrackDataActor(modelContainer: container)

    let musicDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let session = ImportSession(
        trackDataActor: trackActor,
        metadataExtractor: metadataExtractor,
        musicContainerURL: musicDirectory
    )

    testCase.addTeardownBlock {
        try? FileManager.default.removeItem(at: musicDirectory)
    }

    return ImportSessionTestEnvironment(
        session: session,
        trackActor: trackActor,
        musicDirectory: musicDirectory
    )
}

private func makeTemporaryFile(named name: String, testCase: XCTestCase) throws -> URL {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    let url = directory.appendingPathComponent(name)
    try Data([0, 1, 2, 3]).write(to: url)

    testCase.addTeardownBlock {
        try? FileManager.default.removeItem(at: directory)
    }

    return url
}

private struct StubMetadataExtractor: MetadataExtracting {
    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        TrackMetadata(
            url: url,
            title: url.lastPathComponent,
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            duration: 180,
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            isLossless: true,
            sourceURL: url
        )
    }

    func extractMetadata(from urls: [URL]) async throws -> [TrackMetadata] {
        try await urls.asyncMap { try await extractTrackMetadata(from: $0) }
    }
}
