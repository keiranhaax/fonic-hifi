//
//  FonicHiFiApp.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import SwiftUI
import SwiftData
import OSLog

@main
struct FonicHiFiApp: App {
    
    // MARK: - Properties
    
    @StateObject private var dataManager: DataManager
    @StateObject private var audioService: AudioEngineFacade
    @StateObject private var importService: LibraryImportService
    
    private let logger = Logger(subsystem: "com.fonichifi.app", category: "FonicHiFiApp")
    
    // MARK: - Initialization
    
    init() {
        // Disable SwiftUI's async rendering if it's causing issues
        UserDefaults.standard.set(false, forKey: "SwiftUI.Animation.AsyncRendering")

        // Create logger early for error reporting
        let initLogger = Logger(subsystem: "com.fonichifi.app", category: "FonicHiFiApp.init")

        do {
            let dataManager = try DataManager()
            let playbackStateManager = PlaybackStateManager()  // Shared instance
            let audioService = AudioEngineFacade(stateManager: playbackStateManager)
            let importService = LibraryImportService(
                trackDataActor: dataManager.trackDataActor,
                metadataExtractor: dataManager.metadataExtractor
            )

            self._dataManager = StateObject(wrappedValue: dataManager)
            self._audioService = StateObject(wrappedValue: audioService)
            self._importService = StateObject(wrappedValue: importService)

        } catch {
            initLogger.critical("Failed to initialize app: \(error.localizedDescription)")

            // Create minimal fallback instances to allow app to launch
            // with reduced functionality rather than crashing
            let playbackStateManager = PlaybackStateManager()
            let audioService = AudioEngineFacade(stateManager: playbackStateManager)

            // Try to create a minimal DataManager if possible
            if let fallbackDataManager = try? DataManager() {
                let importService = LibraryImportService(
                    trackDataActor: fallbackDataManager.trackDataActor,
                    metadataExtractor: fallbackDataManager.metadataExtractor
                )
                self._dataManager = StateObject(wrappedValue: fallbackDataManager)
                self._importService = StateObject(wrappedValue: importService)
            } else {
                // Create dummy services that won't work but allow UI to load
                let dummyDataManager = DataManager.makePreviewDataManager()
                let dummyImportService = DataManager.makePreviewImportService()
                self._dataManager = StateObject(wrappedValue: dummyDataManager)
                self._importService = StateObject(wrappedValue: dummyImportService)
            }

            self._audioService = StateObject(wrappedValue: audioService)
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
            
        } catch {
            logger.error("Failed to initialize app: \(error.localizedDescription)")
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
