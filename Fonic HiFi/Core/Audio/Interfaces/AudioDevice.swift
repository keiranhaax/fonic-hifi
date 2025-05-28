//
//  AudioDevice.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/2025.
//

import Foundation
import AVFoundation

/// Represents an audio input or output device with its capabilities
@frozen
public struct AudioDevice: Sendable, Equatable, Hashable, Codable, Identifiable {
    
    // MARK: - Core Properties
    
    /// Unique device identifier
    public let id: String
    
    /// Human-readable device name
    public let name: String
    
    /// Device type classification
    public let type: AudioDeviceType
    
    /// Whether this is an output device (true) or input device (false)
    public let isOutput: Bool
    
    /// Whether the device is currently available and connected
    public let isAvailable: Bool
    
    /// Device connection type
    public let connectionType: AudioConnectionType
    
    // MARK: - Audio Capabilities
    
    /// Supported sample rates in Hz
    public let supportedSampleRates: [Double]
    
    /// Supported bit depths
    public let supportedBitDepths: [UInt16]
    
    /// Maximum number of channels supported
    public let maxChannels: UInt8
    
    /// Whether the device supports bit-perfect playback
    public let supportsBitPerfect: Bool
    
    /// Minimum buffer size in frames
    public let minBufferSize: UInt32
    
    /// Maximum buffer size in frames
    public let maxBufferSize: UInt32
    
    /// Preferred buffer size in frames
    public let preferredBufferSize: UInt32
    
    // MARK: - Device Information
    
    /// Device manufacturer name
    public let manufacturer: String?
    
    /// Device model identifier
    public let model: String?
    
    /// Device transport type (USB, Bluetooth, etc.)
    public let transport: String?
    
    /// Hardware latency in seconds
    public let hardwareLatency: TimeInterval
    
    /// Whether the device is the system default
    public let isDefault: Bool
    
    /// Device quality rating
    public let qualityRating: DeviceQuality
    
    // MARK: - Computed Properties
    
    /// Best supported sample rate for high-quality playback
    public var bestSampleRate: Double {
        supportedSampleRates.max() ?? 44100
    }
    
    /// Best supported bit depth
    public var bestBitDepth: UInt16 {
        supportedBitDepths.max() ?? 16
    }
    
    /// Whether this device supports high-resolution audio
    public var supportsHighResolution: Bool {
        bestSampleRate > 48000 || bestBitDepth > 16
    }
    
    /// Whether this device is suitable for audiophile use
    public var isAudiophileGrade: Bool {
        supportsBitPerfect && 
        supportsHighResolution && 
        qualityRating.rawValue >= DeviceQuality.good.rawValue
    }
    
    /// Device capability summary string
    public var capabilityString: String {
        let maxRate = bestSampleRate >= 1000 ? "\(Int(bestSampleRate / 1000))kHz" : "\(Int(bestSampleRate))Hz"
        return "\(maxRate)/\(bestBitDepth)-bit"
    }
    
    /// Short display name (truncated if too long)
    public var displayName: String {
        if name.count > 25 {
            return String(name.prefix(22)) + "..."
        }
        return name
    }
    
    // MARK: - Initialization
    
    public init(
        id: String,
        name: String,
        type: AudioDeviceType = .unknown,
        isOutput: Bool,
        isAvailable: Bool = true,
        connectionType: AudioConnectionType = .unknown,
        supportedSampleRates: [Double] = [44100, 48000],
        supportedBitDepths: [UInt16] = [16],
        maxChannels: UInt8 = 2,
        supportsBitPerfect: Bool = false,
        minBufferSize: UInt32 = 64,
        maxBufferSize: UInt32 = 4096,
        preferredBufferSize: UInt32 = 512,
        manufacturer: String? = nil,
        model: String? = nil,
        transport: String? = nil,
        hardwareLatency: TimeInterval = 0.001,
        isDefault: Bool = false,
        qualityRating: DeviceQuality = .standard
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.isOutput = isOutput
        self.isAvailable = isAvailable
        self.connectionType = connectionType
        self.supportedSampleRates = supportedSampleRates.sorted()
        self.supportedBitDepths = supportedBitDepths.sorted()
        self.maxChannels = maxChannels
        self.supportsBitPerfect = supportsBitPerfect
        self.minBufferSize = minBufferSize
        self.maxBufferSize = maxBufferSize
        self.preferredBufferSize = preferredBufferSize
        self.manufacturer = manufacturer
        self.model = model
        self.transport = transport
        self.hardwareLatency = hardwareLatency
        self.isDefault = isDefault
        self.qualityRating = qualityRating
    }
    
