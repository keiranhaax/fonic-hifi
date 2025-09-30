//
//  BitPerfectValidatorService.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import AVFoundation
import Foundation

/// Protocol defining bit-perfect validation methods for audio playback verification
@MainActor
public protocol BitPerfectValidatorService: AnyObject, Sendable {
    // MARK: - Core Validation

    /// Validate if current playback setup can achieve bit-perfect output
    /// - Parameters:
    ///   - sourceFormat: The source audio format from the file
    ///   - outputDevice: The current output device (optional)
    /// - Returns: Detailed validation result
    func validateBitPerfectPlayback(
        sourceFormat: AudioFileInfo,
        outputDevice: AudioDevice?,
    ) async -> BitPerfectValidationResult

    /// Validate a specific audio format against output capabilities
    /// - Parameters:
    ///   - format: Audio format to validate
    ///   - sampleRate: Desired sample rate
    ///   - bitDepth: Desired bit depth
    ///   - outputDevice: Target output device (optional)
    /// - Returns: Validation result
    func validateFormat(
        _ format: AudioFormat,
        sampleRate: Int,
        bitDepth: Int,
        outputDevice: AudioDevice?,
    ) async -> BitPerfectValidationResult

    /// Perform real-time validation during playback
    /// - Parameters:
    ///   - audioSession: Current AVAudioSession
    ///   - sourceFormat: Source audio format
    /// - Returns: Current validation status
    func validateRealTime(
        audioSession: AVAudioSession,
        sourceFormat: AudioFileInfo,
    ) async -> BitPerfectValidationResult

    // MARK: - Device Analysis

    /// Get detailed capabilities of the current output device
    /// - Returns: Device capabilities for bit-perfect validation
    func getCurrentDeviceCapabilities() async -> DeviceCapabilities

    /// Get all available output devices with their capabilities
    /// - Returns: Array of devices with capability information
    func getAvailableDevicesWithCapabilities() async -> [DeviceWithCapabilities]

    /// Check if a specific device supports bit-perfect playback
    /// - Parameter device: Device to check
    /// - Returns: Whether the device supports bit-perfect output
    func supportseBitPerfectPlayback(device: AudioDevice) async -> Bool

    // MARK: - DAC Compatibility

    /// Update DAC compatibility information
    /// - Parameter dacInfo: DAC compatibility information to cache
    func updateDACCompatibility(_ dacInfo: DACCompatibilityInfo) async

    /// Get known DAC compatibility information
    /// - Parameter deviceIdentifier: Device identifier
    /// - Returns: Cached DAC information if available
    func getDACCompatibility(for deviceIdentifier: String) async -> DACCompatibilityInfo?

    /// Clear all cached DAC compatibility information
    func clearDACCompatibilityCache() async

    // MARK: - Analysis & Recommendations

    /// Analyze current audio path for potential issues
    /// - Returns: Detailed analysis with recommendations
    func analyzeAudioPath() async -> AudioPathAnalysis

    /// Get recommendations for optimal bit-perfect setup
    /// - Parameter sourceFormat: Source audio format
    /// - Returns: Configuration recommendations
    func getOptimalConfiguration(for sourceFormat: AudioFileInfo) async -> BitPerfectRecommendations

    /// Check if current audio session settings are optimal
    /// - Returns: Session analysis with suggested improvements
    func analyzeAudioSession() async -> AudioSessionAnalysis

    // MARK: - Format Conversion Analysis

    /// Determine if format conversion is required
    /// - Parameters:
    ///   - sourceFormat: Source audio format
    ///   - outputCapabilities: Output device capabilities
    /// - Returns: Conversion analysis results
    func analyzeRequiredConversion(
        sourceFormat: AudioFileInfo,
        outputCapabilities: DeviceCapabilities,
    ) async -> ConversionAnalysis

    /// Get supported output formats for current device
    /// - Returns: List of natively supported formats
    func getSupportedOutputFormats() async -> [AudioOutputFormat]
}

// MARK: - Supporting Types

/// Detailed device capabilities for bit-perfect validation
public struct DeviceCapabilities: Sendable, Equatable {
    /// Supported sample rates in Hz
    public let supportedSampleRates: [Int]

    /// Maximum supported bit depth
    public let maxBitDepth: Int

    /// Maximum number of channels
    public let maxChannels: Int

    /// Whether device supports hardware volume control
    public let supportsHardwareVolume: Bool

    /// Whether device bypasses system mixer
    public let bypassesSystemMixer: Bool

    /// Device buffer size capabilities
    public let bufferSizeRange: ClosedRange<Int>

