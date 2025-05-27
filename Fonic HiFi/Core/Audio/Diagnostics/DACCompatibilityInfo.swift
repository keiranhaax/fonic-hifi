//
//  DACCompatibilityInfo.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation

/// Compatibility information for external DACs and audio devices
public struct DACCompatibilityInfo: Sendable, Codable, Equatable {
    
    // MARK: - Device Identification
    
    /// Unique device identifier (vendor ID + product ID or similar)
    public let deviceIdentifier: String
    
    /// Manufacturer name
    public let manufacturer: String
    
    /// Device model name
    public let modelName: String
    
    /// Device firmware version (if available)
    public let firmwareVersion: String?
    
    /// Device connection interface
    public let connectionInterface: DACConnectionInterface
    
    // MARK: - Audio Capabilities
    
    /// Maximum supported sample rate in Hz
    public let maxSampleRate: Int
    
    /// Minimum supported sample rate in Hz
    public let minSampleRate: Int
    
    /// All supported sample rates
    public let supportedSampleRates: [Int]
    
    /// Maximum supported bit depth
    public let maxBitDepth: Int
    
    /// Supported bit depths
    public let supportedBitDepths: [Int]
    
    /// Maximum number of channels
    public let maxChannels: Int
    
    /// Supported channel configurations
    public let supportedChannelConfigurations: [ChannelConfiguration]
    
    // MARK: - Bit-Perfect Capabilities
    
    /// Whether device supports true bit-perfect playback
    public let supportsBitPerfect: Bool
    
    /// Whether device supports exclusive mode access
    public let supportsExclusiveMode: Bool
    
    /// Whether device bypasses system mixer
    public let bypassesSystemMixer: Bool
    
    /// Whether device supports hardware volume control
    public let supportsHardwareVolume: Bool
    
    /// Whether device supports native DSD playback
    public let supportsDSD: Bool
    
    /// Whether device supports MQA decoding
    public let supportsMQA: Bool
    
    // MARK: - Performance Characteristics
    
    /// Typical buffer size range supported
    public let bufferSizeRange: ClosedRange<Int>
    
    /// Measured audio latency in milliseconds
    public let measuredLatency: Double?
    
    /// Signal-to-noise ratio in dB
    public let signalToNoiseRatio: Double?
    
    /// Total harmonic distortion percentage
    public let totalHarmonicDistortion: Double?
    
    /// Dynamic range in dB
    public let dynamicRange: Double?
    
    // MARK: - Compatibility Notes
    
    /// Known compatibility issues with iOS/macOS
    public let knownIssues: [DACCompatibilityIssue]
    
    /// Recommended settings for optimal performance
    public let recommendedSettings: DACRecommendedSettings
    
    /// Special requirements or limitations
    public let specialRequirements: [String]
    
    /// User notes or experiences
    public let userNotes: [String]
    
    // MARK: - Metadata
    
    /// When this compatibility info was last updated
    public let lastUpdated: Date
    
    /// Data source (manual entry, crowd-sourced, manufacturer, etc.)
    public let dataSource: DACDataSource
    
    /// Confidence level in the data (0.0 to 1.0)
    public let confidenceLevel: Double
    
    /// Number of user reports that contributed to this data
    public let userReportCount: Int
    
    // MARK: - Initialization
    
