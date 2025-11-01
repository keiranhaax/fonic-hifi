@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioPerformanceProfilerTests: XCTestCase {
    func testCollectingSamplesStoresProfilingData() {
        let profiler = AudioPerformanceProfiler()
        profiler.beginProfiling(duration: 10)

        profiler.collectSample(from: makeMetrics(cpu: 30, memory: 120_000_000, bufferFill: 0.7, latency: 0.02))
        profiler.collectSample(from: makeMetrics(cpu: 45, memory: 150_000_000, bufferFill: 0.6, latency: 0.03))

        guard let data = profiler.profilingData else {
            XCTFail("Expected profiling data to be present")
            return
        }

        XCTAssertEqual(data.cpuSamples.count, 2)
        XCTAssertEqual(data.memorySamples.count, 2)
        XCTAssertEqual(data.latencySamples.count, 2)
        XCTAssertEqual(data.bufferFillSamples.count, 2)
        XCTAssertEqual(data.cpuProfile.peakUsage, 45)
        XCTAssertGreaterThan(data.bufferProfile.averageBufferFill, 0.6)
    }

    func testDetectedBottlenecksWhenThresholdsExceeded() {
        let profiler = AudioPerformanceProfiler()
        profiler.beginProfiling(duration: nil)

        for _ in 0 ..< 5 {
            profiler.collectSample(from: makeMetrics(cpu: 85, memory: 450 * 1_048_576, bufferFill: 0.18, latency: 0.09))
        }

        let bottlenecks = profiler.detectedBottlenecks()

        XCTAssertTrue(bottlenecks.contains(where: { $0.type == .cpu }))
        XCTAssertTrue(bottlenecks.contains(where: { $0.type == .memory }))
        XCTAssertTrue(bottlenecks.contains(where: { $0.type == .io }))
        XCTAssertTrue(bottlenecks.contains(where: { $0.type == .buffer }))
    }

    func testOptimizationOpportunitiesReflectCapturedData() {
        let profiler = AudioPerformanceProfiler()
        profiler.beginProfiling(duration: nil)

        profiler.collectSample(from: makeMetrics(cpu: 70, memory: 500 * 1_048_576, bufferFill: 0.25, latency: 0.08))

        let opportunities = profiler.optimizationOpportunities()

        XCTAssertTrue(opportunities.contains(where: { $0.type == .resourceManagement }))
        XCTAssertTrue(opportunities.contains(where: { $0.type == .bufferSizing }))
        XCTAssertTrue(opportunities.contains(where: { $0.type == .formatOptimization }))
    }
}

private extension AudioPerformanceProfilerTests {
    func makeMetrics(
        cpu: Float,
        memory: Int64,
        bufferFill: Float,
        latency: TimeInterval,
    ) -> AudioMetrics {
        AudioMetrics(
            cpuUsage: cpu,
            memoryUsage: memory,
            bufferUnderruns: 2,
            decodingLatency: 0.01,
            bufferFillLevel: bufferFill,
            droppedFrames: 1,
            renderLatency: latency,
            currentBitrate: 2_000_000,
            averageLatency: latency,
            peakLatency: latency * 1.4,
            glitchCount: 1,
            sampleRate: 192_000,
            bitDepth: 24,
            channelCount: 2,
            engineType: "ProfilerEngine",
            audioFormat: "flac",
            isBitPerfect: true,
            bufferSize: 512,
            bufferResets: 1,
            averageBufferFill: bufferFill,
            underrunRate: 0.5,
            timeSinceLastUnderrun: 5,
            diskIOPS: 150,
            networkBandwidth: 0,
            thermalPressure: 0.5,
            batteryUsageRate: 200,
            threadUtilization: ThreadUtilization(audioThreadCPU: cpu / 2, decoderThreadCPU: cpu / 3, ioThreadCPU: 5, mainThreadCPU: 3, activeThreadCount: 4),
            estimatedSNR: 100,
            dynamicRange: 110,
            frequencyResponseScore: 0.95,
            jitter: 0.001,
            clockDrift: 0.0005,
            recoverableErrors: 1,
            criticalErrors: 0,
            recoverySuccessRate: 0.8,
            lastRecoveryTime: 0.4,
            performanceScore: 0.75,
            qualityScore: 0.88,
            reliabilityScore: 0.83,
            efficiencyScore: 0.7,
        )
    }
}
