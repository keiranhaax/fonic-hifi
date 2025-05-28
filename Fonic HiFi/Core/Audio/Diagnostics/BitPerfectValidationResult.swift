//
//  BitPerfectValidationResult.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation

/// Comprehensive result of bit-perfect validation
public struct BitPerfectValidationResult: Sendable, Equatable {
    
    // MARK: - Core Validation Results
    
    /// Whether bit-perfect playback is possible/active
    public let isValid: Bool
    
    /// Overall validation confidence (0.0 to 1.0)
    public let confidence: Double
    
    /// Timestamp when validation was performed
    public let timestamp: Date
    
    // MARK: - Sample Rate Validation
    
    /// Expected source sample rate in Hz
    public let expectedSampleRate: Int
    
    /// Actual output sample rate in Hz
    public let actualSampleRate: Int
    
    /// Whether sample rates match exactly
    public let sampleRateMatches: Bool
    
    // MARK: - Bit Depth Validation
    
    /// Expected source bit depth
    public let expectedBitDepth: Int
    
    /// Actual output bit depth
    public let actualBitDepth: Int
    
    /// Whether bit depths match exactly
    public let bitDepthMatches: Bool
    
    // MARK: - Channel Configuration
    
    /// Expected source channel count
    public let expectedChannels: Int
    
    /// Actual output channel count
    public let actualChannels: Int
    
    /// Whether channel counts match exactly
    public let channelCountMatches: Bool
    
    // MARK: - Validation Issues
    
    /// Primary reason for validation failure (if any)
    public let mismatchReason: BitPerfectMismatchReason?
    
    /// All detected validation issues
    public let validationIssues: [ValidationIssue]
    
    /// Warnings that don't prevent bit-perfect but may affect quality
    public let warnings: [ValidationWarning]
    
    // MARK: - Device Information
    
    /// Information about the output device used for validation
    public let deviceInfo: DeviceValidationInfo?
    
    /// Whether the device supports the required format natively
    public let deviceSupportsFormat: Bool
    
    // MARK: - Processing Chain Analysis
    
    /// Whether any audio processing is detected in the chain
    public let hasAudioProcessing: Bool
    
    /// Detected processing stages that affect bit-perfect playback
    public let processingStages: [AudioProcessingStage]
    
    /// System volume level (affects bit-perfect if not 100%)
    public let systemVolume: Float
    
    /// Application volume level
    public let applicationVolume: Float
    
    // MARK: - Recommendations
    
    /// Recommended settings to achieve or improve bit-perfect playback
    public let recommendedSettings: BitPerfectSettings
    
    /// Alternative configurations if bit-perfect is not possible
    public let alternatives: [AlternativeConfiguration]
    
    /// Performance impact assessment
    public let performanceImpact: PerformanceImpact
    
    // MARK: - Initialization
    
    public init(
        isValid: Bool,
        confidence: Double = 1.0,
        timestamp: Date = Date(),
        expectedSampleRate: Int,
        actualSampleRate: Int,
        expectedBitDepth: Int,
        actualBitDepth: Int,
        expectedChannels: Int = 2,
        actualChannels: Int = 2,
        mismatchReason: BitPerfectMismatchReason? = nil,
        validationIssues: [ValidationIssue] = [],
        warnings: [ValidationWarning] = [],
        deviceInfo: DeviceValidationInfo? = nil,
        deviceSupportsFormat: Bool = true,
        hasAudioProcessing: Bool = false,
        processingStages: [AudioProcessingStage] = [],
        systemVolume: Float = 1.0,
        applicationVolume: Float = 1.0,
        recommendedSettings: BitPerfectSettings = BitPerfectSettings(),
        alternatives: [AlternativeConfiguration] = [],
        performanceImpact: PerformanceImpact = .low
    ) {
        self.isValid = isValid
        self.confidence = confidence
        self.timestamp = timestamp
        self.expectedSampleRate = expectedSampleRate
        self.actualSampleRate = actualSampleRate
        self.sampleRateMatches = expectedSampleRate == actualSampleRate
        self.expectedBitDepth = expectedBitDepth
        self.actualBitDepth = actualBitDepth
        self.bitDepthMatches = expectedBitDepth == actualBitDepth
        self.expectedChannels = expectedChannels
        self.actualChannels = actualChannels
        self.channelCountMatches = expectedChannels == actualChannels
        self.mismatchReason = mismatchReason
        self.validationIssues = validationIssues
        self.warnings = warnings
        self.deviceInfo = deviceInfo
        self.deviceSupportsFormat = deviceSupportsFormat
        self.hasAudioProcessing = hasAudioProcessing
        self.processingStages = processingStages
        self.systemVolume = systemVolume
        self.applicationVolume = applicationVolume
        self.recommendedSettings = recommendedSettings
        self.alternatives = alternatives
        self.performanceImpact = performanceImpact
    }
    
