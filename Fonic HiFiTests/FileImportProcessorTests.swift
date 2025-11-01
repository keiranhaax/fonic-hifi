@testable import Fonic_HiFi
import SwiftData
import XCTest

final class FileImportProcessorTests: XCTestCase {
    func testProcessFilesStreamImportsAudioFiles() async throws {
        let environment = try makeTestEnvironment()
        let processor = environment.processor
        let temporaryFiles = try makeTemporaryFiles(count: 2, testCase: self)

        let discovered = temporaryFiles.map { url in
            FileImportProcessor.DiscoveredAudioFile(originalURL: url, securityScopedBookmark: nil)
        }

        var results: [FileImportProcessor.ProcessedFileResult] = []
        let stream = await processor.processFilesStream(discovered, maxConcurrentTasks: 2)

        for await result in stream {
            results.append(result)
        }

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.filter { $0.identifier != nil }.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.error == nil })
    }

    func testProcessFilesStreamSkipsDuplicateEntries() async throws {
        let environment = try makeTestEnvironment()
        let processor = environment.processor
        let temporaryFiles = try makeTemporaryFiles(count: 1, testCase: self)
        guard let fileURL = temporaryFiles.first else {
            XCTFail("Expected a temporary file for testing")
            return
        }
        let discovered = FileImportProcessor.DiscoveredAudioFile(originalURL: fileURL, securityScopedBookmark: nil)

        var firstPass: [FileImportProcessor.ProcessedFileResult] = []
        let firstStream = await processor.processFilesStream([discovered])
        for await result in firstStream {
            firstPass.append(result)
        }

        XCTAssertEqual(firstPass.count, 1)
        XCTAssertNotNil(firstPass.first?.identifier)

        var secondPass: [FileImportProcessor.ProcessedFileResult] = []
        let secondStream = await processor.processFilesStream([discovered])
        for await result in secondStream {
            secondPass.append(result)
        }

        XCTAssertEqual(secondPass.count, 1)
        XCTAssertNil(secondPass.first?.identifier)
        XCTAssertNotNil(secondPass.first?.error)
    }

    func testProcessFilesStreamHandlesMixedResults() async throws {
        let files = try makeTemporaryFiles(count: 3, testCase: self)
        let failingName = files[1].deletingPathExtension().lastPathComponent
        let failingExtractor = ConditionalMetadataExtractor { url in
            url.lastPathComponent.contains(failingName)
        }
        let environment = try makeTestEnvironment(metadataExtractor: failingExtractor)
        let processor = environment.processor

        let discovered = files.map { url in
            FileImportProcessor.DiscoveredAudioFile(originalURL: url, securityScopedBookmark: nil)
        }

        var results: [FileImportProcessor.ProcessedFileResult] = []
        let stream = await processor.processFilesStream(discovered, maxConcurrentTasks: 3)

        for await result in stream {
            results.append(result)
        }

        XCTAssertEqual(results.count, 3)
        XCTAssertEqual(results.filter { $0.identifier != nil }.count, 2)
        XCTAssertEqual(results.filter { $0.error != nil }.count, 1)
        XCTAssertTrue(results.contains { $0.error?.message.contains("metadata") == true })
    }

    func testDiscoverAudioFilesStreamEnumeratesDirectory() async throws {
        let environment = try makeTestEnvironment()
        let processor = environment.processor
        let files = try makeTemporaryFiles(count: 3, testCase: self)
        guard let directory = files.first?.deletingLastPathComponent() else {
            XCTFail("Expected a directory for discovery streaming")
            return
        }

        var discovered: [FileImportProcessor.DiscoveredAudioFile] = []
        let stream = await processor.discoverAudioFilesStream(from: [directory])

        for await file in stream {
            discovered.append(file)
        }

        XCTAssertEqual(discovered.count, files.count)
        let expectedNames = Set(files.map { $0.lastPathComponent })
        let yieldedNames = Set(discovered.map { $0.originalURL.lastPathComponent })
        XCTAssertEqual(yieldedNames, expectedNames)
    }

    func testProcessFilesStreamSupportsAsyncSequenceInput() async throws {
        let environment = try makeTestEnvironment()
        let processor = environment.processor
        let temporaryFiles = try makeTemporaryFiles(count: 2, testCase: self)

        let discovered = temporaryFiles.map { url in
            FileImportProcessor.DiscoveredAudioFile(originalURL: url, securityScopedBookmark: nil)
        }

        let (stream, continuation) = AsyncStream<FileImportProcessor.DiscoveredAudioFile>.makeStream()
        Task {
            for file in discovered {
                continuation.yield(file)
            }
            continuation.finish()
        }

        var results: [FileImportProcessor.ProcessedFileResult] = []
        let resultStream = await processor.processFilesStream(stream, maxConcurrentTasks: 2)

        for await result in resultStream {
            results.append(result)
        }

        XCTAssertEqual(results.count, discovered.count)
        XCTAssertEqual(results.filter { $0.identifier != nil }.count, discovered.count)
    }

    func testProcessFilesBatchReturnsAggregatedResults() async throws {
        let environment = try makeTestEnvironment()
        let processor = environment.processor
        let temporaryFiles = try makeTemporaryFiles(count: 2, testCase: self)

        let discovered = temporaryFiles.map { url in
            FileImportProcessor.DiscoveredAudioFile(originalURL: url, securityScopedBookmark: nil)
        }

        let results = await processor.processFiles(discovered, maxConcurrentTasks: 2)

        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.filter { $0.identifier != nil }.count, 2)
        XCTAssertTrue(results.allSatisfy { $0.error == nil })
    }
}

// MARK: - Test Helpers

private struct TestEnvironment {
    let processor: FileImportProcessor
    let container: ModelContainer
}

private func makeTestEnvironment(metadataExtractor: MetadataExtracting = StubMetadataExtractor()) throws -> TestEnvironment {
    let schema = Schema([Track.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let trackActor = TrackDataActor(modelContainer: container)

    let processor = FileImportProcessor(
        trackDataActor: trackActor,
        metadataExtractor: metadataExtractor,
        securityAccessor: StubSecurityAccessor()
    )

    return TestEnvironment(processor: processor, container: container)
}

private func makeTemporaryFiles(count: Int, testCase: XCTestCase) throws -> [URL] {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    var urls: [URL] = []
    for index in 0..<count {
        let url = directory.appendingPathComponent("track\(index).flac")
        try Data([0, 1, 2, 3]).write(to: url)
        urls.append(url)
    }

    testCase.addTeardownBlock {
        try? FileManager.default.removeItem(at: directory)
    }

    return urls
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

private struct StubSecurityAccessor: SecurityScopedAccessing {
    func startAccessing(_ url: URL) -> Bool { url.startAccessingSecurityScopedResource() }

    func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}

private struct ConditionalMetadataExtractor: MetadataExtracting, Sendable {
    let shouldFail: @Sendable (URL) -> Bool

    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        if shouldFail(url) {
            throw NSError(domain: "ConditionalMetadataExtractor", code: 1, userInfo: [NSLocalizedDescriptionKey: "metadata unavailable"])
        }
        return try await StubMetadataExtractor().extractTrackMetadata(from: url)
    }

    func extractMetadata(from urls: [URL]) async throws -> [TrackMetadata] {
        try await urls.asyncMap { try await extractTrackMetadata(from: $0) }
    }
}
