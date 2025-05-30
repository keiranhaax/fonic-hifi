//
//  AppState.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import SwiftUI
import Combine

/// Global app state for managing Now Playing and other shared UI states
@MainActor
final class AppState: ObservableObject {
    // MARK: - Properties
    
    /// Currently playing track
    @Published var currentTrack: TrackInfo?
    
    /// Store the original Track object for audio playback
    /// This is needed because TrackInfo doesn't contain all the data needed for audio playback
    @Published var currentTrackObject: Track?
    
    /// Whether music is currently playing
    @Published var isPlaying: Bool = false
    
    /// Whether the full Now Playing view is showing
    @Published var showingNowPlaying: Bool = false
    
    /// Whether the mini player should be visible
    @Published var showMiniPlayer: Bool = false
    
    /// Progress of the current track (0.0 to 1.0)
    @Published var playbackProgress: Double = 0.0
    
    /// Current playback time in seconds
    @Published var currentTime: TimeInterval = 0.0
    
    /// Duration of the current track in seconds
    @Published var duration: TimeInterval = 0.0
    
    /// Volume level (0.0 to 1.0)
    @Published var volume: Float = 1.0
    
    /// Whether shuffle is enabled
    @Published var isShuffleEnabled: Bool = false
    
    /// Current repeat mode
    @Published var repeatMode: QueueRepeatMode = .none
    
    /// Cancellables for Combine subscriptions
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Initialization
    
    init() {
        // Initialize with default values
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
        // Reset playback progress for new track
        playbackProgress = 0.0
        currentTime = 0.0
        duration = track.duration
    }
    
    /// Toggles play/pause state
    func togglePlayPause() {
        isPlaying.toggle()
    }
    
    /// Shows the full Now Playing view
    func showNowPlaying() {
        showingNowPlaying = true
    }
    
    /// Hides the full Now Playing view
    func hideNowPlaying() {
        showingNowPlaying = false
    }
    
    /// Updates playback progress
    func updateProgress(current: TimeInterval, duration: TimeInterval) {
        self.currentTime = current
        self.duration = duration
        self.playbackProgress = duration > 0 ? current / duration : 0.0
    }
    
    /// Connects the audio service to update app state
    func connectAudioService(_ audioService: AudioEngineFacade) {
        audioService.setupAppStateBindings(appState: self, cancellables: &cancellables)
    }
}