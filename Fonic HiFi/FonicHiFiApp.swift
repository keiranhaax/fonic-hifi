//
//  FonicHiFiApp.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import OSLog
import SwiftData
import SwiftUI

@main
struct FonicHiFiApp: App {
    // MARK: - Properties

    @StateObject private var dataManager: DataManager
    @StateObject private var audioService: AudioEngineFacade
    @StateObject private var importService: LibraryImportService

    @State private var launchError: LaunchError?
    @State private var showInitializationError: Bool
    @State private var isUsingFallbackServices: Bool

    private let logger = Logger(subsystem: "com.fonichifi.app", category: "FonicHiFiApp")

    // App launch time tracking
    private let appLaunchStartTime = Date()
    private let performanceMonitor = PerformanceMonitor()

    // MARK: - Initialization

    init() {
        // Disable SwiftUI's async rendering if it's causing issues
        UserDefaults.standard.set(false, forKey: "SwiftUI.Animation.AsyncRendering")

        // Register custom SwiftData transformers
        UUIDArrayTransformer.register()

        // Create logger early for error reporting
        let initLogger = Logger(subsystem: "com.fonichifi.app", category: "FonicHiFiApp.init")

        _launchError = State(initialValue: nil)
        _showInitializationError = State(initialValue: false)
        _isUsingFallbackServices = State(initialValue: false)

        do {
            let dataManager = try DataManager()
            let playbackStateManager = PlaybackStateManager() // Shared instance

            // Create AudioMonitor with performance monitor connection
            let audioMonitor = AudioMonitor(performanceMonitor: performanceMonitor)

            let audioService = AudioEngineFacade(
                stateManager: playbackStateManager,
                monitor: audioMonitor,
            )
            let importService = LibraryImportService(
                trackDataActor: dataManager.trackDataActor,
                metadataExtractor: dataManager.metadataExtractor,
            )

            _dataManager = StateObject(wrappedValue: dataManager)
            _audioService = StateObject(wrappedValue: audioService)
            _importService = StateObject(wrappedValue: importService)

        } catch {
            initLogger.critical("Failed to initialize app: \(error.localizedDescription)")
            let fallback = FonicHiFiApp.makeFallbackServices(
                performanceMonitor: performanceMonitor,
                errorLogger: initLogger,
            )

            _dataManager = StateObject(wrappedValue: fallback.dataManager)
            _audioService = StateObject(wrappedValue: fallback.audioService)
            _importService = StateObject(wrappedValue: fallback.importService)

            _launchError = State(initialValue: LaunchError(message: error.localizedDescription))
            _showInitializationError = State(initialValue: true)
            _isUsingFallbackServices = State(initialValue: true)
        }
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            ContentView()
                .audioEngine(audioService)
                .dataManager(dataManager)
                .importService(importService)
                .modelContext(dataManager.mainContext)
                .task {
                    await initializeApp()
                }
                .overlay(alignment: .top) {
                    if isUsingFallbackServices {
                        Text("Running in limited mode due to initialization issues.")
                            .font(.footnote)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(.ultraThinMaterial, in: Capsule())
                            .padding()
                    }
                }
                .alert("Initialization Issue", isPresented: $showInitializationError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    if let launchError {
                        Text(launchError.errorDescription ?? "An unknown error occurred. The app is running with limited functionality.")
                    } else {
                        Text("The app encountered an issue during startup and is running with limited functionality.")
                    }
                }
        }
        .modelContainer(dataManager.container)
    }

    // MARK: - App Initialization

    @MainActor
    private func initializeApp() async {
        logger.info("Initializing Fonic HiFi app...")

        do {
            // Initialize audio service with proper error handling
            try await audioService.initialize()
            logger.info("Audio service initialized successfully")

            // Perform any other startup tasks
            await performStartupTasks()

            // Track app launch time
            let launchDuration = Date().timeIntervalSince(appLaunchStartTime)
            await performanceMonitor.recordAppLaunchTime(launchDuration)
            logger.info("App launch completed in \(String(format: "%.2f", launchDuration)) seconds")

        } catch {
            logger.error("Failed to initialize app: \(error.localizedDescription)")

            // Track app launch time even if initialization fails
            let launchDuration = Date().timeIntervalSince(appLaunchStartTime)
            await performanceMonitor.recordAppLaunchTime(launchDuration)

            // Record the error in performance monitor
            await performanceMonitor.recordError(error, context: "App initialization")

            // You could show an alert to the user here if needed
            // For now, we'll just log the error and continue with limited functionality
        }
    }

    @MainActor
    private func performStartupTasks() async {
        // Cleanup missing files (in background)
        Task {
            do {
                let removedCount = try await dataManager.cleanupMissingFiles()
                if removedCount > 0 {
                    logger.info("Cleaned up \(removedCount) missing files from library")
                }
            } catch {
                logger.error("Failed to cleanup missing files: \(error.localizedDescription)")
            }
        }

        // Log library statistics
        Task {
            do {
                let stats = try await dataManager.getLibraryStatistics()
                logger.info("Library stats: \(stats.trackCount) tracks, \(stats.albumCount) albums, \(stats.artistCount) artists")
            } catch {
                logger.error("Failed to get library statistics: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Launch Error Representation

private struct LaunchError: Identifiable, LocalizedError {
    let id = UUID()
    let message: String

    var errorDescription: String? { message }
}

// MARK: - Fallback Service Construction

private extension FonicHiFiApp {
    typealias AppServices = (dataManager: DataManager, audioService: AudioEngineFacade, importService: LibraryImportService)

    static func makeFallbackServices(
        performanceMonitor: PerformanceMonitor,
        errorLogger: Logger,
    ) -> AppServices {
        let playbackStateManager = PlaybackStateManager()
        let audioMonitor = AudioMonitor(performanceMonitor: performanceMonitor)
        let audioService = AudioEngineFacade(
            stateManager: playbackStateManager,
            monitor: audioMonitor,
        )

        let fallbackDataManager = DataManager.makeFallbackDataManager()
            ?? DataManager.makePreviewDataManager()

        guard let dataManager = fallbackDataManager else {
            errorLogger.critical("Unable to provide a fallback DataManager; using fresh in-memory instance")
            let resilientManager = DataManager.ensureFallbackDataManager()
            let importService = LibraryImportService(
                trackDataActor: resilientManager.trackDataActor,
                metadataExtractor: resilientManager.metadataExtractor,
            )
            return (resilientManager, audioService, importService)
        }

        let importService = LibraryImportService(
            trackDataActor: dataManager.trackDataActor,
            metadataExtractor: dataManager.metadataExtractor,
        )

        return (dataManager, audioService, importService)
    }
}
