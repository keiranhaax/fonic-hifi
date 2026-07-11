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

    /// Last render time for tracking playback position
    private var lastRenderTime: AVAudioTime?

    // Progress updates are handled by AudioEngineFacade's ProgressTimerManager
    // No local timer needed

    /// Current playback state
    private var playbackState: PlaybackState = .idle

    /// Audio session manager
    private let sessionManager: any AudioSessionManaging

    private let logger = Log.logger(.audioEngine)

    /// Current configuration
    private var configuration: AudioEngineConfiguration = .init()

    /// Completion handler for when playback finishes
    private var completionHandler: (() -> Void)?

    /// Performance metrics collector
    private var metricsStartTime: Date?
    private let bufferUnderruns = BufferUnderrunTracker()

    // MARK: - Initialization

    public init(sessionManager: any AudioSessionManaging = AudioSessionManager.shared) {
        self.sessionManager = sessionManager
        super.init()
        setupEngine()
    }

    // MARK: - AudioEngineService Implementation

    public var currentTime: TimeInterval {
        get async {
            let activePlayer = isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode
            guard let playerTime = activePlayer.playerTime(forNodeTime: activePlayer.lastRenderTime ?? AVAudioTime()) else {
                return 0
            }

            if let file = audioFile {
                let sampleRate = file.processingFormat.sampleRate
                return Double(playerTime.sampleTime) / sampleRate
            }

            return 0
        }
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
                !hasAudioProcessing()
        }
    }

    public func load(url: URL) async throws {
        // Stop any current playback
        await stop()
        await bufferUnderruns.reset()

        do {
            // Create audio file
            audioFile = try AVAudioFile(forReading: url)
            guard let file = audioFile else {
                throw AudioError.fileNotFound(url)
            }

            #if DEBUG
                logger.debug("=== AVAUDIOENGINE PREPARE DEBUG ===")
            #endif

            // Store total frames for duration calculation
            totalFrames = file.length

            try reconnectPlayerNodesIfNeeded(for: file.processingFormat)

            // Connect player node if needed
            if !engine.isRunning {
                try startEngine()
            }

            #if DEBUG
                let format = file.processingFormat
                logger.debug("1. Attached player node")
                logger.debug("2. Connected player to mixer with format: \(String(describing: format), privacy: .public)")
                logger.debug("3. Sample rate: \(format.sampleRate, privacy: .public)")
                logger.debug("4. Channels: \(format.channelCount, privacy: .public)")
                logger.debug("5. Main mixer connected to output: \(self.engine.mainMixerNode.numberOfOutputs > 0, privacy: .public)")
                logger.debug("6. Engine prepared")
                logger.debug("=== END PREPARE DEBUG ===")
            #endif

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

        #if DEBUG
            logger.debug("=== AVAUDIOENGINE PLAY DEBUG ===")
            logger.debug("1. Engine running before start: \(self.engine.isRunning, privacy: .public)")
        #endif

        // Audio session is managed by AudioSessionManager, not here

        // Start playback
        if !engine.isRunning {
            try startEngine()
            #if DEBUG
                logger.debug("2. Engine started")
            #endif
        }

        #if DEBUG
            logger.debug("3. Engine running after start: \(self.engine.isRunning, privacy: .public)")
            logger.debug("4. Player node playing state: \(activePlayer.isPlaying, privacy: .public)")
        #endif

        // Schedule file for playback
        // CRITICAL: AVAudioPlayerNode completion handlers run on background threads
        // per Apple documentation. We must explicitly dispatch to main actor.
        activePlayer.scheduleFile(file, at: nil) { [weak self] in
            #if DEBUG
                self?.logger.debug("5. File playback completed")
            #endif
            // This closure runs on Core Audio's background thread
            // Use Task to dispatch to MainActor safely
            Task { @MainActor [weak self] in
                self?.handlePlaybackCompletionSync()
            }
        }

        activePlayer.play()
        #if DEBUG
            logger.debug("6. Called activePlayer.play()")
            logger.debug("7. Player node playing after play: \(activePlayer.isPlaying, privacy: .public)")
            logger.debug("8. Output volume: \(activePlayer.volume, privacy: .public)")
            logger.debug("9. Engine output node volume: \(self.engine.mainMixerNode.outputVolume, privacy: .public)")
            logger.debug("=== END AVAUDIOENGINE DEBUG ===")
        #endif

        playbackState = await .playing(currentTime: currentTime, duration: duration)

        // Progress timer is managed by AudioEngineFacade
        // Record metrics start time
        metricsStartTime = Date()
        await bufferUnderruns.reset()
    }

    public func pause() async {
        let activePlayer = isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode
        activePlayer.pause()
        playbackState = await .paused(currentTime: currentTime, duration: duration)
        // Progress timer is managed by AudioEngineFacade
    }

    public func stop() async {
        // Stop both players
        primaryPlayerNode.stop()
        secondaryPlayerNode.stop()
        playbackState = .stopped
        // Progress timer is managed by AudioEngineFacade

        // Reset position and gapless state
        audioFile = nil
        totalFrames = 0
        preparedFile = nil
        hasNextPrepared = false
        isPrimaryActive = true
        await bufferUnderruns.reset()

        do {
            try await sessionManager.activateSession(false)
        } catch {
            logger.error("Failed to deactivate audio session: \(String(describing: error), privacy: .public)")
        }
    }

    public func seek(to time: TimeInterval) async throws {
        guard let file = audioFile else {
            throw AudioError.invalidSeekPosition(time)
        }

        let activePlayer = isPrimaryActive ? primaryPlayerNode : secondaryPlayerNode
        let wasPlaying = activePlayer.isPlaying

        // Stop current playback
        activePlayer.stop()

        // Calculate frame position
        let sampleRate = file.processingFormat.sampleRate
        let framePosition = AVAudioFramePosition(time * sampleRate)

        // Validate seek position
        guard framePosition >= 0, framePosition < file.length else {
            throw AudioError.invalidSeekPosition(time)
        }

        // Create new segment
        let framesToPlay = file.length - framePosition

        // Schedule segment
        activePlayer.scheduleSegment(
            file,
            startingFrame: framePosition,
            frameCount: AVAudioFrameCount(framesToPlay),
            at: nil,
        ) { [weak self] in
            // This closure runs on Core Audio's background thread
            // Use Task to dispatch to MainActor safely
            Task { @MainActor [weak self] in
                self?.handlePlaybackCompletionSync()
            }
        }

        // Resume if was playing
        if wasPlaying {
            activePlayer.play()
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

        // Apply configuration to engine
        let format = engine.outputNode.outputFormat(forBus: 0)

        // If engine is running, we need to stop and reconfigure
        if engine.isRunning {
            engine.stop()

            // Reconfigure with new settings
            if let preferredSampleRate = configuration.sampleRate {
                // Note: AVAudioEngine doesn't allow direct sample rate changes
                // This would require recreating the engine
            }

            try startEngine()
        }
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

            // Schedule file on inactive player
            inactivePlayer.scheduleFile(file, at: nil) { [weak self] in
                Task { @MainActor [weak self] in
                    self?.handlePlaybackCompletionSync()
                }
            }

            hasNextPrepared = true
            logger.debug("Prepared next track for gapless playback: \(url.lastPathComponent)")
        } catch {
            logger.error("Failed to prepare next track: \(error.localizedDescription)")
            preparedFile = nil
            hasNextPrepared = false
        }
    }

    public func getMetrics() async -> AudioMetrics {
        let cpuUsage = getCurrentCPUUsage()
        let memoryUsage = getCurrentMemoryUsage()

        return AudioMetrics(
            cpuUsage: cpuUsage,
            memoryUsage: memoryUsage,
        bufferUnderruns: await bufferUnderruns.value(),
            decodingLatency: 0.001, // AVAudioEngine has very low latency
            bufferFillLevel: 1.0,
            droppedFrames: 0,
            renderLatency: 0.005,
            timestamp: Date(),
        )
    }

    // MARK: - Private Methods

    private func setupEngine() {
        // Attach primary chain nodes
        engine.attach(primaryPlayerNode)
        engine.attach(primaryTimePitchNode)

        // Attach secondary chain nodes for gapless playback
        engine.attach(secondaryPlayerNode)
        engine.attach(secondaryTimePitchNode)

        // Attach EQ and submix nodes
        engine.attach(submixNode)
        engine.attach(eqNode)

        // Connect chains to mixer
        let format = engine.outputNode.outputFormat(forBus: 0)

        // Primary chain: primaryPlayer → primaryTimePitch → submix
        engine.connect(primaryPlayerNode, to: primaryTimePitchNode, format: nil)
        engine.connect(primaryTimePitchNode, to: submixNode, format: format)

        // Secondary chain: secondaryPlayer → secondaryTimePitch → submix
        engine.connect(secondaryPlayerNode, to: secondaryTimePitchNode, format: nil)
        engine.connect(secondaryTimePitchNode, to: submixNode, format: format)

        // Master chain: submix → EQ → mainMixer
        engine.connect(submixNode, to: eqNode, format: format)
        engine.connect(eqNode, to: engine.mainMixerNode, format: format)

        // Configure EQ bands with standard frequencies
        configureEQBands()

        // Set up tap for monitoring (optional)
        setupMonitoring()
    }

    /// Insert EQ node into the audio graph
    private func insertEQIntoGraph() {
        guard !isEQInGraph else { return }
        engine.disconnectNodeOutput(submixNode)
        engine.connect(submixNode, to: eqNode, format: nil)
        engine.connect(eqNode, to: engine.mainMixerNode, format: nil)
        isEQInGraph = true
        logger.debug("EQ node inserted into audio graph")
    }

    /// Remove EQ node from the audio graph for true bit-perfect bypass
    private func removeEQFromGraph() {
        guard isEQInGraph else { return }
        engine.disconnectNodeOutput(submixNode)
        engine.disconnectNodeOutput(eqNode)
        engine.connect(submixNode, to: engine.mainMixerNode, format: nil)
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
        engine.connect(primaryPlayerNode, to: primaryTimePitchNode, format: fileFormat)
        engine.connect(secondaryPlayerNode, to: secondaryTimePitchNode, format: fileFormat)

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
        // EQ is active if enabled
        currentPlaybackRate != 1.0 || isEQEnabled
    }

    // Progress timer functionality moved to AudioEngineFacade's ProgressTimerManager
    // This eliminates race conditions and centralizes progress updates

    private func setupMonitoring() {
        // Install tap on output for monitoring buffer underruns
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        let tracker = bufferUnderruns

        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format,
            block: Self.makeMonitoringTap(tracker: tracker)
        )
    }

    private nonisolated static func makeMonitoringTap(
        tracker: BufferUnderrunTracker
    ) -> AVAudioNodeTapBlock {
        { buffer, _ in
            guard buffer.frameLength == 0 else { return }
            Task {
                await tracker.increment()
            }
        }
    }

    private func getCurrentCPUUsage() -> Float {
        #if canImport(Mach)
            // Simplified CPU usage calculation
            // In production, use proper system APIs
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(
                        mach_task_self_,
                        task_flavor_t(MACH_TASK_BASIC_INFO),
                        $0,
                        &count,
                    )
                }
            }

            if result == KERN_SUCCESS {
                // This is a simplified calculation
                return Float(info.resident_size) / Float(1024 * 1024 * 1024) * 100
            }
        #endif

        return 0
    }

    private func getCurrentMemoryUsage() -> Int64 {
        #if canImport(Mach)
            var info = mach_task_basic_info()
            var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4

            let result = withUnsafeMutablePointer(to: &info) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(
                        mach_task_self_,
                        task_flavor_t(MACH_TASK_BASIC_INFO),
                        $0,
                        &count,
                    )
                }
            }

            if result == KERN_SUCCESS {
                return Int64(info.resident_size)
            }
        #endif

        return 0
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

    // MARK: - Equalizer

    /// Whether this engine supports EQ processing
    public var supportsEQ: Bool {
        get async { true }
    }

    /// Apply an equalizer configuration to the audio output
    /// Uses true bypass (removes EQ node from graph) when disabled for bit-perfect playback
    public func applyEQ(_ configuration: EqualizerConfiguration) async {
        eqConfiguration = configuration
        isEQEnabled = configuration.isEnabled

        if configuration.isEnabled {
            // Ensure EQ is in the graph
            if !isEQInGraph {
                insertEQIntoGraph()
            }

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
                removeEQFromGraph()
            }
            engine.mainMixerNode.outputVolume = 1.0  // Reset to unity
        }

        logger.debug("EQ \(configuration.isEnabled ? "enabled" : "disabled") with preset: \(LogPrivacy.truncated(configuration.presetName ?? "Custom", limit: 32))")
    }

    // MARK: - Completion Handler

    /// Set a completion handler for when playback finishes
    public func setCompletionHandler(_ handler: @escaping () -> Void) {
        completionHandler = handler
    }

    /// Handle playback completion synchronously on main thread
    /// This is called from Task { @MainActor in } to avoid RealtimeMessenger crashes
    private func handlePlaybackCompletionSync() {
        playbackState = .stopped

        // Call completion handler if it exists
        completionHandler?()
    }

    deinit {
        // Swift 6 strict concurrency prevents accessing non-Sendable properties in deinit
        // Cleanup should be done explicitly via stop() method before deallocation
    }
}
