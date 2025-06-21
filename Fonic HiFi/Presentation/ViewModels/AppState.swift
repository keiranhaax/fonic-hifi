//
//  AppState.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import SwiftUI
import Combine

/// Global app state for managing UI-specific state (not playback state)
/// Playback state is managed by PlaybackStateManager for single source of truth
@MainActor
final class AppState: ObservableObject {
    // MARK: - UI State Properties
    
    /// Currently playing track (derived from playback state)
    @Published var currentTrack: TrackInfo?
    
    /// Store the original Track object for audio playback
    /// This is needed because TrackInfo doesn't contain all the data needed for audio playback
    @Published var currentTrackObject: Track? {
        didSet {
            print("currentTrackObject changed to: \(currentTrackObject?.title ?? "nil")")
        }
    }
    
    /// Whether the full Now Playing view is showing
    @Published var showingNowPlaying = false {
        didSet {
            print("showingNowPlaying changed to: \(showingNowPlaying)")
        }
    }
    
    /// Whether the mini player should be visible
    @Published var showMiniPlayer: Bool = false
    
    /// Volume level (0.0 to 1.0) - UI state, not playback state
    @Published var volume: Float = 1.0
    
    /// Whether shuffle is enabled - UI state
    @Published var isShuffleEnabled: Bool = false
    
    /// Current repeat mode - UI state
    @Published var repeatMode: QueueRepeatMode = .none
    
    // MARK: - Derived Properties from PlaybackStateManager
    
    /// Reference to the unified playback state manager
    private let playbackStateManager: PlaybackStateManager
    
    /// Whether music is currently playing (derived from playback state)
    var isPlaying: Bool {
        playbackStateManager.currentState.isPlaying
    }
    
    /// Progress of the current track (0.0 to 1.0) (derived from playback state)
    var playbackProgress: Double {
        playbackStateManager.currentState.progress ?? 0.0
    }
    
    /// Current playback time in seconds (derived from playback state)
    var currentTime: TimeInterval {
        playbackStateManager.currentState.currentTime ?? 0.0
    }
    
    /// Duration of the current track in seconds (derived from playback state)
    var duration: TimeInterval {
        playbackStateManager.currentState.duration ?? 0.0
    }
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init(playbackStateManager: PlaybackStateManager = PlaybackStateManager()) {
        self.playbackStateManager = playbackStateManager
        
        // Observe playback state changes to update UI
        setupPlaybackStateObservation()
    }
    
    /// Setup observation of playback state changes
    private func setupPlaybackStateObservation() {
        playbackStateManager.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                // Update derived UI state when playback state changes
                self?.handlePlaybackStateChange(change)
            }
            .store(in: &cancellables)
    }
    
    /// Handle playback state changes and update UI accordingly
    private func handlePlaybackStateChange(_ change: PlaybackStateChange) {
        // Update mini player visibility based on playback state
        switch change.to {
        case .idle, .stopped:
            showMiniPlayer = false
        case .playing, .paused, .loading, .buffering:
            showMiniPlayer = true
        default:
            break
        }
        
        // Trigger UI updates for derived properties
        objectWillChange.send()
    }
    
    // MARK: - Methods
    
    /// Updates the current track and shows mini player
    func setCurrentTrack(_ track: Track?) {
        guard let track = track else {
            currentTrack = nil
            currentTrackObject = nil
            showMiniPlayer = false
            return
        }
        
        // Store both the Track object and TrackInfo
        currentTrackObject = track
        currentTrack = TrackInfo(from: track)
        showMiniPlayer = true
    }
    
    /// Shows the full Now Playing view
    func showNowPlaying() {
        showingNowPlaying = true
    }
    
    /// Hides the full Now Playing view
    func hideNowPlaying() {
        showingNowPlaying = false
    }
    
    /// Access to the playback state manager for advanced operations
    var playbackManager: PlaybackStateManager {
        return playbackStateManager
    }
}