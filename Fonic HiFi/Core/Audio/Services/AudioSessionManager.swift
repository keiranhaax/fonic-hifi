//
//  AudioSessionManager.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import AVFoundation
import Foundation
import MediaPlayer
import OSLog

/// Protocol for audio session management with proper actor isolation
@MainActor
public protocol AudioSessionManaging: Sendable {
    // Configuration
    func configureSession() async throws
    func activateSession(_ active: Bool) async throws
    func setPreferredSampleRate(_ sampleRate: Double) async

    // Remote Commands
    func enableRemoteCommands() async
    func disableRemoteCommands() async

    // Framework Notifications
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
    private var interruptionObservationTokens = Set<NotificationCenter.ObservationToken>()
    private var isHandlingMediaServicesReset = false
    private(set) var remoteCommandRegistrationGeneration = 0
    /// Internal registration bookkeeping keeps lifecycle tests independent of
    /// the system-owned MPRemoteCommandCenter (which has no trigger API).
    private(set) var registeredRemoteCommandDescriptions: [String] = []
    private var remoteCommandRoutingEnabled = true
    private(set) var activationTransitionCount = 0
    private(set) var deactivationTransitionCount = 0

    private let logger = Log.logger(.audioSession)
    private let notificationCenter: NotificationCenter

    // MARK: - Initialization

    public init(notificationCenter: NotificationCenter = .default) {
        self.notificationCenter = notificationCenter
        super.init()
    }

    // MARK: - AudioSessionService Implementation

    public func configureAudioSession() async throws {
        do {
            // The playback category already supports AirPlay. The explicit
            // allowAirPlay option is only valid with playAndRecord.
            try session.setCategory(.playback, mode: .default, options: [])

            // Deliberate: keep the iOS 17+ default of interrupting active
            // Now Playing sessions when the route disconnects. The unplug then
            // arrives both as an interruption and as an .oldDeviceUnavailable
            // route change; StateCoordinator clears the auto-resume intent on
            // the route path so the pair cannot resume onto the new route.
            try session.setPrefersInterruptionOnRouteDisconnect(true)

            // Register for system notifications
            if !hasRegisteredForNotifications {
                registerForNotifications()
                hasRegisteredForNotifications = true
            }
        } catch {
            throw AudioError.sessionConfigurationFailed(
                reason: "Failed to configure session: \(error.localizedDescription)",
            )
        }
    }

    public func activateAudioSession() async throws {
        guard !_isSessionActive else { return }

        do {
            let didActivate = try await session.activate(options: [])

            guard didActivate else {
                throw AudioError.sessionConfigurationFailed(
                    reason: "The system declined audio-session activation"
                )
            }

            _isSessionActive = true
            activationTransitionCount += 1
            logger.notice(
                """
                Audio session activated:
                category=\(self.session.category.rawValue, privacy: .public)
                sampleRate=\(self.session.sampleRate, privacy: .public)
                otherAudioPlaying=\(self.session.isOtherAudioPlaying, privacy: .public)
                """
            )
        } catch {
            throw AudioError.sessionConfigurationFailed(
                reason: "Failed to activate session: \(error.localizedDescription)",
            )
        }
    }

    public func deactivateAudioSession() async throws {
        guard _isSessionActive else { return }

        do {
            let didDeactivate = try await session.deactivate(options: [.notifyOthersOnDeactivation])

            guard didDeactivate else {
                throw AudioError.sessionConfigurationFailed(
                    reason: "The system declined audio-session deactivation"
                )
            }

            _isSessionActive = false
            deactivationTransitionCount += 1
            logger.notice("Audio session deactivated")
        } catch {
            throw AudioError.sessionConfigurationFailed(
                reason: "Failed to deactivate session: \(error.localizedDescription)",
            )
        }
    }

