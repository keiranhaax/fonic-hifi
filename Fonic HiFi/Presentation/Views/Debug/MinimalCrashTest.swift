//
//  MinimalCrashTest.swift
//  Fonic HiFi
//
//  Minimal test to isolate the crash
//

import SwiftUI

/// Minimal test view to isolate the crash
@MainActor
struct MinimalCrashTest: View {
    @StateObject private var testState = TestState()
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 40) {
                Text("Minimal Crash Test")
                    .font(.title)
                
                // Test 1: Direct state change
                Button("Test 1: Direct State Change") {
                    debugLogThreadContext("Button 1 tapped")
                    testState.showingOverlay = true
                }
                .buttonStyle(.borderedProminent)
                
                // Test 2: State change in Task
                Button("Test 2: Task State Change") {
                    debugLogThreadContext("Button 2 tapped")
                    Task { @MainActor in
                        MainActor.assertIsolated()
                        testState.showingOverlay = true
                    }
                }
                .buttonStyle(.borderedProminent)
                
                // Test 3: State change with animation
                Button("Test 3: Animated State Change") {
                    debugLogThreadContext("Button 3 tapped")
                    withAnimation {
                        testState.showingOverlay = true
                    }
                }
                .buttonStyle(.borderedProminent)
                
                // Test 4: State change after async operation
                Button("Test 4: Async Then State Change") {
                    debugLogThreadContext("Button 4 tapped")
                    Task { @MainActor in
                        MainActor.assertIsolated()
                        // Simulate async work
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        MainActor.assertIsolated()
                        testState.showingOverlay = true
                    }
                }
                .buttonStyle(.borderedProminent)
                
                Text("Overlay is: \(testState.showingOverlay ? "Showing" : "Hidden")")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .overlay {
            if testState.showingOverlay {
                TestOverlayView(testState: testState)
                    .transition(.opacity)
                    .animation(.easeInOut, value: testState.showingOverlay)
            }
        }
    }
}

/// Test state object
@MainActor
final class TestState: ObservableObject {
    @Published var showingOverlay = false
    
    func show() {
        MainActor.logContext(message: "Showing overlay")
        showingOverlay = true
    }
    
    func hide() {
        MainActor.logContext(message: "Hiding overlay")
        showingOverlay = false
    }
}

/// Test overlay view
@MainActor
struct TestOverlayView: View {
    @ObservedObject var testState: TestState
    
    var body: some View {
        ZStack {
            Color.black.opacity(0.8)
                .ignoresSafeArea()
                .onTapGesture {
                    debugLogThreadContext("Background tapped")
                    testState.hide()
                }
            
            VStack(spacing: 20) {
                Text("Test Overlay")
                    .font(.title)
                    .foregroundColor(.white)
                
                Button("Close") {
                    debugLogThreadContext("Close button tapped")
                    testState.hide()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.gray)
            .cornerRadius(12)
        }
        .onAppear {
            MainActor.logContext(message: "Overlay appeared")
            dispatchPrecondition(condition: .onQueue(.main))
        }
    }
}

#Preview {
    MinimalCrashTest()
}