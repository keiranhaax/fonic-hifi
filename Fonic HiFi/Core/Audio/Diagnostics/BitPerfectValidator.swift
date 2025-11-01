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

    private var lastValidationResult: BitPerfectValidationResult?
    private var lastValidationTimestamp: Date?
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
        outputDevice _: AudioDevice?,
    ) async -> BitPerfectValidationResult {
        logger.info("Starting bit-perfect validation for \(sourceFormat.format.displayName, privacy: .public) at \(sourceFormat.sampleRate)Hz/\(sourceFormat.bitDepth)-bit")

        if let cachedResult = getCachedValidationResult() {
            logger.debug("Returning cached validation result")
            return cachedResult
        }

        let result = await validationEngine.validate(
            session: audioSession,
            sourceFormat: sourceFormat
        )

        cacheValidationResult(result)

        logger.info(
            "Validation complete: \(result.isValid ? "VALID" : "INVALID", privacy: .public) (confidence: \(String(format: "%.1f%%", result.confidence * 100)))"
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

    private func getCachedValidationResult() -> BitPerfectValidationResult? {
        guard let lastResult = lastValidationResult,
              let lastTimestamp = lastValidationTimestamp,
              Date().timeIntervalSince(lastTimestamp) < validationCacheTimeout
        else {
            return nil
        }
        return lastResult
    }

    private func cacheValidationResult(_ result: BitPerfectValidationResult) {
        lastValidationResult = result
        lastValidationTimestamp = Date()
    }

}
