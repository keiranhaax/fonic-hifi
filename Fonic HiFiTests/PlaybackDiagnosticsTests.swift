@testable import Fonic_HiFi
import XCTest

final class PlaybackDiagnosticsTests: XCTestCase {
    func testSystemScoreAppliesIssuePenalty() {
        let issues = [
            PlaybackDiagnosticsFixtures.makeIssue(severity: .major, title: "Buffer Instability"),
            PlaybackDiagnosticsFixtures.makeIssue(severity: .critical, title: "Engine Failure"),
        ]

        let diagnostics = PlaybackDiagnosticsFixtures.makeDiagnostics(
            systemHealth: .good,
            metrics: PlaybackDiagnosticsFixtures.makeMetrics(performanceScore: 0.9),
            issues: issues,
        )

        XCTAssertEqual(diagnostics.systemScore, 65)
    }

    func testPriorityIssuesFiltersAndSortsBySeverity() {
        let issues = [
            PlaybackDiagnosticsFixtures.makeIssue(severity: .moderate, title: "Cache Warning"),
            PlaybackDiagnosticsFixtures.makeIssue(severity: .critical, title: "Dropout Spike"),
            PlaybackDiagnosticsFixtures.makeIssue(severity: .major, title: "Latency Drift"),
        ]

        let diagnostics = PlaybackDiagnosticsFixtures.makeDiagnostics(issues: issues)

        XCTAssertEqual(diagnostics.priorityIssues.map(\.severity), [.critical, .major])
        XCTAssertEqual(diagnostics.priorityIssues.first?.title, "Dropout Spike")
    }

    func testGenerateExecutiveSummaryIncludesHighlights() {
        let issues = [PlaybackDiagnosticsFixtures.makeIssue(severity: .critical, title: "Thermal Throttling")]
        let recommendations = [PlaybackDiagnosticsFixtures.makeRecommendation(priority: .high, title: "Increase Buffer Size")]

        let diagnostics = PlaybackDiagnosticsFixtures.makeDiagnostics(
            issues: issues,
            recommendations: recommendations,
        )

        let summary = diagnostics.generateExecutiveSummary()

        XCTAssertTrue(summary.contains("Priority Issues (1)"))
        XCTAssertTrue(summary.contains("• Thermal Throttling"))
        XCTAssertTrue(summary.contains("Key Recommendations:"))
        XCTAssertTrue(summary.contains("• Increase Buffer Size"))
    }

    func testExportForAnalysisIncludesMetricsAndRecommendations() {
        let recommendation = PlaybackDiagnosticsFixtures.makeRecommendation(priority: .critical, title: "Switch Engine")
        let diagnostics = PlaybackDiagnosticsFixtures.makeDiagnostics(
            systemHealth: .excellent,
            metrics: PlaybackDiagnosticsFixtures.makeMetrics(performanceScore: 0.92),
            recommendations: [recommendation],
        )

        let payload = diagnostics.exportForAnalysis()

        XCTAssertEqual(payload["systemHealth"] as? String, "excellent")
        XCTAssertEqual(payload["systemScore"] as? Int, diagnostics.systemScore)

        let metrics = payload["metrics"] as? [String: Any]
        let bufferUnderruns = (metrics?["bufferUnderruns"] as? NSNumber)?.intValue
        XCTAssertEqual(bufferUnderruns, diagnostics.currentMetrics.bufferUnderruns)

        let performanceScore = (metrics?["performanceScore"] as? NSNumber)?.floatValue
        XCTAssertNotNil(performanceScore)
        if let performanceScore {
            XCTAssertEqual(performanceScore, diagnostics.currentMetrics.performanceScore, accuracy: 0.0001)
        }

        let recommendations = payload["recommendations"] as? [[String: Any]]
        XCTAssertEqual(recommendations?.count, 1)
        XCTAssertEqual(recommendations?.first?["title"] as? String, "Switch Engine")
    }

    func testNeedsAttentionFlagsLowScores() {
        let diagnostics = PlaybackDiagnosticsFixtures.makeDiagnostics(
            systemHealth: .poor,
            metrics: PlaybackDiagnosticsFixtures.makeMetrics(performanceScore: 0.45),
        )

        XCTAssertTrue(diagnostics.needsAttention)
        XCTAssertEqual(diagnostics.dashboardStatus, .critical)
    }
}

