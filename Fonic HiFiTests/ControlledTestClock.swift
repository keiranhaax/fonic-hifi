import Foundation
import Synchronization

/// A manually advanced Swift `Clock` for deterministic timer tests.
final class ControlledTestClock: Clock {
    struct Instant: InstantProtocol {
        fileprivate let offset: Duration

        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.offset < rhs.offset
        }

        func advanced(by duration: Duration) -> Self {
            Self(offset: offset + duration)
        }

        func duration(to other: Self) -> Duration {
            other.offset - offset
        }
    }

    typealias Duration = Swift.Duration

    private struct Sleeper: Sendable {
        let id: UUID
        let deadline: Instant
        let continuation: CheckedContinuation<Void, any Error>
    }

    private struct State: Sendable {
        var now = Instant(offset: .zero)
        var sleepers: [Sleeper] = []
    }

    private enum RegistrationResult {
        case cancelled
        case ready
        case suspended
    }

    private enum TestClockError: Error {
        case sleeperRegistrationTimedOut(minimumCount: Int)
    }

    private let state = Mutex(State())

    var now: Instant {
        state.withLock { $0.now }
    }

    var minimumResolution: Duration {
        .nanoseconds(1)
    }

    func sleep(until deadline: Instant, tolerance _: Duration?) async throws {
        let id = UUID()

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                let result = state.withLock { state -> RegistrationResult in
                    guard !Task.isCancelled else {
                        return .cancelled
                    }
                    guard deadline > state.now else {
                        return .ready
                    }

                    state.sleepers.append(
                        Sleeper(
                            id: id,
                            deadline: deadline,
                            continuation: continuation,
                        ),
                    )
                    return .suspended
                }

                switch result {
                case .cancelled:
                    continuation.resume(throwing: CancellationError())
                case .ready:
                    continuation.resume()
                case .suspended:
                    break
                }
            }
        } onCancel: {
            let continuation = state.withLock { state -> CheckedContinuation<Void, any Error>? in
                guard let index = state.sleepers.firstIndex(where: { $0.id == id }) else {
                    return nil
                }
                return state.sleepers.remove(at: index).continuation
            }
            continuation?.resume(throwing: CancellationError())
        }
    }

    func advance(by duration: Duration) {
        precondition(duration >= .zero)

        let ready = state.withLock { state -> [CheckedContinuation<Void, any Error>] in
            state.now = state.now.advanced(by: duration)
            let ready = state.sleepers.filter { $0.deadline <= state.now }
            state.sleepers.removeAll { $0.deadline <= state.now }
            return ready.map(\.continuation)
        }
        ready.forEach { $0.resume() }
    }

    func waitUntilSleeperCount(_ minimumCount: Int = 1) async throws {
        let timeoutClock = ContinuousClock()
        let deadline = timeoutClock.now.advanced(by: .seconds(2))

        while timeoutClock.now < deadline {
            if state.withLock({ $0.sleepers.count >= minimumCount }) {
                return
            }
            try Task.checkCancellation()
            await Task.yield()
        }

        throw TestClockError.sleeperRegistrationTimedOut(minimumCount: minimumCount)
    }
}
