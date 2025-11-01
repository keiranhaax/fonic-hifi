import Foundation

@MainActor
final class AudioMonitorMetricsCollector {
    private let systemMetricsCollector: any SystemMetricsCollecting
    private let thermalStateMonitor: any ThermalStateMonitoring
    private let engineMetricsCollector: any EngineMetricsCollecting

    init(
        systemMetricsCollector: any SystemMetricsCollecting,
        thermalStateMonitor: any ThermalStateMonitoring,
        engineMetricsCollector: any EngineMetricsCollecting
    ) {
        self.systemMetricsCollector = systemMetricsCollector
        self.thermalStateMonitor = thermalStateMonitor
        self.engineMetricsCollector = engineMetricsCollector
    }

    func collectMetrics(
        for engine: AudioEngineService?,
        analytics: AudioSessionAnalytics,
        timeSinceLastUnderrun: TimeInterval?
    ) async -> AudioMetrics {
        let systemMetrics = await systemMetricsCollector.collectCurrentMetrics()
        let thermalInfo = await thermalStateMonitor.getCurrentState()
        let engineMetrics = await engineMetricsCollector.metrics(for: engine)

        return AudioMetrics(
            cpuUsage: systemMetrics.cpuUsage,
            memoryUsage: systemMetrics.memoryUsage,
            bufferUnderruns: engineMetrics.bufferUnderruns,
            decodingLatency: engineMetrics.decodingLatency,
            bufferFillLevel: engineMetrics.bufferFillLevel,
            droppedFrames: engineMetrics.droppedFrames,
            renderLatency: engineMetrics.renderLatency,
            currentBitrate: engineMetrics.currentBitrate,
            averageLatency: analytics.averageLatency(),
            peakLatency: analytics.peakLatency(),
            glitchCount: engineMetrics.glitchCount,
            sampleRate: engineMetrics.sampleRate,
            bitDepth: engineMetrics.bitDepth,
            channelCount: engineMetrics.channelCount,
            engineType: engineMetrics.engineType,
            audioFormat: engineMetrics.audioFormat,
            isBitPerfect: engineMetrics.isBitPerfect,
            bufferSize: engineMetrics.bufferSize,
            bufferResets: engineMetrics.bufferResets,
            averageBufferFill: analytics.averageBufferFill(),
            underrunRate: analytics.underrunRate(),
            timeSinceLastUnderrun: timeSinceLastUnderrun,
            diskIOPS: systemMetrics.diskIOPS,
            networkBandwidth: systemMetrics.networkBandwidth,
            thermalPressure: Float(thermalInfo.isThrottling ? 0.8 : 0.2),
            batteryUsageRate: systemMetrics.batteryUsageRate,
            threadUtilization: engineMetrics.threadUtilization,
            estimatedSNR: engineMetrics.estimatedSNR,
            dynamicRange: engineMetrics.dynamicRange,
            frequencyResponseScore: engineMetrics.frequencyResponseScore,
            jitter: engineMetrics.jitter,
            clockDrift: engineMetrics.clockDrift,
            recoverableErrors: engineMetrics.recoverableErrors,
            criticalErrors: engineMetrics.criticalErrors,
            recoverySuccessRate: engineMetrics.recoverySuccessRate,
            lastRecoveryTime: engineMetrics.lastRecoveryTime,
            performanceScore: calculatePerformanceScore(systemMetrics, engineMetrics),
            qualityScore: calculateQualityScore(engineMetrics),
            reliabilityScore: calculateReliabilityScore(engineMetrics),
            efficiencyScore: calculateEfficiencyScore(systemMetrics, thermalInfo)
        )
    }
}

private extension AudioMonitorMetricsCollector {
    func calculatePerformanceScore(_ systemMetrics: SystemMetrics, _ engineMetrics: EngineMetrics) -> Float {
        var score: Float = 1.0

        if systemMetrics.cpuUsage > 80 {
            score -= 0.3
        } else if systemMetrics.cpuUsage > 60 {
            score -= 0.15
        }

        if engineMetrics.bufferUnderruns > 0 {
            score -= 0.4
        }

        if engineMetrics.droppedFrames > 0 {
            score -= 0.2
        }

        if engineMetrics.renderLatency > 0.1 {
            score -= 0.1
        }

        return max(0.0, min(1.0, score))
    }

    func calculateQualityScore(_ engineMetrics: EngineMetrics) -> Float {
        var score: Float = 1.0

        if engineMetrics.isBitPerfect {
            score += 0.1
        }

        if engineMetrics.sampleRate >= 96_000, engineMetrics.bitDepth >= 24 {
            score += 0.05
        }

        if engineMetrics.glitchCount > 0 {
            score -= 0.3
        }

        if let snr = engineMetrics.estimatedSNR, snr > 100 {
            score += 0.05
        }

        return max(0.0, min(1.0, score))
    }

    func calculateReliabilityScore(_ engineMetrics: EngineMetrics) -> Float {
        var score: Float = 1.0

        if engineMetrics.criticalErrors > 0 {
            score -= 0.5
        }

        if engineMetrics.recoverableErrors > 0 {
            score -= 0.2
        }

        score *= engineMetrics.recoverySuccessRate

        return max(0.0, min(1.0, score))
    }

    func calculateEfficiencyScore(_ systemMetrics: SystemMetrics, _ thermalInfo: ThermalMonitoringInfo) -> Float {
        var score: Float = 1.0

        if systemMetrics.cpuUsage < 30 {
            score += 0.1
        } else if systemMetrics.cpuUsage > 70 {
            score -= 0.2
        }

        if thermalInfo.isThrottling {
            score -= 0.3
        }

        if let batteryRate = systemMetrics.batteryUsageRate, batteryRate < 100 {
            score += 0.05
        }

        return max(0.0, min(1.0, score))
    }
}