    // MARK: - Computed Properties
    
    /// Overall format compatibility score (0.0 to 1.0)
    public var compatibilityScore: Double {
        var score = 1.0
        
        if !sampleRateMatches { score -= 0.4 }
        if !bitDepthMatches { score -= 0.3 }
        if !channelCountMatches { score -= 0.2 }
        if hasAudioProcessing { score -= 0.1 }
        
        return max(0.0, score)
    }
    
    /// Whether all critical parameters match
    public var criticalParametersMatch: Bool {
        return sampleRateMatches && bitDepthMatches && channelCountMatches
    }
    
    /// Whether volume settings allow bit-perfect playback
    public var volumeIsOptimal: Bool {
        return systemVolume == 1.0 && applicationVolume == 1.0
    }
    
    /// Quick summary of validation status
    public var statusSummary: String {
        if isValid {
            return "Bit-perfect playback active"
        } else if let reason = mismatchReason {
            return reason.userFriendlyDescription
        } else {
            return "Bit-perfect validation failed"
        }
    }
    
    /// Detailed validation report for debugging
    public var detailedReport: String {
        var report = "Bit-Perfect Validation Report\n"
        report += "==============================\n"
        report += "Timestamp: \(timestamp)\n"
        report += "Result: \(isValid ? "VALID" : "INVALID")\n"
        report += "Confidence: \(String(format: "%.1f%%", confidence * 100))\n\n"
        
        report += "Format Comparison:\n"
        report += "- Sample Rate: \(expectedSampleRate)Hz → \(actualSampleRate)Hz (\(sampleRateMatches ? "MATCH" : "MISMATCH"))\n"
        report += "- Bit Depth: \(expectedBitDepth)-bit → \(actualBitDepth)-bit (\(bitDepthMatches ? "MATCH" : "MISMATCH"))\n"
        report += "- Channels: \(expectedChannels) → \(actualChannels) (\(channelCountMatches ? "MATCH" : "MISMATCH"))\n\n"
        
        if let deviceInfo = deviceInfo {
            report += "Output Device:\n"
            report += "- Name: \(deviceInfo.name)\n"
            report += "- Type: \(deviceInfo.type.displayName)\n"
            report += "- Supports Format: \(deviceSupportsFormat ? "YES" : "NO")\n\n"
        }
        
        report += "Audio Processing:\n"
        report += "- System Volume: \(String(format: "%.0f%%", systemVolume * 100))\n"
        report += "- App Volume: \(String(format: "%.0f%%", applicationVolume * 100))\n"
        report += "- Processing Stages: \(processingStages.count)\n"
        
        if !processingStages.isEmpty {
            for stage in processingStages {
                report += "  • \(stage.description)\n"
            }
        }
        
        if !validationIssues.isEmpty {
            report += "\nIssues Detected:\n"
            for issue in validationIssues {
                report += "- [\(issue.severity.rawValue.uppercased())] \(issue.description)\n"
            }
        }
        
        if !warnings.isEmpty {
            report += "\nWarnings:\n"
            for warning in warnings {
                report += "- \(warning.description)\n"
            }
        }
        
        return report
    }
}

// MARK: - Supporting Types

/// Specific reasons why bit-perfect playback cannot be achieved
public enum BitPerfectMismatchReason: String, Sendable, CaseIterable {
    case sampleRateMismatch = "sample_rate_mismatch"
    case bitDepthMismatch = "bit_depth_mismatch"
    case channelCountMismatch = "channel_count_mismatch"
    case deviceNotCapable = "device_not_capable"
    case systemVolumeNotUnity = "system_volume_not_unity"
    case applicationVolumeNotUnity = "application_volume_not_unity"
    case audioProcessingActive = "audio_processing_active"
    case formatConversionRequired = "format_conversion_required"
    case systemMixerActive = "system_mixer_active"
    case exclusiveModeUnavailable = "exclusive_mode_unavailable"
    case bluetoothCompression = "bluetooth_compression"
    case airplayCompression = "airplay_compression"
    case dspProcessingEnabled = "dsp_processing_enabled"
    case equalizerActive = "equalizer_active"
    case spatialAudioActive = "spatial_audio_active"
    case unknownIssue = "unknown_issue"
    
