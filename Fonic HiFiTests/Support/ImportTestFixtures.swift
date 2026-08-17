@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

@MainActor
struct ImportTestEnvironment {
    let service: LibraryImportService
    let container: ModelContainer
    let trackActor: TrackDataActor
    let invalidationCount: () -> Int
}

@MainActor
func makeImportTestEnvironment(
    metadataExtractor: MetadataExtracting = TestMetadataExtractor(),
    fileProcessingConcurrency: Int = 2,
    isStoredInMemoryOnly: Bool = true,
    musicContainerURL: URL? = nil
) throws -> ImportTestEnvironment {
    let schema = Schema([Track.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: isStoredInMemoryOnly)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let trackActor = TrackDataActor(modelContainer: container)

    var invalidations = 0
    let fileProcessor = FileImportProcessor(
        trackDataActor: trackActor,
        metadataExtractor: metadataExtractor,
        musicContainerURL: musicContainerURL
    )
    let service = LibraryImportService(
        fileProcessor: fileProcessor,
        fileProcessingConcurrency: fileProcessingConcurrency,
        statisticsInvalidator: { invalidations += 1 }
    )

    return ImportTestEnvironment(
        service: service,
        container: container,
        trackActor: trackActor,
        invalidationCount: { invalidations }
    )
}

func makeTemporaryTestDirectory(
    named name: String,
    testCase: XCTestCase
) throws -> URL {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(name, isDirectory: true)
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    testCase.addTeardownBlock {
        try? FileManager.default.removeItem(at: directory)
    }

    return directory
}

func makeTemporaryAudioFiles(
    count: Int,
    prefix: String = "track",
    sizeMultiplier: Int = 1,
    testCase: XCTestCase
) throws -> [URL] {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

    var urls: [URL] = []
    urls.reserveCapacity(count)

    for index in 0..<count {
        let url = directory.appendingPathComponent("\(prefix)\(index).wav")
        let frameCount = max(441, (index + 1) * sizeMultiplier * 256)
        try makeValidPCMTestWAVData(frameCount: frameCount).write(to: url)
        urls.append(url)
    }

    testCase.addTeardownBlock {
        try? FileManager.default.removeItem(at: directory)
    }

    return urls
}

func makeNestedAudioDirectory(
    fileCountPerFolder: Int,
    depth: Int,
    branchingFactor: Int = 2,
    duplicateCount: Int = 0,
    testCase: XCTestCase
) throws -> (root: URL, totalFiles: Int, duplicateCandidates: [URL]) {
    precondition(fileCountPerFolder > 0 && depth > 0)

    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    let fileManager = FileManager.default
    try fileManager.createDirectory(at: root, withIntermediateDirectories: true)

    var audioFiles: [URL] = []

    func populate(directory: URL, remainingDepth: Int, branchIndex: Int) throws {
        for index in 0..<fileCountPerFolder {
            let audioURL = directory.appendingPathComponent("track_\(remainingDepth)_\(branchIndex)_\(index).wav")
            let sizeSeed = remainingDepth * (index + 1)
            let frameCount = max(441, (sizeSeed + 1) * 256)
            try makeValidPCMTestWAVData(frameCount: frameCount).write(to: audioURL)
            audioFiles.append(audioURL)
        }

        let ignoredURL = directory.appendingPathComponent("note_\(remainingDepth)_\(branchIndex).txt")
        try Data("ignore".utf8).write(to: ignoredURL)

        guard remainingDepth > 1 else { return }

        for childIndex in 0..<branchingFactor {
            let child = directory.appendingPathComponent("folder_\(remainingDepth)_\(branchIndex)_\(childIndex)", isDirectory: true)
            try fileManager.createDirectory(at: child, withIntermediateDirectories: true)
            try populate(directory: child, remainingDepth: remainingDepth - 1, branchIndex: childIndex)
        }
    }

    try populate(directory: root, remainingDepth: depth, branchIndex: 0)

    testCase.addTeardownBlock {
        try? fileManager.removeItem(at: root)
    }

    let duplicateCandidates = Array(audioFiles.prefix(min(duplicateCount, audioFiles.count)))
    return (root, audioFiles.count, duplicateCandidates)
}

/// Writes a small, valid little-endian PCM WAV payload for import tests.
///
/// Import tests must exercise media validation and never rely on arbitrary bytes
/// renamed with an audio extension. The payload is intentionally silent so the
/// fixture remains deterministic while still being decodable by AVFoundation.
func makeValidPCMTestWAVData(
    sampleRate: UInt32 = 44_100,
    channels: UInt16 = 2,
    frameCount: Int = 4_410,
) -> Data {
    let bytesPerSample = MemoryLayout<Int16>.size
    let dataSize = UInt32(frameCount * Int(channels) * bytesPerSample)
    let riffSize = 36 + dataSize
    let byteRate = sampleRate * UInt32(channels) * UInt32(bytesPerSample)
    let blockAlign = channels * UInt16(bytesPerSample)

    var data = Data()

    func appendASCII(_ value: String) {
        data.append(contentsOf: value.utf8)
    }

    func appendLittleEndian<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { bytes in
            data.append(contentsOf: bytes)
        }
    }

    appendASCII("RIFF")
    appendLittleEndian(riffSize)
    appendASCII("WAVE")
    appendASCII("fmt ")
    appendLittleEndian(UInt32(16))
    appendLittleEndian(UInt16(1))
    appendLittleEndian(channels)
    appendLittleEndian(sampleRate)
    appendLittleEndian(byteRate)
    appendLittleEndian(blockAlign)
    appendLittleEndian(UInt16(16))
    appendASCII("data")
    appendLittleEndian(dataSize)
    data.append(contentsOf: repeatElement(UInt8(0), count: Int(dataSize)))

    return data
}

@MainActor
func seedTracks(in environment: ImportTestEnvironment, from urls: [URL]) async throws {
    guard !urls.isEmpty else { return }

    let extractor = TestMetadataExtractor()
    for url in urls {
        let metadata = try await extractor.extractTrackMetadata(from: url)
        let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
        let enriched = metadata.withSourceInfo(
            sourceURL: url,
            sourceBookmark: bookmark
        )
        _ = try await environment.trackActor.createTrack(from: enriched)
    }
}

@MainActor
func waitUntil(_ predicate: @escaping () -> Bool, timeout: TimeInterval = 2) async throws {
    let deadline = Date().addingTimeInterval(timeout)
    while Date() < deadline {
        if predicate() { return }
        try await Task.sleep(nanoseconds: 20_000_000)
    }
    throw XCTestError(.timeoutWhileWaiting)
}

@MainActor
func waitForCancellation(_ service: LibraryImportService, timeout: TimeInterval = 2) async throws {
    try await waitUntil({ service.isImporting == false && service.statusMessage == "Import cancelled" }, timeout: timeout)
}

struct TestMetadataExtractor: MetadataExtracting {
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
            bitrate: 2_000_000,
            channels: 2,
            isLossless: true
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

struct SlowMetadataExtractor: MetadataExtracting {
    let delay: TimeInterval

    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
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
