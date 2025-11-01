//
//  AudioPerformanceProfiler.swift
//  Fonic HiFi
//
//  Created by Droid on 10/6/25.
//

import Foundation

@MainActor
public final class AudioPerformanceProfiler {
    private(set) var profilingData: ProfilingData?
    private(set) var profilingStartTime: Date?
    private(set) var profilingDuration: TimeInterval?

    public init() {}

    public func beginProfiling(duration: TimeInterval?) {
        profilingStartTime = Date()
        profilingDuration = duration
        profilingData = ProfilingData()
    }

    public func markStop() {
        guard let startTime = profilingStartTime else { return }
        profilingDuration = Date().timeIntervalSince(startTime)
    }

    public func reset() {
        profilingData = nil
        profilingStartTime = nil
        profilingDuration = nil
    }

    public func collectSample(from metrics: AudioMetrics, at timestamp: Date = Date()) {
        guard let profilingData else { return }

        profilingData.cpuSamples.append(metrics.cpuUsage)
        profilingData.memorySamples.append(metrics.memoryUsage)
        profilingData.latencySamples.append(metrics.renderLatency)
        profilingData.bufferFillSamples.append(metrics.bufferFillLevel)
        profilingData.sampleTimestamps.append(timestamp)

        if let previousUnderruns = profilingData.lastKnownBufferUnderrunTotal {
            let delta = max(0, metrics.bufferUnderruns - previousUnderruns)
            profilingData.underrunCount += delta
        }
        profilingData.lastKnownBufferUnderrunTotal = metrics.bufferUnderruns

        let maxSamples = 600
        if profilingData.cpuSamples.count > maxSamples {
            profilingData.cpuSamples.removeFirst(profilingData.cpuSamples.count - maxSamples)
            profilingData.memorySamples.removeFirst(profilingData.memorySamples.count - maxSamples)
            profilingData.latencySamples.removeFirst(profilingData.latencySamples.count - maxSamples)
            profilingData.bufferFillSamples.removeFirst(profilingData.bufferFillSamples.count - maxSamples)
            profilingData.sampleTimestamps.removeFirst(profilingData.sampleTimestamps.count - maxSamples)
        }
    }

    public func finalize() {
        guard let profilingData else { return }

        if let startTime = profilingStartTime {
            profilingDuration = Date().timeIntervalSince(startTime)
        }

        let alignedCount = min(
            profilingData.sampleTimestamps.count,
            profilingData.cpuSamples.count,
            profilingData.memorySamples.count,
            profilingData.latencySamples.count,
            profilingData.bufferFillSamples.count,
        )

        if alignedCount > 0 {
            profilingData.sampleTimestamps = Array(profilingData.sampleTimestamps.suffix(alignedCount))
            profilingData.cpuSamples = Array(profilingData.cpuSamples.suffix(alignedCount))
            profilingData.memorySamples = Array(profilingData.memorySamples.suffix(alignedCount))
            profilingData.latencySamples = Array(profilingData.latencySamples.suffix(alignedCount))
            profilingData.bufferFillSamples = Array(profilingData.bufferFillSamples.suffix(alignedCount))
        }

        profilingData.lastKnownBufferUnderrunTotal = nil
    }

    public func performanceProfile(for duration: TimeInterval) -> PerformanceProfile? {
        guard let profilingData, let startTime = profilingStartTime else { return nil }

        return PerformanceProfile(
            startTime: startTime,
            duration: duration,
            cpuProfile: profilingData.cpuProfile,
            memoryProfile: profilingData.memoryProfile,
            latencyProfile: profilingData.latencyProfile,
            bufferProfile: profilingData.bufferProfile,
            bottlenecks: [],
            optimizations: [],
        )
    }

    public func detectedBottlenecks() -> [PerformanceBottleneck] {
        guard let profilingData else { return [] }
        return detectedBottlenecks(for: profilingData)
    }

