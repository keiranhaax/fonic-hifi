import AVFoundation
import Dispatch
@testable import Fonic_HiFi
import Foundation
import OSLog
import XCTest

final class FormatDetectionServiceConcurrencyTests: XCTestCase {
    func testM4AACodecIsDetectedAsLossyAAC() async throws {
        let url = try makeM4AFixture(formatID: kAudioFormatMPEG4AAC)
        let info = try await AudioFormatDetectionManager().detectFormat(at: url)

        XCTAssertEqual(info.format, .aac)
        XCTAssertFalse(info.isLossless)
        XCTAssertEqual(info.codec, AudioFormat.aac.displayName)
        XCTAssertEqual(info.container, "m4a")
    }

    func testM4AAppleLosslessCodecIsDetectedAsALAC() async throws {
        let url = try makeM4AFixture(formatID: kAudioFormatAppleLossless)
        let info = try await AudioFormatDetectionManager().detectFormat(at: url)

        XCTAssertEqual(info.format, .alac)
        XCTAssertTrue(info.isLossless)
        XCTAssertEqual(info.codec, AudioFormat.alac.displayName)
        XCTAssertEqual(info.container, "m4a")
    }

    func testFLACFixtureHasDetectionAndPlaybackContract() async throws {
        let url = try makeEncodedFixture(
            base64: """
            ZkxhQwAAACISABIAAAS0AAS0CsRA8AAAETqzWeftMSRbinzlWHPdRSIDhAAALg0AAABMYXZmNjIuMTIuMTAxAQAAABUAAABlbmNv
            ZGVyPUxhdmY2Mi4xMi4xMDH/+HkIABE5jE4AAAEAAf8C/QP4BO4F4AbM5qevF1fzc7tHV69E4CXEEwAMknwz/8MucsOhnNJmSTTMn
            wmZJJyeE5CTycnknklzJpMmkyeZOczMyYTmQzJJMyE8hJJmScyZmUzmfPk4bMmfMl5JyScySTJMMyQ8k5kpCGzPDMk+UkzNySachy
            hOTKZOQzPJDmEyZCckyZyeSTknyZyTznOSmZzmSaSZ5MmSTmSTkmQ5kmUhmUyUyT85yfJzmTmeZyHkJ8kmSTJh5hk8mTyTmeSUk0y
            fmkmkl5kzSSeSHM5kmTJJOkJkyZJ4TOczmeTnJPnPJ5JmSSTJMkw5hOTyQmZkmchOyc/JmWeTaE8zJJ5kmTMnkJkycJJM5mck8meT
            zJMzMyyZz4fM85hnmZk8JMk5JzJJnmSaSSbmeczsk5NkmZMzTJmSSZJJ5JJOmSTMzOYefk9Jk2czs5M5IfhJ5M4eEyZCZMhkySeQl
            kmzzJkzMyeeTPyTzmSZycyZh5CTk5JOQzmZnhnYfkuw5OTDnJyTzmTOSTmSZkmSkkmZJlMmSdOekn+cmfJyT8kmZkkznIczyZMkpOc
            M8/mGZnzn5KTMw/OYZkmTJkmSSTknJyZk88yfz5M6ZJnJOzJyUMw85DkkhSGTMwzOSScklJJnzMyT8/JJc5nMw/kzSTOYTkyTJIfI
            ZKSZOTOTTmec0nkzknM5nTJnJMkmTMkkzJMnIZOZ5Mz+fM+Znw7k8mZJSSZ8JmTMkzJITkk2ckzPMyZNn+YT5OQzQzJMkyZmZkmZD
            MkySSehJk5JpJzzlMoWSnOcheSeQmcmSSTkkzJJJmZyZLJJ8M//DLnLDoZzSZkk0zJ8JmSScnhOQk8nJ5J5JcyaTJpMnmTnMzMmE5
            kMySTMhPISSZknMmZlM5nz5OGzJnzJeScknMkkyTDMkPJOZKQhszwzJPlJMzckmnIcoTkymTkMzyQ5hMmQnJMmcnkk5J8mck85zkpm
            c5kmkmeTJkk5kk5JkOZJlIZlMlMk/Ocnyc5k5nmch5CfJJkkyYeYZPJk8k5nklJNMn5pJpJeZM0knkhzOZJkySTpCZMmSeEznM5nk
            5yT5zyeSZkkkyTJMOYTk8kJmZJnITsnPyZlnk2hPMySeZJkzJ5CZMnCSTOZnJPJnk8yTMzMsmc+HzPOYZ5mZPCTJOScySZ5kmkkm5
            nnM7JOTZJmTM0yZkkmSSeSSTpkkzMzmHn5PSZNnM7OTOSH4SeTOHhMmQmTIZMknkJZJs8yZMzMnnkz8k85kmcnMmYeQk5OSTkM5mZ
            4Z2H5LsOTkw5yck85kzkk5kmZJkpJJmSZTJknTnpJ/nJnyck/JJmZJM5yHM8mTJKTnDPP5hmZ85+SkzMPzmGZJkyZJkkk5JycmZPPM
            n8+TOmSZyTsyclDMPOQ5JIUhkzMMzkknJJSSZ8zMk/PySXOZzMP5M0kzmE5MkySHyGSkmTkzk05nnNJ5M5JzOZ0yZyTJJkzJJMyTJ
            yGTmeTM/nzPmZ8O5PJmSUkmfCZkzJMySE5JNnJMzzMmTZ/mE+TkM0MyTJMmZmZJmQzJMkknoSZOSaSc85TKFkpznIXknkJnJkkk5JM
            ySSZmMCO
            """,
            fileExtension: "flac"
        )
        let detector = AudioFormatDetectionManager()
        let info = try await detector.detectFormat(at: url)
        let isSupported = await detector.isFormatSupported(.flac)

        XCTAssertEqual(info.format, .flac)
        XCTAssertTrue(info.isLossless)
        XCTAssertTrue(isSupported)
        XCTAssertTrue(AudioEngineType.audioKitEngine.canHandle(.flac))
    }

