@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

@MainActor
final class LosslessBitDepthRepairTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        UserDefaults.standard.removeObject(forKey: DataManager.losslessBitDepthRepairDefaultsKey)
    }

    override func tearDown() async throws {
        UserDefaults.standard.removeObject(forKey: DataManager.losslessBitDepthRepairDefaultsKey)
        try await super.tearDown()
    }

    func testRepairUpdatesSourceDepthWithoutChangingIdentityOrUserState() async throws {
        let manager = try makeManager()
        let url = URL(filePath: "/lossless-repair/track.flac")
        let track = Track(
            url: url,
            title: "Source Depth",
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            duration: 120,
            sampleRate: 96_000,
            bitDepth: 32,
            channels: 2,
            isLossless: true
        )
        track.isFavorite = true
        track.playCount = 7
        let playlist = Playlist(name: "Keep Me")
        playlist.trackIds = [track.id]
        playlist.tracks = [track]
        manager.mainContext.insert(track)
        manager.mainContext.insert(playlist)
        try manager.mainContext.save()

        let detector = LosslessRepairFormatDetector(outcomes: [
            url: .success(.create(url: url, format: .flac, bitDepth: 24)),
        ])
        await manager.repairLosslessSourceBitDepthsIfNeeded(formatDetector: detector)

        XCTAssertTrue(UserDefaults.standard.bool(forKey: DataManager.losslessBitDepthRepairDefaultsKey))
        let context = ModelContext(manager.container)
        let repaired = try XCTUnwrap(context.fetch(FetchDescriptor<Track>()).first)
        XCTAssertEqual(repaired.id, track.id)
        XCTAssertEqual(repaired.bitDepth, 24)
        XCTAssertTrue(repaired.isFavorite)
        XCTAssertEqual(repaired.playCount, 7)
        XCTAssertEqual(repaired.playlists.first?.trackIds, [track.id])
    }

    func testRepairIncludesFLACAndALACButNotLossyM4A() async throws {
        let manager = try makeManager()
        let flac = Track(
            url: URL(filePath: "/lossless-repair/one.fixture"),
            title: "FLAC",
            artist: "Artist",
            album: "Album",
            audioFormat: "flac",
            bitDepth: 32
        )
        let alac = Track(
            url: URL(filePath: "/lossless-repair/two.m4a"),
            title: "ALAC",
            artist: "Artist",
            album: "Album",
            audioFormat: "Apple Lossless",
            bitDepth: 16
        )
        let aac = Track(
            url: URL(filePath: "/lossless-repair/three.m4a"),
            title: "AAC",
            artist: "Artist",
            album: "Album",
            audioFormat: "AAC",
            bitDepth: 16
        )
        [flac, alac, aac].forEach(manager.mainContext.insert)
        try manager.mainContext.save()

        let candidates = try await manager.trackDataActor.losslessBitDepthRepairCandidates(limit: 10)

        XCTAssertEqual(Set(candidates.map(\.trackID)), Set([flac.id, alac.id]))
    }

    func testFailureLeavesRepairPendingAndRetryable() async throws {
        let manager = try makeManager()
        let firstURL = URL(filePath: "/lossless-repair/first.flac")
        let secondURL = URL(filePath: "/lossless-repair/second.flac")
        let first = Track(
            url: firstURL,
            title: "First",
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            bitDepth: 32
        )
        let second = Track(
            url: secondURL,
            title: "Second",
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            bitDepth: 32
        )
        manager.mainContext.insert(first)
        manager.mainContext.insert(second)
        try manager.mainContext.save()

        let firstAttempt = LosslessRepairFormatDetector(outcomes: [
            firstURL: .failure,
            secondURL: .success(.create(url: secondURL, format: .flac, bitDepth: 16)),
        ])
        await manager.repairLosslessSourceBitDepthsIfNeeded(formatDetector: firstAttempt)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: DataManager.losslessBitDepthRepairDefaultsKey))

        let retry = LosslessRepairFormatDetector(outcomes: [
            firstURL: .success(.create(url: firstURL, format: .flac, bitDepth: 24)),
            secondURL: .success(.create(url: secondURL, format: .flac, bitDepth: 16)),
        ])
        await manager.repairLosslessSourceBitDepthsIfNeeded(formatDetector: retry)

        XCTAssertTrue(UserDefaults.standard.bool(forKey: DataManager.losslessBitDepthRepairDefaultsKey))
        let tracks = try ModelContext(manager.container).fetch(FetchDescriptor<Track>())
        XCTAssertEqual(tracks.first { $0.id == first.id }?.bitDepth, 24)
        XCTAssertEqual(tracks.first { $0.id == second.id }?.bitDepth, 16)
    }

    func testReadOnlyRecoveryDoesNotScanOrMarkRepairComplete() async throws {
        let manager = try makeManager(mutationPolicy: .readOnly)
        let url = URL(filePath: "/lossless-repair/read-only.flac")
        let track = Track(
            url: url,
            title: "Read Only",
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            bitDepth: 32
        )
        manager.mainContext.insert(track)
        try manager.mainContext.save()
        let detector = LosslessRepairFormatDetector(outcomes: [
            url: .success(.create(url: url, format: .flac, bitDepth: 24)),
        ])

        await manager.repairLosslessSourceBitDepthsIfNeeded(formatDetector: detector)

        XCTAssertFalse(UserDefaults.standard.bool(forKey: DataManager.losslessBitDepthRepairDefaultsKey))
        let detectionCount = await detector.detectionCount
        XCTAssertEqual(detectionCount, 0)
        let stored = try XCTUnwrap(ModelContext(manager.container).fetch(FetchDescriptor<Track>()).first)
        XCTAssertEqual(stored.bitDepth, 32)
    }

    private func makeManager(mutationPolicy: DataMutationPolicy = .normal) throws -> DataManager {
        let schema = Schema([
            Track.self,
            Album.self,
            Artist.self,
            Playlist.self,
            RecentSearch.self,
            ListeningSession.self,
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return DataManager(container: container, isFallback: false, mutationPolicy: mutationPolicy)
    }
}

private actor LosslessRepairFormatDetector: FormatDetectionService {
    enum Outcome: Sendable {
        case success(AudioFileInfo)
        case failure
    }

    private let outcomes: [URL: Outcome]
    private(set) var detectionCount = 0

    init(outcomes: [URL: Outcome]) {
        self.outcomes = outcomes
    }

    func detectFormat(at url: URL) async throws -> AudioFileInfo {
        detectionCount += 1
        guard let outcome = outcomes[url] else { throw LosslessRepairTestError.missing }
        switch outcome {
        case let .success(info):
            return info
        case .failure:
            throw LosslessRepairTestError.failure
        }
    }

    func validateFile(at url: URL) async -> Bool {
        (try? await detectFormat(at: url)) != nil
    }

    func isFormatSupported(_ format: AudioFormat) -> Bool {
        format == .flac || format == .alac
    }

    func getFormatCapabilities(_ format: AudioFormat) -> FormatCapabilities? {
        guard isFormatSupported(format) else { return nil }
        return FormatCapabilities(
            maxSampleRate: 384_000,
            maxBitDepth: 32,
            supportsMultiChannel: true,
            supportsArtwork: true,
            supportsChapters: false,
            requiresSpecializedDecoder: false
        )
    }
}

private enum LosslessRepairTestError: Error {
    case missing
    case failure
}
