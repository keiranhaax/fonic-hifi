@testable import Fonic_HiFi
import Combine
import Foundation
import XCTest

@MainActor
final class PlaybackStateManagerTests: XCTestCase {

    func testUpdateStateSkipsDuplicateStates() async throws {
        let manager = PlaybackStateManager(
            initialState: .idle,
            enableTransitionValidation: false
        )

        var stateChanges: [PlaybackStateChange] = []
        let cancellable = manager.statePublisher.sink { stateChanges.append($0) }
        defer { cancellable.cancel() }

        // First update should emit
        manager.updateState(.playing(currentTime: 10.0, duration: 180.0))
        // Duplicate - should NOT emit
        manager.updateState(.playing(currentTime: 10.0, duration: 180.0))
        // Duplicate - should NOT emit
        manager.updateState(.playing(currentTime: 10.0, duration: 180.0))

        // Wait for async delivery via RunLoop.main
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(stateChanges.count, 1, "Duplicate states should not emit - got \(stateChanges.count) emissions")
    }

    func testUpdateStateEmitsForDifferentStates() async throws {
        let manager = PlaybackStateManager(
            initialState: .idle,
            enableTransitionValidation: false
        )

        var stateChanges: [PlaybackStateChange] = []
        let cancellable = manager.statePublisher.sink { stateChanges.append($0) }
        defer { cancellable.cancel() }

        // Different states should all emit
        manager.updateState(.playing(currentTime: 10.0, duration: 180.0))
        manager.updateState(.playing(currentTime: 20.0, duration: 180.0))
        manager.updateState(.paused(currentTime: 20.0, duration: 180.0))

        // Wait for async delivery via RunLoop.main
        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(stateChanges.count, 3, "Different states should all emit - got \(stateChanges.count) emissions")
    }

    func testUpdateStateReturnsTrueForDuplicates() {
        let manager = PlaybackStateManager(
            initialState: .idle,
            enableTransitionValidation: false
        )

        let firstResult = manager.updateState(.playing(currentTime: 10.0, duration: 180.0))
        let secondResult = manager.updateState(.playing(currentTime: 10.0, duration: 180.0))

        XCTAssertTrue(firstResult, "First update should succeed")
        XCTAssertTrue(secondResult, "Duplicate update should return true (no-op success)")
    }
}