private enum PlaybackDiagnosticsFixtures {
    static let timestamp = Date(timeIntervalSince1970: 1_000_000)

    static func makeDiagnostics(
        systemHealth: DiagnosticHealthStatus = .good,
        metrics: AudioMetrics = makeMetrics(performanceScore: 0.9),
        issues: [DiagnosticIssue] = [],
        recommendations: [PerformanceRecommendation] = [],
        alerts: [PlaybackAlert] = [defaultAlert],
        optimizations: [OptimizationOpportunity] = [defaultOptimization],
    ) -> PlaybackDiagnostics {
        PlaybackDiagnostics(
            timestamp: timestamp,
            sessionDuration: 3600,
            diagnosticsVersion: "1.0",
            systemHealth: systemHealth,
            currentMetrics: metrics,
            engineInfo: engineInfo,
            sessionInfo: sessionInfo,
            deviceInfo: deviceInfo,
            performanceTrends: performanceTrends,
            resourceUtilization: resourceUtilization,
            qualityAssessment: qualityAssessment,
            efficiencyAnalysis: efficiencyAnalysis,
            activeIssues: issues,
            recentAlerts: alerts,
            recommendations: recommendations,
            optimizations: optimizations,
            sessionStatistics: sessionStatistics,
            errorHistory: errorHistory,
            milestones: milestones,
            osCompatibility: osCompatibility,
            hardwareCompatibility: hardwareCompatibility,
            formatSupport: formatSupport,
            debugInfo: debugInfo,
            logEntries: logEntries,
            configurationDump: configurationDump,
        )
    }

    static func makeMetrics(performanceScore: Float) -> AudioMetrics {
        AudioMetrics(
            cpuUsage: 32,
            memoryUsage: 128_000_000,
            bufferUnderruns: 1,
            decodingLatency: 0.012,
            bufferFillLevel: 0.82,
            droppedFrames: 0,
            renderLatency: 0.004,
            timestamp: timestamp,
            currentBitrate: 2_000_000,
            averageLatency: 0.01,
            peakLatency: 0.02,
            glitchCount: 1,
            sampleRate: 192_000,
            bitDepth: 24,
            channelCount: 2,
            engineType: "AudioKitEngine",
            audioFormat: "FLAC",
            isBitPerfect: true,
            bufferSize: 1024,
            bufferResets: 0,
            averageBufferFill: 0.9,
            underrunRate: 0.1,
            timeSinceLastUnderrun: 120,
            diskIOPS: 30,
            networkBandwidth: 0,
            thermalPressure: 0.1,
            batteryUsageRate: 12,
            estimatedSNR: 98,
            dynamicRange: 110,
            frequencyResponseScore: 0.98,
            jitter: 0.0001,
            clockDrift: 0.00005,
            recoverableErrors: 0,
            criticalErrors: 0,
            recoverySuccessRate: 1,
            lastRecoveryTime: 1,
            performanceScore: performanceScore,
            qualityScore: 0.95,
            reliabilityScore: 0.96,
            efficiencyScore: 0.9,
        )
    }

    static func makeIssue(severity: IssueSeverity, title: String) -> DiagnosticIssue {
        DiagnosticIssue(
            type: .performance,
            severity: severity,
            title: title,
            description: "Detected condition requiring attention",
            technicalDetails: "Details for \(title)",
            resolution: "Follow mitigation steps",
            canAutoResolve: false,
            firstDetected: timestamp,
        )
    }

    static func makeRecommendation(priority: RecommendationPriority, title: String) -> PerformanceRecommendation {
        PerformanceRecommendation(
            type: .engineSelection,
            priority: priority,
            title: title,
            description: "Apply tuning for \(title)",
            expectedImprovement: "Improves stability",
            technicalDetails: "Adjust engine parameters",
        )
    }

    private static let engineInfo = AudioEngineInfo(
        type: "AudioKitEngine",
        version: "2.1",
        capabilities: ["Gapless", "Bit-Perfect"],
        configuration: ["renderMode": "realTime"],
        performanceProfile: "balanced",
        lastInitialized: timestamp,
    )

