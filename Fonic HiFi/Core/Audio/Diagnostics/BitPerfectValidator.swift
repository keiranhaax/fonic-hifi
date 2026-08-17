//
//  BitPerfectValidator.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import AVFoundation
import Foundation
import OSLog

/// Concrete implementation of bit-perfect validation using AVAudioSession and format analysis
@MainActor
public final class BitPerfectValidator: BitPerfectValidatorService, ObservableObject {
    private let audioSession: AVAudioSession
    private let logger = Log.logger(.diagnosticsBitPerfectValidator)
    private let deviceManager: any BitPerfectDeviceManaging
    private let validationEngine: BitPerfectValidationEngine

    private struct ValidationCacheKey: Equatable {
        let sourceFormat: String
        let sourceSampleRate: Double
        let sourceBitDepth: UInt16
        let sourceChannels: UInt8
        let outputDevice: AudioDevice?
        let routeIdentifiers: [String]
        let sessionSampleRate: Double
        let sessionChannels: Int
        let systemVolume: Float
        let sessionCategory: String
        let sessionMode: String
        let context: BitPerfectEligibilityContext
    }

    private var lastValidation: (key: ValidationCacheKey, result: BitPerfectValidationResult, timestamp: Date)?
    private let validationCacheTimeout: TimeInterval = 5.0

    public init(
        audioSession: AVAudioSession = AVAudioSession.sharedInstance(),
        deviceManager: (any BitPerfectDeviceManaging)? = nil,
        processingAnalyzer: (any BitPerfectProcessingAnalyzing)? = nil,
        recommendationEngine: (any BitPerfectRecommendationGenerating)? = nil,
    ) {
        self.audioSession = audioSession
        let resolvedDeviceManager = deviceManager ?? BitPerfectDeviceManager()
        let resolvedProcessingAnalyzer = processingAnalyzer ?? BitPerfectProcessingAnalyzer()
        let resolvedRecommendationEngine = recommendationEngine ?? BitPerfectRecommendationEngine()

        self.deviceManager = resolvedDeviceManager
        self.validationEngine = BitPerfectValidationEngine(
            deviceManager: resolvedDeviceManager,
            processingAnalyzer: resolvedProcessingAnalyzer,
            recommendationEngine: resolvedRecommendationEngine
        )
    }

    // MARK: - Core Validation

    public func validateBitPerfectPlayback(
        sourceFormat: AudioFileInfo,
        outputDevice: AudioDevice?,
        context: BitPerfectEligibilityContext = .unknown
    ) async -> BitPerfectValidationResult {
        let formatName = sourceFormat.format.displayName
        let sampleRate = sourceFormat.sampleRate
        let bitDepth = sourceFormat.bitDepth
        logger.info("Starting bit-perfect validation for \(formatName, privacy: .public) at \(sampleRate, privacy: .public)Hz/\(bitDepth, privacy: .public)-bit")

        let cacheKey = makeCacheKey(
            sourceFormat: sourceFormat,
            outputDevice: outputDevice,
            context: context
        )
        if let cachedResult = getCachedValidationResult(for: cacheKey) {
            logger.debug("Returning cached validation result")
            return cachedResult
        }

        let result = await validationEngine.validate(
            session: audioSession,
            sourceFormat: sourceFormat,
            context: context
        )

        cacheValidationResult(result, for: cacheKey)

        let eligibility = result.isValid ? "ELIGIBLE" : "INELIGIBLE"
        let confidence = String(format: "%.1f%%", result.confidence * 100)
        logger.info(
            "Eligibility assessment complete: \(eligibility, privacy: .public) (confidence: \(confidence, privacy: .public))"
        )

        return result
    }

    public func validateFormat(
        _ format: AudioFormat,
        sampleRate: Int,
        bitDepth: Int,
        outputDevice: AudioDevice?,
    ) async -> BitPerfectValidationResult {
        let syntheticFileInfo = AudioFileInfo(
            url: URL(fileURLWithPath: "/synthetic"),
            format: format,
            duration: 0,
            bitDepth: UInt16(bitDepth),
            sampleRate: Double(sampleRate),
            channels: 2,
            fileSize: 0,
            bitrate: nil,
        )

        return await validateBitPerfectPlayback(
            sourceFormat: syntheticFileInfo,
            outputDevice: outputDevice,
            context: .unknown
        )
    }

