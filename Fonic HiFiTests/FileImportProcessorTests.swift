@testable import Fonic_HiFi
import SwiftData
import XCTest

final class FileImportProcessorTests: XCTestCase {
    @MainActor
    func testPostCopyMetadataFailureRemovesManagedFile() async throws {
        let managedDirectory = try makeManagedImportDirectory(testCase: self)
        let sourceURL = try makePCMTestAudioFile(fileExtension: "wav", testCase: self)
        let environment = try makeTestEnvironment(
            metadataExtractor: AlwaysFailingMetadataExtractor(),
            musicContainerURL: managedDirectory,
        )
        let file = FileImportProcessor.DiscoveredAudioFile(
            originalURL: sourceURL,
            securityScopedBookmark: nil,
        )

        do {
            _ = try await environment.processor.processAudioFile(file)
            XCTFail("Expected metadata extraction to fail")
        } catch is InjectedMetadataError {
            // Expected.
        } catch {
            XCTFail("Unexpected import error: \(error)")
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: managedDirectory.path).isEmpty)
        let trackCount = try await environment.trackActor.getTracksCount()
        XCTAssertEqual(trackCount, 0)
    }

    @MainActor
    func testCancellingResultStreamStopsBoundedWorkersAndCleansManagedFiles() async throws {
        let managedDirectory = try makeManagedImportDirectory(testCase: self)
        let sourceFiles = try (0 ..< 5).map { _ in
            try makePCMTestAudioFile(fileExtension: "wav", testCase: self)
        }
        let extractor = BlockingMetadataExtractor()
        let environment = try makeTestEnvironment(
            metadataExtractor: extractor,
            musicContainerURL: managedDirectory,
        )
        let files = sourceFiles.map {
            FileImportProcessor.DiscoveredAudioFile(originalURL: $0, securityScopedBookmark: nil)
        }
        let stream = await environment.processor.processFilesStream(files, maxConcurrentTasks: 2)

        let consumer = Task {
            var resultCount = 0
            for await _ in stream {
                resultCount += 1
            }
            return resultCount
        }

        let reachedConcurrencyLimit = await waitForStartedCount(2, extractor: extractor)
        XCTAssertTrue(reachedConcurrencyLimit)

        consumer.cancel()
        let resultCount = await consumer.value
        let workersStopped = await waitForNoActiveExtractions(extractor)
        let stoppedSnapshot = await extractor.snapshot()

        await extractor.releaseAll()
        let copiedFilesRemoved = await waitForEmptyDirectory(managedDirectory)
        let finalSnapshot = await extractor.snapshot()

        XCTAssertEqual(resultCount, 0, "Cancellation must not be emitted as a generic failure result")
        XCTAssertTrue(workersStopped)
        XCTAssertEqual(stoppedSnapshot.startedCount, 2, "Work must remain bounded by maxConcurrentTasks")
        XCTAssertEqual(stoppedSnapshot.activeCount, 0)
        XCTAssertEqual(stoppedSnapshot.cancelledCount, 2)
        XCTAssertEqual(finalSnapshot.startedCount, stoppedSnapshot.startedCount, "Producer scheduled work after termination")
        XCTAssertTrue(copiedFilesRemoved)
        XCTAssertTrue(sourceFiles.allSatisfy { FileManager.default.fileExists(atPath: $0.path) })
        let trackCount = try await environment.trackActor.getTracksCount()
        XCTAssertEqual(trackCount, 0)
    }

    @MainActor
    func testConcurrentSameSourceImportsCreateOneTrackAndManagedFile() async throws {
        let importCount = 8
        let managedDirectory = try makeManagedImportDirectory(testCase: self)
        let sourceURL = try makePCMTestAudioFile(fileExtension: "wav", testCase: self)
        let extractor = BlockingMetadataExtractor()
        let environment = try makeTestEnvironment(
            metadataExtractor: extractor,
            musicContainerURL: managedDirectory,
        )
        let discovered = FileImportProcessor.DiscoveredAudioFile(
            originalURL: sourceURL,
            securityScopedBookmark: nil,
        )
        let stream = await environment.processor.processFilesStream(
            Array(repeating: discovered, count: importCount),
            maxConcurrentTasks: importCount,
        )
        let consumer = Task {
            var results: [FileImportProcessor.ProcessedFileResult] = []
            for await result in stream {
                results.append(result)
            }
            return results
        }

        let allWorkersReachedExtraction = await waitForStartedCount(importCount, extractor: extractor)
        let blockedSnapshot = await extractor.snapshot()
        await extractor.releaseAll()
        let results = await consumer.value

        XCTAssertTrue(allWorkersReachedExtraction, "Copy and metadata work should remain concurrent before the claim")
        XCTAssertEqual(blockedSnapshot.activeCount, importCount)
        XCTAssertEqual(results.count, importCount)
        XCTAssertEqual(results.filter(\.succeeded).count, 1)
        XCTAssertEqual(results.filter(\.isDuplicate).count, importCount - 1)
        XCTAssertTrue(results.allSatisfy { $0.error == nil })
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: managedDirectory.path).count, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        let importedTrackCount = try await environment.trackActor.getTracksCount()
        XCTAssertEqual(importedTrackCount, 1)

        let verificationContext = ModelContext(environment.container)
        XCTAssertEqual(try verificationContext.fetch(FetchDescriptor<Artist>()).count, 1)
        XCTAssertEqual(try verificationContext.fetch(FetchDescriptor<Album>()).count, 1)
    }

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
        XCTAssertTrue(secondPass.first?.isDuplicate ?? false)
        XCTAssertNil(secondPass.first?.error)
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
    let trackActor: TrackDataActor
}

