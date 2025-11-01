import Foundation
@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioMonitorTests: XCTestCase {
    func testStartMonitoringDelegatesToRuntimeAndEngineHooks() async throws {
        let runtime = StubRuntime()
        let hooks = StubEngineHooks()
        let builder = StubDiagnosticsBuilder(result: Self.sampleDiagnostics)
        let monitor = makeMonitor(
            runtime: runtime,
            hooks: hooks,
            builder: builder,
            alertManager: StubAlertManager()
        )

        await monitor.startMonitoring(updateInterval: 0.5)

        XCTAssertEqual(runtime.startMonitoringCalls.count, 1)
        let startCall = try XCTUnwrap(runtime.startMonitoringCalls.first)
        XCTAssertEqual(startCall.interval, 0.5, accuracy: 0.0001)
        XCTAssertNil(startCall.engine)
        XCTAssertEqual(hooks.startMonitoringIntervals, [0.5])
    }

    func testAttachAndDetachEnginePropagatesToCollaborators() async {
        let runtime = StubRuntime()
        let hooks = StubEngineHooks()
        let builder = StubDiagnosticsBuilder(result: Self.sampleDiagnostics)
        let alertManager = StubAlertManager()
        let monitor = makeMonitor(runtime: runtime, hooks: hooks, builder: builder, alertManager: alertManager)

        let engine = StubEngineService()
        await monitor.attachToEngine(engine)
        await monitor.detachFromEngine()

        XCTAssertEqual(runtime.updateEngineValues.count, 2)
        XCTAssertTrue(runtime.updateEngineValues[0] is StubEngineService)
        XCTAssertNil(runtime.updateEngineValues[1])
        XCTAssertEqual(hooks.setEngineValues.count, 2)
        XCTAssertTrue(hooks.setEngineValues[0] is StubEngineService)
        XCTAssertNil(hooks.setEngineValues[1])
    }

    func testPerformDiagnosticsUsesDiagnosticsBuilder() async throws {
        let runtime = StubRuntime()
        runtime.collectMetricsReturnValue = AudioMetrics(
            cpuUsage: 42,
            memoryUsage: 128_000_000,
            bufferUnderruns: 1,
            decodingLatency: 0.02,
            bufferFillLevel: 0.75,
            droppedFrames: 0,
            renderLatency: 0.015
        )
        runtime.isMonitoring = true

        let hooks = StubEngineHooks()
        let builderResult = Self.sampleDiagnostics
        let builder = StubDiagnosticsBuilder(result: builderResult)
        let alert = PlaybackAlert(
            type: .bufferUnderrun,
            severity: .medium,
            message: "Test Alert",
            technicalDetails: "",
            timestamp: Date(),
            triggerValues: [:],
            suggestedActions: []
        )
        let alertManager = StubAlertManager(alerts: [alert])
        let monitor = makeMonitor(runtime: runtime, hooks: hooks, builder: builder, alertManager: alertManager)

        let result = await monitor.performDiagnosticsCheck()

        XCTAssertEqual(result.sessionDuration, builderResult.sessionDuration)
        XCTAssertEqual(builder.invocations.count, 1)

        let invocation = try XCTUnwrap(builder.invocations.first)
        XCTAssertEqual(invocation.currentMetrics, runtime.collectMetricsReturnValue)
        XCTAssertEqual(invocation.alertHistory, alertManager.alertHistory)
        XCTAssertEqual(invocation.runtimeSnapshot.isMonitoring, true)
        let expectedHealth: DiagnosticHealthStatus = {
            switch runtime.collectMetricsReturnValue.healthStatus {
            case .excellent: .excellent
            case .good: .good
            case .fair: .fair
            case .poor: .poor
            case .critical: .critical
            }
        }()
        XCTAssertEqual(invocation.systemHealth, expectedHealth)
    }

    // MARK: - Helpers

    private func makeMonitor(
        runtime: StubRuntime,
        hooks: StubEngineHooks,
        builder: StubDiagnosticsBuilder,
        alertManager: StubAlertManager
    ) -> AudioMonitor {
        AudioMonitor(
            alertManager: alertManager,
            runtimeController: runtime,
            engineHookController: hooks,
            diagnosticsBuilderOverride: builder
        )
    }

    private static let sampleDiagnostics: PlaybackDiagnostics = {
        let trend = TrendIndicator(currentValue: 0, changePercent: 0, direction: .stable, stability: .stable)
        return PlaybackDiagnostics(
            sessionDuration: 0,
            systemHealth: .good,
            currentMetrics: .empty,
            engineInfo: AudioEngineInfo(
                type: "stub",
                version: "1.0",
                capabilities: [],
                configuration: [:],
                performanceProfile: "stub",
                lastInitialized: Date()
            ),
            sessionInfo: AudioSessionInfo(
                category: "playback",
                mode: "default",
                options: [],
                sampleRate: 44_100,
                ioBufferDuration: 0.01,
                isActive: true,
                isOtherAudioPlaying: false
            ),
            deviceInfo: AudioDeviceInfo(
                deviceID: "stub",
                name: "Stub Device",
                sampleRate: 44_100,
                bitDepth: 16,
                channels: 2,
                bufferSize: 512,
                latency: 0.01
            ),
            performanceTrends: PerformanceTrendSummary(
                cpuTrend: trend,
                memoryTrend: trend,
                latencyTrend: trend,
                qualityTrend: trend,
                bufferTrend: trend,
                overallTrend: .stable
            ),
            resourceUtilization: ResourceUtilizationSummary(
                cpuUtilization: ResourceUsageAnalysis(
                    currentUsage: 0,
                    averageUsage: 0,
                    peakUsage: 0,
                    efficiencyScore: 1,
                    classification: .minimal
                ),
                memoryUtilization: ResourceUsageAnalysis(
                    currentUsage: 0,
                    averageUsage: 0,
                    peakUsage: 0,
                    efficiencyScore: 1,
                    classification: .minimal
                ),
                batteryUtilization: ResourceUsageAnalysis(
                    currentUsage: 0,
                    averageUsage: 0,
                    peakUsage: 0,
                    efficiencyScore: 1,
                    classification: .minimal
                ),
                networkUtilization: ResourceUsageAnalysis(
                    currentUsage: 0,
                    averageUsage: 0,
                    peakUsage: 0,
                    efficiencyScore: 1,
                    classification: .minimal
                ),
                overallEfficiency: .good
            ),
            qualityAssessment: QualityAssessmentSummary(
                qualityScore: 100,
                bitPerfectStatus: .active,
                signalIntegrity: SignalIntegrityAssessment(
                    integrityScore: 100,
                    issues: [],
                    pathAnalysis: "stable",
                    jitterLevel: .minimal
                ),
                qualityIssues: [],
                improvements: []
            ),
            efficiencyAnalysis: EfficiencyAnalysisSummary(
                efficiencyScore: 100,
                powerEfficiency: .excellent,
                performanceEfficiency: .excellent,
                optimizationOpportunities: []
            ),
            activeIssues: [],
            recentAlerts: [],
            recommendations: [],
            optimizations: [],
            sessionStatistics: SessionStatisticsSummary(
                totalUptime: 0,
                averagePerformanceScore: 1,
                totalAlerts: 0,
                errorRate: 0,
                bufferUnderrunIncidents: 0,
                qualityDropCount: 0,
                recoverySuccessRate: 1
            ),
            errorHistory: ErrorHistorySummary(
                totalErrors: 0,
                errorsByCategory: [:],
                mostRecentError: nil,
                mostCommonErrorType: nil,
                errorFrequencyTrend: .stable
            ),
            milestones: [],
            osCompatibility: OSCompatibilityInfo(
                iosVersion: "26.0",
                deviceModel: "Test",
                compatibilityStatus: .excellent,
                knownIssues: [],
                recommendedSettings: []
            ),
            hardwareCompatibility: HardwareCompatibilityInfo(
                deviceCapabilities: DeviceCapabilityAssessment(
                    capabilityScore: 100,
                    cpuRating: .excellent,
                    memoryRating: .excellent,
                    audioProcessingCapability: .professional
                ),
                audioHardware: AudioHardwareInfo(
                    builtInAudio: BuiltInAudioInfo(
                        dacQuality: .excellent,
                        maxSampleRate: 44_100,
                        maxBitDepth: 16,
                        snr: nil
                    ),
                    externalDevices: [],
                    supportedFormats: []
                ),
                performanceLimitations: [],
                upgradeRecommendations: []
            ),
            formatSupport: FormatSupportMatrix(
                supportedFormats: [],
                compatibilityScore: 100,
                recommendations: []
            ),
            debugInfo: DebugInformation(
                sessionID: "stub",
                systemInfo: SystemDebugInfo(
                    deviceIdentifier: "stub",
                    systemVersion: "iOS",
                    availableMemory: 0,
                    cpuArchitecture: "arm64",
                    thermalState: "nominal"
                ),
                audioStackInfo: AudioStackDebugInfo(
                    activeAudioUnits: [],
                    sessionDetails: [:],
                    engineConfiguration: [:],
                    bufferInfo: BufferDebugInfo(
                        bufferSizes: [:],
                        bufferUtilization: [:],
                        allocationHistory: []
                    )
                ),
                performanceCounters: [:],
                debugFlags: [:]
            ),
            logEntries: [],
            configurationDump: ConfigurationDump(
                engineConfig: [:],
                sessionConfig: [:],
                deviceConfig: [:],
                userPreferences: [:],
                systemSettings: [:]
            )
        )
    }()
}

