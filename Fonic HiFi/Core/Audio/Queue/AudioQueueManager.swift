//
//  AudioQueueManager.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Combine
import Foundation
import Observation
import OSLog

/// Main actor class that manages the audio playback queue
@MainActor
@Observable
public final class AudioQueueManager: AudioQueue {
    private let logger = Log.logger(.audioQueueManager)

    // MARK: - Published Properties

    /// All tracks in the queue
    public private(set) var tracks: [AudioTrack] = []

    /// Current playing index
    public private(set) var currentIndex: Int?

    /// Shuffle mode setting
    public var shuffleMode: QueueShuffleMode = .off {
        didSet {
            beginQueueStateMutation()
            defer { endQueueStateMutation() }

            if shuffleMode != oldValue {
                handleShuffleModeChange(from: oldValue, to: shuffleMode)
                delegate?.audioQueue(self, didChangeShuffleMode: shuffleMode)
                markQueueStateEmissionPending()
            }
        }
    }

    /// Repeat mode setting
    public var repeatMode: QueueRepeatMode = .none {
        didSet {
            beginQueueStateMutation()
            defer { endQueueStateMutation() }

            if repeatMode != oldValue {
                updateNavigationState()
                delegate?.audioQueue(self, didChangeRepeatMode: repeatMode)
                markQueueStateEmissionPending()
            }
        }
    }

    /// Playback history
    public private(set) var history: [AudioTrack] = []

    /// Most recently persisted playback position for force-quit resume.
    private var lastPlaybackPosition: TimeInterval = 0

    // MARK: - Private Properties

    /// Original order of tracks (before shuffle)
    private var originalOrder: [AudioTrack] = []

    /// Current shuffle sequence
    private var shuffleSequence: [Int] = []

    /// Cached shuffle sequences for performance
    private var shuffleSequenceCache: [String: [Int]] = [:]

    /// Whether navigation state is dirty and needs recalculation
    private var navigationStateDirty = true

    /// Cached navigation state
    private var _hasNext = false
    private var _hasPrevious = false

    /// Maximum history size (default 50)
    private let maxHistorySize: Int

    /// Queue persistence owner. Automatic writes are coalesced and performed off MainActor.
    @ObservationIgnored
    private let queueStatePersister: any QueueStatePersisting

    /// Queue delegate for change notifications
    public weak var delegate: AudioQueueDelegate?

    /// Emits one immutable final snapshot for each logical queue-state mutation.
    @ObservationIgnored
    private let queueStateSubject = PassthroughSubject<QueueState, Never>()

    @ObservationIgnored
    private var queueStateMutationDepth = 0

    @ObservationIgnored
    private var queueStateEmissionPending = false

    @ObservationIgnored
    private var queueStatePersistenceSuppressionDepth = 0

    @ObservationIgnored
    private var restoredFallbackNeedsPersistence = false

    // MARK: - Computed Properties

    /// Current track being played
    public var currentTrack: AudioTrack? {
        guard let index = currentIndex,
              index >= 0, index < tracks.count else { return nil }
        return tracks[index]
    }

    /// Whether there is a next track available
    public var hasNext: Bool {
        updateNavigationStateIfNeeded()
        return _hasNext
    }

    /// Whether there is a previous track available
    public var hasPrevious: Bool {
        updateNavigationStateIfNeeded()
        return _hasPrevious
    }

    /// Current queue state snapshot
    public var queueState: QueueState {
        updateNavigationStateIfNeeded()
        return QueueState(
            tracks: tracks,
            originalTracks: originalOrder,
            currentIndex: currentIndex,
            shuffleMode: shuffleMode,
            repeatMode: repeatMode,
            hasNext: _hasNext,
            hasPrevious: _hasPrevious,
            history: history,
            shuffleSequence: shuffleMode.isActive ? shuffleSequence : nil,
            timestamp: Date(),
            lastPlaybackPosition: lastPlaybackPosition
        )
    }

