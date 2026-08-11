import AVFoundation
import Foundation

@MainActor
final class BitPerfectValidationEngine {
    private let deviceManager: any BitPerfectDeviceManaging
    private let processingAnalyzer: any BitPerfectProcessingAnalyzing
    private let recommendationEngine: any BitPerfectRecommendationGenerating

    init(
        deviceManager: any BitPerfectDeviceManaging,
        processingAnalyzer: any BitPerfectProcessingAnalyzing,
        recommendationEngine: any BitPerfectRecommendationGenerating
    ) {
        self.deviceManager = deviceManager
        self.processingAnalyzer = processingAnalyzer
        self.recommendationEngine = recommendationEngine
    }

    func validate(
        session: AVAudioSession,
        sourceFormat: AudioFileInfo,
        context: BitPerfectEligibilityContext
    ) async -> BitPerfectValidationResult {
        var validationIssues: [ValidationIssue] = []
        let warnings: [ValidationWarning] = []
        var processingStages: [AudioProcessingStage] = []

        // Post-load engine evidence supersedes session-only inference: once a
        // track is loaded, the engine's measured output format is the actual
        // output under validation.
        let measuredEngineOutput = context.engineEvidence.flatMap { $0.isTrackLoaded ? $0 : nil }
        let engineProcessingActive = context.engineEvidence?.hasEngineProcessing ?? false

        let deviceCapabilities = await deviceManager.currentCapabilities(using: session)
        let deviceInfo = await deviceManager.currentDeviceInfo(using: session)
        let sessionAnalysis = analyzeSession(session)
        let processingDetection = await processingAnalyzer.detectProcessing(in: session)

        if processingDetection.hasProcessing {
            processingStages.append(contentsOf: processingDetection.stages)
            validationIssues.append(
                ValidationIssue(
                    type: .processingDetected,
                    description: "Audio processing detected in signal path",
                    technicalDetails: "Active processing: \(processingDetection.stages.map(\.description).joined(separator: ", "))",
                    severity: .warning,
                    suggestedResolution: "Disable audio processing features",
                    canAutoResolve: true
                )
            )
        }

        if context.hasDSP {
            let stageDescription = [
                context.equalizerEnabled ? "equalizer" : nil,
                context.replayGainEnabled ? "Replay Gain" : nil,
                context.playbackRate != 1 ? "playback-rate conversion" : nil,
                context.crossfadeEnabled ? "crossfade" : nil
            ].compactMap { $0 }.joined(separator: ", ")
            processingStages.append(
                AudioProcessingStage(
                    type: context.equalizerEnabled ? .equalization : .dynamicsProcessing,
                    description: "Application DSP active: \(stageDescription)",
                    affectsBitPerfect: true,
                    performanceImpact: 0.2
                )
            )
            validationIssues.append(
                ValidationIssue(
                    type: .processingDetected,
                    description: "Application audio processing is enabled",
                    technicalDetails: stageDescription,
                    severity: .warning,
                    suggestedResolution: "Disable EQ, Replay Gain, crossfade, and playback-rate conversion",
                    canAutoResolve: true
                )
            )
        }

        if engineProcessingActive {
            processingStages.append(
                AudioProcessingStage(
                    type: .dynamicsProcessing,
                    description: "Engine graph processing active",
                    affectsBitPerfect: true,
                    performanceImpact: 0.2
                )
            )
            validationIssues.append(
                ValidationIssue(
                    type: .processingDetected,
                    description: "Engine-side audio processing is active",
                    technicalDetails: "The active engine reports a processing stage in its graph",
                    severity: .warning,
                    suggestedResolution: "Disable playback-rate, EQ, and gain stages",
                    canAutoResolve: true
                )
            )
        }

        let actualSampleRate = (measuredEngineOutput?.engineOutputSampleRate).map(Int.init)
            ?? Int(session.sampleRate)
        let targetSampleRate = Int(sourceFormat.sampleRate)
        let sampleRateMatches = actualSampleRate == targetSampleRate

        if !sampleRateMatches {
            validationIssues.append(
                ValidationIssue(
                    type: .formatMismatch,
                    description: "Sample rate mismatch: source \(sourceFormat.sampleRate)Hz vs output \(actualSampleRate)Hz",
                    technicalDetails: "Sample rate conversion will be applied, preventing bit-perfect playback",
                    severity: .error,
                    suggestedResolution: "Configure output device to match source sample rate",
                    canAutoResolve: true
                )
            )

            processingStages.append(
                AudioProcessingStage(
                    type: .sampleRateConversion,
                    description: "Sample rate conversion from \(sourceFormat.sampleRate)Hz to \(actualSampleRate)Hz",
                    affectsBitPerfect: true,
                    performanceImpact: 0.3
                )
            )
        }

        let estimatedBitDepth = deviceManager.estimateOutputBitDepth(for: session, capabilities: deviceCapabilities)
        let bitDepthMatches = sourceFormat.bitDepth <= estimatedBitDepth

        if !bitDepthMatches {
            validationIssues.append(
                ValidationIssue(
                    type: .formatMismatch,
                    description: "Bit depth limitation: source \(sourceFormat.bitDepth)-bit vs output \(estimatedBitDepth)-bit",
                    technicalDetails: "Bit depth conversion or truncation may occur",
                    severity: .warning,
                    suggestedResolution: "Use a DAC that supports \(sourceFormat.bitDepth)-bit audio",
                    canAutoResolve: false
                )
            )
        }

        let routeChannels = session.currentRoute.outputs.first?.channels?.count ?? 2
        let sessionChannels = session.outputNumberOfChannels > 0
            ? Int(session.outputNumberOfChannels)
            : routeChannels
        let actualChannels = measuredEngineOutput?.engineOutputChannelCount ?? sessionChannels
        let sourceChannels = Int(sourceFormat.channels)
        let channelCountMatches = sourceChannels == actualChannels

        if !channelCountMatches {
            validationIssues.append(
                ValidationIssue(
                    type: .formatMismatch,
                    description: "Channel mismatch: source \(sourceChannels) vs output \(actualChannels)",
                    technicalDetails: "Channel mixing will be applied, preventing bit-perfect playback",
                    severity: .error,
                    suggestedResolution: "Use a source and output path with matching channel counts",
                    canAutoResolve: false
                )
            )

            processingStages.append(
                AudioProcessingStage(
                    type: .channelMixing,
                    description: "Channel mixing from \(sourceChannels) to \(actualChannels) channels",
                    affectsBitPerfect: true,
                    performanceImpact: 0.1
                )
            )
        }

        let systemVolume = session.outputVolume
        let volumeIsOptimal = systemVolume == 1.0
        let applicationVolumeIsOptimal = context.applicationVolume == 1.0

        if !volumeIsOptimal {
            validationIssues.append(
                ValidationIssue(
                    type: .volumeScaling,
                    description: "System volume is not at 100%",
                    technicalDetails: "Current volume: \(Int(systemVolume * 100))%",
                    severity: .warning,
                    suggestedResolution: "Set system volume to 100%",
                    canAutoResolve: true
                )
            )

            processingStages.append(
                AudioProcessingStage(
                    type: .volumeControl,
                    description: "Digital volume scaling at \(Int(systemVolume * 100))%",
                    affectsBitPerfect: true,
                    performanceImpact: 0.1
                )
            )
        }

        if !applicationVolumeIsOptimal {
            validationIssues.append(
                ValidationIssue(
                    type: .volumeScaling,
                    description: "Application volume is not at 100%",
                    technicalDetails: "Current application volume: \(Int(context.applicationVolume * 100))%",
                    severity: .warning,
                    suggestedResolution: "Set application volume to 100%",
                    canAutoResolve: true
                )
            )
        }

        let deviceSupportsFormat = deviceCapabilities.supportedSampleRates.contains(Int(sourceFormat.sampleRate)) &&
            sourceFormat.bitDepth <= deviceCapabilities.maxBitDepth &&
            sourceChannels <= deviceCapabilities.maxChannels

        if !deviceSupportsFormat {
            validationIssues.append(
                ValidationIssue(
                    type: .deviceLimitation,
                    description: "Output device doesn't natively support the source format",
                    technicalDetails: "Device max: \(deviceCapabilities.maxBitDepth)-bit, \(deviceCapabilities.supportedSampleRates.max() ?? 0)Hz",
                    severity: .error,
                    suggestedResolution: "Use a DAC that supports the source format natively",
                    canAutoResolve: false
                )
            )
        }

        let mismatchReason: BitPerfectMismatchReason? = {
            if !sampleRateMatches { return .sampleRateMismatch }
            if !bitDepthMatches { return .bitDepthMismatch }
            if !channelCountMatches { return .channelCountMismatch }
            if !deviceSupportsFormat { return .deviceNotCapable }
            if !volumeIsOptimal { return .systemVolumeNotUnity }
            if !applicationVolumeIsOptimal { return .applicationVolumeNotUnity }
            if processingDetection.hasProcessing || context.hasDSP || engineProcessingActive {
                return .audioProcessingActive
            }
            return nil
        }()

        let isValid = sampleRateMatches &&
            bitDepthMatches &&
            channelCountMatches &&
            deviceSupportsFormat &&
            volumeIsOptimal &&
            applicationVolumeIsOptimal &&
            !processingDetection.hasProcessing &&
            !context.hasDSP &&
            !engineProcessingActive

        let recommendedSettings = recommendationEngine.recommendedSettings(
            sourceFormat: sourceFormat,
            deviceCapabilities: deviceCapabilities
        )
        let alternatives = recommendationEngine.alternatives(
            sourceFormat: sourceFormat,
            deviceCapabilities: deviceCapabilities
        )
        let performanceImpact = recommendationEngine.performanceImpact(
            processingStages: processingStages,
            sourceFormat: sourceFormat
        )

        let hasKnownDAC = if let deviceInfo {
            await deviceManager.dacCompatibility(for: deviceInfo.id) != nil
        } else {
            false
        }

        let confidence = recommendationEngine.validationConfidence(
            deviceInfo: deviceInfo,
            sessionAnalysis: sessionAnalysis,
            hasKnownDAC: hasKnownDAC
        )

        var measurementEvidence: Set<BitPerfectMeasurementEvidence> = [.sourceFormat]
        if measuredEngineOutput?.engineOutputSampleRate != nil {
            measurementEvidence.insert(.actualEngineOutputFormat)
        }

        return BitPerfectValidationResult(
            isValid: isValid,
            measurementEvidence: measurementEvidence,
            confidence: confidence,
            expectedSampleRate: Int(sourceFormat.sampleRate),
            actualSampleRate: actualSampleRate,
            expectedBitDepth: Int(sourceFormat.bitDepth),
            actualBitDepth: estimatedBitDepth,
            actualBitDepthIsEstimated: true,
            expectedChannels: sourceChannels,
            actualChannels: actualChannels,
            mismatchReason: mismatchReason,
            validationIssues: validationIssues,
            warnings: warnings,
            deviceInfo: deviceInfo,
            deviceSupportsFormat: deviceSupportsFormat,
            deviceCapabilitiesAreEstimated: true,
            hasAudioProcessing: processingDetection.hasProcessing || context.hasDSP || engineProcessingActive,
            processingStages: processingStages,
            systemVolume: systemVolume,
            applicationVolume: context.applicationVolume,
            recommendedSettings: recommendedSettings,
            alternatives: alternatives,
            performanceImpact: performanceImpact
        )
    }