    public init(
        deviceIdentifier: String,
        manufacturer: String,
        modelName: String,
        firmwareVersion: String? = nil,
        connectionInterface: DACConnectionInterface,
        maxSampleRate: Int,
        minSampleRate: Int = 44100,
        supportedSampleRates: [Int] = [44100, 48000, 96000, 192000],
        maxBitDepth: Int,
        supportedBitDepths: [Int] = [16, 24, 32],
        maxChannels: Int = 2,
        supportedChannelConfigurations: [ChannelConfiguration] = [.stereo],
        supportsBitPerfect: Bool = true,
        supportsExclusiveMode: Bool = false,
        bypassesSystemMixer: Bool = false,
        supportsHardwareVolume: Bool = true,
        supportsDSD: Bool = false,
        supportsMQA: Bool = false,
        bufferSizeRange: ClosedRange<Int> = 128...8192,
        measuredLatency: Double? = nil,
        signalToNoiseRatio: Double? = nil,
        totalHarmonicDistortion: Double? = nil,
        dynamicRange: Double? = nil,
        knownIssues: [DACCompatibilityIssue] = [],
        recommendedSettings: DACRecommendedSettings = DACRecommendedSettings(),
        specialRequirements: [String] = [],
        userNotes: [String] = [],
        lastUpdated: Date = Date(),
        dataSource: DACDataSource = .userReport,
        confidenceLevel: Double = 0.8,
        userReportCount: Int = 1
    ) {
        self.deviceIdentifier = deviceIdentifier
        self.manufacturer = manufacturer
        self.modelName = modelName
        self.firmwareVersion = firmwareVersion
        self.connectionInterface = connectionInterface
        self.maxSampleRate = maxSampleRate
        self.minSampleRate = minSampleRate
        self.supportedSampleRates = supportedSampleRates
        self.maxBitDepth = maxBitDepth
        self.supportedBitDepths = supportedBitDepths
        self.maxChannels = maxChannels
        self.supportedChannelConfigurations = supportedChannelConfigurations
        self.supportsBitPerfect = supportsBitPerfect
        self.supportsExclusiveMode = supportsExclusiveMode
        self.bypassesSystemMixer = bypassesSystemMixer
        self.supportsHardwareVolume = supportsHardwareVolume
        self.supportsDSD = supportsDSD
        self.supportsMQA = supportsMQA
        self.bufferSizeRange = bufferSizeRange
        self.measuredLatency = measuredLatency
        self.signalToNoiseRatio = signalToNoiseRatio
        self.totalHarmonicDistortion = totalHarmonicDistortion
        self.dynamicRange = dynamicRange
        self.knownIssues = knownIssues
        self.recommendedSettings = recommendedSettings
        self.specialRequirements = specialRequirements
        self.userNotes = userNotes
        self.lastUpdated = lastUpdated
        self.dataSource = dataSource
        self.confidenceLevel = confidenceLevel
        self.userReportCount = userReportCount
    }
    
    // MARK: - Computed Properties
    
    /// Display name combining manufacturer and model
    public var displayName: String {
        return "\(manufacturer) \(modelName)"
    }
    
    /// Whether this DAC is considered high-end/audiophile grade
    public var isAudiophileGrade: Bool {
        return maxBitDepth >= 24 && 
               maxSampleRate >= 192000 && 
               supportsBitPerfect &&
               (signalToNoiseRatio ?? 0) >= 120
    }
    
    /// Quality rating based on specifications
    public var qualityRating: DACQualityRating {
        var score = 0
        
        if maxBitDepth >= 32 { score += 2 }
        else if maxBitDepth >= 24 { score += 1 }
        
        if maxSampleRate >= 384000 { score += 3 }
        else if maxSampleRate >= 192000 { score += 2 }
        else if maxSampleRate >= 96000 { score += 1 }
        
        if supportsBitPerfect { score += 2 }
        if supportsExclusiveMode { score += 1 }
        if supportsDSD { score += 1 }
        if supportsMQA { score += 1 }
        
        if let snr = signalToNoiseRatio {
            if snr >= 130 { score += 2 }
            else if snr >= 120 { score += 1 }
        }
        
        switch score {
        case 0...3: return .basic
        case 4...6: return .good
        case 7...9: return .excellent
        case 10...12: return .reference
        default: return .reference
        }
    }
    
    /// Recommended sample rate for best performance
    public var recommendedSampleRate: Int {
        // Prefer 96kHz for high-end DACs that support it
        if supportedSampleRates.contains(96000) && maxSampleRate >= 96000 {
            return 96000
        }
        // Fall back to 48kHz for most DACs
        if supportedSampleRates.contains(48000) {
            return 48000
        }
        // Default to 44.1kHz
        return 44100
    }
    