    /// A mutation-only queue-state stream. Read `queueState` separately when an initial value is needed.
    public var queueStatePublisher: AnyPublisher<QueueState, Never> {
        queueStateSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init(
        maxHistorySize: Int = 50,
        delegate: AudioQueueDelegate? = nil,
        queueStateSuiteName: String? = nil
    ) {
        self.maxHistorySize = maxHistorySize
        self.delegate = delegate
        queueStatePersister = UserDefaultsQueueStatePersister(suiteName: queueStateSuiteName)
    }

    init(
        maxHistorySize: Int = 50,
        delegate: AudioQueueDelegate? = nil,
        queueStatePersister: any QueueStatePersisting
    ) {
        self.maxHistorySize = maxHistorySize
        self.delegate = delegate
        self.queueStatePersister = queueStatePersister
    }

    // MARK: - Queue Operations

    public func enqueue(tracks newTracks: [AudioTrack]) {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard !newTracks.isEmpty else { return }

        tracks.append(contentsOf: newTracks)
        originalOrder.append(contentsOf: newTracks)

        // Update shuffle sequence if needed
        if shuffleMode.isActive {
            updateShuffleSequence()
        }

        markNavigationStateDirty()
        notifyTracksChanged()
        recordQueueMutation("enqueue", extra: [
            "delta": "\(newTracks.count)"
        ])
        markQueueStateEmissionPending()
    }

    public func enqueueNext(tracks newTracks: [AudioTrack]) {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard !newTracks.isEmpty else { return }

        let insertIndex = currentIndex.map { $0 + 1 } ?? 0
        insert(tracks: newTracks, at: insertIndex)
        recordQueueMutation("enqueueNext", extra: [
            "delta": "\(newTracks.count)",
            "index": "\(insertIndex)"
        ])
    }

    public func enqueueLater(tracks newTracks: [AudioTrack]) {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        enqueue(tracks: newTracks)
    }

    @discardableResult
    public func remove(at index: Int) -> AudioTrack? {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard index >= 0, index < tracks.count else { return nil }
        let previousCurrentTrackID = currentTrack?.id

        let removedTrack = tracks.remove(at: index)

        // Update original order
        if let originalIndex = originalOrder.firstIndex(where: { $0.id == removedTrack.id }) {
            originalOrder.remove(at: originalIndex)
        }

        // Adjust current index if needed
        if let current = currentIndex {
            if index == current {
                // Removed current track, keep same index but track will change
                if tracks.isEmpty {
                    currentIndex = nil
                } else if current >= tracks.count {
                    currentIndex = tracks.count - 1
                }
                notifyCurrentTrackChanged()
            } else if index < current {
                // Removed track before current, shift index down
                currentIndex = current - 1
                notifyCurrentTrackChanged()
            }
        }

        if previousCurrentTrackID != currentTrack?.id {
            lastPlaybackPosition = 0
        }

        // Update shuffle sequence
        if shuffleMode.isActive {
            updateShuffleSequence()
        }

        markNavigationStateDirty()
        notifyTracksChanged()

        recordQueueMutation("remove", extra: [
            "index": "\(index)"
        ])
        markQueueStateEmissionPending()

        return removedTrack
    }

    @discardableResult
    public func remove(track: AudioTrack) -> Bool {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return false }
        remove(at: index)
        return true
    }

    public func removeRemaining(at offsets: IndexSet) {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        let baseIndex = currentIndex.map { $0 + 1 } ?? 0
        var remaining = Array(tracks.dropFirst(baseIndex))
        let sortedOffsets = offsets.sorted()

        guard !sortedOffsets.isEmpty,
              sortedOffsets.allSatisfy(remaining.indices.contains) else { return }

        let removedIDs = Set(sortedOffsets.map { remaining[$0].id })
        for offset in sortedOffsets.reversed() {
            remaining.remove(at: offset)
        }

        if shuffleMode.isActive {
            tracks = Array(tracks.prefix(baseIndex)) + remaining
            originalOrder.removeAll { removedIDs.contains($0.id) }
            finishShuffledRemainingEdit()
        } else {
            replaceQueue(with: Array(tracks.prefix(baseIndex)) + remaining, startIndex: currentIndex)
        }
    }

    public func move(from fromIndex: Int, to toIndex: Int) {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard fromIndex >= 0, fromIndex < tracks.count,
              toIndex >= 0, toIndex < tracks.count,
              fromIndex != toIndex else { return }

        let track = tracks.remove(at: fromIndex)
        tracks.insert(track, at: toIndex)

        // Update current index if needed
        if let current = currentIndex {
            if fromIndex == current {
                currentIndex = toIndex
                notifyCurrentTrackChanged()
            } else if fromIndex < current, toIndex >= current {
                currentIndex = current - 1
                notifyCurrentTrackChanged()
            } else if fromIndex > current, toIndex <= current {
                currentIndex = current + 1
                notifyCurrentTrackChanged()
            }
        }

        // Update shuffle sequence
        if shuffleMode.isActive {
            updateShuffleSequence()
        }

        markNavigationStateDirty()
        notifyTracksChanged()

        recordQueueMutation("move", extra: [
            "from": "\(fromIndex)",
            "to": "\(toIndex)"
        ])
        markQueueStateEmissionPending()
    }

