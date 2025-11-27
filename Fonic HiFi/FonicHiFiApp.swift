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

    private let dataManager: DataManager?
    private let audioService: AudioEngineFacade
    private let importService: LibraryImportService?
    private let artworkService: ArtworkService?
    private let widgetCoordinator: WidgetDataCoordinator?
    private let liveActivityManager: LiveActivityManager?

    @State private var launchError: LaunchError?
    @State private var showInitializationError: Bool
    @State private var isUsingFallbackServices: Bool

    private let logger = Log.logger(.app)
    private let fallbackError: DataManagerError?

    // App launch time tracking
    private let appLaunchStartTime = Date()
    private let performanceMonitor = PerformanceMonitor()

    // MARK: - Initialization

    init() {
        // Disable SwiftUI's async rendering if it's causing issues
        UserDefaults.standard.set(false, forKey: "SwiftUI.Animation.AsyncRendering")

        // Create logger early for error reporting
        let initLogger = Log.logger(.appLifecycle)

        let resolution = FonicHiFiApp.resolveInitialization(
            performanceMonitor: performanceMonitor,
            initLogger: initLogger,
        )

        dataManager = resolution.dataManager
        audioService = resolution.audioService
        importService = resolution.importService
        artworkService = resolution.artworkService
        widgetCoordinator = resolution.widgetCoordinator
        liveActivityManager = resolution.liveActivityManager
        fallbackError = resolution.fallbackError

        var launchError = resolution.launchError
        let showInitializationError = resolution.showInitializationError
        let usingFallback = resolution.usingFallback
        let resolvedDataManager = resolution.dataManager

        let fallbackActive = usingFallback || (resolvedDataManager?.isFallback ?? false)

        _launchError = State(initialValue: launchError)
        _showInitializationError = State(initialValue: showInitializationError)
        _isUsingFallbackServices = State(initialValue: fallbackActive)

        if resolvedDataManager == nil {
            if launchError == nil {
                let fallbackMessage = fallbackError?.localizedDescription
                    ?? "Fonic HiFi could not initialize a recovery data store."
                let fallbackLaunchError = LaunchError(message: fallbackMessage)
                launchError = fallbackLaunchError
                _launchError = State(initialValue: fallbackLaunchError)
            }
            _isUsingFallbackServices = State(initialValue: true)
            _showInitializationError = State(initialValue: true)
        }

        if launchError == nil, resolvedDataManager?.isFallback == true {
            launchError = LaunchError(
                message: "Fonic HiFi is operating in recovery mode due to a storage issue.",
            )
            _launchError = State(initialValue: launchError)
            _showInitializationError = State(initialValue: true)
        }
    }

    // MARK: - Scene

    var body: some Scene {
        WindowGroup {
            rootView
        }
    }

    @ViewBuilder
    private var rootView: some View {
        if let dataManager {
            mainAppView(using: dataManager)
        } else {
            fallbackView
        }
    }

    private func mainAppView(using dataManager: DataManager) -> some View {
        ContentView()
            .audioEngine(audioService)
            .dataManager(dataManager)
            .libraryRepository(dataManager.makeLibraryRepository())
            .importService(importService)
            .artworkService(artworkService)
            .modelContext(dataManager.mainContext)
            .task {
                await initializeApp()
            }
            .overlay(alignment: .top) {
                if let recoveryState = dataManager.importRecoveryState {
                    RecoveryModeBanner(state: recoveryState)
                } else if isUsingFallbackServices {
                    RecoveryModeBanner(
                        state: .init(
                            mode: .ephemeralStorage,
                            headline: "Limited Mode Active",
                            message: "Fonic HiFi is using fallback services due to initialization issues.",
                            guidance: "Restart the app after the issue is resolved to return to full functionality.",
                        ),
                    )
                }
            }
            .alert("Initialization Issue", isPresented: $showInitializationError) {
                Button("OK", role: .cancel) {}
            } message: {
                if let launchError {
                    let fallbackDescription = launchError.errorDescription
                        ?? "An unknown error occurred. The app is running with limited functionality."
                    Text(fallbackDescription)
                } else {
                    Text(
                        "The app encountered an issue during startup and is running with limited functionality.",
                    )
                }
            }
            .modelContainer(dataManager.container)
    }

    private var fallbackView: some View {
        RecoveryUnavailableView(
            launchError: launchError,
            fallbackError: fallbackError,
        )
        .audioEngine(audioService)
        .importService(importService)
    }

    // MARK: - App Initialization

    @MainActor
    private func initializeApp() async {
        logger.info("Initializing Fonic HiFi app...")

        do {
            // Initialize audio service with proper error handling
            try await audioService.initialize()
            logger.info("Audio service initialized successfully")

            // Configure intent dependency provider for widget/Live Activity intents
            IntentDependencyProvider.shared.configure(
                audioEngine: audioService,
                widgetCoordinator: widgetCoordinator
            )
            logger.info("IntentDependencyProvider configured")

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
        guard let dataManager else { return }

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
                let statsMessage = "Library stats: \(stats.trackCount) tracks, \(stats.albumCount) albums, " +
                    "\(stats.artistCount) artists"
                logger.info("\(statsMessage)")
            } catch {
                logger.error("Failed to get library statistics: \(error.localizedDescription)")
            }
        }
    }
}

