import Foundation

actor AsyncSemaphore {
    struct Snapshot: Equatable, Sendable {
        let availablePermits: Int
        let waitingTaskCount: Int
    }

    private struct Waiter {
        let id: UUID
        let continuation: CheckedContinuation<Void, Error>
    }

    private let maximumValue: Int
    private var currentValue: Int
    private var waiters: [Waiter] = []

    init(value: Int) {
        precondition(value > 0, "AsyncSemaphore requires value greater than zero")
        maximumValue = value
        currentValue = value
    }

    func acquire() async throws {
        try Task.checkCancellation()

        if currentValue > 0 {
            currentValue -= 1
            return
        }

        let waiterID = UUID()
        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                guard !Task.isCancelled else {
                    continuation.resume(throwing: CancellationError())
                    return
                }
                waiters.append(Waiter(id: waiterID, continuation: continuation))
            }
        } onCancel: {
            Task {
                await self.cancelWaiter(id: waiterID)
            }
        }

        do {
            try Task.checkCancellation()
        } catch {
            release()
            throw error
        }
    }

    func release() {
        if !waiters.isEmpty {
            let waiter = waiters.removeFirst()
            waiter.continuation.resume()
            return
        }

        guard currentValue < maximumValue else {
            return
        }

        currentValue += 1
    }

    func snapshot() -> Snapshot {
        Snapshot(
            availablePermits: currentValue,
            waitingTaskCount: waiters.count,
        )
    }

    private func cancelWaiter(id: UUID) {
        guard let index = waiters.firstIndex(where: { $0.id == id }) else { return }
        let waiter = waiters.remove(at: index)
        waiter.continuation.resume(throwing: CancellationError())
    }
}