    /// Recommended bit depth for best performance
    public var recommendedBitDepth: Int {
        // Prefer 24-bit for high-quality DACs
        if supportedBitDepths.contains(24) && maxBitDepth >= 24 {
            return 24
        }
        // Fall back to 16-bit
        return 16
    }
    
    // MARK: - Validation Methods
    
    /// Check if a specific format is supported
    public func supportsFormat(sampleRate: Int, bitDepth: Int, channels: Int) -> Bool {
        return supportedSampleRates.contains(sampleRate) &&
               supportedBitDepths.contains(bitDepth) &&
               channels <= maxChannels
    }
    
    /// Check if bit-perfect playback is possible for a format
    public func supportsBitPerfectPlayback(sampleRate: Int, bitDepth: Int, channels: Int) -> Bool {
        return supportsBitPerfect &&
               supportsFormat(sampleRate: sampleRate, bitDepth: bitDepth, channels: channels)
    }
    
    /// Get optimal buffer size for a given sample rate
    public func optimalBufferSize(for sampleRate: Int) -> Int {
        // Higher sample rates benefit from larger buffers
        let baseSize = bufferSizeRange.lowerBound
        let multiplier = sampleRate >= 192000 ? 4 : sampleRate >= 96000 ? 2 : 1
        return min(baseSize * multiplier, bufferSizeRange.upperBound)
    }
}

// MARK: - Supporting Types

/// DAC connection interfaces
public enum DACConnectionInterface: String, Sendable, Codable {
    case usb = "usb"
    case thunderbolt = "thunderbolt"
    case lightning = "lightning"
    case headphoneJack = "headphone_jack"
    case optical = "optical"
    case coaxial = "coaxial"
    case ethernet = "ethernet"
    case wireless = "wireless"
    case internal = "internal"
    case unknown = "unknown"
    
    /// Whether this interface typically supports bit-perfect audio
    public var supportsBitPerfect: Bool {
        switch self {
        case .usb, .thunderbolt, .lightning, .optical, .coaxial, .ethernet:
            return true
        case .headphoneJack, .internal:
            return false
        case .wireless, .unknown:
            return false
        }
    }
}

/// Channel configuration options
public enum ChannelConfiguration: String, Sendable, Codable {
    case mono = "mono"
    case stereo = "stereo"
    case surround5_1 = "surround_5_1"
    case surround7_1 = "surround_7_1"
    case quadraphonic = "quadraphonic"
    case multichannel = "multichannel"
    
    /// Number of channels for this configuration
    public var channelCount: Int {
        switch self {
        case .mono: return 1
        case .stereo: return 2
        case .quadraphonic: return 4
        case .surround5_1: return 6
        case .surround7_1: return 8
        case .multichannel: return 16 // Arbitrary high number
        }
    }
}

/// Known compatibility issues with specific DACs
public struct DACCompatibilityIssue: Sendable, Codable, Equatable {
    /// Description of the issue
    public let description: String
    
    /// Affected iOS/macOS versions
    public let affectedVersions: [String]
    
    /// Severity of the issue
    public let severity: IssueSeverity
    
    /// Known workarounds
    public let workarounds: [String]
    
    /// Whether the issue is resolved in latest firmware/software
    public let isResolved: Bool
    
    public init(
        description: String,
        affectedVersions: [String] = [],
        severity: IssueSeverity,
        workarounds: [String] = [],
        isResolved: Bool = false
    ) {
        self.description = description
        self.affectedVersions = affectedVersions
        self.severity = severity
        self.workarounds = workarounds
        self.isResolved = isResolved
    }
}

/// Severity levels for compatibility issues
public enum IssueSeverity: String, Sendable, Codable {
    case minor = "minor"
    case moderate = "moderate"
    case major = "major"
    case critical = "critical"
}

/// Recommended settings for optimal DAC performance
public struct DACRecommendedSettings: Sendable, Codable, Equatable {
    /// Recommended sample rate
    public let sampleRate: Int
    
    /// Recommended bit depth
    public let bitDepth: Int
    
    /// Recommended buffer size
    public let bufferSize: Int
    
    /// Whether to use exclusive mode (if available)
    public let useExclusiveMode: Bool
    
