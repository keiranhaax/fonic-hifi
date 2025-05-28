//
//  Track.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//  Updated by Claude on 5/28/25.
//

import Foundation

/// Track interface for audio engine compatibility
/// This provides a compatible interface for the existing audio engine code
/// while the full SwiftData Track model is defined in Data/Models/Track.swift
public protocol TrackProtocol: Identifiable {
    var id: UUID { get }
    var title: String { get }
    var artist: String { get }
    var album: String { get }
    var url: URL { get }
    var duration: TimeInterval { get }
    var audioFormat: String { get }
}

/// Legacy Track struct for backward compatibility
/// Use the SwiftData Track model for new code
public struct LegacyTrack: TrackProtocol, Codable, Sendable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let album: String
    public let url: URL
    public let duration: TimeInterval
    public let audioFormat: String
    
    /// Legacy format property for existing code
    public var format: AudioFormat {
        return AudioFormat(rawValue: audioFormat) ?? .unknown
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        url: URL,
        duration: TimeInterval,
        format: AudioFormat
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.url = url
        self.duration = duration
        self.audioFormat = format.rawValue
    }
    
    public init(
        id: UUID = UUID(),
        title: String,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        url: URL,
        duration: TimeInterval,
        audioFormat: String
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.url = url
        self.duration = duration
        self.audioFormat = audioFormat
    }
}

/// Convenience typealias for existing code
public typealias AudioTrack = LegacyTrack