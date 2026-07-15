import Foundation
import OSLog

actor FormatDetectionCoordinator {
    enum CoordinatorError: Error {
        case timeout
    }

    private let semaphore: AsyncSemaphore
    private let logger: Logger
    private let timeout: TimeInterval?

    init(maxConcurrentDetections: Int, timeout: TimeInterval?, logger: Logger) {
        semaphore = AsyncSemaphore(value: maxConcurrentDetections)
        self.timeout = timeout
        self.logger = logger
    }

    func performDetection(
        for _: URL,
        operation: @escaping @Sendable () async throws -> AudioFileInfo,
    ) async throws -> AudioFileInfo {
        try Task.checkCancellation()
        let waitBegan = ContinuousClock.now

        await semaphore.acquire()
        let waitDuration = waitBegan.duration(to: .now)
        logger.debug(
            "detection.start wait_ms=\(milliseconds(waitDuration), privacy: .public)"
        )

        let detectionBegan = ContinuousClock.now

        defer {
            Task {
                await semaphore.release()
            }
        }

        do {
            let result: AudioFileInfo = if let timeout, timeout > 0 {
                try await withThrowingTaskGroup(of: AudioFileInfo.self) { group in
                    group.addTask(operation: operation)
                    group.addTask {
                        try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                        throw CoordinatorError.timeout
                    }

                    guard let next = try await group.next() else {
                        group.cancelAll()
                        throw CancellationError()
                    }

                    group.cancelAll()
                    return next
                }
            } else {
                try await operation()
            }

            let detectionDuration = detectionBegan.duration(to: .now)
            logger.debug(
                "detection.success duration_ms=\(milliseconds(detectionDuration), privacy: .public)"
            )
            return result
        } catch is CancellationError {
            logger.info("detection.cancelled")
            throw CancellationError()
        } catch CoordinatorError.timeout {
            logger.error("detection.timeout")
            throw DetectionError.timeout
        } catch {
            logger.error(
                "detection.failure error_type=\(String(describing: type(of: error)), privacy: .public)"
            )
            throw error
        }
    }
}

private func milliseconds(_ duration: Duration) -> Double {
    let nanoseconds = Double(duration / .nanoseconds(1))
    return nanoseconds / 1_000_000.0
}
