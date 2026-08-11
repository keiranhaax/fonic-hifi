//
//  AVAudioEngineAdapter.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import AVFoundation
import Foundation
import OSLog
#if canImport(Mach)
    import Mach
#endif

/// Main-actor callback used by the owning diagnostics surface when route
/// recovery cannot be completed. The adapter passes only a stable event kind
/// and privacy-safe detail; it never forwards URLs or localized error text.
public typealias ConfigurationRecoveryFailureHandler = @MainActor (
    PlaybackHealthEvent.Kind,
    String?
) -> Void

public struct ProcessMetricsSnapshot: Sendable, Equatable {
    public let cpuUsage: Float?
    public let residentMemoryBytes: Int64?

    public init(cpuUsage: Float?, residentMemoryBytes: Int64?) {
        self.cpuUsage = cpuUsage
        self.residentMemoryBytes = residentMemoryBytes
    }
}

/// Narrow boundary for process-level measurements used by engine diagnostics.
public protocol ProcessMetricsProviding: Sendable {
    func currentProcessMetrics() -> ProcessMetricsSnapshot
}

public struct MachProcessMetricsProvider: ProcessMetricsProviding {
    public init() {}

    public func currentProcessMetrics() -> ProcessMetricsSnapshot {
        #if canImport(Mach)
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }

        if result == KERN_SUCCESS {
            return ProcessMetricsSnapshot(
                cpuUsage: nil,
                residentMemoryBytes: Int64(info.resident_size)
            )
        }
        #endif

        return ProcessMetricsSnapshot(cpuUsage: nil, residentMemoryBytes: nil)
    }
}

private actor BufferUnderrunTracker {
    private var count = 0

    func increment() {
        count += 1
    }

    func reset() {
        count = 0
    }

    func value() -> Int {
        count
    }
}

/// AVAudioEngine-based implementation of AudioEngineService for standard audio formats
@MainActor
public final class AVAudioEngineAdapter: NSObject, AudioEngineService {
    // MARK: - Properties

    /// The underlying AVAudioEngine
    private let engine = AVAudioEngine()

    /// Primary player node for audio playback
    private let primaryPlayerNode = AVAudioPlayerNode()

    /// Secondary player node for gapless playback
    private let secondaryPlayerNode = AVAudioPlayerNode()

    /// Primary time pitch node for playback rate adjustment
    private let primaryTimePitchNode = AVAudioUnitTimePitch()

    /// Secondary time pitch node for gapless playback
    private let secondaryTimePitchNode = AVAudioUnitTimePitch()

    /// Independent per-chain gain stages. ReplayGain and crossfade ramps must
    /// not share the master submix volume, otherwise one chain can attenuate
    /// the other while both are rendered.
    private let primaryGainNode = AVAudioMixerNode()
    private let secondaryGainNode = AVAudioMixerNode()

    /// 10-band parametric equalizer
    private let eqNode = AVAudioUnitEQ(numberOfBands: 10)

    /// Submix node for combining both player chains before EQ
    private let submixNode = AVAudioMixerNode()

    /// Current EQ configuration
    private var eqConfiguration = EqualizerConfiguration.default

    /// Whether EQ processing is enabled
    public private(set) var isEQEnabled = false

    /// Whether the EQ node is currently in the audio graph
    private var isEQInGraph = true

    /// Tracks which player is currently active (true = primary)
    private var isPrimaryActive = true

    /// File prepared for gapless playback on secondary player
    private var preparedFile: AVAudioFile?

    /// Whether a next track has been prepared for gapless playback
    public private(set) var hasNextPrepared = false

    /// Current playback rate (1.0 = normal speed)
    public private(set) var currentPlaybackRate: Double = 1.0

    /// Current audio file being played
    private var audioFile: AVAudioFile?

    /// Total number of frames in the current file
    private var totalFrames: AVAudioFramePosition = 0

    /// Absolute source frame where the active player's current schedule begins.
    ///
    /// `AVAudioPlayerNode.playerTime(forNodeTime:)` reports time relative to the
    /// scheduled segment, so a seek must retain its source-frame base.
    private var scheduledStartFrame: AVAudioFramePosition = 0

    /// Last render time for tracking playback position
    private var lastRenderTime: AVAudioTime?

    private struct PreparedGaplessTransition {
        let url: URL
        let file: AVAudioFile
        let sourceGeneration: UUID
        let nextGeneration: UUID
        let nextPlayerIsPrimary: Bool
        let boundaryHostTime: UInt64
    }

    private var playbackGeneration: UUID?
    private var preparedTransition: PreparedGaplessTransition?
    private var unconsumedPreparedURL: URL?

    private var currentGainDB: Float = 0
    private var crossfadeTask: Task<Void, Never>?
    private var crossfadeGeneration: UUID?
    private var crossfadeSourceGeneration: UUID?
    private var crossfadeTargetGeneration: UUID?
    private var crossfadeTargetFile: AVAudioFile?
    private var crossfadeTargetGainDB: Float = 0
    private var crossfadeTargetCompleted = false
    private var crossfadeSleeper: @MainActor (Swift.Duration) async throws -> Void = {
        try await Task.sleep(for: $0)
    }

    /// True when pause() suspended a node that still owns its unrendered schedule.
    /// A resume must not schedule the file again because doing so appends a second
    /// copy of the track behind the paused segment.
    private var isSuspendedWithPendingSchedule = false

    /// Absolute source frame observed at pause while the node's render clock
    /// catches up after resume. This is an observation floor only; it never
    /// changes the scheduled segment or playback generation.
    private var suspendedPlaybackFrame: AVAudioFramePosition?

    // Progress updates are handled by AudioEngineFacade's ProgressTimerManager
    // No local timer needed

    /// Current playback state
    private var playbackState: PlaybackState = .idle

    private let processMetricsProvider: any ProcessMetricsProviding

    private let logger = Log.logger(.audioEngine)

    /// Current configuration
    private var configuration: AudioEngineConfiguration = .init()

    /// Completion handler for when playback finishes
    private var completionHandler: (() -> Void)?

