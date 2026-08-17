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
    private let clock: any Clock<Duration>
    private let now: () -> Date
    private var timerTask: Task<Void, Never>?
    private var volumeRestoreTask: Task<Void, Never>?
    private var deadline: Date?
    private var originalVolume: Float = 1.0
    private var needsVolumeRestore = false

    // MARK: - Init

    public convenience init() {
        self.init(clock: ContinuousClock())
    }

    init(
        clock: any Clock<Duration>,
        now: @escaping () -> Date = Date.init
    ) {
        self.clock = clock
        self.now = now
    }

    deinit {
        timerTask?.cancel()
        volumeRestoreTask?.cancel()
    }

    // MARK: - Public API

    /// Start sleep timer with specified duration.
    /// - Parameter seconds: Total timer duration
    /// - Parameter currentVolume: Current audio volume for fade-out restoration
    public func start(seconds: Int, currentVolume: Float) {
        stop()
        let duration = max(1, seconds)
        remainingSeconds = duration
        deadline = now().addingTimeInterval(TimeInterval(duration))
        originalVolume = min(max(currentVolume, 0), 1)
        needsVolumeRestore = true
        isActive = true
        logger.debug("Sleep timer started: \(duration, privacy: .public)s, fade: \(self.fadeOutDuration, privacy: .public)s")

        let clock = clock
        timerTask = Task { @MainActor [weak self] in
            while let self, self.isActive, self.remainingSeconds > 0 {
                do {
                    try await clock.sleep(for: .seconds(1))
                    try Task.checkCancellation()
                } catch {
                    return
                }
                self.refreshRemainingTime()

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
        cancel(restoreVolume: true)
    }

    func cancel(restoreVolume: Bool) {
        timerTask?.cancel()
        timerTask = nil
        volumeRestoreTask?.cancel()
        volumeRestoreTask = nil
        deadline = nil
        if restoreVolume, needsVolumeRestore {
            onVolumeChange?(originalVolume)
        }
        needsVolumeRestore = false
        isActive = false
        remainingSeconds = 0
        logger.debug("Sleep timer stopped")
    }

    // MARK: - Private

    private func timerComplete() {
        logger.info("Sleep timer complete")
        timerTask = nil
        deadline = nil
        isActive = false
        onComplete?()

        // Restore volume after a brief delay (for next play)
        let clock = clock
        volumeRestoreTask = Task { @MainActor [weak self] in
            do {
                try await clock.sleep(for: .milliseconds(500))
                try Task.checkCancellation()
            } catch {
                return
            }

            guard let self, self.needsVolumeRestore else { return }
            self.needsVolumeRestore = false
            self.volumeRestoreTask = nil
            self.onVolumeChange?(self.originalVolume)
        }
    }

    private func refreshRemainingTime() {
        guard let deadline else { return }
        let wallClockRemaining = max(0, Int(ceil(deadline.timeIntervalSince(now()))))
        remainingSeconds = min(remainingSeconds, wallClockRemaining)
    }
}