    public func moveRemaining(fromOffsets source: IndexSet, toOffset destination: Int) {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        let baseIndex = currentIndex.map { $0 + 1 } ?? 0
        let remaining = Array(tracks.dropFirst(baseIndex))
        let sortedOffsets = source.sorted()

        guard !sortedOffsets.isEmpty,
              destination >= 0, destination <= remaining.count,
              sortedOffsets.allSatisfy(remaining.indices.contains) else { return }

        let movingTracks = sortedOffsets.map { remaining[$0] }
        var reorderedRemaining = remaining
        for offset in sortedOffsets.reversed() {
            reorderedRemaining.remove(at: offset)
        }

        let removedBeforeDestination = sortedOffsets.filter { $0 < destination }.count
        let insertionIndex = destination - removedBeforeDestination
        reorderedRemaining.insert(contentsOf: movingTracks, at: insertionIndex)

        let reorderedTracks = Array(tracks.prefix(baseIndex)) + reorderedRemaining
        if shuffleMode.isActive {
            tracks = reorderedTracks
            finishShuffledRemainingEdit()
        } else {
            replaceQueue(with: reorderedTracks, startIndex: currentIndex)
        }
    }

    public func clear() {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        let hadVisibleQueueState = !tracks.isEmpty ||
            !originalOrder.isEmpty ||
            !shuffleSequence.isEmpty ||
            currentIndex != nil

        tracks.removeAll()
        originalOrder.removeAll()
        shuffleSequence.removeAll()
        shuffleSequenceCache.removeAll() // Clear cache when clearing queue
        currentIndex = nil
        lastPlaybackPosition = 0

        markNavigationStateDirty()
        notifyTracksChanged()
        notifyCurrentTrackChanged()

        recordQueueMutation("clear")
        if hadVisibleQueueState {
            markQueueStateEmissionPending()
        }
    }

    public func clearHistory() {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard !history.isEmpty else { return }
        history.removeAll()
        markQueueStateEmissionPending()
    }

    // MARK: - Navigation

    /// Returns the next track without changing queue state or persistence.
    /// Playback callers use this to prepare audio before committing a queue
    /// transition, so a failed load/play cannot advance the persisted queue.
    public func peekNext() -> AudioTrack? {
        peekNext(using: repeatMode)
    }

    /// Returns the next manually-requested track without changing queue state.
    public func peekNextManually() -> AudioTrack? {
        peekNext(using: repeatMode.manualNavigationMode)
    }

    /// Returns the next natural-completion track without changing queue state.
    public func peekNextAfterCompletion() -> AudioTrack? {
        peekNext(using: repeatMode)
    }

    /// Returns the previous manually-requested track without changing queue state.
    public func peekPreviousManually() -> AudioTrack? {
        guard let index = calculatePreviousIndex(using: repeatMode.manualNavigationMode),
              tracks.indices.contains(index)
        else {
            return nil
        }
        return tracks[index]
    }

    /// Commits a previously peeked next track after playback has succeeded.
    /// The expected ID prevents a stale async playback request from overwriting
    /// a newer queue mutation.
    @discardableResult
    public func commitNext(
        _ track: AudioTrack,
        expectedCurrentID: UUID?
    ) -> Bool {
        commitNavigation(
            to: track,
            expectedCurrentID: expectedCurrentID,
            addCurrentToHistory: true,
            action: "next"
        )
    }

    /// Commits a previously peeked previous track after playback has succeeded.
    @discardableResult
    public func commitPrevious(
        _ track: AudioTrack,
        expectedCurrentID: UUID?
    ) -> Bool {
        commitNavigation(
            to: track,
            expectedCurrentID: expectedCurrentID,
            addCurrentToHistory: false,
            action: "previous"
        )
    }

    public func next() -> AudioTrack? {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        return advanceToNext(using: repeatMode)
    }

    /// Advances for an explicit user skip, which escapes repeat-one.
    public func nextManually() -> AudioTrack? {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        return advanceToNext(using: repeatMode.manualNavigationMode)
    }

