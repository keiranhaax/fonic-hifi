// Performance Monitoring Contract
// Version: 1.0
// Purpose: Define interface for performance and health monitoring

import Foundation

// MARK: - Protocol Definition

protocol PerformanceMonitoring: Sendable {
    // Audio Metrics
    func recordAudioLatency(_ latency: TimeInterval) async
    func recordBufferUnderrun() async
    func recordFormatSwitch(from: AudioFormat, to: AudioFormat, duration: TimeInterval) async

    // Memory Metrics
    func recordMemoryUsage(_ bytes: Int64) async
    func recordMemoryWarning() async
    func checkMemoryPressure() async -> MemoryPressure

    // Performance Metrics
    func recordAppLaunchTime(_ duration: TimeInterval) async
    func recordSearchLatency(_ duration: TimeInterval, resultCount: Int) async
    func recordImportPerformance(_ metrics: ImportMetrics) async

    // Error Tracking
    func recordError(_ error: Error, context: String) async
    func recordCrash(_ reason: String) async

    // Reporting
    func generateReport() async -> PerformanceReport
    func reset() async
}

// MARK: - Data Types

struct PerformanceReport: Sendable {
    let period: DateInterval
    let audioMetrics: AudioPerformanceMetrics
    let memoryMetrics: MemoryMetrics
    let performanceMetrics: AppPerformanceMetrics
    let errorMetrics: ErrorMetrics
}

struct AudioPerformanceMetrics: Sendable {
    let averageLatency: TimeInterval
    let maxLatency: TimeInterval
    let bufferUnderrunCount: Int
    let formatSwitchCount: Int
    let averageFormatSwitchTime: TimeInterval
    let bitPerfectSessions: Int
    let totalPlaybackTime: TimeInterval
}

struct MemoryMetrics: Sendable {
    let averageUsage: Int64 // Bytes
    let peakUsage: Int64
    let warningCount: Int
    let pressureEvents: [MemoryPressure]
}

struct AppPerformanceMetrics: Sendable {
    let appLaunchTime: TimeInterval?
    let averageSearchLatency: TimeInterval
    let p95SearchLatency: TimeInterval
    let totalImports: Int
    let averageImportTime: TimeInterval
    let failedImports: Int
}

struct ErrorMetrics: Sendable {
    let totalErrors: Int
    let errorsByType: [String: Int]
    let crashCount: Int
    let crashReasons: [String]
}

enum MemoryPressure: String, Sendable {
    case normal
    case warning
    case urgent
    case critical
}

// MARK: - Thresholds

struct PerformanceThresholds: Sendable {
    static let targetAudioLatency: TimeInterval = 0.05 // 50ms
    static let targetAppLaunchTime: TimeInterval = 2.0 // 2 seconds
    static let targetSearchLatency: TimeInterval = 0.15 // 150ms
    static let targetMemoryUsage: Int64 = 200 * 1024 * 1024 // 200MB
    static let acceptableCrashRate: Double = 0.001 // 0.1%
}

// MARK: - Contract Tests (These should fail initially)

final class MonitoringContractTests {
    func testAudioMetricsRecording() async throws {
        let monitor: PerformanceMonitoring = PerformanceMonitor() // Should fail: not implemented

        await monitor.recordAudioLatency(0.025)
        await monitor.recordBufferUnderrun()
        await monitor.recordFormatSwitch(from: .mp3, to: .flac, duration: 0.1)

        let report = await monitor.generateReport()
        assert(report.audioMetrics.bufferUnderrunCount == 1)
    }

    func testMemoryTracking() async throws {
        let monitor: PerformanceMonitoring = PerformanceMonitor() // Should fail: not implemented

        await monitor.recordMemoryUsage(150 * 1024 * 1024) // 150MB
        let pressure = await monitor.checkMemoryPressure()
        assert(pressure == .normal)

        await monitor.recordMemoryWarning()
        let report = await monitor.generateReport()
        assert(report.memoryMetrics.warningCount == 1)
    }

    func testPerformanceMetrics() async throws {
        let monitor: PerformanceMonitoring = PerformanceMonitor() // Should fail: not implemented

        await monitor.recordAppLaunchTime(1.5)
        await monitor.recordSearchLatency(0.1, resultCount: 100)

        let importMetrics = ImportMetrics(
            totalFiles: 100,
            successfulImports: 98,
            failedImports: 2,
            duplicatesSkipped: 5,
            averageFileProcessingTime: 0.5,
            totalImportTime: 50,
        )
        await monitor.recordImportPerformance(importMetrics)

        let report = await monitor.generateReport()
        assert(report.performanceMetrics.appLaunchTime == 1.5)
    }

    func testErrorTracking() async throws {
        let monitor: PerformanceMonitoring = PerformanceMonitor() // Should fail: not implemented

        let error = PlaybackError.unsupportedFormat(.mp3)
        await monitor.recordError(error, context: "playback")

        let report = await monitor.generateReport()
        assert(report.errorMetrics.totalErrors == 1)
    }
}