// MARK: - Launch Error Representation

struct LaunchError: Identifiable, LocalizedError {
    let id = UUID()
    let message: String

    var errorDescription: String? { message }
}

// MARK: - Fallback Service Construction

private extension FonicHiFiApp {
    struct InitializationResult {
        let dataManager: DataManager?
        let audioService: AudioEngineFacade
        let importService: LibraryImportService?
        let artworkService: ArtworkService?
        let widgetCoordinator: WidgetDataCoordinator?
        let liveActivityManager: LiveActivityManager?
        let launchError: LaunchError?
        let showInitializationError: Bool
        let usingFallback: Bool
        let fallbackError: DataManagerError?
    }

    struct AppServices {
        let dataManager: DataManager?
        let audioService: AudioEngineFacade
        let importService: LibraryImportService?
        let artworkService: ArtworkService?
        let widgetCoordinator: WidgetDataCoordinator?
        let liveActivityManager: LiveActivityManager?
        let recoveryError: DataManagerError?
    }

    static func resolveInitialization(
        performanceMonitor: PerformanceMonitor,
        initLogger: Logger,
    ) -> InitializationResult {
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("-UITestPreviewData"),
           let previewServices = makePreviewServices(performanceMonitor: performanceMonitor) {
            return InitializationResult(
                dataManager: previewServices.dataManager,
                audioService: previewServices.audioService,
                importService: previewServices.importService,
                artworkService: previewServices.artworkService,
                widgetCoordinator: previewServices.widgetCoordinator,
                liveActivityManager: previewServices.liveActivityManager,
                launchError: nil,
                showInitializationError: false,
                usingFallback: previewServices.dataManager?.isFallback ?? false,
                fallbackError: previewServices.recoveryError
            )
        }

        do {
            let services = try makePrimaryServices(performanceMonitor: performanceMonitor)
            return InitializationResult(
                dataManager: services.dataManager,
                audioService: services.audioService,
                importService: services.importService,
                artworkService: services.artworkService,
                widgetCoordinator: services.widgetCoordinator,
                liveActivityManager: services.liveActivityManager,
                launchError: nil,
                showInitializationError: false,
                usingFallback: false,
                fallbackError: nil,
            )
        } catch {
            initLogger.critical("Failed to initialize app: \(error.localizedDescription)")
            let fallback = makeFallbackServices(
                performanceMonitor: performanceMonitor,
                errorLogger: initLogger,
            )
            return InitializationResult(
                dataManager: fallback.dataManager,
                audioService: fallback.audioService,
                importService: fallback.importService,
                artworkService: fallback.artworkService,
                widgetCoordinator: fallback.widgetCoordinator,
                liveActivityManager: fallback.liveActivityManager,
                launchError: LaunchError(message: error.localizedDescription),
                showInitializationError: true,
                usingFallback: fallback.dataManager != nil,
                fallbackError: fallback.recoveryError,
            )
        }
    }

    static func makePrimaryServices(
        performanceMonitor: PerformanceMonitor,
    ) throws -> AppServices {
        let dataManager = try DataManager()
        let playbackStateManager = PlaybackStateManager()
        let audioMonitor = AudioMonitor(performanceMonitor: performanceMonitor)
        let queueManager = AudioQueueManager()
        let audioService = AudioEngineFacade(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            monitor: audioMonitor,
        )
        let importService = LibraryImportService(
            trackDataActor: dataManager.trackDataActor,
            metadataExtractor: dataManager.metadataExtractor,
        )
        let artworkService = ArtworkService(container: dataManager.container)
        let widgetCoordinator = WidgetDataCoordinator(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            artworkService: artworkService,
        )
        let liveActivityManager = LiveActivityManager(
            stateManager: playbackStateManager,
            queueManager: queueManager
        )
        return AppServices(
            dataManager: dataManager,
            audioService: audioService,
            importService: importService,
            artworkService: artworkService,
            widgetCoordinator: widgetCoordinator,
            liveActivityManager: liveActivityManager,
            recoveryError: nil,
        )
    }

