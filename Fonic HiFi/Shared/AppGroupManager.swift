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
    private let reloadTimeline: @MainActor () -> Void
    private let reloadAllTimelinesAction: @MainActor () -> Void
    private let logger = Log.logger(.widgetData)
    private var lastPlaybackState: WidgetPlaybackState?
    private var lastTrackInfo: WidgetTrackInfo?
    private var lastUpNextTracks: [WidgetTrackInfo] = []

    // MARK: - Initialization

    private convenience init() {
        self.init(
            defaults: UserDefaults.appGroup,
            reloadTimeline: {
                WidgetCenter.shared.reloadTimelines(ofKind: WidgetConstants.WidgetKind.nowPlaying)
            },
            reloadAllTimelines: {
                WidgetCenter.shared.reloadAllTimelines()
            }
        )
    }

    init(
        defaults: UserDefaults?,
        reloadTimeline: @escaping @MainActor () -> Void = {},
        reloadAllTimelines: @escaping @MainActor () -> Void = {}
    ) {
        self.defaults = defaults
        self.reloadTimeline = reloadTimeline
        reloadAllTimelinesAction = reloadAllTimelines
        isAvailable = defaults != nil

        lastPlaybackState = loadPlaybackStateFromDefaults()
        lastTrackInfo = loadTrackInfoFromDefaults()
        lastUpNextTracks = loadUpNextTracksFromDefaults()
        lastSyncDate = defaults?.object(forKey: WidgetConstants.Keys.lastUpdated) as? Date

        if !isAvailable {
            logger.error("App Group UserDefaults not available - widget sync disabled")
        } else {
            logger.info("App Group initialized: \(WidgetConstants.appGroupIdentifier, privacy: .public)")
        }
    }

    // MARK: - State Sync

    /// Update playback state in App Group
    /// Only writes if state has meaningfully changed
    @discardableResult
    public func updatePlaybackState(_ state: WidgetPlaybackState) -> Bool {
        guard isAvailable, let defaults else { return false }

        // Timestamp/current-time changes are meaningful: widgets interpolate
        // progress from this snapshot and must receive fresh transport state.
        if lastPlaybackState == state { return false }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(state) else { return false }

        defaults.set(data, forKey: WidgetConstants.Keys.playbackState)
        lastPlaybackState = state
        recordSyncDate(in: defaults)

        logger.debug("Playback state synced: playing=\(state.isPlaying, privacy: .public), progress=\(state.progress, privacy: .private)")
        return true
    }

    /// Update track info in App Group
    /// Only writes if track has changed
    @discardableResult
    public func updateTrackInfo(_ track: WidgetTrackInfo?) -> Bool {
        guard isAvailable, let defaults else { return false }

        if let track {
            // Compare the full payload so metadata and late artwork availability
            // can update while the same track remains current.
            guard track != lastTrackInfo else { return false }
            guard let data = try? JSONEncoder().encode(track) else { return false }
            defaults.set(data, forKey: WidgetConstants.Keys.trackInfo)
            lastTrackInfo = track
            logger.debug("Current track info synced")
        } else {
            // A new process starts with in-memory comparison state reconstructed from
            // disk. The key check also protects callers if another process wrote after
            // this manager was initialized.
            guard lastTrackInfo != nil
                || defaults.object(forKey: WidgetConstants.Keys.trackInfo) != nil
            else { return false }
            defaults.removeObject(forKey: WidgetConstants.Keys.trackInfo)
            lastTrackInfo = nil
            logger.debug("Track info cleared")
        }

        recordSyncDate(in: defaults)
        return true
    }

    /// Update up-next tracks in App Group
    /// Only writes if the compact payload has changed
    @discardableResult
    public func updateUpNextTracks(_ tracks: [WidgetTrackInfo]) -> Bool {
        guard isAvailable, let defaults else { return false }

        // Limit to 5 tracks for widget display
        let limited = Array(tracks.prefix(5))

        // Compare complete entries so artwork and metadata updates are not discarded.
        guard limited != lastUpNextTracks else { return false }

        guard let data = try? JSONEncoder().encode(limited) else { return false }
        defaults.set(data, forKey: WidgetConstants.Keys.upNextTracks)
        lastUpNextTracks = limited
        recordSyncDate(in: defaults)

        logger.debug("Up-next tracks synced: \(limited.count, privacy: .public) tracks")
        return true
    }

    /// Trigger widget timeline reload
    /// Should be called after meaningful state changes (track change, play/pause)
    public func reloadWidgetTimelines() {
        reloadTimeline()
        logger.debug("Widget timeline reload triggered")
    }

    /// Reload all widget timelines
    public func reloadAllTimelines() {
        reloadAllTimelinesAction()
        logger.debug("All widget timelines reload triggered")
    }

    // MARK: - State Reading

    /// Load current playback state from App Group
    public func loadPlaybackState() -> WidgetPlaybackState {
        loadPlaybackStateFromDefaults() ?? .idle
    }

    /// Load current track info from App Group
    public func loadTrackInfo() -> WidgetTrackInfo? {
        loadTrackInfoFromDefaults()
    }

    /// Load up-next tracks from App Group
    public func loadUpNextTracks() -> [WidgetTrackInfo] {
        loadUpNextTracksFromDefaults()
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
        lastUpNextTracks = []
        lastSyncDate = nil

        logger.info("All widget data cleared")
    }

    // MARK: - Persistence Helpers

    private func loadPlaybackStateFromDefaults() -> WidgetPlaybackState? {
        guard let data = defaults?.data(forKey: WidgetConstants.Keys.playbackState) else {
            return nil
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(WidgetPlaybackState.self, from: data)
    }

    private func loadTrackInfoFromDefaults() -> WidgetTrackInfo? {
        guard let data = defaults?.data(forKey: WidgetConstants.Keys.trackInfo) else {
            return nil
        }
        return try? JSONDecoder().decode(WidgetTrackInfo.self, from: data)
    }

    private func loadUpNextTracksFromDefaults() -> [WidgetTrackInfo] {
        guard let data = defaults?.data(forKey: WidgetConstants.Keys.upNextTracks) else {
            return []
        }
        return (try? JSONDecoder().decode([WidgetTrackInfo].self, from: data)) ?? []
    }

    private func recordSyncDate(in defaults: UserDefaults) {
        let syncDate = Date()
        defaults.set(syncDate, forKey: WidgetConstants.Keys.lastUpdated)
        lastSyncDate = syncDate
    }
}
