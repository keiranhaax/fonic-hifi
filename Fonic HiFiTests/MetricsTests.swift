@testable import Fonic_HiFi
import os
import XCTest

final class MetricsTests: XCTestCase {
    private let defaultsKey = "com.fonichifi.metrics.enabled"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        Metrics.setSinkForTesting(nil)
    }

    override func tearDown() {
        Metrics.setSinkForTesting(nil)
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        super.tearDown()
    }

    func testEnablePersistsToggle() {
        Metrics.enable(true)
        XCTAssertTrue(Metrics.isEnabled)
        XCTAssertTrue(UserDefaults.standard.bool(forKey: defaultsKey))

        Metrics.enable(false)
        XCTAssertFalse(Metrics.isEnabled)
        XCTAssertFalse(UserDefaults.standard.bool(forKey: defaultsKey))
    }

    func testIncrementDoesNothingWhenDisabled() {
        Metrics.enable(false)

        let expectation = expectation(description: "sink not called")
        expectation.isInverted = true

        Metrics.setSinkForTesting { _, _, _, _ in
            expectation.fulfill()
        }

        Metrics.increment(.importsDiscovered)
        wait(for: [expectation], timeout: 0.1)
    }

    func testIncrementSkipsZeroAmount() {
        Metrics.enable(true)

        let expectation = expectation(description: "sink should not fire")
        expectation.isInverted = true

        Metrics.setSinkForTesting { _, _, _, _ in
            expectation.fulfill()
        }

        Metrics.increment(.importsCompleted, by: 0)
        wait(for: [expectation], timeout: 0.1)
    }

    func testIncrementDeliversSortedMetadataWhenEnabled() {
        Metrics.enable(true)

        let expectation = expectation(description: "sink called")
        let lock = OSAllocatedUnfairLock<(MetricsCounter, Int, String)?>(initialState: nil)

        Metrics.setSinkForTesting { counter, amount, meta, metadata in
            lock.withLock { state in
                state = (counter, amount, meta)
            }
            expectation.fulfill()
            XCTAssertEqual(metadata, ["action": "enqueue", "path": "Track.flac"])
        }

        Metrics.increment(
            .queueMutation,
            by: 3,
            metadata: ["path": "Track.flac", "action": "enqueue"]
        )

        wait(for: [expectation], timeout: 0.1)

        let captured = lock.withLock { $0 }
        XCTAssertEqual(captured?.0, .queueMutation)
        XCTAssertEqual(captured?.1, 3)
        XCTAssertEqual(captured?.2, "action=enqueue path=Track.flac")
    }

    func testIncrementHandlesEmptyMetadata() {
        Metrics.enable(true)

        let expectation = expectation(description: "sink called")
        let metaLock = OSAllocatedUnfairLock<String?>(initialState: nil)

        Metrics.setSinkForTesting { _, _, meta, metadata in
            metaLock.withLock { state in
                state = meta
            }
            XCTAssertTrue(metadata.isEmpty)
            expectation.fulfill()
        }

        Metrics.increment(.engineSwitch)

        wait(for: [expectation], timeout: 0.1)
        let capturedMeta = metaLock.withLock { $0 }
        XCTAssertEqual(capturedMeta ?? "", "")
    }
}
