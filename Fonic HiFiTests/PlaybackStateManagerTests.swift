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

    func testUpdateTimeDebouncesSmallPlayingDeltas() async throws {
        let manager = PlaybackStateManager(
            initialState: .playing(currentTime: 10.0, duration: 180.0),
            enableTransitionValidation: false
        )

        var stateChanges: [PlaybackStateChange] = []
        let cancellable = manager.statePublisher.sink { stateChanges.append($0) }
        defer { cancellable.cancel() }

        manager.updateTime(10.1, duration: 180.0)
        manager.updateTime(10.2, duration: 180.0)

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(stateChanges.count, 0, "Expected no emissions for tiny playing deltas")
        XCTAssertEqual(manager.currentState, .playing(currentTime: 10.0, duration: 180.0))
    }

    func testUpdateTimeEmitsWhenPlayingDeltaExceedsThreshold() async throws {
        let manager = PlaybackStateManager(
            initialState: .playing(currentTime: 10.0, duration: 180.0),
            enableTransitionValidation: false
        )

        var stateChanges: [PlaybackStateChange] = []
        let cancellable = manager.statePublisher.sink { stateChanges.append($0) }
        defer { cancellable.cancel() }

        manager.updateTime(10.35, duration: 180.0)

        try await Task.sleep(for: .milliseconds(100))

        XCTAssertEqual(stateChanges.count, 1, "Expected one emission when delta exceeds debounce threshold")
        XCTAssertEqual(manager.currentState, .playing(currentTime: 10.35, duration: 180.0))
    }
}