// MARK: - Stubs

@MainActor
private final class StubRuntime: AudioMonitorRuntimeControlling {
    struct StartCall {
        let interval: TimeInterval
        let engine: AudioEngineService?
    }

    private(set) var startMonitoringCalls: [StartCall] = []
    private(set) var stopMonitoringCallCount = 0
    private(set) var updateIntervalCalls: [TimeInterval] = []
    private(set) var evaluateAlertsCallCount = 0
    private(set) var startProfilingDurations: [TimeInterval?] = []
    private(set) var stopProfilingCallCount = 0
    private(set) var updateEngineValues: [AudioEngineService?] = []
    private(set) var invalidateCallCount = 0

    var updateInterval: TimeInterval = 1.0
    var isMonitoring = false
    var isProfiling = false
    var collectMetricsReturnValue: AudioMetrics = .empty

    func startMonitoring(updateInterval: TimeInterval, engine: AudioEngineService?) async {
        self.updateInterval = updateInterval
        isMonitoring = true
        startMonitoringCalls.append(StartCall(interval: updateInterval, engine: engine))
    }

    func stopMonitoring() async {
        isMonitoring = false
        stopMonitoringCallCount += 1
    }

    func updateMonitoringInterval(to interval: TimeInterval) {
        updateInterval = interval
        updateIntervalCalls.append(interval)
    }

