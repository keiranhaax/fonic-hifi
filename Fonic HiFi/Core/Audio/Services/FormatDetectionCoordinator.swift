import Foundation
import OSLog

struct DetectionRequestContext: Sendable {
    let identifier: UUID
    let url: URL

    init(url: URL) {
        identifier = UUID()
        self.url = url
    }
}

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
        for url: URL,
        operation: @escaping @Sendable () async throws -> AudioFileInfo,
    ) async throws -> AudioFileInfo {
        try Task.checkCancellation()
        let context = DetectionRequestContext(url: url)
        let waitBegan = ContinuousClock.now

        await semaphore.acquire()
        let waitDuration = waitBegan.duration(to: .now)
        logger.debug(
            "detection.start id=\(context.identifier.uuidString, privacy: .public) url=\(context.url.lastPathComponent, privacy: .public) wait_ms=\(milliseconds(waitDuration), privacy: .public)"
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
                "detection.success id=\(context.identifier.uuidString, privacy: .public) url=\(context.url.lastPathComponent, privacy: .public) duration_ms=\(milliseconds(detectionDuration), privacy: .public)"
            )
            return result
        } catch is CancellationError {
            logger.info(
                "detection.cancelled id=\(context.identifier.uuidString, privacy: .public) url=\(context.url.lastPathComponent, privacy: .public)"
            )
            throw CancellationError()
        } catch CoordinatorError.timeout {
            logger.error(
                "detection.timeout id=\(context.identifier.uuidString, privacy: .public) url=\(context.url.lastPathComponent, privacy: .public)"
            )
            throw DetectionError.timeout
        } catch {
            logger.error(
                "detection.failure id=\(context.identifier.uuidString, privacy: .public) url=\(context.url.lastPathComponent, privacy: .public) error=\(error.localizedDescription, privacy: .public)"
            )
            throw error
        }
    }
}

private func milliseconds(_ duration: Duration) -> Double {
    let nanoseconds = Double(duration / .nanoseconds(1))
    return nanoseconds / 1_000_000.0
}