    public func setPreferredSampleRate(_ sampleRate: Double) async {
        guard sampleRate > 0 else {
            logger.warning("Ignoring invalid preferred sample rate: \(sampleRate, privacy: .public)")
            return
        }

        do {
            try session.setPreferredSampleRate(sampleRate)
            logger.info(
                """
                Requested preferred sample rate:
                requested=\(sampleRate, privacy: .public)
                actualPreferred=\(self.session.preferredSampleRate, privacy: .public)
                active=\(self.session.sampleRate, privacy: .public)
                """
            )
        } catch {
            logger.warning("Failed to set preferred sample rate: \(error.localizedDescription, privacy: .private)")
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
        if case .began = interruption {
            _isSessionActive = false
        }
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
        // A facade can be re-initialised after shutdown or a media-services
        // reset. Remove every previous target before installing the one owned
        // command set so callbacks cannot execute twice.
        removeRemoteCommandTargets()
        remoteCommandRoutingEnabled = true
        remoteCommandRegistrationGeneration += 1

        // Play/Pause
        commandCenter.playCommand.isEnabled = true
        commandCenter.playCommand.addTarget(
            handler: Self.makeRemoteCommandHandler(owner: self, command: .play)
        )

        commandCenter.pauseCommand.isEnabled = true
        commandCenter.pauseCommand.addTarget(
            handler: Self.makeRemoteCommandHandler(owner: self, command: .pause)
        )

        commandCenter.stopCommand.isEnabled = true
        commandCenter.stopCommand.addTarget(
            handler: Self.makeRemoteCommandHandler(owner: self, command: .stop)
        )

        commandCenter.togglePlayPauseCommand.isEnabled = true
        commandCenter.togglePlayPauseCommand.addTarget(
            handler: Self.makeRemoteCommandHandler(owner: self, command: .togglePlayPause)
        )

        // Next/Previous
        commandCenter.nextTrackCommand.isEnabled = true
        commandCenter.nextTrackCommand.addTarget(
            handler: Self.makeRemoteCommandHandler(owner: self, command: .nextTrack)
        )

        commandCenter.previousTrackCommand.isEnabled = true
        commandCenter.previousTrackCommand.addTarget(
            handler: Self.makeRemoteCommandHandler(owner: self, command: .previousTrack)
        )

        // Seek
        commandCenter.changePlaybackPositionCommand.isEnabled = true
        commandCenter.changePlaybackPositionCommand.addTarget(
            handler: Self.makeSeekCommandHandler(owner: self)
        )

        // Relative skip commands are unsupported; keep them hidden from system controls.
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        registeredRemoteCommandDescriptions = [
            "play",
            "pause",
            "stop",
            "togglePlayPause",
            "nextTrack",
            "previousTrack",
            "changePlaybackPosition",
        ]
    }

    public func disableRemoteCommands() async {
        removeRemoteCommandTargets()
        remoteCommandRoutingEnabled = false
        registeredRemoteCommandDescriptions = []
    }

    /// Dispatches through the same MainActor handoff used by MPRemoteCommand
    /// handlers. This is only a deterministic lifecycle seam for tests; it
    /// does not simulate or claim a system Control Center event.
    internal func dispatchRegisteredRemoteCommandForTesting(_ command: RemoteCommand) {
        guard registeredRemoteCommandDescriptions.contains(Self.registrationKey(for: command)) else {
            return
        }
        Self.routeRemoteCommand(command, to: self)
    }

    private func removeRemoteCommandTargets() {
        commandCenter.playCommand.isEnabled = false
        commandCenter.pauseCommand.isEnabled = false
        commandCenter.stopCommand.isEnabled = false
        commandCenter.togglePlayPauseCommand.isEnabled = false
        commandCenter.nextTrackCommand.isEnabled = false
        commandCenter.previousTrackCommand.isEnabled = false
        commandCenter.changePlaybackPositionCommand.isEnabled = false
        commandCenter.skipForwardCommand.isEnabled = false
        commandCenter.skipBackwardCommand.isEnabled = false

        // Remove all targets
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.stopCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
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
        throw AudioError.deviceError(
            reason: """
            Direct audio output selection is not supported on iOS.
            Use system settings or AirPlay to choose an output.
            """
        )
    }

    // MARK: - Private Methods

    private func registerForNotifications() {
        let inactiveObservation = notificationCenter.addObserver(
            of: session,
            for: .didBecomeInactive
        ) { [weak self] message in
            guard let interruption = Self.interruption(
                from: message.deactivationResult
            ) else {
                return
            }
            Self.routeInterruption(interruption, to: self)
        }
        interruptionObservationTokens.insert(inactiveObservation)

        let resumptionObservation = notificationCenter.addObserver(
            of: session,
            for: .resumptionRecommendation
        ) { [weak self] message in
            Self.routeInterruption(
                Self.interruption(from: message.recommendation),
                to: self
            )
        }
        interruptionObservationTokens.insert(resumptionObservation)

        // Route change notifications
        notificationCenter.addObserver(
            self,
            selector: #selector(handleRouteChangeNotification(_:)),
            name: AVAudioSession.routeChangeNotification,
            object: session,
        )

        // Media services reset (rare but important)
        notificationCenter.addObserver(
            self,
            selector: #selector(handleMediaServicesReset(_:)),
            name: AVAudioSession.mediaServicesWereResetNotification,
            object: session,
        )
    }

    @objc nonisolated private func handleRouteChangeNotification(_ notification: Notification) {
        guard let payload = Self.routeChangePayload(from: notification) else { return }

        Task { @MainActor [weak self] in
            guard let self else { return }
            let currentRoute = self.session.currentRoute.outputs.first?.portName ?? "Unknown"
            let change = AudioRouteChange(
                reason: payload.reason,
                previousRoute: payload.previousRoute,
                currentRoute: currentRoute
            )
            await self.handleRouteChange(change)
        }
    }

    @objc nonisolated private func handleMediaServicesReset(_: Notification) {
        Task { @MainActor [weak self] in
            guard let self, !self.isHandlingMediaServicesReset else { return }
            self.isHandlingMediaServicesReset = true
            defer { self.isHandlingMediaServicesReset = false }

            let shouldReactivate = self._isSessionActive
            self._isSessionActive = false

            // Prevent commands from reaching invalid engine objects while the
            // session and playback graph are being rebuilt.
            await self.disableRemoteCommands()

            do {
                try await self.configureAudioSession()
                if shouldReactivate {
                    try await self.activateAudioSession()
                }
            } catch {
                self.logger.error(
                    """
                    Failed to reconfigure audio session after media services reset:
                    \(String(describing: error), privacy: .private)
                    """
                )
            }

            // The delegate owns playback orchestration and can now replace its
            // invalid engine while preserving user-visible playback state.
            await self.delegate?.audioSessionMediaServicesWereReset()

            // Media services reset invalidates command registrations as well as
            // audio-engine objects. Register one fresh command set only after
            // playback recovery has reached a coherent state.
            await self.enableRemoteCommands()
        }
    }

    private struct RouteChangePayload: Sendable {
        let reason: AudioRouteChangeReason
        let previousRoute: String?
    }

    nonisolated static func interruption(
        from recommendation: AVAudioSession.ResumptionRecommendation
    ) -> AudioInterruptionType {
        .ended(shouldResume: recommendation == .shouldResume)
    }

    nonisolated static func interruption(
        from deactivationResult: AVAudioSession.DeactivationResult
    ) -> AudioInterruptionType? {
        switch deactivationResult {
        case .systemInterruption:
            .began
        case .appDeactivated:
            nil
        @unknown default:
            nil
        }
    }

    nonisolated static func routeInterruption(
        _ interruption: AudioInterruptionType,
        to owner: AudioSessionManager?
    ) {
        Task { @MainActor [weak owner] in
            await owner?.handleInterruption(interruption)
        }
    }

    private nonisolated static func routeChangePayload(
        from notification: Notification
    ) -> RouteChangePayload? {
        guard let info = notification.userInfo,
              let reasonValue = info[AVAudioSessionRouteChangeReasonKey] as? UInt,
              let reason = AVAudioSession.RouteChangeReason(rawValue: reasonValue)
        else {
            return nil
        }

        let previousRoute = (info[AVAudioSessionRouteChangePreviousRouteKey] as? AVAudioSessionRouteDescription)?
            .outputs.first?.portName
        return RouteChangePayload(
            reason: AudioRouteChangeReason(from: reason),
            previousRoute: previousRoute
        )
    }

    private nonisolated static func makeRemoteCommandHandler(
        owner: AudioSessionManager,
        command: RemoteCommand
    ) -> (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        { [weak owner] _ in
            routeRemoteCommand(command, to: owner)
            return .success
        }
    }

    private nonisolated static func registrationKey(for command: RemoteCommand) -> String {
        switch command {
        case .play: "play"
        case .pause: "pause"
        case .stop: "stop"
        case .togglePlayPause: "togglePlayPause"
        case .nextTrack: "nextTrack"
        case .previousTrack: "previousTrack"
        case .seek: "changePlaybackPosition"
        default: "unsupported"
        }
    }

    nonisolated static func routeRemoteCommand(
        _ command: RemoteCommand,
        to owner: AudioSessionManager?
    ) {
        Task { @MainActor [weak owner] in
            guard let owner, owner.remoteCommandRoutingEnabled else {
                return
            }
            await owner.delegate?.audioSessionDidReceiveCommand(command)
        }
    }

    private nonisolated static func makeSeekCommandHandler(
        owner: AudioSessionManager
    ) -> (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus {
        { [weak owner] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            let position = event.positionTime
            Task { @MainActor [weak owner] in
                guard let owner,
                      owner.remoteCommandRoutingEnabled
                else {
                    return
                }
                await owner.delegate?.audioSessionDidReceiveCommand(.seek(to: position))
            }
            return .success
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
        for token in interruptionObservationTokens {
            notificationCenter.removeObserver(token)
        }
        notificationCenter.removeObserver(self)
    }
}
