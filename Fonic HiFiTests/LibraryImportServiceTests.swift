@testable import Fonic_HiFi
import Combine
import Foundation
import os
import SwiftData
import XCTest

@MainActor
final class LibraryImportServiceTests: XCTestCase {
    private let metricsDefaultsKey = "com.fonichifi.metrics.enabled"

    override func tearDown() async throws {
        Metrics.setSinkForTesting(nil)
        Metrics.enable(false)
        UserDefaults.standard.removeObject(forKey: metricsDefaultsKey)
        try await super.tearDown()
    }

    func testCancellingNoResultPipelineCancelsDiscoveryProducer() async throws {
        let schema = Schema([Track.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let trackActor = TrackDataActor(modelContainer: container)
        let checkpoint = ControlledDiscoveryCheckpoint()
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let managedDirectory = root.appendingPathComponent("Music", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: root)
        }

        let sourceURL = try makePCMTestAudioFile(fileExtension: "wav", testCase: self)
        let processor = FileImportProcessor(
            trackDataActor: trackActor,
            metadataExtractor: TestMetadataExtractor(),
            musicContainerURL: managedDirectory,
            discoveryCheckpoint: {
                await checkpoint.wait()
            },
        )
        let service = LibraryImportService(fileProcessor: processor, fileProcessingConcurrency: 1)
        let pipelineFinished = expectation(description: "Cancelled no-result pipeline finished")
        let pipelineTask = Task { @MainActor in
            await service.executeImportPipeline(urls: [sourceURL])
            pipelineFinished.fulfill()
        }

        let discoveryStarted = await waitForDiscoveryCheckpoint(checkpoint)
        XCTAssertTrue(discoveryStarted)

        pipelineTask.cancel()
        await fulfillment(of: [pipelineFinished], timeout: 1)

        let checkpointSnapshot = await checkpoint.snapshot()
        await checkpoint.releaseAll()
        _ = await pipelineTask.result

        XCTAssertEqual(checkpointSnapshot.startedCount, 1)
        XCTAssertEqual(checkpointSnapshot.cancelledCount, 1)
        XCTAssertNil(checkpointSnapshot.unexpectedErrorDescription)
        XCTAssertEqual(service.statusMessage, "Import cancelled")
        XCTAssertFalse(service.isImportComplete)
        XCTAssertFalse(service.isImporting)
        XCTAssertTrue(FileManager.default.fileExists(atPath: sourceURL.path))
        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: managedDirectory.path).isEmpty)
        let trackCount = try await trackActor.getTracksCount()
        XCTAssertEqual(trackCount, 0)
    }

    func testImportFilesSkipsDuplicates() async throws {
        let environment = try makeImportTestEnvironment()
        let service = environment.service
        let temporaryFiles = try makeTemporaryAudioFiles(count: 1, testCase: self)
        guard let fileURL = temporaryFiles.first else {
            XCTFail("Expected a temporary file for testing")
            return
        }

        let firstImport = await service.importSingleFile(fileURL)
        let duplicateImport = await service.importSingleFile(fileURL)

        XCTAssertEqual(service.recentlyImported.count, 1)
        XCTAssertEqual(service.importErrors.count, 1)
        XCTAssertNotNil(firstImport)
        XCTAssertNil(duplicateImport)
        if let duplicateError = service.importErrors.first?.error as? FileImportProcessor.ProcessedFileError {
            XCTAssertTrue(duplicateError.message.contains("Duplicate"))
        } else {
            XCTFail("Unexpected error type: \(String(describing: service.importErrors.first?.error))")
        }
    }

    func testReadOnlyPolicyRejectsBulkAndSingleImportBeforeCopying() async throws {
        let root = try makeTemporaryTestDirectory(named: "read-only-import", testCase: self)
        let musicDirectory = root.appendingPathComponent("Music", isDirectory: true)
        try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
        let sourceURL = try makePCMTestAudioFile(fileExtension: "wav", testCase: self)
        let schema = Schema([Track.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let trackActor = TrackDataActor(modelContainer: container, mutationPolicy: .readOnly)
        let processor = FileImportProcessor(
            trackDataActor: trackActor,
            metadataExtractor: TestMetadataExtractor(),
            musicContainerURL: musicDirectory
        )
        let service = LibraryImportService(
            fileProcessor: processor,
            fileProcessingConcurrency: 1,
            mutationPolicy: .readOnly
        )

        service.importFiles(from: [sourceURL])
        XCTAssertEqual(service.importErrors.first?.error as? ImportServiceError, .readOnly)
        XCTAssertTrue(service.statusMessage.localizedCaseInsensitiveContains("read-only"))
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: musicDirectory.path), [])

        let singleImport = await service.importSingleFile(sourceURL)
        XCTAssertNil(singleImport)
        XCTAssertEqual(service.importErrors.last?.error as? ImportServiceError, .readOnly)
        XCTAssertEqual(try FileManager.default.contentsOfDirectory(atPath: musicDirectory.path), [])
    }

    func testCancelImportStopsProcessing() async throws {
        let metadataExtractor = ControlledMetadataExtractor()
        let environment = try makeImportTestEnvironment(metadataExtractor: metadataExtractor)
        let service = environment.service
        let files = try makeTemporaryAudioFiles(count: 6, testCase: self)
        let discoveryStarted = expectation(description: "At least one file discovered")
        let discoveryObservation = service.$totalFiles
            .filter { $0 > 0 }
            .prefix(1)
            .sink { _ in
                discoveryStarted.fulfill()
            }
        defer { discoveryObservation.cancel() }

        service.importFiles(from: files)
        await fulfillment(of: [discoveryStarted], timeout: 2)

        service.cancelImport()

        XCTAssertEqual(service.statusMessage, "Import cancelled")
        XCTAssertFalse(service.isImportComplete)
        XCTAssertTrue(service.isImporting)
        XCTAssertLessThan(service.filesProcessed, service.totalFiles)

        await metadataExtractor.releaseAll()
        try await waitForCancellation(service)
        XCTAssertFalse(service.isImporting)
        XCTAssertFalse(service.isImportComplete)
    }

    func testImportPipelineStreamsDiscoveryCounts() async throws {
        let environment = try makeImportTestEnvironment(metadataExtractor: SlowMetadataExtractor(delay: 0.01))
        let service = environment.service
        let files = try makeTemporaryAudioFiles(count: 4, testCase: self)

        service.importFiles(from: files)
        try await waitUntil({ service.totalFiles == files.count })
        try await waitUntil({ service.filesProcessed == files.count })

        XCTAssertEqual(service.totalFiles, files.count)
        XCTAssertEqual(service.filesProcessed, files.count)
        XCTAssertEqual(environment.invalidationCount(), 1)
        XCTAssertFalse(service.isImporting)
        XCTAssertTrue(service.isImportComplete)
    }

    func testImportPipelineHandlesNestedDirectoriesAndLargeVolume() async throws {
        let environment = try makeImportTestEnvironment(metadataExtractor: SlowMetadataExtractor(delay: 0.002))
        let service = environment.service
        let scenario = try makeNestedAudioDirectory(
            fileCountPerFolder: 12,
            depth: 3,
            branchingFactor: 2,
            duplicateCount: 0,
            testCase: self
        )

        let enumerator = FileManager.default.enumerator(
            at: scenario.root,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        )
        var enumeratedAudio = 0
        while let url = enumerator?.nextObject() as? URL {
            if url.pathExtension.lowercased() == "wav" {
                enumeratedAudio += 1
            }
        }
        XCTAssertEqual(enumeratedAudio, scenario.totalFiles)

        let processor = FileImportProcessor(
            trackDataActor: environment.trackActor,
            metadataExtractor: SlowMetadataExtractor(delay: 0)
        )
        let discovered = await processor.discoverAudioFiles(from: [scenario.root])
        XCTAssertEqual(discovered.count, scenario.totalFiles)

        await service.executeImportPipeline(urls: [scenario.root])

        XCTAssertEqual(service.totalFiles, scenario.totalFiles)
        XCTAssertEqual(service.filesProcessed, scenario.totalFiles)
        XCTAssertEqual(service.recentlyImported.count, scenario.totalFiles)
        XCTAssertTrue(service.importErrors.isEmpty)
        XCTAssertEqual(environment.invalidationCount(), 1)
        XCTAssertEqual(service.importProgress, 1.0, accuracy: 0.0001)
        XCTAssertTrue(service.statusMessage.contains("Import completed"))
        XCTAssertTrue(service.isImportComplete)
    }

    func testImportMetricsEmitsDiscoveryAndCompletionCounters() async throws {
        let environment = try makeImportTestEnvironment()
        let service = environment.service
        let files = try makeTemporaryAudioFiles(count: 2, testCase: self)
        let eventsLock = OSAllocatedUnfairLock<[(counter: MetricsCounter, amount: Int, metadata: [String: String])]>(initialState: [])

        Metrics.enable(true)
        Metrics.setSinkForTesting { counter, amount, _, metadata in
            eventsLock.withLock { state in
                state.append((counter, amount, metadata))
            }
        }

        service.importFiles(from: files)
        try await waitUntil({ service.filesProcessed == files.count })
        try await waitUntil({ service.isImporting == false })

        let events = eventsLock.withLock { $0 }

        let requested = events.first { $0.counter == .importsDiscovered && $0.metadata["phase"] == "requested" }
        XCTAssertEqual(requested?.amount, files.count)

        let discovered = events.filter { $0.counter == .importsDiscovered && $0.metadata["file"] != nil }
        XCTAssertEqual(discovered.count, files.count)

        let fileNames = Set(files.map { $0.lastPathComponent })
        XCTAssertEqual(Set(discovered.compactMap { $0.metadata["file"] }), fileNames)

        let completed = events.filter { $0.counter == .importsCompleted }
        XCTAssertEqual(completed.count, files.count)
        XCTAssertTrue(completed.allSatisfy { event in
            guard let file = event.metadata["file"], let duration = event.metadata["duration"] else { return false }
            return fileNames.contains(file) && !duration.isEmpty
        })

        XCTAssertFalse(events.contains { $0.counter == .importsFailed })
    }

    func testImportMetricsEmitsFailureWithTruncatedReason() async throws {
        let files = try makeTemporaryAudioFiles(count: 2, testCase: self)
        guard let failingFile = files.last else {
            XCTFail("Expected at least one file")
            return
        }

        let environment = try makeImportTestEnvironment(
            metadataExtractor: PartiallyFailingMetadataExtractor(
                failingIdentifiers: [failingFile.deletingPathExtension().lastPathComponent]
            )
        )
        let service = environment.service
        let eventsLock = OSAllocatedUnfairLock<[(counter: MetricsCounter, amount: Int, metadata: [String: String])]>(initialState: [])

        Metrics.enable(true)
        Metrics.setSinkForTesting { counter, amount, _, metadata in
            eventsLock.withLock { state in
                state.append((counter, amount, metadata))
            }
        }

        service.importFiles(from: files)
        try await waitUntil({ service.filesProcessed == files.count })
        try await waitUntil({ service.isImporting == false })

        let events = eventsLock.withLock { $0 }
        let failures = events.filter { $0.counter == .importsFailed }
        XCTAssertEqual(failures.count, 1)

        guard let failure = failures.first else {
            XCTFail("Expected failure event")
            return
        }

        XCTAssertEqual(failure.metadata["file"], failingFile.lastPathComponent)
        if let reason = failure.metadata["reason"] {
            XCTAssertTrue(reason.hasSuffix("…"))
            XCTAssertLessThanOrEqual(reason.count, 61)
        } else {
            XCTFail("Expected failure reason metadata")
        }
    }
}