    private func advanceToNext(using navigationRepeatMode: QueueRepeatMode) -> AudioTrack? {
        let nextIndex = calculateNextIndex(using: navigationRepeatMode)
        guard let index = nextIndex else { return nil }

        // Add current track to history before moving
        if let currentTrack {
            addToHistory(track: currentTrack)
        }

        setCurrentIndex(index)
        recordQueueMutation("next")
        return currentTrack
    }

    private func peekNext(using navigationRepeatMode: QueueRepeatMode) -> AudioTrack? {
        guard let index = calculateNextIndex(using: navigationRepeatMode),
              tracks.indices.contains(index)
        else {
            return nil
        }
        return tracks[index]
    }

    @discardableResult
    private func commitNavigation(
        to track: AudioTrack,
        expectedCurrentID: UUID?,
        addCurrentToHistory: Bool,
        action: String
    ) -> Bool {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard currentTrack?.id == expectedCurrentID,
              let index = tracks.firstIndex(where: { $0.id == track.id })
        else {
            return false
        }

        if addCurrentToHistory, let currentTrack, currentTrack.id != track.id {
            addToHistory(track: currentTrack)
        }

        guard setCurrentIndex(index) else { return false }
        recordQueueMutation(action)
        markQueueStateEmissionPending()
        return true
    }

    public func previous() -> AudioTrack? {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        return moveToPrevious(using: repeatMode)
    }

    /// Moves backward for an explicit user skip, which escapes repeat-one.
    public func previousManually() -> AudioTrack? {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        return moveToPrevious(using: repeatMode.manualNavigationMode)
    }

    private func moveToPrevious(using navigationRepeatMode: QueueRepeatMode) -> AudioTrack? {
        let previousIndex = calculatePreviousIndex(using: navigationRepeatMode)
        guard let index = previousIndex else { return nil }

        setCurrentIndex(index)
        recordQueueMutation("previous")
        return currentTrack
    }

    @discardableResult
    public func setCurrentIndex(_ index: Int?) -> Bool {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard index != currentIndex else { return true }

        if let index {
            guard index >= 0, index < tracks.count else { return false }
        }

        let previousCurrentTrackID = currentTrack?.id
        currentIndex = index
        if previousCurrentTrackID != currentTrack?.id {
            lastPlaybackPosition = 0
        }
        markNavigationStateDirty()
        notifyCurrentTrackChanged()
        markQueueStateEmissionPending()
        return true
    }

    @discardableResult
    public func setCurrentTrack(_ track: AudioTrack?) -> Bool {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard let track else {
            return setCurrentIndex(nil)
        }

        // If track exists in queue, select it
        if let index = tracks.firstIndex(where: { $0.id == track.id }) {
            return setCurrentIndex(index)
        }

        // Track not in queue - append it and select
        enqueue(track: track)
        return setCurrentIndex(tracks.count - 1)
    }

    /// Installs a launch fallback without replacing a persisted queue that may
    /// only be temporarily unavailable. The fallback becomes durable once the
    /// user successfully resumes playback.
    @discardableResult
    func restoreFallbackTrack(_ track: AudioTrack) -> Bool {
        queueStatePersistenceSuppressionDepth += 1
        defer { queueStatePersistenceSuppressionDepth -= 1 }

        let didRestore = setCurrentTrack(track)
        if didRestore {
            restoredFallbackNeedsPersistence = true
        }
        return didRestore
    }

    func commitRestoredFallbackIfNeeded() {
        guard restoredFallbackNeedsPersistence else { return }
        restoredFallbackNeedsPersistence = false
        queueStatePersister.requestSave(queueState)
    }

    // MARK: - Queue Manipulation

    public func replaceQueue(with newTracks: [AudioTrack], startIndex: Int?) {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        let previousCurrentTrackID = currentTrack?.id
        tracks = newTracks
        originalOrder = newTracks

        if shuffleMode.isActive {
            updateShuffleSequence()
        }

        currentIndex = startIndex
        if previousCurrentTrackID != currentTrack?.id {
            lastPlaybackPosition = 0
        }

        markNavigationStateDirty()
        notifyTracksChanged()
        notifyCurrentTrackChanged()

        recordQueueMutation("replace", extra: [
            "size": "\(newTracks.count)",
            "startIndex": startIndex.map(String.init) ?? "nil"
        ])
        markQueueStateEmissionPending()
    }

