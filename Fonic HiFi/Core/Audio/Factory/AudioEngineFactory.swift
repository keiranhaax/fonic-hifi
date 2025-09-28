//
//  AudioEngineFactory.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation
import os.log

/// Factory for creating appropriate audio engine instances based on format and configuration
@MainActor
public final class AudioEngineFactory {
    
    // MARK: - Properties
    
    /// Logger for diagnostics
    private static let logger = Logger(subsystem: "com.fonicHiFi", category: "AudioEngineFactory")
    
    /// Format detection service
    private let formatDetector: FormatDetectionService
    
    /// Registered engine types and their availability
    private var availableEngines: [AudioEngineType: Bool] = [
        .avAudioEngine: true,
        .audioKitEngine: true  // AudioKit is now available
    ]
    
    // MARK: - Initialization
    
    public init(formatDetector: FormatDetectionService = AudioFormatDetectionManager.shared) {
        self.formatDetector = formatDetector
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
        configuration: AudioEngineConfiguration
    ) async throws -> AudioEngineService {
        
        // Determine the best engine type
        let engineType = selectEngineType(for: format, configuration: configuration)
        
        Self.logger.info("Selected \(engineType.rawValue) for format: \(format.displayName)")
        
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
        configuration: AudioEngineConfiguration
    ) async throws -> AudioEngineService {
        
        // Detect format
        let fileInfo = try await formatDetector.detectFormat(at: url)
        
        // Create engine for detected format
        return try await makeEngine(for: fileInfo.format, configuration: configuration)
    }
    
    // MARK: - Engine Selection Logic
    
    public func selectEngineType(
        for format: AudioFormat,
        configuration: AudioEngineConfiguration
    ) -> AudioEngineType {

        // Check user preference first - it overrides performance mode selection
        let preferredEngine = UserDefaults.standard.string(forKey: "preferredAudioEngine")
        if let preferredEngine = preferredEngine {
            switch preferredEngine {
            case "AudioKit", "AudioKitEngine":
                if availableEngines[.audioKitEngine] == true && AudioEngineType.audioKitEngine.canHandle(format) {
                    return .audioKitEngine
                }
            default:
                break
            }
        }

        // Performance mode influences selection
        switch configuration.performanceMode {
        case .efficiency:
            // Prefer native engine for battery life
            if canUseAVAudioEngine(for: format) {
                return .avAudioEngine
            }
            
        case .quality:
            // Prefer high-quality engines for quality mode
            if availableEngines[.audioKitEngine] == true && AudioEngineType.audioKitEngine.canHandle(format) {
                return .audioKitEngine
            }
            if canUseAVAudioEngine(for: format) {
                return .avAudioEngine
            }
            
        case .balanced:
            // Use AudioKit for balanced performance if available
            if availableEngines[.audioKitEngine] == true && AudioEngineType.audioKitEngine.canHandle(format) {
                return .audioKitEngine
            }
            if canUseAVAudioEngine(for: format) {
                return .avAudioEngine
            }
            break
        }
        
        // Standard selection logic - try AudioKit first if available
        if availableEngines[.audioKitEngine] == true && AudioEngineType.audioKitEngine.canHandle(format) {
            return .audioKitEngine
        }

        if canUseAVAudioEngine(for: format) {
            return .avAudioEngine
        }
        
        // Last resort: try AVAudioEngine anyway
        Self.logger.warning("No specialized engine available for \(format.displayName), attempting AVAudioEngine")
        return .avAudioEngine
    }
    
    private func canUseAVAudioEngine(for format: AudioFormat) -> Bool {
        return AVAudioEngineConfig.isFormatNativelySupported(format)
    }
    
    // MARK: - Engine Creation
    
    private func createEngine(of type: AudioEngineType) async throws -> AudioEngineService {
        guard let isAvailable = availableEngines[type], isAvailable else {
            throw AudioError.engineInitializationFailed(
                reason: "\(type.displayName) is not available"
            )
        }
        
        switch type {
        case .avAudioEngine:
            return AVAudioEngineAdapter()

        case .audioKitEngine:
            let adapter = AudioKitEngineAdapter()

            // Check if AudioKit initialized successfully
            do {
                try adapter.checkInitialization()
                return adapter
            } catch {
                // AudioKit failed to initialize, mark as unavailable and fall back
                Self.logger.error("AudioKit initialization failed: \(error.localizedDescription)")
                registerEngine(.audioKitEngine, isAvailable: false)

                // Fall back to AVAudioEngine
                Self.logger.info("Falling back to AVAudioEngine due to AudioKit failure")
                return AVAudioEngineAdapter()
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
        Self.logger.info("Registered \(type.rawValue): \(isAvailable ? "available" : "unavailable")")
    }
    
    /// Check if an engine type is available
    /// - Parameter type: Engine type to check
    /// - Returns: true if engine is available
    public func isEngineAvailable(_ type: AudioEngineType) -> Bool {
        return availableEngines[type] ?? false
    }
    
    /// Get all available engine types
    /// - Returns: Array of available engine types
    public func availableEngineTypes() -> [AudioEngineType] {
        return availableEngines.compactMap { $0.value ? $0.key : nil }
    }
    
    // MARK: - Diagnostics
    
    /// Get diagnostic information about engine selection for a format
    /// - Parameter format: Audio format to analyze
    /// - Returns: Diagnostic information
    public func diagnostics(for format: AudioFormat) -> EngineDiagnostics {
        let preferredEngine = selectEngineType(
            for: format,
            configuration: AudioEngineConfiguration()
        )
        
        let alternativeEngines = AudioEngineType.allCases
            .filter { $0 != preferredEngine && $0.canHandle(format) }
            .filter { availableEngines[$0] == true }
        
        return EngineDiagnostics(
            format: format,
            preferredEngine: preferredEngine,
            alternativeEngines: alternativeEngines,
            isPreferredAvailable: availableEngines[preferredEngine] ?? false
        )
    }
}

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
            result += "\nAlternatives: \(alternativeEngines.map { $0.displayName }.joined(separator: ", "))"
        }
        
        return result
    }
}
