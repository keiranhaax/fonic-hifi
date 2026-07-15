//
//  AppGroupManager.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import Foundation
import OSLog
import WidgetKit

/// Thread-safe manager for App Group shared state
/// Provides a centralized interface for reading/writing widget data
@MainActor
public final class AppGroupManager: ObservableObject {
    // MARK: - Singleton

    public static let shared = AppGroupManager()

    // MARK: - Published State

    @Published public private(set) var lastSyncDate: Date?
    @Published public private(set) var isAvailable: Bool = false

    // MARK: - Private Properties

    private let defaults: UserDefaults?
    private let logger = Log.logger(.widgetData)
    private var lastPlaybackState: WidgetPlaybackState?
    private var lastTrackInfo: WidgetTrackInfo?
    private var lastUpNextIds: [UUID] = []

    // MARK: - Initialization

    private init() {
        defaults = UserDefaults.appGroup
        isAvailable = defaults != nil

        if !isAvailable {
            logger.error("App Group UserDefaults not available - widget sync disabled")
        } else {
            logger.info("App Group initialized: \(WidgetConstants.appGroupIdentifier)")
        }
    }

    // MARK: - State Sync

    /// Update playback state in App Group
    /// Only writes if state has meaningfully changed
    public func updatePlaybackState(_ state: WidgetPlaybackState) {
        guard isAvailable else { return }

        // Skip if state hasn't meaningfully changed
        if let last = lastPlaybackState,
           last.isPlaying == state.isPlaying,
           last.hasNext == state.hasNext,
           last.hasPrevious == state.hasPrevious,
           last.shuffleEnabled == state.shuffleEnabled,
           last.repeatMode == state.repeatMode,
           abs(last.duration - state.duration) < 0.1 {
            // Only time changed - skip write for efficiency
            // Progress updates happen through Live Activity, not widgets
            return
        }

        state.save()
        lastPlaybackState = state
        lastSyncDate = Date()

        logger.debug("Playback state synced: playing=\(state.isPlaying), progress=\(state.progress)")
    }

    /// Update track info in App Group
    /// Only writes if track has changed
    public func updateTrackInfo(_ track: WidgetTrackInfo?) {
        guard isAvailable else { return }

        // Skip if same track
        if let track, let last = lastTrackInfo, last.id == track.id {
            return
        }

        if let track {
            track.save()
            lastTrackInfo = track
            logger.debug("Current track info synced")
        } else {
            // Skip if already cleared
            guard lastTrackInfo != nil else { return }
            defaults?.removeObject(forKey: WidgetConstants.Keys.trackInfo)
            lastTrackInfo = nil
            logger.debug("Track info cleared")
        }

        lastSyncDate = Date()
    }

    /// Update up-next tracks in App Group
    /// Only writes if track IDs have changed
    public func updateUpNextTracks(_ tracks: [WidgetTrackInfo]) {
        guard isAvailable else { return }

        // Limit to 5 tracks for widget display
        let limited = Array(tracks.prefix(5))
        let newIds = limited.map(\.id)

        // Skip if same tracks
        guard newIds != lastUpNextIds else { return }
        lastUpNextIds = newIds

        limited.saveAsUpNext()
        logger.debug("Up-next tracks synced: \(limited.count) tracks")
    }

    /// Trigger widget timeline reload
    /// Should be called after meaningful state changes (track change, play/pause)
    public func reloadWidgetTimelines() {
        WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.WidgetKind.nowPlaying)
        logger.debug("Widget timeline reload triggered")
    }

    /// Reload all widget timelines
    public func reloadAllTimelines() {
        WidgetCenter.shared.reloadAllTimelines()
        logger.debug("All widget timelines reload triggered")
    }

    // MARK: - State Reading

    /// Load current playback state from App Group
    public func loadPlaybackState() -> WidgetPlaybackState {
        WidgetPlaybackState.loadOrIdle()
    }

    /// Load current track info from App Group
    public func loadTrackInfo() -> WidgetTrackInfo? {
        WidgetTrackInfo.load()
    }

    /// Load up-next tracks from App Group
    public func loadUpNextTracks() -> [WidgetTrackInfo] {
        [WidgetTrackInfo].loadUpNext()
    }

    /// Get last updated date from App Group
    public func loadLastUpdated() -> Date? {
        defaults?.object(forKey: WidgetConstants.Keys.lastUpdated) as? Date
    }

    // MARK: - Cleanup

    /// Clear all widget data from App Group
    public func clearAllData() {
        guard let defaults else { return }

        defaults.removeObject(forKey: WidgetConstants.Keys.playbackState)
        defaults.removeObject(forKey: WidgetConstants.Keys.trackInfo)
        defaults.removeObject(forKey: WidgetConstants.Keys.upNextTracks)
        defaults.removeObject(forKey: WidgetConstants.Keys.lastUpdated)

        lastPlaybackState = nil
        lastTrackInfo = nil
        lastSyncDate = nil

        logger.info("All widget data cleared")
    }
}
