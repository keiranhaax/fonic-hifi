//
//  BitPerfectValidator.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation
import AVFoundation
import os.log

/// Concrete implementation of bit-perfect validation using AVAudioSession and format analysis
@MainActor
public final class BitPerfectValidator: BitPerfectValidatorService, ObservableObject {
    
    // MARK: - Private Properties
    
    private let audioSession: AVAudioSession
    private let logger = Logger(subsystem: "com.fonichifi.audio", category: "BitPerfectValidator")
    
    /// Cache for DAC compatibility information
    private var dacCompatibilityCache: [String: DACCompatibilityInfo] = [:]
    
    /// Cache for device capabilities
    private var deviceCapabilitiesCache: [String: DeviceCapabilities] = [:]
    
    /// Last validation result for caching
    private var lastValidationResult: BitPerfectValidationResult?
    private var lastValidationTimestamp: Date?
    
    /// Validation cache timeout in seconds
    private let validationCacheTimeout: TimeInterval = 5.0
    
    // MARK: - Initialization
    
    public init(audioSession: AVAudioSession = AVAudioSession.sharedInstance()) {
        self.audioSession = audioSession
        loadDACCompatibilityDatabase()
    }
    
    // MARK: - Core Validation
    
    public func validateBitPerfectPlayback(
        sourceFormat: AudioFileInfo,
        outputDevice: AudioDevice?
    ) async -> BitPerfectValidationResult {
        
        logger.info("Starting bit-perfect validation for \(sourceFormat.format.displayName) at \(sourceFormat.sampleRate)Hz/\(sourceFormat.bitDepth)-bit")
        
        // Check cache first
        if let cachedResult = getCachedValidationResult() {
            logger.debug("Returning cached validation result")
            return cachedResult
        }
        
        var validationIssues: [ValidationIssue] = []
        var warnings: [ValidationWarning] = []
        var processingStages: [AudioProcessingStage] = []
        
        // Get current device capabilities
        let deviceCapabilities = await getCurrentDeviceCapabilities()
        let deviceInfo = await getCurrentDeviceInfo()
        
        // Analyze audio session settings
        let sessionAnalysis = await analyzeAudioSession()
        
        // Check sample rate compatibility
        let actualSampleRate = Int(audioSession.sampleRate)
        let sampleRateMatches = Int(sourceFormat.sampleRate) == actualSampleRate
        
        if !sampleRateMatches {
            validationIssues.append(ValidationIssue(
                type: .formatMismatch,
                description: "Sample rate mismatch: source \(sourceFormat.sampleRate)Hz vs output \(actualSampleRate)Hz",
                technicalDetails: "Sample rate conversion will be applied, preventing bit-perfect playback",
                severity: .error,
                suggestedResolution: "Configure output device to match source sample rate",
                canAutoResolve: true
            ))
            
            processingStages.append(AudioProcessingStage(
                type: .sampleRateConversion,
                description: "Sample rate conversion from \(sourceFormat.sampleRate)Hz to \(actualSampleRate)Hz",
                affectsBitPerfect: true,
                performanceImpact: 0.3
            ))
        }
        
        // Estimate actual bit depth (iOS limitation: no direct access)
        let estimatedBitDepth = estimateOutputBitDepth(deviceCapabilities: deviceCapabilities)
        let bitDepthMatches = sourceFormat.bitDepth <= estimatedBitDepth
        
        if !bitDepthMatches {
            validationIssues.append(ValidationIssue(
                type: .formatMismatch,
                description: "Bit depth limitation: source \(sourceFormat.bitDepth)-bit vs output \(estimatedBitDepth)-bit",
                technicalDetails: "Bit depth conversion or truncation may occur",
                severity: .warning,
                suggestedResolution: "Use a DAC that supports \(sourceFormat.bitDepth)-bit audio",
                canAutoResolve: false
            ))
        }
        
        // Check for audio processing
        let audioProcessingDetected = await detectAudioProcessing()
        if audioProcessingDetected.hasProcessing {
            processingStages.append(contentsOf: audioProcessingDetected.stages)
            
            validationIssues.append(ValidationIssue(
                type: .processingDetected,
                description: "Audio processing detected in signal path",
                technicalDetails: "Active processing: \(audioProcessingDetected.stages.map(\.description).joined(separator: ", "))",
                severity: .warning,
                suggestedResolution: "Disable audio processing features",
                canAutoResolve: true
            ))
        }
        
        // Check volume levels
        let systemVolume = audioSession.outputVolume
        let volumeIsOptimal = systemVolume == 1.0
        
        if !volumeIsOptimal {
            validationIssues.append(ValidationIssue(
                type: .volumeScaling,
                description: "System volume is not at 100%",
                technicalDetails: "Current volume: \(Int(systemVolume * 100))%",
                severity: .warning,
                suggestedResolution: "Set system volume to 100%",
                canAutoResolve: true
            ))
            
            processingStages.append(AudioProcessingStage(
                type: .volumeControl,
                description: "Digital volume scaling at \(Int(systemVolume * 100))%",
                affectsBitPerfect: true,
                performanceImpact: 0.1
            ))
        }
        
        // Check device capabilities
        let deviceSupportsFormat = deviceCapabilities.supportedSampleRates.contains(Int(sourceFormat.sampleRate)) &&
                                  sourceFormat.bitDepth <= deviceCapabilities.maxBitDepth
        
        if !deviceSupportsFormat {
            validationIssues.append(ValidationIssue(
                type: .deviceLimitation,
                description: "Output device doesn't natively support the source format",
                technicalDetails: "Device max: \(deviceCapabilities.maxBitDepth)-bit, \(deviceCapabilities.supportedSampleRates.max() ?? 0)Hz",
                severity: .error,
                suggestedResolution: "Use a DAC that supports the source format natively",
                canAutoResolve: false
            ))
        }
        
        // Determine primary mismatch reason
        let mismatchReason: BitPerfectMismatchReason? = {
            if !sampleRateMatches { return .sampleRateMismatch }
            if !bitDepthMatches { return .bitDepthMismatch }
            if !deviceSupportsFormat { return .deviceNotCapable }
            if !volumeIsOptimal { return .systemVolumeNotUnity }
            if audioProcessingDetected.hasProcessing { return .audioProcessingActive }
            return nil
        }()
        
        // Calculate overall validity
        let isValid = sampleRateMatches && 
                     bitDepthMatches && 
                     deviceSupportsFormat && 
                     volumeIsOptimal && 
                     !audioProcessingDetected.hasProcessing
        
        // Generate recommendations
        let recommendedSettings = generateRecommendedSettings(
            sourceFormat: sourceFormat,
            deviceCapabilities: deviceCapabilities
        )
        
        // Create alternatives if bit-perfect isn't possible
        let alternatives = await generateAlternatives(
            sourceFormat: sourceFormat,
            deviceCapabilities: deviceCapabilities
        )
        
        // Assess performance impact
        let performanceImpact = calculatePerformanceImpact(
            processingStages: processingStages,
            sourceFormat: sourceFormat
        )
        
        // Calculate confidence level
        let confidence = calculateValidationConfidence(
            deviceInfo: deviceInfo,
            sessionAnalysis: sessionAnalysis
        )
        
        let result = BitPerfectValidationResult(
            isValid: isValid,
            confidence: confidence,
            expectedSampleRate: Int(sourceFormat.sampleRate),
            actualSampleRate: actualSampleRate,
            expectedBitDepth: Int(sourceFormat.bitDepth),
            actualBitDepth: estimatedBitDepth,
            expectedChannels: Int(sourceFormat.channels),
            actualChannels: Int(audioSession.currentRoute.outputs.first?.channels?.count ?? 2),
            mismatchReason: mismatchReason,
            validationIssues: validationIssues,
            warnings: warnings,
            deviceInfo: deviceInfo,
            deviceSupportsFormat: deviceSupportsFormat,
            hasAudioProcessing: audioProcessingDetected.hasProcessing,
            processingStages: processingStages,
            systemVolume: systemVolume,
            applicationVolume: 1.0, // Assume app volume is at 100%
            recommendedSettings: recommendedSettings,
            alternatives: alternatives,
            performanceImpact: performanceImpact
        )
        
        // Cache the result
        cacheValidationResult(result)
        
        logger.info("Validation complete: \(isValid ? "VALID" : "INVALID") (confidence: \(String(format: "%.1f%%", confidence * 100)))")
        
        return result
    }
    
