//
//  AudioQueueManager.swift
//  Fonic HiFi
//
//  Created by Claude on 5/27/25.
//

import Foundation
import Observation

/// Main actor class that manages the audio playback queue
@MainActor
@Observable
public final class AudioQueueManager: AudioQueue, Sendable {
    
    // MARK: - Published Properties
    
    /// All tracks in the queue
    public private(set) var tracks: [AudioTrack] = []
    
    /// Current playing index
    public private(set) var currentIndex: Int?
    
    /// Shuffle mode setting
    public var shuffleMode: QueueShuffleMode = .off {
        didSet {
            if shuffleMode != oldValue {
                handleShuffleModeChange(from: oldValue, to: shuffleMode)
                delegate?.audioQueue(self, didChangeShuffleMode: shuffleMode)
            }
        }
    }
    
    /// Repeat mode setting
    public var repeatMode: QueueRepeatMode = .none {
        didSet {
            if repeatMode != oldValue {
                updateNavigationState()
                delegate?.audioQueue(self, didChangeRepeatMode: repeatMode)
            }
        }
    }
    
    /// Playback history
    public private(set) var history: [AudioTrack] = []
    
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
    
    /// Queue delegate for change notifications
    public weak var delegate: AudioQueueDelegate?
    
    // MARK: - Computed Properties
    
