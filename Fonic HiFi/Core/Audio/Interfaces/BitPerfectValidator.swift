//
//  BitPerfectValidator.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Represents the status of bit-perfect playback validation
public struct BitPerfectStatus: Sendable {
    /// Whether bit-perfect playback is currently active
    public let isActive: Bool
    
    /// Source file sample rate in Hz
    public let sourceSampleRate: Int
    
    /// Output device sample rate in Hz
    public let outputSampleRate: Int
    
    /// Source file bit depth
    public let sourceBitDepth: Int
    
    /// Output device bit depth
    public let outputBitDepth: Int
    
    /// Indicates if any DSP processing is active
    public let hasProcessing: Bool
    
    /// Reason why bit-perfect is not active (if applicable)
    public let failureReason: BitPerfectFailureReason?
    
    /// Overall validation result
    public var isValid: Bool {
        return isActive && 
               sourceSampleRate == outputSampleRate &&
               sourceBitDepth == outputBitDepth &&
               !hasProcessing
    }
}

/// Reasons why bit-perfect playback cannot be achieved
public enum BitPerfectFailureReason: String, Sendable {
    case sampleRateMismatch = "Sample rate mismatch"
    case bitDepthMismatch = "Bit depth mismatch"
    case dspProcessingActive = "DSP processing is active"
    case deviceNotCapable = "Output device not capable"
    case formatNotSupported = "Format requires conversion"
    case volumeNotUnity = "Volume is not at 100%"
    case equalizerActive = "Equalizer is active"
}

/// Information about an audio output device
public struct AudioDevice: Sendable {
    public let id: String
    public let name: String
    public let supportedSampleRates: [Int]
    public let maxBitDepth: Int
    public let isDefault: Bool
    public let type: AudioDeviceType
}

/// Types of audio output devices
public enum AudioDeviceType: String, Sendable {
    case builtin = "builtin"
    case bluetooth = "bluetooth"
    case airplay = "airplay"
    case usb = "usb"
    case hdmi = "hdmi"
}

/// Protocol for validating bit-perfect playback conditions
@MainActor
public protocol BitPerfectValidator: Sendable {
    
    // MARK: - Validation
    
    /// Validate if bit-perfect playback is possible for given audio info
    /// - Parameter info: Audio file information
    /// - Returns: Bit-perfect validation status
    func validateBitPerfect(for info: AudioFileInfo) async -> BitPerfectStatus
    
    /// Check if a specific device can achieve bit-perfect playback
    /// - Parameters:
    ///   - device: Audio output device
    ///   - info: Audio file information
    /// - Returns: true if device can achieve bit-perfect
    func canAchieveBitPerfect(with device: AudioDevice, for info: AudioFileInfo) async -> Bool
    
    // MARK: - Device Management
    
    /// Get all available audio output devices
    /// - Returns: Array of available devices
    func getAvailableDevices() async -> [AudioDevice]
    
    /// Get the current audio output device
    /// - Returns: Currently selected device
    func getCurrentDevice() async -> AudioDevice?
    
    /// Select an audio output device
    /// - Parameter device: Device to select
    /// - Throws: AudioError if selection fails
    func selectDevice(_ device: AudioDevice) async throws
    
    // MARK: - Configuration
    
    /// Configure system for bit-perfect playback
    /// - Parameter info: Audio file information
    /// - Throws: AudioError if configuration fails
    func configureBitPerfect(for info: AudioFileInfo) async throws
    
    /// Reset audio configuration to defaults
    func resetConfiguration() async
}

/// Audio file information needed for bit-perfect validation
public struct AudioFileInfo: Sendable {
    public let format: AudioFormat
    public let sampleRate: Int
    public let bitDepth: Int
    public let channels: Int
    public let bitrate: Int?
    public let duration: TimeInterval
    public let fileSize: Int64
    
    /// Indicates if this is a high-resolution audio file
    public var isHighResolution: Bool {
        return (bitDepth > 16 || sampleRate > 48000) && format.isLossless
    }
}