    public func insert(tracks newTracks: [AudioTrack], at index: Int) {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard !newTracks.isEmpty else { return }
        guard index >= 0, index <= tracks.count else { return }

        for (offset, track) in newTracks.enumerated() {
            tracks.insert(track, at: index + offset)
            originalOrder.insert(track, at: originalOrder.endIndex)
        }

        // Adjust current index if needed
        if let current = currentIndex, index <= current {
            currentIndex = current + newTracks.count
            notifyCurrentTrackChanged()
        }

        // Update shuffle sequence
        if shuffleMode.isActive {
            updateShuffleSequence()
        }

        markNavigationStateDirty()
        notifyTracksChanged()

        recordQueueMutation("insert", extra: [
            "delta": "\(newTracks.count)",
            "index": "\(index)"
        ])
        markQueueStateEmissionPending()
    }

    public func shuffle() {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        let previousTrackIDs = tracks.map(\.id)
        let previousSequence = shuffleSequence
        shuffleMode = shuffleMode.isActive ? shuffleMode : .random
        updateShuffleSequence()
        recordQueueMutation("shuffle", extra: [
            "mode": shuffleMode.description
        ])
        if tracks.map(\.id) != previousTrackIDs || shuffleSequence != previousSequence {
            markQueueStateEmissionPending()
        }
    }

    public func restoreOrder() {
        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        guard shuffleMode.isActive else { return }

        // Preserve current track
        let preservedTrack = currentTrack

        // Restoring shuffle mode to off will invoke restoreOriginalOrder()
        shuffleMode = .off

        // Re-select the preserved track once original ordering is restored
        if let track = preservedTrack {
            currentIndex = tracks.firstIndex { $0.id == track.id }
        } else {
            currentIndex = nil
        }

        markNavigationStateDirty()
        notifyTracksChanged()
        notifyCurrentTrackChanged()

        recordQueueMutation("restoreOrder")
    }

    // MARK: - Private Methods

    private func beginQueueStateMutation() {
        queueStateMutationDepth += 1
    }

    private func endQueueStateMutation() {
        precondition(queueStateMutationDepth > 0, "Unbalanced queue-state mutation scope")
        queueStateMutationDepth -= 1

        guard queueStateMutationDepth == 0 else { return }

        guard queueStateEmissionPending else { return }
        queueStateEmissionPending = false
        let finalState = queueState
        queueStateSubject.send(finalState)
        guard queueStatePersistenceSuppressionDepth == 0 else { return }
        restoredFallbackNeedsPersistence = false
        queueStatePersister.requestSave(finalState)
    }

    private func markQueueStateEmissionPending() {
        queueStateEmissionPending = true
    }

    private func handleShuffleModeChange(from oldMode: QueueShuffleMode, to newMode: QueueShuffleMode) {
        if newMode.isActive, !oldMode.isActive {
            // Turning shuffle on
            updateShuffleSequence()
        } else if !newMode.isActive, oldMode.isActive {
            // Turning shuffle off - restore original order
            restoreOriginalOrder()
        } else if newMode.isActive, oldMode.isActive {
            // Changing shuffle type
            updateShuffleSequence()
        }

        markNavigationStateDirty()
    }

    private func updateShuffleSequence() {
        guard shuffleMode.isActive else {
            shuffleSequence.removeAll()
            return
        }

        let preservedTrack = currentTrack

        // Generate cache key based on tracks and mode
        let cacheKey = "\(shuffleMode.rawValue)_\(tracks.count)_\(currentIndex?.description ?? "nil")"

        // Check if we have a cached sequence
        if let cached = shuffleSequenceCache[cacheKey] {
            shuffleSequence = cached
        } else {
            // Generate new sequence and cache it
            shuffleSequence = shuffleMode.generateShuffleSequence(
                trackCount: tracks.count,
                currentIndex: currentIndex,
                tracks: tracks,
            )

            // Limit cache size to prevent memory growth
            if shuffleSequenceCache.count > 10 {
                // Remove oldest entries (simple FIFO)
                let keysToRemove = Array(shuffleSequenceCache.keys.prefix(5))
                keysToRemove.forEach { shuffleSequenceCache.removeValue(forKey: $0) }
            }

            shuffleSequenceCache[cacheKey] = shuffleSequence
        }

        // Reorder tracks according to shuffle sequence
        if !shuffleSequence.isEmpty {
            let shuffledTracks = shuffleSequence.compactMap { index in
                originalOrder.indices.contains(index) ? originalOrder[index] : nil
            }
            tracks = shuffledTracks

            if let preservedTrack,
               let preservedIndex = tracks.firstIndex(where: { $0.id == preservedTrack.id }) {
                currentIndex = preservedIndex
            } else {
                currentIndex = tracks.isEmpty ? nil : 0
            }
        }
    }

