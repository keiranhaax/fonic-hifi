//
//  PlaybackCoordinator.swift
//  Fonic HiFi
//
//  Coordinates playback operations including play, pause, stop, seek, and progress tracking.
//  Extracted from AudioEngineFacade to improve modularity and maintainability.
//

import Foundation
import AVFoundation
import os.log

/// Handles all playback-related operations and progress management
@MainActor
public final class PlaybackCoordinator {
  
  // MARK: - Dependencies
  
  private let sessionManager: AudioSessionManager
  private let formatDetectionManager: AudioFormatDetectionManager
  private let engineFactory: AudioEngineFactory
  private let stateManager: PlaybackStateManager
  private let queueManager: AudioQueueManager
  private let validator: BitPerfectValidator
  private let monitor: AudioMonitor
  private let progressTimer: ProgressTimerManager
  
  // MARK: - State
  
  private weak var facade: AudioEngineFacade?
  private var currentEngine: AudioEngineService? {
    facade?.currentEngine
  }
  
  private var engineConfiguration: AudioEngineConfiguration {
    facade?.engineConfiguration ?? .default
  }
  
  private let logger = Logger(subsystem: "com.fonichifi.audio", category: "PlaybackCoordinator")
  
  // MARK: - Initialization
  
  init(
    sessionManager: AudioSessionManager,
    formatDetectionManager: AudioFormatDetectionManager,
    engineFactory: AudioEngineFactory,
    stateManager: PlaybackStateManager,
    queueManager: AudioQueueManager,
    validator: BitPerfectValidator,
    monitor: AudioMonitor,
    progressTimer: ProgressTimerManager,
    facade: AudioEngineFacade
  ) {
    self.sessionManager = sessionManager
    self.formatDetectionManager = formatDetectionManager
    self.engineFactory = engineFactory
    self.stateManager = stateManager
    self.queueManager = queueManager
    self.validator = validator
    self.monitor = monitor
    self.progressTimer = progressTimer
    self.facade = facade
  }
  
  // MARK: - Playback Control
  
  /// Play a specific track
  /// - Parameter track: The track to play
  public func play(track: Track) async throws {
    assertMainThread()
    
    guard facade?.isReady == true else {
      throw AudioError.engineInitializationFailed(reason: "Engine not ready")
    }
    
    logger.info("Playing track: \(track.title)")
    
    // Ensure we're on MainActor since this is a public API
    dispatchPrecondition(condition: .onQueue(.main))
    
    do {
      // 1. Ensure audio session is active first
      try await sessionManager.activateAudioSession()
      logger.debug("Audio session activated")
      
      // 2. Detect format
      let formatInfo = try await formatDetectionManager.detectFormat(at: track.url)
      logger.debug("Format detected: \(formatInfo.format.displayName)")
      
      // 3. Validate bit-perfect capability if needed
      if engineConfiguration.performanceMode == .quality {
        let validationResult = await validator.validateBitPerfectPlayback(
          sourceFormat: formatInfo,
          outputDevice: nil
        )
        
        if !validationResult.isValid {
          logger.warning("Bit-perfect validation failed: \(validationResult.mismatchReason?.userFriendlyDescription ?? "Unknown")")
        }
      }
      
      // 4. Create or reconfigure engine if needed
      try await ensureEngineForFormat(formatInfo)
      
      // 5. Update queue - we're already on MainActor
      if queueManager.currentTrack?.id != track.id {
        queueManager.setCurrentTrack(track.toAudioTrack())
      }
      stateManager.updateState(.loading())
      
      // 6. Load and play
      guard let engine = currentEngine else {
        throw AudioError.engineInitializationFailed(reason: "Engine not ready")
      }
      
      try await engine.load(url: track.url)
      stateManager.updateState(.playing(currentTime: 0, duration: formatInfo.duration))
      
      try await engine.play()
      
      // Start progress timer with optimized interval (0.25s for better battery life)
      startProgressTracking()
      
      logger.info("Playback started successfully")
      
    } catch {
      // Handle errors - we're already on MainActor
      logger.error("Failed to play track: \(error.localizedDescription)")
      stateManager.updateState(.error(
        error as? AudioError ?? .playbackFailed(reason: error.localizedDescription),
        lastKnownTime: nil
      ))
      throw error
    }
  }
  
  /// Resume playback from current position
  public func resume() async throws {
    assertMainThread()
    
    guard facade?.isReady == true else {
      throw AudioError.engineInitializationFailed(reason: "Engine not ready")
    }
    
    guard let engine = currentEngine else {
      throw AudioError.engineInitializationFailed(reason: "Engine not ready")
    }
    
    logger.info("Resuming playback")
    
    do {
      if let nextState = stateManager.currentState.nextPlayState {
        stateManager.updateState(nextState)
      }
      
      try await engine.play()
      
      // Update state to playing with current time
      let currentTime = await engine.currentTime
      let duration = await engine.duration
      stateManager.updateState(.playing(currentTime: currentTime, duration: duration))
      
      // Restart progress timer with optimized interval
      startProgressTracking()
      
    } catch {
      logger.error("Failed to resume playback: \(error.localizedDescription)")
      stateManager.updateState(.error(
        error as? AudioError ?? .playbackFailed(reason: error.localizedDescription),
        lastKnownTime: nil
      ))
      throw error
    }
  }
  
