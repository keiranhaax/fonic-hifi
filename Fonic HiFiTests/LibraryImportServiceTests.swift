@testable import Fonic_HiFi
import os
import SwiftData
import XCTest

@MainActor
final class LibraryImportServiceTests: XCTestCase {
    private let metricsDefaultsKey = "com.fonichifi.metrics.enabled"

    override func tearDown() {
        Metrics.setSinkForTesting(nil)
        Metrics.enable(false)
        UserDefaults.standard.removeObject(forKey: metricsDefaultsKey)
        super.tearDown()
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

    func testCancelImportStopsProcessing() async throws {
        let environment = try makeImportTestEnvironment(metadataExtractor: SlowMetadataExtractor(delay: 0.05))
        let service = environment.service
        let files = try makeTemporaryAudioFiles(count: 6, testCase: self)

        service.importFiles(from: files)
        try await waitUntil({ service.isImporting })

        service.cancelImport()
        try await waitForCancellation(service)

        XCTAssertEqual(service.statusMessage, "Import cancelled")
        XCTAssertFalse(service.isImporting)
        XCTAssertLessThan(service.filesProcessed, service.totalFiles)
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
        XCTAssertEqual(environment.invalidationCount(), files.count)
        XCTAssertFalse(service.isImporting)
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
            if url.pathExtension.lowercased() == "flac" {
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
        XCTAssertEqual(environment.invalidationCount(), scenario.totalFiles)
        XCTAssertEqual(service.importProgress, 1.0, accuracy: 0.0001)
        XCTAssertTrue(service.statusMessage.contains("Import completed"))
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

    func extractMetadata(from urls: [URL]) async throws -> [TrackMetadata] {
        try await urls.asyncMap { try await extractTrackMetadata(from: $0) }
    }
}

private struct SyntheticMetadataError: LocalizedError {
    var errorDescription: String? {
        String(repeating: "x", count: 80)
    }
}