    /// Whether to enable hardware volume control
    public let useHardwareVolume: Bool
    
    /// Additional driver-specific settings
    public let driverSettings: [String: String]
    
    /// Performance optimization tips
    public let optimizationTips: [String]
    
    public init(
        sampleRate: Int = 96000,
        bitDepth: Int = 24,
        bufferSize: Int = 512,
        useExclusiveMode: Bool = false,
        useHardwareVolume: Bool = true,
        driverSettings: [String: String] = [:],
        optimizationTips: [String] = []
    ) {
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.bufferSize = bufferSize
        self.useExclusiveMode = useExclusiveMode
        self.useHardwareVolume = useHardwareVolume
        self.driverSettings = driverSettings
        self.optimizationTips = optimizationTips
    }
}

/// Data source for DAC compatibility information
public enum DACDataSource: String, Sendable, Codable {
    case manufacturer = "manufacturer"
    case userReport = "user_report"
    case crowdSourced = "crowd_sourced"
    case testing = "testing"
    case specification = "specification"
    case review = "review"
    case unknown = "unknown"
    
    /// Reliability score for this data source (0.0 to 1.0)
    public var reliabilityScore: Double {
        switch self {
        case .manufacturer, .specification:
            return 0.9
        case .testing, .review:
            return 0.8
        case .crowdSourced:
            return 0.7
        case .userReport:
            return 0.6
        case .unknown:
            return 0.3
        }
    }
}

/// Quality rating for DACs
public enum DACQualityRating: String, Sendable, Codable {
    case basic = "basic"
    case good = "good"
    case excellent = "excellent"
    case reference = "reference"
    
    /// Display name for the quality rating
    public var displayName: String {
        switch self {
        case .basic: return "Basic"
        case .good: return "Good"
        case .excellent: return "Excellent"
        case .reference: return "Reference"
        }
    }
    
    /// Description of what this rating means
    public var description: String {
        switch self {
        case .basic:
            return "Entry-level DAC with basic functionality"
        case .good:
            return "Good quality DAC suitable for most users"
        case .excellent:
            return "High-quality DAC with excellent performance"
        case .reference:
            return "Reference-grade DAC for audiophiles"
        }
    }
}

// MARK: - Factory Methods

extension DACCompatibilityInfo {
    
    /// Create compatibility info for Apple's built-in audio
    public static func appleBuiltIn() -> DACCompatibilityInfo {
        return DACCompatibilityInfo(
            deviceIdentifier: "apple_builtin",
            manufacturer: "Apple",
            modelName: "Built-in Audio",
            connectionInterface: .internal,
            maxSampleRate: 48000,
            minSampleRate: 44100,
            supportedSampleRates: [44100, 48000],
            maxBitDepth: 16,
            supportedBitDepths: [16],
            maxChannels: 2,
            supportedChannelConfigurations: [.stereo],
            supportsBitPerfect: false,
            supportsExclusiveMode: false,
            bypassesSystemMixer: false,
            supportsHardwareVolume: true,
            supportsDSD: false,
            supportsMQA: false,
            bufferSizeRange: 256...2048,
            dataSource: .specification,
            confidenceLevel: 1.0
        )
    }
    
    /// Create compatibility info for common USB DACs
    public static func genericUSBDAC() -> DACCompatibilityInfo {
        return DACCompatibilityInfo(
            deviceIdentifier: "generic_usb_dac",
            manufacturer: "Generic",
            modelName: "USB DAC",
            connectionInterface: .usb,
            maxSampleRate: 192000,
            minSampleRate: 44100,
            supportedSampleRates: [44100, 48000, 96000, 192000],
            maxBitDepth: 24,
            supportedBitDepths: [16, 24],
            maxChannels: 2,
            supportedChannelConfigurations: [.stereo],
            supportsBitPerfect: true,
            supportsExclusiveMode: false,
            bypassesSystemMixer: false,
            supportsHardwareVolume: true,
            supportsDSD: false,
            supportsMQA: false,
            bufferSizeRange: 128...4096,
            dataSource: .specification,
            confidenceLevel: 0.7
        )
    }
} 