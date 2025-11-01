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

    private let sessionManager: AudioSessionManager
    private let formatDetectionManager: AudioFormatDetectionManager
    private let validator: BitPerfectValidator
    private let stateManager: PlaybackStateManager
    private let queueManager: AudioQueueManager
    private let engineManager: AudioEngineManager
    private let progressTimer: ProgressTimerManager
    private let uiState: AudioUIState
    private let diagnosticsHandler: DiagnosticsHandler

    private let logger = Log.logger(.playbackController)

    init(
        sessionManager: AudioSessionManager,
        formatDetectionManager: AudioFormatDetectionManager,
        validator: BitPerfectValidator,
        stateManager: PlaybackStateManager,
        queueManager: AudioQueueManager,
        engineManager: AudioEngineManager,
        progressTimer: ProgressTimerManager,
        uiState: AudioUIState,
        diagnosticsHandler: @escaping DiagnosticsHandler,
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
    }

    // MARK: - Playback Commands

    func play(track: Track, queueEntry: AudioTrack? = nil) async throws {
        try await sessionManager.activateAudioSession()

        let info = try await formatDetectionManager.detectFormat(at: track.url)
        logger.info("Detected format for playback: \(info.format.displayName)")

        if engineManager.configuration.performanceMode == .quality {
            let validation = await validator.validateBitPerfectPlayback(
                sourceFormat: info,
                outputDevice: nil,
            )
            if !validation.isValid {
                logger.warning("Bit-perfect validation failed: \(validation.mismatchReason?.userFriendlyDescription ?? "Unknown")")
            }
        }

        let engine = try await engineManager.ensureEngine(for: info)

        let audioTrack = queueEntry ?? track.toAudioTrack()
        if queueManager.currentTrack?.id != audioTrack.id {
            queueManager.setCurrentTrack(audioTrack)
        }

        uiState.currentTrack = track
        uiState.showMiniPlayer = true
        stateManager.updateState(.loading())

        try await engine.load(url: audioTrack.url)
        await applyPlaybackParameters(for: audioTrack, engine: engine)
        try await engine.play()

        stateManager.updateState(.playing(currentTime: 0, duration: info.duration))
        await updateNowPlayingInfo(track: track, duration: info.duration)

        startProgressTracking(engine: engine)
        await diagnosticsHandler(track, info)
        await prepareUpcomingTrack(engine: engine)
    }

    func resume() async throws {
        guard let engine = engineManager.currentEngine else {
            throw AudioError.engineInitializationFailed(reason: "Engine not ready")
        }

        try await sessionManager.activateAudioSession()

        if let track = uiState.currentTrack {
            await applyPlaybackParameters(for: track, engine: engine)
        }

        try await engine.play()

        let currentTime = await engine.currentTime
        let duration = await engine.duration
        stateManager.updateState(.playing(currentTime: currentTime, duration: duration))

        if let track = uiState.currentTrack {
            await updateNowPlayingInfo(track: track, duration: duration, currentTime: currentTime)
            await prepareUpcomingTrack(engine: engine)
            await diagnosticsHandler(track, nil)
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
    }

    func stop() async {
        progressTimer.stop()

        if let engine = engineManager.currentEngine {
            await engine.stop()
        }

        stateManager.updateState(.stopped)
        uiState.reset()
        await sessionManager.clearNowPlayingInfo()
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

        stateManager.updateState(.playing(currentTime: 0, duration: audioTrack.duration))
        await updateNowPlayingInfo(track: displayTrack, duration: audioTrack.duration)
        startProgressTracking(engine: engine)
        await diagnosticsHandler(displayTrack, nil)
        await prepareUpcomingTrack(engine: engine)
    }

    // MARK: - Helpers

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
        guard engineManager.configuration.enableGapless || engineManager.configuration.crossfadeDuration > 0,
              let nextTrack = queueManager.getNextTrack()
        else {
            return
        }

        await engine.prepareNext(url: nextTrack.url)
    }

    private func startProgressTracking(engine: AudioEngineService) {
        progressTimer.start(pollInterval: 0.2) { [weak self] in
            guard let self else { return }
            guard stateManager.currentState.isPlaying else { return }

            async let currentTime = engine.currentTime
            async let duration = engine.duration
            let (time, total) = await (currentTime, duration)
            stateManager.updateTime(time, duration: total)

            var nowPlayingInfo = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
            nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = engineManager.configuration.playbackRate
            await sessionManager.updateNowPlayingInfo(nowPlayingInfo)
        }
    }

    private func updateNowPlayingInfo(track: Track, duration: TimeInterval, currentTime: TimeInterval = 0) async {
        var artworkImage: UIImage?
        if let data = track.artwork {
            artworkImage = UIImage(data: data)
        }

        var nowPlayingInfo = track.toNowPlayingInfo(
            currentTime: currentTime,
            playbackRate: Float(engineManager.configuration.playbackRate),
            artwork: artworkImage,
        )
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration

        await sessionManager.updateNowPlayingInfo(nowPlayingInfo)
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
