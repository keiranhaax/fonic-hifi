//
//  WidgetDataCoordinator.swift
//  Fonic HiFi
//
//  Created by Claude on 11/26/25.
//

import Combine
import Foundation
import OSLog

@MainActor
protocol WidgetSharedStateManaging: AnyObject {
    @discardableResult
    func updatePlaybackState(_ state: WidgetPlaybackState) -> Bool

    @discardableResult
    func updateTrackInfo(_ track: WidgetTrackInfo?) -> Bool

    @discardableResult
    func updateUpNextTracks(_ tracks: [WidgetTrackInfo]) -> Bool

    func loadTrackInfo() -> WidgetTrackInfo?
    func loadUpNextTracks() -> [WidgetTrackInfo]
    func reloadWidgetTimelines()
}

extension AppGroupManager: WidgetSharedStateManaging {}

/// Coordinates data synchronization between the main app and widget extension.
/// Queue mutations drive updates directly; no timer or idle polling is used.
@MainActor
public final class WidgetDataCoordinator: ObservableObject {
    // MARK: - Dependencies

    private let playbackStateProvider: @MainActor @Sendable () -> PlaybackState
    private let queueStateProvider: @MainActor @Sendable () -> QueueState
    private let artworkDataProvider: (@MainActor @Sendable (UUID) async -> Data?)?
    private let appGroupManager: any WidgetSharedStateManaging
    private let artworkCache: any WidgetArtworkCaching
    private let reloadDelay: @Sendable () async throws -> Void

    // MARK: - Private Properties

    private let logger = Log.logger(.widget)
    private var cancellables = Set<AnyCancellable>()
    private var queuePayloadTask: Task<Void, Never>?
    private var reloadDebounceTask: Task<Void, Never>?
    private var queueGeneration: UInt = 0
    private var reloadGeneration: UInt = 0
    private var latestQueueState: QueueState

    // MARK: - Published State

    @Published public private(set) var isSyncing = false
    @Published public private(set) var lastSyncDate: Date?

    // MARK: - Initialization

    public convenience init(
        stateManager: PlaybackStateManager,
        queueManager: AudioQueueManager,
        artworkService: ArtworkService? = nil
    ) {
        let artworkDataProvider: (@MainActor @Sendable (UUID) async -> Data?)?
        if let artworkService {
            artworkDataProvider = { trackId in
                await artworkService.loadArtworkData(forTrackId: trackId)
            }
        } else {
            artworkDataProvider = nil
        }

        self.init(
            playbackStateProvider: { stateManager.currentState },
            playbackStatePublisher: stateManager.statePublisher,
            queueStateProvider: { queueManager.queueState },
            queueStatePublisher: queueManager.queueStatePublisher,
            artworkDataProvider: artworkDataProvider,
            appGroupManager: AppGroupManager.shared,
            artworkCache: WidgetArtworkCache.shared,
            reloadDelay: {
                try await Task.sleep(for: .milliseconds(500))
            }
        )
    }

    init(
        playbackStateProvider: @escaping @MainActor @Sendable () -> PlaybackState,
        playbackStatePublisher: AnyPublisher<PlaybackStateChange, Never>,
        queueStateProvider: @escaping @MainActor @Sendable () -> QueueState,
        queueStatePublisher: AnyPublisher<QueueState, Never>,
        artworkDataProvider: (@MainActor @Sendable (UUID) async -> Data?)?,
        appGroupManager: any WidgetSharedStateManaging,
        artworkCache: any WidgetArtworkCaching,
        reloadDelay: @escaping @Sendable () async throws -> Void
    ) {
        self.playbackStateProvider = playbackStateProvider
        self.queueStateProvider = queueStateProvider
        self.artworkDataProvider = artworkDataProvider
        self.appGroupManager = appGroupManager
        self.artworkCache = artworkCache
        self.reloadDelay = reloadDelay

        let initialQueueState = queueStateProvider()
        latestQueueState = initialQueueState

        setupObservers(
            playbackStatePublisher: playbackStatePublisher,
            queueStatePublisher: queueStatePublisher,
            initialQueueState: initialQueueState
        )

        logger.info("WidgetDataCoordinator initialized")
    }