    func collectCurrentMetrics() async -> AudioMetrics {
        collectMetricsReturnValue
    }

    func evaluateAlerts() async {
        evaluateAlertsCallCount += 1
    }

    func startProfiling(duration: TimeInterval?) async {
        isProfiling = true
        startProfilingDurations.append(duration)
    }

    func stopProfiling() async {
        isProfiling = false
        stopProfilingCallCount += 1
    }

    func updateEngine(_ engine: AudioEngineService?) {
        updateEngineValues.append(engine)
    }

    func invalidate() {
        invalidateCallCount += 1
    }
}

@MainActor
private final class StubEngineHooks: AudioMonitorEngineHooking {
    private(set) var setEngineValues: [AudioEngineService?] = []
    private(set) var startMonitoringIntervals: [TimeInterval] = []
    private(set) var stopMonitoringCallCount = 0
    private(set) var updatedIntervals: [TimeInterval] = []

    func setEngine(_ engine: AudioEngineService?) {
        setEngineValues.append(engine)
    }

    func startMonitoring(interval: TimeInterval) {
        startMonitoringIntervals.append(interval)
    }

    func stopMonitoring() {
        stopMonitoringCallCount += 1
    }

    func updateMonitoringInterval(to interval: TimeInterval) {
        updatedIntervals.append(interval)
    }
}

