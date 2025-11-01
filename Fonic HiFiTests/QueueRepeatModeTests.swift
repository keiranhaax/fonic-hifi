@testable import Fonic_HiFi
import Foundation
import XCTest

final class QueueRepeatModeTests: XCTestCase {
    func testDescriptionsAndSymbols() {
        XCTAssertEqual(QueueRepeatMode.none.description, "No Repeat")
        XCTAssertEqual(QueueRepeatMode.all.shortDescription, "All")
        XCTAssertEqual(QueueRepeatMode.one.symbolName, "repeat.1.circle")
        XCTAssertFalse(QueueRepeatMode.none.isInfinite)
        XCTAssertTrue(QueueRepeatMode.one.isInfinite)
        XCTAssertEqual(QueueRepeatMode.none.next, .all)
        XCTAssertEqual(QueueRepeatMode.all.previous, .none)
    }

    func testHasNextAndHasPreviousLogic() {
        XCTAssertFalse(QueueRepeatMode.none.hasNext(currentIndex: nil, queueCount: 0, isShuffled: false))
        XCTAssertTrue(QueueRepeatMode.all.hasNext(currentIndex: 2, queueCount: 3, isShuffled: true))
        XCTAssertTrue(QueueRepeatMode.one.hasPrevious(currentIndex: 0, queueCount: 1, isShuffled: false))
        XCTAssertFalse(QueueRepeatMode.none.hasPrevious(currentIndex: 0, queueCount: 1, isShuffled: false))
    }

    func testNextIndexRespectsRepeatModes() {
        XCTAssertEqual(QueueRepeatMode.none.nextIndex(from: nil, queueCount: 3), 0)
        XCTAssertEqual(QueueRepeatMode.none.nextIndex(from: 1, queueCount: 3), 2)
        XCTAssertNil(QueueRepeatMode.none.nextIndex(from: 2, queueCount: 3))

        XCTAssertEqual(QueueRepeatMode.all.nextIndex(from: 2, queueCount: 3), 0)
        XCTAssertEqual(QueueRepeatMode.one.nextIndex(from: 1, queueCount: 3), 1)
    }

    func testPreviousIndexRespectsRepeatModes() {
        XCTAssertNil(QueueRepeatMode.none.previousIndex(from: 0, queueCount: 3))
        XCTAssertEqual(QueueRepeatMode.none.previousIndex(from: 2, queueCount: 3), 1)

        XCTAssertEqual(QueueRepeatMode.all.previousIndex(from: 0, queueCount: 3), 2)
        XCTAssertEqual(QueueRepeatMode.one.previousIndex(from: 1, queueCount: 3), 1)
    }

    func testCodableRoundTrip() throws {
        let data = try JSONEncoder().encode(QueueRepeatMode.all)
        let decoded = try JSONDecoder().decode(QueueRepeatMode.self, from: data)
        XCTAssertEqual(decoded, .all)
    }
}
