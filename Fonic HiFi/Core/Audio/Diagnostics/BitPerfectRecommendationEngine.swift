//
//  BitPerfectRecommendationEngine.swift
//  Fonic HiFi
//
//  Created by Factory Droid on 10/6/25.
//

import AVFoundation
import Foundation

@MainActor
public protocol BitPerfectRecommendationGenerating {
    func recommendedSettings(sourceFormat: AudioFileInfo, deviceCapabilities: DeviceCapabilities) -> BitPerfectSettings
    func alternatives(sourceFormat: AudioFileInfo, deviceCapabilities: DeviceCapabilities) -> [AlternativeConfiguration]
    func conversionAnalysis(sourceFormat: AudioFileInfo, outputCapabilities: DeviceCapabilities) -> ConversionAnalysis
    func performanceImpact(processingStages: [AudioProcessingStage], sourceFormat: AudioFileInfo) -> PerformanceImpact
    func validationConfidence(
        deviceInfo: DeviceValidationInfo?,
        sessionAnalysis: AudioSessionAnalysis,
        hasKnownDAC: Bool,
    ) -> Double
    func expectedImprovementDescription(for changes: [ConfigurationChange]) -> String
}

@MainActor
public final class BitPerfectRecommendationEngine: BitPerfectRecommendationGenerating {
    public init() {}

    public func recommendedSettings(sourceFormat: AudioFileInfo, deviceCapabilities: DeviceCapabilities) -> BitPerfectSettings {
        let optimalSampleRate = deviceCapabilities.supportedSampleRates
            .filter { Double($0) >= sourceFormat.sampleRate }
            .map(Double.init)
            .min() ?? sourceFormat.sampleRate

        let optimalBitDepth = min(sourceFormat.bitDepth, UInt16(deviceCapabilities.maxBitDepth))
        let optimalBufferSize = deviceCapabilities.bufferSizeRange.lowerBound

        return BitPerfectSettings(
            sampleRate: Int(optimalSampleRate),
            bitDepth: Int(optimalBitDepth),
            bufferSize: Int(optimalBufferSize),
            useExclusiveMode: deviceCapabilities.supportsExclusiveMode,
            bypassSystemVolume: deviceCapabilities.bypassesSystemMixer,
            sessionCategory: AVAudioSession.Category.playback.rawValue,
        )
    }

    public func alternatives(sourceFormat: AudioFileInfo, deviceCapabilities: DeviceCapabilities) -> [AlternativeConfiguration] {
        var configurations: [AlternativeConfiguration] = []

        if let maxSampleRate = deviceCapabilities.supportedSampleRates.max() {
            configurations.append(AlternativeConfiguration(
                description: "Maximum device capability",
                outputFormat: AudioOutputFormat(
                    sampleRate: maxSampleRate,
                    bitDepth: deviceCapabilities.maxBitDepth,
                    channels: min(Int(sourceFormat.channels), Int(deviceCapabilities.maxChannels)),
                    isFloatingPoint: deviceCapabilities.maxBitDepth == 32,
                ),
                benefits: ["Highest quality possible on this device"],
                tradeoffs: sourceFormat.sampleRate > Double(maxSampleRate) ? ["Sample rate downsampling required"] : [],
            ))
        }

        configurations.append(AlternativeConfiguration(
            description: "CD Quality (44.1kHz/16-bit)",
            outputFormat: AudioOutputFormat(
                sampleRate: 44100,
                bitDepth: 16,
                channels: 2,
                isFloatingPoint: false,
            ),
            benefits: ["Universal compatibility", "Lower CPU usage", "Stable playback"],
            tradeoffs: sourceFormat.sampleRate > 44100 || sourceFormat.bitDepth > 16 ? ["Reduced resolution from source"] : [],
        ))

        return configurations
    }

