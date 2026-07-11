//
//  PerformanceMonitor.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import Foundation
import OSLog

// MARK: - Protocol Definition

public protocol PerformanceMonitoring: Sendable {
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

public struct PerformanceReport: Sendable {
    public let period: DateInterval
    public let audioMetrics: AudioPerformanceMetrics
    public let memoryMetrics: MemoryMetrics
    public let performanceMetrics: AppPerformanceMetrics
    public let errorMetrics: ErrorMetrics
}

public struct AudioPerformanceMetrics: Sendable {
    public let averageLatency: TimeInterval
    public let maxLatency: TimeInterval
    public let bufferUnderrunCount: Int
    public let formatSwitchCount: Int
    public let averageFormatSwitchTime: TimeInterval
}

public struct MemoryMetrics: Sendable {
    public let averageUsage: Int64 // Bytes
    public let peakUsage: Int64
    public let warningCount: Int
    public let pressureEvents: [MemoryPressure]
}

public struct AppPerformanceMetrics: Sendable {
    public let appLaunchTime: TimeInterval?
    public let averageSearchLatency: TimeInterval
    public let p95SearchLatency: TimeInterval
    public let totalImports: Int
    public let averageImportTime: TimeInterval
    public let failedImports: Int
}

public struct ErrorMetrics: Sendable {
    public let totalErrors: Int
    public let errorsByType: [String: Int]
    public let crashCount: Int
    public let crashReasons: [String]
}

public enum MemoryPressure: String, Sendable {
    case normal
    case warning
    case urgent
    case critical
}

// MARK: - Thresholds

public struct PerformanceThresholds: Sendable {
    public static let targetAudioLatency: TimeInterval = 0.05 // 50ms
    public static let targetAppLaunchTime: TimeInterval = 2.0 // 2 seconds
    public static let targetSearchLatency: TimeInterval = 0.15 // 150ms
    public static let targetMemoryUsage: Int64 = 200 * 1024 * 1024 // 200MB
    public static let acceptableCrashRate: Double = 0.001 // 0.1%
}

// MARK: - Implementation

/// Monitors and tracks performance metrics for the audio player
public actor PerformanceMonitor: PerformanceMonitoring {
    // MARK: - Properties

    private let logger = Log.logger(.diagnosticsPerformance)

    // Audio metrics storage
    private var audioLatencies: [TimeInterval] = []
    private var bufferUnderruns: Int = 0
    private var formatSwitches: [(from: AudioFormat, to: AudioFormat, duration: TimeInterval)] = []

    // Memory metrics storage
    private var memoryUsages: [Int64] = []
    private var memoryWarnings: Int = 0
    private var memoryPressureEvents: [MemoryPressure] = []

    // Performance metrics storage
    private var appLaunchTime: TimeInterval?
    private var searchLatencies: [(duration: TimeInterval, resultCount: Int)] = []
    private var importMetrics: [ImportMetrics] = []

    // Error metrics storage
    private var errors: [(error: Error, context: String, timestamp: Date)] = []
    private var crashes: [(reason: String, timestamp: Date)] = []

    // Tracking period
    private let startTime: Date

    // MARK: - Initialization

    public init() {
        startTime = Date()
        self.logger.info("Performance monitor initialized")
    }

    // MARK: - Audio Metrics

    public func recordAudioLatency(_ latency: TimeInterval) async {
        self.audioLatencies.append(latency)

        if latency > PerformanceThresholds.targetAudioLatency {
            self.logger.warning("Audio latency exceeded target: \(latency)s > \(PerformanceThresholds.targetAudioLatency)s")
        }
    }

    public func recordBufferUnderrun() async {
        self.bufferUnderruns += 1
        self.logger.warning("Buffer underrun detected. Total: \(self.bufferUnderruns)")
    }

    public func recordFormatSwitch(from: AudioFormat, to: AudioFormat, duration: TimeInterval) async {
        self.formatSwitches.append((from: from, to: to, duration: duration))
        self.logger.info("Format switch: \(from.rawValue) -> \(to.rawValue) in \(duration)s")
    }

    // MARK: - Memory Metrics

    public func recordMemoryUsage(_ bytes: Int64) async {
        self.memoryUsages.append(bytes)

        if bytes > PerformanceThresholds.targetMemoryUsage {
            self.logger.warning("Memory usage exceeded target: \(bytes / 1024 / 1024)MB > \(PerformanceThresholds.targetMemoryUsage / 1024 / 1024)MB")
        }
    }

    public func recordMemoryWarning() async {
        self.memoryWarnings += 1
        self.memoryPressureEvents.append(.warning)
        self.logger.warning("Memory warning received. Total: \(self.memoryWarnings)")
    }

    public func checkMemoryPressure() async -> MemoryPressure {
        // Get current memory usage
        let info = ProcessInfo.processInfo
        let physicalMemory = info.physicalMemory

        // This is a simplified check - in production, use more sophisticated methods
        if let lastUsage = self.memoryUsages.last {
            let usageRatio = Double(lastUsage) / Double(physicalMemory)

            switch usageRatio {
            case 0 ..< 0.5:
                return .normal
            case 0.5 ..< 0.7:
                return .warning
            case 0.7 ..< 0.9:
                return .urgent
            default:
                return .critical
            }
        }

        return .normal
    }

    // MARK: - Performance Metrics

    public func recordAppLaunchTime(_ duration: TimeInterval) async {
        self.appLaunchTime = duration

        if duration > PerformanceThresholds.targetAppLaunchTime {
            self.logger.warning("App launch time exceeded target: \(duration)s > \(PerformanceThresholds.targetAppLaunchTime)s")
        } else {
            self.logger.info("App launched in \(duration)s")
        }
    }

    public func recordSearchLatency(_ duration: TimeInterval, resultCount: Int) async {
        self.searchLatencies.append((duration: duration, resultCount: resultCount))

        if duration > PerformanceThresholds.targetSearchLatency {
            self.logger.warning("Search latency exceeded target: \(duration)s > \(PerformanceThresholds.targetSearchLatency)s")
        }
    }

    public func recordImportPerformance(_ metrics: ImportMetrics) async {
        self.importMetrics.append(metrics)
        self.logger.info("Import completed: \(metrics.successfulImports)/\(metrics.totalFiles) files in \(metrics.totalImportTime)s")
    }

    // MARK: - Error Tracking

    public func recordError(_ error: Error, context: String) async {
        self.errors.append((error: error, context: context, timestamp: Date()))
        self.logger.error("Error in \(context): \(error.localizedDescription)")
    }

    public func recordCrash(_ reason: String) async {
        self.crashes.append((reason: reason, timestamp: Date()))
        self.logger.critical("Crash recorded: \(reason)")
    }

    // MARK: - Reporting

    public func generateReport() async -> PerformanceReport {
        let period = DateInterval(start: self.startTime, end: Date())

        // Calculate audio metrics
        let audioMetrics = AudioPerformanceMetrics(
            averageLatency: self.audioLatencies.isEmpty ? 0 : self.audioLatencies.reduce(0, +) / Double(self.audioLatencies.count),
            maxLatency: self.audioLatencies.max() ?? 0,
            bufferUnderrunCount: self.bufferUnderruns,
            formatSwitchCount: self.formatSwitches.count,
            averageFormatSwitchTime: self.formatSwitches.isEmpty ? 0 : self.formatSwitches.map(\.duration).reduce(0, +) / Double(self.formatSwitches.count),
        )

        // Calculate memory metrics
        let memoryMetrics = MemoryMetrics(
            averageUsage: self.memoryUsages.isEmpty ? 0 : self.memoryUsages.reduce(Int64(0), +) / Int64(self.memoryUsages.count),
            peakUsage: self.memoryUsages.max() ?? 0,
            warningCount: self.memoryWarnings,
            pressureEvents: self.memoryPressureEvents,
        )

        // Calculate performance metrics
        let searchLatencyValues = self.searchLatencies.map(\.duration).sorted()
        let p95Index = Int(Double(searchLatencyValues.count) * 0.95)

        let performanceMetrics = AppPerformanceMetrics(
            appLaunchTime: self.appLaunchTime,
            averageSearchLatency: self.searchLatencies.isEmpty ? 0 : self.searchLatencies.map(\.duration).reduce(0, +) / Double(self.searchLatencies.count),
            p95SearchLatency: searchLatencyValues.isEmpty ? 0 : searchLatencyValues[min(p95Index, searchLatencyValues.count - 1)],
            totalImports: self.importMetrics.count,
            averageImportTime: self.importMetrics.isEmpty ? 0 : self.importMetrics.map(\.totalImportTime).reduce(0, +) / Double(self.importMetrics.count),
            failedImports: self.importMetrics.map(\.failedImports).reduce(0, +),
        )

        // Calculate error metrics
        var errorsByType: [String: Int] = [:]
        for (error, _, _) in self.errors {
            let typeName = String(describing: type(of: error))
            errorsByType[typeName, default: 0] += 1
        }

        let errorMetrics = ErrorMetrics(
            totalErrors: self.errors.count,
            errorsByType: errorsByType,
            crashCount: self.crashes.count,
            crashReasons: self.crashes.map(\.reason),
        )

        return PerformanceReport(
            period: period,
            audioMetrics: audioMetrics,
            memoryMetrics: memoryMetrics,
            performanceMetrics: performanceMetrics,
            errorMetrics: errorMetrics,
        )
    }

    public func reset() async {
        self.logger.info("Resetting performance metrics")

        // Clear all metrics
        self.audioLatencies.removeAll()
        self.bufferUnderruns = 0
        self.formatSwitches.removeAll()

        self.memoryUsages.removeAll()
        self.memoryWarnings = 0
        self.memoryPressureEvents.removeAll()

        self.appLaunchTime = nil
        self.searchLatencies.removeAll()
        self.importMetrics.removeAll()

        self.errors.removeAll()
        self.crashes.removeAll()
    }

}
