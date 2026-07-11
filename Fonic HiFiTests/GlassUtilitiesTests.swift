@testable import Fonic_HiFi
import XCTest

final class GlassUtilitiesTests: XCTestCase {
    @MainActor
    func testMemoryManagerRegistrationLimit() {
        let manager = GlassEffectMemoryManager.shared

        // Reset state
        while manager.activeEffectCount > 0 {
            manager.unregisterEffect()
        }

        var registrationsSucceeded = 0
        for _ in 0 ..< 12 {
            if manager.registerEffect() {
                registrationsSucceeded += 1
            }
        }
        XCTAssertEqual(registrationsSucceeded, 12)

        // Next registration should fail because limit reached
        XCTAssertFalse(manager.registerEffect())

        // Clean up to avoid test interference
        while manager.activeEffectCount > 0 {
            manager.unregisterEffect()
        }
    }
}
