import AVFoundation
@testable import Fonic_HiFi
import XCTest

@MainActor
final class BitPerfectValidatorTests: XCTestCase {
    func testValidateBitPerfectPlaybackAggregatesCollaboratorData() async {
        let capabilities = DeviceCapabilities(
            supportedSampleRates: [44100, 96000],
            maxBitDepth: 32,
            maxChannels: 2,
            supportsHardwareVolume: true,
            bypassesSystemMixer: true,
            bufferSizeRange: 64 ... 256,
            supportsExclusiveMode: true,
        )
        let deviceInfo = DeviceValidationInfo(
            id: "usb-dac",
            name: "Reference DAC",
            type: .usb,
            isDefault: true,
            capabilities: capabilities,
            connectionType: .usb,
        )
        let deviceManager = MockDeviceManager(
            capabilities: capabilities,
            deviceInfo: deviceInfo,
            bitDepthEstimate: 24,
        )
        let processingStage = AudioProcessingStage(
            type: .systemMixer,
            description: "System mixer active",
            affectsBitPerfect: true,
            performanceImpact: 0.4,
        )
        let analyzer = MockProcessingAnalyzer(
            detection: BitPerfectProcessingDetection(hasProcessing: true, stages: [processingStage]),
        )
        let expectedSettings = BitPerfectSettings(
            sampleRate: 96000,
            bitDepth: 24,
            bufferSize: 64,
            useExclusiveMode: true,
            bypassSystemVolume: true,
            sessionCategory: AVAudioSession.Category.playback.rawValue,
        )
        let alternative = AlternativeConfiguration(
            description: "USB DAC native",
            outputFormat: AudioOutputFormat(sampleRate: 96000, bitDepth: 24, channels: 2),
            benefits: ["Matches source format"],
            tradeoffs: [],
        )
        let recommendationEngine = MockRecommendationEngine(
            recommendedSettings: expectedSettings,
            alternatives: [alternative],
            performanceImpact: .high,
            confidence: 0.82,
        )
        let validator = BitPerfectValidator(
            audioSession: AVAudioSession.sharedInstance(),
            deviceManager: deviceManager,
            processingAnalyzer: analyzer,
            recommendationEngine: recommendationEngine,
        )
        let sourceFormat = AudioFileInfo(
            url: URL(fileURLWithPath: "/music/hires.flac"),
            format: .flac,
            duration: 180,
            bitDepth: 24,
            sampleRate: 96000,
            channels: 2,
            fileSize: 42_000_000,
        )

        let result = await validator.validateBitPerfectPlayback(sourceFormat: sourceFormat, outputDevice: nil)

        XCTAssertFalse(result.isValid)
        XCTAssertEqual(result.mismatchReason, .sampleRateMismatch)
        XCTAssertTrue(result.hasAudioProcessing)
        XCTAssertTrue(result.processingStages.contains(processingStage))
        XCTAssertTrue(result.processingStages.contains { $0.type == .sampleRateConversion })
        XCTAssertEqual(result.recommendedSettings, expectedSettings)
        XCTAssertEqual(result.alternatives, [alternative])
        XCTAssertEqual(result.performanceImpact, .high)
        XCTAssertEqual(result.deviceInfo, deviceInfo)
        XCTAssertEqual(result.confidence, 0.82, accuracy: 0.0001)
        XCTAssertEqual(deviceManager.currentCapabilitiesCallCount, 1)
        XCTAssertEqual(analyzer.detectCallCount, 1)
        XCTAssertEqual(recommendationEngine.recommendedCallCount, 1)
        XCTAssertEqual(recommendationEngine.alternativesCallCount, 1)
        XCTAssertEqual(recommendationEngine.performanceImpactCallCount, 1)
        XCTAssertEqual(recommendationEngine.validationConfidenceCallCount, 1)
    }