    func testValidUnsupportedOpusFixtureIsRejected() async throws {
        let url = try makeEncodedFixture(
            base64: """
            T2dnUwACAAAAAAAAAACYZTmIAAAAAFU5I4QBE09wdXNIZWFkAQE4AYC7AAAAAABPZ2dTAAAAAAAAAAAAAJhlOYgBAAAApAY1rgE+
            T3B1c1RhZ3MNAAAATGF2ZjYyLjEyLjEwMQEAAAAdAAAAZW5jb2Rlcj1MYXZjNjIuMjguMTAxIGxpYm9wdXNPZ2dTAAQYAwAAAAAA
            AJhlOYgCAAAAXtFgoAEHCAvmOyOrYA==
            """,
            fileExtension: "opus",
        )

        do {
            _ = try await AudioFormatDetectionManager().detectFormat(at: url)
            XCTFail("Expected a valid but unsupported Opus file to be rejected")
        } catch DetectionError.unknownFormat(let rejectedURL) {
            XCTAssertEqual(rejectedURL, url)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

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

    func testCoordinatorReleasesPermitImmediatelyAfterFailure() async {
        let coordinator = FormatDetectionCoordinator(
            maxConcurrentDetections: 1,
            timeout: nil,
            logger: Log.logger(.audioDetection)
        )

        let firstURL = FileManager.default.temporaryDirectory.appendingPathComponent("permit-first.flac")
        let secondURL = FileManager.default.temporaryDirectory.appendingPathComponent("permit-second.flac")

        let firstFinished = expectation(description: "First detection finished")
        let secondFinished = expectation(description: "Second detection finished")

        Task {
            do {
                _ = try await coordinator.performDetection(for: firstURL) {
                    try await Task.sleep(for: .milliseconds(100))
                    throw DetectionError.timeout
                }
                XCTFail("Expected first detection to fail")
            } catch {
                firstFinished.fulfill()
            }
        }

        Task {
            do {
                _ = try await coordinator.performDetection(for: secondURL) {
                    AudioFileInfo.create(
                        url: secondURL,
                        format: .flac,
                        sampleRate: 44_100,
                        bitDepth: 16,
                        channels: 2,
                        bitrate: 1_000_000,
                        duration: 30,
                        fileSize: 2_000_000
                    )
                }
                secondFinished.fulfill()
            } catch {
                XCTFail("Expected second detection to succeed: \(error)")
            }
        }

        await fulfillment(of: [firstFinished, secondFinished], timeout: 1.0)
    }

    private func makeM4AFixture(formatID: AudioFormatID) throws -> URL {
        try makeAudioFixture(formatID: formatID, fileExtension: "m4a")
    }

    private func makeAudioFixture(
        formatID: AudioFormatID,
        fileExtension: String
    ) throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        var settings: [String: Any] = [
            AVFormatIDKey: Int(formatID),
            AVSampleRateKey: 44_100,
            AVNumberOfChannelsKey: 2,
        ]
        if formatID == kAudioFormatMPEG4AAC {
            settings[AVEncoderBitRateKey] = 128_000
        } else {
            settings[AVEncoderBitDepthHintKey] = 16
        }

        let file = try AVAudioFile(
            forWriting: url,
            settings: settings,
            commonFormat: .pcmFormatFloat32,
            interleaved: false,
        )
        let buffer = try XCTUnwrap(
            AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: 4_410,
            ),
        )
        buffer.frameLength = 4_410
        try file.write(from: buffer)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
    }

    private func makeEncodedFixture(base64: String, fileExtension: String) throws -> URL {
        let data = try XCTUnwrap(
            Data(base64Encoded: base64, options: .ignoreUnknownCharacters),
        )
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension(fileExtension)
        try data.write(to: url, options: .atomic)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
        }
        return url
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
