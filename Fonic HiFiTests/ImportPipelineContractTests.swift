@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

@MainActor
final class ImportPipelineContractTests: XCTestCase {
    func testZeroByteWAVIsRejectedAsInvalidBeforeDetection() async throws {
        let url = try makeTemporaryAudioFile(data: Data(), fileExtension: "wav")

        do {
            _ = try await AudioFormatDetectionManager().detectFormat(at: url)
            XCTFail("A zero-byte audio file must not be accepted")
        } catch let error as DetectionError {
            guard case .invalidFile = error else {
                XCTFail("Expected invalidFile, got \(error)")
                return
            }
        } catch {
            XCTFail("Expected DetectionError.invalidFile, got \(error)")
        }
    }

    func testTruncatedWAVPayloadIsRejectedAsInvalidBeforeDetection() async throws {
        var data = makeValidPCMTestWAVData(frameCount: 4_410)
        data.removeLast(64)
        let url = try makeTemporaryAudioFile(data: data, fileExtension: "wav")

        do {
            _ = try await AudioFormatDetectionManager().detectFormat(at: url)
            XCTFail("A truncated audio payload must not be accepted")
        } catch let error as DetectionError {
            guard case .invalidFile = error else {
                XCTFail("Expected invalidFile, got \(error)")
                return
            }
        } catch {
            XCTFail("Expected DetectionError.invalidFile, got \(error)")
        }
    }

    func testValidShortWAVProducesValidAudioFileInfo() async throws {
        let data = makeValidPCMTestWAVData(frameCount: 441)
        let url = try makeTemporaryAudioFile(data: data, fileExtension: "wav")

        let info = try await AudioFormatDetectionManager().detectFormat(at: url)

        XCTAssertTrue(info.isValid)
        XCTAssertEqual(info.format, .wav)
        XCTAssertGreaterThan(info.duration, 0)
        XCTAssertGreaterThan(info.sampleRate, 0)
        XCTAssertGreaterThan(info.channels, 0)
    }

    func testAudioFileInfoRejectsNonFiniteDuration() {
        for duration in [Double.infinity, -Double.infinity, .nan] {
            let info = AudioFileInfo(
                url: URL(fileURLWithPath: "/tmp/nonfinite.wav"),
                format: .wav,
                duration: duration,
                bitDepth: 16,
                sampleRate: 44_100,
                channels: 2,
                fileSize: 1_024,
            )

            XCTAssertFalse(info.isValid, "Duration \(duration) must be rejected")
        }
    }

    func testNonFiniteMetadataIsRejectedBeforeSwiftDataClaim() async throws {
        let root = try makeTemporaryTestDirectory(named: "nonfinite-import", testCase: self)
        let musicDirectory = root.appendingPathComponent("Music", isDirectory: true)
        try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)

