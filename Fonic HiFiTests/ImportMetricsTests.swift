@testable import Fonic_HiFi
import XCTest

final class ImportMetricsTests: XCTestCase {
    func testCalculatedAverageTimeUsesSuccessfulImports() {
        var metrics = ImportMetrics(
            totalFiles: 10,
            successfulImports: 4,
            failedImports: 2,
            duplicatesSkipped: 1,
            averageFileProcessingTime: 0.35,
            totalImportTime: 8.0
        )

        XCTAssertEqual(metrics.calculatedAverageTime, 2.0)

        metrics.successfulImports = 0
        XCTAssertEqual(metrics.calculatedAverageTime, 0)
    }

    func testSuccessRateAndDescriptionReflectMetrics() {
        let metrics = ImportMetrics(
            totalFiles: 20,
            successfulImports: 15,
            failedImports: 3,
            duplicatesSkipped: 2,
            averageFileProcessingTime: 0.42,
            totalImportTime: 12.6
        )

        XCTAssertEqual(metrics.successRate, 75)

        let description = metrics.formattedDescription
        XCTAssertTrue(description.contains("Total files: 20"))
        XCTAssertTrue(description.contains("Successful imports: 15"))
        XCTAssertTrue(description.contains("Failed imports: 3"))
        XCTAssertTrue(description.contains("Duplicates skipped: 2"))
        XCTAssertTrue(description.contains("Success rate: 75.0%"))
    }
}
