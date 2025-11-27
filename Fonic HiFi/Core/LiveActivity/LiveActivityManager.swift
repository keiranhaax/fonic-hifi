//
//  LiveActivityManager.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

@preconcurrency import ActivityKit
import Combine
import Foundation
import OSLog
import UIKit

/// Manages Live Activity lifecycle for Now Playing
/// Handles start, update, and end of Dynamic Island and Lock Screen Live Activity [Verified-Apple]
///
/// **Update Strategy:**
/// - Updates are sparse, NOT every second
/// - System interpolates progress using `playbackRate`
/// - Update only on: play/pause, seek, track change
@MainActor
public final class LiveActivityManager: ObservableObject {
    // MARK: - Dependencies

    private let stateManager: PlaybackStateManager
    private let queueManager: AudioQueueManager
    private let artworkCache: WidgetArtworkCache

    // MARK: - Private Properties

    private let logger = Log.logger(.widget)
    private var cancellables = Set<AnyCancellable>()
    private var observationTask: Task<Void, Never>?

    private var currentActivity: Activity<NowPlayingAttributes>?
    private var lastTrackId: UUID?
    private var lastIsPlaying: Bool?
    private var lastSeekTime: TimeInterval?

    // MARK: - Published State

    @Published public private(set) var isActivityActive: Bool = false
    @Published public private(set) var activityId: String?

    // MARK: - Initialization

    public init(
        stateManager: PlaybackStateManager,
        queueManager: AudioQueueManager
    ) {
        self.stateManager = stateManager
        self.queueManager = queueManager
        self.artworkCache = WidgetArtworkCache.shared

        setupObservers()
        logger.info("LiveActivityManager initialized")
    }

    deinit {
        observationTask?.cancel()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe playback state changes
        stateManager.statePublisher
            .receive(on: RunLoop.main)
            .sink { [weak self] change in
                Task {
                    await self?.handlePlaybackStateChange(change)
                }
            }
            .store(in: &cancellables)

        // Observe queue changes for track switching
        observationTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }

                let currentState = withObservationTracking {
                    self.queueManager.queueState
                } onChange: {
                    // Called when tracked properties change
                }

                await self.handleQueueStateChange(currentState)

                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    // MARK: - State Change Handlers

    private func handlePlaybackStateChange(_ change: PlaybackStateChange) async {
        let state = change.nextState
        let isPlayingChanged = lastIsPlaying != state.isPlaying
        let seekOccurred = detectSeek(currentTime: state.currentTime)

        lastIsPlaying = state.isPlaying

        // Start activity if needed
        if state.isPlaying, currentActivity == nil {
            await startActivityIfNeeded()
        }

        // Update activity on meaningful changes
        if currentActivity != nil, isPlayingChanged || seekOccurred {
            await updateActivity(playbackState: state)
        }

        // End activity if playback stopped and we should dismiss
        if !state.isPlaying, !isPlayingChanged {
            // Don't end immediately on pause, only if it stays paused
            scheduleActivityEndIfNeeded()
        }
    }

    private func handleQueueStateChange(_ state: QueueState) async {
        guard let currentTrack = state.currentTrack else {
            // No track - end activity
            await endActivity()
            lastTrackId = nil
            return
        }

        let trackChanged = currentTrack.id != lastTrackId
        lastTrackId = currentTrack.id

        if trackChanged {
            // Track changed - restart activity with new attributes
            await restartActivityForNewTrack(currentTrack)
        }
    }

    private func detectSeek(currentTime: TimeInterval?) -> Bool {
        guard let current = currentTime, let last = lastSeekTime else {
            lastSeekTime = currentTime
            return false
        }

        // Detect seek if time jumped by more than 2 seconds
        let timeDiff = abs(current - last)
        let isSeek = timeDiff > 2.0

        lastSeekTime = currentTime
        return isSeek
    }

    // MARK: - Activity Lifecycle

    /// Start a Live Activity for the current track
    public func startActivityIfNeeded() async {
        guard currentActivity == nil,
              ActivityAuthorizationInfo().areActivitiesEnabled else {
            return
        }

        guard let track = queueManager.queueState.currentTrack else {
            logger.debug("Cannot start Live Activity - no current track")
            return
        }

        await startActivity(for: track)
    }

    private func startActivity(for track: AudioTrack) async {
        let attributes = createAttributes(for: track)
        let contentState = createContentState()

        do {
            let activity = try Activity.request(
                attributes: attributes,
                content: .init(state: contentState, staleDate: staleDate()),
                pushType: nil // No push updates needed for local playback
            )

            currentActivity = activity
            activityId = activity.id
            isActivityActive = true
            lastTrackId = track.id

            logger.info("Live Activity started: \(activity.id)")

            // Monitor activity state
            monitorActivityState(activity)

        } catch {
            logger.error("Failed to start Live Activity: \(error.localizedDescription)")
        }
    }

    private func restartActivityForNewTrack(_ track: AudioTrack) async {
        // End existing activity
        await endActivity()

        // Start new activity for the new track
        await startActivity(for: track)
    }

