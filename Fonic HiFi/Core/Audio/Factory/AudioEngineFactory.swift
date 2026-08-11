//
//  AudioEngineFactory.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation
import OSLog

@MainActor
public protocol AudioEngineFactoring {
    func selectEngineType(
        for format: AudioFormat,
        configuration: AudioEngineConfiguration,
    ) -> AudioEngineType

    func makeEngine(
        for format: AudioFormat,
        configuration: AudioEngineConfiguration,
    ) async throws -> AudioEngineService
}

/// Factory for creating appropriate audio engine instances based on format and configuration
@MainActor
public final class AudioEngineFactory {
    // MARK: - Properties

    /// Logger for diagnostics
    private static let logger = Log.logger(.audioEngineFactory)

    /// Format detection service
    private let formatDetector: any FormatDetectionService

    /// Persisted user preference source
    private let preferences: UserDefaults

    /// Optional diagnostics sink for AVAudioEngine route-recovery failures.
    private let configurationRecoveryFailureHandler: ConfigurationRecoveryFailureHandler?

    /// Registered engine types and their availability
    private var availableEngines: [AudioEngineType: Bool] = [
        .avAudioEngine: true,
        .audioKitEngine: true, // AudioKit is now available
    ]

    // MARK: - Initialization

    public init(
        formatDetector: any FormatDetectionService = AudioFormatDetectionManager.shared,
        preferences: UserDefaults = .standard,
        configurationRecoveryFailureHandler: ConfigurationRecoveryFailureHandler? = nil,
    ) {
        self.formatDetector = formatDetector
        self.preferences = preferences
        self.configurationRecoveryFailureHandler = configurationRecoveryFailureHandler
    }

    // MARK: - Factory Methods

    /// Create an audio engine for the specified format and configuration
    /// - Parameters:
    ///   - format: Audio format to play
    ///   - configuration: Engine configuration including performance mode
    /// - Returns: Appropriate AudioEngineService implementation
    /// - Throws: AudioError if no suitable engine is available
    public func makeEngine(
        for format: AudioFormat,
        configuration: AudioEngineConfiguration,
    ) async throws -> AudioEngineService {
        // Determine the best engine type
        let engineType = selectEngineType(for: format, configuration: configuration)

        Self.logger.info(
            "Selected \(engineType.rawValue, privacy: .public) for format: \(format.displayName, privacy: .public)"
        )

        // Create and configure the engine
        let engine = try await createEngine(of: engineType)
        try await engine.configure(with: configuration)

        return engine
    }

    /// Create an engine for a file URL by detecting its format first
    /// - Parameters:
    ///   - url: File URL to analyze
    ///   - configuration: Engine configuration
    /// - Returns: Appropriate AudioEngineService implementation
    /// - Throws: AudioError if format detection fails or no engine available
    public func makeEngine(
        for url: URL,
        configuration: AudioEngineConfiguration,
    ) async throws -> AudioEngineService {
        // Detect format
        let fileInfo = try await formatDetector.detectFormat(at: url)

        // Create engine for detected format
        return try await makeEngine(for: fileInfo.format, configuration: configuration)
    }

    // MARK: - Engine Selection Logic

    public func selectEngineType(
        for format: AudioFormat,
        configuration: AudioEngineConfiguration,
    ) -> AudioEngineType {
        let requiresEQ = configuration.equalizerEnabled

        // A compatible user preference overrides performance-mode selection.
        if let preferredEngine = preferredEngineType(for: format, requiringEQ: requiresEQ) {
            return preferredEngine
        }

        // Performance mode influences selection
        switch configuration.performanceMode {
        case .efficiency:
            // Prefer native engine for battery life
            if canUseAVAudioEngine(for: format), !requiresEQ || AudioEngineType.avAudioEngine.supportsEQ {
                return .avAudioEngine
            }

        case .quality:
            // Prefer high-quality engines for quality mode
            if availableEngines[.audioKitEngine] == true,
               AudioEngineType.audioKitEngine.canHandle(format),
               !requiresEQ || AudioEngineType.audioKitEngine.supportsEQ {
                return .audioKitEngine
            }
            if canUseAVAudioEngine(for: format), !requiresEQ || AudioEngineType.avAudioEngine.supportsEQ {
                return .avAudioEngine
            }

        case .balanced:
            // Use AudioKit for balanced performance if available
            if availableEngines[.audioKitEngine] == true,
               AudioEngineType.audioKitEngine.canHandle(format),
               !requiresEQ || AudioEngineType.audioKitEngine.supportsEQ {
                return .audioKitEngine
            }
            if canUseAVAudioEngine(for: format), !requiresEQ || AudioEngineType.avAudioEngine.supportsEQ {
                return .avAudioEngine
            }
        }

        // Standard selection logic - try AudioKit first if available
        if availableEngines[.audioKitEngine] == true,
           AudioEngineType.audioKitEngine.canHandle(format),
           !requiresEQ || AudioEngineType.audioKitEngine.supportsEQ {
            return .audioKitEngine
        }

        if canUseAVAudioEngine(for: format), !requiresEQ || AudioEngineType.avAudioEngine.supportsEQ {
            return .avAudioEngine
        }

        if requiresEQ {
            Self.logger.error(
                "No EQ-capable engine can decode \(format.displayName, privacy: .public); preserving format fallback"
            )
            if availableEngines[.audioKitEngine] == true,
               AudioEngineType.audioKitEngine.canHandle(format) {
                return .audioKitEngine
            }
        }

        // Last resort: try AVAudioEngine anyway
        Self.logger.warning(
            "No specialized engine available for \(format.displayName, privacy: .public), attempting AVAudioEngine"
        )
        return .avAudioEngine
    }

