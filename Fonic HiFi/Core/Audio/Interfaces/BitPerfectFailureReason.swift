//
//  BitPerfectFailureReason.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import Foundation

/// Detailed reasons why bit-perfect playback validation failed
@frozen
public enum BitPerfectFailureReason: Sendable, Equatable, CaseIterable {
    
    // MARK: - Format Mismatches
    
    /// Source and output sample rates don't match
    case sampleRateMismatch(source: Double, output: Double)
    
    /// Source and output bit depths don't match
    case bitDepthMismatch(source: UInt16, output: UInt16)
    
    /// Source and output channel counts don't match
    case channelMismatch(source: UInt8, output: UInt8)
    
    /// Audio format is not supported in bit-perfect mode
    case unsupportedFormat(AudioFormat)
    
    // MARK: - Device Limitations
    
    /// Output device doesn't support bit-perfect playback
    case deviceNotBitPerfect(deviceName: String)
    
    /// Device doesn't support the required sample rate
    case deviceSampleRateNotSupported(required: Double, supported: [Double])
    
    /// Device doesn't support the required bit depth
    case deviceBitDepthNotSupported(required: UInt16, supported: [UInt16])
    
    /// Device doesn't support the required channel configuration
    case deviceChannelCountNotSupported(required: UInt8, maximum: UInt8)
    
    // MARK: - System Limitations
    
    /// System volume is not at unity gain (1.0)
    case volumeNotUnity(currentVolume: Float)
    
    /// Audio effects or processing are enabled
    case audioProcessingEnabled(effects: [String])
    
    /// System mixer is interfering with direct output
    case systemMixerActive
    
    /// Another app is using exclusive audio access
    case exclusiveAccessBlocked(blockingApp: String?)
    
    /// iOS audio session configuration prevents bit-perfect output
    case audioSessionRestriction(reason: String)
    
    // MARK: - Hardware Issues
    
    /// Hardware doesn't support direct audio output
    case hardwareNotSupported
    
    /// USB/Thunderbolt connection is not optimal
    case connectionNotOptimal(connectionType: String)
    
    /// Clock synchronization issues detected
    case clockSyncIssues
    
    /// Hardware buffer configuration prevents bit-perfect output
    case bufferConfigurationIssue(details: String)
    
    // MARK: - Computed Properties
    
    /// User-friendly description of the failure reason
    public var description: String {
        return userFriendlyDescription
    }
    
    /// User-friendly description of the failure reason
    public var userFriendlyDescription: String {
        switch self {
        case .sampleRateMismatch(let source, let output):
            return "Sample rate mismatch: source is \(formatSampleRate(source)), output is \(formatSampleRate(output))"
            
        case .bitDepthMismatch(let source, let output):
            return "Bit depth mismatch: source is \(source)-bit, output is \(output)-bit"
            
        case .channelMismatch(let source, let output):
            return "Channel mismatch: source has \(source) channels, output has \(output) channels"
            
        case .unsupportedFormat(let format):
            return "Format \(format.displayName) is not supported for bit-perfect playback"
            
        case .deviceNotBitPerfect(let deviceName):
            return "\(deviceName) does not support bit-perfect playback"
            
        case .deviceSampleRateNotSupported(let required, let supported):
            let supportedStr = supported.map(formatSampleRate).joined(separator: ", ")
            return "Device doesn't support \(formatSampleRate(required)). Supported: \(supportedStr)"
            
        case .deviceBitDepthNotSupported(let required, let supported):
            let supportedStr = supported.map { "\($0)-bit" }.joined(separator: ", ")
            return "Device doesn't support \(required)-bit. Supported: \(supportedStr)"
            
        case .deviceChannelCountNotSupported(let required, let maximum):
            return "Device doesn't support \(required) channels (maximum: \(maximum))"
            
        case .volumeNotUnity(let currentVolume):
            return "System volume must be at maximum for bit-perfect playback (currently \(Int(currentVolume * 100))%)"
            
        case .audioProcessingEnabled(let effects):
            return "Audio effects are enabled: \(effects.joined(separator: ", "))"
            
        case .systemMixerActive:
            return "System audio mixer is interfering with direct output"
            
        case .exclusiveAccessBlocked(let blockingApp):
            if let app = blockingApp {
                return "Another app (\(app)) has exclusive audio access"
            } else {
                return "Another app has exclusive audio access"
            }
            
        case .audioSessionRestriction(let reason):
            return "iOS audio session restriction: \(reason)"
            
        case .hardwareNotSupported:
            return "Hardware doesn't support bit-perfect audio output"
            
        case .connectionNotOptimal(let connectionType):
            return "\(connectionType) connection is not optimal for bit-perfect playback"
            
        case .clockSyncIssues:
            return "Audio clock synchronization issues detected"
            
        case .bufferConfigurationIssue(let details):
            return "Hardware buffer configuration issue: \(details)"
        }
    }
    
