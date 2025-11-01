import Foundation

actor AsyncSemaphore {
    private let maximumValue: Int
    private var currentValue: Int
    private var waiters: [CheckedContinuation<Void, Never>] = []

    init(value: Int) {
        precondition(value > 0, "AsyncSemaphore requires value greater than zero")
        maximumValue = value
        currentValue = value
    }

    func acquire() async {
        if currentValue > 0 {
            currentValue -= 1
            return
        }

        await withCheckedContinuation { continuation in
            waiters.append(continuation)
        }
    }

    func release() {
        if !waiters.isEmpty {
            let continuation = waiters.removeFirst()
            continuation.resume()
            return
        }

        guard currentValue < maximumValue else {
            return
        }

        currentValue += 1
    }
}
