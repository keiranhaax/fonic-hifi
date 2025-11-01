import Foundation

@MainActor
final class AudioMetricsScheduler {
    private let minimumInterval: TimeInterval = 0.01

    private var monitoringTask: Task<Void, Never>?
    private var monitoringHandler: (@MainActor () async -> Void)?
    private var monitoringInterval: TimeInterval = 1.0

    private var profilingTask: Task<Void, Never>?
    private var profilingHandler: (@MainActor () async -> Void)?
    private var profilingInterval: TimeInterval = 0.1

    func startMonitoring(every interval: TimeInterval, handler: @escaping @MainActor () async -> Void) {
        monitoringHandler = handler
        monitoringInterval = interval
        monitoringTask?.cancel()
        monitoringTask = makeRepeatingTask(interval: interval) { await handler() }
    }

    func updateMonitoringInterval(to interval: TimeInterval) {
        guard let handler = monitoringHandler else { return }
        monitoringInterval = interval
        startMonitoring(every: interval, handler: handler)
    }

    func stopMonitoring() {
        monitoringTask?.cancel()
        monitoringTask = nil
        monitoringHandler = nil
    }

    func startProfiling(every interval: TimeInterval, handler: @escaping @MainActor () async -> Void) {
        profilingHandler = handler
        profilingInterval = interval
        profilingTask?.cancel()
        profilingTask = makeRepeatingTask(interval: interval) { await handler() }
    }

    func stopProfiling() {
        profilingTask?.cancel()
        profilingTask = nil
        profilingHandler = nil
    }

    func cancelAll() {
        stopMonitoring()
        stopProfiling()
    }

    private func makeRepeatingTask(interval: TimeInterval, action: @escaping @MainActor () async -> Void) -> Task<Void, Never> {
        let safeInterval = max(interval, minimumInterval)
        return Task { @MainActor [safeInterval] in
            let duration = Duration.seconds(safeInterval)
            while !Task.isCancelled {
                try? await Task.sleep(for: duration)
                if Task.isCancelled { break }
                await action()
            }
        }
    }
}