    /// Performance metrics collector
    private var metricsStartTime: Date?
    private let bufferUnderruns = BufferUnderrunTracker()

    /// Coalesces configuration-change bursts before restarting the graph.
    private var configurationRecoveryScheduler: EngineConfigurationChangeRecoveryScheduler?

    /// Observer for route or hardware changes that stop this engine.
    private var configurationChangeObserver: NSObjectProtocol?

    private let configurationRecoveryFailureHandler: ConfigurationRecoveryFailureHandler?
    private var pendingConfigurationRecoveryFrame: AVAudioFramePosition?
    private var pendingConfigurationRecoveryWasPlaying: Bool?
    private var monitoringTapInstalled = false

    // MARK: - Initialization

    public init(
        processMetricsProvider: any ProcessMetricsProviding = MachProcessMetricsProvider(),
        configurationRecoveryFailureHandler: ConfigurationRecoveryFailureHandler? = nil
    ) throws {
        self.processMetricsProvider = processMetricsProvider
        self.configurationRecoveryFailureHandler = configurationRecoveryFailureHandler
        super.init()
        configurationRecoveryScheduler = EngineConfigurationChangeRecoveryScheduler { [weak self] in
            self?.recoverAfterConfigurationChange()
        }
        try setupEngine()
        observeConfigurationChanges()
    }

    // MARK: - AudioEngineService Implementation

    public var currentTime: TimeInterval {
        get async {
            guard let file = audioFile else { return 0 }

            let absoluteFrame = currentAbsolutePlaybackFrame()
            let visibleFrame: AVAudioFramePosition
            if let suspendedPlaybackFrame {
                if !isSuspendedWithPendingSchedule,
                   absoluteFrame >= suspendedPlaybackFrame {
                    self.suspendedPlaybackFrame = nil
                    visibleFrame = absoluteFrame
                } else {
                    visibleFrame = suspendedPlaybackFrame
                }
            } else {
                visibleFrame = absoluteFrame
            }

            return Double(visibleFrame) / file.processingFormat.sampleRate
        }
    }

    private func currentAbsolutePlaybackFrame() -> AVAudioFramePosition {
        guard audioFile != nil else { return 0 }

        let activePlayer = isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode
        let nodeSampleTime: AVAudioFramePosition
        if let renderTime = activePlayer.lastRenderTime,
           let playerTime = activePlayer.playerTime(forNodeTime: renderTime) {
            nodeSampleTime = playerTime.sampleTime
        } else {
            nodeSampleTime = 0
        }

        return Self.absolutePlaybackFrame(
            scheduledStartFrame: scheduledStartFrame,
            nodeSampleTime: nodeSampleTime,
            totalFrames: totalFrames
        )
    }

    public var duration: TimeInterval {
        get async {
            guard let file = audioFile else { return 0 }
            return Double(file.length) / file.processingFormat.sampleRate
        }
    }

    public var isPlaying: Bool {
        get async {
            let activePlayer = isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode
            return activePlayer.isPlaying
        }
    }

    public var volume: Float {
        get async {
            primaryPlayerNode.volume
        }
    }

    public var audioFormat: AudioFormat? {
        get async {
            guard let url = audioFile?.url else { return nil }
            return AudioFormat.from(url: url) ?? .unknown
        }
    }

    public var isBitPerfect: Bool {
        get async {
            // Check if sample rates match and no processing is applied
            guard let file = audioFile else { return false }
            let outputFormat = engine.outputNode.outputFormat(forBus: 0)

            return file.processingFormat.sampleRate == outputFormat.sampleRate &&
                primaryPlayerNode.volume == 1.0 &&
                abs(currentGainDB) < .ulpOfOne &&
                !hasAudioProcessing()
        }
    }

    public func playbackFormatEvidence() async -> AudioEngineFormatEvidence? {
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        return AudioEngineFormatEvidence(
            isTrackLoaded: audioFile != nil,
            loadedSampleRate: audioFile?.processingFormat.sampleRate,
            loadedChannelCount: audioFile.map { Int($0.processingFormat.channelCount) },
            engineOutputSampleRate: outputFormat.sampleRate > 0 ? outputFormat.sampleRate : nil,
            engineOutputChannelCount: outputFormat.channelCount > 0 ? Int(outputFormat.channelCount) : nil,
            hasEngineProcessing: hasAudioProcessing()
        )
    }

    public func load(url: URL) async throws {
        await unloadTrack()
        setupMonitoring()
        await bufferUnderruns.reset()
        isSuspendedWithPendingSchedule = false
        suspendedPlaybackFrame = nil
        pendingConfigurationRecoveryFrame = nil
        pendingConfigurationRecoveryWasPlaying = nil

        do {
            // Create audio file
            audioFile = try AVAudioFile(forReading: url)
            guard let file = audioFile else {
                throw AudioError.fileNotFound(url)
            }

            // Store total frames for duration calculation
            totalFrames = file.length
            scheduledStartFrame = 0

            try reconnectPlayerNodesIfNeeded(for: file.processingFormat)

            // Connect player node if needed
            if !engine.isRunning {
                try startEngine()
            }

            playbackState = .idle

        } catch {
            throw AudioError.decodingFailed(reason: error.localizedDescription)
        }
    }