private struct PartiallyFailingMetadataExtractor: MetadataExtracting {
    let failingIdentifiers: Set<String>

    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        if failingIdentifiers.contains(where: { url.lastPathComponent.contains($0) }) {
            throw SyntheticMetadataError()
        }
        return try await TestMetadataExtractor().extractTrackMetadata(from: url)
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

private struct SyntheticMetadataError: LocalizedError {
    var errorDescription: String? {
        String(repeating: "x", count: 80)
    }
}

private actor ControlledMetadataExtractor: MetadataExtracting {
    private var isReleased = false
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        let waiterID = UUID()

        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                guard !isReleased, !Task.isCancelled else {
                    continuation.resume()
                    return
                }
                waiters[waiterID] = continuation
            }
        } onCancel: {
            Task {
                await self.resumeWaiter(id: waiterID)
            }
        }

        try Task.checkCancellation()
        return try await TestMetadataExtractor().extractTrackMetadata(from: url)
    }

    func extractMetadata(from urls: [URL], maxConcurrentTasks: Int) async throws -> [TrackMetadata] {
        var metadata: [TrackMetadata] = []
        metadata.reserveCapacity(urls.count)
        for url in urls {
            metadata.append(try await extractTrackMetadata(from: url))
        }
        return metadata
    }

    func releaseAll() {
        isReleased = true
        let continuations = Array(waiters.values)
        waiters.removeAll()
        continuations.forEach { $0.resume() }
    }

    private func resumeWaiter(id: UUID) {
        guard let continuation = waiters.removeValue(forKey: id) else { return }
        continuation.resume()
    }
}

