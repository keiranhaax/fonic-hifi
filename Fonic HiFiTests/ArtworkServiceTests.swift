import Foundation
import SwiftData
import UIKit
import XCTest

@testable import Fonic_HiFi

@MainActor
final class ArtworkServiceTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var service: ArtworkService!
    private var tempDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        let schema = Schema(versionedSchema: SchemaV3.self)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        container = try ModelContainer(for: schema, configurations: [configuration])
        context = ModelContext(container)
        service = ArtworkService(container: container)

        tempDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    }

    override func tearDown() async throws {
        service?.clearCache()
        service = nil
        context = nil
        container = nil
        if let tempDirectory {
            try? FileManager.default.removeItem(at: tempDirectory)
        }
        tempDirectory = nil
        try await super.tearDown()
    }

    func testArtworkForTrackUsesCacheUntilCleared() async throws {
        let track = try makeTrack(
            title: "Track A",
            artist: "Artist A",
            album: "Album A",
            artwork: makePNGData(color: .systemBlue)
        )
        let originalData = track.artwork
        try context.save()

        let first = await service.artwork(for: track.id)
        XCTAssertEqual(first, originalData)

        track.artwork = makePNGData(color: .systemRed)
        let updatedData = track.artwork
        try context.save()

        let cached = await service.artwork(for: track.id)
        XCTAssertEqual(cached, originalData)

        service.clearCache()
        let refreshed = await service.artwork(for: track.id)
        XCTAssertEqual(refreshed, updatedData)
    }

    func testAlbumArtworkForMissingAlbumReturnsNil() async throws {
        try context.save()

        let result = await service.albumArtwork(for: UUID())

        XCTAssertNil(result)
    }

    func testAlbumArtworkByTitleAndArtistUsesCache() async throws {
        let track = try makeTrack(
            title: "Query Track",
            artist: "Query Artist",
            album: "Query Album",
            artwork: makePNGData(color: .systemPurple)
        )
        let originalData = track.artwork
        try context.save()

        let first = await service.albumArtwork(title: "Query Album", artist: "Query Artist")
        XCTAssertEqual(first, originalData)

        track.artwork = makePNGData(color: .black)
        let updatedData = track.artwork
        try context.save()

        let cached = await service.albumArtwork(title: "Query Album", artist: "Query Artist")
        XCTAssertEqual(cached, originalData)

        service.clearCache()
        let refreshed = await service.albumArtwork(title: "Query Album", artist: "Query Artist")
        XCTAssertEqual(refreshed, updatedData)
    }

    func testLoadArtworkDataDelegatesToTrackLookup() async throws {
        let track = try makeTrack(
            title: "Delegation Track",
            artist: "Delegation Artist",
            album: "Delegation Album",
            artwork: makePNGData(color: .brown)
        )
        try context.save()

        let direct = await service.artwork(for: track.id)
        service.clearCache()
        let viaAlias = await service.loadArtworkData(forTrackId: track.id)

        XCTAssertEqual(viaAlias, direct)
    }

    private func makeTrack(
        title: String,
        artist: String,
        album: String,
        artwork: Data
    ) throws -> Track {
        let fileURL = tempDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("flac")
        try Data(repeating: 0xAB, count: 1024).write(to: fileURL)

        let track = Track(
            url: fileURL,
            title: title,
            artist: artist,
            album: album,
            audioFormat: "FLAC",
            duration: 180,
            isLossless: true
        )
        track.albumArtist = artist
        track.artwork = artwork
        context.insert(track)
        return track
    }

    private func makePNGData(color: UIColor) -> Data {
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: 300, height: 300))
        let image = renderer.image { context in
            color.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 300, height: 300))
        }
        return image.pngData() ?? Data()
    }
}