    public func play() async throws {
        guard let file = audioFile else {
            throw AudioError.fileNotFound(URL(fileURLWithPath: ""))
        }

        let activePlayer = isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode

        // Audio session is managed by AudioSessionManager, not here

        // Start playback
        if !engine.isRunning {
            try startEngine()
        }

        // A paused player still owns the unrendered remainder of its schedule.
        // Re-scheduling here would append another copy of the current file and
        // reset any source-frame base established by a seek.
        if isSuspendedWithPendingSchedule,
           playbackGeneration != nil,
           scheduledStartFrame <= totalFrames {
            try activePlayer.playAudio()
            activeGainNode.outputVolume = linearGain(for: currentGainDB)
            isSuspendedWithPendingSchedule = false
            playbackState = await .playing(currentTime: currentTime, duration: duration)
            metricsStartTime = Date()
            return
        }

        let generation = UUID()
        playbackGeneration = generation
        crossfadeTask?.cancel()
        crossfadeTask = nil
        crossfadeGeneration = nil
        invalidateArmedInactivePlayer()
        isSuspendedWithPendingSchedule = false
        suspendedPlaybackFrame = nil
        scheduledStartFrame = 0
        activeGainNode.outputVolume = linearGain(for: currentGainDB)
        inactiveGainNode.outputVolume = 0
        activePlayer.scheduleFile(
            file,
            at: nil,
            completionCallbackType: .dataPlayedBack,
            completionHandler: Self.makeCompletionCallback(owner: self, generation: generation)
        )

        try activePlayer.playAudio()

        playbackState = await .playing(currentTime: currentTime, duration: duration)

        // Progress timer is managed by AudioEngineFacade
        // Record metrics start time
        metricsStartTime = Date()
        await bufferUnderruns.reset()
    }

    public func pause() async {
        cancelCrossfade(rearmSourceCompletion: false)
        let activePlayer = isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode
        let hasPendingSchedule = audioFile != nil && playbackGeneration != nil
        let pausedFrame = suspendedPlaybackFrame ?? currentAbsolutePlaybackFrame()
        isSuspendedWithPendingSchedule = hasPendingSchedule
        suspendedPlaybackFrame = hasPendingSchedule ? pausedFrame : nil
        invalidateArmedInactivePlayer()
        activePlayer.pause()
        playbackState = await .paused(currentTime: currentTime, duration: duration)
        // Progress timer is managed by AudioEngineFacade
    }

    public func stop() async {
        await unloadTrack()
        engine.stop()
        removeMonitoringTap()
        await bufferUnderruns.reset()
    }

    private func unloadTrack() async {
        cancelCrossfade(rearmSourceCompletion: false)
        // Stop both players
        primaryPlayerNode.stop()
        secondaryPlayerNode.stop()
        playbackState = .stopped
        // Progress timer is managed by AudioEngineFacade

        // Reset position and gapless state
        audioFile = nil
        totalFrames = 0
        scheduledStartFrame = 0
        preparedFile = nil
        preparedTransition = nil
        unconsumedPreparedURL = nil
        playbackGeneration = nil
        hasNextPrepared = false
        isPrimaryActive = true
        currentGainDB = 0
        primaryGainNode.outputVolume = 1
        secondaryGainNode.outputVolume = 0
        isSuspendedWithPendingSchedule = false
        suspendedPlaybackFrame = nil
        pendingConfigurationRecoveryFrame = nil
        pendingConfigurationRecoveryWasPlaying = nil
    }

    public func seek(to time: TimeInterval) async throws {
        guard let file = audioFile else {
            throw AudioError.invalidSeekPosition(time)
        }

        cancelCrossfade(rearmSourceCompletion: false)
        let activePlayer = isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode
        let wasPlaying = activePlayer.isPlaying

        // Calculate frame position
        let sampleRate = file.processingFormat.sampleRate
        let fileDuration = Double(file.length) / sampleRate
        guard sampleRate > 0,
              time.isFinite,
              time >= 0,
              time < fileDuration
        else {
            throw AudioError.invalidSeekPosition(time)
        }
        let framePosition = AVAudioFramePosition(time * sampleRate)
        guard framePosition >= 0, framePosition < file.length else {
            throw AudioError.invalidSeekPosition(time)
        }

        // Stop current playback only after validation so a rejected seek does
        // not destroy the currently scheduled segment.
        activePlayer.stop()
        let inactivePlayer = isPrimaryActive ? secondaryPlayerNode : primaryPlayerNode
        inactivePlayer.stop()
        preparedFile = nil
        preparedTransition = nil
        unconsumedPreparedURL = nil
        hasNextPrepared = false
        isSuspendedWithPendingSchedule = false
        suspendedPlaybackFrame = nil

        // Create new segment
        let framesToPlay = file.length - framePosition

        // Schedule segment
        let generation = UUID()
        playbackGeneration = generation
        scheduledStartFrame = framePosition
        activeGainNode.outputVolume = linearGain(for: currentGainDB)
        inactiveGainNode.outputVolume = 0
        activePlayer.scheduleSegment(
            file,
            startingFrame: framePosition,
            frameCount: AVAudioFrameCount(framesToPlay),
            at: nil,
            completionCallbackType: .dataPlayedBack,
            completionHandler: Self.makeCompletionCallback(owner: self, generation: generation)
        )

        // Resume if was playing
        if wasPlaying {
            try activePlayer.playAudio()
        }
    }

    public func setVolume(_ volume: Float) async {
        // Apply volume to both players
        let clampedVolume = max(0.0, min(1.0, volume))
        primaryPlayerNode.volume = clampedVolume
        secondaryPlayerNode.volume = clampedVolume
    }

    public func configure(with configuration: AudioEngineConfiguration) async throws {
        self.configuration = configuration
    }

