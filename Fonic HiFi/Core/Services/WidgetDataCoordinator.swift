//
//  WidgetDataCoordinator.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import Combine
import Foundation
import OSLog

/// Coordinates data synchronization between the main app and widget extension
/// Observes playback state and queue changes, then serializes to App Group
@MainActor
public final class WidgetDataCoordinator: ObservableObject {
    // MARK: - Dependencies

    private let stateManager: PlaybackStateManager
    private let queueManager: AudioQueueManager
    private let artworkService: ArtworkService?

    // MARK: - Private Properties

    private let logger = Log.logger(.widget)
    private let appGroupManager = AppGroupManager.shared
    private let artworkCache = WidgetArtworkCache.shared

    private var cancellables = Set<AnyCancellable>()
    private var observationTask: Task<Void, Never>?
    private var lastTrackId: UUID?
    private var lastIsPlaying: Bool?
    private var reloadDebounceTask: Task<Void, Never>?

    // MARK: - Published State

    @Published public private(set) var isSyncing: Bool = false
    @Published public private(set) var lastSyncDate: Date?

    // MARK: - Initialization

    public init(
        stateManager: PlaybackStateManager,
        queueManager: AudioQueueManager,
        artworkService: ArtworkService? = nil
    ) {
        self.stateManager = stateManager
        self.queueManager = queueManager
        self.artworkService = artworkService

        setupObservers()
        performInitialSync()

        logger.info("WidgetDataCoordinator initialized")
    }

    deinit {
        observationTask?.cancel()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe playback state changes via Combine publisher
        stateManager.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                self?.handlePlaybackStateChange(change)
            }
            .store(in: &cancellables)

