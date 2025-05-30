//
//  DebugContentView.swift
//  Fonic HiFi
//
//  Debug version to test different presentation methods
//

import SwiftUI

@MainActor
struct DebugContentView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var audioService: AudioEngineFacade
    @State private var testScenario = 0
    @State private var debugLogs: [String] = []
    
    // Test different presentation methods
    @State private var showingSheet = false
    @State private var showingFullScreen = false
    @State private var showingOverlay = false
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("Debug Test Scenarios")
                    .font(.title)
                
                Picker("Scenario", selection: $testScenario) {
                    Text("Sheet Presentation").tag(0)
                    Text("Full Screen Cover").tag(1)
                    Text("ZStack Overlay").tag(2)
                    Text("Navigation Push").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()
                
                // Test buttons
                VStack(spacing: 16) {
                    Button("Test Selected Scenario") {
                        testSelectedScenario()
                    }
                    .buttonStyle(.borderedProminent)
                    
                    Button("Test Direct State Change") {
                        addLog("Testing direct state change")
                        appState.showingNowPlaying = true
                    }
                    
                    Button("Test With Animation") {
                        addLog("Testing with animation")
                        withAnimation {
                            appState.showingNowPlaying = true
                        }
                    }
                    
                    Button("Test Async Update") {
                        Task { @MainActor in
                            addLog("Testing async update")
                            appState.showingNowPlaying = true
                        }
                    }
                }
                
                Divider()
                
                // Debug logs
                VStack(alignment: .leading) {
                    Text("Debug Logs:")
                        .font(.headline)
                    
                    ScrollView {
                        VStack(alignment: .leading) {
                            ForEach(debugLogs, id: \.self) { log in
                                Text(log)
                                    .font(.caption)
                                    .monospaced()
                            }
                        }
                    }
                    .frame(maxHeight: 200)
                    .border(Color.gray)
                }
                .padding()
                
                Spacer()
            }
            .navigationTitle("Debug Mode")
            // Test presentations
            .sheet(isPresented: $showingSheet) {
                DebugNowPlayingView()
                    .environmentObject(appState)
                    .environmentObject(audioService)
            }
            .fullScreenCover(isPresented: $showingFullScreen) {
                DebugNowPlayingView()
                    .environmentObject(appState)
                    .environmentObject(audioService)
            }
            .overlay {
                if showingOverlay {
                    DebugNowPlayingView()
                        .environmentObject(appState)
                        .environmentObject(audioService)
                        .background(Color.black.opacity(0.8))
                        .onTapGesture {
                            showingOverlay = false
                        }
                }
            }
        }
        .onAppear {
            addLog("ContentView appeared")
            addLog("Main thread: \(Thread.isMainThread)")
        }
    }
    
    private func testSelectedScenario() {
        addLog("\n=== Testing Scenario \(testScenario) ===")
        
        switch testScenario {
        case 0:
            addLog("Presenting via sheet")
            showingSheet = true
        case 1:
            addLog("Presenting via fullScreenCover")
            showingFullScreen = true
        case 2:
            addLog("Presenting via overlay")
            showingOverlay = true
        case 3:
            addLog("Would present via navigation (not implemented)")
        default:
            break
        }
    }
    
    private func addLog(_ message: String) {
        let timestamp = Date().timeIntervalSince1970
        let log = "\(String(format: "%.3f", timestamp)): \(message)"
        print("[DEBUG CONTENT] \(log)")
        debugLogs.append(log)
    }
}

#Preview {
    DebugContentView()
        .environmentObject(AppState())
        .environmentObject(AudioEngineFacade())
}