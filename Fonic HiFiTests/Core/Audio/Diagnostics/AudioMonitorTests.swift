//
//  AudioMonitorTests.swift
//  Fonic HiFiTests
//
//  Created by Claude on 5/27/25.
//

import XCTest
import Combine
@testable import Fonic_HiFi

/// Comprehensive unit tests for AudioMonitor class
@MainActor
final class AudioMonitorTests: XCTestCase {
    
    // MARK: - Properties
    
    private var audioMonitor: AudioMonitor!
    private var mockEngine: MockAudioEngine!
    private var cancellables: Set<AnyCancellable>!
    
    // MARK: - Setup & Teardown
    
    override func setUp() {
        super.setUp()
        audioMonitor = AudioMonitor()
        mockEngine = MockAudioEngine()
        cancellables = Set<AnyCancellable>()
    }
    
    override func tearDown() {
        cancellables.removeAll()
        Task {
            await audioMonitor.stopMonitoring()
        }
        audioMonitor = nil
        mockEngine = nil
        super.tearDown()
    }
    
    // MARK: - Monitoring Control Tests
    
    func testStartMonitoring() async {
        // Given
        let expectation = XCTestExpectation(description: "Monitoring started")
        
        // When
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        // Wait briefly for monitoring to start
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            expectation.fulfill()
        }
        
        await fulfillment(of: [expectation], timeout: 1.0)
        