    /// Technical description for debugging
    public var technicalDescription: String {
        switch self {
        case .sampleRateMismatch(let source, let output):
            return "Sample rate mismatch: source=\(source)Hz, output=\(output)Hz"
            
        case .bitDepthMismatch(let source, let output):
            return "Bit depth mismatch: source=\(source)bit, output=\(output)bit"
            
        case .channelMismatch(let source, let output):
            return "Channel mismatch: source=\(source)ch, output=\(output)ch"
            
        case .unsupportedFormat(let format):
            return "Unsupported format: \(format.rawValue)"
            
        case .deviceNotBitPerfect(let deviceName):
            return "Device not bit-perfect capable: \(deviceName)"
            
        case .volumeNotUnity(let currentVolume):
            return "Volume not unity: \(currentVolume)"
            
        case .audioProcessingEnabled(let effects):
            return "Audio processing enabled: [\(effects.joined(separator: ","))]"
            
        default:
            return userFriendlyDescription
        }
    }
    
    /// Severity level of this failure
    public var severity: FailureSeverity {
        switch self {
        case .sampleRateMismatch, .bitDepthMismatch, .channelMismatch:
            return .critical
            
        case .unsupportedFormat, .deviceNotBitPerfect:
            return .critical
            
        case .volumeNotUnity:
            return .warning
            
        case .audioProcessingEnabled:
            return .moderate
            
        case .systemMixerActive, .exclusiveAccessBlocked:
            return .moderate
            
        case .hardwareNotSupported:
            return .critical
            
        case .connectionNotOptimal:
            return .warning
            
        case .clockSyncIssues, .bufferConfigurationIssue:
            return .moderate
            
        default:
            return .moderate
        }
    }
    
    /// Whether this issue can potentially be resolved automatically
    public var isAutoResolvable: Bool {
        switch self {
        case .volumeNotUnity:
            return true // Can adjust system volume
            
        case .audioProcessingEnabled:
            return true // Can disable effects
            
        case .systemMixerActive:
            return false // System-level limitation
            
        case .exclusiveAccessBlocked:
            return false // Requires user action
            
        case .audioSessionRestriction:
            return true // Can reconfigure session
            
        case .bufferConfigurationIssue:
            return true // Can adjust buffer settings
            
        default:
            return false
        }
    }
    
    /// Suggested resolution steps
    public var resolutionSteps: [String] {
        switch self {
        case .volumeNotUnity:
            return ["Set system volume to maximum", "Use app volume control instead"]
            
        case .audioProcessingEnabled(let effects):
            return ["Disable audio effects: \(effects.joined(separator: ", "))", "Check system sound settings"]
            
        case .deviceNotBitPerfect:
            return ["Use a DAC that supports bit-perfect playback", "Connect via USB instead of Bluetooth"]
            
        case .connectionNotOptimal:
            return ["Use USB connection instead of Bluetooth", "Ensure direct connection to device"]
            
        case .exclusiveAccessBlocked:
            return ["Close other audio apps", "Check for background audio processes"]
            
        case .systemMixerActive:
            return ["Enable exclusive audio mode", "Check iOS audio settings"]
            
        case .clockSyncIssues:
            return ["Restart audio session", "Check device clock settings"]
            
        default:
            return ["Check device compatibility", "Verify audio format support"]
        }
    }
    
