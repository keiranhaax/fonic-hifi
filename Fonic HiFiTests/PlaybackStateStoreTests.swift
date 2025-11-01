@testable import Fonic_HiFi
import Combine
import XCTest

@MainActor
final class PlaybackStateStoreTests: XCTestCase {
    func testEventPublisherEmitsStateAndTransition() {
        let store = PlaybackStateStore(configuration: .testing)
        var received: [PlaybackStateEvent] = []
        let expectation = expectation(description: "event stream emits state and transition")
        expectation.expectedFulfillmentCount = 2

        let cancellable = store.onEvent { event in
            received.append(event)
            expectation.fulfill()
        }

        store.stateManager.transitionToPlaying(currentTime: 1.5, duration: 120)

        wait(for: [expectation], timeout: 1.0)

        defer { cancellable.cancel() }

        XCTAssertEqual(received.count, 2)

        guard case let .stateChanged(change) = received.first else {
            return XCTFail("Expected first event to be stateChanged")
        }

        XCTAssertEqual(change.nextState, .playing(currentTime: 1.5, duration: 120))

        guard case let .transitionOccurred(transition) = received.last else {
            return XCTFail("Expected second event to be transitionOccurred")
        }

        XCTAssertTrue(transition.isValid)
        XCTAssertEqual(transition.nextState, .playing(currentTime: 1.5, duration: 120))
        XCTAssertEqual(store.currentState, .playing(currentTime: 1.5, duration: 120))
    }

    func testUpdateConfigurationAppliesLoggingFlag() {
        let store = PlaybackStateStore(configuration: .default)
        XCTAssertFalse(store.stateManager.loggingEnabled)

        let newConfiguration = PlaybackStateConfiguration(
            enableTransitionValidation: true,
            enableLogging: true,
            maxHistorySize: 50,
            emitTimeUpdateEvents: true,
            timeUpdateThrottle: 0.25
        )

        store.updateConfiguration(newConfiguration)

        XCTAssertEqual(store.configuration.enableLogging, true)
        XCTAssertTrue(store.stateManager.loggingEnabled)
    }

    func testCreateStateManagerHonorsTransitionValidation() {
        let strictManager = PlaybackStateStore.createStateManager(with: .default)
        let allowed = strictManager.updateState(.playing(currentTime: 0, duration: 180))
        XCTAssertFalse(allowed)
        XCTAssertEqual(strictManager.currentState, .idle)

        let relaxedManager = PlaybackStateStore.createStateManager(with: .testing)
        let relaxedAllowed = relaxedManager.updateState(.playing(currentTime: 0, duration: 180))
        XCTAssertTrue(relaxedAllowed)
        XCTAssertEqual(relaxedManager.currentState, .playing(currentTime: 0, duration: 180))
    }
}
