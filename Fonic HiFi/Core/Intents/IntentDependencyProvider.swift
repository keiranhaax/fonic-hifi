//
//  IntentDependencyProvider.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import Foundation
import OSLog

/// Provides access to app services for App Intents
/// App Intents with LiveActivityIntent run in the app process, so they can access
/// the live AudioEngineFacade instance directly via this provider.
@MainActor
public final class IntentDependencyProvider {
    // MARK: - Singleton

    public static let shared = IntentDependencyProvider()

    // MARK: - Dependencies

    private weak var _audioEngine: AudioEngineFacade?
    private weak var _widgetCoordinator: WidgetDataCoordinator?

    private let logger = Log.logger(.widget)

    // MARK: - Initialization

    private init() {}

    // MARK: - Configuration

    /// Configure the provider with app services. Call this during app initialization.
    public func configure(
        audioEngine: AudioEngineFacade,
        widgetCoordinator: WidgetDataCoordinator?
    ) {
        _audioEngine = audioEngine
        _widgetCoordinator = widgetCoordinator
        logger.info("IntentDependencyProvider configured")
    }

    // MARK: - Access

    /// Returns the AudioEngineFacade if available and ready
    public var audioEngine: AudioEngineFacade? {
        guard let engine = _audioEngine, engine.isReady else {
            logger.warning("AudioEngineFacade not available or not ready for intent")
            return nil
        }
        return engine
    }

    /// Returns the WidgetDataCoordinator if available
    public var widgetCoordinator: WidgetDataCoordinator? {
        _widgetCoordinator
    }

    /// Check if the provider is configured and ready
    public var isReady: Bool {
        _audioEngine?.isReady ?? false
    }
}
