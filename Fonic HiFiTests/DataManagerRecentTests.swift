@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

@MainActor
final class DataManagerRecentTests: XCTestCase {
    private var container: ModelContainer!
    private var manager: DataManager!
    private var temporaryDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()

        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)

        let schema = Schema([
            Track.self,
            Album.self,
            Artist.self,
            Playlist.self,
            RecentSearch.self
        ])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        manager = DataManager(container: container, isFallback: false)
    }

    override func tearDownWithError() throws {
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        manager = nil
        container = nil
        temporaryDirectory = nil
        try super.tearDownWithError()
    }

    func testGetRecentlyAddedTracksReturnsNewestFirst() async throws {
        let baseDate = Date()
        for index in 0..<5 {
            try insertTrack(
                name: "Track-\(index)",
                dateAdded: baseDate.addingTimeInterval(Double(index) * 60)
            )
        }
        try manager.mainContext.save()

        let recent = try await manager.getRecentlyAddedTracks(limit: 3)
        XCTAssertEqual(recent.count, 3)
        XCTAssertEqual(recent.first?.title, "Track-4")
        XCTAssertEqual(recent.map(\.title), ["Track-4", "Track-3", "Track-2"])
    }

    func testGetRecentlyPlayedTracksFiltersByPlaybackDate() async throws {
        let baseDate = Date()

        try insertTrack(
            name: "NeverPlayed",
            dateAdded: baseDate,
            lastPlayed: nil
        )

        try insertTrack(
            name: "Yesterday",
            dateAdded: baseDate,
            lastPlayed: baseDate.addingTimeInterval(-86_400)
        )

        try insertTrack(
            name: "Today",
            dateAdded: baseDate,
            lastPlayed: baseDate
        )

        try manager.mainContext.save()

        let played = try await manager.getRecentlyPlayedTracks(limit: 5)
        XCTAssertEqual(played.count, 2)
        XCTAssertEqual(played.map(\.title), ["Today", "Yesterday"])
    }

    func testRecentSearchDelegationFlowsThroughActor() async throws {
        try await manager.addRecentSearch("ambient")
        try await manager.addRecentSearch("jazz")
        try await manager.updateSearchResultCount(query: "jazz", count: 8)

        var searches = try await manager.getRecentSearches(limit: 10)
        XCTAssertEqual(searches.count, 2)
        XCTAssertEqual(searches.first?.query, "jazz")
        XCTAssertEqual(searches.first?.resultCount, 8)

        try await manager.clearRecentSearches()
        searches = try await manager.getRecentSearches(limit: 5)
        XCTAssertTrue(searches.isEmpty)
    }

    private func insertTrack(name: String, dateAdded: Date, lastPlayed: Date? = nil) throws {
        let url = temporaryDirectory.appendingPathComponent("\(name).flac")
        let data = Data(repeating: 0xAB, count: 2048)
        try data.write(to: url)

        let track = Track(
            url: url,
            title: name,
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            duration: 180,
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            isLossless: true
        )

        track.dateAdded = dateAdded
        track.lastPlayed = lastPlayed
        manager.mainContext.insert(track)
    }
}
