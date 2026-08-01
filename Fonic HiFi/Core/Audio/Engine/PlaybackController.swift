//
//  PlaybackController.swift
//  Fonic HiFi
//
//  Extracted playback operations from the facade for Phase 2C modularisation.
//

import Foundation
import MediaPlayer
import OSLog
import UIKit

@MainActor
protocol PlaybackQueueHandling: AnyObject {
    func play(track: Track, queueEntry: AudioTrack?) async throws
    func crossfade(to audioTrack: AudioTrack, displayTrack: Track) async throws
    func stop() async
}

@MainActor
final class PlaybackController {
    typealias DiagnosticsHandler = @MainActor (Track, AudioFileInfo?) async -> Void
    typealias TrackCompletionHandler = @MainActor () async -> Void
    typealias LoopCheckHandler = @MainActor (TimeInterval) -> TimeInterval?

    private static let progressPollInterval: TimeInterval = 0.1

    private let sessionManager: any AudioSessionService
    private let formatDetectionManager: any FormatDetectionService
    private let validator: BitPerfectValidator
    private let stateManager: PlaybackStateManager
    private let queueManager: AudioQueueManager
    private let engineManager: AudioEngineManager
    private let progressTimer: ProgressTimerManager
    private let uiState: AudioUIState
    private let diagnosticsHandler: DiagnosticsHandler
    private let nowProvider: @Sendable () -> Date
    private let nowPlayingSyncInterval: TimeInterval
    private var lastNowPlayingSyncDate: Date?

    /// Callback invoked when a track finishes playing naturally (not stopped by user)
    var onTrackComplete: TrackCompletionHandler?

    /// Callback to check if A-B loop should trigger. Returns seek target if loop needed.
    var loopCheckHandler: LoopCheckHandler?

    private let logger = Log.logger(.playbackController)

    init(
        sessionManager: any AudioSessionService,
        formatDetectionManager: any FormatDetectionService,
        validator: BitPerfectValidator,
        stateManager: PlaybackStateManager,
        queueManager: AudioQueueManager,
        engineManager: AudioEngineManager,
        progressTimer: ProgressTimerManager,
        uiState: AudioUIState,
        diagnosticsHandler: @escaping DiagnosticsHandler,
        nowProvider: @escaping @Sendable () -> Date = Date.init,
        nowPlayingSyncInterval: TimeInterval = 5.0,
    ) {
        self.sessionManager = sessionManager
        self.formatDetectionManager = formatDetectionManager
        self.validator = validator
        self.stateManager = stateManager
        self.queueManager = queueManager
        self.engineManager = engineManager
        self.progressTimer = progressTimer
        self.uiState = uiState
        self.diagnosticsHandler = diagnosticsHandler
        self.nowProvider = nowProvider
        self.nowPlayingSyncInterval = max(0, nowPlayingSyncInterval)
    }

    // MARK: - Playback Commands