    // MARK: - Factory Methods
    
    /// Create a device representing built-in speakers
    public static func builtInSpeaker() -> AudioDevice {
        return AudioDevice(
            id: "built-in-speaker",
            name: "Built-in Speaker",
            type: .builtIn,
            isOutput: true,
            connectionType: .builtin,
            supportedSampleRates: [44100, 48000],
            supportedBitDepths: [16],
            maxChannels: 2,
            supportsBitPerfect: false,
            isDefault: true,
            qualityRating: .basic
        )
    }
    
    /// Create a device representing built-in microphone
    public static func builtInMicrophone() -> AudioDevice {
        return AudioDevice(
            id: "built-in-microphone",
            name: "Built-in Microphone",
            type: .builtIn,
            isOutput: false,
            connectionType: .builtin,
            supportedSampleRates: [44100, 48000],
            supportedBitDepths: [16],
            maxChannels: 1,
            supportsBitPerfect: false,
            isDefault: true,
            qualityRating: .basic
        )
    }
    
    /// Create a device representing wired headphones
    public static func wiredHeadphones() -> AudioDevice {
        return AudioDevice(
            id: "wired-headphones",
            name: "Wired Headphones",
            type: .headphones,
            isOutput: true,
            connectionType: .headphoneJack,
            supportedSampleRates: [44100, 48000],
            supportedBitDepths: [16],
            maxChannels: 2,
            supportsBitPerfect: true,
            qualityRating: .standard
        )
    }
    
    /// Create a generic Bluetooth audio device
    public static func bluetoothAudio(name: String) -> AudioDevice {
        return AudioDevice(
            id: "bluetooth-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            name: name,
            type: .bluetooth,
            isOutput: true,
            connectionType: .bluetooth,
            supportedSampleRates: [44100],
            supportedBitDepths: [16],
            maxChannels: 2,
            supportsBitPerfect: false,
            qualityRating: .standard
        )
    }
    
    /// Create a high-end USB DAC device
    public static func usbDAC(name: String, manufacturer: String? = nil) -> AudioDevice {
        return AudioDevice(
            id: "usb-dac-\(name.lowercased().replacingOccurrences(of: " ", with: "-"))",
            name: name,
            type: .usbDAC,
            isOutput: true,
            connectionType: .usb,
            supportedSampleRates: [44100, 48000, 88200, 96000, 176400, 192000],
            supportedBitDepths: [16, 24, 32],
            maxChannels: 2,
            supportsBitPerfect: true,
            manufacturer: manufacturer,
            hardwareLatency: 0.0005,
            qualityRating: .excellent
        )
    }
    
    // MARK: - Capability Checking
    
    /// Check if the device supports a specific sample rate
    public func supports(sampleRate: Double) -> Bool {
        supportedSampleRates.contains(sampleRate)
    }
    
    /// Check if the device supports a specific bit depth
    public func supports(bitDepth: UInt16) -> Bool {
        supportedBitDepths.contains(bitDepth)
    }
    
    /// Check if the device can handle a specific audio format
    public func supports(format: AudioFileInfo) -> Bool {
        return supports(sampleRate: format.sampleRate) &&
               supports(bitDepth: format.bitDepth) &&
               format.channels <= maxChannels
    }
    
    /// Get the optimal buffer size for the given sample rate
    public func optimalBufferSize(for sampleRate: Double) -> UInt32 {
        // Prefer lower latency for higher sample rates
        let latencyMs = sampleRate > 96000 ? 5.0 : 10.0
        let framesNeeded = UInt32(sampleRate * latencyMs / 1000.0)
        return max(minBufferSize, min(maxBufferSize, framesNeeded))
    }
}

// MARK: - Supporting Enums