    private func preferredEngineType(
        for format: AudioFormat,
        requiringEQ: Bool = false
    ) -> AudioEngineType? {
        let storedValue = preferences.string(forKey: AudioEnginePreference.storageKey)
        let preference = AudioEnginePreference(storedValue: storedValue)

        if let canonicalValue = preference.canonicalStoredValue,
           canonicalValue != storedValue {
            preferences.set(canonicalValue, forKey: AudioEnginePreference.storageKey)
            Self.logger.info("Migrated legacy audio engine preference")
        }

        switch preference {
        case .automatic:
            return nil
        case .unsupported:
            Self.logger.warning("Unsupported audio engine preference; using automatic engine selection")
            return nil
        case .requested(let requestedEngine):
            guard availableEngines[requestedEngine] == true else {
                Self.logger.warning(
                    "Requested \(requestedEngine.rawValue, privacy: .public) is unavailable; using automatic engine selection"
                )
                return nil
            }

            guard requestedEngine.canHandle(format) else {
                Self.logger.warning(
                    "Requested \(requestedEngine.rawValue, privacy: .public) cannot handle \(format.displayName, privacy: .public); using automatic engine selection"
                )
                return nil
            }

            guard !requiringEQ || requestedEngine.supportsEQ else {
                Self.logger.warning(
                    "Requested \(requestedEngine.rawValue, privacy: .public) does not support enabled EQ; using automatic EQ-capable selection"
                )
                return nil
            }

            return requestedEngine
        }
    }

    private func canUseAVAudioEngine(for format: AudioFormat) -> Bool {
        AVAudioEngineConfig.isFormatNativelySupported(format)
    }

    // MARK: - Engine Creation

    private func createEngine(of type: AudioEngineType) async throws -> AudioEngineService {
        guard let isAvailable = availableEngines[type], isAvailable else {
            throw AudioError.engineInitializationFailed(
                reason: "\(type.displayName) is not available",
            )
        }

        switch type {
        case .avAudioEngine:
            return try AVAudioEngineAdapter(
                configurationRecoveryFailureHandler: configurationRecoveryFailureHandler
            )

        case .audioKitEngine:
            let adapter = AudioKitEngineAdapter()

            // Check if AudioKit initialized successfully
            do {
                try adapter.checkInitialization()
                return adapter
            } catch {
                // AudioKit failed to initialize, mark as unavailable and fall back
                Self.logger.error(
                    "AudioKit initialization failed: \(error.localizedDescription, privacy: .private)"
                )
                registerEngine(.audioKitEngine, isAvailable: false)

                // Fall back to AVAudioEngine
                Self.logger.info("Falling back to AVAudioEngine due to AudioKit failure")
                return try AVAudioEngineAdapter(
                    configurationRecoveryFailureHandler: configurationRecoveryFailureHandler
                )
            }
        }
    }

    // MARK: - Engine Registration

    /// Register availability of an engine type
    /// - Parameters:
    ///   - type: Engine type to register
    ///   - isAvailable: Whether the engine is available
    public func registerEngine(_ type: AudioEngineType, isAvailable: Bool) {
        availableEngines[type] = isAvailable
        Self.logger.info(
            "Registered \(type.rawValue, privacy: .public): \(isAvailable ? "available" : "unavailable", privacy: .public)"
        )
    }

    /// Check if an engine type is available
    /// - Parameter type: Engine type to check
    /// - Returns: true if engine is available
    public func isEngineAvailable(_ type: AudioEngineType) -> Bool {
        availableEngines[type] ?? false
    }

    /// Get all available engine types
    /// - Returns: Array of available engine types
    public func availableEngineTypes() -> [AudioEngineType] {
        availableEngines.compactMap { $0.value ? $0.key : nil }
    }

    // MARK: - Diagnostics

    /// Get diagnostic information about engine selection for a format
    /// - Parameter format: Audio format to analyze
    /// - Returns: Diagnostic information
    public func diagnostics(for format: AudioFormat) -> EngineDiagnostics {
        let preferredEngine = selectEngineType(
            for: format,
            configuration: AudioEngineConfiguration(),
        )

        let alternativeEngines = AudioEngineType.allCases
            .filter { $0 != preferredEngine && $0.canHandle(format) }
            .filter { availableEngines[$0] == true }

        return EngineDiagnostics(
            format: format,
            preferredEngine: preferredEngine,
            alternativeEngines: alternativeEngines,
            isPreferredAvailable: availableEngines[preferredEngine] ?? false,
        )
    }
}

extension AudioEngineFactory: AudioEngineFactoring {}

// MARK: - Diagnostics

/// Diagnostic information about engine selection
public struct EngineDiagnostics: Sendable {
    public let format: AudioFormat
    public let preferredEngine: AudioEngineType
    public let alternativeEngines: [AudioEngineType]
    public let isPreferredAvailable: Bool

    public var summary: String {
        var result = "Format: \(format.displayName)\n"
        result += "Preferred Engine: \(preferredEngine.displayName)"

        if !isPreferredAvailable {
            result += " (NOT AVAILABLE)"
        }

        if !alternativeEngines.isEmpty {
            result += "\nAlternatives: \(alternativeEngines.map(\.displayName).joined(separator: ", "))"
        }

        return result
    }
}
