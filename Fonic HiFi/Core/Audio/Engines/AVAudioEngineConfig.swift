//
//  AVAudioEngineConfig.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation
import AVFoundation

/// Configuration helper for AVAudioEngine setup and optimization
public struct AVAudioEngineConfig {
    
    // MARK: - Buffer Configuration
    
    /// Calculate optimal buffer size based on performance mode
    public static func optimalBufferSize(for mode: PerformanceMode) -> AVAudioFrameCount {
        switch mode {
        case .balanced:
            return 512   // Good balance of latency and performance
        case .quality:
            return 2048  // Larger buffer for stability
        case .efficiency:
            return 4096  // Maximum efficiency, higher latency
        }
    }
    
    // MARK: - Format Configuration
    
    /// Create optimal audio format for a given file and output
    public static func optimalFormat(
        for file: AVAudioFile,
        outputFormat: AVAudioFormat,
        configuration: AudioEngineConfiguration
    ) -> AVAudioFormat? {
        
        let fileFormat = file.processingFormat
        
        // If bit-perfect is enabled, try to match source format
        if configuration.enableBitPerfect {
            // Check if output supports the file's sample rate
            if outputFormat.sampleRate == fileFormat.sampleRate {
                return fileFormat
            }
        }
        
        // Otherwise, create a format that matches output device
        let channelLayout = fileFormat.channelLayout ?? AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!
        
        return AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: outputFormat.sampleRate,
            interleaved: false,
            channelLayout: channelLayout
        )
    }
    
    // MARK: - Channel Configuration
    
    /// Get appropriate channel layout for number of channels
    public static func channelLayout(for channelCount: Int) -> AVAudioChannelLayout {
        switch channelCount {
        case 1:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Mono)!
        case 2:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!
        case 6:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_MPEG_5_1_A)!
        case 8:
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_MPEG_7_1_A)!
        default:
            // Default to stereo for unsupported channel counts
            return AVAudioChannelLayout(layoutTag: kAudioChannelLayoutTag_Stereo)!
        }
    }
    
    // MARK: - Sample Rate Configuration
    
    /// Common sample rates supported by iOS devices
    public static let commonSampleRates: [Double] = [
        44100,   // CD quality
        48000,   // Professional audio
        88200,   // 2x CD quality
        96000,   // High-res
        176400,  // 4x CD quality
        192000   // Maximum high-res
    ]
    
    /// Find the nearest supported sample rate
    public static func nearestSupportedSampleRate(
        to targetRate: Double,
        availableRates: [Double] = commonSampleRates
    ) -> Double {
        
        // If exact match exists, use it
        if availableRates.contains(targetRate) {
            return targetRate
        }
        
        // Find nearest rate
        let nearest = availableRates.min(by: { abs($0 - targetRate) < abs($1 - targetRate) })
        return nearest ?? 48000
    }
    
    // MARK: - Converter Configuration
    
    /// Create sample rate converter settings
    public static func sampleRateConverterSettings(
        quality: PerformanceMode
    ) -> [String: Any] {
        
        let converterQuality: Int32
        
        switch quality {
        case .balanced:
            converterQuality = Int32(AVAudioQuality.medium.rawValue)
        case .quality:
            converterQuality = Int32(AVAudioQuality.max.rawValue)
        case .efficiency:
            converterQuality = Int32(AVAudioQuality.low.rawValue)
        }
        
        return [
            AVSampleRateConverterAudioQualityKey: converterQuality,
            AVSampleRateConverterAlgorithmKey: AVSampleRateConverterAlgorithm_Normal
        ]
    }
    
    // MARK: - Performance Tuning
    
    /// Get render quality settings based on performance mode
    public static func renderQuality(for mode: PerformanceMode) -> AVAudioQuality {
        switch mode {
        case .balanced:
            return .high
        case .quality:
            return .max
        case .efficiency:
            return .medium
        }
    }
    
    /// Calculate IO buffer duration for latency requirements
    public static func ioBufferDuration(for mode: PerformanceMode) -> TimeInterval {
        switch mode {
        case .balanced:
            return 0.005  // 5ms
        case .quality:
            return 0.010  // 10ms
        case .efficiency:
            return 0.023  // 23ms (one video frame at 44.1kHz)
        }
    }
    
    // MARK: - Format Validation
    
    /// Check if a format is natively supported by AVAudioEngine
    public static func isFormatNativelySupported(_ format: AudioFormat) -> Bool {
        switch format {
        case .mp3, .aac, .alac, .wav, .aiff:
            return true
        case .flac, .ape, .dsd:
            return false
        }
    }
    
    /// Check if sample rate conversion is needed
    public static func needsSampleRateConversion(
        sourceRate: Double,
        outputRate: Double,
        allowResampling: Bool
    ) -> Bool {
        
        if sourceRate == outputRate {
            return false
        }
        
        // If bit-perfect is required and rates don't match
        if !allowResampling {
            return true
        }
        
        // Check if it's an integer multiple (e.g., 44.1kHz to 88.2kHz)
        let ratio = max(sourceRate, outputRate) / min(sourceRate, outputRate)
        return ratio.truncatingRemainder(dividingBy: 1.0) != 0
    }
}