    func play(track: Track, queueEntry: AudioTrack? = nil) async throws {
        let info = try await formatDetectionManager.detectFormat(at: track.url)
        try Task.checkCancellation()
        await sessionManager.setPreferredSampleRate(info.sampleRate)
        try Task.checkCancellation()
        try await sessionManager.activateAudioSession()
        try Task.checkCancellation()
        logger.info("Detected format for playback: \(info.format.displayName, privacy: .public)")

        let audioTrack = queueEntry ?? track.toAudioTrack()
        let preparedEngine = engineManager.currentEngine
        let preparedTransition = if let preparedEngine {
            await preparedEngine.consumePreparedTransition(to: audioTrack.url)
        } else {
            PreparedTrackTransition.none
        }
        let adoptedPreparedTransition = preparedTransition.wasAdopted
        let engine: AudioEngineService
        if adoptedPreparedTransition, let preparedEngine {
            engine = preparedEngine
            if preparedTransition == .preloadedFallback {
                logger.info(
                    "Adopted preloaded track with a stop/start fallback; no render-boundary gapless claim"
                )
            }
        } else {
            engine = try await engineManager.ensureEngine(for: info)
        }
        try Task.checkCancellation()

        if engineManager.configuration.performanceMode == .quality {
            let validation = await validator.validateBitPerfectPlayback(
                sourceFormat: info,
                outputDevice: nil,
                context: await engineManager.bitPerfectEligibilityContext()
            )
            try Task.checkCancellation()
            if !validation.isValid {
                logger.warning("Bit-perfect eligibility check failed: \(validation.mismatchReason?.userFriendlyDescription ?? "Unknown", privacy: .private)")
            }
        }

        if queueManager.currentTrack?.id != audioTrack.id {
            queueManager.setCurrentTrack(audioTrack)
        }

        uiState.currentTrack = track
        uiState.showMiniPlayer = true
        stateManager.updateState(.loading())

        if !adoptedPreparedTransition {
            try await engine.load(url: audioTrack.url)
            try Task.checkCancellation()
        }
        await applyPlaybackParameters(for: audioTrack, engine: engine)
        try Task.checkCancellation()

        // Set completion handler for auto-advance
        engine.setCompletionHandler(Self.makeCompletionHandler(owner: self))

        if !adoptedPreparedTransition {
            try await engine.play()
            try Task.checkCancellation()
        }

        stateManager.updateState(.playing(currentTime: 0, duration: info.duration))
        await updateNowPlayingInfo(track: track, duration: info.duration)
        try Task.checkCancellation()

        startProgressTracking(engine: engine)
        await diagnosticsHandler(track, info)
        try Task.checkCancellation()
        await prepareUpcomingTrack(engine: engine)
        try Task.checkCancellation()
    }

    func resume() async throws {
        guard let engine = engineManager.currentEngine else {
            throw AudioError.engineInitializationFailed(reason: "Engine not ready")
        }

        try await sessionManager.activateAudioSession()
        try Task.checkCancellation()

        if let track = uiState.currentTrack {
            await applyPlaybackParameters(for: track, engine: engine)
            try Task.checkCancellation()
        }

        try await engine.play()
        try Task.checkCancellation()

        let currentTime = await engine.currentTime
        try Task.checkCancellation()
        let duration = await engine.duration
        try Task.checkCancellation()
        stateManager.updateState(.playing(currentTime: currentTime, duration: duration))

        if let track = uiState.currentTrack {
            await updateNowPlayingInfo(track: track, duration: duration, currentTime: currentTime)
            try Task.checkCancellation()
            await prepareUpcomingTrack(engine: engine)
            try Task.checkCancellation()
            await diagnosticsHandler(track, nil)
            try Task.checkCancellation()
        }

        startProgressTracking(engine: engine)
    }

    func pause() async {
        guard let engine = engineManager.currentEngine else {
            logger.warning("Cannot pause: engine not ready")
            return
        }

        progressTimer.stop()
        await engine.pause()

        let currentTime = await engine.currentTime
        let duration = await engine.duration
        stateManager.updateState(.paused(currentTime: currentTime, duration: duration))
        if let track = uiState.currentTrack {
            await updateNowPlayingInfo(track: track, duration: duration, currentTime: currentTime, playbackRate: 0)
        }
    }

    func stop() async {
        progressTimer.stop()

        if let engine = engineManager.currentEngine {
            await engine.stop()
        }

        stateManager.updateState(.stopped)
        uiState.reset()
        await sessionManager.clearNowPlayingInfo()
        lastNowPlayingSyncDate = nil
    }

    func seek(to time: TimeInterval) async throws {
        guard let engine = engineManager.currentEngine else {
            throw AudioError.engineInitializationFailed(reason: "Engine not ready")
        }

        let currentState = stateManager.currentState
        guard currentState.canSeek else {
            throw AudioError.playbackFailed(reason: "Cannot seek in current state")
        }

        let currentTime = await engine.currentTime
        let duration = await engine.duration
        stateManager.updateState(.seeking(targetTime: time, currentTime: currentTime))

        do {
            try await engine.seek(to: time)
            if currentState.isPlaying {
                stateManager.updateState(.playing(currentTime: time, duration: duration))
            } else {
                stateManager.updateState(.paused(currentTime: time, duration: duration))
            }
            if let track = uiState.currentTrack {
                let playbackRate: Float = currentState.isPlaying ? Float(engineManager.configuration.playbackRate) : 0
                await updateNowPlayingInfo(track: track, duration: duration, currentTime: time, playbackRate: playbackRate)
            }
        } catch {
            if currentState.isPlaying {
                stateManager.updateState(.playing(currentTime: currentTime, duration: duration))
            } else {
                stateManager.updateState(.paused(currentTime: currentTime, duration: duration))
            }
            throw error
        }
    }