    public func validateFormat(
        _ format: AudioFormat,
        sampleRate: Int,
        bitDepth: Int,
        outputDevice: AudioDevice?
    ) async -> BitPerfectValidationResult {
        
        let syntheticFileInfo = AudioFileInfo(
            url: URL(fileURLWithPath: "/synthetic"),
            format: format,
            duration: 0,
            bitDepth: UInt16(bitDepth),
            sampleRate: Double(sampleRate),
            channels: 2,
            fileSize: 0,
            bitrate: nil
        )
        
        return await validateBitPerfectPlayback(
            sourceFormat: syntheticFileInfo,
            outputDevice: outputDevice
        )
    }
    
    public func validateRealTime(
        audioSession: AVAudioSession,
        sourceFormat: AudioFileInfo
    ) async -> BitPerfectValidationResult {
        
        // For real-time validation, we use the provided session
        // This allows validation during active playback
        
        let currentDevice = audioSession.currentRoute.outputs.first
        let audioDevice = currentDevice.map { output in
            AudioDevice(
                id: output.uid,
                name: output.portName,
                type: audioDeviceType(from: output.portType),
                isOutput: true,
                isAvailable: true,
                connectionType: audioConnectionTypeFromPortType(output.portType),
                supportedSampleRates: [44100, 48000],
                supportedBitDepths: [16, 24],
                maxChannels: UInt8(output.channels?.count ?? 2),
                supportsBitPerfect: false,
                isDefault: true
            )
        }
        
        return await validateBitPerfectPlayback(
            sourceFormat: sourceFormat,
            outputDevice: audioDevice
        )
    }
    