    public func prepareNext(url: URL) async {
        // Get the inactive player for gapless preparation
        let inactivePlayer = isPrimaryActive ? secondaryPlayerNode : primaryPlayerNode

        do {
            // Ensure engine is running
            if !engine.isRunning {
                try startEngine()
            }

            // Load the next file
            preparedFile = try AVAudioFile(forReading: url)
            guard let file = preparedFile else { return }

            inactivePlayer.stop()
            hasNextPrepared = true

            guard let sourceFile = audioFile,
                  let sourceGeneration = playbackGeneration,
                  let renderTime = (isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode).lastRenderTime,
                  let playerTime = (isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode)
                    .playerTime(forNodeTime: renderTime)
            else {
                logger.debug(
                    "Prepared next track without render-boundary scheduling; normal transition fallback remains active"
                )
                return
            }

            guard !formatsDiffer(sourceFile.processingFormat, file.processingFormat) else {
                logger.info(
                    "Prepared next track uses a different processing format; using an honest non-gapless fallback"
                )
                return
            }

            let currentSourceFrame = Self.absolutePlaybackFrame(
                scheduledStartFrame: scheduledStartFrame,
                nodeSampleTime: playerTime.sampleTime,
                totalFrames: sourceFile.length
            )
            let remainingFrames = max(0, sourceFile.length - currentSourceFrame)
            let delay = Self.gaplessBoundaryDelay(
                remainingFrames: remainingFrames,
                sampleRate: sourceFile.processingFormat.sampleRate,
                playbackRate: currentPlaybackRate
            )
            let boundaryHostTime = renderTime.hostTime &+ AVAudioTime.hostTime(forSeconds: delay)
            let nextGeneration = UUID()

            inactivePlayer.scheduleFile(
                file,
                at: nil,
                completionCallbackType: .dataPlayedBack,
                completionHandler: Self.makeCompletionCallback(
                    owner: self,
                    generation: nextGeneration
                )
            )
            try inactivePlayer.playAudio(at: AVAudioTime(hostTime: boundaryHostTime))

            preparedTransition = PreparedGaplessTransition(
                url: url,
                file: file,
                sourceGeneration: sourceGeneration,
                nextGeneration: nextGeneration,
                nextPlayerIsPrimary: !isPrimaryActive,
                boundaryHostTime: boundaryHostTime
            )
            logger.debug("Prepared next track for gapless playback: \(url.lastPathComponent, privacy: .private(mask: .hash))")
        } catch {
            logger.error("Failed to prepare next track: \(error.localizedDescription, privacy: .private)")
            preparedFile = nil
            preparedTransition = nil
            hasNextPrepared = false
        }
    }

    public func invalidatePreparedTransition() async {
        invalidateArmedInactivePlayer()
    }

    public func consumePreparedTransition(to url: URL) async -> PreparedTrackTransition {
        guard unconsumedPreparedURL == url, audioFile?.url == url else {
            return .none
        }
        unconsumedPreparedURL = nil
        return .renderBoundary
    }

    public var metricsAvailability: AudioMetricsAvailability {
        .partial
    }

    /// AVAudioEngine exposes route/format/latency and the installed underrun tap,
    /// but not decoder latency, buffer fill, dropped frames, or process CPU.
    public func availableMetrics() async -> AudioMetrics? {
        let processMetrics = processMetricsProvider.currentProcessMetrics()
        guard let cpuUsage = processMetrics.cpuUsage,
              let residentMemoryBytes = processMetrics.residentMemoryBytes else {
            // A partial process provider cannot support the full snapshot
            // contract. Returning nil keeps EngineMetricsCollector from
            // turning unavailable values into fabricated zeros.
            return nil
        }
        let outputFormat = engine.outputNode.outputFormat(forBus: 0)
        let streamDescription = outputFormat.streamDescription.pointee
        let sampleRate = outputFormat.sampleRate
        let channelCount = Int(outputFormat.channelCount)
        let bitDepth = Int(streamDescription.mBitsPerChannel)
        let bufferSize = Int(audioSessionBufferFrames(sampleRate: sampleRate))
        let renderLatency = AVAudioSession.sharedInstance().outputLatency

        return AudioMetrics(
            engineMetricsAvailability: .partial,
            cpuUsage: cpuUsage,
            memoryUsage: residentMemoryBytes,
            bufferUnderruns: await bufferUnderruns.value(),
            decodingLatency: 0,
            bufferFillLevel: 0,
            droppedFrames: 0,
            renderLatency: renderLatency,
            timestamp: Date(),
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channelCount: channelCount,
            engineType: AudioEngineType.avAudioEngine.rawValue,
            audioFormat: audioFile?.url.pathExtension.lowercased() ?? "unknown",
            isBitPerfect: await isBitPerfect,
            bufferSize: bufferSize
        )
    }

    // MARK: - Private Methods

    private func setupEngine() throws {
        // Attach primary chain nodes
        engine.attach(primaryPlayerNode)
        engine.attach(primaryTimePitchNode)

        // Attach secondary chain nodes for gapless playback
        engine.attach(secondaryPlayerNode)
        engine.attach(secondaryTimePitchNode)

        engine.attach(primaryGainNode)
        engine.attach(secondaryGainNode)

        // Attach EQ and submix nodes
        engine.attach(submixNode)
        engine.attach(eqNode)

        // Connect chains to mixer
        let format = engine.outputNode.outputFormat(forBus: 0)

        // Primary chain: primaryPlayer → primaryTimePitch → primaryGain → submix
        try engine.connectNode(primaryPlayerNode, to: primaryTimePitchNode, format: nil)
        try engine.connectNode(primaryTimePitchNode, to: primaryGainNode, format: format)
        try engine.connectNode(primaryGainNode, to: submixNode, format: format)

        // Secondary chain: secondaryPlayer → secondaryTimePitch → secondaryGain → submix
        try engine.connectNode(secondaryPlayerNode, to: secondaryTimePitchNode, format: nil)
        try engine.connectNode(secondaryTimePitchNode, to: secondaryGainNode, format: format)
        try engine.connectNode(secondaryGainNode, to: submixNode, format: format)
        primaryGainNode.outputVolume = 1
        secondaryGainNode.outputVolume = 0

        // Master chain: submix → EQ → mainMixer
        try engine.connectNode(submixNode, to: eqNode, format: format)
        try engine.connectNode(eqNode, to: engine.mainMixerNode, format: format)

        // Configure EQ bands with standard frequencies
        configureEQBands()

        // Set up tap for monitoring (optional)
        setupMonitoring()
    }

    /// Insert EQ node into the audio graph
    private func insertEQIntoGraph() throws {
        guard !isEQInGraph else { return }
        engine.disconnectNodeOutput(submixNode)
        do {
            try engine.connectNode(submixNode, to: eqNode, format: nil)
            try engine.connectNode(eqNode, to: engine.mainMixerNode, format: nil)
        } catch {
            engine.disconnectNodeOutput(submixNode)
            engine.disconnectNodeOutput(eqNode)
            do {
                try engine.connectNode(submixNode, to: engine.mainMixerNode, format: nil)
            } catch {
                logger.fault(
                    "Failed to restore EQ bypass graph: \(error.localizedDescription, privacy: .private)"
                )
            }
            throw error
        }
        isEQInGraph = true
        logger.debug("EQ node inserted into audio graph")
    }

