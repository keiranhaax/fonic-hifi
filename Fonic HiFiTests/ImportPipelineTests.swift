@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

final class ImportPipelineTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none,
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func makeTemporaryAudioFiles(count: Int) throws -> [URL] {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        var urls: [URL] = []
        for index in 0 ..< count {
            let url = directory.appendingPathComponent("test-track-\(index).flac")
            try Data("test-data".utf8).write(to: url)
            urls.append(url)
        }

        return urls
    }

    func testTrackExistsMatchesEquivalentSourceURL() async throws {
        let container = try makeInMemoryContainer()
        let trackDataActor = TrackDataActor(modelContainer: container)

        let basePath = (NSTemporaryDirectory() as NSString).appendingPathComponent("Import/Library")
        let originalURL = URL(fileURLWithPath: basePath)
            .appendingPathComponent("Track.flac")
        let equivalentURL = URL(fileURLWithPath: basePath.uppercased())
            .appendingPathComponent("TRACK.FLAC")
        let storedURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("storage/Track.flac")

        let metadata = TrackMetadata(
            url: storedURL,
            title: "Test Track",
            artist: "Test Artist",
            album: "Test Album",
            audioFormat: "FLAC",
            duration: 120,
            sampleRate: 44100,
            bitDepth: 16,
            channels: 2,
            isLossless: true,
            sourceURL: originalURL,
            sourceBookmark: nil,
            sourceURLHash: originalURL.librarySourceHash(),
        )

        let trackId = try await trackDataActor.createTrack(from: metadata)

        let existing = try await trackDataActor.trackExists(for: equivalentURL)
        XCTAssertEqual(existing, trackId)

        let differentURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("import/Other/Track.flac")
        let nonExisting = try await trackDataActor.trackExists(for: differentURL)
        XCTAssertNil(nonExisting)
    }

    func testTrackExistsMatchesBookmarkHash() async throws {
        let container = try makeInMemoryContainer()
        let trackDataActor = TrackDataActor(modelContainer: container)

        let originalURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("import/original/Track.flac")
        let storedURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("storage/Track.flac")
        let bookmarkData = Data("sample-bookmark".utf8)

        let metadata = TrackMetadata(
            url: storedURL,
            title: "Bookmark Track",
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            duration: 200,
            sampleRate: 48_000,
            bitDepth: 24,
            channels: 2,
            isLossless: true,
            sourceURL: originalURL,
            sourceBookmark: bookmarkData,
            sourceURLHash: originalURL.librarySourceHash(),
            sourceBookmarkHash: bookmarkData.sha256Hex()
        )

        let trackId = try await trackDataActor.createTrack(from: metadata)

        let newImportURL = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("reimport/new-location/Track.flac")
        let duplicate = try await trackDataActor.trackExists(for: newImportURL, bookmark: bookmarkData)
        XCTAssertEqual(duplicate, trackId)

        let otherBookmark = Data("other-bookmark".utf8)
        let notDuplicate = try await trackDataActor.trackExists(for: newImportURL, bookmark: otherBookmark)
        XCTAssertNil(notDuplicate)
    }

    func testDiscoverAudioFilesReleasesSecurityScope() async throws {
        let container = try makeInMemoryContainer()
        let trackDataActor = TrackDataActor(modelContainer: container)
        let metadataExtractor = await MainActor.run {
            MetadataExtractionService(formatDetectionService: DummyFormatDetectionService())
        }
        let securityAccessor = MockSecurityScopedAccessor()
        let processor = FileImportProcessor(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor,
            securityAccessor: securityAccessor,
        )

        let tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)

        let audioFile = tempDirectory.appendingPathComponent("sample.flac")
        try Data([0x00, 0x01, 0x02]).write(to: audioFile)

        let discovered = await processor.discoverAudioFiles(from: [tempDirectory])
        XCTAssertEqual(discovered.count, 1)
        XCTAssertEqual(securityAccessor.startCount, securityAccessor.stopCount)
        XCTAssertGreaterThan(securityAccessor.startCount, 0)

        try? FileManager.default.removeItem(at: tempDirectory)
    }

    @MainActor
    func testStreamedImportProcessesAllFiles() async throws {
        let container = try makeInMemoryContainer()
        let trackDataActor = TrackDataActor(modelContainer: container)
        let concurrencyTracker = ConcurrencyTracker()
        let metadataExtractor = MockMetadataExtractor(tracker: concurrencyTracker)
        var invalidationCount = 0

        let importService = LibraryImportService(
            trackDataActor: trackDataActor,
            metadataExtractor: metadataExtractor,
            fileProcessingConcurrency: 2,
            statisticsInvalidator: {
                invalidationCount += 1
            }
        )

        let urls = try makeTemporaryAudioFiles(count: 6)
        let directory = urls.first?.deletingLastPathComponent()
        defer {
            if let directory {
                try? FileManager.default.removeItem(at: directory)
            }
        }

        await importService.executeImportPipeline(urls: urls)

        XCTAssertEqual(importService.totalFiles, urls.count)
        XCTAssertEqual(importService.filesProcessed, urls.count)
        XCTAssertEqual(importService.recentlyImported.count, urls.count)
        XCTAssertTrue(importService.importErrors.isEmpty)
        XCTAssertEqual(invalidationCount, 1)
        XCTAssertEqual(importService.importProgress, 1.0, accuracy: 0.0001)

        let trackCount = try await trackDataActor.getTracksCount()
        XCTAssertEqual(trackCount, urls.count)

        let maxConcurrency = await concurrencyTracker.maxConcurrent()
        XCTAssertLessThanOrEqual(maxConcurrency, 2)
    }

    func testProcessFilesStreamEmitsMixedResults() async throws {
        let container = try makeInMemoryContainer()
        let trackDataActor = TrackDataActor(modelContainer: container)
        let extractor = StubMetadataExtractor { url in
            if url.lastPathComponent.contains("fail") {
                throw StubExtractionError.failure
            }
            return makeMetadata(for: url)
        }
        let securityAccessor = MockSecurityScopedAccessor()
        let processor = FileImportProcessor(
            trackDataActor: trackDataActor,
            metadataExtractor: extractor,
            securityAccessor: securityAccessor
        )

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let successFile = try makeDiscoveredAudioFile(name: "success.flac", in: directory)
        let failingFile = try makeDiscoveredAudioFile(name: "fail.flac", in: directory)

        let stream = await processor.processFilesStream([successFile, failingFile], maxConcurrentTasks: 2)
        var successes = 0
        var failures = 0
        for await result in stream {
            if result.succeeded {
                successes += 1
            } else {
                failures += 1
                XCTAssertEqual(result.error?.message, StubExtractionError.failure.localizedDescription)
            }
        }

        XCTAssertEqual(successes, 1)
        XCTAssertEqual(failures, 1)
        XCTAssertGreaterThan(securityAccessor.startCount, 0)
        XCTAssertEqual(securityAccessor.startCount, securityAccessor.stopCount)

        let trackCount = try await trackDataActor.getTracksCount()
        XCTAssertEqual(trackCount, 1)

        try? cleanupMusicContainer()
        try? FileManager.default.removeItem(at: directory)
    }

    func testProcessFilesStreamSkipsDuplicateImports() async throws {
        let container = try makeInMemoryContainer()
        let trackDataActor = TrackDataActor(modelContainer: container)
        let extractor = StubMetadataExtractor { url in makeMetadata(for: url) }
        let securityAccessor = MockSecurityScopedAccessor()
        let processor = FileImportProcessor(
            trackDataActor: trackDataActor,
            metadataExtractor: extractor,
            securityAccessor: securityAccessor
        )

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let audioFile = try makeDiscoveredAudioFile(name: "duplicate.flac", in: directory)

        let initialStream = await processor.processFilesStream([audioFile], maxConcurrentTasks: 1)
        var initialResults: [FileImportProcessor.ProcessedFileResult] = []
        for await result in initialStream {
            initialResults.append(result)
        }
        XCTAssertEqual(initialResults.count, 1)
        XCTAssertTrue(initialResults.first?.succeeded ?? false)

        let duplicateStream = await processor.processFilesStream([audioFile], maxConcurrentTasks: 1)
        var duplicateResults: [FileImportProcessor.ProcessedFileResult] = []
        for await result in duplicateStream {
            duplicateResults.append(result)
        }

        XCTAssertEqual(duplicateResults.count, 1)
        XCTAssertFalse(duplicateResults.first?.succeeded ?? true)
        XCTAssertTrue(duplicateResults.first?.isDuplicate ?? false)
        XCTAssertNil(duplicateResults.first?.error)

        let trackCount = try await trackDataActor.getTracksCount()
        XCTAssertEqual(trackCount, 1)

        try? cleanupMusicContainer()
        try? FileManager.default.removeItem(at: directory)
    }
}

