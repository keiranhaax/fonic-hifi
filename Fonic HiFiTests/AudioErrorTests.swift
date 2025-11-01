import Foundation
@testable import Fonic_HiFi
import XCTest

final class AudioErrorTests: XCTestCase {
    func testErrorDescriptionsMatchExpectedMessages() {
        let url = URL(fileURLWithPath: "/Music/track.flac")
        let cases: [(AudioError, String)] = [
            (.unsupportedFormat("WMA"), "The audio format 'WMA' is not supported"),
            (.fileNotFound(url), "Audio file not found at: track.flac"),
            (.decodingFailed(reason: "Codec missing"), "Failed to decode audio: Codec missing"),
            (.engineInitializationFailed(reason: "Graph error"), "Failed to initialize audio engine: Graph error"),
            (.playbackFailed(reason: "Output stalled"), "Playback failed: Output stalled"),
            (.sessionConfigurationFailed(reason: "Category mismatch"), "Failed to configure audio session: Category mismatch"),
            (.permissionDenied(url), "Permission denied to access: track.flac"),
            (.deviceError(reason: "No output route"), "Audio device error: No output route"),
            (.queueEmpty, "The playback queue is empty"),
            (.invalidSeekPosition(12), "Invalid seek position: 12.0"),
        ]

        for (error, expected) in cases {
            XCTAssertEqual(error.errorDescription, expected)
            XCTAssertEqual(error.failureReason, expected)
        }
    }

    func testRecoverySuggestionsCoverKeyScenarios() {
        let permissionURL = URL(fileURLWithPath: "/Music/locked.flac")
        XCTAssertEqual(
            AudioError.permissionDenied(permissionURL).recoverySuggestion,
            "Grant Fonic HiFi permission to access your music files"
        )

        XCTAssertEqual(
            AudioError.queueEmpty.recoverySuggestion,
            "Add tracks to the queue before attempting playback"
        )

        XCTAssertEqual(
            AudioError.bitPerfectNotPossible(.sampleRateMismatch(source: 96000, output: 48000)).recoverySuggestion,
            "Select an audio device that supports the file's sample rate"
        )

        XCTAssertEqual(
            AudioError.bitPerfectNotPossible(.volumeNotUnity(currentVolume: 0.5)).recoverySuggestion,
            "Set volume to 100% for bit-perfect playback"
        )

        XCTAssertEqual(
            AudioError.bitPerfectNotPossible(.audioProcessingEnabled(effects: ["EQ"])).recoverySuggestion,
            "Disable the equalizer for bit-perfect playback"
        )

        XCTAssertEqual(
            AudioError.bitPerfectNotPossible(.hardwareNotSupported).recoverySuggestion,
            "Adjust settings to enable bit-perfect playback"
        )
    }

    func testBitPerfectFailureDescriptionsEmbedDetails() {
        let reason = BitPerfectFailureReason.deviceSampleRateNotSupported(required: 192000, supported: [44100, 96000])
        let error = AudioError.bitPerfectNotPossible(reason)

        XCTAssertEqual(reason.description, reason.userFriendlyDescription)
        XCTAssertTrue(reason.description.contains("Device doesn't support"))
        XCTAssertTrue(reason.description.contains("Supported:"))
        XCTAssertTrue((error.errorDescription ?? "").contains("Bit-perfect playback"))
    }
}
