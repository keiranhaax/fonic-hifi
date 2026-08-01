@testable import Fonic_HiFi
import XCTest

final class AsyncSemaphoreTests: XCTestCase {
    func testCancellationBeforeWaiterRegistrationDoesNotLeakContinuation() async throws {
        let semaphore = AsyncSemaphore(value: 1)
        try await semaphore.acquire()

        for iteration in 0 ..< 200 {
            let waiter = Task {
                withUnsafeCurrentTask { task in
                    task?.cancel()
                }
                try await semaphore.acquire()
            }

            do {
                try await waiter.value
                XCTFail("Pre-cancelled waiter acquired a permit on iteration \(iteration)")
            } catch is CancellationError {
                // Expected.
            } catch {
                XCTFail("Unexpected error on iteration \(iteration): \(error)")
            }

            let snapshot = await semaphore.snapshot()
            XCTAssertEqual(
                snapshot,
                AsyncSemaphore.Snapshot(availablePermits: 0, waitingTaskCount: 0),
                "Pre-registration cancellation leaked a waiter on iteration \(iteration)",
            )
        }

        await semaphore.release()
        let finalSnapshot = await semaphore.snapshot()
        XCTAssertEqual(
            finalSnapshot,
            AsyncSemaphore.Snapshot(availablePermits: 1, waitingTaskCount: 0),
        )
    }

    func testCancelledWaiterReturnsTransferredPermit() async throws {
        let semaphore = AsyncSemaphore(value: 1)
        try await semaphore.acquire()

        let waiter = Task {
            try await semaphore.acquire()
        }

        let waiterQueued = await waitForWaiterCount(1, on: semaphore)
        XCTAssertTrue(waiterQueued)

        waiter.cancel()
        await semaphore.release()

        do {
            try await waiter.value
            XCTFail("Expected the queued acquisition to observe cancellation")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected cancellation error: \(error)")
        }

        let finalSnapshot = await semaphore.snapshot()
        XCTAssertEqual(
            finalSnapshot,
            AsyncSemaphore.Snapshot(availablePermits: 1, waitingTaskCount: 0),
        )
    }

    func testReleaseCancellationRacePreservesPermitAccounting() async throws {
        let semaphore = AsyncSemaphore(value: 1)

        for iteration in 0 ..< 200 {
            try await semaphore.acquire()

            let waiter = Task {
                try await semaphore.acquire()
            }

            let waiterQueued = await waitForWaiterCount(1, on: semaphore)
            XCTAssertTrue(waiterQueued, "Waiter did not queue on iteration \(iteration)")

            waiter.cancel()
            await semaphore.release()

            do {
                try await waiter.value
                XCTFail("Cancelled waiter acquired a permit on iteration \(iteration)")
            } catch is CancellationError {
                // Expected whether cancellation or release wins the actor race.
            } catch {
                XCTFail("Unexpected error on iteration \(iteration): \(error)")
            }

            let iterationSnapshot = await semaphore.snapshot()
            XCTAssertEqual(
                iterationSnapshot,
                AsyncSemaphore.Snapshot(availablePermits: 1, waitingTaskCount: 0),
                "Permit accounting drifted on iteration \(iteration)",
            )
        }

        await semaphore.release()
        let overReleaseSnapshot = await semaphore.snapshot()
        XCTAssertEqual(
            overReleaseSnapshot,
            AsyncSemaphore.Snapshot(availablePermits: 1, waitingTaskCount: 0),
            "An extra release must not overfill the semaphore",
        )
    }
}

private func waitForWaiterCount(_ expectedCount: Int, on semaphore: AsyncSemaphore) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: .seconds(2))

    while clock.now < deadline {
        if await semaphore.snapshot().waitingTaskCount == expectedCount {
            return true
        }
        await Task.yield()
    }

    return await semaphore.snapshot().waitingTaskCount == expectedCount
}