private actor DummyFormatDetectionService: FormatDetectionService {
    func detectFormat(at url: URL) async throws -> AudioFileInfo {
        throw DetectionError.unknownFormat(url)
    }

    func validateFile(at _: URL) async -> Bool {
        true
    }

    func isFormatSupported(_: AudioFormat) -> Bool {
        true
    }

    func getFormatCapabilities(_: AudioFormat) -> FormatCapabilities? {
        nil
    }
}

private actor ConcurrencyTracker {
    private var current = 0
    private var maxObserved = 0

    func begin() {
        current += 1
        if current > maxObserved {
            maxObserved = current
        }
    }

    func end() {
        current = max(0, current - 1)
    }

    func maxConcurrent() -> Int {
        maxObserved
    }
}

private final class MockMetadataExtractor: MetadataExtracting {
    private let tracker: ConcurrencyTracker

    init(tracker: ConcurrencyTracker) {
        self.tracker = tracker
    }

    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        try await withTaskCancellationHandler(operation: {
            await tracker.begin()
            try await Task.sleep(nanoseconds: 5_000_000)

            let metadata = TrackMetadata(
                url: url,
                title: url.lastPathComponent,
                artist: "Test Artist",
                album: "Test Album",
                albumArtist: nil,
                genre: nil,
                year: nil,
                trackNumber: nil,
                discNumber: nil,
                composer: nil,
                conductor: nil,
                audioFormat: "FLAC",
                duration: 120,
                sampleRate: 48_000,
                bitDepth: 24,
                bitrate: 1_411_000,
                channels: 2,
                isLossless: true,
                artwork: nil,
                lyrics: nil,
                comment: nil
            )

            await tracker.end()
            return metadata
        }, onCancel: {
            Task { await self.tracker.end() }
        })
    }

    func extractMetadata(from urls: [URL], maxConcurrentTasks: Int) async throws -> [TrackMetadata] {
        try await withThrowingTaskGroup(of: TrackMetadata.self) { group in
            for url in urls {
                group.addTask { try await self.extractTrackMetadata(from: url) }
            }

            var results: [TrackMetadata] = []
            for try await metadata in group {
                results.append(metadata)
            }
            return results
        }
    }
}

