import Foundation

@MainActor
final class AudioMonitoringReportBuilder {
    func summary(metrics: [AudioMetrics], alerts: [PlaybackAlert]) -> String {
        "Performance summary for \(metrics.count) samples and \(alerts.count) alerts"
    }

    func keyFindings(metrics: [AudioMetrics], alerts: [PlaybackAlert]) -> [String] {
        var findings: [String] = []

        if !alerts.isEmpty {
            findings.append("Total of \(alerts.count) alerts during monitoring period")
        }

        let avgCPU = average(of: metrics.map { Double($0.cpuUsage) })
        if avgCPU > 50 {
            findings.append("Average CPU usage was elevated at \(String(format: "%.1f", avgCPU))%")
        }

        return findings
    }

    func performanceTrends(for metrics: [AudioMetrics]) -> [PerformanceTrend] {
        guard metrics.count >= 2 else { return [] }

        let cpuIndicator = buildTrend(from: metrics.map { Double($0.cpuUsage) }, higherIsBetter: false)
        let memoryIndicator = buildTrend(from: metrics.map { Double($0.memoryUsage) / 1_048_576 }, higherIsBetter: false)
        let latencyIndicator = buildTrend(from: metrics.map { Double($0.renderLatency * 1000) }, higherIsBetter: false)
        let qualityIndicator = buildTrend(from: metrics.map { Double($0.qualityScore * 100) }, higherIsBetter: true)
        let bufferIndicator = buildTrend(from: metrics.map { Double($0.bufferFillLevel * 100) }, higherIsBetter: true)

        let trends = [
            makePerformanceTrend(label: "CPU Usage", indicator: cpuIndicator),
            makePerformanceTrend(label: "Memory Usage", indicator: memoryIndicator),
            makePerformanceTrend(label: "Render Latency", indicator: latencyIndicator),
            makePerformanceTrend(label: "Quality Score", indicator: qualityIndicator),
            makePerformanceTrend(label: "Buffer Fill", indicator: bufferIndicator),
        ]

        return trends.filter { abs($0.magnitude) >= 1 || $0.direction != .stable }
    }

    func trendSummary(for metrics: [AudioMetrics]) -> PerformanceTrendSummary {
        let cpuTrend = buildTrend(from: metrics.map { Double($0.cpuUsage) }, higherIsBetter: false)
        let memoryTrend = buildTrend(from: metrics.map { Double($0.memoryUsage) / 1_048_576 }, higherIsBetter: false)
        let latencyTrend = buildTrend(from: metrics.map { Double($0.renderLatency * 1000) }, higherIsBetter: false)
        let qualityTrend = buildTrend(from: metrics.map { Double($0.qualityScore * 100) }, higherIsBetter: true)
        let bufferTrend = buildTrend(from: metrics.map { Double($0.bufferFillLevel * 100) }, higherIsBetter: true)

        let overallTrend = deriveOverallTrend([cpuTrend, memoryTrend, latencyTrend, qualityTrend, bufferTrend])

        return PerformanceTrendSummary(
            cpuTrend: cpuTrend,
            memoryTrend: memoryTrend,
            latencyTrend: latencyTrend,
            qualityTrend: qualityTrend,
            bufferTrend: bufferTrend,
            overallTrend: overallTrend
        )
    }

    func average(of values: [Double]) -> Double {
        guard !values.isEmpty else { return 0 }
        return values.reduce(0, +) / Double(values.count)
    }

    // MARK: - Private Helpers

    private func standardDeviation(of values: [Double]) -> Double {
        guard values.count > 1 else { return 0 }
        let mean = average(of: values)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance)
    }

    private func buildTrend(from values: [Double], higherIsBetter: Bool) -> TrendIndicator {
        guard !values.isEmpty else {
            return TrendIndicator(currentValue: 0, changePercent: 0, direction: .stable, stability: .stable)
        }

        let current = values.last ?? 0
        let historical = Array(values.dropLast())
        let baseline = historical.isEmpty ? current : average(of: historical)
        let delta = current - baseline
        let changePercent = baseline == 0 ? 0 : (delta / abs(baseline)) * 100
        let stability = trendStability(for: values)

        let direction: TrendDirection
        if stability == .volatile {
            direction = .volatile
        } else {
            let threshold = 1.5
            if higherIsBetter {
                if changePercent > threshold { direction = .improving }
                else if changePercent < -threshold { direction = .degrading }
                else { direction = .stable }
            } else {
                if changePercent < -threshold { direction = .improving }
                else if changePercent > threshold { direction = .degrading }
                else { direction = .stable }
            }
        }

        return TrendIndicator(currentValue: current, changePercent: changePercent, direction: direction, stability: stability)
    }

    private func makePerformanceTrend(label: String, indicator: TrendIndicator) -> PerformanceTrend {
        let magnitude = abs(indicator.changePercent)
        let significance: TrendSignificance = switch magnitude {
        case 0 ..< 2: .low
        case 2 ..< 5: .medium
        case 5 ..< 10: .high
        default: .veryHigh
        }

        let description = "\(label): \(String(format: "%.1f", indicator.currentValue)) (\(String(format: "%.1f", indicator.changePercent))%)"

        return PerformanceTrend(metric: label, direction: indicator.direction, magnitude: magnitude, significance: significance, description: description)
    }

    private func trendStability(for values: [Double]) -> TrendStability {
        guard !values.isEmpty else { return .stable }
        let mean = average(of: values.map { abs($0) })
        let deviation = standardDeviation(of: values)
        let ratio = mean == 0 ? deviation : deviation / (mean + 1)

        switch ratio {
        case ..<0.05: return .stable
        case ..<0.15: return .fluctuating
        default: return .volatile
        }
    }

    private func deriveOverallTrend(_ indicators: [TrendIndicator]) -> TrendDirection {
        if indicators.contains(where: { $0.direction == .volatile }) {
            return .volatile
        }

        let score = indicators.reduce(0.0) { partial, indicator -> Double in
            switch indicator.direction {
            case .improving: return partial + 1
            case .degrading: return partial - 1
            case .volatile: return partial
            case .stable: return partial
            }
        } / Double(max(indicators.count, 1))

        if score > 0.3 { return .improving }
        if score < -0.3 { return .degrading }
        return .stable
    }
}