        // Then
        let isMonitoring = await audioMonitor.isMonitoring
        XCTAssertTrue(isMonitoring, "Monitoring should be active")
    }
    
    func testStopMonitoring() async {
        // Given
        await audioMonitor.startMonitoring()
        
        // When
        await audioMonitor.stopMonitoring()
        
        // Then
        let isMonitoring = await audioMonitor.isMonitoring
        XCTAssertFalse(isMonitoring, "Monitoring should be stopped")
    }
    
    func testUpdateMonitoringInterval() async {
        // Given
        await audioMonitor.startMonitoring(updateInterval: 1.0)
        
        // When
        await audioMonitor.updateMonitoringInterval(0.5)
        
        // Then
        let isMonitoring = await audioMonitor.isMonitoring
        XCTAssertTrue(isMonitoring, "Monitoring should still be active after interval update")
    }
    
    // MARK: - Metrics Collection Tests
    
    func testGetCurrentMetrics() async {
        // When
        let metrics = await audioMonitor.getCurrentMetrics()
        
        // Then
        XCTAssertNotNil(metrics, "Should return current metrics")
        XCTAssertGreaterThanOrEqual(metrics.timestamp.timeIntervalSinceNow, -1.0, "Metrics should have recent timestamp")
    }
    
    func testMetricsPublisher() async {
        // Given
        let expectation = XCTestExpectation(description: "Metrics published")
        var receivedMetrics: AudioMetrics?
        
        audioMonitor.metricsPublisher
            .sink { metrics in
                receivedMetrics = metrics
                expectation.fulfill()
            }
            .store(in: &cancellables)
        
        // When
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then
        XCTAssertNotNil(receivedMetrics, "Should receive metrics from publisher")
    }
    
    func testHistoricalMetrics() async {
        // Given
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        // Wait for some metrics to be collected
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms
        
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-1.0)
        
        // When
        let historicalMetrics = await audioMonitor.getHistoricalMetrics(from: startTime, to: endTime)
        
        // Then
        XCTAssertGreaterThan(historicalMetrics.count, 0, "Should have collected historical metrics")
    }
    
    // MARK: - Engine Integration Tests
    
    func testAttachToEngine() async {
        // When
        await audioMonitor.attachToEngine(mockEngine)
        
        // Then
        let currentEngine = await audioMonitor.currentEngine
        XCTAssertNotNil(currentEngine, "Should have attached engine")
    }
    
    func testDetachFromEngine() async {
        // Given
        await audioMonitor.attachToEngine(mockEngine)
        
        // When
        await audioMonitor.detachFromEngine()
        
        // Then
        let currentEngine = await audioMonitor.currentEngine
        XCTAssertNil(currentEngine, "Should have detached engine")
    }
    
    // MARK: - Alert Configuration Tests
    
    func testConfigureAlerts() async {
        // Given
        let configuration = AlertConfiguration(
            cpuThreshold: 80.0,
            memoryThreshold: 100_000_000,
            bufferFillThreshold: 0.2,
            latencyThreshold: 0.1,
            maxBufferUnderruns: 5,
            enableThermalMonitoring: true,
            alertCooldownSeconds: 30.0
        )
        
        // When
        await audioMonitor.configureAlerts(configuration)
        
        // Then
        let retrievedConfig = await audioMonitor.getAlertConfiguration()
        XCTAssertEqual(retrievedConfig.cpuThreshold, 80.0, "CPU threshold should be set")
        XCTAssertEqual(retrievedConfig.memoryThreshold, 100_000_000, "Memory threshold should be set")
    }
    
    // MARK: - Performance Profiling Tests
    
    func testStartProfiling() async {
        // When
        await audioMonitor.startProfiling()
        
        // Then
        let isProfiling = await audioMonitor.isProfiling
        XCTAssertTrue(isProfiling, "Profiling should be active")
    }
    
    func testStopProfiling() async {
        // Given
        await audioMonitor.startProfiling()
        
        // When
        await audioMonitor.stopProfiling()
        
        // Then
        let isProfiling = await audioMonitor.isProfiling
        XCTAssertFalse(isProfiling, "Profiling should be stopped")
    }
    
    func testProfilingWithDuration() async {
        // When
        await audioMonitor.startProfiling(duration: 0.2)
        
        // Wait for profiling to stop automatically
        try? await Task.sleep(nanoseconds: 300_000_000)
        
        // Then
        let isProfiling = await audioMonitor.isProfiling
        XCTAssertFalse(isProfiling, "Profiling should stop automatically after duration")
    }
    
    func testGetProfilingResults() async {
        // Given
        await audioMonitor.startProfiling()
        
        // Wait briefly to collect some data
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        await audioMonitor.stopProfiling()
        
        // When
        let results = await audioMonitor.getProfilingResults()
        
        // Then
        XCTAssertNotNil(results, "Should return profiling results")
        XCTAssertGreaterThan(results?.duration ?? 0, 0, "Results should have duration")
    }
    
    // MARK: - Session Management Tests
    
    func testSessionSummary() async {
        // Given
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        // Wait for session to accumulate some data
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let summary = await audioMonitor.getSessionSummary()
        
        // Then
        XCTAssertGreaterThan(summary.duration, 0, "Session should have duration")
        XCTAssertGreaterThan(summary.sampleCount, 0, "Session should have collected samples")
    }
    
    func testClearHistory() async {
        // Given
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        // Wait for some metrics to be collected
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        await audioMonitor.clearHistory()
        
        // Then
        let summary = await audioMonitor.getSessionSummary()
        XCTAssertEqual(summary.sampleCount, 0, "History should be cleared")
    }
    
    // MARK: - Diagnostics Tests
    
    func testPerformDiagnosticsCheck() async {
        // Given
        await audioMonitor.startMonitoring()
        
        // When
        let diagnostics = await audioMonitor.performDiagnosticsCheck()
        
        // Then
        XCTAssertNotNil(diagnostics, "Should return diagnostics")
        XCTAssertNotNil(diagnostics.currentMetrics, "Diagnostics should include current metrics")
        XCTAssertNotNil(diagnostics.engineInfo, "Diagnostics should include engine info")
    }
    
    func testCheckPlaybackHealth() async {
        // When
        let healthStatus = await audioMonitor.checkPlaybackHealth()
        
        // Then
        XCTAssertNotNil(healthStatus, "Should return health status")
    }
    
    // MARK: - Mock Alert Scenarios
    
    func testHighCPUAlert() async {
        // Given
        let expectation = XCTestExpectation(description: "High CPU alert")
        
        audioMonitor.alertsPublisher
            .sink { alert in
                if alert.type == .highCPUUsage {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Configure low threshold for testing
        let config = AlertConfiguration(
            cpuThreshold: 20.0, // Low threshold to trigger alert
            memoryThreshold: 1_000_000_000,
            bufferFillThreshold: 0.1,
            latencyThreshold: 1.0,
            maxBufferUnderruns: 100,
            enableThermalMonitoring: false,
            alertCooldownSeconds: 0.1
        )
        await audioMonitor.configureAlerts(config)
        
        // When
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then - expectation fulfilled means alert was triggered
    }
    
    func testBufferUnderrunAlert() async {
        // Given
        let expectation = XCTestExpectation(description: "Buffer underrun alert")
        
        audioMonitor.alertsPublisher
            .sink { alert in
                if alert.type == .bufferUnderrun {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Configure to trigger buffer underrun alerts
        mockEngine.simulateBufferUnderruns = true
        await audioMonitor.attachToEngine(mockEngine)
        
        let config = AlertConfiguration(
            cpuThreshold: 100.0,
            memoryThreshold: 1_000_000_000,
            bufferFillThreshold: 1.0,
            latencyThreshold: 1.0,
            maxBufferUnderruns: 0, // Any underruns trigger alert
            enableThermalMonitoring: false,
            alertCooldownSeconds: 0.1
        )
        await audioMonitor.configureAlerts(config)
        
        // When
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then - expectation fulfilled means alert was triggered
    }
    
    func testLowBufferFillAlert() async {
        // Given
        let expectation = XCTestExpectation(description: "Low buffer fill alert")
        
        audioMonitor.alertsPublisher
            .sink { alert in
                if alert.type == .lowBufferFill {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        // Configure to simulate low buffer fill
        mockEngine.simulateLowBufferFill = true
        await audioMonitor.attachToEngine(mockEngine)
        
        let config = AlertConfiguration(
            cpuThreshold: 100.0,
            memoryThreshold: 1_000_000_000,
            bufferFillThreshold: 0.8, // High threshold to trigger alert
            latencyThreshold: 1.0,
            maxBufferUnderruns: 100,
            enableThermalMonitoring: false,
            alertCooldownSeconds: 0.1
        )
        await audioMonitor.configureAlerts(config)
        
        // When
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Then - expectation fulfilled means alert was triggered
    }
    
    // MARK: - Performance Simulation Tests
    
    func testHighCPUCondition() async {
        // Given
        mockEngine.simulateHighCPU = true
        await audioMonitor.attachToEngine(mockEngine)
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        // Wait for metrics to be collected
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let metrics = await audioMonitor.getCurrentMetrics()
        
        // Then
        XCTAssertGreaterThan(metrics.cpuUsage, 80, "Should simulate high CPU usage")
    }
    
    func testBufferUnderrunCondition() async {
        // Given
        mockEngine.simulateBufferUnderruns = true
        await audioMonitor.attachToEngine(mockEngine)
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        // Wait for metrics to be collected
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let metrics = await audioMonitor.getCurrentMetrics()
        
        // Then
        XCTAssertGreaterThan(metrics.bufferUnderruns, 0, "Should simulate buffer underruns")
    }
    
    func testHighMemoryCondition() async {
        // Given
        mockEngine.simulateHighMemory = true
        await audioMonitor.attachToEngine(mockEngine)
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        // Wait for metrics to be collected
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let metrics = await audioMonitor.getCurrentMetrics()
        
        // Then
        XCTAssertGreaterThan(metrics.memoryUsage, 100_000_000, "Should simulate high memory usage")
    }
    
    func testLatencySpikes() async {
        // Given
        mockEngine.simulateLatencySpikes = true
        await audioMonitor.attachToEngine(mockEngine)
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        // Wait for metrics to be collected
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let metrics = await audioMonitor.getCurrentMetrics()
        
        // Then
        XCTAssertGreaterThan(metrics.renderLatency, 0.05, "Should simulate latency spikes")
    }
    
    // MARK: - Export and Reporting Tests
    
    func testExportMetricsJSON() async {
        // Given
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        // Wait for some metrics to be collected
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        // When
        let exportData = await audioMonitor.exportMetrics(format: .json)
        
        // Then
        XCTAssertGreaterThan(exportData.count, 0, "Should export data")
    }
    
    func testGenerateReport() async {
        // Given
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        // Wait for some metrics to be collected
        try? await Task.sleep(nanoseconds: 200_000_000)
        
        let endTime = Date()
        let startTime = endTime.addingTimeInterval(-1.0)
        let timeRange = DateInterval(start: startTime, end: endTime)
        
        // When
        let report = await audioMonitor.generateReport(for: timeRange)
        
        // Then
        XCTAssertNotNil(report, "Should generate report")
        XCTAssertEqual(report.timeRange, timeRange, "Report should have correct time range")
    }
    
    // MARK: - Edge Cases and Error Handling
    
    func testMultipleStartStopCycles() async {
        // Test multiple start/stop cycles
        for _ in 0..<3 {
            await audioMonitor.startMonitoring(updateInterval: 0.1)
            try? await Task.sleep(nanoseconds: 100_000_000)
            await audioMonitor.stopMonitoring()
            try? await Task.sleep(nanoseconds: 50_000_000)
        }
        
        let isMonitoring = await audioMonitor.isMonitoring
        XCTAssertFalse(isMonitoring, "Should handle multiple start/stop cycles")
    }
    
    func testMemoryManagement() async {
        // Start monitoring with rapid updates
        await audioMonitor.startMonitoring(updateInterval: 0.01)
        
        // Let it run for a bit to generate many metrics
        try? await Task.sleep(nanoseconds: 500_000_000)
        
        // Stop monitoring
        await audioMonitor.stopMonitoring()
        
        // Verify memory cleanup (metrics history should be limited)
        let summary = await audioMonitor.getSessionSummary()
        XCTAssertLessThanOrEqual(summary.sampleCount, 1000, "Should limit metrics history size")
    }
    
    func testConcurrentOperations() async {
        // Test concurrent monitoring operations
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                await self.audioMonitor.startMonitoring(updateInterval: 0.1)
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: 50_000_000)
                _ = await self.audioMonitor.getCurrentMetrics()
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: 100_000_000)
                await self.audioMonitor.evaluateAlerts()
            }
            
            group.addTask {
                try? await Task.sleep(nanoseconds: 150_000_000)
                _ = await self.audioMonitor.getSessionSummary()
            }
        }
        
        // Should complete without crashes
        let isMonitoring = await audioMonitor.isMonitoring
        XCTAssertTrue(isMonitoring, "Should handle concurrent operations")
    }
    
    // MARK: - Performance Tests
    
    func testMonitoringPerformance() async {
        // Measure time for metrics collection
        let startTime = CFAbsoluteTimeGetCurrent()
        
        for _ in 0..<100 {
            _ = await audioMonitor.getCurrentMetrics()
        }
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        // Should complete 100 metrics collections in reasonable time
        XCTAssertLessThan(timeElapsed, 1.0, "Metrics collection should be performant")
    }
    
    func testHighFrequencyMonitoring() async {
        // Test monitoring at high frequency (10Hz)
        await audioMonitor.startMonitoring(updateInterval: 0.1)
        
        let expectation = XCTestExpectation(description: "High frequency monitoring")
        var metricsCount = 0
        
        audioMonitor.metricsPublisher
            .sink { _ in
                metricsCount += 1
                if metricsCount >= 5 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)
        
        await fulfillment(of: [expectation], timeout: 2.0)
        
        // Should handle high frequency updates
        XCTAssertGreaterThanOrEqual(metricsCount, 5, "Should handle high frequency monitoring")
    }
}

// MARK: - Mock Audio Engine

/// Mock audio engine for testing
private class MockAudioEngine: AudioEngineService {
    
    // MARK: - Simulation Flags
    
    var simulateHighCPU = false
    var simulateHighMemory = false
    var simulateBufferUnderruns = false
    var simulateLowBufferFill = false
    var simulateLatencySpikes = false
    var simulateGlitches = false
    
    // MARK: - AudioEngineService Implementation
    
    func collectMetrics() async -> EngineMetrics {
        return EngineMetrics(
            bufferUnderruns: simulateBufferUnderruns ? 5 : 0,
            decodingLatency: simulateLatencySpikes ? 0.08 : 0.01,
            bufferFillLevel: simulateLowBufferFill ? 0.3 : 0.85,
            droppedFrames: simulateGlitches ? 10 : 0,
            renderLatency: simulateLatencySpikes ? 0.1 : 0.023,
            currentBitrate: 1411200,
            glitchCount: simulateGlitches ? 3 : 0,
            sampleRate: 44100,
            bitDepth: 16,
            channelCount: 2,
            engineType: "MockEngine",
            audioFormat: "PCM",
            isBitPerfect: !simulateGlitches,
            bufferSize: 512,
            bufferResets: simulateBufferUnderruns ? 2 : 0,
            threadUtilization: ThreadUtilization(
                renderThreadUsage: simulateHighCPU ? 0.95 : 0.3,
                decodingThreadUsage: simulateHighCPU ? 0.8 : 0.2,
                ioThreadUsage: 0.1,
                overallThreadEfficiency: simulateHighCPU ? 0.6 : 0.9
            ),
            estimatedSNR: simulateGlitches ? 80 : 110,
            dynamicRange: simulateGlitches ? 85 : 96,
            frequencyResponseScore: simulateGlitches ? 0.7 : 0.95,
            jitter: simulateLatencySpikes ? 0.5 : 0.05,
            clockDrift: 0.01,
            recoverableErrors: simulateGlitches ? 2 : 0,
            criticalErrors: 0,
            recoverySuccessRate: 1.0,
            lastRecoveryTime: nil
        )
    }
    
    // Mock implementations for required protocol methods
    func initializeEngine() async throws {
        // Mock implementation
    }
    
    func shutdownEngine() async {
        // Mock implementation
    }
    
    func startPlayback() async throws {
        // Mock implementation
    }
    
    func stopPlayback() async {
        // Mock implementation
    }
    
    var isRunning: Bool {
        return true
    }
}

// MARK: - Helper Extensions

/// Helper struct for engine metrics (moved from main implementation)
private struct EngineMetrics {
    let bufferUnderruns: Int
    let decodingLatency: TimeInterval
    let bufferFillLevel: Float
    let droppedFrames: Int
    let renderLatency: TimeInterval
    let currentBitrate: Int64
    let glitchCount: Int
    let sampleRate: Double
    let bitDepth: Int
    let channelCount: Int
    let engineType: String
    let audioFormat: String
    let isBitPerfect: Bool
    let bufferSize: Int
    let bufferResets: Int
    let threadUtilization: ThreadUtilization
    let estimatedSNR: Float?
    let dynamicRange: Float?
    let frequencyResponseScore: Float?
    let jitter: Float
    let clockDrift: Float
    let recoverableErrors: Int
    let criticalErrors: Int
    let recoverySuccessRate: Float
    let lastRecoveryTime: TimeInterval?
}

/// Mock protocol for audio engine service
private protocol AudioEngineService {
    func collectMetrics() async -> EngineMetrics
    func initializeEngine() async throws
    func shutdownEngine() async
    func startPlayback() async throws
    func stopPlayback() async
    var isRunning: Bool { get }
} 