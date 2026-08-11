import Foundation
import OSLog
import os

enum MetricsCounter: String {
    case importsDiscovered = "imports.discovered"
    case importsCompleted = "imports.completed"
    case importsFailed = "imports.failed"
    case engineSwitch = "audio.engine.switch"
    case queueMutation = "audio.queue.mutation"
}

enum Metrics {
    typealias MetricsSink = @Sendable (MetricsCounter, Int, String, [String: String]) -> Void
    private static let defaultsKey = "com.fonichifi.metrics.enabled"
    private static let sinkLock = OSAllocatedUnfairLock<MetricsSink?>(initialState: nil)

    static var isEnabled: Bool {
        get {
            UserDefaults.standard.bool(forKey: defaultsKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: defaultsKey)
        }
    }

    static func enable(_ enabled: Bool) {
        isEnabled = enabled
    }

    static func increment(_ counter: MetricsCounter, by amount: Int = 1, metadata: [String: String] = [:]) {
        guard isEnabled, amount != 0 else { return }

        let meta = metadata
            .map { "\($0.key)=\($0.value)" }
            .sorted()
            .joined(separator: " ")

        if let sink = sinkLock.withLock({ $0 }) {
            sink(counter, amount, meta, metadata)
        }

        logger(for: counter).log("metric=\(counter.rawValue, privacy: .public) delta=\(amount, privacy: .public) \(meta, privacy: .private)")
    }

    private static func logger(for counter: MetricsCounter) -> Logger {
        switch counter {
        case .importsDiscovered, .importsCompleted, .importsFailed:
            return Log.logger(.metricsImport)
        case .engineSwitch:
            return Log.logger(.metricsEngine)
        case .queueMutation:
            return Log.logger(.metricsQueue)
        }
    }

    #if DEBUG
    static func setSinkForTesting(_ handler: MetricsSink?) {
        sinkLock.withLock { state in
            state = handler
        }
    }
    #endif
}
