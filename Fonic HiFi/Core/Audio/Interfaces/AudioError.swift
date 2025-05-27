//
//  AudioError.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Errors that can occur during audio operations
public enum AudioError: LocalizedError, Sendable {
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
    case networkError(Error)
    
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
        case .unsupportedFormat(let format):
            return "The audio format '\(format)' is not supported"
            
        case .fileNotFound(let url):
            return "Audio file not found at: \(url.lastPathComponent)"
            
        case .decodingFailed(let reason):
            return "Failed to decode audio: \(reason)"
            
        case .engineInitializationFailed(let reason):
            return "Failed to initialize audio engine: \(reason)"
            
        case .playbackFailed(let reason):
            return "Playback failed: \(reason)"
            
        case .sessionConfigurationFailed(let reason):
            return "Failed to configure audio session: \(reason)"
            
        case .cancelled:
            return "Operation was cancelled"
            
        case .networkError(let error):
            return "Network error: \(error.localizedDescription)"
            
        case .permissionDenied(let url):
            return "Permission denied to access: \(url.lastPathComponent)"
            
        case .deviceError(let reason):
            return "Audio device error: \(reason)"
            
        case .queueEmpty:
            return "The playback queue is empty"
            
        case .invalidSeekPosition(let position):
            return "Invalid seek position: \(position)"
            
        case .bitPerfectNotPossible(let reason):
            return "Bit-perfect playback not possible: \(reason.rawValue)"
        }
    }
    
    public var failureReason: String? {
        return errorDescription
    }
    
    public var recoverySuggestion: String? {
        switch self {
        case .unsupportedFormat:
            return "Try converting the file to a supported format like FLAC or ALAC"
            
        case .fileNotFound:
            return "Check if the file exists and hasn't been moved or deleted"
            
        case .permissionDenied:
            return "Grant Fonic HiFi permission to access your music files"
            
        case .deviceError:
            return "Try selecting a different audio output device"
            
        case .queueEmpty:
            return "Add tracks to the queue before attempting playback"
            
        case .bitPerfectNotPossible(let reason):
            switch reason {
            case .sampleRateMismatch:
                return "Select an audio device that supports the file's sample rate"
            case .volumeNotUnity:
                return "Set volume to 100% for bit-perfect playback"
            case .equalizerActive:
                return "Disable the equalizer for bit-perfect playback"
            default:
                return "Adjust settings to enable bit-perfect playback"
            }
            
        default:
            return nil
        }
    }
}