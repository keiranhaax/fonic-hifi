@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioMetricsSchedulerTests: XCTestCase {
    func testMonitoringFiresRepeatedly() async {
        let scheduler = AudioMetricsScheduler()
        let expectation = expectation(description: "Scheduler fires")
        expectation.expectedFulfillmentCount = 3

        scheduler.startMonitoring(every: 0.01) {
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 0.2)
        scheduler.stopMonitoring()
    }

    func testProfilingStopsCancelsTask() async {
        let scheduler = AudioMetricsScheduler()
        let expectation = expectation(description: "Profiling fires")
        expectation.expectedFulfillmentCount = 1
        var callCount = 0

        scheduler.startProfiling(every: 0.01) {
            callCount += 1
            expectation.fulfill()
        }

        await fulfillment(of: [expectation], timeout: 0.2)
        scheduler.stopProfiling()
        let recorded = callCount
        try? await Task.sleep(nanoseconds: 20_000_000)
        XCTAssertEqual(callCount, recorded)
    }
}