    deinit {
        queuePayloadTask?.cancel()
        reloadDebounceTask?.cancel()
    }

    // MARK: - Setup

    private func setupObservers(
        playbackStatePublisher: AnyPublisher<PlaybackStateChange, Never>,
        queueStatePublisher: AnyPublisher<QueueState, Never>,
        initialQueueState: QueueState
    ) {
        playbackStatePublisher
            .sink { [weak self] change in
                self?.handlePlaybackStateChange(change)
            }
            .store(in: &cancellables)

        // The queue publisher is mutation-only. Prepending the state captured on
        // this MainActor turn gives a coherent immediate snapshot without a race
        // window or a periodic wake-up.
        queueStatePublisher
            .prepend(initialQueueState)
            .sink { [weak self] state in
                self?.handleQueueStateChange(state)
            }
            .store(in: &cancellables)
    }

    // MARK: - State Change Handlers

    private func handlePlaybackStateChange(_ change: PlaybackStateChange) {
        let playbackState = createWidgetPlaybackState(
            from: change.nextState,
            queueState: latestQueueState
        )
        recordChange(appGroupManager.updatePlaybackState(playbackState))
    }

    private func handleQueueStateChange(_ state: QueueState) {
        latestQueueState = state
        queueGeneration &+= 1
        let generation = queueGeneration

        queuePayloadTask?.cancel()

        // Persist a complete queue snapshot synchronously. Reuse only artwork keys
        // already associated with the same IDs so a new track never inherits stale
        // artwork while the cache actor resolves files.
        let persistedArtworkKeys = persistedArtworkKeys(for: state)
        let changed = applyQueuePayload(state, artworkKeys: persistedArtworkKeys)
        recordChange(changed)

        let task = makeArtworkEnrichmentTask(for: state, generation: generation)
        queuePayloadTask = task
    }

    // MARK: - Sync Methods

    /// Perform a full, awaited sync of current state to App Group.
    /// App Intents use this after mutating playback or queue state.
    public func syncCurrentState() async {
        isSyncing = true
        defer {
            isSyncing = false
            lastSyncDate = Date()
        }

        let currentQueueState = queueStateProvider()
        latestQueueState = currentQueueState
        queueGeneration &+= 1
        let generation = queueGeneration

        queuePayloadTask?.cancel()

        let persistedArtworkKeys = persistedArtworkKeys(for: currentQueueState)
        let changed = applyQueuePayload(
            currentQueueState,
            artworkKeys: persistedArtworkKeys
        )
        recordChange(changed)

        let task = makeArtworkEnrichmentTask(
            for: currentQueueState,
            generation: generation
        )
        queuePayloadTask = task
        await withTaskCancellationHandler {
            await task.value
        } onCancel: {
            task.cancel()
        }

        logger.info("Full widget state sync completed")
    }

    // MARK: - Queue Payloads

    private func applyQueuePayload(
        _ queueState: QueueState,
        artworkKeys: Set<String>
    ) -> Bool {
        let playbackState = createWidgetPlaybackState(
            from: playbackStateProvider(),
            queueState: queueState
        )
        let currentTrackInfo = queueState.currentTrack.map {
            makeTrackInfo(from: $0, artworkKeys: artworkKeys)
        }
        let upNextTracks = queueState.remainingTracks.prefix(5).map {
            makeTrackInfo(from: $0, artworkKeys: artworkKeys)
        }

        let playbackChanged = appGroupManager.updatePlaybackState(playbackState)
        let trackChanged = appGroupManager.updateTrackInfo(currentTrackInfo)
        let upNextChanged = appGroupManager.updateUpNextTracks(Array(upNextTracks))
        return playbackChanged || trackChanged || upNextChanged
    }