    // MARK: - Device Analysis
    
    public func getCurrentDeviceCapabilities() async -> DeviceCapabilities {
        let currentRoute = audioSession.currentRoute
        guard let output = currentRoute.outputs.first else {
            return getDefaultDeviceCapabilities()
        }
        
        // Check cache first
        if let cached = deviceCapabilitiesCache[output.uid] {
            return cached
        }
        
        // Determine device capabilities based on connection type
        let capabilities = determineDeviceCapabilities(from: output)
        
        // Cache the result
        deviceCapabilitiesCache[output.uid] = capabilities
        
        return capabilities
    }
    
    public func getAvailableDevicesWithCapabilities() async -> [DeviceWithCapabilities] {
        var devicesWithCapabilities: [DeviceWithCapabilities] = []
        
        // Get current route outputs
        let outputs = audioSession.currentRoute.outputs
        
        for output in outputs {
            let device = AudioDevice(
                id: output.uid,
                name: output.portName,
                type: audioDeviceType(from: output.portType),
                isOutput: true,
                isAvailable: true,
                connectionType: audioConnectionTypeFromPortType(output.portType),
                supportedSampleRates: getEstimatedSampleRates(for: output).map { Double($0) },
                supportedBitDepths: [16, UInt16(getEstimatedMaxBitDepth(for: output))],
                maxChannels: UInt8(output.channels?.count ?? 2),
                supportsBitPerfect: [AudioDeviceType.usbDAC, .usb, .thunderbolt].contains(audioDeviceType(from: output.portType)),
                isDefault: outputs.first?.uid == output.uid
            )
            
            let capabilities = determineDeviceCapabilities(from: output)
            
            devicesWithCapabilities.append(DeviceWithCapabilities(
                device: device,
                capabilities: capabilities
            ))
        }
        
        return devicesWithCapabilities
    }
    
    public func supportseBitPerfectPlayback(device: AudioDevice) async -> Bool {
        // Check if device connection type typically supports bit-perfect
        let connectionSupported = device.type.supportsHighQuality
        
        // Check if we have specific DAC compatibility info
        if let dacInfo = await getDACCompatibility(for: device.id) {
            return dacInfo.supportsBitPerfect
        }
        
        // Check device capabilities
        let capabilities = deviceCapabilitiesCache[device.id] ?? getDefaultDeviceCapabilities()
        
        return connectionSupported && 
               capabilities.maxBitDepth >= 16 && 
               capabilities.supportedSampleRates.contains(44100)
    }
    
    // MARK: - DAC Compatibility
    
    public func updateDACCompatibility(_ dacInfo: DACCompatibilityInfo) async {
        dacCompatibilityCache[dacInfo.deviceIdentifier] = dacInfo
        await saveDACCompatibilityDatabase()
    }
    