@MainActor
private final class StubDiagnosticsBuilder: AudioMonitorDiagnosticsBuilding {
    struct Invocation {
        let currentMetrics: AudioMetrics
        let latestMetric: AudioMetrics?
        let sessionSummary: AudioSessionSummary
        let alertHistory: [PlaybackAlert]
        let runtimeSnapshot: AudioMonitorDiagnosticsBuilder.RuntimeSnapshot
        let engine: AudioEngineService?
        let metricsSampleCount: Int
        let systemHealth: DiagnosticHealthStatus
    }

    private let result: PlaybackDiagnostics
    private(set) var invocations: [Invocation] = []

    init(result: PlaybackDiagnostics) {
        self.result = result
    }

    func makeDiagnostics(
        currentMetrics: AudioMetrics,
        latestMetric: AudioMetrics?,
        sessionSummary: AudioSessionSummary,
        alertHistory: [PlaybackAlert],
        runtime: AudioMonitorDiagnosticsBuilder.RuntimeSnapshot,
        engine: AudioEngineService?,
        metricsSampleCount: Int,
        systemHealth: DiagnosticHealthStatus
    ) async -> PlaybackDiagnostics {
        invocations.append(
            Invocation(
                currentMetrics: currentMetrics,
                latestMetric: latestMetric,
                sessionSummary: sessionSummary,
                alertHistory: alertHistory,
                runtimeSnapshot: runtime,
                engine: engine,
                metricsSampleCount: metricsSampleCount,
                systemHealth: systemHealth
            )
        )
        return result
    }
}

@MainActor
private final class StubAlertManager: AudioAlertManaging {
    var alertConfiguration: AlertConfiguration
    var alertHistory: [PlaybackAlert]

    init(alerts: [PlaybackAlert] = [], configuration: AlertConfiguration = .default) {
        self.alertHistory = alerts
        self.alertConfiguration = configuration
    }

    func updateConfiguration(_ configuration: AlertConfiguration) {
        alertConfiguration = configuration
    }

    func evaluateAlerts(for metrics: AudioMetrics) -> [PlaybackAlert] {
        []
    }

    func recordInterruptionAlert(_ alert: PlaybackAlert) {
        alertHistory.append(alert)
    }

    func reset() {
        alertHistory.removeAll()
    }
}

extension StubAlertManager: @unchecked Sendable {}

@MainActor
private final class StubEngineService: AudioEngineService {
    var currentTime: TimeInterval { get async { 0 } }
    var duration: TimeInterval { get async { 0 } }
    var isPlaying: Bool { get async { false } }
    var volume: Float { get async { 1.0 } }
    var audioFormat: AudioFormat? { get async { nil } }
    var isBitPerfect: Bool { get async { true } }

    func load(url _: URL) async throws {}
    func play() async throws {}
    func pause() async {}
    func stop() async {}
    func seek(to _: TimeInterval) async throws {}
    func setVolume(_: Float) async {}
    func setPlaybackRate(_: Double) async {}
    func applyReplayGain(_: Float) async {}
    func configure(with _: AudioEngineConfiguration) async throws {}
    func prepareNext(url _: URL) async {}
    func crossfade(to _: URL, duration _: TimeInterval, playbackRate _: Double, gainDB _: Float) async throws {}
    func getMetrics() async -> AudioMetrics { .empty }
    func collectMetrics() async {}
}