    /// Whether device supports exclusive mode
    public let supportsExclusiveMode: Bool

    /// Native formats supported without conversion
    public let nativeFormats: [AudioOutputFormat]

    public init(
        supportedSampleRates: [Int],
        maxBitDepth: Int,
        maxChannels: Int,
        supportsHardwareVolume: Bool = true,
        bypassesSystemMixer: Bool = false,
        bufferSizeRange: ClosedRange<Int> = 128 ... 8192,
        supportsExclusiveMode: Bool = false,
        nativeFormats: [AudioOutputFormat] = [],
    ) {
        self.supportedSampleRates = supportedSampleRates
        self.maxBitDepth = maxBitDepth
        self.maxChannels = maxChannels
        self.supportsHardwareVolume = supportsHardwareVolume
        self.bypassesSystemMixer = bypassesSystemMixer
        self.bufferSizeRange = bufferSizeRange
        self.supportsExclusiveMode = supportsExclusiveMode
        self.nativeFormats = nativeFormats
    }
}

/// Device paired with its capabilities
public struct DeviceWithCapabilities: Sendable {
    public let device: AudioDevice
    public let capabilities: DeviceCapabilities

    public init(device: AudioDevice, capabilities: DeviceCapabilities) {
        self.device = device
        self.capabilities = capabilities
    }
}

/// Audio output format specification
public struct AudioOutputFormat: Sendable, Equatable {
    public let sampleRate: Int
    public let bitDepth: Int
    public let channels: Int
    public let isFloatingPoint: Bool

    public init(sampleRate: Int, bitDepth: Int, channels: Int, isFloatingPoint: Bool = false) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.isFloatingPoint = isFloatingPoint
    }
}

/// Analysis of the current audio signal path
public struct AudioPathAnalysis: Sendable {
    /// Whether the path is bit-perfect
    public let isBitPerfect: Bool

    /// Detected signal processing stages
    public let processingStages: [AudioProcessingStage]

    /// Identified bottlenecks or limitations
    public let limitations: [AudioPathLimitation]

    /// Overall quality score (0.0 to 1.0)
    public let qualityScore: Double

    /// Timestamp of analysis
    public let timestamp: Date

    public init(
        isBitPerfect: Bool,
        processingStages: [AudioProcessingStage],
        limitations: [AudioPathLimitation],
        qualityScore: Double,
        timestamp: Date = Date(),
    ) {
        self.isBitPerfect = isBitPerfect
        self.processingStages = processingStages
        self.limitations = limitations
        self.qualityScore = qualityScore
        self.timestamp = timestamp
    }
}

/// Detected audio processing stage in the signal path
public struct AudioProcessingStage: Sendable, Equatable {
    /// Type of processing
    public let type: ProcessingType

    /// Description of the processing
    public let description: String

    /// Whether this stage affects bit-perfect playback
    public let affectsBitPerfect: Bool

    /// Performance impact (0.0 to 1.0)
    public let performanceImpact: Double

    public init(type: ProcessingType, description: String, affectsBitPerfect: Bool, performanceImpact: Double) {
        self.type = type
        self.description = description
        self.affectsBitPerfect = affectsBitPerfect
        self.performanceImpact = performanceImpact
    }
}

/// Types of audio processing
public enum ProcessingType: String, Sendable {
    case sampleRateConversion = "sample_rate_conversion"
    case bitDepthConversion = "bit_depth_conversion"
    case channelMixing = "channel_mixing"
    case volumeControl = "volume_control"
    case equalization
    case dynamicsProcessing = "dynamics_processing"
    case spatialAudio = "spatial_audio"
    case systemMixer = "system_mixer"
    case movieMode = "movie_mode"
    case voiceProcessing = "voice_processing"
    case spokenAudioMode = "spoken_audio_mode"
    case bluetoothCodec = "bluetooth_codec"
}

/// Limitations detected in the audio path
public struct AudioPathLimitation: Sendable {
    /// Type of limitation
    public let type: LimitationType

    /// Description of the limitation
    public let description: String

    /// Suggested resolution
    public let resolution: String

    /// Severity level
    public let severity: LimitationSeverity

    public init(type: LimitationType, description: String, resolution: String, severity: LimitationSeverity) {
        self.type = type
        self.description = description
        self.resolution = resolution
        self.severity = severity
    }
}

/// Types of audio path limitations
public enum LimitationType: String, Sendable {
    case deviceLimitation = "device_limitation"
    case systemLimitation = "system_limitation"
    case formatIncompatibility = "format_incompatibility"
    case configurationIssue = "configuration_issue"
    case resourceConstraint = "resource_constraint"
}