    /// Remove EQ node from the audio graph for true bit-perfect bypass
    private func removeEQFromGraph() throws {
        guard isEQInGraph else { return }
        engine.disconnectNodeOutput(submixNode)
        engine.disconnectNodeOutput(eqNode)
        do {
            try engine.connectNode(submixNode, to: engine.mainMixerNode, format: nil)
        } catch {
            engine.disconnectNodeOutput(submixNode)
            do {
                try engine.connectNode(submixNode, to: eqNode, format: nil)
                try engine.connectNode(eqNode, to: engine.mainMixerNode, format: nil)
            } catch {
                logger.fault(
                    "Failed to restore EQ processing graph: \(error.localizedDescription, privacy: .private)"
                )
            }
            throw error
        }
        isEQInGraph = false
        logger.debug("EQ node removed from audio graph for bit-perfect bypass")
    }

    /// Configure EQ bands with standard audiophile frequencies
    /// Uses shelf filters for edge bands (32 Hz, 16 kHz) for smoother response
    private func configureEQBands() {
        let frequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]

        for (index, freq) in frequencies.enumerated() {
            eqNode.bands[index].frequency = freq
            eqNode.bands[index].bandwidth = 1.0
            eqNode.bands[index].gain = 0
            eqNode.bands[index].bypass = true // Start bypassed (EQ disabled)

            // Use shelf filters for edge bands for smoother response
            switch index {
            case 0:
                eqNode.bands[index].filterType = .lowShelf
            case 9:
                eqNode.bands[index].filterType = .highShelf
            default:
                eqNode.bands[index].filterType = .parametric
            }
        }
    }

    private func startEngine() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    /// Stop and clear any future render scheduled on the inactive gapless node.
    /// This is required before a fresh schedule and whenever playback pauses;
    /// an absolute host-time schedule is not cancelled by pausing the active
    /// node alone.
    private func invalidateArmedInactivePlayer() {
        let inactivePlayer = isPrimaryActive ? secondaryPlayerNode : primaryPlayerNode
        inactivePlayer.stop()
        inactivePlayer.volume = primaryPlayerNode.volume
        inactiveGainNode.outputVolume = 0
        preparedFile = nil
        preparedTransition = nil
        unconsumedPreparedURL = nil
        hasNextPrepared = false
    }

    private func observeConfigurationChanges() {
        let engineIdentifier = ObjectIdentifier(engine)
        configurationChangeObserver = NotificationCenter.default.addObserver(
            forName: .AVAudioEngineConfigurationChange,
            object: engine,
            queue: nil
        ) { [weak self, engineIdentifier] notification in
            guard Self.isConfigurationChangeForEngine(
                notification,
                engineIdentifier: engineIdentifier
            ) else {
                return
            }

            Task { @MainActor [weak self] in
                guard let self else { return }
                // Capture transport before the debounce gives the route a
                // chance to invalidate player render time. The scheduler only
                // coalesces the subsequent graph rebuild.
                self.pendingConfigurationRecoveryFrame = self.currentAbsolutePlaybackFrame()
                self.pendingConfigurationRecoveryWasPlaying = self.playbackState.isPlaying
                self.configurationRecoveryScheduler?.schedule()
            }
        }
    }

    nonisolated static func isConfigurationChangeForEngine(
        _ notification: Notification,
        engineIdentifier: ObjectIdentifier
    ) -> Bool {
        guard let notificationObject = notification.object as AnyObject? else {
            return false
        }
        return ObjectIdentifier(notificationObject) == engineIdentifier
    }

    /// Restart the existing graph after AVAudioEngine stopped for a hardware
    /// or route configuration change. Capture the source frame before touching
    /// the graph, then install one fresh generation for only the unrendered
    /// remainder. Route and interruption intent remain owned by StateCoordinator.
    // Internal for deterministic contract tests; production notifications
    // still enter through the debounced observer above.
    func recoverAfterConfigurationChange() {
        guard let file = audioFile else { return }

        let wasPlaying = pendingConfigurationRecoveryWasPlaying ?? playbackState.isPlaying
        let capturedFrame = min(
            max(
                0,
                pendingConfigurationRecoveryFrame
                    ?? suspendedPlaybackFrame
                    ?? currentAbsolutePlaybackFrame()
            ),
            totalFrames
        )
        pendingConfigurationRecoveryFrame = nil
        pendingConfigurationRecoveryWasPlaying = nil
        let remainingFrames = totalFrames - capturedFrame
        let recoveryGeneration = UUID()

        do {
            primaryPlayerNode.stop()
            secondaryPlayerNode.stop()
            preparedFile = nil
            preparedTransition = nil
            unconsumedPreparedURL = nil
            hasNextPrepared = false

            try reconnectPlayerNodesIfNeeded(for: file.processingFormat)
            engine.prepare()
            try startEngine()

            guard remainingFrames > 0 else {
                playbackGeneration = nil
                scheduledStartFrame = totalFrames
                isSuspendedWithPendingSchedule = false
                suspendedPlaybackFrame = nil
                playbackState = .stopped
                logger.info("AVAudioEngine configuration recovery reached track end")
                return
            }

            let activePlayer = isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode
            playbackGeneration = recoveryGeneration
            scheduledStartFrame = capturedFrame
            suspendedPlaybackFrame = capturedFrame
            isSuspendedWithPendingSchedule = !wasPlaying
            activePlayer.scheduleSegment(
                file,
                startingFrame: capturedFrame,
                frameCount: AVAudioFrameCount(remainingFrames),
                at: nil,
                completionCallbackType: .dataPlayedBack,
                completionHandler: Self.makeCompletionCallback(
                    owner: self,
                    generation: recoveryGeneration
                )
            )

            if wasPlaying {
                try activePlayer.playAudio()
                isSuspendedWithPendingSchedule = false
            }

            let recoveredTime = Double(capturedFrame) / file.processingFormat.sampleRate
            let recoveredDuration = Double(totalFrames) / file.processingFormat.sampleRate
            playbackState = wasPlaying
                ? .playing(currentTime: recoveredTime, duration: recoveredDuration)
                : .paused(currentTime: recoveredTime, duration: recoveredDuration)
            logger.info("Recovered AVAudioEngine after configuration change")
        } catch {
            playbackGeneration = nil
            isSuspendedWithPendingSchedule = false
            suspendedPlaybackFrame = capturedFrame
            playbackState = .paused(
                currentTime: Double(capturedFrame) / file.processingFormat.sampleRate,
                duration: Double(totalFrames) / file.processingFormat.sampleRate
            )
            let detail = "reason=\(String(describing: type(of: error)))"
            configurationRecoveryFailureHandler?(
                .audioEngineConfigurationRecoveryFailed,
                detail
            )
            logger.error(
                "Failed to recover AVAudioEngine after configuration change: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    private func reconnectPlayerNodesIfNeeded(for fileFormat: AVAudioFormat) throws {
        let primaryInput = primaryTimePitchNode.inputFormat(forBus: 0)
        let secondaryInput = secondaryTimePitchNode.inputFormat(forBus: 0)
        let requiresReconnect =
            formatsDiffer(primaryInput, fileFormat) ||
            formatsDiffer(secondaryInput, fileFormat)

        guard requiresReconnect else { return }

        let wasRunning = engine.isRunning
        if wasRunning {
            engine.stop()
        }

        engine.disconnectNodeOutput(primaryPlayerNode)
        engine.disconnectNodeOutput(secondaryPlayerNode)
        try engine.connectNode(primaryPlayerNode, to: primaryTimePitchNode, format: fileFormat)
        try engine.connectNode(secondaryPlayerNode, to: secondaryTimePitchNode, format: fileFormat)

        logger.debug(
            """
            Reconnected player nodes for file format:
            sampleRate=\(fileFormat.sampleRate, privacy: .public)
            channels=\(fileFormat.channelCount, privacy: .public)
            """
        )

        if wasRunning {
            try startEngine()
        }
    }

    private func formatsDiffer(_ lhs: AVAudioFormat, _ rhs: AVAudioFormat) -> Bool {
        lhs.sampleRate != rhs.sampleRate ||
            lhs.channelCount != rhs.channelCount ||
            lhs.commonFormat != rhs.commonFormat ||
            lhs.isInterleaved != rhs.isInterleaved
    }

    private func hasAudioProcessing() -> Bool {
        // Check if any effects or processing nodes are active
        // Time pitch node is active if rate is not 1.0
        // EQ and either gain/crossfade stage are active processing paths.
        currentPlaybackRate != 1.0 ||
            isEQEnabled ||
            abs(currentGainDB) >= .ulpOfOne ||
            crossfadeGeneration != nil
    }

    // Progress timer functionality moved to AudioEngineFacade's ProgressTimerManager
    // This eliminates race conditions and centralizes progress updates

    private func setupMonitoring() {
        guard !monitoringTapInstalled else { return }
        // Install tap on output for monitoring buffer underruns
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let tracker = bufferUnderruns

        do {
            try engine.mainMixerNode.installAudioTap(
                onBus: 0,
                bufferSize: 1024,
                format: format,
                tapProvider: Self.makeMonitoringTap(tracker: tracker)
            )
            monitoringTapInstalled = true
        } catch {
            logger.warning(
                "Audio underrun monitoring is unavailable: \(error.localizedDescription, privacy: .private)"
            )
        }
    }

    private func removeMonitoringTap() {
        guard monitoringTapInstalled else { return }
        engine.mainMixerNode.removeTap(onBus: 0)
        monitoringTapInstalled = false
    }

    var isMonitoringTapInstalledForTesting: Bool {
        monitoringTapInstalled
    }

    var isEngineRunningForTesting: Bool {
        engine.isRunning
    }

    private nonisolated static func makeMonitoringTap(
        tracker: BufferUnderrunTracker
    ) -> @Sendable (AVReadOnlyAudioPCMBuffer, AVAudioTime) -> Void {
        { buffer, _ in
            guard buffer.frameLength == 0 else { return }
            Task {
                await tracker.increment()
            }
        }
    }

    static func gaplessBoundaryDelay(
        remainingFrames: AVAudioFramePosition,
        sampleRate: Double,
        playbackRate: Double
    ) -> TimeInterval {
        guard remainingFrames > 0, sampleRate > 0, playbackRate > 0 else {
            return 0
        }
        return Double(remainingFrames) / sampleRate / playbackRate
    }

    static func absolutePlaybackFrame(
        scheduledStartFrame: AVAudioFramePosition,
        nodeSampleTime: AVAudioFramePosition,
        totalFrames: AVAudioFramePosition
    ) -> AVAudioFramePosition {
        guard totalFrames > 0 else { return 0 }

        let startFrame = min(max(0, scheduledStartFrame), totalFrames)
        let relativeFrame = max(0, nodeSampleTime)
        let (absoluteFrame, overflowed) = startFrame.addingReportingOverflow(relativeFrame)
        guard !overflowed else { return totalFrames }
        return min(absoluteFrame, totalFrames)
    }

    private func audioSessionBufferFrames(sampleRate: Double) -> AVAudioFrameCount {
        let duration = AVAudioSession.sharedInstance().ioBufferDuration
        return AVAudioFrameCount(max(duration * sampleRate, 0))
    }

    private var activeGainNode: AVAudioMixerNode {
        isPrimaryActive ? primaryGainNode : secondaryGainNode
    }

    private var inactiveGainNode: AVAudioMixerNode {
        isPrimaryActive ? secondaryGainNode : primaryGainNode
    }

    private func linearGain(for gainDB: Float) -> Float {
        guard gainDB.isFinite else { return 1 }
        // AVAudioMixerNode outputVolume is a linear scalar. Keep the stage in
        // its documented range; positive replay gain is represented by the
        // target ceiling rather than overflowing the node.
        return min(1, max(0, pow(10, gainDB / 20)))
    }

    // MARK: - Playback Rate

    /// Set the playback rate (0.5 to 2.0, where 1.0 is normal speed)
    public func setPlaybackRate(_ rate: Double) async {
        let clampedRate = max(0.5, min(2.0, rate))
        // Apply to both time pitch nodes for consistent gapless behavior
        primaryTimePitchNode.rate = Float(clampedRate)
        secondaryTimePitchNode.rate = Float(clampedRate)
        currentPlaybackRate = clampedRate
    }

    public func applyReplayGain(_ gainDB: Float) async {
        currentGainDB = gainDB.isFinite ? gainDB : 0
        guard crossfadeGeneration == nil else { return }
        activeGainNode.outputVolume = linearGain(for: currentGainDB)
    }

    /// Render a bounded equal-power transition on the two independent player
    /// chains. The transition UUID is separate from each player schedule
    /// generation, so a late callback from an abandoned target cannot commit
    /// queue state or replace the source track.
    public func crossfade(
        to url: URL,
        duration: TimeInterval,
        playbackRate: Double,
        gainDB: Float
    ) async throws {
        guard let sourceFile = audioFile else {
            try await load(url: url)
            await setPlaybackRate(playbackRate)
            await applyReplayGain(gainDB)
            try await play()
            return
        }

        cancelCrossfade(rearmSourceCompletion: true)

        let targetFile = try AVAudioFile(forReading: url)
        guard !formatsDiffer(sourceFile.processingFormat, targetFile.processingFormat) else {
            // A crossfade between incompatible processing formats cannot be
            // rendered by this graph. Keep the transition honest and use the
            // established load/restart path instead.
            try await load(url: url)
            await setPlaybackRate(playbackRate)
            await applyReplayGain(gainDB)
            try await play()
            return
        }

        let sourceGeneration = playbackGeneration
        let targetGeneration = UUID()
        let transitionGeneration = UUID()
        let inactivePlayer = isPrimaryActive ? secondaryPlayerNode : primaryPlayerNode

        inactivePlayer.stop()
        inactivePlayer.volume = primaryPlayerNode.volume
        inactiveGainNode.outputVolume = 0
        inactivePlayer.scheduleFile(
            targetFile,
            at: nil,
            completionCallbackType: .dataPlayedBack,
            completionHandler: Self.makeCompletionCallback(owner: self, generation: targetGeneration)
        )
        try inactivePlayer.playAudio()

        currentPlaybackRate = max(0.5, min(2.0, playbackRate))
        primaryTimePitchNode.rate = Float(currentPlaybackRate)
        secondaryTimePitchNode.rate = Float(currentPlaybackRate)
        let targetGainDB = gainDB.isFinite ? gainDB : 0
        activeGainNode.outputVolume = linearGain(for: currentGainDB)
        inactiveGainNode.outputVolume = 0
        crossfadeSourceGeneration = sourceGeneration
        crossfadeTargetGeneration = targetGeneration
        crossfadeTargetFile = targetFile
        crossfadeTargetGainDB = targetGainDB
        crossfadeTargetCompleted = false
        crossfadeGeneration = transitionGeneration
        isSuspendedWithPendingSchedule = false
        suspendedPlaybackFrame = nil

        if duration <= 0 {
            finishCrossfade(generation: transitionGeneration)
            return
        }

        let boundedDuration = max(0, duration)
        crossfadeTask = Task { @MainActor [weak self] in
            await self?.performCrossfade(duration: boundedDuration, generation: transitionGeneration)
        }
    }

    private func performCrossfade(duration: TimeInterval, generation: UUID) async {
        let stepDuration = min(0.05, max(duration, 0.001))
        let steps = max(1, Int(ceil(duration / stepDuration)))

        for step in 1 ... steps {
            guard !Task.isCancelled, crossfadeGeneration == generation else {
                return
            }

            let progress = min(1, Double(step) / Double(steps))
            let sourceWeight = Float(cos(progress * .pi / 2))
            let targetWeight = Float(sin(progress * .pi / 2))
            activeGainNode.outputVolume = linearGain(for: currentGainDB) * sourceWeight
            inactiveGainNode.outputVolume = linearGain(for: crossfadeTargetGainDB) * targetWeight

            do {
                try await crossfadeSleeper(.milliseconds(Int(stepDuration * 1_000)))
            } catch {
                return
            }
        }

        guard crossfadeGeneration == generation else { return }
        finishCrossfade(generation: generation)
    }

    private func finishCrossfade(generation: UUID) {
        guard crossfadeGeneration == generation,
              let targetFile = crossfadeTargetFile,
              let targetGeneration = crossfadeTargetGeneration else { return }

        let sourcePlayer = isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode
        sourcePlayer.stop()
        isPrimaryActive.toggle()
        audioFile = targetFile
        totalFrames = targetFile.length
        scheduledStartFrame = 0
        playbackGeneration = targetGeneration
        currentGainDB = crossfadeTargetGainDB
        activeGainNode.outputVolume = linearGain(for: currentGainDB)
        inactiveGainNode.outputVolume = 0
        preparedFile = nil
        preparedTransition = nil
        unconsumedPreparedURL = nil
        hasNextPrepared = false
        crossfadeTask = nil
        crossfadeGeneration = nil
        crossfadeSourceGeneration = nil
        crossfadeTargetGeneration = nil
        crossfadeTargetFile = nil
        crossfadeTargetGainDB = 0
        let targetCompleted = crossfadeTargetCompleted
        crossfadeTargetCompleted = false
        playbackState = .playing(
            currentTime: 0,
            duration: Double(targetFile.length) / targetFile.processingFormat.sampleRate
        )
        if targetCompleted {
            playbackState = .stopped
            playbackGeneration = nil
            completionHandler?()
        }
    }

    private func cancelCrossfade(rearmSourceCompletion: Bool) {
        guard crossfadeTask != nil || crossfadeGeneration != nil else { return }
        crossfadeTask?.cancel()
        crossfadeTask = nil
        crossfadeGeneration = nil
        crossfadeTargetFile = nil
        crossfadeSourceGeneration = nil
        crossfadeTargetGeneration = nil
        crossfadeTargetGainDB = 0
        crossfadeTargetCompleted = false
        let inactivePlayer = isPrimaryActive ? secondaryPlayerNode : primaryPlayerNode
        inactivePlayer.stop()
        activeGainNode.outputVolume = linearGain(for: currentGainDB)
        inactiveGainNode.outputVolume = 0
        if !rearmSourceCompletion {
            playbackGeneration = nil
        }
    }

    // MARK: - Equalizer

    /// Whether this engine supports EQ processing
    public var supportsEQ: Bool {
        get async { true }
    }

    /// Apply an equalizer configuration to the audio output
    /// Uses true bypass (removes EQ node from graph) when disabled for bit-perfect playback
    public func applyEQ(_ configuration: EqualizerConfiguration) async throws {
        if configuration.isEnabled {
            // Ensure EQ is in the graph
            if !isEQInGraph {
                try insertEQIntoGraph()
            }

            eqConfiguration = configuration
            isEQEnabled = true
            for (index, band) in configuration.bands.enumerated() where index < 10 {
                eqNode.bands[index].frequency = band.frequency
                eqNode.bands[index].bandwidth = band.bandwidth
                eqNode.bands[index].gain = band.gain
                eqNode.bands[index].bypass = false
            }

            // Apply preamp gain to prevent clipping
            let linearGain = pow(10, configuration.preampGain / 20)
            engine.mainMixerNode.outputVolume = Float(linearGain)
        } else {
            // Remove EQ from graph for true bit-perfect bypass
            if isEQInGraph {
                try removeEQFromGraph()
            }
            eqConfiguration = configuration
            isEQEnabled = false
            engine.mainMixerNode.outputVolume = 1.0  // Reset to unity
        }

        let enabledState = configuration.isEnabled ? "enabled" : "disabled"
        let presetName = LogPrivacy.truncated(configuration.presetName ?? "Custom", limit: 32)
        logger.debug("EQ \(enabledState, privacy: .public) with preset: \(presetName, privacy: .private)")
    }

    // MARK: - Completion Handler

    /// Set a completion handler for when playback finishes
    public func setCompletionHandler(_ handler: @escaping () -> Void) {
        completionHandler = handler
    }

    var chainVolumesForTesting: (primary: Float, secondary: Float) {
        (primaryGainNode.outputVolume, secondaryGainNode.outputVolume)
    }

    func setCrossfadeSleeperForTesting(
        _ sleeper: @escaping @MainActor (Swift.Duration) async throws -> Void
    ) {
        crossfadeSleeper = sleeper
    }

    private nonisolated static func makeCompletionCallback(
        owner: AVAudioEngineAdapter,
        generation: UUID
    ) -> @Sendable (AVAudioPlayerNodeCompletionCallbackType) -> Void {
        { [weak owner] _ in
            Task { @MainActor [weak owner] in
                owner?.handlePlaybackCompletion(generation: generation)
            }
        }
    }

    private func handlePlaybackCompletion(generation: UUID) {
        // A crossfade owns both schedules until the transition commits. The
        // source callback is intentionally ignored (it only marks the old
        // node complete), while a target callback cannot supersede the
        // transition generation or queue state.
        if crossfadeGeneration != nil {
            if generation == crossfadeSourceGeneration {
                return
            }
            if generation == crossfadeTargetGeneration {
                crossfadeTargetCompleted = true
                return
            }
        }
        guard playbackGeneration == generation else { return }
        isSuspendedWithPendingSchedule = false
        suspendedPlaybackFrame = nil

        if let transition = preparedTransition,
           transition.sourceGeneration == generation {
            commitPreparedTransition(transition)
            completionHandler?()
            return
        }

        playbackState = .stopped
        scheduledStartFrame = totalFrames
        playbackGeneration = nil
        completionHandler?()
    }

    private func commitPreparedTransition(_ transition: PreparedGaplessTransition) {
        let sourcePlayer = transition.nextPlayerIsPrimary
            ? secondaryPlayerNode
            : primaryPlayerNode
        sourcePlayer.stop()
        isPrimaryActive = transition.nextPlayerIsPrimary
        audioFile = transition.file
        totalFrames = transition.file.length
        scheduledStartFrame = 0
        playbackGeneration = transition.nextGeneration
        preparedFile = nil
        preparedTransition = nil
        hasNextPrepared = false
        unconsumedPreparedURL = transition.url
        playbackState = .playing(currentTime: 0, duration: Double(transition.file.length) / transition.file.processingFormat.sampleRate)
    }

    @MainActor deinit {
        crossfadeTask?.cancel()
        configurationRecoveryScheduler?.cancel()
        removeMonitoringTap()
        engine.stop()
        if let configurationChangeObserver {
            NotificationCenter.default.removeObserver(configurationChangeObserver)
        }
    }
}

/// MainActor-owned debounce scheduler for engine configuration recovery.
@MainActor
final class EngineConfigurationChangeRecoveryScheduler {
    private let recoveryDelay: Duration
    private let recoveryHandler: @MainActor () -> Void
    private var task: Task<Void, Never>?

    init(
        recoveryDelay: Duration = .milliseconds(100),
        recoveryHandler: @escaping @MainActor () -> Void
    ) {
        self.recoveryDelay = recoveryDelay
        self.recoveryHandler = recoveryHandler
    }

    func schedule() {
        task?.cancel()
        let recoveryDelay = self.recoveryDelay
        let recoveryHandler = self.recoveryHandler
        task = Task { @MainActor [recoveryDelay, recoveryHandler] in
            try? await Task.sleep(for: recoveryDelay)
            guard !Task.isCancelled else { return }
            recoveryHandler()
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }

    deinit {
        task?.cancel()
    }
}
