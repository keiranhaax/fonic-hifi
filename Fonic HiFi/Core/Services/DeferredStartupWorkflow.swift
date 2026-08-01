import Foundation

struct DeferredStartupOperation: Sendable {
    let delay: Duration
    let action: @MainActor @Sendable () async -> Void
}

struct DeferredStartupWorkflow<WorkflowClock: Clock>: Sendable
where WorkflowClock.Duration == Duration {
    private let clock: WorkflowClock
    private let operations: [DeferredStartupOperation]

    init(
        clock: WorkflowClock,
        operations: [DeferredStartupOperation]
    ) {
        self.clock = clock
        self.operations = operations
    }

    func run() async {
        await withTaskGroup(of: Void.self) { group in
            for operation in operations {
                group.addTask {
                    do {
                        try await clock.sleep(for: operation.delay)
                        try Task.checkCancellation()
                    } catch {
                        return
                    }

                    await operation.action()
                }
            }
        }
    }
}