    func setVolume(_ volume: Float) async {
        guard let engine = engineManager.currentEngine else {
            logger.warning("Cannot set volume: engine not ready")
            return
        }

        await engine.setVolume(max(0.0, min(1.0, volume)))
    }

    func crossfade(to audioTrack: AudioTrack, displayTrack: Track) async throws {
        guard let engine = engineManager.currentEngine else {
            try await play(track: displayTrack, queueEntry: audioTrack)
            return
        }

        uiState.currentTrack = displayTrack
        uiState.showMiniPlayer = true
        stateManager.updateState(.loading())

        let gain = replayGainValue(for: audioTrack, mode: engineManager.configuration.replayGainMode)
        try await engine.crossfade(
            to: audioTrack.url,
            duration: engineManager.configuration.crossfadeDuration,
            playbackRate: engineManager.configuration.playbackRate,
            gainDB: gain,
        )
        try Task.checkCancellation()

        stateManager.updateState(.playing(currentTime: 0, duration: audioTrack.duration))
        await updateNowPlayingInfo(track: displayTrack, duration: audioTrack.duration)
        try Task.checkCancellation()
        startProgressTracking(engine: engine)
        await diagnosticsHandler(displayTrack, nil)
        try Task.checkCancellation()
        await prepareUpcomingTrack(engine: engine)
        try Task.checkCancellation()
    }

    /// Rebuild playback after AVFoundation resets media services.
    ///
    /// The replacement engine is loaded and positioned but intentionally left
    /// paused. This prevents an unsolicited resume while preserving the user's
    /// track and elapsed time in both app state and Now Playing.
    func recoverAfterMediaServicesReset(
        track: Track,
        queueEntry: AudioTrack?,
        info: AudioFileInfo,
        preservedPosition: TimeInterval
    ) async throws {
        progressTimer.stop()

        let engine = try await engineManager.rebuildEngineAfterMediaServicesReset(for: info)
        let audioTrack = queueEntry ?? track.toAudioTrack()
        let duration = info.duration > 0 ? info.duration : audioTrack.duration
        let position = min(max(0, preservedPosition), max(0, duration))

        try await engine.load(url: audioTrack.url)
        await applyPlaybackParameters(for: audioTrack, engine: engine)
        engine.setCompletionHandler(Self.makeCompletionHandler(owner: self))

        if position > 0 {
            try await engine.seek(to: position)
        }
        await engine.pause()

        uiState.currentTrack = track
        uiState.showMiniPlayer = true
        stateManager.forceUpdateState(.paused(currentTime: position, duration: duration))
        await updateNowPlayingInfo(
            track: track,
            duration: duration,
            currentTime: position,
            playbackRate: 0
        )
        await prepareUpcomingTrack(engine: engine)
    }

    // MARK: - Helpers

    private nonisolated static func makeCompletionHandler(
        owner: PlaybackController
    ) -> () -> Void {
        { [weak owner] in
            Task { @MainActor [weak owner] in
                await owner?.handleTrackCompletion()
            }
        }
    }

    private func applyPlaybackParameters(for track: any TrackProtocol, engine: AudioEngineService) async {
        await engine.setPlaybackRate(engineManager.configuration.playbackRate)
        let gain = replayGainValue(for: track, mode: engineManager.configuration.replayGainMode)
        await engine.applyReplayGain(gain)
    }

    private func replayGainValue(for track: any TrackProtocol, mode: ReplayGainMode) -> Float {
        switch mode {
        case .off:
            0
        case .track:
            track.replayGainTrack ?? 0
        case .album:
            track.replayGainAlbum ?? track.replayGainTrack ?? 0
        }
    }

    private func prepareUpcomingTrack(engine: AudioEngineService) async {
        guard engineManager.configuration.enableGapless,
              engineManager.configuration.crossfadeDuration == 0,
              let nextTrack = queueManager.getNextTrack()
        else {
            return
        }

        await engine.prepareNext(url: nextTrack.url)
    }

