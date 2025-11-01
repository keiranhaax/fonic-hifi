import Foundation

@MainActor
final class AudioPerformanceAdvisor {
    func recommendations(for metrics: AudioMetrics?) -> [PerformanceRecommendation] {
        guard let metrics else {
            return [defaultRecommendation()]
        }

        var recommendations: [PerformanceRecommendation] = []

        if metrics.cpuUsage > 75 {
            recommendations.append(
                PerformanceRecommendation(
                    type: .performanceModeAdjustment,
                    priority: .high,
                    title: "Enable Performance Mode",
                    description: "CPU usage averaged \(Int(metrics.cpuUsage))%. Enable performance mode to prioritize audio threads.",
                    expectedImprovement: "CPU spikes reduced by ~15%",
                    technicalDetails: "Activates AVAudioSessionModeVideoRecording and raises audio thread QoS.",
                    canAutoApply: false
                )
            )
        }

        if metrics.bufferFillLevel < 0.35 {
            recommendations.append(
                PerformanceRecommendation(
                    type: .audioSessionConfiguration,
                    priority: .medium,
                    title: "Increase IO Buffer Duration",
                    description: "Buffer fill dropped to \(Int(metrics.bufferFillLevel * 100))%. Increasing IO buffer provides more headroom.",
                    expectedImprovement: "Underruns reduced by up to 60%",
                    technicalDetails: "Set AVAudioSession.ioBufferDuration to 0.012s when using high resolution content.",
                    canAutoApply: true
                )
            )
        }

        if metrics.jitter > 0.004 {
            recommendations.append(
                PerformanceRecommendation(
                    type: .engineSelection,
                    priority: .medium,
                    title: "Use Wired Output",
                    description: "Detected jitter of \(String(format: "%.3f", metrics.jitter * 1000)) ms. Wired output stabilizes the master clock.",
                    expectedImprovement: "Jitter floor reduced by ~40%",
                    technicalDetails: "Switch to USB or Lightning DAC for critical listening sessions.",
                    canAutoApply: false
                )
            )
        }

        if !metrics.isBitPerfect {
            recommendations.append(
                PerformanceRecommendation(
                    type: .formatOptimization,
                    priority: .medium,
                    title: "Review Output Format",
                    description: "Bit-perfect playback is disabled. Matching output sample rate avoids SRC artifacts.",
                    expectedImprovement: "Quality score +5",
                    technicalDetails: "Align AVAudioSession sample rate with source (\(Int(metrics.sampleRate)) Hz).",
                    canAutoApply: false
                )
            )
        }

        if recommendations.isEmpty {
            recommendations.append(defaultRecommendation())
        }

        return recommendations
    }

    func opportunities(for metrics: AudioMetrics?) -> [OptimizationOpportunity] {
        guard let metrics else { return [] }

        var opportunities: [OptimizationOpportunity] = []

        if Double(metrics.memoryUsage) / 1_048_576 > 450 {
            let reclaimed = Int(Double(metrics.memoryUsage) / 1_048_576 - 450)
            opportunities.append(
                OptimizationOpportunity(
                    type: .resourceManagement,
                    description: "Unload inactive visualizers to reclaim \(reclaimed) MB",
                    expectedGain: 12,
                    complexity: .medium
                )
            )
        }

        if Double(metrics.networkBandwidth) / 1_000_000 > 8 {
            opportunities.append(
                OptimizationOpportunity(
                    type: .formatOptimization,
                    description: "Transcode cached radio streams to AAC 256 for lower bandwidth during roaming",
                    expectedGain: 9,
                    complexity: .medium
                )
            )
        }

        return opportunities
    }

    private func defaultRecommendation() -> PerformanceRecommendation {
        PerformanceRecommendation(
            type: .backgroundAppManagement,
            priority: .low,
            title: "Maintain Current Configuration",
            description: "No critical issues detected during the monitoring window.",
            expectedImprovement: "N/A",
            technicalDetails: "Continue monitoring if workload changes.",
            canAutoApply: false
        )
    }
}
