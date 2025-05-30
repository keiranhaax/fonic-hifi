//
//  AudioSessionManager.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation
import AVFoundation
import MediaPlayer

/// Concrete implementation of AudioSessionService using AVAudioSession
@MainActor
public final class AudioSessionManager: NSObject, AudioSessionService {
    
    // MARK: - Properties
    
    /// Shared instance for global access
    public static let shared = AudioSessionManager()
    
    /// The underlying AVAudioSession
    private let session = AVAudioSession.sharedInstance()
    
    /// Remote command center for handling media controls
    private let commandCenter = MPRemoteCommandCenter.shared()
    
    /// Now playing info center
    private let nowPlayingCenter = MPNowPlayingInfoCenter.default()
    
    /// Delegate for session events
    public weak var delegate: AudioSessionDelegate?
    
    /// Internal state tracking
    private var _isSessionActive = false
    private var hasRegisteredForNotifications = false
    
    // MARK: - Initialization
    
    public override init() {
        super.init()
    }
    
    // MARK: - AudioSessionService Implementation
    
    public func configureAudioSession() async throws {
        do {
            // Configure for music playback with AirPlay and Bluetooth support
            try session.setCategory(
                .playback,
                mode: .default,
                options: [.allowBluetooth, .allowAirPlay]
            )
            
            // Set preferred settings for high-quality audio
            try session.setPreferredSampleRate(48000) // 48kHz default
            try session.setPreferredIOBufferDuration(0.005) // 5ms for low latency
            
            // Register for notifications if not already done
            if !hasRegisteredForNotifications {
                registerForNotifications()
                hasRegisteredForNotifications = true
            }
            
        } catch {
            throw AudioError.sessionConfigurationFailed(reason: error.localizedDescription)
        }
    }
    
    public func activateAudioSession() async throws {
        do {
            try session.setActive(true, options: .notifyOthersOnDeactivation)
            _isSessionActive = true
        } catch {
            throw AudioError.sessionConfigurationFailed(reason: "Failed to activate session: \(error.localizedDescription)")
        }
    }
    