private actor ControlledDiscoveryCheckpoint {
    struct Snapshot: Sendable {
        let startedCount: Int
        let cancelledCount: Int
        let unexpectedErrorDescription: String?
    }

    private var startedCount = 0
    private var cancelledCount = 0
    private var unexpectedErrorDescription: String?
    private var waiters: [UUID: CheckedContinuation<Void, Error>] = [:]

    func wait() async {
        let waiterID = UUID()
        startedCount += 1

        do {
            try await withTaskCancellationHandler {
                try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                    guard !Task.isCancelled else {
                        continuation.resume(throwing: CancellationError())
                        return
                    }
                    waiters[waiterID] = continuation
                }
            } onCancel: {
                Task {
                    await self.cancelWaiter(id: waiterID)
                }
            }
            try Task.checkCancellation()
        } catch is CancellationError {
            cancelledCount += 1
        } catch {
            unexpectedErrorDescription = error.localizedDescription
        }
    }

    func snapshot() -> Snapshot {
        Snapshot(
            startedCount: startedCount,
            cancelledCount: cancelledCount,
            unexpectedErrorDescription: unexpectedErrorDescription,
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

private func waitForDiscoveryCheckpoint(_ checkpoint: ControlledDiscoveryCheckpoint) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))
    while clock.now < deadline {
        if await checkpoint.snapshot().startedCount > 0 {
            return true
        }
        await Task.yield()
    }
    return await checkpoint.snapshot().startedCount > 0
}
