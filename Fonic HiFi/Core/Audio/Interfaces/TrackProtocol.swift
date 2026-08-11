//
//  TrackProtocol.swift
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
    var replayGainTrack: Float? { get set }
    var replayGainAlbum: Float? { get set }
    var isFavorite: Bool { get }
    var isAvailable: Bool { get }
}

public extension TrackProtocol {
    var isFavorite: Bool { false }
    var isAvailable: Bool { true }
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
    public var replayGainTrack: Float?
    public var replayGainAlbum: Float?
    public var isFavorite: Bool
    public var isAvailable: Bool

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case artist
        case album
        case url
        case duration
        case audioFormat
        case replayGainTrack
        case replayGainAlbum
        case isFavorite
        case isAvailable
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        artist = try container.decode(String.self, forKey: .artist)
        album = try container.decode(String.self, forKey: .album)
        url = try container.decode(URL.self, forKey: .url)
        duration = try container.decode(TimeInterval.self, forKey: .duration)
        audioFormat = try container.decode(String.self, forKey: .audioFormat)
        replayGainTrack = try container.decodeIfPresent(Float.self, forKey: .replayGainTrack)
        replayGainAlbum = try container.decodeIfPresent(Float.self, forKey: .replayGainAlbum)
        isFavorite = try container.decodeIfPresent(Bool.self, forKey: .isFavorite) ?? false
        isAvailable = try container.decodeIfPresent(Bool.self, forKey: .isAvailable) ?? true
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(artist, forKey: .artist)
        try container.encode(album, forKey: .album)
        try container.encode(url, forKey: .url)
        try container.encode(duration, forKey: .duration)
        try container.encode(audioFormat, forKey: .audioFormat)
        try container.encodeIfPresent(replayGainTrack, forKey: .replayGainTrack)
        try container.encodeIfPresent(replayGainAlbum, forKey: .replayGainAlbum)
        try container.encode(isFavorite, forKey: .isFavorite)
        try container.encode(isAvailable, forKey: .isAvailable)
    }

    /// Legacy format property for existing code
    public var format: AudioFormat {
        AudioFormat(rawValue: audioFormat) ?? .unknown
    }

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        url: URL,
        duration: TimeInterval,
        format: AudioFormat,
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.url = url
        self.duration = duration
        audioFormat = format.rawValue
        replayGainTrack = nil
        replayGainAlbum = nil
        isFavorite = false
        isAvailable = true
    }

    public init(
        id: UUID = UUID(),
        title: String,
        artist: String = "Unknown Artist",
        album: String = "Unknown Album",
        url: URL,
        duration: TimeInterval,
        audioFormat: String,
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.url = url
        self.duration = duration
        self.audioFormat = audioFormat
        replayGainTrack = nil
        replayGainAlbum = nil
        isFavorite = false
        isAvailable = true
    }
}

/// Convenience typealias for existing code
public typealias AudioTrack = LegacyTrack