    func analyzeAudioPath(session: AVAudioSession) async -> AudioPathAnalysis {
        let deviceInfo = await deviceManager.currentDeviceInfo(using: session)
        let processingDetection = await processingAnalyzer.detectProcessing(in: session)

        var limitations: [AudioPathLimitation] = []
        var qualityScore = 1.0

        if let deviceInfo {
            let supportsBitPerfect = [AudioDeviceType.usbDAC, .usb, .thunderbolt].contains(deviceInfo.type)
            if !supportsBitPerfect {
                limitations.append(
                    AudioPathLimitation(
                        type: .deviceLimitation,
                        description: "Output device doesn't support bit-perfect audio",
                        resolution: "Connect a high-quality external DAC",
                        severity: .error
                    )
                )
                qualityScore -= 0.4
            }

            if deviceInfo.connectionType == .bluetooth {
                limitations.append(
                    AudioPathLimitation(
                        type: .systemLimitation,
                        description: "Bluetooth audio uses lossy compression",
                        resolution: "Use wired or USB audio connection",
                        severity: .warning
                    )
                )
                qualityScore -= 0.3
            }
        }

        if session.outputVolume < 1.0 {
            limitations.append(
                AudioPathLimitation(
                    type: .configurationIssue,
                    description: "System volume is not at maximum",
                    resolution: "Set system volume to 100%",
                    severity: .warning
                )
            )
            qualityScore -= 0.1
        }

        if processingDetection.hasProcessing {
            qualityScore -= Double(processingDetection.stages.count) * 0.1
        }

        qualityScore = max(0.0, qualityScore)

        return AudioPathAnalysis(
            isBitPerfect: qualityScore >= 0.9 && !processingDetection.hasProcessing,
            processingStages: processingDetection.stages,
            limitations: limitations,
            qualityScore: qualityScore
        )
    }