/// Classification of audio device types
public enum AudioDeviceType: String, Sendable, CaseIterable, Codable {
    case builtIn = "Built-in"
    case builtin = "Builtin"
    case headphones = "Headphones"
    case speakers = "Speakers"
    case usbDAC = "USB DAC"
    case usb = "USB"
    case bluetooth = "Bluetooth"
    case airPlay = "AirPlay"
    case airplay = "Airplay"
    case thunderbolt = "Thunderbolt"
    case hdmi = "HDMI"
    case unknown = "Unknown"
    
    public var description: String {
        return rawValue
    }
    
    /// Display name for UI
    public var displayName: String {
        return rawValue
    }
    
    /// Whether this device type typically supports high-quality audio
    public var supportsHighQuality: Bool {
        switch self {
        case .usbDAC, .usb, .thunderbolt, .hdmi:
            return true
        case .headphones, .speakers:
            return true
        case .builtIn, .builtin, .bluetooth, .airPlay, .airplay:
            return false
        case .unknown:
            return false
        }
    }
}

/// Audio connection types
public enum AudioConnectionType: String, Sendable, CaseIterable, Codable {
    case builtin = "Built-in"
    case headphoneJack = "Headphone Jack"
    case usb = "USB"
    case bluetooth = "Bluetooth"
    case airPlay = "AirPlay"
    case thunderbolt = "Thunderbolt"
    case lightning = "Lightning"
    case unknown = "Unknown"
    
    public var description: String {
        return rawValue
    }
    
    /// Typical latency characteristics for this connection type
    public var typicalLatency: TimeInterval {
        switch self {
        case .builtin, .headphoneJack:
            return 0.001
        case .usb, .thunderbolt, .lightning:
            return 0.0005
        case .bluetooth:
            return 0.040
        case .airPlay:
            return 0.100
        case .unknown:
            return 0.010
        }
    }
}

/// Device quality classification
public enum DeviceQuality: Int, Sendable, CaseIterable, Codable {
    case basic = 1
    case standard = 2
    case good = 3
    case excellent = 4
    case reference = 5
    
    public var description: String {
        switch self {
        case .basic:
            return "Basic"
        case .standard:
            return "Standard"
        case .good:
            return "Good"
        case .excellent:
            return "Excellent"
        case .reference:
            return "Reference"
        }
    }
    
    public var emoji: String {
        switch self {
        case .basic:
            return "🔉"
        case .standard:
            return "🔊"
        case .good:
            return "🎵"
        case .excellent:
            return "🎼"
        case .reference:
            return "🏆"
        }
    }
}

// MARK: - Extensions

extension AudioDevice {
    /// Create a device from an AVAudioSessionPortDescription
    public static func from(port: AVAudioSessionPortDescription) -> AudioDevice {
        let connectionType: AudioConnectionType
        let deviceType: AudioDeviceType
        let qualityRating: DeviceQuality
        
        switch port.portType {
        case .builtInSpeaker:
            connectionType = .builtin
            deviceType = .builtIn
            qualityRating = .basic
        case .headphones:
            connectionType = .headphoneJack
            deviceType = .headphones
            qualityRating = .standard
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            connectionType = .bluetooth
            deviceType = .bluetooth
            qualityRating = .standard
        case .usbAudio:
            connectionType = .usb
            deviceType = .usbDAC
            qualityRating = .excellent
        case .airPlay:
            connectionType = .airPlay
            deviceType = .airPlay
            qualityRating = .good
        default:
            connectionType = .unknown
            deviceType = .unknown
            qualityRating = .standard
        }
        
        return AudioDevice(
            id: port.uid,
            name: port.portName,
            type: deviceType,
            isOutput: true, // AVAudioSessionPortDescription is typically for outputs
            connectionType: connectionType,
            supportedSampleRates: [44100, 48000], // Conservative defaults
            supportedBitDepths: [16],
            maxChannels: UInt8(port.channels?.count ?? 2),
            supportsBitPerfect: connectionType == .usb || connectionType == .headphoneJack,
            qualityRating: qualityRating
        )
    }
    
    /// Get a user-friendly description including capabilities
    public var fullDescription: String {
        var components = [name]
        
        if let manufacturer = manufacturer {
            components.append("by \(manufacturer)")
        }
        
        components.append("(\(capabilityString))")
        
        if supportsBitPerfect {
            components.append("Bit-Perfect")
        }
        
        return components.joined(separator: " ")
    }
}