private final class MockSecurityScopedAccessor: SecurityScopedAccessing, @unchecked Sendable {
    private let lock = NSLock()
    private(set) var startCount: Int = 0
    private(set) var stopCount: Int = 0

    func startAccessing(_: URL) -> Bool {
        lock.lock()
        startCount += 1
        lock.unlock()
        return true
    }

    func stopAccessing(_: URL) {
        lock.lock()
        stopCount += 1
        lock.unlock()
    }
}

private actor StubMetadataExtractor: MetadataExtracting {
    private let behavior: @Sendable (URL) throws -> TrackMetadata

    init(behavior: @escaping @Sendable (URL) throws -> TrackMetadata) {
        self.behavior = behavior
    }

    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        try behavior(url)
    }

    func extractMetadata(from urls: [URL], maxConcurrentTasks: Int) async throws -> [TrackMetadata] {
        try urls.map { try behavior($0) }
    }
}

private enum StubExtractionError: LocalizedError {
    case failure

    var errorDescription: String? { "Stub extraction failure" }
}

private func makeMetadata(for url: URL) -> TrackMetadata {
    TrackMetadata(
        url: url,
        title: url.deletingPathExtension().lastPathComponent,
        artist: "Artist",
        album: "Album",
        audioFormat: "FLAC",
        duration: 180,
        sampleRate: 48_000,
        bitDepth: 24,
        bitrate: 1_411_000,
        channels: 2,
        isLossless: true
    )
}

private func makeDiscoveredAudioFile(name: String, in directory: URL) throws -> FileImportProcessor.DiscoveredAudioFile {
    let url = directory.appendingPathComponent(name)
    try Data("test-data".utf8).write(to: url)
    return FileImportProcessor.DiscoveredAudioFile(originalURL: url, securityScopedBookmark: nil)
}

private func cleanupMusicContainer() throws {
    if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
        let musicURL = documentsURL.appendingPathComponent("Music", isDirectory: true)
        if FileManager.default.fileExists(atPath: musicURL.path) {
            try FileManager.default.removeItem(at: musicURL)
        }
    }
}
