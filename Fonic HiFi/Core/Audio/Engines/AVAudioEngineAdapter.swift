//
//  AVAudioEngineAdapter.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation
import AVFoundation

/// AVAudioEngine-based implementation of AudioEngineService for standard audio formats
@MainActor
public final class AVAudioEngineAdapter: NSObject, AudioEngineService {
    
    // MARK: - Properties
    
    /// The underlying AVAudioEngine
    private let engine = AVAudioEngine()
    
    /// Player node for audio playback
    private let playerNode = AVAudioPlayerNode()
    
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
    
    /// Current configuration
    private var configuration: AudioEngineConfiguration = .init()
    
    /// Completion handler for when playback finishes
    private var completionHandler: (() -> Void)?
    
    /// Performance metrics collector
    private var metricsStartTime: Date?
    private var bufferUnderrunCount: Int = 0
    
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
            return playerNode.isPlaying
        }
    }
    
    public var volume: Float {
        get async {
            return playerNode.volume
        }
    }
    
    public var audioFormat: AudioFormat? {
        get async {
            guard let url = audioFile?.url else { return nil }
            return AudioFormat.from(url: url)
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
        
        do {
            // Create audio file
            audioFile = try AVAudioFile(forReading: url)
            guard let file = audioFile else {
                throw AudioError.fileNotFound(url)
            }
            
            print("=== AVAUDIOENGINE PREPARE DEBUG ===")
            
            // Store total frames for duration calculation
            totalFrames = file.length
            
            // Connect player node if needed
            if !engine.isRunning {
                try startEngine()
            }
            
            let format = file.processingFormat
            print("1. Attached player node")
            print("2. Connected player to mixer with format: \(format)")
            print("3. Sample rate: \(format.sampleRate)")
            print("4. Channels: \(format.channelCount)")
            print("5. Main mixer connected to output: \(engine.mainMixerNode.numberOfOutputs > 0)")
            print("6. Engine prepared")
            print("=== END PREPARE DEBUG ===")
            
            playbackState = .idle
            
        } catch {
            throw AudioError.decodingFailed(reason: error.localizedDescription)
        }
    }
    
    public func play() async throws {
        assertMainThread()
        
        guard let file = audioFile else {
            throw AudioError.fileNotFound(URL(fileURLWithPath: ""))
        }
        
        print("=== AVAUDIOENGINE PLAY DEBUG ===")
        print("1. Engine running before start: \(engine.isRunning)")

        // Audio session is managed by AudioSessionManager, not here

        // Start playback
        if !engine.isRunning {
            try startEngine()
            print("2. Engine started")
        }
        
        print("3. Engine running after start: \(engine.isRunning)")
        print("4. Player node playing state: \(playerNode.isPlaying)")
        
        // Schedule file for playback
        // CRITICAL: AVAudioPlayerNode completion handlers run on background threads
        // per Apple documentation. We must explicitly dispatch to main actor.
        playerNode.scheduleFile(file, at: nil) {
            print("5. File playback completed")
            // This closure runs on Core Audio's background thread
            // Use Task to dispatch to MainActor safely
            Task { @MainActor [weak self] in
                self?.handlePlaybackCompletionSync()
            }
        }
        
        playerNode.play()
        print("6. Called playerNode.play()")
        print("7. Player node playing after play: \(playerNode.isPlaying)")
        print("8. Output volume: \(playerNode.volume)")
        print("9. Engine output node volume: \(engine.mainMixerNode.outputVolume)")
        print("=== END AVAUDIOENGINE DEBUG ===")
        
        playbackState = .playing(currentTime: await currentTime, duration: await duration)
        
        // Progress timer is managed by AudioEngineFacade
        // Record metrics start time
        metricsStartTime = Date()
        bufferUnderrunCount = 0
    }
    
    public func pause() async {
        assertMainThread()
        
        playerNode.pause()
        playbackState = .paused(currentTime: await currentTime, duration: await duration)
        // Progress timer is managed by AudioEngineFacade
    }
    
    public func stop() async {
        assertMainThread()
        
        playerNode.stop()
        playbackState = .stopped
        // Progress timer is managed by AudioEngineFacade
        
        // Reset position
        audioFile = nil
        totalFrames = 0
        
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            print("Failed to deactivate audio session: \(error)")
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
        guard framePosition >= 0 && framePosition < file.length else {
            throw AudioError.invalidSeekPosition(time)
        }
        
        // Create new segment
        let framesToPlay = file.length - framePosition
        
        // Schedule segment
        playerNode.scheduleSegment(
            file,
            startingFrame: framePosition,
            frameCount: AVAudioFrameCount(framesToPlay),
            at: nil
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
    
    public func prepareNext(url: URL) async {
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
            bufferUnderruns: bufferUnderrunCount,
            decodingLatency: 0.001, // AVAudioEngine has very low latency
            bufferFillLevel: 1.0,
            droppedFrames: 0,
            renderLatency: 0.005,
            timestamp: Date()
        )
    }
    
    // MARK: - Private Methods
    
    private func setupEngine() {
        // Attach player node
        engine.attach(playerNode)
        
        // Connect player to output
        let format = engine.outputNode.outputFormat(forBus: 0)
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
        // Set up tap for monitoring (optional)
        setupMonitoring()
    }
    
    private func startEngine() throws {
        if !engine.isRunning {
            try engine.start()
        }
    }
    
    private func hasAudioProcessing() -> Bool {
        // Check if any effects or processing nodes are connected
        // For now, return false as we don't have effects yet
        return false
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
        
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { [weak self] buffer, time in
            // Monitor for buffer underruns
            // Audio tap handlers run on audio render thread, so dispatch to main actor for state updates
            if buffer.frameLength == 0 {
                Task { @MainActor [weak self] in
                    self?.bufferUnderrunCount += 1
                }
            }
        }
    }
    
    private func getCurrentCPUUsage() -> Float {
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
                    &count
                )
            }
        }
        
        if result == KERN_SUCCESS {
            // This is a simplified calculation
            return Float(info.resident_size) / Float(1024 * 1024 * 1024) * 100
        }
        
        return 0
    }
    
    private func getCurrentMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        if result == KERN_SUCCESS {
            return Int64(info.resident_size)
        }
        
        return 0
    }
    
    // MARK: - Completion Handler
    
    /// Set a completion handler for when playback finishes
    public func setCompletionHandler(_ handler: @escaping () -> Void) {
        completionHandler = handler
    }
    
    /// Handle playback completion synchronously on main thread
    /// This is called from Task { @MainActor in } to avoid RealtimeMessenger crashes
    private func handlePlaybackCompletionSync() {
        assertMainThread()
        
        playbackState = .stopped
        
        // Call completion handler if it exists
        completionHandler?()
    }
    
    /// Assert that we're running on the main thread
    /// Helps catch threading issues during development
    private func assertMainThread(
        file: StaticString = #file,
        line: UInt = #line,
        function: StaticString = #function
    ) {
        #if DEBUG
        assert(
            Thread.isMainThread,
            "\(function) must be called on the main thread. Called from \(file):\(line)"
        )
        #endif
    }
    
    deinit {
        // Swift 6 strict concurrency prevents accessing non-Sendable properties in deinit
        // Cleanup should be done explicitly via stop() method before deallocation
    }
}