        let sourceURL = try makePCMTestAudioFile(fileExtension: "wav", testCase: self)
        let schema = Schema([Track.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let trackActor = TrackDataActor(modelContainer: container)
        let processor = FileImportProcessor(
            trackDataActor: trackActor,
            metadataExtractor: NonFiniteMetadataExtractor(),
            musicContainerURL: musicDirectory,
        )
        let file = FileImportProcessor.DiscoveredAudioFile(
            originalURL: sourceURL,
            securityScopedBookmark: nil,
        )

        do {
            _ = try await processor.processAudioFile(file)
            XCTFail("Non-finite metadata must not be claimed")
        } catch {
            // Expected validation failure before the SwiftData commit.
        }

        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: musicDirectory.path).isEmpty)
        let trackCount = try await trackActor.getTracksCount()
        XCTAssertEqual(trackCount, 0)
    }

    func testCancelledSingleImportRemovesManagedCopy() async throws {
        let root = try makeTemporaryTestDirectory(named: "cancelled-import", testCase: self)
        let musicDirectory = root.appendingPathComponent("Music", isDirectory: true)
        try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)

        let sourceURL = try makePCMTestAudioFile(fileExtension: "wav", testCase: self)
        let schema = Schema([Track.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let trackActor = TrackDataActor(modelContainer: container)
        let extractor = CancellationBlockingMetadataExtractor()
        let processor = FileImportProcessor(
            trackDataActor: trackActor,
            metadataExtractor: extractor,
            musicContainerURL: musicDirectory,
        )
        let file = FileImportProcessor.DiscoveredAudioFile(
            originalURL: sourceURL,
            securityScopedBookmark: nil,
        )

        let importTask = Task {
            try await processor.processAudioFile(file)
        }

        let extractionStarted = await extractor.waitForStart()
        XCTAssertTrue(extractionStarted)

        importTask.cancel()
        do {
            _ = try await importTask.value
            XCTFail("Cancellation must stop the import")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Expected CancellationError, got \(error)")
        }

        XCTAssertTrue(try FileManager.default.contentsOfDirectory(atPath: musicDirectory.path).isEmpty)
        let trackCount = try await trackActor.getTracksCount()
        XCTAssertEqual(trackCount, 0)
    }

    func testCancelImportKeepsOwnershipUntilPipelineSettles() async throws {
        let schema = Schema([Track.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        let trackActor = TrackDataActor(modelContainer: container)
        let extractor = PipelineGateMetadataExtractor()
        let processor = FileImportProcessor(
            trackDataActor: trackActor,
            metadataExtractor: extractor,
            musicContainerURL: try makeTemporaryTestDirectory(named: "cancel-retrigger", testCase: self),
        )
        let service = LibraryImportService(fileProcessor: processor, fileProcessingConcurrency: 1)
        let files = try makeTemporaryAudioFiles(count: 1, testCase: self)

        service.importFiles(from: files)
        let firstStarted = await extractor.waitForStartedCount(atLeast: 1)
        XCTAssertTrue(firstStarted)

        service.cancelImport()

        XCTAssertTrue(
            service.isImporting,
            "The active task must retain ownership until its cancellation cleanup completes",
        )

        service.importFiles(from: files)
        let secondStarted = await extractor.waitForStartedCount(atLeast: 2, timeout: .milliseconds(200))
        XCTAssertFalse(secondStarted, "A cancelled pipeline must not overlap a retriggered pipeline")

        await extractor.releaseAll()
    }

    private func makeTemporaryAudioFile(data: Data, fileExtension: String) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("fixture").appendingPathExtension(fileExtension)
        try data.write(to: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return url
    }
}

private struct NonFiniteMetadataExtractor: MetadataExtracting {
    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        TrackMetadata(
            url: url,
            title: "Invalid duration",
            artist: "Artist",
            album: "Album",
            audioFormat: "WAV",
            duration: .infinity,
            sampleRate: 44_100,
            bitDepth: 16,
            channels: 2,
            isLossless: true,
            sourceURL: url,
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

private actor CancellationBlockingMetadataExtractor: MetadataExtracting {
    private var started = false
    private var waiter: CheckedContinuation<Void, Error>?

    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        started = true
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                waiter = continuation
            }
        } onCancel: {
            Task { await self.cancelWaiter() }
        }

        return try await TestMetadataExtractor().extractTrackMetadata(from: url)
    }

    func waitForStart(timeout: Duration = .seconds(2)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if started { return true }
            await Task.yield()
        }
        return started
    }

    func extractMetadata(from urls: [URL], maxConcurrentTasks: Int) async throws -> [TrackMetadata] {
        var results: [TrackMetadata] = []
        results.reserveCapacity(urls.count)
        for url in urls {
            results.append(try await extractTrackMetadata(from: url))
        }
        return results
    }

    private func cancelWaiter() {
        guard let waiter else { return }
        self.waiter = nil
        waiter.resume(throwing: CancellationError())
    }
}

private actor PipelineGateMetadataExtractor: MetadataExtracting {
    private var startedCount = 0
    private var waiters: [UUID: CheckedContinuation<Void, Never>] = [:]

    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        let waiterID = UUID()
        startedCount += 1

        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                guard !Task.isCancelled else {
                    continuation.resume()
                    return
                }
                waiters[waiterID] = continuation
            }
        } onCancel: {
            Task { await self.resumeWaiter(id: waiterID) }
        }

        try Task.checkCancellation()
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

    func waitForStartedCount(atLeast expected: Int, timeout: Duration = .seconds(2)) async -> Bool {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: timeout)
        while clock.now < deadline {
            if startedCount >= expected { return true }
            await Task.yield()
        }
        return startedCount >= expected
    }

    func releaseAll() {
        let continuations = Array(waiters.values)
        waiters.removeAll()
        continuations.forEach { $0.resume() }
    }

    private func resumeWaiter(id: UUID) {
        guard let waiter = waiters.removeValue(forKey: id) else { return }
        waiter.resume()
    }
}
