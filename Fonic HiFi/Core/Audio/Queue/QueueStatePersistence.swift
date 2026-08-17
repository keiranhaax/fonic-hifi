import Foundation
import OSLog

@MainActor
protocol QueueStatePersisting: AnyObject {
    func requestSave(_ state: QueueState)
    func save(_ state: QueueState) async
    func load() async -> QueueState?
    func clear() async
    func flush() async
}

@MainActor
final class UserDefaultsQueueStatePersister: QueueStatePersisting {
    private let logger = Log.logger(.audioQueueState)
    private let worker: QueueStatePersistenceWorker
    private var pendingSaveTask: Task<Void, Never>?
    private var pendingSaveGeneration: UInt = 0

    init(suiteName: String?) {
        worker = QueueStatePersistenceWorker(suiteName: suiteName)
    }

    func requestSave(_ state: QueueState) {
        pendingSaveTask?.cancel()
        pendingSaveGeneration &+= 1

        let worker = worker
        pendingSaveTask = Task {
            do {
                try await Task.sleep(for: .milliseconds(75))
                try Task.checkCancellation()
                try await worker.save(state)
            } catch is CancellationError {
                // A newer queue snapshot superseded this pending write.
            } catch {
                logger.error(
                    "Failed to save queue state: \(error.localizedDescription, privacy: .private)"
                )
            }
        }
    }

    func save(_ state: QueueState) async {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        pendingSaveGeneration &+= 1

        do {
            try await worker.save(state)
        } catch {
            logger.error(
                "Failed to save queue state: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    func load() async -> QueueState? {
        await worker.load()
    }

    func clear() async {
        pendingSaveTask?.cancel()
        pendingSaveTask = nil
        pendingSaveGeneration &+= 1
        await worker.clear()
    }

    func flush() async {
        while let task = pendingSaveTask {
            let generation = pendingSaveGeneration
            await task.value
            guard generation == pendingSaveGeneration else { continue }
            pendingSaveTask = nil
        }
    }
}

private actor QueueStatePersistenceWorker {
    private let defaults: UserDefaults

    init(suiteName: String?) {
        if let suiteName {
            guard let defaults = UserDefaults(suiteName: suiteName) else {
                preconditionFailure("Unable to create queue persistence suite")
            }
            self.defaults = defaults
        } else {
            defaults = .standard
        }
    }

    func save(_ state: QueueState) throws {
        try Task.checkCancellation()
        let validatedState = state.validateForPersistence()
        try Task.checkCancellation()

        // A transient container-path or file-provider failure must not replace
        // a recoverable queue snapshot with an empty or unselected queue.
        guard state.tracks.isEmpty || !validatedState.tracks.isEmpty else { return }
        guard state.currentTrack?.id == validatedState.currentTrack?.id else { return }

        try validatedState.save(to: defaults)
    }

    func load() -> QueueState? {
        guard let persistedState = QueueState.load(from: defaults),
              !persistedState.tracks.isEmpty
        else {
            return nil
        }

        let validatedState = persistedState.validateForPersistence()
        guard !validatedState.tracks.isEmpty else { return nil }
        guard persistedState.currentTrack?.id == validatedState.currentTrack?.id else { return nil }
        return validatedState
    }

    func clear() {
        QueueState.clear(from: defaults)
    }
}