    /// User-friendly description of the mismatch reason
    public var userFriendlyDescription: String {
        switch self {
        case .sampleRateMismatch:
            return "Sample rate conversion is required"
        case .bitDepthMismatch:
            return "Bit depth conversion is required"
        case .channelCountMismatch:
            return "Channel configuration doesn't match"
        case .deviceNotCapable:
            return "Output device doesn't support the format"
        case .systemVolumeNotUnity:
            return "System volume is not at 100%"
        case .applicationVolumeNotUnity:
            return "Application volume is not at 100%"
        case .audioProcessingActive:
            return "Audio processing is affecting the signal"
        case .formatConversionRequired:
            return "Audio format conversion is required"
        case .systemMixerActive:
            return "System audio mixer is processing the signal"
        case .exclusiveModeUnavailable:
            return "Exclusive audio mode is not available"
        case .bluetoothCompression:
            return "Bluetooth audio compression is active"
        case .airplayCompression:
            return "AirPlay compression is active"
        case .dspProcessingEnabled:
            return "Digital signal processing is enabled"
        case .equalizerActive:
            return "Audio equalizer is active"
        case .spatialAudioActive:
            return "Spatial audio processing is active"
        case .unknownIssue:
            return "Unknown issue preventing bit-perfect playback"
        }
    }
    
    /// Technical description for debugging
    public var technicalDescription: String {
        switch self {
        case .sampleRateMismatch:
            return "Source and output sample rates differ, requiring resampling"
        case .bitDepthMismatch:
            return "Source and output bit depths differ, requiring bit depth conversion"
        case .channelCountMismatch:
            return "Source and output channel counts differ, requiring channel matrix processing"
        case .deviceNotCapable:
            return "The audio output device hardware does not support the source format natively"
        case .systemVolumeNotUnity:
            return "System volume level is not 100%, causing digital volume scaling"
        case .applicationVolumeNotUnity:
            return "Application volume level is not 100%, causing digital volume scaling"
        case .audioProcessingActive:
            return "One or more audio processing stages are active in the signal path"
        case .formatConversionRequired:
            return "The audio format requires conversion to match output capabilities"
        case .systemMixerActive:
            return "The system audio mixer is processing multiple audio streams"
        case .exclusiveModeUnavailable:
            return "Exclusive mode access to the audio device is not available"
        case .bluetoothCompression:
            return "Bluetooth audio codecs are compressing the audio signal"
        case .airplayCompression:
            return "AirPlay protocol is compressing the audio signal"
        case .dspProcessingEnabled:
            return "Hardware or software DSP processing is enabled"
        case .equalizerActive:
            return "Audio equalizer is applying frequency response modifications"
        case .spatialAudioActive:
            return "Spatial audio processing is virtualizing the soundstage"
        case .unknownIssue:
            return "An unidentified issue is preventing bit-perfect audio playback"
        }
    }
    
    /// Severity level of this mismatch reason
    public var severity: LimitationSeverity {
        switch self {
        case .sampleRateMismatch, .bitDepthMismatch, .formatConversionRequired:
            return .error
        case .deviceNotCapable, .exclusiveModeUnavailable:
            return .critical
        case .channelCountMismatch, .systemMixerActive:
            return .warning
        case .systemVolumeNotUnity, .applicationVolumeNotUnity, .audioProcessingActive:
            return .warning
        case .bluetoothCompression, .airplayCompression:
            return .info
        case .dspProcessingEnabled, .equalizerActive, .spatialAudioActive:
            return .warning
        case .unknownIssue:
            return .error
        }
    }
}

/// Specific validation issue detected during bit-perfect analysis
public struct ValidationIssue: Sendable, Equatable {
    /// Type of validation issue
    public let type: ValidationIssueType
    
    /// Human-readable description
    public let description: String
    
    /// Technical details for debugging
    public let technicalDetails: String
    
    /// Severity level
    public let severity: LimitationSeverity
    
    /// Suggested resolution
    public let suggestedResolution: String
    
    /// Whether this issue can be automatically resolved
    public let canAutoResolve: Bool
    
    public init(
        type: ValidationIssueType,
        description: String,
        technicalDetails: String = "",
        severity: LimitationSeverity,
        suggestedResolution: String,
        canAutoResolve: Bool = false
    ) {
        self.type = type
        self.description = description
        self.technicalDetails = technicalDetails
        self.severity = severity
        self.suggestedResolution = suggestedResolution
        self.canAutoResolve = canAutoResolve
    }
}

/// Types of validation issues
public enum ValidationIssueType: String, Sendable {
    case formatMismatch = "format_mismatch"
    case deviceLimitation = "device_limitation"
    case configurationError = "configuration_error"
    case systemLimitation = "system_limitation"
    case processingDetected = "processing_detected"
    case volumeScaling = "volume_scaling"
    case codecIssue = "codec_issue"
    case bufferMismatch = "buffer_mismatch"
    case clockDrift = "clock_drift"
    case noiseFloor = "noise_floor"
}

/// Validation warnings that don't prevent bit-perfect but may affect quality
public struct ValidationWarning: Sendable, Equatable {
    /// Warning description
    public let description: String
    