    func detectedBottlenecks(for profilingData: ProfilingData) -> [PerformanceBottleneck] {
        var bottlenecks: [PerformanceBottleneck] = []

        let cpuAverage = profilingData.cpuProfile.averageUsage
        if cpuAverage > 65 {
            let severity: BottleneckSeverity = switch cpuAverage {
            case 0 ..< 75: .moderate
            case 75 ..< 85: .major
            default: .critical
            }
            bottlenecks.append(
                PerformanceBottleneck(
                    type: .cpu,
                    description: "Audio threads are consuming \(Int(cpuAverage))% CPU on average",
                    severity: severity,
                    impactPercentage: min(cpuAverage, 100),
                ),
            )
        }

        let memoryPeakMB = Double(profilingData.memoryProfile.peakUsage) / 1_048_576
        if memoryPeakMB > 350 {
            let severity: BottleneckSeverity = memoryPeakMB > 600 ? .major : .moderate
            bottlenecks.append(
                PerformanceBottleneck(
                    type: .memory,
                    description: "Peak audio memory usage reached \(Int(memoryPeakMB)) MB",
                    severity: severity,
                    impactPercentage: Float(min(memoryPeakMB / 8.0 * 100.0, 100.0)),
                ),
            )
        }

        let maxLatency = profilingData.latencyProfile.maxLatency
        if maxLatency > 0.04 {
            let severity: BottleneckSeverity = maxLatency > 0.08 ? .critical : .major
            bottlenecks.append(
                PerformanceBottleneck(
                    type: .io,
                    description: "Render latency spiked to \(String(format: "%.0f", maxLatency * 1000)) ms",
                    severity: severity,
                    impactPercentage: Float(min(maxLatency * 2000, 100)),
                ),
            )
        }

        let minBufferFill = profilingData.bufferProfile.minBufferFill
        if minBufferFill < 0.35 {
            let severity: BottleneckSeverity = minBufferFill < 0.2 ? .critical : .major
            bottlenecks.append(
                PerformanceBottleneck(
                    type: .buffer,
                    description: "Buffer fill dipped to \(Int(minBufferFill * 100))%",
                    severity: severity,
                    impactPercentage: Float((1 - minBufferFill) * 100),
                ),
            )
        }

        return bottlenecks
    }

    public func optimizationOpportunities() -> [OptimizationOpportunity] {
        guard let profilingData else { return [] }
        return optimizationOpportunities(for: profilingData)
    }

    func optimizationOpportunities(for profilingData: ProfilingData) -> [OptimizationOpportunity] {
        var opportunities: [OptimizationOpportunity] = []

        if profilingData.cpuProfile.averageUsage > 65 {
            opportunities.append(
                OptimizationOpportunity(
                    type: .resourceManagement,
                    description: "Lower decoder quality or offload visualizations to reduce CPU load",
                    expectedGain: 15,
                    complexity: .medium,
                ),
            )
        }

        let minBufferFill = profilingData.bufferProfile.minBufferFill
        if minBufferFill < 0.4 {
            opportunities.append(
                OptimizationOpportunity(
                    type: .bufferSizing,
                    description: "Increase output buffer size to protect against underruns",
                    expectedGain: min(max(Float((0.5 - minBufferFill) * 100), 5.0), 30.0),
                    complexity: .low,
                ),
            )
        }

        let maxLatency = profilingData.latencyProfile.maxLatency
        if maxLatency > 0.05 {
            opportunities.append(
                OptimizationOpportunity(
                    type: .formatOptimization,
                    description: "Pre-decode high complexity formats or enable hardware decoding",
                    expectedGain: Float(min(maxLatency * 1200, 30)),
                    complexity: .medium,
                ),
            )
        }

        if profilingData.memoryProfile.peakUsage > 400 * 1_048_576 {
            opportunities.append(
                OptimizationOpportunity(
                    type: .resourceManagement,
                    description: "Release cached waveform data and purge inactive buffers",
                    expectedGain: 10,
                    complexity: .low,
                ),
            )
        }

        return opportunities
    }
}
