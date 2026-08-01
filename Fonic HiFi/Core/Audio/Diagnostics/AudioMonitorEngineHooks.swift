import Foundation
import OSLog

@MainActor
final class AudioMonitorEngineHooks {
    private var engine: AudioEngineService?
    private var metricsTask: Task<Void, Never>?
    private var monitoringInterval: TimeInterval = 1.0
    private var isMonitoringActive = false
    private let logger: Logger
    private let sleep: @Sendable (TimeInterval) async throws -> Void

    init(
        logger: Logger,
        sleep: @escaping @Sendable (TimeInterval) async throws -> Void = AudioMonitorEngineHooks.sleep
    ) {
        self.logger = logger
        self.sleep = sleep
    }

    func setEngine(_ engine: AudioEngineService?) {
        metricsTask?.cancel()
        metricsTask = nil
        self.engine = engine

        guard isMonitoringActive,
              let engine,
              engine.metricsAvailability.supportsCollection
        else { return }
        startMetricsTask(for: engine, interval: monitoringInterval)
    }

    func startMonitoring(interval: TimeInterval) {
        monitoringInterval = interval
        isMonitoringActive = true

        guard let engine, engine.metricsAvailability.supportsCollection else { return }
        startMetricsTask(for: engine, interval: interval)
    }

    func stopMonitoring() {
        isMonitoringActive = false
        metricsTask?.cancel()
        metricsTask = nil
    }

    func updateMonitoringInterval(to interval: TimeInterval) {
        monitoringInterval = interval
        guard isMonitoringActive,
              let engine,
              engine.metricsAvailability.supportsCollection
        else { return }
        startMetricsTask(for: engine, interval: interval)
    }

    private func startMetricsTask(for engine: AudioEngineService, interval: TimeInterval) {
        metricsTask?.cancel()

        let adjusted = adjustedInterval(for: engine, requested: interval)
        logger.debug("Starting engine metrics polling at \(adjusted, privacy: .public)s for \(type(of: engine), privacy: .public)")

        metricsTask = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.pollMetrics(interval: adjusted)
        }
    }

    private func adjustedInterval(for engine: AudioEngineService, requested: TimeInterval) -> TimeInterval {
        let minimum: TimeInterval = engine is AudioKitEngineAdapter ? 0.05 : 0.1
        let maximum: TimeInterval = 5.0
        let clamped = max(minimum, min(requested, maximum))
        return clamped
    }

    private func pollMetrics(interval: TimeInterval) async {
        guard let initialEngine = engine else { return }

        await initialEngine.collectMetrics()

        while !Task.isCancelled {
            do {
                try await sleep(interval)
            } catch {
                break
            }

            guard !Task.isCancelled,
                  let currentEngine = engine,
                  currentEngine.metricsAvailability.supportsCollection
            else { break }
            await currentEngine.collectMetrics()
        }
    }

    private static func sleep(_ interval: TimeInterval) async throws {
        let seconds = max(interval, 0.0)
        let nanoseconds = UInt64(seconds * 1_000_000_000)
        try await Task.sleep(nanoseconds: nanoseconds)
    }

    deinit {
        metricsTask?.cancel()
    }
}

extension AudioMonitorEngineHooks: AudioMonitorEngineHooking {}
