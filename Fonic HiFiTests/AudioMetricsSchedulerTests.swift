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

}
