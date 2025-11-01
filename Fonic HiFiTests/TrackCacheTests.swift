@testable import Fonic_HiFi
import XCTest

final class TrackCacheTests: XCTestCase {
    func testAddAndRetrieveTrack() async {
        let cache = TrackCache(maxSize: 4)
        let track = makeTrack(id: UUID())

        await cache.addTrack(track)
        let retrieved = await cache.getTrack(track.id)

        XCTAssertEqual(retrieved?.title, track.title)
    }

    func testRemoveTrackEvictsSpecificEntry() async {
        let cache = TrackCache(maxSize: 3)
        let keep = makeTrack(id: UUID())
        let remove = makeTrack(id: UUID())

        await cache.addTrack(keep)
        await cache.addTrack(remove)

        await cache.removeTrack(remove.id)

        let removed = await cache.getTrack(remove.id)
        let remaining = await cache.getTrack(keep.id)

        XCTAssertNil(removed)
        XCTAssertNotNil(remaining)
    }

    func testEvictionRemovesLeastRecentlyUsed() async {
        let cache = TrackCache(maxSize: 2)
        let first = makeTrack(id: UUID())
        let second = makeTrack(id: UUID())
        let third = makeTrack(id: UUID())

        await cache.addTrack(first)
        await cache.addTrack(second)
        _ = await cache.getTrack(first.id)
        await cache.addTrack(third)

        let missing = await cache.getTrack(second.id)
        XCTAssertNil(missing)
        let remaining = await cache.getTrack(first.id)
        XCTAssertNotNil(remaining)
    }

    func testPruneOldEntriesRemovesStaleTracks() async {
        let cache = TrackCache(maxSize: 5)
        let oldTrack = makeTrack(id: UUID())
        await cache.addTrack(oldTrack)

        try? await Task.sleep(nanoseconds: 120_000_000)

        let recentTrack = makeTrack(id: UUID())
        await cache.addTrack(recentTrack)

        await cache.pruneOldEntries(olderThan: 0.05)

        let oldResult = await cache.getTrack(oldTrack.id)
        let recentResult = await cache.getTrack(recentTrack.id)

        XCTAssertNil(oldResult)
        XCTAssertNotNil(recentResult)
    }

    func testStatisticsReflectCacheState() async {
        let cache = TrackCache(maxSize: 3)
        let tracks = (0..<3).map { _ in makeTrack(id: UUID()) }
        for track in tracks {
            await cache.addTrack(track)
        }

        let stats = await cache.getStatistics()

        XCTAssertEqual(stats.count, 3)
        XCTAssertGreaterThan(stats.totalSizeBytes, 0)
        XCTAssertGreaterThan(stats.averageAccessCount, 0)
    }

    func testClearRemovesAllTracks() async {
        let cache = TrackCache(maxSize: 3)
        let tracks = (0..<2).map { _ in makeTrack(id: UUID()) }

        await cache.addTracks(tracks)
        await cache.clear()

        let stats = await cache.getStatistics()
        XCTAssertEqual(stats.count, 0)
        XCTAssertEqual(stats.totalSizeBytes, 0)
        XCTAssertEqual(stats.fillPercentage, 0)
    }

    func testBatchOperationsReturnExpectedResults() async {
        let cache = TrackCache(maxSize: 5)
        let ids = (0..<4).map { _ in UUID() }
        let tracks = ids.map { makeTrack(id: $0) }

        await cache.addTracks(tracks)
        let subset = await cache.getTracks([ids[0], ids[2], UUID()])

        XCTAssertEqual(subset.count, 2)
        XCTAssertNotNil(subset[ids[0]])
        XCTAssertNotNil(subset[ids[2]])

        // Multiple accesses inflate average access count
        _ = await cache.getTrack(ids[0])
        _ = await cache.getTrack(ids[2])

        let stats = await cache.getStatistics()
        XCTAssertGreaterThan(stats.averageAccessCount, 1)
    }
}

private func makeTrack(id: UUID) -> TrackCache.TrackCacheData {
    TrackCache.TrackCacheData(
        id: id,
        title: "Track-\(id.uuidString.prefix(6))",
        artist: "Artist",
        album: "Album",
        duration: 240,
        url: URL(fileURLWithPath: "/tmp/\(id.uuidString).flac"),
        fileSize: 4_000_000
    )
}
