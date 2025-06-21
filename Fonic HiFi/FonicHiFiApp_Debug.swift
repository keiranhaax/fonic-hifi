//
//  FonicHiFiApp_Debug.swift
//  Fonic HiFi
//
//  Debug version to test different approaches
//

import SwiftUI
import SwiftData

/// Debug version of the app to isolate the crash
// @main  // UNCOMMENT THIS AND COMMENT OUT @main IN FonicHiFiApp.swift TO USE
struct FonicHiFiApp_Debug: App {
    @StateObject private var dataManager = try! DataManager()
    @StateObject private var appState: AppState
    @StateObject private var audioEngine: AudioEngineFacade
    
    private let playbackStateManager: PlaybackStateManager
    
    init() {
        let playbackStateManager = PlaybackStateManager()
        self.playbackStateManager = playbackStateManager
        self._appState = StateObject(wrappedValue: AppState(playbackStateManager: playbackStateManager))
        self._audioEngine = StateObject(wrappedValue: AudioEngineFacade(stateManager: playbackStateManager))
    }
    
    @State private var useDebugMode = true
    @State private var useSafeContentView = false
    
    var body: some Scene {
        WindowGroup {
            Group {
                if useDebugMode {
                    // Debug menu to choose which view to use
                    NavigationStack {
                        VStack(spacing: 20) {
                            Text("Fonic HiFi Debug Mode")
                                .font(.title)
                            
                            Toggle("Use Safe ContentView (Sheet)", isOn: $useSafeContentView)
                                .padding()
                            
                            Button("Launch App") {
                                useDebugMode = false
                            }
                            .buttonStyle(.borderedProminent)
                            
                            Divider()
                            
                            VStack(alignment: .leading) {
                                Text("Debug Options:")
                                    .font(.headline)
                                Text("• Safe ContentView uses sheet presentation")
                                Text("• Regular ContentView uses overlay")
                                Text("• Check console for debug logs")
                            }
                            .padding()
                            
                            Spacer()
                        }
                        .padding()
                        .navigationTitle("Debug Mode")
                    }
                } else if useSafeContentView {
                    ContentView_Safe()
                        .modelContainer(dataManager.container)
                        .environmentObject(dataManager.importService)
                        .environmentObject(appState)
                        .environmentObject(audioEngine)
                } else {
                    ContentView()
                        .modelContainer(dataManager.container)
                        .environmentObject(dataManager.importService)
                        .environmentObject(appState)
                        .environmentObject(audioEngine)
                }
            }
            .onAppear {
                print("App launched with debug mode: \(useDebugMode)")
                print("Main thread: \(Thread.isMainThread)")
                
                Task { @MainActor in
                    // Initialize audio engine
                    do {
                        try await audioEngine.initialize()
                        print("Audio engine initialized successfully")
                    } catch {
                        print("Failed to initialize audio engine: \(error)")
                    }
                }
            }
        }
    }
}

// Comment out the original @main in FonicHiFiApp.swift when using this