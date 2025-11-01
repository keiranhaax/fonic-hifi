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
    private let monitor: AudioMonitor
    private let logger = Log.logger(.audioEngineManager)

    // MARK: - State

    private(set) var currentEngine: AudioEngineService?
    private(set) var currentEngineType: AudioEngineType?
    private(set) var currentFormat: AudioFormat?

    public private(set) var configuration: AudioEngineConfiguration

    // MARK: - Initialization

    public init(
        configuration: AudioEngineConfiguration,
        engineFactory: any AudioEngineFactoring,
        monitor: AudioMonitor,
    ) {
        self.configuration = configuration
        self.engineFactory = engineFactory
        self.monitor = monitor

        logger.debug("AudioEngineManager initialised with configuration: \(String(describing: configuration.performanceMode))")
    }

    // MARK: - Engine Lifecycle

    /// Ensure an engine capable of handling the provided format is available.
    /// - Parameter info: Detected file information describing required capabilities.
    /// - Returns: Configured engine ready for playback.
    /// - Throws: `AudioError` if no suitable engine can be prepared.
    @discardableResult
    public func ensureEngine(for info: AudioFileInfo) async throws -> AudioEngineService {
        let requiredType = engineFactory.selectEngineType(
            for: info.format,
            configuration: configuration,
        )

        if let engine = currentEngine, currentEngineType == requiredType {
            logger.debug("Reusing existing engine for format: \(info.format.displayName)")
            do {
                try await engine.configure(with: configuration)
                return engine
            } catch {
                logger.error("Failed to reconfigure engine: \(error.localizedDescription)")
                return try await recreateEngine(for: info, requiredType: requiredType)
            }
        }

        return try await recreateEngine(for: info, requiredType: requiredType)
    }

    /// Update engine configuration and propagate to active engine if possible.
    /// - Parameter configuration: New configuration to apply.
    public func updateConfiguration(_ configuration: AudioEngineConfiguration) async {
        self.configuration = configuration
        guard let engine = currentEngine else { return }

        do {
            try await engine.configure(with: configuration)
        } catch {
            logger.warning("Failed to live-update engine configuration: \(error.localizedDescription)")
        }
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

    /// Force recreation of the engine on next playback by clearing cached instance.
    public func invalidateCurrentEngine() {
        currentEngine = nil
        currentEngineType = nil
        currentFormat = nil
        logger.debug("Invalidated cached engine reference")
    }

    // MARK: - Helpers

    private func recreateEngine(for info: AudioFileInfo, requiredType: AudioEngineType) async throws -> AudioEngineService {
        logger.debug("Creating new engine (\(requiredType.rawValue)) for format: \(info.format.displayName)")

        await cleanupCurrentEngine()

        let engine = try await engineFactory.makeEngine(
            for: info.format,
            configuration: configuration,
        )

        await monitor.attachToEngine(engine)

        currentEngine = engine
        currentEngineType = requiredType
        currentFormat = info.format

        Metrics.increment(.engineSwitch, metadata: [
            "type": requiredType.rawValue,
            "format": LogPrivacy.truncated(info.format.displayName, limit: 24)
        ])

        return engine
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
                logger.warning("Failed to configure overridden engine: \(error.localizedDescription)")
            }
        }
    }
}
