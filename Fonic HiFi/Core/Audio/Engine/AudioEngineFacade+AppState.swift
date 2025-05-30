//
//  AudioEngineFacade+AppState.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import Foundation
import Combine

extension AudioEngineFacade {
    /// Sets up bindings between AudioEngineFacade and AppState
    @MainActor
    func setupAppStateBindings(appState: AppState, cancellables: inout Set<AnyCancellable>) {
        // Observe playback state changes from state manager
        // Since stateManager is @MainActor, its publisher emits on main thread
        stateManager.statePublisher
            .sink { [weak appState] change in
                // Already on main thread - no need for Task
                switch change.to {
                case .playing:
                    appState?.isPlaying = true
                default:
                    appState?.isPlaying = false
                }
            }
            .store(in: &cancellables)
        
        // We'll update current track directly when playing a new track
        // Since AudioQueueManager uses @Observable, we don't have publishers
        
        // Start progress timer when playing
        stateManager.statePublisher
            .sink { [weak self] change in
                // Already on main thread since stateManager is @MainActor
                switch change.to {
                case .playing:
                    self?.startProgressTimer(appState: appState)
                default:
                    self?.stopProgressTimer()
                }
            }
            .store(in: &cancellables)
        
        // Queue state changes will be handled through direct updates
        // Since AudioQueueManager uses @Observable, we don't have publishers
    }
    
    // MARK: - Progress Timer Management
    
    private func startProgressTimer(appState: AppState) {
        progressTimerManager.start { [weak self] in
            self?.updateProgress(appState: appState)
        }
    }
    
    private func stopProgressTimer() {
        progressTimerManager.stop()
    }
    
    private func updateProgress(appState: AppState) {
        guard let engine = currentEngine,
              let audioTrack = currentTrack,
              audioTrack.duration > 0 else { return }
        
        // We're already on MainActor from the timer
        Task {
            let currentTime = await engine.currentTime
            appState.updateProgress(current: currentTime, duration: audioTrack.duration)
        }
    }
}