/// Severity levels for limitations
public enum LimitationSeverity: String, Sendable {
    case info
    case warning
    case error
    case critical
}

/// Recommendations for optimal bit-perfect configuration
public struct BitPerfectRecommendations: Sendable {
    /// Recommended audio session settings
    public let sessionSettings: [String: String]

    /// Recommended buffer size
    public let bufferSize: Int

    /// Recommended output device (if different from current)
    public let recommendedDevice: AudioDevice?

    /// Configuration changes required
    public let requiredChanges: [ConfigurationChange]

    /// Expected improvement description
    public let expectedImprovement: String

    public init(
        sessionSettings: [String: String],
        bufferSize: Int,
        recommendedDevice: AudioDevice?,
        requiredChanges: [ConfigurationChange],
        expectedImprovement: String,
    ) {
        self.sessionSettings = sessionSettings
        self.bufferSize = bufferSize
        self.recommendedDevice = recommendedDevice
        self.requiredChanges = requiredChanges
        self.expectedImprovement = expectedImprovement
    }
}

/// Required configuration change
public struct ConfigurationChange: Sendable {
    public let setting: String
    public let currentValue: String
    public let recommendedValue: String
    public let reason: String

    public init(setting: String, currentValue: String, recommendedValue: String, reason: String) {
        self.setting = setting
        self.currentValue = currentValue
        self.recommendedValue = recommendedValue
        self.reason = reason
    }
}

/// Analysis of current audio session configuration
public struct AudioSessionAnalysis: Sendable {
    /// Whether session is optimally configured
    public let isOptimal: Bool

    /// Current session settings
    public let currentSettings: [String: String]

    /// Identified issues
    public let issues: [SessionIssue]

    /// Recommended improvements
    public let recommendations: [SessionRecommendation]

    public init(
        isOptimal: Bool,
        currentSettings: [String: String],
        issues: [SessionIssue],
        recommendations: [SessionRecommendation],
    ) {
        self.isOptimal = isOptimal
        self.currentSettings = currentSettings
        self.issues = issues
        self.recommendations = recommendations
    }
}

/// Audio session issue
public struct SessionIssue: Sendable {
    public let description: String
    public let impact: String
    public let severity: LimitationSeverity

    public init(description: String, impact: String, severity: LimitationSeverity) {
        self.description = description
        self.impact = impact
        self.severity = severity
    }
}

/// Audio session recommendation
public struct SessionRecommendation: Sendable {
    public let setting: String
    public let recommendation: String
    public let benefit: String

    public init(setting: String, recommendation: String, benefit: String) {
        self.setting = setting
        self.recommendation = recommendation
        self.benefit = benefit
    }
}

/// Analysis of required format conversion
public struct ConversionAnalysis: Sendable {
    /// Whether conversion is required
    public let conversionRequired: Bool

    /// Types of conversion needed
    public let conversionTypes: [ConversionType]

    /// Quality impact of conversion
    public let qualityImpact: QualityImpact

    /// Performance impact
    public let performanceImpact: Double

    /// Alternative configurations that avoid conversion
    public let alternatives: [AlternativeConfiguration]

    public init(
        conversionRequired: Bool,
        conversionTypes: [ConversionType],
        qualityImpact: QualityImpact,
        performanceImpact: Double,
        alternatives: [AlternativeConfiguration],
    ) {
        self.conversionRequired = conversionRequired
        self.conversionTypes = conversionTypes
        self.qualityImpact = qualityImpact
        self.performanceImpact = performanceImpact
        self.alternatives = alternatives
    }
}

/// Types of format conversion
public enum ConversionType: String, Sendable {
    case sampleRate = "sample_rate"
    case bitDepth = "bit_depth"
    case channelCount = "channel_count"
    case formatType = "format_type"
}

/// Quality impact assessment
public enum QualityImpact: String, Sendable {
    case none
    case minimal
    case moderate
    case significant
    case severe
}

/// Alternative configuration to avoid conversion
public struct AlternativeConfiguration: Sendable, Equatable {
    public let description: String
    public let outputFormat: AudioOutputFormat
    public let benefits: [String]
    public let tradeoffs: [String]

    public init(description: String, outputFormat: AudioOutputFormat, benefits: [String], tradeoffs: [String]) {
        self.description = description
        self.outputFormat = outputFormat
        self.benefits = benefits
        self.tradeoffs = tradeoffs
    }
}