    /// Potential impact on audio quality
    public let qualityImpact: String
    
    /// Recommended action
    public let recommendation: String
    
    /// Warning category
    public let category: WarningCategory
    
    public init(description: String, qualityImpact: String, recommendation: String, category: WarningCategory) {
        self.description = description
        self.qualityImpact = qualityImpact
        self.recommendation = recommendation
        self.category = category
    }
}

/// Categories of validation warnings
public enum WarningCategory: String, Sendable {
    case performance = "performance"
    case compatibility = "compatibility"
    case configuration = "configuration"
    case optimization = "optimization"
}

/// Information about the device used for validation
public struct DeviceValidationInfo: Sendable, Equatable {
    /// Device identifier
    public let id: String
    
    /// Device display name
    public let name: String
    
    /// Device type
    public let type: AudioDeviceType
    
    /// Whether this is the default output device
    public let isDefault: Bool
    
    /// Device-specific capabilities
    public let capabilities: DeviceCapabilities
    
    /// Connection type (wired, wireless, etc.)
    public let connectionType: DeviceConnectionType
    
    public init(
        id: String,
        name: String,
        type: AudioDeviceType,
        isDefault: Bool,
        capabilities: DeviceCapabilities,
        connectionType: DeviceConnectionType
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isDefault = isDefault
        self.capabilities = capabilities
        self.connectionType = connectionType
    }
}

/// Device connection types
public enum DeviceConnectionType: String, Sendable {
    case wired = "wired"
    case bluetooth = "bluetooth"
    case airplay = "airplay"
    case usb = "usb"
    case thunderbolt = "thunderbolt"
    case lightning = "lightning"
    case `internal` = "internal"
    case unknown = "unknown"
    
    /// Whether this connection type typically supports bit-perfect audio
    public var supportsBitPerfect: Bool {
        switch self {
        case .wired, .usb, .thunderbolt, .lightning, .internal:
            return true
        case .bluetooth, .airplay:
            return false
        case .unknown:
            return false
        }
    }
}

/// Recommended settings for optimal bit-perfect playback
public struct BitPerfectSettings: Sendable, Equatable {
    /// Recommended sample rate
    public let sampleRate: Int
    
    /// Recommended bit depth
    public let bitDepth: Int
    
    /// Recommended buffer size
    public let bufferSize: Int
    
    /// Whether to enable exclusive mode (if available)
    public let useExclusiveMode: Bool
    
    /// Whether to bypass system volume control
    public let bypassSystemVolume: Bool
    
    /// Recommended audio session category
    public let sessionCategory: String
    
    /// Additional configuration options
    public let additionalSettings: [String: String]
    
    public init(
        sampleRate: Int = 44100,
        bitDepth: Int = 16,
        bufferSize: Int = 512,
        useExclusiveMode: Bool = false,
        bypassSystemVolume: Bool = false,
        sessionCategory: String = "playback",
        additionalSettings: [String: String] = [:]
    ) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.bufferSize = bufferSize
        self.useExclusiveMode = useExclusiveMode
        self.bypassSystemVolume = bypassSystemVolume
        self.sessionCategory = sessionCategory
        self.additionalSettings = additionalSettings
    }
    
    public static func == (lhs: BitPerfectSettings, rhs: BitPerfectSettings) -> Bool {
        return lhs.sampleRate == rhs.sampleRate &&
               lhs.bitDepth == rhs.bitDepth &&
               lhs.bufferSize == rhs.bufferSize &&
               lhs.useExclusiveMode == rhs.useExclusiveMode &&
               lhs.bypassSystemVolume == rhs.bypassSystemVolume &&
               lhs.sessionCategory == rhs.sessionCategory
    }
}

/// Performance impact assessment of bit-perfect configuration
// PerformanceImpact is defined in AudioEngineType.swift
public struct PerformanceMetrics: Sendable, Equatable {
    /// CPU usage impact (0.0 to 1.0)
    public let cpuImpact: Double
    
    /// Memory usage impact (0.0 to 1.0)
    public let memoryImpact: Double
    
    /// Battery life impact (0.0 to 1.0)
    public let batteryImpact: Double
    
    /// Expected latency in milliseconds
    public let latency: Double
    
    /// Overall performance rating
    public let rating: PerformanceRating
    
    public init(
        cpuImpact: Double = 0.1,
        memoryImpact: Double = 0.1,
        batteryImpact: Double = 0.1,
        latency: Double = 5.0,
        rating: PerformanceRating = .good
    ) {
        self.cpuImpact = cpuImpact
        self.memoryImpact = memoryImpact
        self.batteryImpact = batteryImpact
        self.latency = latency
        self.rating = rating
    }
}

// PerformanceRating is defined in PlaybackDiagnostics.swift 