@testable import Fonic_HiFi
import Foundation
import XCTest

@MainActor
final class DataManagerRecoveryModeTests: XCTestCase {
    func testFallbackManagerIsReadOnlyAcrossMutationAuthorities() async throws {
        let manager = try XCTUnwrap(DataManager.ensureFallbackDataManager())

        XCTAssertEqual(manager.mutationPolicy, .readOnly)
        XCTAssertTrue(manager.isFallback)
        XCTAssertNotNil(manager.importRecoveryState)

        do {
            try await manager.recentSearchesActor.addSearch("recovery search")
            XCTFail("Recovery mode must reject recent-search writes")
        } catch {
            XCTAssertEqual(error as? DataMutationError, .readOnly)
        }

        let searches = try await manager.recentSearchesActor.getRecentSearches()
        XCTAssertTrue(searches.isEmpty)
    }
}