    /// Update the Live Activity with current playback state
    public func updateActivity(playbackState: PlaybackState) async {
        guard let activity = currentActivity else { return }

        let contentState = NowPlayingAttributes.ContentState(
            isPlaying: playbackState.isPlaying,
            currentTime: playbackState.currentTime ?? 0,
            duration: playbackState.duration ?? 0,
            playbackRate: playbackState.isPlaying ? 1.0 : 0.0
        )

        let content = ActivityContent(
            state: contentState,
            staleDate: staleDate()
        )

        await updateActivityOnMain(activity, content: content)

        logger.debug("Live Activity updated - playing: \(playbackState.isPlaying)")
    }

    /// End the current Live Activity
    public func endActivity() async {
        guard let activity = currentActivity else { return }

        let finalState = createContentState()
        let content = ActivityContent(
            state: finalState,
            staleDate: nil
        )

        await endActivityOnMain(activity, content: content)

        currentActivity = nil
        activityId = nil
        isActivityActive = false

        logger.info("Live Activity ended")
    }

    /// Force end all activities (for cleanup)
    public func endAllActivities() async {
        let activities = Activity<NowPlayingAttributes>.activities
        await endAllActivitiesOnMain(Array(activities))

        currentActivity = nil
        activityId = nil
        isActivityActive = false

        logger.info("All Live Activities ended")
    }

    // MARK: - Private Helpers

    private func createAttributes(for track: AudioTrack) -> NowPlayingAttributes {
        // Get tiny artwork thumbnail for Live Activity (max ~3KB)
        let artworkData = loadTinyArtworkThumbnail(for: track)

        return NowPlayingAttributes(
            title: track.title,
            artist: track.artist,
            album: track.album,
            trackId: track.id,
            artworkThumbnail: artworkData,
            isLossless: track.format.isLossless,
            audioFormat: track.audioFormat
        )
    }

    private func createContentState() -> NowPlayingAttributes.ContentState {
        let playbackState = stateManager.currentState

        return NowPlayingAttributes.ContentState(
            isPlaying: playbackState.isPlaying,
            currentTime: playbackState.currentTime ?? 0,
            duration: playbackState.duration ?? 0,
            playbackRate: playbackState.isPlaying ? 1.0 : 0.0
        )
    }

    private func loadTinyArtworkThumbnail(for track: AudioTrack) -> Data? {
        // Load from artwork cache
        guard let image = artworkCache.loadArtworkImage(forKey: track.id.uuidString) else {
            return nil
        }

        // Resize to tiny thumbnail (100x100 max) and compress heavily
        let thumbnailSize = CGSize(width: 100, height: 100)
        let renderer = UIGraphicsImageRenderer(size: thumbnailSize)

        let thumbnail = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: thumbnailSize))
        }

        // Compress to JPEG at 0.5 quality (~3KB or less)
        return thumbnail.jpegData(compressionQuality: 0.5)
    }

    private func staleDate() -> Date {
        // Mark as stale after 5 minutes of no updates
        Date().addingTimeInterval(300)
    }

    private var activityEndTask: Task<Void, Never>?

    private func scheduleActivityEndIfNeeded() {
        // Cancel any existing end task
        activityEndTask?.cancel()

        // Schedule end after 30 seconds of inactivity
        activityEndTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(30))

            guard !Task.isCancelled else { return }

            // Check if still paused
            if !stateManager.currentState.isPlaying {
                await endActivity()
            }
        }
    }

    private func monitorActivityState(_ activity: Activity<NowPlayingAttributes>) {
        Task {
            for await state in activity.activityStateUpdates {
                switch state {
                case .active:
                    logger.debug("Live Activity is active")
                case .ended:
                    logger.info("Live Activity ended by system")
                    await MainActor.run {
                        if currentActivity?.id == activity.id {
                            currentActivity = nil
                            activityId = nil
                            isActivityActive = false
                        }
                    }
                case .dismissed:
                    logger.info("Live Activity dismissed by user")
                    await MainActor.run {
                        if currentActivity?.id == activity.id {
                            currentActivity = nil
                            activityId = nil
                            isActivityActive = false
                        }
                    }
                case .stale:
                    logger.debug("Live Activity marked as stale")
                default:
                    logger.debug("Live Activity state changed to unknown state")
                }
            }
        }
    }

    // MARK: - Activity MainActor Helpers

    /// Main-actor wrapper to keep Activity updates on the UI actor
    @MainActor
    private func updateActivityOnMain(
        _ activity: Activity<NowPlayingAttributes>,
        content: ActivityContent<NowPlayingAttributes.ContentState>
    ) async {
        await activity.update(content)
    }

    /// Main-actor wrapper to end an Activity on the UI actor
    @MainActor
    private func endActivityOnMain(
        _ activity: Activity<NowPlayingAttributes>,
        content: ActivityContent<NowPlayingAttributes.ContentState>
    ) async {
        await activity.end(content, dismissalPolicy: .default)
    }

    /// Main-actor wrapper to end all Activities on the UI actor
    @MainActor
    private func endAllActivitiesOnMain(
        _ activities: [Activity<NowPlayingAttributes>]
    ) async {
        for activity in activities {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
    }
}

// MARK: - WidgetArtworkCache Extension

extension WidgetArtworkCache {
    /// Load artwork as UIImage from cache
    func loadArtworkImage(forKey key: String) -> UIImage? {
        guard let cacheURL = FileManager.default.widgetArtworkCacheURL else {
            return nil
        }

        let fileURL = cacheURL.appendingPathComponent("\(key).jpg")

        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL),
              let image = UIImage(data: data) else {
            return nil
        }

        return image
    }
}
