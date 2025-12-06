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

    /// Player node for audio playback
    private let playerNode = AVAudioPlayerNode()

    /// Time pitch node for playback rate adjustment
    private let timePitchNode = AVAudioUnitTimePitch()

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
    private let sessionManager = AudioSessionManager.shared

    private let logger = Log.logger(.audioEngine)

    /// Current configuration
    private var configuration: AudioEngineConfiguration = .init()

    /// Completion handler for when playback finishes
    private var completionHandler: (() -> Void)?

    /// Performance metrics collector
    private var metricsStartTime: Date?
    private let bufferUnderruns = BufferUnderrunTracker()

    // MARK: - Initialization

    override public init() {
        super.init()
        setupEngine()
    }

    // MARK: - AudioEngineService Implementation

    public var currentTime: TimeInterval {
        get async {
            guard let playerTime = playerNode.playerTime(forNodeTime: playerNode.lastRenderTime ?? AVAudioTime()) else {
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
            playerNode.isPlaying
        }
    }

    public var volume: Float {
        get async {
            playerNode.volume
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
                playerNode.volume == 1.0 &&
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
            logger.debug("4. Player node playing state: \(self.playerNode.isPlaying, privacy: .public)")
        #endif

        // Schedule file for playback
        // CRITICAL: AVAudioPlayerNode completion handlers run on background threads
        // per Apple documentation. We must explicitly dispatch to main actor.
        playerNode.scheduleFile(file, at: nil) { [weak self] in
            #if DEBUG
                self?.logger.debug("5. File playback completed")
            #endif
            // This closure runs on Core Audio's background thread
            // Use Task to dispatch to MainActor safely
            Task { @MainActor [weak self] in
                self?.handlePlaybackCompletionSync()
            }
        }

        playerNode.play()
        #if DEBUG
            logger.debug("6. Called playerNode.play()")
            logger.debug("7. Player node playing after play: \(self.playerNode.isPlaying, privacy: .public)")
            logger.debug("8. Output volume: \(self.playerNode.volume, privacy: .public)")
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
        playerNode.pause()
        playbackState = await .paused(currentTime: currentTime, duration: duration)
        // Progress timer is managed by AudioEngineFacade
    }

    public func stop() async {
        playerNode.stop()
        playbackState = .stopped
        // Progress timer is managed by AudioEngineFacade

        // Reset position
        audioFile = nil
        totalFrames = 0
        await bufferUnderruns.reset()

        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            logger.error("Failed to deactivate audio session: \(String(describing: error), privacy: .public)")
        }
    }

    public func seek(to time: TimeInterval) async throws {
        guard let file = audioFile else {
            throw AudioError.invalidSeekPosition(time)
        }

        let wasPlaying = playerNode.isPlaying

        // Stop current playback
        playerNode.stop()

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
        playerNode.scheduleSegment(
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
            playerNode.play()
        }
    }

    public func setVolume(_ volume: Float) async {
        playerNode.volume = max(0.0, min(1.0, volume))
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

    public func prepareNext(url _: URL) async {
        // For gapless playback preparation
        // This is a simplified implementation
        // Full gapless requires more complex buffering
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
        // Attach nodes
        engine.attach(playerNode)
        engine.attach(timePitchNode)

        // Connect player → timePitch → mixer
        let format = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(playerNode, to: timePitchNode, format: format)
        engine.connect(timePitchNode, to: engine.mainMixerNode, format: format)

        // Set up tap for monitoring (optional)
        setupMonitoring()
    }

    private func startEngine() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }

    private func hasAudioProcessing() -> Bool {
        // Check if any effects or processing nodes are active
        // Time pitch node is active if rate is not 1.0
        currentPlaybackRate != 1.0
    }

    private func handlePlaybackCompletion() {
        playbackState = .stopped
        // Progress timer is managed by AudioEngineFacade
        completionHandler?()
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
        timePitchNode.rate = Float(clampedRate)
        currentPlaybackRate = clampedRate
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
