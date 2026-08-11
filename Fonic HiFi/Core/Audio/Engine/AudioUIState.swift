//
//  AudioUIState.swift
//  Fonic HiFi
//
//  Centralised store for facade UI state, extracted for Phase 2C modularisation.
//

import Foundation

/// Stores UI-facing audio state consumed by SwiftUI.
@MainActor
public final class AudioUIState: ObservableObject {
    @Published public private(set) var currentTrack: Track?
    @Published public private(set) var showMiniPlayer: Bool
    @Published public var diagnosticsStatus: DiagnosticsStatus

    public init(
        currentTrack: Track? = nil,
        showMiniPlayer: Bool = false,
        diagnosticsStatus: DiagnosticsStatus = .empty,
    ) {
        self.currentTrack = currentTrack
        self.showMiniPlayer = showMiniPlayer
        self.diagnosticsStatus = diagnosticsStatus
    }

    /// Updates the displayed track without revealing a new playback surface.
    /// A nil track is a real teardown and always hides the mini player.
    public func setCurrentTrack(_ track: Track?) {
        currentTrack = track
        if track == nil {
            showMiniPlayer = false
        }
    }

    /// Restores the last persisted track as the launch playback surface.
    /// This does not claim that audio is currently playing; the mini player
    /// presents its play action until the user resumes playback.
    public func restorePersistedTrack(_ track: Track?) {
        currentTrack = track
        showMiniPlayer = track != nil
    }

    /// Reveals the mini player only after playback has actually started.
    public func revealMiniPlayerAfterPlaybackStarted() {
        guard currentTrack != nil else { return }
        showMiniPlayer = true
    }

    public func reset() {
        currentTrack = nil
        showMiniPlayer = false
        diagnosticsStatus = .empty
    }
}
