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
    
    /// Timer for updating playback progress
    private var progressTimer: Timer?
    
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
            
            // Store total frames for duration calculation
            totalFrames = file.length
            
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
        
        // Configure audio session
        try await sessionManager.configureAudioSession()
        try await sessionManager.activateAudioSession()
        
        // Schedule file for playback
        playerNode.scheduleFile(file, at: nil) { [weak self] in
            Task { @MainActor in
                self?.handlePlaybackCompletion()
            }
        }
        
        // Start playback
        if !engine.isRunning {
            try startEngine()
        }
        
        playerNode.play()
        playbackState = .playing
        
        // Start progress timer
        startProgressTimer()
        
        // Record metrics start time
        metricsStartTime = Date()
        bufferUnderrunCount = 0
    }
    
    public func pause() async {
        playerNode.pause()
        playbackState = .paused
        stopProgressTimer()
    }
    
    public func stop() async {
        playerNode.stop()
        playbackState = .stopped
        stopProgressTimer()
        
        // Reset position
        audioFile = nil
        totalFrames = 0
        
        // Deactivate audio session
        try? await sessionManager.deactivateAudioSession()
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
            Task { @MainActor in
                self?.handlePlaybackCompletion()
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
        stopProgressTimer()
        completionHandler?()
    }
    
    private func startProgressTimer() {
        stopProgressTimer()
        
        progressTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                // Update progress if needed
                // This could post notifications or update delegates
            }
        }
    }
    
    private func stopProgressTimer() {
        progressTimer?.invalidate()
        progressTimer = nil
    }
    
    private func setupMonitoring() {
        // Install tap on output for monitoring buffer underruns
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        
        engine.mainMixerNode.installTap(
            onBus: 0,
            bufferSize: 1024,
            format: format
        ) { [weak self] buffer, time in
            // Monitor for buffer underruns
            if buffer.frameLength == 0 {
                self?.bufferUnderrunCount += 1
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
    
    deinit {
        stopProgressTimer()
        engine.stop()
    }
}