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
    
    private let logger = Logger(subsystem: "com.fonichifi.app", category: "FonicHiFiApp")
    
    // MARK: - Initialization
    
    init() {
        do {
            let dataManager = try DataManager()
            let audioService = AudioEngineFacade()
            
            self._dataManager = StateObject(wrappedValue: dataManager)
            self._audioService = StateObject(wrappedValue: audioService)
            
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
            // Initialize audio service
            try await audioService.initialize()
            logger.info("Audio service initialized successfully")
            
            // Perform any other startup tasks
            await performStartupTasks()
            
        } catch {
            logger.error("Failed to initialize app: \(error.localizedDescription)")
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
