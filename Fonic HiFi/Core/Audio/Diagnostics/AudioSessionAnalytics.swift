import Foundation

@MainActor
final class AudioSessionAnalytics {
    private let maxEntries: Int
    private var history: [AudioMetrics] = []
    private var counters: [String: Double] = [:]
    private var sessionStart: Date?

    init(maxEntries: Int = 1000) {
        self.maxEntries = maxEntries
    }

    func startNewSession(at startDate: Date = Date()) {
        history.removeAll()
        counters.removeAll()
        sessionStart = startDate
    }

    func append(_ metrics: AudioMetrics) {
        history.append(metrics)
        if history.count > maxEntries {
            history.removeFirst(history.count - maxEntries)
        }
    }

    func reset() {
        history.removeAll()
        counters.removeAll()
        sessionStart = nil
    }

    func recentMetrics(window: Int) -> [AudioMetrics] {
        guard !history.isEmpty else { return [] }
        let count = min(window, history.count)
        return Array(history.suffix(count))
    }

    var historySnapshot: [AudioMetrics] { history }

    var latestMetric: AudioMetrics? { history.last }

    var metricsCount: Int { history.count }

    var performanceCounters: [String: Double] { counters }

    var sessionStartTime: Date? { sessionStart }

    func averageLatency() -> TimeInterval {
        let latencies = history.map(\.renderLatency)
        guard !latencies.isEmpty else { return 0 }
        return latencies.reduce(0, +) / Double(latencies.count)
    }

    func peakLatency() -> TimeInterval {
        history.map(\.renderLatency).max() ?? 0
    }

    func averageBufferFill() -> Float {
        let fills = history.map(\.bufferFillLevel)
        guard !fills.isEmpty else { return 1.0 }
        return fills.reduce(0, +) / Float(fills.count)
    }

    func underrunRate(currentDate: Date = Date()) -> Float {
        guard let sessionStart else { return 0 }
        guard let latest = history.last else { return 0 }
        let duration = currentDate.timeIntervalSince(sessionStart)
        guard duration > 0 else { return 0 }
        return Float(latest.bufferUnderruns) / Float(duration / 60)
    }

    func averageMetrics() -> AudioMetrics {
        guard !history.isEmpty else { return AudioMetrics.empty }

        let count = Float(history.count)
        let avgCPU = history.map(\.cpuUsage).reduce(0, +) / count
        let avgMemory = history.map(\.memoryUsage).reduce(0, +) / Int64(history.count)
        let avgLatency = history.map(\.renderLatency).reduce(0, +) / Double(history.count)
        let avgBufferFill = history.map(\.bufferFillLevel).reduce(0, +) / count

        return AudioMetrics(
            cpuUsage: avgCPU,
            memoryUsage: avgMemory,
            bufferUnderruns: 0,
            decodingLatency: avgLatency,
            bufferFillLevel: avgBufferFill,
            droppedFrames: 0,
            renderLatency: avgLatency
        )
    }

    func peakMetrics() -> AudioMetrics {
        guard !history.isEmpty else { return AudioMetrics.empty }

        let maxCPU = history.map(\.cpuUsage).max() ?? 0
        let maxMemory = history.map(\.memoryUsage).max() ?? 0
        let maxLatency = history.map(\.renderLatency).max() ?? 0
        let minBufferFill = history.map(\.bufferFillLevel).min() ?? 1.0
        let maxUnderruns = history.map(\.bufferUnderruns).max() ?? 0
        let maxDroppedFrames = history.map(\.droppedFrames).max() ?? 0

        return AudioMetrics(
            cpuUsage: maxCPU,
            memoryUsage: maxMemory,
            bufferUnderruns: maxUnderruns,
            decodingLatency: maxLatency,
            bufferFillLevel: minBufferFill,
            droppedFrames: maxDroppedFrames,
            renderLatency: maxLatency
        )
    }

    func overallHealth(window: Int = 10) -> PlaybackHealthStatus {
        guard !history.isEmpty else { return .excellent }

        let recentMetrics = history.suffix(window)
        let avgPerformanceScore = recentMetrics.map(\.performanceScore).reduce(0, +) / Float(recentMetrics.count)
        let hasUnderruns = recentMetrics.contains { $0.bufferUnderruns > 0 }
        let hasCriticalErrors = recentMetrics.contains { $0.criticalErrors > 0 }

        if hasCriticalErrors {
            return .critical
        } else if hasUnderruns {
            return .poor
        } else if avgPerformanceScore >= 0.9 {
            return .excellent
        } else if avgPerformanceScore >= 0.7 {
            return .good
        } else {
            return .fair
        }
    }

    func sessionPerformanceScore() -> Double {
        guard !history.isEmpty else { return 1.0 }
        let avgPerformanceScore = history.map(\.performanceScore).reduce(0, +) / Float(history.count)
        return Double(avgPerformanceScore)
    }

    func recordPerformanceCounters(for metrics: AudioMetrics) {
        counters["total_samples"] = (counters["total_samples"] ?? 0) + 1
        counters["cpu_max"] = max(counters["cpu_max"] ?? 0, Double(metrics.cpuUsage))
        counters["memory_max"] = max(counters["memory_max"] ?? 0, Double(metrics.memoryUsage))
        counters["latency_max"] = max(counters["latency_max"] ?? 0, metrics.renderLatency)
        counters["underruns_total"] = Double(metrics.bufferUnderruns)
    }

    func sessionDuration(currentDate: Date = Date()) -> TimeInterval {
        guard let sessionStart else { return 0 }
        return currentDate.timeIntervalSince(sessionStart)
    }

}
