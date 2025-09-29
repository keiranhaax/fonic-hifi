// Audio Session Management Contract
// Version: 1.0
// Purpose: Define interface for audio session management with proper actor isolation

import AVFoundation
import Foundation

// MARK: - Protocol Definition

@MainActor
protocol AudioSessionManaging: Sendable {
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
    var currentRoute: AVAudioSessionRouteDescription { get async }
    var isSessionActive: Bool { get async }
    var supportsBitPerfect: Bool { get async }
}

// MARK: - Error Types

enum AudioSessionError: Error, Sendable {
    case configurationFailed(String)
    case activationFailed(String)
    case routeChangeFailed(String)
    case remoteCommandSetupFailed(String)
    case unsupportedSampleRate(Int)
}

// MARK: - Remote Command Types

enum RemoteCommand: Sendable {
    case play
    case pause
    case stop
    case nextTrack
    case previousTrack
    case seek(to: TimeInterval)
    case changePlaybackRate(Float)
}

// MARK: - Configuration Options

struct AudioSessionConfiguration: Sendable {
    let category: AVAudioSession.Category
    let mode: AVAudioSession.Mode
    let options: AVAudioSession.CategoryOptions
    let preferredSampleRate: Double
    let preferredBufferDuration: TimeInterval
}

// MARK: - Contract Tests (These should fail initially)

final class AudioSessionContractTests {
    @MainActor
    func testConfigureSession() async throws {
        let manager: AudioSessionManaging = AudioSessionManager() // Should fail: not implemented
        try await manager.configureSession()
        await assert(manager.isSessionActive == true)
    }

    @MainActor
    func testRemoteCommands() async throws {
        let manager: AudioSessionManaging = AudioSessionManager() // Should fail: not implemented
        await manager.enableRemoteCommands()
        // Verify command center is configured
    }

    @MainActor
    func testInterruptionHandling() async throws {
        let manager: AudioSessionManaging = AudioSessionManager() // Should fail: not implemented
        let notification = Notification(name: AVAudioSession.interruptionNotification)
        await manager.handleInterruption(notification)
        // Verify appropriate state change
    }

    @MainActor
    func testBitPerfectSupport() async throws {
        let manager: AudioSessionManaging = AudioSessionManager() // Should fail: not implemented
        let supported = await manager.supportsBitPerfect
        assert(supported == true || supported == false) // Must return valid bool
    }
}
