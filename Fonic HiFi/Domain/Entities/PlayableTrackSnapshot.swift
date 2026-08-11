//
//  PlayableTrackSnapshot.swift
//  Fonic HiFi
//
//  Sendable playback currency shared by queue, controller, and facade
//  boundaries. SwiftData models stay inside their owning actor; only this
//  immutable value crosses into playback orchestration.
//

import Foundation

/// Immutable, Sendable playback representation.
///
/// `Track` is a SwiftData model and must not be detached from its model
/// context. This snapshot carries the durable identity, resolved media URL,
/// playback parameters, and the presentation metadata required by the audio
/// and Now Playing layers without retaining the model itself.
public struct PlayableTrackSnapshot: Sendable, Equatable, Identifiable {
    public let id: UUID
    public let resolvedURL: URL
    public let replayGainTrack: Double?
    public let replayGainAlbum: Double?
    public let isAvailable: Bool
    public let isFavorite: Bool

    public let title: String
    public let artist: String
    public let album: String
    public let audioFormat: String
    public let duration: TimeInterval
    public let sampleRate: Double
    public let bitDepth: Int
    public let channels: Int
    public let isLossless: Bool

    public init(
        id: UUID,
        resolvedURL: URL,
        replayGainTrack: Double? = nil,
        replayGainAlbum: Double? = nil,
        isAvailable: Bool = true,
        isFavorite: Bool = false,
        title: String,
        artist: String,
        album: String,
        audioFormat: String,
        duration: TimeInterval,
        sampleRate: Double = 44_100,
        bitDepth: Int = 16,
        channels: Int = 2,
        isLossless: Bool = false,
    ) {
        self.id = id
        self.resolvedURL = resolvedURL
        self.replayGainTrack = replayGainTrack
        self.replayGainAlbum = replayGainAlbum
        self.isAvailable = isAvailable
        self.isFavorite = isFavorite
        self.title = title
        self.artist = artist
        self.album = album
        self.audioFormat = audioFormat
        self.duration = duration
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.channels = channels
        self.isLossless = isLossless
    }

    /// Captures all playback-relevant values before a model leaves its owner.
    public init(track: Track) {
        self.init(
            id: track.id,
            resolvedURL: track.url,
            replayGainTrack: track.replayGainTrack.map(Double.init),
            replayGainAlbum: track.replayGainAlbum.map(Double.init),
            isAvailable: track.isAvailable,
            isFavorite: track.isFavorite,
            title: track.title,
            artist: track.artist,
            album: track.album,
            audioFormat: track.audioFormat,
            duration: track.duration,
            sampleRate: track.sampleRate,
            bitDepth: track.bitDepth,
            channels: track.channels,
            isLossless: track.isLossless,
        )
    }

    /// Combines presentation metadata with the queue entry's durable identity
    /// and resolved URL when both are available.
    public init(track: Track, queueEntry: AudioTrack) {
        self.init(
            id: queueEntry.id,
            resolvedURL: queueEntry.url,
            replayGainTrack: queueEntry.replayGainTrack.map(Double.init)
                ?? track.replayGainTrack.map(Double.init),
            replayGainAlbum: queueEntry.replayGainAlbum.map(Double.init)
                ?? track.replayGainAlbum.map(Double.init),
            isAvailable: track.isAvailable,
            isFavorite: track.isFavorite,
            title: track.title,
            artist: track.artist,
            album: track.album,
            audioFormat: track.audioFormat,
            duration: track.duration,
            sampleRate: track.sampleRate,
            bitDepth: track.bitDepth,
            channels: track.channels,
            isLossless: track.isLossless,
        )
    }

    /// Captures the queue's legacy value type without minting another UUID.
    public init(audioTrack: AudioTrack) {
        self.init(
            id: audioTrack.id,
            resolvedURL: audioTrack.url,
            replayGainTrack: audioTrack.replayGainTrack.map(Double.init),
            replayGainAlbum: audioTrack.replayGainAlbum.map(Double.init),
            isAvailable: audioTrack.isAvailable,
            isFavorite: audioTrack.isFavorite,
            title: audioTrack.title,
            artist: audioTrack.artist,
            album: audioTrack.album,
            audioFormat: audioTrack.audioFormat,
            duration: audioTrack.duration,
        )
    }

    public var audioTrack: AudioTrack {
        var track = LegacyTrack(
            id: id,
            title: title,
            artist: artist,
            album: album,
            url: resolvedURL,
            duration: duration,
            audioFormat: audioFormat,
        )
        track.replayGainTrack = replayGainTrack.map(Float.init)
        track.replayGainAlbum = replayGainAlbum.map(Float.init)
        track.isFavorite = isFavorite
        track.isAvailable = isAvailable
        return track
    }

    /// Creates the presentation model at the MainActor/UI boundary. The
    /// SwiftData model never crosses the snapshot boundary itself.
    @MainActor
    public func makeDisplayTrack() -> Track {
        let track = Track(
            id: id,
            url: resolvedURL,
            title: title,
            artist: artist,
            album: album,
            audioFormat: audioFormat,
            duration: duration,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channels: channels,
            isLossless: isLossless,
        )
        track.replayGainTrack = replayGainTrack.map(Float.init)
        track.replayGainAlbum = replayGainAlbum.map(Float.init)
        if !isAvailable {
            track.unavailableCheckCount = 1
            track.unavailableSince = track.dateAdded
            track.availabilityLastCheckedAt = track.dateAdded
        }
        track.isFavorite = isFavorite
        return track
    }
}
