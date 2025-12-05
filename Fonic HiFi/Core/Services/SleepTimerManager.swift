import Combine
import Foundation
import os

/// Manages sleep timer countdown and triggers pause when complete.
@MainActor
public final class SleepTimerManager: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var remainingSeconds: Int = 0

    // MARK: - Private

    private let logger = Log.logger(.audio)
    private var timerTask: Task<Void, Never>?

    // MARK: - Init

    public init() {}

    deinit {
        timerTask?.cancel()
    }

    // MARK: - Public API

    /// Start sleep timer with specified duration.
    public func start(seconds: Int) {
        stop()
        remainingSeconds = seconds
        isActive = true
        logger.debug("Sleep timer started: \(seconds)s")

        timerTask = Task { @MainActor [weak self] in
            while let self, self.isActive, self.remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self.remainingSeconds -= 1
            }

            if let self, self.remainingSeconds == 0 {
                self.timerComplete()
            }
        }
    }

    /// Stop and reset the timer.
    public func stop() {
        timerTask?.cancel()
        timerTask = nil
        isActive = false
        remainingSeconds = 0
        logger.debug("Sleep timer stopped")
    }

    // MARK: - Private

    private func timerComplete() {
        logger.info("Sleep timer complete")
        isActive = false
    }
}