    private func restoreOriginalOrder() {
        let currentTrack = currentTrack
        tracks = originalOrder
        shuffleSequence.removeAll()
        shuffleSequenceCache.removeAll() // Clear cache when restoring order

        // Find current track in original order
        if let track = currentTrack {
            currentIndex = tracks.firstIndex { $0.id == track.id }
        }
    }

    private func finishShuffledRemainingEdit() {
        shuffleSequence = Array(tracks.indices)
        shuffleSequenceCache.removeAll()
        markNavigationStateDirty()
        notifyTracksChanged()
        markQueueStateEmissionPending()
    }

    private func recordQueueMutation(_ action: String, extra: [String: String] = [:]) {
        var metadata = extra
        metadata["action"] = action
        metadata["size"] = "\(tracks.count)"
        Metrics.increment(.queueMutation, metadata: metadata)
    }

    private func calculateNextIndex(using navigationRepeatMode: QueueRepeatMode? = nil) -> Int? {
        let effectiveRepeatMode = navigationRepeatMode ?? repeatMode

        if shuffleMode.isActive {
            return shuffleMode.nextIndex(
                currentIndex: currentIndex,
                shuffleSequence: shuffleSequence,
                repeatMode: effectiveRepeatMode,
            )
        } else {
            return effectiveRepeatMode.nextIndex(
                from: currentIndex,
                queueCount: tracks.count,
            )
        }
    }

    private func calculatePreviousIndex(using navigationRepeatMode: QueueRepeatMode? = nil) -> Int? {
        let effectiveRepeatMode = navigationRepeatMode ?? repeatMode

        if shuffleMode.isActive {
            return shuffleMode.previousIndex(
                currentIndex: currentIndex,
                shuffleSequence: shuffleSequence,
                repeatMode: effectiveRepeatMode,
            )
        } else {
            return effectiveRepeatMode.previousIndex(
                from: currentIndex,
                queueCount: tracks.count,
            )
        }
    }

    private func updateNavigationState() {
        _hasNext = repeatMode.hasNext(
            currentIndex: currentIndex,
            queueCount: tracks.count,
            isShuffled: shuffleMode.isActive,
        )

        _hasPrevious = repeatMode.hasPrevious(
            currentIndex: currentIndex,
            queueCount: tracks.count,
            isShuffled: shuffleMode.isActive,
        )

        // More precise check based on actual next/previous calculation
        if !_hasNext {
            _hasNext = calculateNextIndex() != nil
        }

        if !_hasPrevious {
            _hasPrevious = calculatePreviousIndex() != nil
        }

        navigationStateDirty = false
    }

    private func updateNavigationStateIfNeeded() {
        if navigationStateDirty {
            updateNavigationState()
        }
    }

    private func markNavigationStateDirty() {
        navigationStateDirty = true
    }

    private func addToHistory(track: AudioTrack) {
        // Remove if already in history to avoid duplicates
        history.removeAll { $0.id == track.id }

        // Add to beginning
        history.insert(track, at: 0)

        // Trim to max size
        if history.count > maxHistorySize {
            history = Array(history.prefix(maxHistorySize))
        }

        delegate?.audioQueue(self, didAddToHistory: track)
        markQueueStateEmissionPending()
    }

    // MARK: - Persistence

    /// Save current queue state to persistence
    /// - Parameter playbackPosition: Current playback position in seconds (for resume)
    public func saveState(playbackPosition: TimeInterval = 0) async {
        lastPlaybackPosition = playbackPosition
        let state = QueueState(
            tracks: tracks,
            originalTracks: originalOrder,
            currentIndex: currentIndex,
            shuffleMode: shuffleMode,
            repeatMode: repeatMode,
            hasNext: hasNext,
            hasPrevious: hasPrevious,
            history: history,
            shuffleSequence: shuffleMode.isActive ? shuffleSequence : nil,
            timestamp: Date(),
            lastPlaybackPosition: playbackPosition
        )

        await queueStatePersister.save(state)
    }

