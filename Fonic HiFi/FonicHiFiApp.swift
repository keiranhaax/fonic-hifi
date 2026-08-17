//
//  FonicHiFiApp.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import AVFAudio
import OSLog
import SwiftData
import SwiftUI

@main
struct FonicHiFiApp: App {
    // MARK: - Properties

    @Environment(\.scenePhase) private var scenePhase

    private let dataManager: DataManager?
    private let audioService: AudioEngineFacade
    private let importService: LibraryImportService?
    private let artworkService: ArtworkService?
    private let widgetCoordinator: WidgetDataCoordinator?

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
        fallbackError = resolution.fallbackError
        if let resolvedDataManager = resolution.dataManager {
            resolution.audioService.configureSessionTracking(
                dataActor: resolvedDataManager.trackDataActor
            )
        }

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
        if let dataManager, let importService {
            mainAppView(using: dataManager, importService: importService)
        } else {
            fallbackView
        }
    }

    private func mainAppView(
        using dataManager: DataManager,
        importService: LibraryImportService,
    ) -> some View {
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
            .task(id: scenePhase) {
                guard scenePhase == .background else { return }
                await audioService.persistQueueStateForSuspension()
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
    }

    // MARK: - App Initialization

    @MainActor
    private func initializeApp() async {
        logger.info("Initializing Fonic HiFi app...")

        do {
            // Initialize audio service with proper error handling
            try await audioService.initialize()
            logger.info("Audio service initialized successfully")
            await restoreRecentTrackIfNeeded()

            // Configure intent dependency provider for widget/Live Activity intents
            IntentDependencyProvider.shared.configure(
                audioEngine: audioService,
                widgetCoordinator: widgetCoordinator
            )
            logger.info("IntentDependencyProvider configured")

            // Track app launch time
            let launchDuration = Date().timeIntervalSince(appLaunchStartTime)
            await performanceMonitor.recordAppLaunchTime(launchDuration)
            logger.info("App launch completed in \(String(format: "%.2f", launchDuration), privacy: .public) seconds")

            // Perform non-launch-critical work after recording the same interactive boundary.
            await performStartupTasks()

        } catch {
            logger.error("Failed to initialize app: \(error.localizedDescription, privacy: .private)")
            let startupError = LaunchError(message: error.localizedDescription)
            launchError = startupError
            showInitializationError = true
            isUsingFallbackServices = true

            // Track app launch time even if initialization fails
            let launchDuration = Date().timeIntervalSince(appLaunchStartTime)
            await performanceMonitor.recordAppLaunchTime(launchDuration)

            // Record the error in performance monitor
            await performanceMonitor.recordError(error, context: "App initialization")

            logger.warning("Continuing in limited mode after startup failure")
        }
    }

    @MainActor
    private func restoreRecentTrackIfNeeded() async {
        guard audioService.currentTrack == nil, let dataManager else { return }

        do {
            guard let recentTrack = try await dataManager.getRecentlyPlayedTracks(limit: 1).first,
                  audioService.restoreLaunchTrack(recentTrack)
            else {
                return
            }
            logger.info("Restored launch track from listening history")
        } catch {
            // Listening history is a recovery source, not a launch requirement.
            logger.warning(
                "Unable to restore launch track from listening history: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    @MainActor
    private func performStartupTasks() async {
        guard let dataManager else { return }
        let logger = logger
        let workflow = DeferredStartupWorkflow(
            clock: ContinuousClock(),
            operations: [
                DeferredStartupOperation(delay: .seconds(3)) {
                    do {
                        let removedCount = try await dataManager.cleanupMissingFiles()
                        guard !Task.isCancelled else { return }
                        if removedCount > 0 {
                            logger.info(
                                "Cleaned up \(removedCount, privacy: .public) missing files from library"
                            )
                        }
                    } catch {
                        guard !Task.isCancelled else { return }
                        logger.error(
                            "Failed to cleanup missing files: \(error.localizedDescription, privacy: .private)"
                        )
                    }
                },
                DeferredStartupOperation(delay: .seconds(5)) {
                    do {
                        let stats = try await dataManager.getLibraryStatistics()
                        guard !Task.isCancelled else { return }
                        let statsMessage = "Library stats: \(stats.trackCount) tracks, " +
                            "\(stats.albumCount) albums, \(stats.artistCount) artists"
                        logger.info("\(statsMessage, privacy: .public)")
                    } catch {
                        guard !Task.isCancelled else { return }
                        logger.error(
                            "Failed to get library statistics: \(error.localizedDescription, privacy: .private)"
                        )
                    }
                },
                DeferredStartupOperation(delay: .seconds(8)) {
                    await dataManager.backfillAlbumArtistRelationshipsIfNeeded()
                },
                DeferredStartupOperation(delay: .seconds(10)) {
                    await dataManager.repairLosslessSourceBitDepthsIfNeeded()
                },
            ]
        )

        await workflow.run()
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
        let recoveryError: DataManagerError?
    }

    static func resolveInitialization(
        performanceMonitor: PerformanceMonitor,
        initLogger: Logger,
    ) -> InitializationResult {
        #if DEBUG
        let processInfo = ProcessInfo.processInfo
        if processInfo.arguments.contains("-UITestPreviewData"),
           let previewServices = makePreviewServices(performanceMonitor: performanceMonitor) {
            return InitializationResult(
                dataManager: previewServices.dataManager,
                audioService: previewServices.audioService,
                importService: previewServices.importService,
                artworkService: previewServices.artworkService,
                widgetCoordinator: previewServices.widgetCoordinator,
                launchError: nil,
                showInitializationError: false,
                usingFallback: previewServices.dataManager?.isFallback ?? false,
                fallbackError: previewServices.recoveryError
            )
        }
        #endif

        do {
            let services = try makePrimaryServices(performanceMonitor: performanceMonitor)
            return InitializationResult(
                dataManager: services.dataManager,
                audioService: services.audioService,
                importService: services.importService,
                artworkService: services.artworkService,
                widgetCoordinator: services.widgetCoordinator,
                launchError: nil,
                showInitializationError: false,
                usingFallback: false,
                fallbackError: nil,
            )
        } catch {
            initLogger.critical("Failed to initialize app: \(error.localizedDescription, privacy: .private)")
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
        // DataManager's import service is wired to invalidateLibrary(), which
        // bumps libraryRevision so repository-backed views refresh after imports.
        // A standalone LibraryImportService would silently skip that signal.
        let importService = dataManager.importService
        let artworkService = ArtworkService(container: dataManager.container)
        let widgetCoordinator = WidgetDataCoordinator(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            artworkService: artworkService,
        )
        return AppServices(
            dataManager: dataManager,
            audioService: audioService,
            importService: importService,
            artworkService: artworkService,
            widgetCoordinator: widgetCoordinator,
            recoveryError: nil,
        )
    }

    #if DEBUG
    static func makePreviewServices(
        performanceMonitor: PerformanceMonitor
    ) -> AppServices? {
        if ProcessInfo.processInfo.arguments.contains("-UITestResetQueuePersistence") {
            QueueState.clear()
        }

        if ProcessInfo.processInfo.arguments.contains("-UITestFileManagerData"),
           let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            for filename in ["UI Test Track.mp3", "UI Test Album.flac"] {
                let fixtureURL = documentsURL.appendingPathComponent(filename)
                _ = FileManager.default.createFile(
                    atPath: fixtureURL.path,
                    contents: Data("Fonic UI test fixture".utf8)
                )
            }
            try? FileManager.default.createDirectory(
                at: documentsURL.appendingPathComponent("UI Test Folder", isDirectory: true),
                withIntermediateDirectories: true
            )
        }

        guard let dataManager = DataManager.makePreviewDataManager()
            ?? DataManager.makeFallbackDataManager() else {
            return nil
        }

        if ProcessInfo.processInfo.arguments.contains("-UITestLibraryData") {
            let fixtureURL = FileManager.default.temporaryDirectory.appendingPathComponent("semantic-track.wav")
            if let format = AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 2),
               let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 441_000) {
                buffer.frameLength = 441_000
                try? FileManager.default.removeItem(at: fixtureURL)
                if let file = try? AVAudioFile(forWriting: fixtureURL, settings: format.settings) {
                    try? file.write(from: buffer)
                }
            }
            let track = Track(
                url: fixtureURL,
                title: "Semantic Track",
                artist: "Semantic Artist",
                album: "Semantic Album",
                audioFormat: "WAV",
                duration: 10,
                sampleRate: 44_100,
                bitDepth: 16,
                channels: 2,
                isLossless: true
            )
            let artist = Artist(name: "Semantic Artist")
            let album = Album(
                title: "Semantic Album",
                albumArtist: "Semantic Artist",
                year: 2026,
                totalTracks: 1
            )
            let playlist = Playlist(
                name: "Semantic Playlist",
                playlistDescription: "Semantic test collection"
            )
            track.genre = "Electronic"
            track.lastPlayed = .now
            track.playCount = 5
            album.isFavorite = true
            track.artistRelation = artist
            track.albumRelation = album
            playlist.addTrack(track.id)
            playlist.tracks = [track]
            dataManager.container.mainContext.insert(track)
            dataManager.container.mainContext.insert(artist)
            dataManager.container.mainContext.insert(album)
            dataManager.container.mainContext.insert(playlist)
            try? dataManager.container.mainContext.save()
        }

        let playbackStateManager = PlaybackStateManager()
        let audioMonitor = AudioMonitor(performanceMonitor: performanceMonitor)
        let queueManager = AudioQueueManager()
        let audioService = AudioEngineFacade(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            monitor: audioMonitor
        )
        let previewTrack = Track(
            url: FileManager.default.temporaryDirectory.appendingPathComponent("fonic-ui-test-preview.flac"),
            title: "Impulse Response",
            artist: "Fonic Ensemble",
            album: "Signal Paths",
            audioFormat: "FLAC",
            duration: 245,
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            isLossless: true
        )
        previewTrack.lyrics = "Reference lyrics for accessibility testing."
        if !ProcessInfo.processInfo.arguments.contains("-UITestNoCurrentTrack") {
            queueManager.setCurrentTrack(previewTrack.toAudioTrack())
            audioService.setCurrentTrack(previewTrack)
            playbackStateManager.forceUpdateState(
                .playing(currentTime: 0, duration: previewTrack.duration)
            )
        }
        if ProcessInfo.processInfo.arguments.contains("-UITestPlaybackError") {
            audioService.reportPlaybackControlError(AudioError.playbackFailed(reason: "UI testing."))
        }
        let importService = dataManager.importService
        let artworkService = ArtworkService(container: dataManager.container)
        let widgetCoordinator = WidgetDataCoordinator(
            stateManager: playbackStateManager,
            queueManager: queueManager,
            artworkService: artworkService
        )

        return AppServices(
            dataManager: dataManager,
            audioService: audioService,
            importService: importService,
            artworkService: artworkService,
            widgetCoordinator: widgetCoordinator,
            recoveryError: nil
        )
    }
    #endif

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

        if let fallbackManager = DataManager.makeFallbackDataManager() {
            let importService = fallbackManager.importService
            let artworkService = ArtworkService(container: fallbackManager.container)
            let widgetCoordinator = WidgetDataCoordinator(
                stateManager: playbackStateManager,
                queueManager: queueManager,
                artworkService: artworkService,
            )
            return AppServices(
                dataManager: fallbackManager,
                audioService: audioService,
                importService: importService,
                artworkService: artworkService,
                widgetCoordinator: widgetCoordinator,
                recoveryError: nil,
            )
        }

        do {
            let resilientManager = try DataManager.ensureFallbackDataManager()
            let importService = resilientManager.importService
            let artworkService = ArtworkService(container: resilientManager.container)
            let widgetCoordinator = WidgetDataCoordinator(
                stateManager: playbackStateManager,
                queueManager: queueManager,
                artworkService: artworkService,
            )
            return AppServices(
                dataManager: resilientManager,
                audioService: audioService,
                importService: importService,
                artworkService: artworkService,
                widgetCoordinator: widgetCoordinator,
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
            \(dataManagerError.localizedDescription, privacy: .private)
            """,
        )

        return dataManagerError
    }
}