        // Poll queue manager with change detection
        // 500ms interval with trackId/trackCount comparison to reduce CPU
        observationTask = Task { @MainActor [weak self] in
            var lastTrackId: UUID?
            var lastTrackCount: Int = -1  // -1 ensures initial sync fires

            while !Task.isCancelled {
                guard let self else { return }

                let state = queueManager.queueState
                let currentId = state.currentTrack?.id
                let currentCount = state.tracks.count

                // Only process when meaningful fields change
                if currentId != lastTrackId || currentCount != lastTrackCount {
                    lastTrackId = currentId
                    lastTrackCount = currentCount
                    handleQueueStateChange(state)
                }

                // 500ms is 5x slower than 100ms - reduces CPU waste
                try? await Task.sleep(for: .milliseconds(500))
            }
        }
    }

    private func performInitialSync() {
        Task {
            await syncCurrentState()
        }
    }

    // MARK: - State Change Handlers

    private func handlePlaybackStateChange(_ change: PlaybackStateChange) {
        let playbackState = createWidgetPlaybackState(from: change.nextState)
        appGroupManager.updatePlaybackState(playbackState)

        // Only reload widgets on meaningful state changes
        let isPlayingChanged = lastIsPlaying != playbackState.isPlaying
        lastIsPlaying = playbackState.isPlaying

        if isPlayingChanged {
            scheduleWidgetReload()
        }
    }

    private func handleQueueStateChange(_ state: QueueState) {
        // Update track info if track changed
        if let currentTrack = state.currentTrack {
            let trackId = currentTrack.id
            let trackChanged = trackId != lastTrackId
            lastTrackId = trackId

            if trackChanged {
                Task {
                    await updateTrackInfo(from: currentTrack)
                    updateUpNextTracks(from: state)
                    scheduleWidgetReload()
                }
            }
        } else {
            // No current track - clear widget data
            appGroupManager.updateTrackInfo(nil)
            appGroupManager.updateUpNextTracks([])
            lastTrackId = nil

            if lastIsPlaying != false {
                scheduleWidgetReload()
            }
        }
    }

    // MARK: - Sync Methods

    /// Perform a full sync of current state to App Group
    public func syncCurrentState() async {
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        // Sync playback state
        let playbackState = createWidgetPlaybackState(from: stateManager.currentState)
        appGroupManager.updatePlaybackState(playbackState)

        // Sync current track
        let currentQueueState = queueManager.queueState
        if let currentTrack = currentQueueState.currentTrack {
            await updateTrackInfo(from: currentTrack)
            lastTrackId = currentTrack.id
        } else {
            appGroupManager.updateTrackInfo(nil)
            lastTrackId = nil
        }

        // Sync up-next tracks
        updateUpNextTracks(from: currentQueueState)

        lastIsPlaying = playbackState.isPlaying

        logger.info("Full widget state sync completed")
    }

    /// Force reload all widget timelines
    public func forceReloadWidgets() {
        appGroupManager.reloadAllTimelines()
        logger.debug("Forced widget timeline reload")
    }

    // MARK: - Private Helpers

    private func createWidgetPlaybackState(from state: PlaybackState) -> WidgetPlaybackState {
        let currentQueueState = queueManager.queueState

        let repeatModeString: String = switch currentQueueState.repeatMode {
        case .none: "none"
        case .one: "one"
        case .all: "all"
        }

        return WidgetPlaybackState(
            isPlaying: state.isPlaying,
            currentTime: state.currentTime ?? 0,
            duration: state.duration ?? 0,
            shuffleEnabled: currentQueueState.shuffleMode.isActive,
            repeatMode: repeatModeString,
            hasNext: currentQueueState.hasNext,
            hasPrevious: currentQueueState.hasPrevious,
            timestamp: Date(),
            playbackRate: state.isPlaying ? 1.0 : 0.0
        )
    }

    private func updateTrackInfo(from track: AudioTrack) async {
        // Check if we have artwork cached, if not try to cache it
        let artworkKey = track.id.uuidString

        if !artworkCache.hasArtwork(forKey: artworkKey) {
            await cacheArtwork(for: track)
        }

        let trackInfo = WidgetTrackInfo(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            artworkKey: artworkCache.hasArtwork(forKey: artworkKey) ? artworkKey : nil,
            audioFormat: track.audioFormat,
            isLossless: track.format.isLossless
        )

        appGroupManager.updateTrackInfo(trackInfo)
    }

    private func updateUpNextTracks(from queueState: QueueState) {
        let upNext = queueState.remainingTracks.prefix(5).map { track in
            WidgetTrackInfo(
                id: track.id,
                title: track.title,
                artist: track.artist,
                album: track.album,
                duration: track.duration,
                artworkKey: artworkCache.hasArtwork(forKey: track.id.uuidString) ? track.id.uuidString : nil,
                audioFormat: track.audioFormat,
                isLossless: track.format.isLossless
            )
        }

        appGroupManager.updateUpNextTracks(Array(upNext))
    }

    private func cacheArtwork(for track: AudioTrack) async {
        guard let artworkService else { return }

        // Try to load artwork from the artwork service
        // This assumes ArtworkService has a method to get artwork data
        if let artworkData = await artworkService.loadArtworkData(forTrackId: track.id) {
            artworkCache.storeArtworkData(artworkData, forTrackId: track.id)
        }
    }

    private func scheduleWidgetReload() {
        // Debounce widget reloads to avoid excessive refreshes
        reloadDebounceTask?.cancel()
        reloadDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(500))

            guard !Task.isCancelled else { return }

            appGroupManager.reloadWidgetTimelines()
        }
    }

    // MARK: - Cleanup

    /// Clean up orphaned artwork from cache
    public func cleanupOrphanedArtwork() async {
        // Get all valid track IDs from the queue
        let validIds = Set(queueManager.queueState.tracks.map(\.id))
        artworkCache.removeOrphanedArtwork(validTrackIds: validIds)
    }

    /// Clear all widget data
    public func clearAllWidgetData() {
        appGroupManager.clearAllData()
        artworkCache.clearCache()
        lastTrackId = nil
        lastIsPlaying = nil
        logger.info("All widget data cleared")
    }
}
