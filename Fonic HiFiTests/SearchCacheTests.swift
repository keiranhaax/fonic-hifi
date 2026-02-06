@testable import Fonic_HiFi
import XCTest

final class SearchCacheTests: XCTestCase {
    func testQueryNormalizationEnablesCaseInsensitiveLookups() async {
        let cache = SearchCache(ttl: 60)
        await cache.set("Lo-Fi Mix", result: .init(query: "lo-fi mix"))

        let cached = await cache.get("LO-FI MIX")
        XCTAssertNotNil(cached)
        XCTAssertEqual(cached?.query, "lo-fi mix")
    }

    func testGetReturnsNilAfterEntryExpires() async {
        let cache = SearchCache(ttl: 10)
        let staleTimestamp = Date().addingTimeInterval(-20)

        await cache.set("ambient", result: .init(query: "ambient", timestamp: staleTimestamp))

        let cached = await cache.get("ambient")
        XCTAssertNil(cached)
    }

    func testUpdateTracksRefreshesExistingEntry() async {
        let cache = SearchCache(ttl: 60)
        let initialAlbums = [SearchCache.CachedAlbum(id: UUID(), title: "Intro", artistName: "Artist", trackCount: 1)]
        await cache.set("jazz", result: .init(query: "jazz", albums: initialAlbums))

        let tracks = [
            Track(
                url: URL(fileURLWithPath: "/tmp/a.flac"),
                title: "A",
                artist: "Artist",
                album: "Album",
                audioFormat: "FLAC",
                duration: 200,
                sampleRate: 96_000,
                bitDepth: 24,
                channels: 2,
                isLossless: true
            ),
            Track(
                url: URL(fileURLWithPath: "/tmp/b.flac"),
                title: "B",
                artist: "Artist",
                album: "Album",
                audioFormat: "FLAC",
                duration: 180,
                sampleRate: 96_000,
                bitDepth: 24,
                channels: 2,
                isLossless: true
            ),
        ]

        await cache.updateTracks("jazz", tracks: tracks)

        let cached = await cache.get("jazz")
        XCTAssertEqual(cached?.tracks.count, 2)
        XCTAssertEqual(cached?.albums.count, 1)
        XCTAssertEqual(cached?.albums.first?.title, "Intro")
    }

    func testInvalidateExpiredRemovesOnlyStaleEntries() async {
        let cache = SearchCache(ttl: 5)
        await cache.set("old", result: .init(query: "old", timestamp: Date().addingTimeInterval(-20)))
        await cache.set("fresh", result: .init(query: "fresh", timestamp: Date()))

        await cache.invalidateExpired()

        let old = await cache.get("old")
        let fresh = await cache.get("fresh")

        XCTAssertNil(old)
        XCTAssertNotNil(fresh)
    }

    func testCacheTrimKeepsMostRecentEntries() async {
        let cache = SearchCache(ttl: 120, maxCacheSize: 2)
        await cache.set("one", result: .init(query: "one", timestamp: Date().addingTimeInterval(-30)))
        await cache.set("two", result: .init(query: "two", timestamp: Date().addingTimeInterval(-20)))
        await cache.set("three", result: .init(query: "three", timestamp: Date()))

        let stats = await cache.getStatistics()
        let latest = await cache.get("three")

        XCTAssertEqual(stats.entryCount, 1)
        XCTAssertEqual(stats.newestEntry?.timeIntervalSince1970.rounded(), stats.oldestEntry?.timeIntervalSince1970.rounded())
        XCTAssertNotNil(latest)
    }

    func testInvalidateRemovesSpecificEntry() async {
        let cache = SearchCache(ttl: 30)
        await cache.set("ambient", result: .init(query: "ambient"))
        await cache.set("jazz", result: .init(query: "jazz"))

        await cache.invalidate("ambient")

        let ambient = await cache.get("ambient")
        let jazz = await cache.get("jazz")

        XCTAssertNil(ambient)
        XCTAssertNotNil(jazz)
    }

    func testClearEmptiesCacheAndStatistics() async {
        let cache = SearchCache(ttl: 60)
        await cache.set("a", result: .init(query: "a", tracks: [.init(id: UUID(), title: "T", artist: "A", album: "B", duration: 10)]))
        await cache.set("b", result: .init(query: "b"))

        await cache.clear()

        let stats = await cache.getStatistics()
        XCTAssertEqual(stats.entryCount, 0)
        XCTAssertTrue(stats.isEmpty)
        XCTAssertEqual(stats.cacheEfficiency, 0)
        XCTAssertEqual(stats.cacheFreshnessDescription, "No cache entries")
    }

    func testStatisticsReportExpiredEntriesAndEfficiency() async {
        let cache = SearchCache(ttl: 10)
        let oldDate = Date().addingTimeInterval(-30)
        let freshDate = Date()
        let tracks = [SearchCache.CachedTrack(id: UUID(), title: "Song", artist: "Artist", album: "Album", duration: 200)]

        await cache.set("old", result: .init(query: "old", timestamp: oldDate))
        await cache.set("fresh", result: .init(query: "fresh", tracks: tracks, timestamp: freshDate))

        let stats = await cache.getStatistics()

        XCTAssertEqual(stats.entryCount, 2)
        XCTAssertEqual(stats.expiredCount, 1)
        XCTAssertEqual(stats.totalCachedResults, 1)
        XCTAssertEqual(stats.averageResultsPerEntry, 0)
        XCTAssertEqual(stats.cacheEfficiency, 0.5, accuracy: 0.0001)
        XCTAssertEqual(stats.cacheFreshnessDescription, "Fresh")
    }
}
