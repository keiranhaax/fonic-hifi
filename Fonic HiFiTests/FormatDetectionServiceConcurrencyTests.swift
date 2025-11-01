import Dispatch
@testable import Fonic_HiFi
import Foundation
import XCTest

final class FormatDetectionServiceConcurrencyTests: XCTestCase {
    func testConcurrentValidationDoesNotDeadlock() async {
        let detector = AudioFormatDetectionManager.shared
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)

        await withTaskGroup(of: Bool.self) { group in
            for _ in 0 ..< 10 {
                group.addTask {
                    await detector.validateFile(at: missingURL)
                }
            }

            for await result in group {
                XCTAssertFalse(result)
            }
        }
    }

    func testFormatSupportQueryFromBackgroundQueue() async {
        let detector = AudioFormatDetectionManager.shared

        let result = await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let startedOnMainThread = Thread.isMainThread
                Task {
                    let isSupported = await detector.isFormatSupported(.mp3)
                    continuation.resume(returning: (startedOnMainThread, isSupported))
                }
            }
        }

        XCTAssertFalse(result.0, "Expected background queue invocation")
        XCTAssertTrue(result.1)
    }

    func testConcurrentDetectFormatGracefullyFailsForMissingFiles() async {
        let detector = AudioFormatDetectionManager.shared
        let missingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try await withThrowingTaskGroup(of: Void.self) { group in
                for _ in 0 ..< 8 {
                    group.addTask {
                        do {
                            _ = try await detector.detectFormat(at: missingURL)
                            XCTFail("Expected detectFormat to throw")
                        } catch let error as DetectionError {
                            if case let DetectionError.fileNotFound(url) = error {
                                XCTAssertEqual(url, missingURL)
                            } else {
                                XCTFail("Unexpected detection error: \(error)")
                            }
                        } catch {
                            XCTFail("Unexpected error: \(error)")
                        }
                    }
                }
                for try await _ in group {}
            }
        } catch {
            XCTFail("Group should not throw: \(error)")
        }
    }

    func testCoordinatorEnforcesConcurrencyLimit() async throws {
        let tracker = ConcurrencyTracker()
        let manager = AudioFormatDetectionManager(maxConcurrentDetections: 2, timeout: 2.0)
        await manager.clearAdapters()

        let temporaryDirectory = FileManager.default.temporaryDirectory
        var urls: [URL] = []
        for index in 0 ..< 6 {
            let url = temporaryDirectory.appendingPathComponent("concurrency-test-\(index).flac")
            FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)
            urls.append(url)
        }

        let adapter = StubDetectionAdapter(tracker: tracker, delay: 0.1)
        await manager.registerAdapter(adapter)

        try await withThrowingTaskGroup(of: Void.self) { group in
            for url in urls {
                group.addTask {
                    _ = try await manager.detectFormat(at: url)
                }
            }
            for try await _ in group {}
        }

        let observedMaximum = await tracker.maximum
        XCTAssertLessThanOrEqual(observedMaximum, 2)
    }

    func testDetectionCancellationPropagates() async {
        let tracker = ConcurrencyTracker()
        let manager = AudioFormatDetectionManager(maxConcurrentDetections: 2, timeout: 5.0)
        await manager.clearAdapters()

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("cancel-test.flac")
        FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)

        let adapter = StubDetectionAdapter(tracker: tracker, delay: 1.0)
        await manager.registerAdapter(adapter)

        let task = Task {
            try await manager.detectFormat(at: url)
        }

        try? await Task.sleep(for: .milliseconds(50))
        task.cancel()

        do {
            _ = try await task.value
            XCTFail("Expected cancellation to propagate")
        } catch is CancellationError {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testDetectionTimesOutWhenOperationExceedsLimit() async {
        let tracker = ConcurrencyTracker()
        let manager = AudioFormatDetectionManager(maxConcurrentDetections: 1, timeout: 0.05)
        await manager.clearAdapters()

        let url = FileManager.default.temporaryDirectory.appendingPathComponent("timeout-test.flac")
        FileManager.default.createFile(atPath: url.path, contents: Data(), attributes: nil)

        let adapter = StubDetectionAdapter(tracker: tracker, delay: 0.2)
        await manager.registerAdapter(adapter)

        do {
            _ = try await manager.detectFormat(at: url)
            XCTFail("Expected timeout to throw")
        } catch DetectionError.timeout {
            XCTAssertTrue(true)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private actor ConcurrencyTracker {
    private var activeCount = 0
    private var maximumObserved = 0

    func begin() {
        activeCount += 1
        if activeCount > maximumObserved {
            maximumObserved = activeCount
        }
    }

    func end() {
        activeCount = max(0, activeCount - 1)
    }

    var maximum: Int {
        maximumObserved
    }
}

private struct StubDetectionAdapter: FormatDetectionAdapter {
    let supportedFormats: [AudioFormat] = [.flac]
    let tracker: ConcurrencyTracker
    let delay: TimeInterval

    func detectFormat(at url: URL) async throws -> AudioFileInfo {
        await tracker.begin()
        do {
            try Task.checkCancellation()
            let nanoseconds = UInt64(delay * 1_000_000_000)
            try await Task.sleep(nanoseconds: nanoseconds)

            let info = AudioFileInfo.create(
                url: url,
                format: .flac,
                sampleRate: 96000,
                bitDepth: 24,
                channels: 2,
                bitrate: 3_000_000,
                duration: 60,
                fileSize: 10_000_000,
            )

            await tracker.end()
            return info
        } catch {
            await tracker.end()
            throw error
        }
    }
}