    public func conversionAnalysis(
        sourceFormat: AudioFileInfo,
        outputCapabilities: DeviceCapabilities,
    ) -> ConversionAnalysis {
        var conversionTypes: [ConversionType] = []
        var qualityImpact: QualityImpact = .none
        var performanceImpactValue = 0.0

        if !outputCapabilities.supportedSampleRates.contains(Int(sourceFormat.sampleRate)) {
            conversionTypes.append(.sampleRate)
            qualityImpact = .moderate
            performanceImpactValue += 0.3
        }

        if sourceFormat.bitDepth > outputCapabilities.maxBitDepth {
            conversionTypes.append(.bitDepth)
            if qualityImpact == .none { qualityImpact = .minimal }
            performanceImpactValue += 0.1
        }

        if sourceFormat.channels > outputCapabilities.maxChannels {
            conversionTypes.append(.channelCount)
            if qualityImpact == .none { qualityImpact = .minimal }
            performanceImpactValue += 0.2
        }

        let alternatives = conversionAlternatives(
            sourceFormat: sourceFormat,
            outputCapabilities: outputCapabilities,
        )

        return ConversionAnalysis(
            conversionRequired: !conversionTypes.isEmpty,
            conversionTypes: conversionTypes,
            qualityImpact: qualityImpact,
            performanceImpact: performanceImpactValue,
            alternatives: alternatives,
        )
    }

    public func performanceImpact(
        processingStages: [AudioProcessingStage],
        sourceFormat: AudioFileInfo,
    ) -> PerformanceImpact {
        let totalProcessingImpact = processingStages.reduce(0.0) { $0 + $1.performanceImpact }
        let formatImpact = Double(sourceFormat.sampleRate) / 44100.0 * 0.1 +
            Double(sourceFormat.bitDepth) / 16.0 * 0.05
        let cpuImpact = min(1.0, totalProcessingImpact + formatImpact)

        if cpuImpact < 0.3 {
            return .low
        } else if cpuImpact < 0.6 {
            return .medium
        } else {
            return .high
        }
    }

    public func validationConfidence(
        deviceInfo: DeviceValidationInfo?,
        sessionAnalysis: AudioSessionAnalysis,
        hasKnownDAC: Bool,
    ) -> Double {
        var confidence = 0.8

        if hasKnownDAC {
            confidence += 0.1
        }

        if deviceInfo?.type == .unknown {
            confidence -= 0.2
        }

        if !sessionAnalysis.isOptimal {
            confidence -= 0.1
        }

        return max(0.1, min(1.0, confidence))
    }

    public func expectedImprovementDescription(for changes: [ConfigurationChange]) -> String {
        guard !changes.isEmpty else {
            return "Configuration is already optimal for bit-perfect playback"
        }

        let improvements = changes.map { change -> String in
            switch change.setting {
            case "Sample Rate":
                return "eliminate sample rate conversion"
            case "System Volume":
                return "remove digital volume scaling"
            default:
                return "optimize \(change.setting.lowercased())"
            }
        }

        return "Expected improvements: \(improvements.joined(separator: ", "))"
    }

    private func conversionAlternatives(
        sourceFormat: AudioFileInfo,
        outputCapabilities: DeviceCapabilities,
    ) -> [AlternativeConfiguration] {
        guard !outputCapabilities.supportedSampleRates.contains(Int(sourceFormat.sampleRate)) else { return [] }

        if let closestRate = outputCapabilities.supportedSampleRates.min(by: { lhs, rhs in
            abs(Double(lhs) - sourceFormat.sampleRate) < abs(Double(rhs) - sourceFormat.sampleRate)
        }) {
            return [
                AlternativeConfiguration(
                    description: "Closest supported sample rate (\(closestRate)Hz)",
                    outputFormat: AudioOutputFormat(
                        sampleRate: closestRate,
                        bitDepth: min(Int(sourceFormat.bitDepth), outputCapabilities.maxBitDepth),
                        channels: min(Int(sourceFormat.channels), Int(outputCapabilities.maxChannels)),
                        isFloatingPoint: outputCapabilities.maxBitDepth == 32,
                    ),
                    benefits: ["Minimal sample rate conversion", "Device native support"],
                    tradeoffs: ["Sample rate conversion required"],
                ),
            ]
        }

        return []
    }
}