    /// Restore queue state from persistence
    /// - Returns: true if state was restored, false otherwise
    @discardableResult
    public func restoreState() async -> Bool {
        guard let validatedState = await queueStatePersister.load(),
              !validatedState.isEmpty
        else {
            return false
        }

        beginQueueStateMutation()
        defer { endQueueStateMutation() }

        // Set modes before restoring tracks so shuffle observers cannot reorder persisted traversal.
        shuffleMode = validatedState.shuffleMode
        repeatMode = validatedState.repeatMode
        tracks = validatedState.tracks
        originalOrder = validatedState.originalTracks ?? validatedState.tracks
        currentIndex = validatedState.currentIndex
        shuffleSequence = shuffleMode.isActive ? Array(tracks.indices) : []

        // Restore history
        history = validatedState.history
        lastPlaybackPosition = validatedState.lastPlaybackPosition

        // Update navigation state
        markNavigationStateDirty()

        // Notify delegates
        notifyTracksChanged()
        notifyCurrentTrackChanged()
        markQueueStateEmissionPending()

        return true
    }

    /// Clear persisted queue state
    public func clearSavedState() async {
        await queueStatePersister.clear()
    }

    /// Waits for the current coalesced automatic write, primarily for lifecycle and test synchronization.
    public func flushPendingPersistence() async {
        await queueStatePersister.flush()
    }

    // MARK: - Notifications

    private func notifyTracksChanged() {
        delegate?.audioQueue(self, didUpdateTracks: tracks)
    }

    private func notifyCurrentTrackChanged() {
        delegate?.audioQueue(self, didChangeCurrentTrack: currentTrack, at: currentIndex)
    }
}

// MARK: - Debug Support

public extension AudioQueueManager {
    /// Get debug information about the queue state
    var debugInfo: String {
        let shuffleInfo = shuffleMode.isActive ?
            "Shuffle: \(shuffleMode.description) (sequence: \(shuffleSequence))" :
            "Shuffle: Off"

        return """
        AudioQueueManager Debug Info:
        - Tracks: \(tracks.count)
        - Current Index: \(currentIndex?.description ?? "nil")
        - Current Track: \(currentTrack?.title ?? "None")
        - \(shuffleInfo)
        - Repeat: \(repeatMode.description)
        - Has Next: \(hasNext)
        - Has Previous: \(hasPrevious)
        - History: \(history.count) tracks
        - Original Order: \(originalOrder.count) tracks
        """
    }

    /// Validate internal consistency (for debugging)
    func validateState() -> [String] {
        var issues: [String] = []

        if tracks.count != originalOrder.count {
            issues.append("Track count mismatch: tracks=\(tracks.count), original=\(originalOrder.count)")
        }

        if shuffleMode.isActive, shuffleSequence.count != tracks.count {
            issues.append("Shuffle sequence count mismatch: sequence=\(shuffleSequence.count), tracks=\(tracks.count)")
        }

        if let currentIndex {
            if currentIndex < 0 || currentIndex >= tracks.count {
                issues.append("Current index out of bounds: \(currentIndex) (tracks: \(tracks.count))")
            }
        }

        if history.count > maxHistorySize {
            issues.append("History exceeds max size: \(history.count) > \(maxHistorySize)")
        }

        return issues
    }

    // MARK: - Navigation Methods

    /// Get the next track in the queue
    /// - Returns: The next track, or nil if no next track
    func getNextTrack() -> AudioTrack? {
        guard hasNext else { return nil }
        guard let currentIndex else { return nil }

        if repeatMode == .one {
            return currentTrack
        }

        let nextIndex = currentIndex + 1
        if nextIndex < tracks.count {
            return tracks[nextIndex]
        } else if repeatMode == .all, !tracks.isEmpty {
            return tracks[0]
        }

        return nil
    }

    /// Move to the next track in the queue
    /// - Returns: True if moved successfully, false otherwise
    func moveToNext() -> Bool {
        guard hasNext else { return false }
        return next() != nil
    }

    /// Get the previous track in the queue
    /// - Returns: The previous track, or nil if no previous track
    func getPreviousTrack() -> AudioTrack? {
        guard hasPrevious else { return nil }
        guard let currentIndex, currentIndex > 0 else { return nil }
        return tracks[currentIndex - 1]
    }

    /// Move to the previous track in the queue
    /// - Returns: True if moved successfully, false otherwise
    func moveToPrevious() -> Bool {
        guard hasPrevious else { return false }
        return previous() != nil
    }
}