    private static let sessionInfo = AudioSessionInfo(
        category: "playback",
        mode: "default",
        options: ["mixWithOthers"],
        sampleRate: 192_000,
        ioBufferDuration: 0.01,
        isActive: true,
        isOtherAudioPlaying: false,
    )

    private static let deviceInfo = AudioDeviceInfo(
        deviceID: "BuiltInSpeaker",
        name: "iPhone Speakers",
        sampleRate: 192_000,
        bitDepth: 24,
        channels: 2,
        bufferSize: 1024,
        latency: 0.01,
    )

    private static let trendIndicator = TrendIndicator(
        currentValue: 32,
        changePercent: -5,
        direction: .improving,
        stability: .stable,
    )

    private static let performanceTrends = PerformanceTrendSummary(
        cpuTrend: trendIndicator,
        memoryTrend: trendIndicator,
        latencyTrend: trendIndicator,
        qualityTrend: trendIndicator,
        bufferTrend: trendIndicator,
        overallTrend: .improving,
    )

    private static let resourceUtilization = ResourceUtilizationSummary(
        cpuUtilization: ResourceUsageAnalysis(
            currentUsage: 32,
            averageUsage: 28,
            peakUsage: 60,
            efficiencyScore: 0.8,
            classification: .moderate,
        ),
        memoryUtilization: ResourceUsageAnalysis(
            currentUsage: 45,
            averageUsage: 40,
            peakUsage: 70,
            efficiencyScore: 0.75,
            classification: .high,
        ),
        batteryUtilization: ResourceUsageAnalysis(
            currentUsage: 12,
            averageUsage: 10,
            peakUsage: 18,
            efficiencyScore: 0.85,
            classification: .low,
        ),
        networkUtilization: ResourceUsageAnalysis(
            currentUsage: 0,
            averageUsage: 0,
            peakUsage: 0,
            efficiencyScore: 1,
            classification: .minimal,
        ),
        overallEfficiency: .good,
    )

    private static let qualityAssessment = QualityAssessmentSummary(
        qualityScore: 94,
        bitPerfectStatus: .active,
        signalIntegrity: SignalIntegrityAssessment(
            integrityScore: 96,
            issues: [.noise],
            pathAnalysis: "Signal path nominal",
            jitterLevel: .minimal,
        ),
        qualityIssues: [
            QualityIssue(
                type: .format,
                description: "Minor noise floor detected",
                impact: .minimal,
                resolution: "Enable exclusive mode",
            ),
        ],
        improvements: [
            QualityImprovement(
                title: "Enable Upsampling",
                description: "Use high quality resampler",
                expectedGain: 3,
                difficulty: .moderate,
            ),
        ],
    )

    private static let efficiencyAnalysis = EfficiencyAnalysisSummary(
        efficiencyScore: 88,
        powerEfficiency: .excellent,
        performanceEfficiency: .good,
        optimizationOpportunities: [],
    )

    private static let sessionStatistics = SessionStatisticsSummary(
        totalUptime: 7200,
        averagePerformanceScore: 0.88,
        totalAlerts: 2,
        errorRate: 0.05,
        bufferUnderrunIncidents: 1,
        qualityDropCount: 0,
        recoverySuccessRate: 0.98,
    )

    private static let errorHistory = ErrorHistorySummary(
        totalErrors: 2,
        errorsByCategory: [.buffer: 1, .session: 1],
        mostRecentError: DiagnosticError(
            code: "BUF-001",
            category: .buffer,
            description: "Buffer underrun",
            timestamp: timestamp,
            recoveryAttempted: true,
            recoverySuccessful: true,
        ),
        mostCommonErrorType: .buffer,
        errorFrequencyTrend: .stable,
    )

    private static let milestones = [
        PerformanceMilestone(
            type: .uptime,
            achievedAt: timestamp,
            description: "Two hours continuous playback",
            value: 7200,
        ),
    ]

    private static let osCompatibility = OSCompatibilityInfo(
        iosVersion: "26.0",
        deviceModel: "iPhone 16 Pro",
        compatibilityStatus: .excellent,
        knownIssues: [],
        recommendedSettings: ["Enable Lossless"],
    )