    func optimalConfiguration(
        session: AVAudioSession,
        sourceFormat: AudioFileInfo
    ) async -> BitPerfectRecommendations {
        let deviceCapabilities = await deviceManager.currentCapabilities(using: session)
        let recommendedSettings = recommendationEngine.recommendedSettings(
            sourceFormat: sourceFormat,
            deviceCapabilities: deviceCapabilities
        )

        var requiredChanges: [ConfigurationChange] = []

        if Int(session.sampleRate) != recommendedSettings.sampleRate {
            requiredChanges.append(
                ConfigurationChange(
                    setting: "Sample Rate",
                    currentValue: "\(Int(session.sampleRate))Hz",
                    recommendedValue: "\(recommendedSettings.sampleRate)Hz",
                    reason: "Match source format for bit-perfect playback"
                )
            )
        }

        if session.outputVolume < 1.0 {
            requiredChanges.append(
                ConfigurationChange(
                    setting: "System Volume",
                    currentValue: "\(Int(session.outputVolume * 100))%",
                    recommendedValue: "100%",
                    reason: "Prevent digital volume scaling"
                )
            )
        }

        let sessionSettings: [String: String] = [
            "sampleRate": String(recommendedSettings.sampleRate),
            "bufferDuration": "0.005",
            "category": AVAudioSession.Category.playback.rawValue,
            "mode": session.mode.rawValue
        ]

        return BitPerfectRecommendations(
            sessionSettings: sessionSettings,
            bufferSize: recommendedSettings.bufferSize,
            recommendedDevice: nil,
            requiredChanges: requiredChanges,
            expectedImprovement: recommendationEngine.expectedImprovementDescription(for: requiredChanges)
        )
    }

