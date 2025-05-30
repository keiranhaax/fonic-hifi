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
    @StateObject private var appState = AppState()
    
    private let logger = Logger(subsystem: "com.fonichifi.app", category: "FonicHiFiApp")
    
    // MARK: - Initialization
    
    init() {
        // Disable SwiftUI's async rendering if it's causing issues
        UserDefaults.standard.set(false, forKey: "SwiftUI.Animation.AsyncRendering")
        
        do {
            let dataManager = try DataManager()
            let audioService = AudioEngineFacade()
            let importService = LibraryImportService(
                trackDataActor: dataManager.trackDataActor,
                metadataExtractor: dataManager.metadataExtractor
            )
            
            self._dataManager = StateObject(wrappedValue: dataManager)
            self._audioService = StateObject(wrappedValue: audioService)
            self._importService = StateObject(wrappedValue: importService)
            
        } catch {
            fatalError("Failed to initialize app: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Scene
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(dataManager)
                .environmentObject(audioService)
                .environmentObject(importService)
                .environmentObject(appState)
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
            
            // Connect audio service to app state
            appState.connectAudioService(audioService)
            logger.info("Audio service connected to app state")
            
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
