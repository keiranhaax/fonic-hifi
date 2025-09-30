//
//  AudioError.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Errors that can occur during audio operations
public enum AudioError: LocalizedError, Sendable, Equatable {
    /// The audio format is not supported
    case unsupportedFormat(String)

    /// The requested file was not found
    case fileNotFound(URL)

    /// Failed to decode the audio file
    case decodingFailed(reason: String)

    /// Failed to initialize the audio engine
    case engineInitializationFailed(reason: String)

    /// Playback failed for a specific reason
    case playbackFailed(reason: String)

    /// Failed to configure audio session
    case sessionConfigurationFailed(reason: String)

    /// The operation was cancelled
    case cancelled

    /// Network error (for future streaming support)
    case networkError(String)

    /// Insufficient permissions to access file
    case permissionDenied(URL)

    /// Audio device error
    case deviceError(reason: String)

    /// Queue is empty
    case queueEmpty

    /// Invalid seek position
    case invalidSeekPosition(TimeInterval)

    /// Bit-perfect playback cannot be achieved
    case bitPerfectNotPossible(BitPerfectFailureReason)

    // MARK: - LocalizedError

    public var errorDescription: String? {
        switch self {
        case let .unsupportedFormat(format):
            "The audio format '\(format)' is not supported"

        case let .fileNotFound(url):
            "Audio file not found at: \(url.lastPathComponent)"

        case let .decodingFailed(reason):
            "Failed to decode audio: \(reason)"

        case let .engineInitializationFailed(reason):
            "Failed to initialize audio engine: \(reason)"

        case let .playbackFailed(reason):
            "Playback failed: \(reason)"

        case let .sessionConfigurationFailed(reason):
            "Failed to configure audio session: \(reason)"

        case .cancelled:
            "Operation was cancelled"

        case let .networkError(error):
            "Network error: \(error)"

        case let .permissionDenied(url):
            "Permission denied to access: \(url.lastPathComponent)"

        case let .deviceError(reason):
            "Audio device error: \(reason)"

        case .queueEmpty:
            "The playback queue is empty"

        case let .invalidSeekPosition(position):
            "Invalid seek position: \(position)"

        case let .bitPerfectNotPossible(reason):
            "Bit-perfect playback not possible: \(reason.description)"
        }
    }

    public var failureReason: String? {
        errorDescription
    }

    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedFormat:
            "Try converting the file to a supported format like FLAC or ALAC"

        case .fileNotFound:
            "Check if the file exists and hasn't been moved or deleted"

        case .permissionDenied:
            "Grant Fonic HiFi permission to access your music files"

        case .deviceError:
            "Try selecting a different audio output device"

        case .queueEmpty:
            "Add tracks to the queue before attempting playback"

        case let .bitPerfectNotPossible(reason):
            switch reason {
            case .sampleRateMismatch:
                "Select an audio device that supports the file's sample rate"
            case .volumeNotUnity:
                "Set volume to 100% for bit-perfect playback"
            case .audioProcessingEnabled:
                "Disable the equalizer for bit-perfect playback"
            default:
                "Adjust settings to enable bit-perfect playback"
            }

        default:
            nil
        }
    }
}