    // MARK: - Helper Methods
    
    private func formatSampleRate(_ rate: Double) -> String {
        if rate >= 1000 {
            return String(format: "%.0f kHz", rate / 1000)
        } else {
            return String(format: "%.0f Hz", rate)
        }
    }
}

// MARK: - Supporting Types

/// Severity classification for bit-perfect validation failures
public enum FailureSeverity: Int, Sendable, CaseIterable {
    case warning = 1
    case moderate = 2
    case critical = 3
    
    public var description: String {
        switch self {
        case .warning:
            return "Warning"
        case .moderate:
            return "Moderate"
        case .critical:
            return "Critical"
        }
    }
    
    public var emoji: String {
        switch self {
        case .warning:
            return "⚠️"
        case .moderate:
            return "🔶"
        case .critical:
            return "🔴"
        }
    }
    
    public var color: String {
        switch self {
        case .warning:
            return "yellow"
        case .moderate:
            return "orange"
        case .critical:
            return "red"
        }
    }
}

// MARK: - Extensions

extension BitPerfectFailureReason {
    /// Create a failure reason for format compatibility issues
    public static func formatCompatibility(
        sourceFormat: AudioFileInfo,
        deviceCapabilities: AudioDevice
    ) -> BitPerfectFailureReason {
        
        if !deviceCapabilities.supports(sampleRate: sourceFormat.sampleRate) {
            return .deviceSampleRateNotSupported(
                required: sourceFormat.sampleRate,
                supported: deviceCapabilities.supportedSampleRates
            )
        }
        
        if !deviceCapabilities.supports(bitDepth: sourceFormat.bitDepth) {
            return .deviceBitDepthNotSupported(
                required: sourceFormat.bitDepth,
                supported: deviceCapabilities.supportedBitDepths
            )
        }
        
        if sourceFormat.channels > deviceCapabilities.maxChannels {
            return .deviceChannelCountNotSupported(
                required: sourceFormat.channels,
                maximum: deviceCapabilities.maxChannels
            )
        }
        
        if !deviceCapabilities.supportsBitPerfect {
            return .deviceNotBitPerfect(deviceName: deviceCapabilities.name)
        }
        
        // Default to unsupported format if no specific issue found
        return .unsupportedFormat(sourceFormat.format)
    }
    
    /// Group multiple failure reasons by severity
    public static func groupBySeverity(_ reasons: [BitPerfectFailureReason]) -> [FailureSeverity: [BitPerfectFailureReason]] {
        return Dictionary(grouping: reasons) { $0.severity }
    }
    
    /// Get the most critical failure from a list
    public static func mostCritical(from reasons: [BitPerfectFailureReason]) -> BitPerfectFailureReason? {
        return reasons.max { $0.severity.rawValue < $1.severity.rawValue }
    }
}

// MARK: - CaseIterable Conformance

extension BitPerfectFailureReason {
    public static var allCases: [BitPerfectFailureReason] {
        return [
            .sampleRateMismatch(source: 96000, output: 48000),
            .bitDepthMismatch(source: 24, output: 16),
            .channelMismatch(source: 2, output: 1),
            .unsupportedFormat(.mp3),
            .deviceNotBitPerfect(deviceName: "Built-in Speaker"),
            .deviceSampleRateNotSupported(required: 96000, supported: [44100, 48000]),
            .deviceBitDepthNotSupported(required: 24, supported: [16]),
            .deviceChannelCountNotSupported(required: 2, maximum: 1),
            .volumeNotUnity(currentVolume: 0.8),
            .audioProcessingEnabled(effects: ["EQ", "Reverb"]),
            .systemMixerActive,
            .exclusiveAccessBlocked(blockingApp: "Music"),
            .audioSessionRestriction(reason: "Background mode not enabled"),
            .hardwareNotSupported,
            .connectionNotOptimal(connectionType: "Bluetooth"),
            .clockSyncIssues,
            .bufferConfigurationIssue(details: "Buffer size too large")
        ]
    }
}