    static func makePreviewServices(
        performanceMonitor: PerformanceMonitor
    ) -> AppServices? {
        guard let dataManager = DataManager.makePreviewDataManager()
            ?? DataManager.makeFallbackDataManager() else {
            return nil
        }

        let playbackStateManager = PlaybackStateManager()
        let audioMonitor = AudioMonitor(performanceMonitor: performanceMonitor)
        let queueManager = AudioQueueManager()
        let audioService = AudioEngineFacade(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            monitor: audioMonitor
        )
        let importService = LibraryImportService(
            trackDataActor: dataManager.trackDataActor,
            metadataExtractor: dataManager.metadataExtractor
        )
        let artworkService = ArtworkService(container: dataManager.container)
        let widgetCoordinator = WidgetDataCoordinator(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            artworkService: artworkService
        )
        let liveActivityManager = LiveActivityManager(
            stateManager: playbackStateManager,
            queueManager: queueManager
        )

        return AppServices(
            dataManager: dataManager,
            audioService: audioService,
            importService: importService,
            artworkService: artworkService,
            widgetCoordinator: widgetCoordinator,
            liveActivityManager: liveActivityManager,
            recoveryError: nil
        )
    }

    static func makeFallbackServices(
        performanceMonitor: PerformanceMonitor,
        errorLogger: Logger,
    ) -> AppServices {
        let playbackStateManager = PlaybackStateManager()
        let audioMonitor = AudioMonitor(performanceMonitor: performanceMonitor)
        let queueManager = AudioQueueManager()
        let audioService = AudioEngineFacade(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            monitor: audioMonitor,
        )

        if let fallbackManager = DataManager.makeFallbackDataManager()
            ?? DataManager.makePreviewDataManager() {
            let importService = LibraryImportService(
                trackDataActor: fallbackManager.trackDataActor,
                metadataExtractor: fallbackManager.metadataExtractor,
            )
            let artworkService = ArtworkService(container: fallbackManager.container)
            let widgetCoordinator = WidgetDataCoordinator(
                stateManager: playbackStateManager,
                queueManager: queueManager,
                artworkService: artworkService,
            )
            let liveActivityManager = LiveActivityManager(
                stateManager: playbackStateManager,
                queueManager: queueManager
            )
            return AppServices(
                dataManager: fallbackManager,
                audioService: audioService,
                importService: importService,
                artworkService: artworkService,
                widgetCoordinator: widgetCoordinator,
                liveActivityManager: liveActivityManager,
                recoveryError: nil,
            )
        }

        do {
            let resilientManager = try DataManager.ensureFallbackDataManager()
            let importService = LibraryImportService(
                trackDataActor: resilientManager.trackDataActor,
                metadataExtractor: resilientManager.metadataExtractor,
            )
            let artworkService = ArtworkService(container: resilientManager.container)
            let widgetCoordinator = WidgetDataCoordinator(
                stateManager: playbackStateManager,
                queueManager: queueManager,
                artworkService: artworkService,
            )
            let liveActivityManager = LiveActivityManager(
                stateManager: playbackStateManager,
                queueManager: queueManager
            )
            return AppServices(
                dataManager: resilientManager,
                audioService: audioService,
                importService: importService,
                artworkService: artworkService,
                widgetCoordinator: widgetCoordinator,
                liveActivityManager: liveActivityManager,
                recoveryError: nil,
            )
        } catch {
            let dataManagerError = logFallbackFailure(error, logger: errorLogger)
            return AppServices(
                dataManager: nil,
                audioService: audioService,
                importService: nil,
                artworkService: nil,
                widgetCoordinator: nil,
                liveActivityManager: nil,
                recoveryError: dataManagerError,
            )
        }
    }

    static func logFallbackFailure(_ error: Error, logger: Logger) -> DataManagerError {
        let dataManagerError: DataManagerError = if let existing = error as? DataManagerError {
            existing
        } else {
            .emergencyFallbackFailed(error)
        }

        logger.critical(
            """
            Unable to provide an emergency fallback DataManager:
            \(dataManagerError.localizedDescription, privacy: .public)
            """,
        )

        return dataManagerError
    }
}