    private func startProgressTracking(engine: AudioEngineService) {
        progressTimer.start(pollInterval: Self.progressPollInterval) { [weak self] in
            guard let self else { return }
            await refreshPlaybackProgress(engine: engine)
        }
    }

    /// Refresh one playback progress cycle.
    ///
    /// Kept as a deterministic unit-test seam because timer scheduling is not
    /// part of the seek/A-B behavior being verified.
    func refreshPlaybackProgress(engine: AudioEngineService) async {
        guard stateManager.currentState.isPlaying else { return }

        async let currentTime = engine.currentTime
        async let duration = engine.duration
        let (time, total) = await (currentTime, duration)
        stateManager.updateTime(time, duration: total)

        var elapsedTime = time
        var forceNowPlayingUpdate = false
        if let seekTarget = loopCheckHandler?(time) {
            do {
                try await engine.seek(to: seekTarget)
                stateManager.updateTime(seekTarget, duration: total)
                elapsedTime = seekTarget
                forceNowPlayingUpdate = true
            } catch is CancellationError {
                return
            } catch {
                guard !Task.isCancelled else { return }
                let playbackError = Self.loopSeekPlaybackError(from: error)
                logger.error(
                    "A-B loop seek failed: \(String(describing: error), privacy: .private)"
                )
                progressTimer.stop()
                stateManager.handleEngineError(playbackError, currentTime: time)
                return
            }
        }

        await updateNowPlayingElapsedTimeIfNeeded(
            currentTime: elapsedTime,
            force: forceNowPlayingUpdate
        )
    }

    private static func loopSeekPlaybackError(from error: any Error) -> AudioError {
        if let audioError = error as? AudioError {
            return audioError
        }
        return .playbackFailed(reason: "A-B loop seek failed")
    }

    private func updateNowPlayingElapsedTimeIfNeeded(
        currentTime: TimeInterval,
        force: Bool = false
    ) async {
        let now = nowProvider()
        if !force,
           let lastNowPlayingSyncDate,
           nowPlayingSyncInterval > 0,
           now.timeIntervalSince(lastNowPlayingSyncDate) < nowPlayingSyncInterval {
            return
        }

        var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = engineManager.configuration.playbackRate
        await sessionManager.updateNowPlayingInfo(nowPlayingInfo)
        lastNowPlayingSyncDate = now
    }

    private func updateNowPlayingInfo(
        track: Track,
        duration: TimeInterval,
        currentTime: TimeInterval = 0,
        playbackRate: Float? = nil
    ) async {
        var artworkImage: UIImage?
        if let data = track.artwork {
            artworkImage = UIImage(data: data)
        }

        var nowPlayingInfo = track.toNowPlayingInfo(
            currentTime: currentTime,
            playbackRate: playbackRate ?? Float(engineManager.configuration.playbackRate),
            artwork: artworkImage,
        )
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration

        await sessionManager.updateNowPlayingInfo(nowPlayingInfo)
        lastNowPlayingSyncDate = nowProvider()
    }

    /// Handle track completion - called when engine finishes playing naturally
    private func handleTrackCompletion() async {
        logger.info("Track completed naturally")
        progressTimer.stop()

        // Invoke the completion callback (set by facade for auto-advance)
        if let onTrackComplete {
            await onTrackComplete()
        } else {
            // No callback set - just stop
            stateManager.updateState(.stopped)
        }
    }

    func reapplyPlaybackParameters() async {
        guard let engine = engineManager.currentEngine else { return }
        if let track = uiState.currentTrack {
            await applyPlaybackParameters(for: track, engine: engine)
        }
    }

    func refreshNowPlayingMetadata() async {
        guard let engine = engineManager.currentEngine,
              let track = uiState.currentTrack else { return }

        async let currentTime = engine.currentTime
        async let duration = engine.duration
        let (time, total) = await (currentTime, duration)

        await updateNowPlayingInfo(track: track, duration: total, currentTime: time)
    }
}

@MainActor
extension PlaybackController: PlaybackQueueHandling {}
