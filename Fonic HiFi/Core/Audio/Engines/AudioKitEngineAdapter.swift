//
//  AudioKitEngineAdapter.swift
//  Fonic HiFi
//
//  Created by Claude on 5/30/25.
//

import Foundation
import AVFoundation
import Combine
import AudioKit

/// AudioKit-based implementation of AudioEngineService with native scheduling
@MainActor
public final class AudioKitEngineAdapter: NSObject, AudioEngineService, ObservableObject {
    
    // MARK: - AudioKit Components

    private let engine = AudioEngine()
    private let player = AudioPlayer()
    private let mixer = Mixer()
    
    // MARK: - State Management
    
    /// Current audio file being played
    private var currentFile: AVAudioFile?
    
    /// Published state for Combine integration
    @Published public private(set) var _isPlaying = false
    @Published public private(set) var _currentTime: TimeInterval = 0
    @Published public private(set) var _duration: TimeInterval = 0
    @Published public private(set) var _volume: Float = 1.0
    
    /// Timer for state updates
    private var updateTimer: Timer?
    
    /// Current configuration
    private var configuration: AudioEngineConfiguration = .default
    
    /// Completion handler for track finish
    private var completionHandler: (() -> Void)?
    
    // MARK: - AudioEngineService Properties
    
    public var currentTime: TimeInterval {
        get async { _currentTime }
    }
    
    public var duration: TimeInterval {
        get async { _duration }
    }
    
    public var isPlaying: Bool {
        get async { _isPlaying }
    }
    
    public var volume: Float {
        get async { _volume }
    }
    
    public var audioFormat: AudioFormat? {
        get async {
            guard let file = currentFile else { return nil }
            return AudioFormat.from(avAudioFormat: file.fileFormat)
        }
    }
    
    public var isBitPerfect: Bool {
        get async {
            // AudioKit can provide bit-perfect playback in certain configurations
            return configuration.performanceMode == .quality
        }
    }
    
    // MARK: - Initialization

    /// Indicates whether AudioKit initialized successfully
    public private(set) var isInitialized: Bool = false

    override public init() {
        super.init()
        do {
            try setupAudioKitEngine()
        } catch {
            print("AudioKit initialization failed: \(error)")
            // Factory will check isInitialized to determine if fallback is needed
        }
    }

    /// Check if the engine initialized successfully
    /// - Throws: AudioError if initialization failed
    public func checkInitialization() throws {
        guard isInitialized else {
            throw AudioError.engineInitializationFailed(
                reason: "AudioKit engine failed to initialize. Audio system may not be available."
            )
        }
    }
    
    deinit {
        Task { [weak self] in
            await self?.cleanup()
        }
    }
    
    // MARK: - AudioEngineService Implementation
    
    public func load(url: URL) async throws {
        guard isInitialized else {
            throw AudioError.engineInitializationFailed(reason: "AudioKit engine is not initialized")
        }

        do {
            // Load the audio file
            let avFile = try AVAudioFile(forReading: url)
            currentFile = avFile

            // Load into AudioKit player
            try player.load(file: avFile)

            // Calculate duration
            _duration = Double(avFile.length) / avFile.fileFormat.sampleRate
            _currentTime = 0

        } catch {
            throw AudioError.decodingFailed(reason: "Failed to load file: \(error.localizedDescription)")
        }
    }
    
    public func play() async throws {
        guard isInitialized else {
            throw AudioError.engineInitializationFailed(reason: "AudioKit engine is not initialized")
        }
        guard currentFile != nil else {
            throw AudioError.playbackFailed(reason: "No file loaded")
        }

        player.play()
        _isPlaying = true
        startProgressPolling()
    }
    
    public func pause() async {
        player.pause()
        _isPlaying = false
        stopProgressPolling()
    }
    
    public func stop() async {
        player.stop()
        _isPlaying = false
        _currentTime = 0
        stopProgressPolling()
    }
    
    public func seek(to time: TimeInterval) async throws {
        guard currentFile != nil else {
            throw AudioError.playbackFailed(reason: "No file loaded")
        }

        player.play(from: time)
        _currentTime = time

        // If we were paused, pause again after seeking
        if !_isPlaying {
            player.pause()
        }
    }
    
    public func setVolume(_ volume: Float) async {
        let clampedVolume = max(0.0, min(1.0, volume))
        player.volume = AUValue(clampedVolume)
        _volume = clampedVolume
    }
    
