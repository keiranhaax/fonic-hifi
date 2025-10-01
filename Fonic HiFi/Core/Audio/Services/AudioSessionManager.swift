//
//  AudioSessionManager.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import AVFoundation
import Foundation
import MediaPlayer

/// Protocol for audio session management with proper actor isolation
@MainActor
public protocol AudioSessionManaging: Sendable {
    // Configuration
    func configureSession() async throws
    func activateSession(_ active: Bool) async throws

    // Remote Commands
    func enableRemoteCommands() async
    func disableRemoteCommands() async

    // Interruption Handling
    func handleInterruption(_ notification: Notification) async
    func handleRouteChange(_ notification: Notification) async

    // State Query
    var currentRouteDescription: AVAudioSessionRouteDescription { get async }
    var isSessionActive: Bool { get async }
    var supportsBitPerfect: Bool { get async }
}

/// Concrete implementation of AudioSessionService using AVAudioSession
@MainActor
public final class AudioSessionManager: NSObject, AudioSessionService, AudioSessionManaging {
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

    override public init() {
        super.init()
    }

    // MARK: - AudioSessionService Implementation

    public func configureAudioSession() async throws {
        do {
            // Set category for high-quality music playback. Avoid incompatible
            // option combinations (OSStatus -50) – we start with a minimal
            // configuration and layer in the optional AirPlay flag when allowed.
            do {
                try session.setCategory(
                    .playback,
                    mode: .default,
                    options: [.allowAirPlay]
                )
            } catch {
                // Some simulator/device builds reject .allowAirPlay with -50; fall
                // back to bare playback which still routes correctly.
                try session.setCategory(.playback, mode: .default, options: [])
            }

            // Register for system notifications
            if !hasRegisteredForNotifications {
                registerForNotifications()
                hasRegisteredForNotifications = true
            }
        } catch {
            throw AudioError.sessionConfigurationFailed(
                reason: "Failed to configure session: \(error.localizedDescription)"
            )
        }
    }

    public func activateAudioSession() async throws {
        do {
            try session.setActive(true, options: [])
            _isSessionActive = true
            print("✅ Audio session activated: category=\(session.category.rawValue), active=\(session.isOtherAudioPlaying)")
        } catch {
            throw AudioError.sessionConfigurationFailed(
                reason: "Failed to activate session: \(error.localizedDescription)"
            )
        }
    }

    public func deactivateAudioSession() async throws {
        do {
            try session.setActive(false, options: .notifyOthersOnDeactivation)
            _isSessionActive = false
            print("✅ Audio session deactivated")
        } catch {
            throw AudioError.sessionConfigurationFailed(
                reason: "Failed to deactivate session: \(error.localizedDescription)"
            )
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
            session.category == .playback
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
            // Remote commands run on real-time audio threads - must dispatch to main safely
            Task { @MainActor [weak self] in
                await self?.delegate?.audioSessionDidReceiveCommand(.play)
            }
            return .success
        }

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.delegate?.audioSessionDidReceiveCommand(.pause)
            }
            return .success
        }

        // Next/Previous
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.delegate?.audioSessionDidReceiveCommand(.nextTrack)
            }
            return .success
        }

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in
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
            Task { @MainActor [weak self] in
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
            Task { @MainActor [weak self] in
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
            Task { @MainActor [weak self] in
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
                supportedBitDepths: [16, 24], // Assume 16 and 24-bit for iOS devices
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
                        supportedBitDepths: [16, 24],
                    )
                    devices.append(device)
                }
            }
        }

        return devices
    }

    public func setPreferredOutput(_: AudioDevice) async throws {
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
            object: session,
        )

        // Route change notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRouteChangeNotification(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: session,
        )

        // Media services reset (rare but important)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
        )
    }

    @objc private func handleInterruptionNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let typeValue = info[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue)
        else {
            return
        }

        Task { @MainActor [weak self] in
            switch type {
            case .began:
                await self?.handleInterruption(.began)

            case .ended:
                let shouldResume = (info[AVAudioSessionInterruptionOptionKey] as? UInt) == AVAudioSession.InterruptionOptions.shouldResume.rawValue
                await self?.handleInterruption(.ended(shouldResume: shouldResume))

            @unknown default:
                break
            }
        }
    }

    @objc private func handleRouteChangeNotification(_ notification: Notification) {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            return
        }

        let previousRoute = (info[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)?
            .outputs.first?.portName

        let currentRoute = session.currentRoute.outputs.first?.portName ?? "Unknown"

        let change = AudioRouteChange(
            reason: AudioRouteChangeReason(from: reason),
            previousRoute: previousRoute,
            currentRoute: currentRoute,
        )

        Task { @MainActor [weak self] in
            await self?.handleRouteChange(change)
        }
    }

    @objc private func handleMediaServicesReset(_: Notification) {
        // Re-configure audio session after media services reset
        Task { @MainActor [weak self] in
            do {
                try await self?.configureAudioSession()
                if self?._isSessionActive == true {
                    try await self?.activateAudioSession()
                }
            } catch {
                print("Failed to reconfigure audio session after media services reset: \(error)")
            }
        }
    }

    private func audioDeviceType(from portType: AVAudioSession.Port) -> AudioDeviceType {
        switch portType {
        case .builtInSpeaker, .builtInReceiver:
            .builtin
        case .bluetoothA2DP, .bluetoothHFP, .bluetoothLE:
            .bluetooth
        case .airPlay:
            .airplay
        case .usbAudio:
            .usb
        case .HDMI:
            .hdmi
        default:
            .builtin
        }
    }

    // MARK: - AudioSessionManaging Protocol Methods

    /// Alias for configureAudioSession to match protocol
    public func configureSession() async throws {
        try await configureAudioSession()
    }

    /// Activate or deactivate the audio session
    public func activateSession(_ active: Bool) async throws {
        if active {
            try await activateAudioSession()
        } else {
            try await deactivateAudioSession()
        }
    }

    /// Handle interruption notifications
    public func handleInterruption(_ notification: Notification) async {
        handleInterruptionNotification(notification)
    }

    /// Handle route change notifications
    public func handleRouteChange(_ notification: Notification) async {
        handleRouteChangeNotification(notification)
    }

    // currentRoute already defined above at line 96 for AudioSessionService compatibility

    /// Get full current audio route for AudioSessionManaging
    public var currentRouteDescription: AVAudioSessionRouteDescription {
        get async {
            session.currentRoute
        }
    }

    // isSessionActive already defined above at line 92

    /// Check if the current route supports bit-perfect playback
    public var supportsBitPerfect: Bool {
        get async {
            // Check if we have a USB or Thunderbolt DAC connected
            let outputs = session.currentRoute.outputs
            for output in outputs {
                switch output.portType {
                case .usbAudio, .thunderbolt:
                    // External DACs typically support bit-perfect
                    return true
                case .headphones:
                    // Lightning/USB-C headphones might support it
                    return output.portName.contains("USB") || output.portName.contains("Lightning")
                default:
                    continue
                }
            }
            return false
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
