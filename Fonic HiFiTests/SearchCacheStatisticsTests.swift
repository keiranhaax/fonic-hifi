@testable import Fonic_HiFi
import XCTest

final class SearchCacheStatisticsTests: XCTestCase {
    func testEmptyCacheStatisticsExposeNilDates() async {
        let cache = SearchCache(ttl: 30)

        let stats = await cache.getStatistics()

        XCTAssertEqual(stats.entryCount, 0)
        XCTAssertNil(stats.oldestEntry)
        XCTAssertNil(stats.newestEntry)
        XCTAssertTrue(stats.isEmpty)
        XCTAssertEqual(stats.cacheFreshnessDescription, "No cache entries")
    }

    func testStatisticsReflectNewestAndOldestEntries() async {
        let cache = SearchCache(ttl: 60)
        let olderDate = Date().addingTimeInterval(-50)
        let newerDate = Date().addingTimeInterval(-5)

        await cache.set("jazz", result: .init(query: "jazz", timestamp: olderDate))
        await cache.set("rock", result: .init(query: "rock", timestamp: newerDate))

        let stats = await cache.getStatistics()

        XCTAssertEqual(stats.entryCount, 2)
        XCTAssertEqual(stats.oldestEntry?.timeIntervalSince1970.rounded(), olderDate.timeIntervalSince1970.rounded())
        XCTAssertEqual(stats.newestEntry?.timeIntervalSince1970.rounded(), newerDate.timeIntervalSince1970.rounded())
        XCTAssertEqual(stats.cacheFreshnessDescription, "Fresh")
    }

    func testStaleCacheDescriptionWhenEntriesOlderThanTTL() async {
        let cache = SearchCache(ttl: 5)
        let staleDate = Date().addingTimeInterval(-20)

        await cache.set("ambient", result: .init(query: "ambient", timestamp: staleDate))

        let stats = await cache.getStatistics()

        XCTAssertEqual(stats.entryCount, 1)
        XCTAssertEqual(stats.cacheFreshnessDescription, "Stale")
    }
}