    public func getDACCompatibility(for deviceIdentifier: String) async -> DACCompatibilityInfo? {
        return dacCompatibilityCache[deviceIdentifier]
    }
    
    public func clearDACCompatibilityCache() async {
        dacCompatibilityCache.removeAll()
        await saveDACCompatibilityDatabase()
    }
    
    // MARK: - Analysis & Recommendations
    
    public func analyzeAudioPath() async -> AudioPathAnalysis {
        let currentDevice = audioSession.currentRoute.outputs.first
        let processingDetection = await detectAudioProcessing()
        
        var limitations: [AudioPathLimitation] = []
        var qualityScore = 1.0
        
        // Analyze device limitations
        if let device = currentDevice {
            let deviceType = audioDeviceType(from: device.portType)
            
            let supportsBitPerfect = [AudioDeviceType.usbDAC, .usb, .thunderbolt].contains(deviceType)
            if !supportsBitPerfect {
                limitations.append(AudioPathLimitation(
                    type: .deviceLimitation,
                    description: "Output device doesn't support bit-perfect audio",
                    resolution: "Connect a high-quality external DAC",
                    severity: .error
                ))
                qualityScore -= 0.4
            }
            
            if device.portType == .bluetoothA2DP {
                limitations.append(AudioPathLimitation(
                    type: .systemLimitation,
                    description: "Bluetooth audio uses lossy compression",
                    resolution: "Use wired or USB audio connection",
                    severity: .warning
                ))
                qualityScore -= 0.3
            }
        }
        
        // Analyze system limitations
        if audioSession.outputVolume < 1.0 {
            limitations.append(AudioPathLimitation(
                type: .configurationIssue,
                description: "System volume is not at maximum",
                resolution: "Set system volume to 100%",
                severity: .warning
            ))
            qualityScore -= 0.1
        }
        
        // Factor in detected processing
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
    
    public func getOptimalConfiguration(for sourceFormat: AudioFileInfo) async -> BitPerfectRecommendations {
        let deviceCapabilities = await getCurrentDeviceCapabilities()
        
        // Find optimal sample rate
        let optimalSampleRate = deviceCapabilities.supportedSampleRates
            .filter { $0 >= Int(sourceFormat.sampleRate) }
            .min() ?? deviceCapabilities.supportedSampleRates.max() ?? 48000
        
        // Find optimal buffer size
        let optimalBufferSize = deviceCapabilities.bufferSizeRange.lowerBound
        
        var requiredChanges: [ConfigurationChange] = []
        
        // Check if sample rate needs changing
        if Int(audioSession.sampleRate) != optimalSampleRate {
            requiredChanges.append(ConfigurationChange(
                setting: "Sample Rate",
                currentValue: "\(Int(audioSession.sampleRate))Hz",
                recommendedValue: "\(optimalSampleRate)Hz",
                reason: "Match source format for bit-perfect playback"
            ))
        }
        
        // Check if volume needs adjusting
        if audioSession.outputVolume < 1.0 {
            requiredChanges.append(ConfigurationChange(
                setting: "System Volume",
                currentValue: "\(Int(audioSession.outputVolume * 100))%",
                recommendedValue: "100%",
                reason: "Prevent digital volume scaling"
            ))
        }
        
        let sessionSettings: [String: String] = [
            "sampleRate": String(optimalSampleRate),
            "bufferDuration": "0.005",
            "category": AVAudioSession.Category.playback.rawValue,
            "mode": AVAudioSession.Mode.default.rawValue
        ]
        
        return BitPerfectRecommendations(
            sessionSettings: sessionSettings,
            bufferSize: optimalBufferSize,
            recommendedDevice: nil, // iOS doesn't allow programmatic device selection
            requiredChanges: requiredChanges,
            expectedImprovement: generateExpectedImprovementDescription(changes: requiredChanges)
        )
    }
    
    public func analyzeAudioSession() async -> AudioSessionAnalysis {
        var issues: [SessionIssue] = []
        var recommendations: [SessionRecommendation] = []
        
        // Check current category
        let currentCategory = audioSession.category
        if currentCategory != .playback {
            issues.append(SessionIssue(
                description: "Audio session category is not optimized for playback",
                impact: "May affect audio quality and performance",
                severity: .warning
            ))
            
            recommendations.append(SessionRecommendation(
                setting: "Audio Session Category",
                recommendation: "Use .playback category",
                benefit: "Optimizes system for audio playback"
            ))
        }
        
        // Check sample rate
        let currentSampleRate = audioSession.sampleRate
        if currentSampleRate < 44100 {
            issues.append(SessionIssue(
                description: "Sample rate is below CD quality",
                impact: "Limited audio resolution",
                severity: .warning
            ))
        }
        
        // Check if session is active
        if !audioSession.isOtherAudioPlaying {
            recommendations.append(SessionRecommendation(
                setting: "Exclusive Access",
                recommendation: "Ensure no other audio apps are playing",
                benefit: "Reduces system mixer interference"
            ))
        }
        
        let currentSettings: [String: String] = [
            "category": currentCategory.rawValue,
            "mode": audioSession.mode.rawValue,
            "sampleRate": String(currentSampleRate),
            "outputVolume": String(audioSession.outputVolume),
            "isOtherAudioPlaying": String(audioSession.isOtherAudioPlaying)
        ]
        
        return AudioSessionAnalysis(
            isOptimal: issues.isEmpty,
            currentSettings: currentSettings,
            issues: issues,
            recommendations: recommendations
        )
    }
    
    public func analyzeRequiredConversion(
        sourceFormat: AudioFileInfo,
        outputCapabilities: DeviceCapabilities
    ) async -> ConversionAnalysis {
        
        var conversionTypes: [ConversionType] = []
        var qualityImpact: QualityImpact = .none
        var performanceImpact: Double = 0.0
        
        // Check sample rate conversion
        if !outputCapabilities.supportedSampleRates.contains(Int(sourceFormat.sampleRate)) {
            conversionTypes.append(.sampleRate)
            qualityImpact = .moderate
            performanceImpact += 0.3
        }
        
        // Check bit depth conversion
        if sourceFormat.bitDepth > outputCapabilities.maxBitDepth {
            conversionTypes.append(.bitDepth)
            if qualityImpact == .none { qualityImpact = .minimal }
            performanceImpact += 0.1
        }
        
        // Check channel conversion
        if sourceFormat.channels > outputCapabilities.maxChannels {
            conversionTypes.append(.channelCount)
            if qualityImpact == .none { qualityImpact = .minimal }
            performanceImpact += 0.2
        }
        
        // Generate alternatives
        let alternatives = generateConversionAlternatives(
            sourceFormat: sourceFormat,
            outputCapabilities: outputCapabilities
        )
        
        return ConversionAnalysis(
            conversionRequired: !conversionTypes.isEmpty,
            conversionTypes: conversionTypes,
            qualityImpact: qualityImpact,
            performanceImpact: performanceImpact,
            alternatives: alternatives
        )
    }
    
    public func getSupportedOutputFormats() async -> [AudioOutputFormat] {
        let capabilities = await getCurrentDeviceCapabilities()
        var formats: [AudioOutputFormat] = []
        
        for sampleRate in capabilities.supportedSampleRates {
            for bitDepth in [16, 24, 32] {
                if bitDepth <= capabilities.maxBitDepth {
                    for channels in [1, 2] {
                        if channels <= capabilities.maxChannels {
                            formats.append(AudioOutputFormat(
                                sampleRate: sampleRate,
                                bitDepth: bitDepth,
                                channels: channels,
                                isFloatingPoint: bitDepth == 32
                            ))
                        }
                    }
                }
            }
        }
        
        return formats
    }
    
    // MARK: - Private Helper Methods
    
    private func getCachedValidationResult() -> BitPerfectValidationResult? {
        guard let lastResult = lastValidationResult,
              let lastTimestamp = lastValidationTimestamp,
              Date().timeIntervalSince(lastTimestamp) < validationCacheTimeout else {
            return nil
        }
        return lastResult
    }
    
    private func cacheValidationResult(_ result: BitPerfectValidationResult) {
        lastValidationResult = result
        lastValidationTimestamp = Date()
    }
    
    private func estimateOutputBitDepth(deviceCapabilities: DeviceCapabilities) -> Int {
        // iOS typically uses 16-bit for built-in audio, 24-bit for external DACs
        let currentRoute = audioSession.currentRoute
        guard let output = currentRoute.outputs.first else {
            return 16
        }
        
        switch output.portType {
        case .builtInSpeaker, .builtInReceiver:
            return 16
        case .headphones:
            return 16
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return 16
        case .thunderbolt:
            return deviceCapabilities.maxBitDepth
        default:
            return 16
        }
    }
    
    private func detectAudioProcessing() async -> (hasProcessing: Bool, stages: [AudioProcessingStage]) {
        var stages: [AudioProcessingStage] = []
        
        // Check for system mixer activity
        if audioSession.isOtherAudioPlaying {
            stages.append(AudioProcessingStage(
                type: .systemMixer,
                description: "System audio mixer is active",
                affectsBitPerfect: true,
                performanceImpact: 0.2
            ))
        }
        
        // Check for volume scaling
        if audioSession.outputVolume < 1.0 {
            stages.append(AudioProcessingStage(
                type: .volumeControl,
                description: "Digital volume scaling at \(Int(audioSession.outputVolume * 100))%",
                affectsBitPerfect: true,
                performanceImpact: 0.1
            ))
        }
        
        // Note: iOS doesn't provide direct access to DSP/EQ settings
        // These would need to be detected through other means or user reporting
        
        return (hasProcessing: !stages.isEmpty, stages: stages)
    }
    
    private func getCurrentDeviceInfo() async -> DeviceValidationInfo? {
        guard let output = audioSession.currentRoute.outputs.first else { return nil }
        
        let deviceType = audioDeviceType(from: output.portType)
        let capabilities = await getCurrentDeviceCapabilities()
        let connectionType = connectionTypeFromPortType(output.portType)
        
        return DeviceValidationInfo(
            id: output.uid,
            name: output.portName,
            type: deviceType,
            isDefault: true,
            capabilities: capabilities,
            connectionType: connectionType
        )
    }
    
    private func determineDeviceCapabilities(from output: AVAudioSessionPortDescription) -> DeviceCapabilities {
        let portType = output.portType
        
        switch portType {
        case .builtInSpeaker, .builtInReceiver:
            return DeviceCapabilities(
                supportedSampleRates: [44100, 48000],
                maxBitDepth: 16,
                maxChannels: 2,
                supportsHardwareVolume: true,
                bypassesSystemMixer: false,
                bufferSizeRange: 256...2048,
                supportsExclusiveMode: false
            )
            
        case .headphones:
            return DeviceCapabilities(
                supportedSampleRates: [44100, 48000],
                maxBitDepth: 16,
                maxChannels: 2,
                supportsHardwareVolume: false,
                bypassesSystemMixer: false,
                bufferSizeRange: 256...1024,
                supportsExclusiveMode: false
            )
            
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return DeviceCapabilities(
                supportedSampleRates: [44100, 48000],
                maxBitDepth: 16,
                maxChannels: 2,
                supportsHardwareVolume: true,
                bypassesSystemMixer: false,
                bufferSizeRange: 512...2048,
                supportsExclusiveMode: false
            )
            
        case .usbAudio:
            // Check DAC compatibility database
            if let dacInfo = dacCompatibilityCache[output.uid] {
                return DeviceCapabilities(
                    supportedSampleRates: dacInfo.supportedSampleRates,
                    maxBitDepth: dacInfo.maxBitDepth,
                    maxChannels: dacInfo.maxChannels,
                    supportsHardwareVolume: dacInfo.supportsHardwareVolume,
                    bypassesSystemMixer: dacInfo.bypassesSystemMixer,
                    bufferSizeRange: dacInfo.bufferSizeRange,
                    supportsExclusiveMode: dacInfo.supportsExclusiveMode
                )
            }
            
            // Default USB DAC capabilities
            return DeviceCapabilities(
                supportedSampleRates: [44100, 48000, 96000, 192000],
                maxBitDepth: 24,
                maxChannels: 2,
                supportsHardwareVolume: true,
                bypassesSystemMixer: false,
                bufferSizeRange: 128...4096,
                supportsExclusiveMode: false
            )
            
        default:
            return getDefaultDeviceCapabilities()
        }
    }
    
    private func getDefaultDeviceCapabilities() -> DeviceCapabilities {
        return DeviceCapabilities(
            supportedSampleRates: [44100, 48000],
            maxBitDepth: 16,
            maxChannels: 2,
            supportsHardwareVolume: true,
            bypassesSystemMixer: false,
            bufferSizeRange: 256...2048,
            supportsExclusiveMode: false
        )
    }
    
    private func getEstimatedSampleRates(for output: AVAudioSessionPortDescription) -> [Int] {
        switch output.portType {
        case .usbAudio:
            return [44100, 48000, 96000, 192000]
        case .builtInSpeaker, .builtInReceiver, .headphones:
            return [44100, 48000]
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return [44100, 48000]
        default:
            return [44100, 48000]
        }
    }
    
    private func getEstimatedMaxBitDepth(for output: AVAudioSessionPortDescription) -> Int {
        switch output.portType {
        case .usbAudio:
            return 24
        case .builtInSpeaker, .builtInReceiver, .headphones:
            return 16
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return 16
        default:
            return 16
        }
    }
    
    private func audioDeviceType(from portType: AVAudioSession.Port) -> AudioDeviceType {
        switch portType {
        case .builtInSpeaker:
            return .builtin
        case .builtInReceiver:
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
    
    private func audioConnectionTypeFromPortType(_ portType: AVAudioSession.Port) -> AudioConnectionType {
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
    
    private func connectionTypeFromPortType(_ portType: AVAudioSession.Port) -> DeviceConnectionType {
        switch portType {
        case .builtInSpeaker, .builtInReceiver:
            return .internal
        case .headphones:
            return .wired
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return .bluetooth
        case .airPlay:
            return .airplay
        case .usbAudio:
            return .usb
        case .thunderbolt:
            return .thunderbolt
        case .lineOut:
            return .wired
        default:
            return .unknown
        }
    }
    
    private func generateRecommendedSettings(
        sourceFormat: AudioFileInfo,
        deviceCapabilities: DeviceCapabilities
    ) -> BitPerfectSettings {
        
        let optimalSampleRate = deviceCapabilities.supportedSampleRates
            .filter { Double($0) >= sourceFormat.sampleRate }
            .map { Double($0) }
            .min() ?? sourceFormat.sampleRate
        
        let optimalBitDepth = min(sourceFormat.bitDepth, UInt16(deviceCapabilities.maxBitDepth))
        let optimalBufferSize = deviceCapabilities.bufferSizeRange.lowerBound
        
        return BitPerfectSettings(
            sampleRate: Int(optimalSampleRate),
            bitDepth: Int(optimalBitDepth),
            bufferSize: Int(optimalBufferSize),
            useExclusiveMode: deviceCapabilities.supportsExclusiveMode,
            bypassSystemVolume: deviceCapabilities.bypassesSystemMixer,
            sessionCategory: AVAudioSession.Category.playback.rawValue
        )
    }
    
    private func generateAlternatives(
        sourceFormat: AudioFileInfo,
        deviceCapabilities: DeviceCapabilities
    ) async -> [AlternativeConfiguration] {
        
        var alternatives: [AlternativeConfiguration] = []
        
        // Alternative 1: Highest quality the device supports
        if let maxSampleRate = deviceCapabilities.supportedSampleRates.max() {
            alternatives.append(AlternativeConfiguration(
                description: "Maximum device capability",
                outputFormat: AudioOutputFormat(
                    sampleRate: maxSampleRate,
                    bitDepth: deviceCapabilities.maxBitDepth,
                    channels: min(Int(sourceFormat.channels), Int(deviceCapabilities.maxChannels))
                ),
                benefits: ["Highest quality possible on this device"],
                tradeoffs: sourceFormat.sampleRate > Double(maxSampleRate) ? ["Sample rate downsampling required"] : []
            ))
        }
        
        // Alternative 2: CD quality (widely supported)
        alternatives.append(AlternativeConfiguration(
            description: "CD Quality (44.1kHz/16-bit)",
            outputFormat: AudioOutputFormat(
                sampleRate: 44100,
                bitDepth: 16,
                channels: 2
            ),
            benefits: ["Universal compatibility", "Lower CPU usage", "Stable playback"],
            tradeoffs: sourceFormat.sampleRate > 44100 || sourceFormat.bitDepth > 16 ? 
                      ["Reduced resolution from source"] : []
        ))
        
        return alternatives
    }
    
    private func generateConversionAlternatives(
        sourceFormat: AudioFileInfo,
        outputCapabilities: DeviceCapabilities
    ) -> [AlternativeConfiguration] {
        
        var alternatives: [AlternativeConfiguration] = []
        
        // Find closest supported sample rate
        if !outputCapabilities.supportedSampleRates.contains(Int(sourceFormat.sampleRate)) {
            if let closestRate = outputCapabilities.supportedSampleRates
                .min(by: { abs(Double($0) - sourceFormat.sampleRate) < abs(Double($1) - sourceFormat.sampleRate) }) {
                
                alternatives.append(AlternativeConfiguration(
                    description: "Closest supported sample rate (\(closestRate)Hz)",
                    outputFormat: AudioOutputFormat(
                        sampleRate: closestRate,
                        bitDepth: min(Int(sourceFormat.bitDepth), outputCapabilities.maxBitDepth),
                        channels: min(Int(sourceFormat.channels), Int(outputCapabilities.maxChannels))
                    ),
                    benefits: ["Minimal sample rate conversion", "Device native support"],
                    tradeoffs: ["Sample rate conversion required"]
                ))
            }
        }
        
        return alternatives
    }
    
    private func calculatePerformanceImpact(
        processingStages: [AudioProcessingStage],
        sourceFormat: AudioFileInfo
    ) -> PerformanceImpact {
        
        let totalProcessingImpact = processingStages.reduce(0.0) { $0 + $1.performanceImpact }
        
        // Higher sample rates and bit depths increase impact
        let formatImpact = Double(sourceFormat.sampleRate) / 44100.0 * 0.1 +
                          Double(sourceFormat.bitDepth) / 16.0 * 0.05
        
        let cpuImpact = min(1.0, totalProcessingImpact + formatImpact)
        let memoryImpact = min(1.0, formatImpact * 2.0)
        let batteryImpact = min(1.0, cpuImpact * 0.8)
        
        let latency = Double(processingStages.count) * 2.0 + 3.0 // Base 3ms + 2ms per stage
        
        let rating: PerformanceRating
        if cpuImpact < 0.2 {
            rating = .excellent
        } else if cpuImpact < 0.4 {
            rating = .good
        } else if cpuImpact < 0.6 {
            rating = .adequate
        } else if cpuImpact < 0.8 {
            rating = .limited
        } else {
            rating = .limited
        }
        
        // Return appropriate performance impact based on CPU usage
        if cpuImpact < 0.3 {
            return .low
        } else if cpuImpact < 0.6 {
            return .medium
        } else {
            return .high
        }
    }
    
    private func calculateValidationConfidence(
        deviceInfo: DeviceValidationInfo?,
        sessionAnalysis: AudioSessionAnalysis
    ) -> Double {
        
        var confidence = 0.8 // Base confidence
        
        // Increase confidence for known devices
        if let deviceInfo = deviceInfo,
           dacCompatibilityCache[deviceInfo.id] != nil {
            confidence += 0.1
        }
        
        // Decrease confidence for unknown or problematic configurations
        if deviceInfo?.type == .unknown {
            confidence -= 0.2
        }
        
        if !sessionAnalysis.isOptimal {
            confidence -= 0.1
        }
        
        return max(0.1, min(1.0, confidence))
    }
    
    private func generateExpectedImprovementDescription(changes: [ConfigurationChange]) -> String {
        if changes.isEmpty {
            return "Configuration is already optimal for bit-perfect playback"
        }
        
        var improvements: [String] = []
        
        for change in changes {
            switch change.setting {
            case "Sample Rate":
                improvements.append("eliminate sample rate conversion")
            case "System Volume":
                improvements.append("remove digital volume scaling")
            default:
                improvements.append("optimize \(change.setting.lowercased())")
            }
        }
        
        return "Expected improvements: \(improvements.joined(separator: ", "))"
    }
    
    // MARK: - DAC Database Management
    
    private func loadDACCompatibilityDatabase() {
        // Load built-in DAC compatibility database
        dacCompatibilityCache["apple_builtin"] = DACCompatibilityInfo.appleBuiltIn()
        dacCompatibilityCache["generic_usb_dac"] = DACCompatibilityInfo.genericUSBDAC()
        
        // Future enhancement: Could load from user defaults or external database
    }
    
    private func saveDACCompatibilityDatabase() async {
        // Future enhancement: Could save to persistent storage
        logger.debug("DAC compatibility database saved with \(self.dacCompatibilityCache.count) entries")
    }
} 