    func testValidateBitPerfectPlaybackReturnsCachedResult() async {
        let capabilities = DeviceCapabilities(
            supportedSampleRates: [44100, 48000],
            maxBitDepth: 24,
            maxChannels: 2,
        )
        let deviceManager = MockDeviceManager(
            capabilities: capabilities,
            deviceInfo: nil,
            bitDepthEstimate: 24,
        )
        let analyzer = MockProcessingAnalyzer(
            detection: BitPerfectProcessingDetection(hasProcessing: false, stages: []),
        )
        let recommendationEngine = MockRecommendationEngine(
            recommendedSettings: BitPerfectSettings(
                sampleRate: 44100,
                bitDepth: 16,
                bufferSize: 128,
                useExclusiveMode: false,
                bypassSystemVolume: false,
                sessionCategory: AVAudioSession.Category.playback.rawValue,
            ),
            alternatives: [],
            performanceImpact: .low,
            confidence: 0.75,
        )
        let validator = BitPerfectValidator(
            audioSession: AVAudioSession.sharedInstance(),
            deviceManager: deviceManager,
            processingAnalyzer: analyzer,
            recommendationEngine: recommendationEngine,
        )
        let sourceFormat = AudioFileInfo(
            url: URL(fileURLWithPath: "/music/cd.flac"),
            format: .flac,
            duration: 200,
            bitDepth: 16,
            sampleRate: 44100,
            channels: 2,
            fileSize: 30_000_000,
        )

        let first = await validator.validateBitPerfectPlayback(sourceFormat: sourceFormat, outputDevice: nil)
        let second = await validator.validateBitPerfectPlayback(sourceFormat: sourceFormat, outputDevice: nil)

        XCTAssertEqual(first, second)
        XCTAssertEqual(deviceManager.currentCapabilitiesCallCount, 1)
        XCTAssertEqual(analyzer.detectCallCount, 1)
        XCTAssertEqual(recommendationEngine.recommendedCallCount, 1)
    }

    func testAnalyzeAudioPathUsesValidationEngineCollaborators() async {
        let capabilities = DeviceCapabilities(
            supportedSampleRates: [44100, 48000],
            maxBitDepth: 24,
            maxChannels: 2,
            supportsHardwareVolume: true,
            bypassesSystemMixer: false,
            bufferSizeRange: 128 ... 1024,
            supportsExclusiveMode: false
        )
        let deviceInfo = DeviceValidationInfo(
            id: "built-in",
            name: "Built-in",
            type: .builtin,
            isDefault: true,
            capabilities: capabilities,
            connectionType: .builtin
        )
        let deviceManager = MockDeviceManager(
            capabilities: capabilities,
            deviceInfo: deviceInfo,
            bitDepthEstimate: 16
        )
        let stage = AudioProcessingStage(
            type: .systemMixer,
            description: "Mixer",
            affectsBitPerfect: true,
            performanceImpact: 0.2
        )
        let analyzer = MockProcessingAnalyzer(
            detection: BitPerfectProcessingDetection(hasProcessing: true, stages: [stage])
        )
        let recommendationEngine = MockRecommendationEngine(
            recommendedSettings: BitPerfectSettings(
                sampleRate: 44100,
                bitDepth: 16,
                bufferSize: 128,
                useExclusiveMode: false,
                bypassSystemVolume: false,
                sessionCategory: AVAudioSession.Category.playback.rawValue
            ),
            alternatives: [],
            performanceImpact: .low,
            confidence: 0.6
        )

        let validator = BitPerfectValidator(
            audioSession: AVAudioSession.sharedInstance(),
            deviceManager: deviceManager,
            processingAnalyzer: analyzer,
            recommendationEngine: recommendationEngine
        )

        let analysis = await validator.analyzeAudioPath()

        XCTAssertEqual(deviceManager.currentDeviceInfoCallCount, 1)
        XCTAssertEqual(analyzer.detectCallCount, 1)
        XCTAssertTrue(analysis.processingStages.contains(stage))
    }

    func testGetOptimalConfigurationRequestsRecommendations() async {
        let capabilities = DeviceCapabilities(
            supportedSampleRates: [44100, 96000],
            maxBitDepth: 24,
            maxChannels: 2,
            supportsHardwareVolume: true,
            bypassesSystemMixer: true,
            bufferSizeRange: 64 ... 256,
            supportsExclusiveMode: true
        )
        let deviceManager = MockDeviceManager(
            capabilities: capabilities,
            deviceInfo: nil,
            bitDepthEstimate: 24
        )
        let analyzer = MockProcessingAnalyzer(
            detection: BitPerfectProcessingDetection(hasProcessing: false, stages: [])
        )
        let recommendationEngine = MockRecommendationEngine(
            recommendedSettings: BitPerfectSettings(
                sampleRate: 96000,
                bitDepth: 24,
                bufferSize: 64,
                useExclusiveMode: true,
                bypassSystemVolume: true,
                sessionCategory: AVAudioSession.Category.playback.rawValue
            ),
            alternatives: [],
            performanceImpact: .medium,
            confidence: 0.7
        )
        let validator = BitPerfectValidator(
            audioSession: AVAudioSession.sharedInstance(),
            deviceManager: deviceManager,
            processingAnalyzer: analyzer,
            recommendationEngine: recommendationEngine
        )
        let sourceFormat = AudioFileInfo(
            url: URL(fileURLWithPath: "/music/hires.flac"),
            format: .flac,
            duration: 120,
            bitDepth: 24,
            sampleRate: 96000,
            channels: 2,
            fileSize: 40_000_000
        )

        _ = await validator.getOptimalConfiguration(for: sourceFormat)

        XCTAssertEqual(deviceManager.currentCapabilitiesCallCount, 1)
        XCTAssertEqual(recommendationEngine.recommendedCallCount, 1)
        XCTAssertEqual(recommendationEngine.expectedImprovementDescriptionCallCount, 1)
    }
}

