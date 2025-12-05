import Combine
import Foundation
import os

/// Manages sleep timer countdown and triggers pause when complete.
@MainActor
public final class SleepTimerManager: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isActive: Bool = false
    @Published public private(set) var remainingSeconds: Int = 0

    /// Callback triggered when timer completes. Wire to AudioEngineFacade.pause().
    public var onComplete: (() -> Void)?

    /// Callback for volume changes during fade-out. Wire to AudioEngineFacade.setVolume().
    public var onVolumeChange: ((Float) -> Void)?

    /// Duration of fade-out in seconds. 0 = no fade.
    public var fadeOutDuration: Int = 0

    // MARK: - Private

    private let logger = Log.logger(.audio)
    private var timerTask: Task<Void, Never>?
    private var originalVolume: Float = 1.0

    // MARK: - Init

    public init() {}

    deinit {
        timerTask?.cancel()
    }

    // MARK: - Public API

    /// Start sleep timer with specified duration.
    /// - Parameter seconds: Total timer duration
    /// - Parameter currentVolume: Current audio volume for fade-out restoration
    public func start(seconds: Int, currentVolume: Float = 1.0) {
        stop()
        remainingSeconds = seconds
        originalVolume = currentVolume
        isActive = true
        logger.debug("Sleep timer started: \(seconds)s, fade: \(self.fadeOutDuration)s")

        timerTask = Task { @MainActor [weak self] in
            while let self, self.isActive, self.remainingSeconds > 0 {
                try? await Task.sleep(for: .seconds(1))
                guard !Task.isCancelled else { break }
                self.remainingSeconds -= 1

                // Handle fade-out
                if self.fadeOutDuration > 0, self.remainingSeconds <= self.fadeOutDuration {
                    let progress = Float(self.remainingSeconds) / Float(self.fadeOutDuration)
                    let newVolume = self.originalVolume * progress
                    self.onVolumeChange?(newVolume)
                }
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
        if isActive {
            // Restore original volume if stopped mid-fade
            onVolumeChange?(originalVolume)
        }
        isActive = false
        remainingSeconds = 0
        logger.debug("Sleep timer stopped")
    }

    // MARK: - Private

    private func timerComplete() {
        logger.info("Sleep timer complete")
        isActive = false
        onComplete?()
        // Restore volume after a brief delay (for next play)
        Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            if let self {
                self.onVolumeChange?(self.originalVolume)
            }
        }
    }
}