  /// Pause playback
  public func pause() async {
    assertMainThread()
    
    guard facade?.isReady == true, let engine = currentEngine else {
      logger.warning("Cannot pause: engine not ready")
      return
    }
    
    logger.info("Pausing playback")
    
    // Stop progress timer
    progressTimer.stop()
    
    await engine.pause()
    
    // Update state to paused with current time
    let currentTime = await engine.currentTime
    let duration = await engine.duration
    stateManager.updateState(.paused(currentTime: currentTime, duration: duration))
  }
  
  /// Stop playback completely
  public func stop() async {
    assertMainThread()
    
    guard let engine = currentEngine else {
      stateManager.updateState(.stopped)
      return
    }
    
    logger.info("Stopping playback")
    
    // Stop progress timer
    progressTimer.stop()
    
    await engine.stop()
    stateManager.updateState(.stopped)
  }
  
  /// Seek to a specific time position
  /// - Parameter time: Target time in seconds
  public func seek(to time: TimeInterval) async throws {
    assertMainThread()
    
    guard facade?.isReady == true, let engine = currentEngine else {
      throw AudioError.engineInitializationFailed(reason: "Engine not ready")
    }
    
    let currentState = stateManager.currentState
    guard currentState.canSeek else {
      throw AudioError.playbackFailed(reason: "Cannot seek in current state")
    }
    
    logger.info("Seeking to \(time)s")
    
    let currentTime = await engine.currentTime
    let duration = await engine.duration
    
    stateManager.updateState(.seeking(targetTime: time, currentTime: currentTime))
    
    do {
      try await engine.seek(to: time)
      
      // Update state based on previous playing status
      if currentState.isPlaying {
        stateManager.updateState(.playing(currentTime: time, duration: duration))
      } else {
        stateManager.updateState(.paused(currentTime: time, duration: duration))
      }
      
    } catch {
      logger.error("Seek failed: \(error.localizedDescription)")
      // Restore previous state
      if currentState.isPlaying {
        stateManager.updateState(.playing(currentTime: currentTime, duration: duration))
      } else {
        stateManager.updateState(.paused(currentTime: currentTime, duration: duration))
      }
      throw error
    }
  }
  
  // MARK: - Progress Management
  
  /// Start progress tracking timer
  private func startProgressTracking() {
    progressTimer.start(pollInterval: 0.2) { [weak self] in
      guard let self = self else { return }
      guard let engine = self.currentEngine,
            self.stateManager.currentState.isPlaying else {
        return
      }
      
      Task {
        let currentTime = await engine.currentTime
        let duration = await engine.duration
        await MainActor.run {
          self.stateManager.updateTime(currentTime, duration: duration)
        }
      }
    }
  }
  
  /// Stop progress tracking
  public func stopProgressTracking() {
    progressTimer.stop()
  }
  
  // MARK: - Engine Management
  
  private func ensureEngineForFormat(_ formatInfo: AudioFileInfo) async throws {
    // Get user's preferred engine
    let preferredEngine = UserDefaults.standard.string(forKey: "preferredAudioEngine") ?? "AVAudioEngine"

    // Check if we need to switch engines based on preference change
    if let currentEngine = currentEngine {
      // Determine the current engine type
      let currentEngineType: String
      switch currentEngine {
      case is AudioKitEngineAdapter:
        currentEngineType = "AudioKit"
      case is AVAudioEngineAdapter:
        currentEngineType = "AVAudioEngine"
      default:
        currentEngineType = "Unknown"
      }

      // If the preferred engine matches current, and it can handle the format, keep it
      if currentEngineType == preferredEngine ||
         (preferredEngine == "AudioKitEngine" && currentEngineType == "AudioKit") {
        // Engine type matches preference, keep current engine
        logger.debug("Current engine matches preference: \(currentEngineType)")
        return
      }

      // Preference changed, need to recreate engine
      logger.info("Engine preference changed from \(currentEngineType) to \(preferredEngine), recreating engine")

      // Stop current playback if playing
      if await stateManager.currentState.isPlaying {
        await currentEngine.stop()
      }

      // Dispose of current engine
      facade?.setCurrentEngine(nil)
    }

    // Create new engine based on preference and format
    let engine = try await engineFactory.makeEngine(
      for: formatInfo.format,
      configuration: engineConfiguration
    )

    // Attach to monitoring
    await monitor.attachToEngine(engine)

    // Set the engine on the facade
    facade?.setCurrentEngine(engine)
    logger.debug("Created new audio engine: \(preferredEngine) for format: \(formatInfo.format.displayName)")
  }
  
  // MARK: - Thread Safety
  
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
}