@MainActor
private final class MockDeviceManager: BitPerfectDeviceManaging {
    var capabilities: DeviceCapabilities
    var deviceInfo: DeviceValidationInfo?
    var bitDepthEstimate: Int

    private(set) var currentCapabilitiesCallCount = 0
    private(set) var currentDeviceInfoCallCount = 0
    private var dacCompatibility: [String: DACCompatibilityInfo] = [:]

    init(capabilities: DeviceCapabilities, deviceInfo: DeviceValidationInfo?, bitDepthEstimate: Int) {
        self.capabilities = capabilities
        self.deviceInfo = deviceInfo
        self.bitDepthEstimate = bitDepthEstimate
    }

    func currentCapabilities(using _: AVAudioSession) async -> DeviceCapabilities {
        currentCapabilitiesCallCount += 1
        return capabilities
    }

    func availableDevices(using _: AVAudioSession) async -> [DeviceWithCapabilities] { [] }

    func supportsBitPerfectPlayback(device _: AudioDevice) async -> Bool { true }

    func updateDACCompatibility(_ dacInfo: DACCompatibilityInfo) async {
        dacCompatibility[dacInfo.deviceIdentifier] = dacInfo
    }

    func dacCompatibility(for deviceIdentifier: String) async -> DACCompatibilityInfo? {
        dacCompatibility[deviceIdentifier]
    }

    func clearDACCompatibilityCache() async {
        dacCompatibility.removeAll()
    }

    func currentDeviceInfo(using _: AVAudioSession) async -> DeviceValidationInfo? {
        currentDeviceInfoCallCount += 1
        return deviceInfo
    }

    func estimateOutputBitDepth(for _: AVAudioSession, capabilities _: DeviceCapabilities) -> Int {
        bitDepthEstimate
    }
}

@MainActor
private final class MockProcessingAnalyzer: BitPerfectProcessingAnalyzing {
    var detection: BitPerfectProcessingDetection
    private(set) var detectCallCount = 0

    init(detection: BitPerfectProcessingDetection) {
        self.detection = detection
    }

    func detectProcessing(in _: AVAudioSession) async -> BitPerfectProcessingDetection {
        detectCallCount += 1
        return detection
    }
}

@MainActor
private final class MockRecommendationEngine: BitPerfectRecommendationGenerating {
    let recommendedSettingsResult: BitPerfectSettings
    let alternativesResult: [AlternativeConfiguration]
    let performanceImpactResult: PerformanceImpact
    let confidenceResult: Double

    private(set) var recommendedCallCount = 0
    private(set) var alternativesCallCount = 0
    private(set) var performanceImpactCallCount = 0
    private(set) var validationConfidenceCallCount = 0
    private(set) var expectedImprovementDescriptionCallCount = 0

    init(
        recommendedSettings: BitPerfectSettings,
        alternatives: [AlternativeConfiguration],
        performanceImpact: PerformanceImpact,
        confidence: Double,
    ) {
        recommendedSettingsResult = recommendedSettings
        alternativesResult = alternatives
        performanceImpactResult = performanceImpact
        confidenceResult = confidence
    }

    func recommendedSettings(sourceFormat _: AudioFileInfo, deviceCapabilities _: DeviceCapabilities) -> BitPerfectSettings {
        recommendedCallCount += 1
        return recommendedSettingsResult
    }

    func alternatives(sourceFormat _: AudioFileInfo, deviceCapabilities _: DeviceCapabilities) -> [AlternativeConfiguration] {
        alternativesCallCount += 1
        return alternativesResult
    }

    func conversionAnalysis(sourceFormat _: AudioFileInfo, outputCapabilities _: DeviceCapabilities) -> ConversionAnalysis {
        ConversionAnalysis(
            conversionRequired: false,
            conversionTypes: [],
            qualityImpact: .none,
            performanceImpact: 0,
            alternatives: [],
        )
    }

    func performanceImpact(processingStages _: [AudioProcessingStage], sourceFormat _: AudioFileInfo) -> PerformanceImpact {
        performanceImpactCallCount += 1
        return performanceImpactResult
    }

    func validationConfidence(
        deviceInfo _: DeviceValidationInfo?,
        sessionAnalysis _: AudioSessionAnalysis,
        hasKnownDAC _: Bool,
    ) -> Double {
        validationConfidenceCallCount += 1
        return confidenceResult
    }

    func expectedImprovementDescription(for _: [ConfigurationChange]) -> String {
        expectedImprovementDescriptionCallCount += 1
        return ""
    }
}