    public func validateRealTime(
        audioSession: AVAudioSession,
        sourceFormat: AudioFileInfo,
    ) async -> BitPerfectValidationResult {
        let currentDevice = audioSession.currentRoute.outputs.first
        let audioDevice = currentDevice.map { validationEngine.audioDevice(from: $0) }

        return await validateBitPerfectPlayback(
            sourceFormat: sourceFormat,
            outputDevice: audioDevice,
            context: .unknown
        )
    }

    // MARK: - Device Analysis

    public func getCurrentDeviceCapabilities() async -> DeviceCapabilities {
        await deviceManager.currentCapabilities(using: audioSession)
    }

    public func getAvailableDevicesWithCapabilities() async -> [DeviceWithCapabilities] {
        await deviceManager.availableDevices(using: audioSession)
    }

    public func supportseBitPerfectPlayback(device: AudioDevice) async -> Bool {
        await deviceManager.supportsBitPerfectPlayback(device: device)
    }

    public func updateDACCompatibility(_ dacInfo: DACCompatibilityInfo) async {
        await deviceManager.updateDACCompatibility(dacInfo)
    }

    public func getDACCompatibility(for deviceIdentifier: String) async -> DACCompatibilityInfo? {
        await deviceManager.dacCompatibility(for: deviceIdentifier)
    }

    public func clearDACCompatibilityCache() async {
        await deviceManager.clearDACCompatibilityCache()
    }

    // MARK: - Analysis & Recommendations

    public func analyzeAudioPath() async -> AudioPathAnalysis {
        await validationEngine.analyzeAudioPath(session: audioSession)
    }

    public func getOptimalConfiguration(for sourceFormat: AudioFileInfo) async -> BitPerfectRecommendations {
        await validationEngine.optimalConfiguration(session: audioSession, sourceFormat: sourceFormat)
    }

    public func analyzeAudioSession() async -> AudioSessionAnalysis {
        validationEngine.analyzeSession(audioSession)
    }

    public func analyzeRequiredConversion(
        sourceFormat: AudioFileInfo,
        outputCapabilities: DeviceCapabilities,
    ) async -> ConversionAnalysis {
        validationEngine.conversionAnalysis(
            sourceFormat: sourceFormat,
            outputCapabilities: outputCapabilities
        )
    }

    public func getSupportedOutputFormats() async -> [AudioOutputFormat] {
        await validationEngine.supportedOutputFormats(session: audioSession)
    }

    // MARK: - Private Helpers

    private func getCachedValidationResult(for key: ValidationCacheKey) -> BitPerfectValidationResult? {
        guard let lastValidation,
              lastValidation.key == key,
              Date().timeIntervalSince(lastValidation.timestamp) < validationCacheTimeout
        else {
            return nil
        }
        return lastValidation.result
    }

    private func cacheValidationResult(_ result: BitPerfectValidationResult, for key: ValidationCacheKey) {
        lastValidation = (key, result, Date())
    }

    private func makeCacheKey(
        sourceFormat: AudioFileInfo,
        outputDevice: AudioDevice?,
        context: BitPerfectEligibilityContext
    ) -> ValidationCacheKey {
        let routeIdentifiers = audioSession.currentRoute.outputs.map {
            "\($0.uid)|\($0.portType.rawValue)"
        }
        return ValidationCacheKey(
            sourceFormat: sourceFormat.format.displayName,
            sourceSampleRate: sourceFormat.sampleRate,
            sourceBitDepth: sourceFormat.bitDepth,
            sourceChannels: sourceFormat.channels,
            outputDevice: outputDevice,
            routeIdentifiers: routeIdentifiers,
            sessionSampleRate: audioSession.sampleRate,
            sessionChannels: Int(audioSession.outputNumberOfChannels),
            systemVolume: audioSession.outputVolume,
            sessionCategory: audioSession.category.rawValue,
            sessionMode: audioSession.mode.rawValue,
            context: context
        )
    }

}
