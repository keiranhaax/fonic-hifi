@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioPerformanceAdvisorTests: XCTestCase {
    func testRecommendationsCoverCriticalScenarios() {
        let advisor = AudioPerformanceAdvisor()

        let metrics = AudioMetrics(
            cpuUsage: 82,
            memoryUsage: 512 * 1_048_576,
            bufferUnderruns: 2,
            decodingLatency: 0.01,
            bufferFillLevel: 0.2,
            droppedFrames: 1,
            renderLatency: 0.02,
            currentBitrate: 2_000_000,
            averageLatency: 0.02,
            peakLatency: 0.04,
            glitchCount: 1,
            sampleRate: 192_000,
            bitDepth: 24,
            channelCount: 2,
            engineType: "TestEngine",
            audioFormat: "flac",
            isBitPerfect: false,
            bufferSize: 512,
            bufferResets: 1,
            averageBufferFill: 0.25,
            underrunRate: 0.5,
            timeSinceLastUnderrun: 10,
            diskIOPS: 120,
            networkBandwidth: 12_000_000,
            thermalPressure: 0.5,
            batteryUsageRate: 180,
            threadUtilization: ThreadUtilization(audioThreadCPU: 40, decoderThreadCPU: 20, ioThreadCPU: 5, mainThreadCPU: 3, activeThreadCount: 4),
            estimatedSNR: 95,
            dynamicRange: 110,
            frequencyResponseScore: 0.9,
            jitter: 0.005,
            clockDrift: 0.0004,
            recoverableErrors: 1,
            criticalErrors: 0,
            recoverySuccessRate: 0.9,
            lastRecoveryTime: 0.5,
            performanceScore: 0.82,
            qualityScore: 0.88,
            reliabilityScore: 0.86,
            efficiencyScore: 0.8
        )

        let recommendations = advisor.recommendations(for: metrics)

        XCTAssertTrue(recommendations.contains(where: { $0.type == .performanceModeAdjustment }))
        XCTAssertTrue(recommendations.contains(where: { $0.type == .audioSessionConfiguration }))
        XCTAssertTrue(recommendations.contains(where: { $0.type == .engineSelection }))
        XCTAssertTrue(recommendations.contains(where: { $0.type == .formatOptimization }))
    }

    func testRecommendationsFallbackWhenNoMetrics() {
        let advisor = AudioPerformanceAdvisor()

        let recommendations = advisor.recommendations(for: nil)

        XCTAssertEqual(recommendations.count, 1)
        XCTAssertEqual(recommendations.first?.title, "Maintain Current Configuration")
    }

    func testOptimizationOpportunitiesBasedOnLatestMetrics() {
        let advisor = AudioPerformanceAdvisor()

        let metrics = AudioMetrics(
            cpuUsage: 45,
            memoryUsage: 600 * 1_048_576,
            bufferUnderruns: 0,
            decodingLatency: 0.008,
            bufferFillLevel: 0.9,
            droppedFrames: 0,
            renderLatency: 0.015,
            currentBitrate: 320_000,
            averageLatency: 0.015,
            peakLatency: 0.02,
            glitchCount: 0,
            sampleRate: 96_000,
            bitDepth: 24,
            channelCount: 2,
            engineType: "TestEngine",
            audioFormat: "aac",
            isBitPerfect: true,
            bufferSize: 512,
            bufferResets: 0,
            averageBufferFill: 0.9,
            underrunRate: 0,
            timeSinceLastUnderrun: nil,
            diskIOPS: 50,
            networkBandwidth: 12_000_000,
            thermalPressure: 0.2,
            batteryUsageRate: 120,
            threadUtilization: ThreadUtilization(audioThreadCPU: 10, decoderThreadCPU: 5, ioThreadCPU: 2, mainThreadCPU: 1, activeThreadCount: 3),
            estimatedSNR: 90,
            dynamicRange: 100,
            frequencyResponseScore: 0.85,
            jitter: 0.001,
            clockDrift: 0.0001,
            recoverableErrors: 0,
            criticalErrors: 0,
            recoverySuccessRate: 1,
            lastRecoveryTime: nil,
            performanceScore: 0.9,
            qualityScore: 0.92,
            reliabilityScore: 0.94,
            efficiencyScore: 0.9
        )

        let opportunities = advisor.opportunities(for: metrics)

        XCTAssertTrue(opportunities.contains(where: { $0.type == .resourceManagement }))
        XCTAssertTrue(opportunities.contains(where: { $0.type == .formatOptimization }))
    }
}