    private static let hardwareCompatibility = HardwareCompatibilityInfo(
        deviceCapabilities: DeviceCapabilityAssessment(
            capabilityScore: 92,
            cpuRating: .excellent,
            memoryRating: .good,
            audioProcessingCapability: .enthusiast,
        ),
        audioHardware: AudioHardwareInfo(
            builtInAudio: BuiltInAudioInfo(
                dacQuality: .excellent,
                maxSampleRate: 192_000,
                maxBitDepth: 24,
                snr: 110,
            ),
            externalDevices: [
                ExternalAudioDevice(
                    name: "Reference DAC",
                    type: .dac,
                    interface: .usb,
                    capabilities: ExternalDeviceCapabilities(
                        maxSampleRate: 384_000,
                        maxBitDepth: 32,
                        supportsBitPerfect: true,
                        qualityRating: .reference,
                    ),
                ),
            ],
            supportedFormats: [
                AudioFormatSupport(
                    format: "FLAC",
                    supportLevel: .native,
                    maxQuality: FormatQuality(
                        maxSampleRate: 384_000,
                        maxBitDepth: 32,
                        maxChannels: 2,
                    ),
                    recommendedEngine: AudioEngineType.audioKitEngine.rawValue,
                ),
            ],
        ),
        performanceLimitations: [
            PerformanceLimitation(
                type: .deviceLimitation,
                description: "Bluetooth bandwidth limits Hi-Res",
                impact: .low,
                workarounds: ["Use wired connection"],
            ),
        ],
        upgradeRecommendations: [
            UpgradeRecommendation(
                type: .hardware,
                description: "Add external clock",
                expectedImprovement: "Lower jitter",
                priority: .optional,
            ),
        ],
    )

    private static let formatSupport = FormatSupportMatrix(
        supportedFormats: [
            AudioFormatSupport(
                format: "ALAC",
                supportLevel: .native,
                maxQuality: FormatQuality(
                    maxSampleRate: 192_000,
                    maxBitDepth: 24,
                    maxChannels: 2,
                ),
                recommendedEngine: AudioEngineType.avAudioEngine.rawValue,
            ),
        ],
        compatibilityScore: 96,
        recommendations: [
            FormatRecommendation(
                format: "FLAC",
                reason: "Highest lossless support",
                qualityBenefit: "Bit-perfect",
                performanceImpact: "Low",
            ),
        ],
    )

    private static let debugInfo = DebugInformation(
        sessionID: "session-123",
        systemInfo: SystemDebugInfo(
            deviceIdentifier: "iPhone16,3",
            systemVersion: "iOS 26.0",
            availableMemory: 4_000_000_000,
            cpuArchitecture: "arm64e",
            thermalState: "nominal",
        ),
        audioStackInfo: AudioStackDebugInfo(
            activeAudioUnits: ["Output", "EQ"],
            sessionDetails: ["category": "playback"],
            engineConfiguration: ["latency": "low"],
            bufferInfo: BufferDebugInfo(
                bufferSizes: ["output": 1024],
                bufferUtilization: ["output": 0.85],
                allocationHistory: [
                    BufferAllocation(
                        timestamp: timestamp,
                        size: 1024,
                        reason: "Initial allocation",
                    ),
                ],
            ),
        ),
        performanceCounters: ["cpu": 32],
        debugFlags: ["safeMode": false],
    )

    private static let logEntries = [
        DiagnosticLogEntry(
            timestamp: timestamp,
            level: .info,
            category: "monitor",
            message: "Diagnostics collected",
            context: ["source": "playback"],
        ),
    ]

    private static let configurationDump = ConfigurationDump(
        engineConfig: ["engine": "AudioKit"],
        sessionConfig: ["mode": "default"],
        deviceConfig: ["output": "Built-in"],
        userPreferences: ["resampler": "linear"],
        systemSettings: ["thermalMode": "automatic"],
    )

    private static let defaultOptimization = OptimizationOpportunity(
        type: .resourceManagement,
        description: "Optimize background activity",
        expectedGain: 0.2,
        complexity: .low,
    )

    private static let defaultAlert = PlaybackAlert(
        type: .highCPUUsage,
        severity: .high,
        message: "CPU usage exceeded threshold",
        technicalDetails: "Sustained 95% usage",
        timestamp: timestamp,
        triggerValues: ["cpu": 95],
        suggestedActions: ["Reduce digital signal processing"],
    )
}
