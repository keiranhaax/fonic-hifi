@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioMonitoringCollectorsTests: XCTestCase {
    func testEngineMetricsCollectorReturnsDefaultWhenEngineMissing() async {
        let collector = EngineMetricsCollector()

        let metrics = await collector.metrics(for: nil)

        XCTAssertEqual(metrics.bufferUnderruns, 0)
        XCTAssertFalse(metrics.isBitPerfect)
        XCTAssertEqual(metrics.bufferFillLevel, 1.0, accuracy: 0.0001)
    }

    func testEngineMetricsCollectorMapsAudioMetrics() async {
        let expected = AudioMetrics(
            cpuUsage: 45,
            memoryUsage: 128_000_000,
            bufferUnderruns: 3,
            decodingLatency: 0.012,
            bufferFillLevel: 0.62,
            droppedFrames: 5,
            renderLatency: 0.018,
            currentBitrate: 2_800_000,
            averageLatency: 0.02,
            peakLatency: 0.04,
            glitchCount: 1,
            sampleRate: 96000,
            bitDepth: 24,
            channelCount: 2,
            engineType: "AudioKit",
            audioFormat: "flac",
            isBitPerfect: true,
            bufferSize: 1024,
            bufferResets: 2,
            averageBufferFill: 0.75,
            underrunRate: 0.2,
            timeSinceLastUnderrun: 10,
            diskIOPS: 80,
            networkBandwidth: 256_000,
            thermalPressure: 0.2,
            batteryUsageRate: 120,
            threadUtilization: ThreadUtilization(audioThreadCPU: 20, decoderThreadCPU: 10, ioThreadCPU: 5, mainThreadCPU: 3, activeThreadCount: 4),
            estimatedSNR: 95,
            dynamicRange: 110,
            frequencyResponseScore: 0.92,
            jitter: 0.0008,
            clockDrift: 0.0002,
            recoverableErrors: 1,
            criticalErrors: 0,
            recoverySuccessRate: 0.9,
            lastRecoveryTime: 0.5,
            performanceScore: 0.88,
            qualityScore: 0.91,
            reliabilityScore: 0.93,
            efficiencyScore: 0.85,
        )

        let engine = StubAudioEngine(metrics: expected)
        let collector = EngineMetricsCollector()

        let metrics = await collector.metrics(for: engine)

        XCTAssertEqual(metrics.bufferUnderruns, expected.bufferUnderruns)
        XCTAssertEqual(metrics.droppedFrames, expected.droppedFrames)
        XCTAssertEqual(metrics.renderLatency, expected.renderLatency)
        XCTAssertTrue(metrics.isBitPerfect)
        XCTAssertEqual(metrics.threadUtilization.audioThreadCPU, expected.threadUtilization.audioThreadCPU)
        XCTAssertEqual(metrics.recoverySuccessRate, expected.recoverySuccessRate, accuracy: 0.0001)
        XCTAssertEqual(metrics.lastRecoveryTime, expected.lastRecoveryTime)
    }

    func testSystemMetricsCollectorProvidesRuntimeValues() async {
        let collector = SystemMetricsCollector()
        await collector.startMonitoring()

        let metrics = await collector.collectCurrentMetrics()

        XCTAssertGreaterThanOrEqual(metrics.cpuUsage, 0)
        XCTAssertLessThanOrEqual(metrics.cpuUsage, 100)
        XCTAssertGreaterThanOrEqual(metrics.memoryUsage, 0)
        XCTAssertGreaterThanOrEqual(metrics.diskIOPS, 0)
        XCTAssertGreaterThanOrEqual(metrics.networkBandwidth, 0)
        if let batteryRate = metrics.batteryUsageRate {
            XCTAssertGreaterThanOrEqual(batteryRate, 0)
        }
    }

    func testSystemMetricsCollectorReportsSystemAudioMetrics() async {
        let collector = SystemMetricsCollector()
        await collector.startMonitoring()

        let metrics = await collector.collectSystemMetrics()

        XCTAssertGreaterThanOrEqual(metrics.systemAudioCPU, 0)
        XCTAssertLessThanOrEqual(metrics.systemAudioCPU, 100)
        XCTAssertGreaterThanOrEqual(metrics.activeAudioSessions, 1)
        XCTAssertGreaterThanOrEqual(metrics.systemAudioMemory, 0)
        XCTAssertGreaterThan(metrics.deviceInfo.sampleRate, 0)
        XCTAssertGreaterThan(metrics.deviceInfo.channels, 0)
        XCTAssertGreaterThan(metrics.deviceInfo.bufferSize, 0)
        XCTAssertGreaterThanOrEqual(metrics.audioUnitLoad, 0)
        XCTAssertLessThanOrEqual(metrics.audioUnitLoad, 1)
    }

    func testThermalStateMonitorProvidesNominalState() async {
        let monitor = ThermalStateMonitor()

        await monitor.startMonitoring()
        let info = await monitor.getCurrentState()

        XCTAssertEqual(info.thermalState, .nominal)
        XCTAssertFalse(info.isThrottling)
        XCTAssertTrue(info.recommendedAdjustments.isEmpty)
    }

    func testInterruptionStatsTrackerAggregatesInformation() async {
        let tracker = InterruptionStatsTracker()
        let start = Date()

        let begin = AudioSessionInterruption(
            type: .began,
            shouldResume: false,
            timestamp: start,
            category: .phoneCall
        )

        let end = AudioSessionInterruption(
            type: .ended,
            shouldResume: true,
            timestamp: start.addingTimeInterval(2),
            category: .phoneCall
        )

        await tracker.recordInterruption(begin)
        await tracker.recordInterruption(end)

        let stats = await tracker.getStatistics()

        XCTAssertEqual(stats.totalInterruptions, 2)
        XCTAssertEqual(stats.interruptionsByType[.began], 1)
        XCTAssertEqual(stats.interruptionsByType[.ended], 1)
        XCTAssertEqual(stats.averageInterruptionDuration, 2, accuracy: 0.001)
        XCTAssertEqual(stats.longestInterruptionDuration, 2, accuracy: 0.001)
        XCTAssertEqual(stats.recoverySuccessRate, 1.0, accuracy: 0.0001)
        XCTAssertEqual(stats.lastInterruptionTime, end.timestamp)
    }

    func testAudioSessionAnalyticsTracksHistoryAndCounters() {
        let analytics = AudioSessionAnalytics(maxEntries: 3)

        analytics.startNewSession(at: Date(timeIntervalSince1970: 0))

        for index in 0..<5 {
            let metric = AudioMetrics(
                cpuUsage: Float(index) * 10,
                memoryUsage: Int64(index) * 1_000,
                bufferUnderruns: index,
                decodingLatency: Double(index) * 0.01,
                bufferFillLevel: 1 - (Float(index) * 0.1),
                droppedFrames: index,
                renderLatency: Double(index) * 0.02
            )
            analytics.append(metric)
            analytics.recordPerformanceCounters(for: metric)
        }

        XCTAssertEqual(analytics.historySnapshot.count, 3)
        XCTAssertEqual(analytics.latestMetric?.bufferUnderruns, 4)
        XCTAssertEqual(analytics.performanceCounters["total_samples"], 5)
        XCTAssertEqual(analytics.performanceCounters["cpu_max"], 40)
        XCTAssertNotNil(analytics.sessionStartTime)

        let average = analytics.averageMetrics()
        XCTAssertGreaterThan(average.cpuUsage, 0)
        XCTAssertGreaterThan(analytics.peakMetrics().renderLatency, 0)
        XCTAssertNotEqual(analytics.overallHealth(), .critical)
        XCTAssertGreaterThan(analytics.sessionPerformanceScore(), 0)
    }

    func testSessionSummaryAggregatesAlertsAndMetrics() {
        let analytics = AudioSessionAnalytics()
        analytics.startNewSession(at: Date(timeIntervalSince1970: 0))

        analytics.append(
            AudioMetrics(
                cpuUsage: 35,
                memoryUsage: 240_000_000,
                bufferUnderruns: 2,
                decodingLatency: 0.02,
                bufferFillLevel: 0.8,
                droppedFrames: 1,
                renderLatency: 0.015
            )
        )

        let alerts = [
            PlaybackAlert(
                type: .bufferUnderrun,
                severity: .high,
                message: "Underrun",
                technicalDetails: "",
                timestamp: Date(),
                triggerValues: [:],
                suggestedActions: []
            ),
            PlaybackAlert(
                type: .highCPUUsage,
                severity: .medium,
                message: "High CPU",
                technicalDetails: "",
                timestamp: Date(),
                triggerValues: [:],
                suggestedActions: []
            ),
        ]

        let summary = analytics.sessionSummary(alertHistory: alerts)

        XCTAssertEqual(summary.totalAlerts, 2)
        XCTAssertEqual(summary.alertsByType[.bufferUnderrun], 1)
        XCTAssertEqual(summary.sampleCount, 1)
        XCTAssertGreaterThan(summary.duration, 0)
        XCTAssertEqual(summary.averageMetrics.cpuUsage, 35, accuracy: 0.001)
    }
}

@MainActor
private final class StubAudioEngine: AudioEngineService {
    private let storedMetrics: AudioMetrics

    init(metrics: AudioMetrics) {
        storedMetrics = metrics
    }

    var currentTime: TimeInterval { get async { 0 } }
    var duration: TimeInterval { get async { 0 } }
    var isPlaying: Bool { get async { false } }
    var volume: Float { get async { 1 } }
    var audioFormat: AudioFormat? { get async { nil } }

    func load(url _: URL) async throws {}
    func play() async throws {}
    func pause() async {}
    func stop() async {}
    func seek(to _: TimeInterval) async throws {}
    func setVolume(_: Float) async {}
    func configure(with _: AudioEngineConfiguration) async throws {}
    func prepareNext(url _: URL) async {}
    func crossfade(to _: URL, duration _: TimeInterval, playbackRate _: Double, gainDB _: Float) async throws {}
    func getMetrics() async -> AudioMetrics { storedMetrics }
    func collectMetrics() async {}
    func setPlaybackRate(_: Double) async {}
    func applyReplayGain(_: Float) async {}
}