    public func deactivateAudioSession() async throws {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            _isSessionActive = false
        } catch {
            throw AudioError.sessionConfigurationFailed(reason: "Failed to deactivate session: \(error.localizedDescription)")
        }
    }
    
    // MARK: - Session State
    
    public var isSessionActive: Bool {
        get async { _isSessionActive }
    }
    
    public var currentRoute: String {
        get async {
            let outputs = session.currentRoute.outputs
            if let output = outputs.first {
                return output.portName
            }
            return "Unknown"
        }
    }
    
    public var isBackgroundAudioEnabled: Bool {
        get async {
            // Check if background audio capability is configured
            return session.category == .playback
        }
    }
    
    // MARK: - Interruption Handling
    
    public func handleInterruption(_ interruption: AudioInterruptionType) async {
        await delegate?.audioSessionDidInterrupt(interruption)
    }
    
    public func handleRouteChange(_ change: AudioRouteChange) async {
        await delegate?.audioSessionRouteDidChange(change)
    }
    
    // MARK: - Now Playing
    
    public func updateNowPlayingInfo(_ info: [String: Any]) async {
        nowPlayingCenter.nowPlayingInfo = info
    }
    
    public func clearNowPlayingInfo() async {
        nowPlayingCenter.nowPlayingInfo = nil
    }
    
    // MARK: - Remote Commands
    
    public func enableRemoteCommands() async {
        // Play/Pause
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.delegate?.audioSessionDidReceiveCommand(.play)
            }
            return .success
        }
        
        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.delegate?.audioSessionDidReceiveCommand(.pause)
            }
            return .success
        }
        
        // Next/Previous
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.delegate?.audioSessionDidReceiveCommand(.nextTrack)
            }
            return .success
        }
        
        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor in
                await self?.delegate?.audioSessionDidReceiveCommand(.previousTrack)
            }
            return .success
        }
        
        // Seek
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let seekEvent = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                await self?.delegate?.audioSessionDidReceiveCommand(.seek(to: seekEvent.positionTime))
            }
            return .success
        }
        
        // Skip intervals (15 seconds default)
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [15]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                await self?.delegate?.audioSessionDidReceiveCommand(.skipForward(skipEvent.interval))
            }
            return .success
        }
        
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [15]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            guard let skipEvent = event as? MPSkipIntervalCommandEvent else {
                return .commandFailed
            }
            Task { @MainActor in
                await self?.delegate?.audioSessionDidReceiveCommand(.skipBackward(skipEvent.interval))
            }
            return .success
        }
    }
    
    public func disableRemoteCommands() async {
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false
        
        // Remove all targets
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.skipForwardCommand.removeTarget(nil)
        commandCenter.skipBackwardCommand.removeTarget(nil)
    }
    
    // MARK: - Audio Output
    
    public func getAvailableOutputs() async -> [AudioDevice] {
        var devices: [AudioDevice] = []
        
        // Get current route outputs
        let outputs = session.currentRoute.outputs
        
        for output in outputs {
            let device = AudioDevice(
                id: output.uid,
                name: output.portName,
                type: audioDeviceType(from: output.portType),
                isOutput: true,
                supportedSampleRates: [44100, 48000], // Common iOS sample rates
                supportedBitDepths: [16, 24] // Assume 16 and 24-bit for iOS devices
            )
            devices.append(device)
        }
        
        // Add available ports if different from current
        if let availableInputs = session.availableInputs {
            for input in availableInputs {
                if !devices.contains(where: { $0.id == input.uid }) {
                    let device = AudioDevice(
                        id: input.uid,
                        name: input.portName,
                        type: audioDeviceType(from: input.portType),
                        isOutput: false,
                        supportedSampleRates: [44100, 48000],
                        supportedBitDepths: [16, 24]
                    )
                    devices.append(device)
                }
            }
        }
        
        return devices
    }
    
    public func setPreferredOutput(_ device: AudioDevice) async throws {
        // Note: iOS doesn't allow direct output selection via AVAudioSession
        // This would typically be done through MPVolumeView or system settings
        // For now, we'll throw an error indicating this limitation
        throw AudioError.deviceError(reason: "Direct audio output selection is not supported on iOS. Use system settings or AirPlay.")
    }
    
    // MARK: - Private Methods
    
    private func registerForNotifications() {
        // Interruption notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleInterruptionNotification(_:)),
            name: AVAudioSession.interruptionNotification,
            object: session
        )
        
        // Route change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChangeNotification(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: session
        )
        
        // Media services reset (rare but important)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: session
        )
    }
    
    @objc private func handleInterruptionNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        Task { @MainActor in
            switch type {
            case .began:
                await handleInterruption(.began)
                
            case .ended:
                let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt) == AVAudioSession.InterruptionOptions.shouldResume.rawValue
                await handleInterruption(.ended(shouldResume: shouldResume))
                
            @unknown default:
                break
            }
        }
    }
    
    @objc private func handleRouteChangeNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue) else {
            return
        }
        
        let previousRoute = (info[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)?
            .outputs.first?.portName
        
        let currentRoute = session.currentRoute.outputs.first?.portName ?? "Unknown"
        
        let change = AudioRouteChange(
            reason: AudioRouteChangeReason(from: reason),
            previousRoute: previousRoute,
            currentRoute: currentRoute
        )
        
        Task { @MainActor in
            await handleRouteChange(change)
        }
    }
    
    @objc private func handleMediaServicesReset(_ notification: Notification) {
        // Re-configure audio session after media services reset
        Task { @MainActor in
            do {
                try await configureAudioSession()
                if _isSessionActive {
                    try await activateAudioSession()
                }
            } catch {
                print("Failed to reconfigure audio session after media services reset: \(error)")
            }
        }
    }
    
    private func audioDeviceType(from portType: AVAudioSession.Port) -> AudioDeviceType {
        switch portType {
        case .builtInSpeaker, .builtInReceiver:
            return .builtin
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            return .bluetooth
        case .airPlay:
            return .airplay
        case .usbAudio:
            return .usb
        case .HDMI:
            return .hdmi
        default:
            return .builtin
        }
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}