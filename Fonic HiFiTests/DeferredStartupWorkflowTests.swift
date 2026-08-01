@testable import Fonic_HiFi
import XCTest

@MainActor
final class DeferredStartupWorkflowTests: XCTestCase {
    func testWorkflowPreservesConcurrentThreeFiveEightSecondSchedule() async throws {
        let clock = ControlledTestClock()
        let recorder = DeferredStartupOperationRecorder()
        let workflow = DeferredStartupWorkflow(
            clock: clock,
            operations: [
                DeferredStartupOperation(delay: .seconds(3)) {
                    recorder.record("cleanup")
                },
                DeferredStartupOperation(delay: .seconds(5)) {
                    recorder.record("statistics")
                },
                DeferredStartupOperation(delay: .seconds(8)) {
                    recorder.record("backfill")
                },
            ]
        )

        let task = Task {
            await workflow.run()
        }
        try await clock.waitUntilSleeperCount(3)

        clock.advance(by: .seconds(3))
        try await recorder.waitForEventCount(1)
        XCTAssertEqual(recorder.events, ["cleanup"])

        clock.advance(by: .seconds(2))
        try await recorder.waitForEventCount(2)
        XCTAssertEqual(recorder.events, ["cleanup", "statistics"])

        clock.advance(by: .seconds(3))
        await task.value
        XCTAssertEqual(recorder.events, ["cleanup", "statistics", "backfill"])
    }

    func testCancellationPreventsDeferredOperationsFromStarting() async throws {
        let clock = ControlledTestClock()
        let recorder = DeferredStartupOperationRecorder()
        let workflow = DeferredStartupWorkflow(
            clock: clock,
            operations: [
                DeferredStartupOperation(delay: .seconds(3)) {
                    recorder.record("cleanup")
                },
                DeferredStartupOperation(delay: .seconds(5)) {
                    recorder.record("statistics")
                },
                DeferredStartupOperation(delay: .seconds(8)) {
                    recorder.record("backfill")
                },
            ]
        )

        let task = Task {
            await workflow.run()
        }
        try await clock.waitUntilSleeperCount(3)

        task.cancel()
        await task.value
        clock.advance(by: .seconds(8))

        XCTAssertTrue(recorder.events.isEmpty)
    }
}

@MainActor
private final class DeferredStartupOperationRecorder {
    private(set) var events: [String] = []

    func record(_ event: String) {
        events.append(event)
    }

    func waitForEventCount(_ count: Int) async throws {
        for _ in 0 ..< 10_000 {
            if events.count >= count {
                return
            }
            try Task.checkCancellation()
            await Task.yield()
        }

        XCTFail("Timed out waiting for \(count) deferred startup events")
    }
}
