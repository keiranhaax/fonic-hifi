import XCTest
@testable import Fonic_HiFi

final class TimedCacheEntryTests: XCTestCase {
    func testEntryRemainsValidWithinTTL() {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = TimedCacheEntry(value: "value", ttl: 5, now: referenceDate)

        XCTAssertTrue(entry.isValid(now: referenceDate.addingTimeInterval(4)))
        XCTAssertTrue(entry.isValid(now: referenceDate))
    }

    func testEntryExpiresAfterTTL() {
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)
        let entry = TimedCacheEntry(value: 42, ttl: 3, now: referenceDate)

        XCTAssertFalse(entry.isValid(now: referenceDate.addingTimeInterval(3.1)))
    }

    func testConcurrentValidityChecks() async {
        let referenceDate = Date(timeIntervalSince1970: 1_700_100_000)
        let entry = TimedCacheEntry(value: UUID(), ttl: 10, now: referenceDate)

        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for _ in 0..<25 {
                group.addTask {
                    entry.isValid(now: referenceDate.addingTimeInterval(5))
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertEqual(results.count, 25)
        XCTAssertTrue(results.allSatisfy { $0 })
    }

    func testConcurrentChecksDetectExpiration() async {
        let referenceDate = Date(timeIntervalSince1970: 1_700_200_000)
        let entry = TimedCacheEntry(value: "expired", ttl: 1, now: referenceDate)

        let results = await withTaskGroup(of: Bool.self, returning: [Bool].self) { group in
            for offset in stride(from: 0.0, through: 1.2, by: 0.3) {
                group.addTask {
                    entry.isValid(now: referenceDate.addingTimeInterval(offset))
                }
            }
            return await group.reduce(into: []) { $0.append($1) }
        }

        XCTAssertTrue(results.contains(false))
        XCTAssertTrue(results.contains(true))
    }
}
