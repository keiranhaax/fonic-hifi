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
    fileProcessingConcurrency: Int = 2
) throws -> ImportTestEnvironment {
    let schema = Schema([Track.self])
    let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try ModelContainer(for: schema, configurations: [configuration])
    let trackActor = TrackDataActor(modelContainer: container)

    var invalidations = 0
    let service = LibraryImportService(
        trackDataActor: trackActor,
        metadataExtractor: metadataExtractor,
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
        let url = directory.appendingPathComponent("\(prefix)\(index).flac")
        let byteCount = max(1024, (index + 1) * sizeMultiplier * 256)
        let data = Data(repeating: UInt8((index + 31) % 255), count: byteCount)
        try data.write(to: url)
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
            let audioURL = directory.appendingPathComponent("track_\(remainingDepth)_\(branchIndex)_\(index).flac")
            let sizeSeed = remainingDepth * (index + 1)
            let byteCount = max(1024, (sizeSeed + 1) * 768)
            let data = Data(repeating: UInt8((sizeSeed + 17) % 255), count: byteCount)
            try data.write(to: audioURL)
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
        try await urls.asyncMap { try await extractTrackMetadata(from: $0) }
    }
}

struct SlowMetadataExtractor: MetadataExtracting {
    let delay: TimeInterval

    func extractTrackMetadata(from url: URL) async throws -> TrackMetadata {
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        return try await TestMetadataExtractor().extractTrackMetadata(from: url)
    }

    func extractMetadata(from urls: [URL], maxConcurrentTasks: Int) async throws -> [TrackMetadata] {
        try await urls.asyncMap { try await extractTrackMetadata(from: $0) }
    }
}

extension Array {
    func asyncMap<T>(_ transform: (Element) async throws -> T) async rethrows -> [T] {
        var result: [T] = []
        result.reserveCapacity(count)
        for element in self {
            result.append(try await transform(element))
        }
        return result
    }
}