private func makeTestEnvironment(
    metadataExtractor: MetadataExtracting = StubMetadataExtractor(),
    musicContainerURL: URL? = nil,
) throws -> TestEnvironment {
    let schema = Schema([Track.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let trackActor = TrackDataActor(modelContainer: container)

    let processor = FileImportProcessor(
        trackDataActor: trackActor,
        metadataExtractor: metadataExtractor,
        securityAccessor: StubSecurityAccessor(),
        musicContainerURL: musicContainerURL,
    )

    return TestEnvironment(processor: processor, container: container, trackActor: trackActor)
}

private func makeTemporaryFiles(count: Int, testCase: XCTestCase) throws -> [URL] {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    var urls: [URL] = []
    for index in 0..<count {
        let url = directory.appendingPathComponent("track\(index).wav")
        let frameCount = max(441, (index + 1) * 256)
        try makeValidPCMTestWAVData(frameCount: frameCount).write(to: url)
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

    func extractMetadata(from urls: [URL], maxConcurrentTasks: Int) async throws -> [TrackMetadata] {
        var results: [TrackMetadata] = []
        results.reserveCapacity(urls.count)
        for url in urls {
            results.append(try await extractTrackMetadata(from: url))
        }
        return results
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

    func extractMetadata(from urls: [URL], maxConcurrentTasks: Int) async throws -> [TrackMetadata] {
        var results: [TrackMetadata] = []
        results.reserveCapacity(urls.count)
        for url in urls {
            results.append(try await extractTrackMetadata(from: url))
        }
        return results
    }
}

private enum InjectedMetadataError: Error {
    case failure
}

private struct AlwaysFailingMetadataExtractor: MetadataExtracting {
    func extractTrackMetadata(from _: URL) async throws -> TrackMetadata {
        throw InjectedMetadataError.failure
    }

    func extractMetadata(from _: [URL], maxConcurrentTasks _: Int) async throws -> [TrackMetadata] {
        throw InjectedMetadataError.failure
    }
}

private actor BlockingMetadataExtractor: MetadataExtracting {
    struct Snapshot: Sendable {
        let startedCount: Int
        let activeCount: Int
        let cancelledCount: Int
    }

    private var startedCount = 0
    private var activeCount = 0
    private var cancelledCount = 0
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]

    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        let waiterID = UUID()
        startedCount += 1
        activeCount += 1

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { continuation in
                    waiters[waiterID] = continuation
                }
            } onCancel: {
                Task {
                    await self.cancelWaiter(id: waiterID)
                }
            }
            try Task.checkCancellation()
            let metadata = try await StubMetadataExtractor().extractTrackMetadata(from: url)
            activeCount -= 1
            return metadata
        } catch {
            activeCount -= 1
            if error is CancellationError {
                cancelledCount += 1
            }
            throw error
        }
    }

    func extractMetadata(from urls: [URL], maxConcurrentTasks _: Int) async throws -> [TrackMetadata] {
        var metadata: [TrackMetadata] = []
        metadata.reserveCapacity(urls.count)
        for url in urls {
            metadata.append(try await extractTrackMetadata(from: url))
        }
        return metadata
    }

    func snapshot() -> Snapshot {
        Snapshot(
            startedCount: startedCount,
            activeCount: activeCount,
            cancelledCount: cancelledCount,
        )
    }

    func releaseAll() {
        let continuations = Array(waiters.values)
        waiters.removeAll()
        continuations.forEach { $0.resume() }
    }

    private func cancelWaiter(id: UUID) {
        guard let continuation = waiters.removeValue(forKey: id) else { return }
        continuation.resume(throwing: CancellationError())
    }
}

@MainActor
private func makeManagedImportDirectory(testCase: XCTestCase) throws -> URL {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let managedDirectory = root.appendingPathComponent("Music", isDirectory: true)
    testCase.addTeardownBlock {
        try? FileManager.default.removeItem(at: root)
    }
    return managedDirectory
}

private func waitForStartedCount(_ expectedCount: Int, extractor: BlockingMetadataExtractor) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
        if await extractor.snapshot().startedCount >= expectedCount {
            return true
        }
        await Task.yield()
    }
    return await extractor.snapshot().startedCount >= expectedCount
}

private func waitForNoActiveExtractions(_ extractor: BlockingMetadataExtractor) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
        if await extractor.snapshot().activeCount == 0 {
            return true
        }
        await Task.yield()
    }
    return await extractor.snapshot().activeCount == 0
}

private func waitForEmptyDirectory(_ directory: URL) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
        if (try? FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty) == true {
            return true
        }
        await Task.yield()
    }
    return (try? FileManager.default.contentsOfDirectory(atPath: directory.path).isEmpty) == true
}