    private func makeArtworkEnrichmentTask(
        for queueState: QueueState,
        generation: UInt
    ) -> Task<Void, Never> {
        let artworkCache = artworkCache
        let artworkDataProvider = artworkDataProvider
        let trackIds = Array(
            ([queueState.currentTrack].compactMap { $0 }
                + Array(queueState.remainingTracks.prefix(5))).map(\.id)
        )

        return Task { @MainActor [weak self] in
            let cachedKeys = await artworkCache.existingArtworkKeys(for: trackIds)
            guard !Task.isCancelled else { return }

            if let self, self.queueGeneration == generation {
                self.recordChange(
                    self.applyQueuePayload(queueState, artworkKeys: cachedKeys)
                )
            } else {
                return
            }

            guard let currentTrack = queueState.currentTrack,
                  !cachedKeys.contains(currentTrack.id.uuidString),
                  let artworkDataProvider
            else {
                return
            }

            guard let artworkData = await artworkDataProvider(currentTrack.id) else {
                return
            }
            guard !Task.isCancelled else { return }

            do {
                guard let artworkKey = try await artworkCache.storeArtworkData(
                    artworkData,
                    forTrackId: currentTrack.id
                ) else {
                    return
                }
                try Task.checkCancellation()

                guard let self, self.queueGeneration == generation else { return }
                var resolvedKeys = cachedKeys
                resolvedKeys.insert(artworkKey)
                self.recordChange(
                    self.applyQueuePayload(queueState, artworkKeys: resolvedKeys)
                )
            } catch is CancellationError {
                // A newer queue event owns the payload now.
            } catch {
                self?.logger.error(
                    "Failed to cache widget artwork: \(error.localizedDescription, privacy: .private)"
                )
            }
        }
    }

    private func persistedArtworkKeys(for queueState: QueueState) -> Set<String> {
        let relevantTrackIds = Set(
            ([queueState.currentTrack].compactMap { $0 }
                + Array(queueState.remainingTracks.prefix(5))).map(\.id)
        )

        var keys = Set<String>()
        let persistedTracks = [appGroupManager.loadTrackInfo()].compactMap { $0 }
            + appGroupManager.loadUpNextTracks()

        for track in persistedTracks
            where relevantTrackIds.contains(track.id) {
            if let artworkKey = track.artworkKey {
                keys.insert(artworkKey)
            }
        }
        return keys
    }

    private func makeTrackInfo(
        from track: AudioTrack,
        artworkKeys: Set<String>
    ) -> WidgetTrackInfo {
        let artworkKey = track.id.uuidString
        return WidgetTrackInfo(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration,
            artworkKey: artworkKeys.contains(artworkKey) ? artworkKey : nil,
            audioFormat: track.audioFormat,
            isLossless: track.format.isLossless
        )
    }

    private func createWidgetPlaybackState(
        from state: PlaybackState,
        queueState: QueueState
    ) -> WidgetPlaybackState {
        let repeatModeString = switch queueState.repeatMode {
        case .none: "none"
        case .one: "one"
        case .all: "all"
        }

        return WidgetPlaybackState(
            isPlaying: state.isPlaying,
            currentTime: state.currentTime ?? 0,
            duration: state.duration ?? 0,
            shuffleEnabled: queueState.shuffleMode.isActive,
            repeatMode: repeatModeString,
            hasNext: queueState.hasNext,
            hasPrevious: queueState.hasPrevious,
            timestamp: Date(),
            playbackRate: state.isPlaying ? 1.0 : 0.0
        )
    }

    // MARK: - Reload Debounce

    private func recordChange(_ changed: Bool) {
        guard changed else { return }
        lastSyncDate = Date()
        scheduleWidgetReload()
    }

    private func scheduleWidgetReload() {
        reloadGeneration &+= 1
        let generation = reloadGeneration
        let reloadDelay = reloadDelay
        let appGroupManager = appGroupManager

        reloadDebounceTask?.cancel()
        reloadDebounceTask = Task { @MainActor [weak self] in
            do {
                try await reloadDelay()
                try Task.checkCancellation()
            } catch {
                return
            }

            guard let self, self.reloadGeneration == generation else { return }
            appGroupManager.reloadWidgetTimelines()
        }
    }

    // MARK: - Test Synchronization

    func waitForPendingQueueUpdate() async {
        let task = queuePayloadTask
        await task?.value
    }

    func waitForPendingReload() async {
        let task = reloadDebounceTask
        await task?.value
    }
}
