@testable import Fonic_HiFi
import OSLog
import XCTest

final class LogCategoryTests: XCTestCase {
    func testEachLogCategoryHasUniqueRawValueAndLogger() {
        let categories = LogCategory.allCases
        XCTAssertFalse(categories.isEmpty)

        let rawValues = categories.map(\.rawValue)
        XCTAssertEqual(Set(rawValues).count, rawValues.count, "Duplicate log category raw values found")

        for category in categories {
            let logger = Log.logger(category)
            XCTAssertFalse(String(describing: logger).isEmpty)
        }
    }
}