    func analyzeSession(_ session: AVAudioSession) -> AudioSessionAnalysis {
        var issues: [SessionIssue] = []
        var recommendations: [SessionRecommendation] = []

        let currentCategory = session.category
        if currentCategory != .playback {
            issues.append(
                SessionIssue(
                    description: "Audio session category is not optimized for playback",
                    impact: "May affect audio quality and performance",
                    severity: .warning
                )
            )

            recommendations.append(
                SessionRecommendation(
                    setting: "Audio Session Category",
                    recommendation: "Use .playback category",
                    benefit: "Optimizes system for audio playback"
                )
            )
        }

        let currentSampleRate = session.sampleRate
        if currentSampleRate < 44100 {
            issues.append(
                SessionIssue(
                    description: "Sample rate is below CD quality",
                    impact: "Limited audio resolution",
                    severity: .warning
                )
            )
        }

        if !session.isOtherAudioPlaying {
            recommendations.append(
                SessionRecommendation(
                    setting: "Exclusive Access",
                    recommendation: "Ensure no other audio apps are playing",
                    benefit: "Reduces system mixer interference"
                )
            )
        }

        let currentSettings: [String: String] = [
            "category": currentCategory.rawValue,
            "mode": session.mode.rawValue,
            "sampleRate": String(currentSampleRate),
            "outputVolume": String(session.outputVolume),
            "isOtherAudioPlaying": String(session.isOtherAudioPlaying)
        ]

        return AudioSessionAnalysis(
            isOptimal: issues.isEmpty,
            currentSettings: currentSettings,
            issues: issues,
            recommendations: recommendations
        )
    }