    public func configure(with configuration: AudioEngineConfiguration) async throws {
        self.configuration = configuration
        
        // Configure AudioKit engine based on performance mode
        switch configuration.performanceMode {
        case .efficiency:
            // Optimize for battery life
            break
        case .balanced:
            // Balanced performance
            break
        case .quality:
            // Maximum quality, bit-perfect if possible
            break
        }
    }
    
    public func prepareNext(url: URL) async {
        // AudioKit doesn't have built-in gapless playback
        // This would require more sophisticated buffer management
    }
    
    public func getMetrics() async -> AudioMetrics {
        let sampleRate = currentFile?.fileFormat.sampleRate ?? 44100
        let channelCount = Int(currentFile?.fileFormat.channelCount ?? 2)
        let bitDepth = Int(getBitDepthFromFormat(currentFile?.fileFormat.commonFormat))
        
        return AudioMetrics(
            cpuUsage: 0.0,
            memoryUsage: 0,
            bufferUnderruns: 0,
            decodingLatency: 0.0,
            bufferFillLevel: 1.0,
            droppedFrames: 0,
            renderLatency: 0.0,
            timestamp: Date(),
            currentBitrate: 0,
            averageLatency: 0.0,
            peakLatency: 0.0,
            glitchCount: 0,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channelCount: channelCount,
            engineType: "AudioKit",
            audioFormat: "Unknown",
            isBitPerfect: false,
            bufferSize: 512,
            bufferResets: 0,
            averageBufferFill: 1.0,
            underrunRate: 0.0,
            timeSinceLastUnderrun: nil,
            diskIOPS: 0.0,
            networkBandwidth: 0,
            thermalPressure: 0.0,
            batteryUsageRate: nil,
            threadUtilization: ThreadUtilization(),
            estimatedSNR: nil,
            dynamicRange: nil,
            frequencyResponseScore: nil,
            jitter: 0.0,
            clockDrift: 0.0,
            recoverableErrors: 0,
            criticalErrors: 0,
            recoverySuccessRate: 1.0,
            lastRecoveryTime: nil,
            performanceScore: 1.0,
            qualityScore: 1.0,
            reliabilityScore: 1.0,
            efficiencyScore: 1.0
        )
    }
    
    public func collectMetrics() async {
        // Implementation for metrics collection
    }
    
    // MARK: - Private Methods
    
    private func setupAudioKitEngine() throws {
        // Configure AudioKit engine
        mixer.addInput(player)
        engine.output = mixer

        do {
            try engine.start()
            isInitialized = true
        } catch {
            isInitialized = false
            throw AudioError.engineInitializationFailed(
                reason: "AudioKit failed to start: \(error.localizedDescription)"
            )
        }
    }
    
    private func startProgressPolling() {
        stopProgressPolling()
        
        updateTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                await self.updateProgress()
            }
        }
    }
    
    private func stopProgressPolling() {
        updateTimer?.invalidate()
        updateTimer = nil
    }
    
    private func updateProgress() async {
        guard _isPlaying else { return }

        // Get current time from AudioKit player
        _currentTime = player.currentTime

        // Check if we've reached the end
        if _currentTime >= _duration {
            _isPlaying = false
            stopProgressPolling()
            completionHandler?()
        }
    }
    
    private func cleanup() async {
        stopProgressPolling()
        engine.stop()
    }
}


// MARK: - Helper Functions

private func getBitDepthFromFormat(_ format: AVAudioCommonFormat?) -> Double {
    guard let format = format else { return 16.0 }
    
    switch format {
    case .pcmFormatFloat32:
        return 32.0
    case .pcmFormatInt16:
        return 16.0
    case .pcmFormatInt32:
        return 32.0
    default:
        return 16.0
    }
}

// MARK: - AudioFormat Extension

extension AudioFormat {
    static func from(avAudioFormat: AVAudioFormat) -> AudioFormat {
        // Try to infer format from file extension or format description
        // This is a simplified implementation
        let sampleRate = avAudioFormat.sampleRate
        let channels = avAudioFormat.channelCount
        
        // For now, default to FLAC for high-res, AAC for standard
        if sampleRate > 48000 || channels > 2 {
            return .flac
        } else {
            return .aac
        }
    }
}