    /// Current track being played
    public var currentTrack: AudioTrack? {
        guard let index = currentIndex,
              index >= 0 && index < tracks.count else { return nil }
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
            currentIndex: currentIndex,
            shuffleMode: shuffleMode,
            repeatMode: repeatMode,
            hasNext: _hasNext,
            hasPrevious: _hasPrevious,
            history: history,
            shuffleSequence: shuffleMode.isActive ? shuffleSequence : nil,
            timestamp: Date()
        )
    }
    
    // MARK: - Initialization
    
    public init(maxHistorySize: Int = 50, delegate: AudioQueueDelegate? = nil) {
        self.maxHistorySize = maxHistorySize
        self.delegate = delegate
    }
    
    // MARK: - Queue Operations
    
    public func enqueue(tracks newTracks: [AudioTrack]) {
        guard !newTracks.isEmpty else { return }
        
        tracks.append(contentsOf: newTracks)
        originalOrder.append(contentsOf: newTracks)
        
        // Update shuffle sequence if needed
        if shuffleMode.isActive {
            updateShuffleSequence()
        }
        
        markNavigationStateDirty()
        notifyTracksChanged()
    }
    
    public func enqueueNext(tracks newTracks: [AudioTrack]) {
        guard !newTracks.isEmpty else { return }
        
        let insertIndex = currentIndex.map { $0 + 1 } ?? 0
        insert(tracks: newTracks, at: insertIndex)
    }
    
    public func enqueueLater(tracks newTracks: [AudioTrack]) {
        enqueue(tracks: newTracks)
    }
    
    @discardableResult
    public func remove(at index: Int) -> AudioTrack? {
        guard index >= 0 && index < tracks.count else { return nil }
        
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
        
        // Update shuffle sequence
        if shuffleMode.isActive {
            updateShuffleSequence()
        }
        
        markNavigationStateDirty()
        notifyTracksChanged()
        
        return removedTrack
    }
    
    @discardableResult
    public func remove(track: AudioTrack) -> Bool {
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else { return false }
        remove(at: index)
        return true
    }
    
    public func move(from fromIndex: Int, to toIndex: Int) {
        guard fromIndex >= 0 && fromIndex < tracks.count &&
              toIndex >= 0 && toIndex < tracks.count &&
              fromIndex != toIndex else { return }
        
        let track = tracks.remove(at: fromIndex)
        tracks.insert(track, at: toIndex)
        
        // Update current index if needed
        if let current = currentIndex {
            if fromIndex == current {
                currentIndex = toIndex
                notifyCurrentTrackChanged()
            } else if fromIndex < current && toIndex >= current {
                currentIndex = current - 1
                notifyCurrentTrackChanged()
            } else if fromIndex > current && toIndex <= current {
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
    }
    
    public func clear() {
        tracks.removeAll()
        originalOrder.removeAll()
        shuffleSequence.removeAll()
        shuffleSequenceCache.removeAll() // Clear cache when clearing queue
        currentIndex = nil

        markNavigationStateDirty()
        notifyTracksChanged()
        notifyCurrentTrackChanged()
    }
    
    public func clearHistory() {
        history.removeAll()
    }
    
    // MARK: - Navigation
    
    public func next() -> AudioTrack? {
        let nextIndex = calculateNextIndex()
        guard let index = nextIndex else { return nil }
        
        // Add current track to history before moving
        if let currentTrack = currentTrack {
            addToHistory(track: currentTrack)
        }
        
        setCurrentIndex(index)
        return currentTrack
    }
    
    public func previous() -> AudioTrack? {
        let previousIndex = calculatePreviousIndex()
        guard let index = previousIndex else { return nil }
        
        setCurrentIndex(index)
        return currentTrack
    }
    
    @discardableResult
    public func setCurrentIndex(_ index: Int?) -> Bool {
        guard index != currentIndex else { return true }
        
        if let index = index {
            guard index >= 0 && index < tracks.count else { return false }
        }
        
        currentIndex = index
        markNavigationStateDirty()
        notifyCurrentTrackChanged()
        return true
    }
    
    @discardableResult
    public func setCurrentTrack(_ track: AudioTrack?) -> Bool {
        guard let track = track else {
            return setCurrentIndex(nil)
        }
        
        guard let index = tracks.firstIndex(where: { $0.id == track.id }) else {
            return false
        }
        
        return setCurrentIndex(index)
    }
    
    // MARK: - Queue Manipulation
    
    public func replaceQueue(with newTracks: [AudioTrack], startIndex: Int?) {
        tracks = newTracks
        originalOrder = newTracks
        
        if shuffleMode.isActive {
            updateShuffleSequence()
        }
        
        currentIndex = startIndex
        
        markNavigationStateDirty()
        notifyTracksChanged()
        notifyCurrentTrackChanged()
    }
    
    public func insert(tracks newTracks: [AudioTrack], at index: Int) {
        guard !newTracks.isEmpty else { return }
        guard index >= 0 && index <= tracks.count else { return }
        
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
    }
    
    public func shuffle() {
        shuffleMode = shuffleMode.isActive ? shuffleMode : .random
        updateShuffleSequence()
    }
    
    public func restoreOrder() {
        guard shuffleMode.isActive else { return }
        
        // Preserve current track
        let currentTrack = self.currentTrack
        
        // Restore original order
        tracks = originalOrder
        shuffleMode = .off
        shuffleSequence.removeAll()
        
        // Find current track in restored order
        if let track = currentTrack {
            currentIndex = tracks.firstIndex { $0.id == track.id }
        }
        
        markNavigationStateDirty()
        notifyTracksChanged()
        notifyCurrentTrackChanged()
    }
    
    // MARK: - Private Methods
    
    private func handleShuffleModeChange(from oldMode: QueueShuffleMode, to newMode: QueueShuffleMode) {
        if newMode.isActive && !oldMode.isActive {
            // Turning shuffle on
            updateShuffleSequence()
        } else if !newMode.isActive && oldMode.isActive {
            // Turning shuffle off - restore original order
            restoreOriginalOrder()
        } else if newMode.isActive && oldMode.isActive {
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
                tracks: tracks
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
            
            // Update current index to match shuffled position
            if let currentTrack = currentTrack {
                currentIndex = tracks.firstIndex { $0.id == currentTrack.id }
            }
        }
    }
    
    private func restoreOriginalOrder() {
        let currentTrack = self.currentTrack
        tracks = originalOrder
        shuffleSequence.removeAll()
        shuffleSequenceCache.removeAll() // Clear cache when restoring order

        // Find current track in original order
        if let track = currentTrack {
            currentIndex = tracks.firstIndex { $0.id == track.id }
        }
    }
    
    private func calculateNextIndex() -> Int? {
        if shuffleMode.isActive {
            return shuffleMode.nextIndex(
                currentIndex: currentIndex,
                shuffleSequence: shuffleSequence,
                repeatMode: repeatMode
            )
        } else {
            return repeatMode.nextIndex(
                from: currentIndex,
                queueCount: tracks.count
            )
        }
    }
    
    private func calculatePreviousIndex() -> Int? {
        if shuffleMode.isActive {
            return shuffleMode.previousIndex(
                currentIndex: currentIndex,
                shuffleSequence: shuffleSequence,
                repeatMode: repeatMode
            )
        } else {
            return repeatMode.previousIndex(
                from: currentIndex,
                queueCount: tracks.count
            )
        }
    }
    
    private func updateNavigationState() {
        _hasNext = repeatMode.hasNext(
            currentIndex: currentIndex,
            queueCount: tracks.count,
            isShuffled: shuffleMode.isActive
        )
        
        _hasPrevious = repeatMode.hasPrevious(
            currentIndex: currentIndex,
            queueCount: tracks.count,
            isShuffled: shuffleMode.isActive
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

extension AudioQueueManager {
    
    /// Get debug information about the queue state
    public var debugInfo: String {
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
    public func validateState() -> [String] {
        var issues: [String] = []
        
        if tracks.count != originalOrder.count {
            issues.append("Track count mismatch: tracks=\(tracks.count), original=\(originalOrder.count)")
        }
        
        if shuffleMode.isActive && shuffleSequence.count != tracks.count {
            issues.append("Shuffle sequence count mismatch: sequence=\(shuffleSequence.count), tracks=\(tracks.count)")
        }
        
        if let currentIndex = currentIndex {
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
    public func getNextTrack() -> AudioTrack? {
        guard hasNext else { return nil }
        guard let currentIndex = currentIndex else { return nil }
        
        if repeatMode == .one {
            return currentTrack
        }
        
        let nextIndex = currentIndex + 1
        if nextIndex < tracks.count {
            return tracks[nextIndex]
        } else if repeatMode == .all && !tracks.isEmpty {
            return tracks[0]
        }
        
        return nil
    }
    
    /// Move to the next track in the queue
    /// - Returns: True if moved successfully, false otherwise
    public func moveToNext() -> Bool {
        guard hasNext else { return false }
        return next() != nil
    }
    
    /// Get the previous track in the queue
    /// - Returns: The previous track, or nil if no previous track
    public func getPreviousTrack() -> AudioTrack? {
        guard hasPrevious else { return nil }
        guard let currentIndex = currentIndex, currentIndex > 0 else { return nil }
        return tracks[currentIndex - 1]
    }
    
    /// Move to the previous track in the queue
    /// - Returns: True if moved successfully, false otherwise
    public func moveToPrevious() -> Bool {
        guard hasPrevious else { return false }
        return previous() != nil
    }
} 