//
//  AudioEngineManager.swift
//  Fonic HiFi
//
//  Created as part of Phase 2C modularisation.
//

import Foundation
import OSLog

/// Coordinates creation, configuration, and lifecycle management of audio engines.
@MainActor
public final class AudioEngineManager {
    // MARK: - Dependencies

    private let engineFactory: any AudioEngineFactoring
    private let monitor: any AudioPerformanceMonitoring
    private let logger = Log.logger(.audioEngineManager)

    // MARK: - State

    private(set) var currentEngine: AudioEngineService?
    private(set) var currentEngineType: AudioEngineType?
    private(set) var currentFormat: AudioFormat?
    private var pendingEngineSwitch: Bool = false
    private(set) var equalizerConfiguration: EqualizerConfiguration = .default
    private(set) var equalizerApplicationResult: EqualizerApplicationResult = .waitingForEngine
    var equalizerApplicationResultHandler: (@MainActor (EqualizerApplicationResult) -> Void)?

    public private(set) var configuration: AudioEngineConfiguration

    // MARK: - Initialization

    public init(
        configuration: AudioEngineConfiguration,
        engineFactory: any AudioEngineFactoring,
        monitor: any AudioPerformanceMonitoring,
    ) {
        self.configuration = configuration
        self.engineFactory = engineFactory
        self.monitor = monitor

        logger.debug("AudioEngineManager initialised with configuration: \(String(describing: configuration.performanceMode), privacy: .public)")
    }

    // MARK: - Engine Lifecycle

    /// Ensure an engine capable of handling the provided format is available.
    /// - Parameter info: Detected file information describing required capabilities.
    /// - Returns: Configured engine ready for playback.
    /// - Throws: `AudioError` if no suitable engine can be prepared.
    @discardableResult
    public func ensureEngine(for info: AudioFileInfo) async throws -> AudioEngineService {
        // Check for deferred preference change
        if pendingEngineSwitch {
            logger.info("Applying deferred engine switch")
            await cleanupCurrentEngine()
            pendingEngineSwitch = false
        }

        let requiredType = engineFactory.selectEngineType(
            for: info.format,
            configuration: configuration,
        )

        if let engine = currentEngine, currentEngineType == requiredType {
            logger.debug("Reusing existing engine for format: \(info.format.displayName, privacy: .public)")
            do {
                try await engine.configure(with: configuration)
                await applyEqualizerConfiguration(to: engine)
                return engine
            } catch {
                logger.error("Failed to reconfigure engine: \(error.localizedDescription, privacy: .private)")
                return try await recreateEngine(for: info, requiredType: requiredType)
            }
        }

        return try await recreateEngine(for: info, requiredType: requiredType)
    }

    /// Update engine configuration and propagate to active engine if possible.
    /// - Parameter configuration: New configuration to apply.
    public func updateConfiguration(_ configuration: AudioEngineConfiguration) async {
        // EQ is a capability requirement, not a transient engine setting. Keep
        // it attached when callers update playback preferences so a later
        // engine selection cannot silently return AudioKit while EQ is active.
        let updatedConfiguration = configuration.with(equalizerEnabled: equalizerConfiguration.isEnabled)
        let requiresEngineSwitch = currentEngine != nil &&
            currentEngineType != selectedEngineType(for: currentFormat, configuration: updatedConfiguration)
        self.configuration = updatedConfiguration
        if requiresEngineSwitch {
            pendingEngineSwitch = true
        }
        guard let engine = currentEngine else { return }

        do {
            try await engine.configure(with: updatedConfiguration)
        } catch {
            logger.warning("Failed to live-update engine configuration: \(error.localizedDescription, privacy: .private)")
        }
    }

    func bitPerfectEligibilityContext() async -> BitPerfectEligibilityContext {
        let applicationVolume: Float
        let engineEvidence: AudioEngineFormatEvidence?
        if let currentEngine {
            applicationVolume = await currentEngine.volume
            engineEvidence = await currentEngine.playbackFormatEvidence()
        } else {
            applicationVolume = 1
            engineEvidence = nil
        }

        return BitPerfectEligibilityContext(
            engineIdentifier: currentEngineType?.rawValue ?? "none",
            applicationVolume: applicationVolume,
            playbackRate: configuration.playbackRate,
            replayGainEnabled: configuration.replayGainMode != .off,
            equalizerEnabled: equalizerConfiguration.isEnabled,
            crossfadeEnabled: configuration.crossfadeDuration > 0,
            engineEvidence: engineEvidence
        )
    }

    /// Retain the desired EQ configuration and apply it to the active engine.
    ///
    /// The retained value is reapplied whenever `ensureEngine(for:)` creates,
    /// recreates, or reconfigures an engine.
    @discardableResult
    public func updateEqualizerConfiguration(
        _ configuration: EqualizerConfiguration
    ) async -> EqualizerApplicationResult {
        equalizerConfiguration = configuration
        let updatedConfiguration = self.configuration.with(equalizerEnabled: configuration.isEnabled)
        if updatedConfiguration.equalizerEnabled != self.configuration.equalizerEnabled {
            self.configuration = updatedConfiguration
            if let currentEngine {
                let selectedType = selectedEngineType(for: currentFormat, configuration: updatedConfiguration)
                let engineSupportsEQ = await currentEngine.supportsEQ
                let requiresEQEngine = configuration.isEnabled && !engineSupportsEQ
                if requiresEQEngine || selectedType != currentEngineType {
                    pendingEngineSwitch = true
                }
            }
        } else if configuration.isEnabled,
                  let currentEngine {
            let engineSupportsEQ = await currentEngine.supportsEQ
            if !engineSupportsEQ,
               selectedEngineType(for: currentFormat, configuration: updatedConfiguration) != currentEngineType {
                pendingEngineSwitch = true
            }
        }

        guard let engine = currentEngine else {
            return recordEqualizerApplicationResult(.waitingForEngine)
        }

        return await applyEqualizerConfiguration(to: engine)
    }