    func supportedOutputFormats(session: AVAudioSession) async -> [AudioOutputFormat] {
        let capabilities = await deviceManager.currentCapabilities(using: session)
        var formats: [AudioOutputFormat] = []

        for sampleRate in capabilities.supportedSampleRates {
            for bitDepth in [16, 24, 32] where bitDepth <= capabilities.maxBitDepth {
                for channels in [1, 2] where channels <= capabilities.maxChannels {
                    formats.append(
                        AudioOutputFormat(
                            sampleRate: sampleRate,
                            bitDepth: bitDepth,
                            channels: channels,
                            isFloatingPoint: bitDepth == 32
                        )
                    )
                }
            }
        }

        return formats
    }

    func audioDevice(from output: AVAudioSessionPortDescription) -> AudioDevice {
        AudioDevice(
            id: output.uid,
            name: output.portName,
            type: audioDeviceType(for: output.portType),
            isOutput: true,
            isAvailable: true,
            connectionType: audioConnectionType(for: output.portType),
            supportedSampleRates: [44100, 48000].map(Double.init),
            supportedBitDepths: [UInt16(16), UInt16(24)],
            maxChannels: UInt8(output.channels?.count ?? 2),
            supportsBitPerfect: false,
            isDefault: true
        )
    }

    func conversionAnalysis(
        sourceFormat: AudioFileInfo,
        outputCapabilities: DeviceCapabilities
    ) -> ConversionAnalysis {
        recommendationEngine.conversionAnalysis(
            sourceFormat: sourceFormat,
            outputCapabilities: outputCapabilities
        )
    }

    private func audioDeviceType(for portType: AVAudioSession.Port) -> AudioDeviceType {
        switch portType {
        case .builtInSpeaker, .builtInReceiver:
            return .builtin
        case .headphones:
            return .headphones
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return .bluetooth
        case .airPlay:
            return .airPlay
        case .usbAudio:
            return .usb
        case .thunderbolt:
            return .thunderbolt
        case .HDMI:
            return .hdmi
        case .lineOut:
            return .speakers
        default:
            return .unknown
        }
    }

    private func audioConnectionType(for portType: AVAudioSession.Port) -> AudioConnectionType {
        switch portType {
        case .builtInSpeaker, .builtInReceiver:
            return .builtin
        case .headphones:
            return .headphoneJack
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return .bluetooth
        case .airPlay:
            return .airPlay
        case .usbAudio:
            return .usb
        case .thunderbolt:
            return .thunderbolt
        case .lineIn, .lineOut:
            return .unknown
        default:
            return .unknown
        }
    }
}