    /// Stop and release the current engine.
    public func cleanupCurrentEngine() async {
        guard let engine = currentEngine else { return }

        if await engine.isPlaying {
            await engine.stop()
        }

        await monitor.detachFromEngine()

        currentEngine = nil
        currentEngineType = nil
        currentFormat = nil

        logger.debug("Cleaned up current audio engine")
    }

    /// Discard and recreate engine objects invalidated by a media-services reset.
    ///
    /// The previous engine must not receive any calls after the reset. Its
    /// configuration and EQ state are retained by the manager and applied to the
    /// replacement produced by the factory.
    @discardableResult
    public func rebuildEngineAfterMediaServicesReset(
        for info: AudioFileInfo
    ) async throws -> AudioEngineService {
        let requiredType = engineFactory.selectEngineType(
            for: info.format,
            configuration: configuration
        )

        await discardEngineAfterMediaServicesReset()

        logger.notice(
            "Rebuilding \(requiredType.rawValue, privacy: .public) after media-services reset"
        )
        return try await recreateEngine(for: info, requiredType: requiredType)
    }

    /// Drop invalid engine references without invoking the engine.
    public func discardEngineAfterMediaServicesReset() async {
        pendingEngineSwitch = false
        guard currentEngine != nil else { return }

        await monitor.detachFromEngine()
        currentEngine = nil
        currentEngineType = nil
        currentFormat = nil
    }

    /// Force recreation of the engine on next playback by clearing cached instance.
    public func invalidateCurrentEngine() {
        currentEngine = nil
        currentEngineType = nil
        currentFormat = nil
        logger.debug("Invalidated cached engine reference")
    }

    /// Signal that the engine should be recreated on next ensureEngine() call.
    /// Use when changing engine preference during active playback.
    public func setPendingEngineSwitch() {
        pendingEngineSwitch = true
        logger.debug("Pending engine switch flagged for next track load")
    }

    // MARK: - Helpers

    private func recreateEngine(for info: AudioFileInfo, requiredType: AudioEngineType) async throws -> AudioEngineService {
        logger.debug("Creating new engine (\(requiredType.rawValue, privacy: .public)) for format: \(info.format.displayName, privacy: .public)")

        await cleanupCurrentEngine()

        let engine = try await engineFactory.makeEngine(
            for: info.format,
            configuration: configuration,
        )

        await monitor.attachToEngine(engine)

        currentEngine = engine
        currentEngineType = requiredType
        currentFormat = info.format
        await applyEqualizerConfiguration(to: engine)

        Metrics.increment(.engineSwitch, metadata: [
            "type": requiredType.rawValue,
            "format": LogPrivacy.truncated(info.format.displayName, limit: 24)
        ])

        return engine
    }

    private func selectedEngineType(
        for format: AudioFormat?,
        configuration: AudioEngineConfiguration
    ) -> AudioEngineType? {
        guard let format else { return nil }
        return engineFactory.selectEngineType(for: format, configuration: configuration)
    }

    @discardableResult
    private func applyEqualizerConfiguration(
        to engine: AudioEngineService
    ) async -> EqualizerApplicationResult {
        let engineType = currentEngineType

        guard equalizerConfiguration.isEnabled else {
            if await engine.supportsEQ {
                do {
                    try await engine.applyEQ(equalizerConfiguration)
                } catch {
                    logger.error(
                        "Failed to disable equalizer: \(error.localizedDescription, privacy: .private)"
                    )
                    return recordEqualizerApplicationResult(.failed(engine: engineType))
                }
            }
            return recordEqualizerApplicationResult(.applied(engine: engineType))
        }

        guard await engine.supportsEQ else {
            logger.warning(
                "Equalizer is unavailable for \(engineType?.rawValue ?? "the current engine", privacy: .public)"
            )
            return recordEqualizerApplicationResult(.unsupported(engine: engineType))
        }

        do {
            try await engine.applyEQ(equalizerConfiguration)
            return recordEqualizerApplicationResult(.applied(engine: engineType))
        } catch {
            logger.error(
                "Failed to apply equalizer: \(error.localizedDescription, privacy: .private)"
            )
            return recordEqualizerApplicationResult(.failed(engine: engineType))
        }
    }

    @discardableResult
    private func recordEqualizerApplicationResult(
        _ result: EqualizerApplicationResult
    ) -> EqualizerApplicationResult {
        equalizerApplicationResult = result
        equalizerApplicationResultHandler?(result)
        return result
    }

    // MARK: - Testing Support

    public func overrideCurrentEngine(_ engine: AudioEngineService, type: AudioEngineType? = nil, format: AudioFormat? = nil) {
        currentEngine = engine
        currentEngineType = type
        currentFormat = format

        Task { @MainActor [weak self] in
            guard let self else { return }
            await monitor.attachToEngine(engine)
            do {
                try await engine.configure(with: configuration)
            } catch {
                logger.warning("Failed to configure overridden engine: \(error.localizedDescription, privacy: .private)")
            }
        }
    }
}
