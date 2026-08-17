//
//  LibraryEntities.swift
//  Fonic HiFi
//
//  Created by Codex on 3/6/26.
//
//  Domain representations for library content. These mirror the SwiftData
//  models but remain transport-friendly and Sendable so that repositories can
//  operate safely off the main actor.
//

import Foundation

public struct TrackEntity: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let album: String
    public let albumArtist: String?
    public let duration: TimeInterval
    public let trackNumber: Int?
    public let discNumber: Int?
    public let genre: String?
    public let year: Int?
    public let audioFormat: String
    public let artworkSha: String?
    public let fileURL: URL
    public let fileSize: Int64
    public let bitDepth: Int
    public let sampleRate: Double
    public let channels: Int
    public let bitrate: Int?
    public let isLossless: Bool
    public let dateAdded: Date
    /// ReplayGain values travel with the transport entity so playback does not
    /// silently reset gain when a SwiftData row is projected into the queue.
    public let replayGainTrack: Float?
    public let replayGainAlbum: Float?
    /// A transport-level availability bit; the persisted miss counters remain
    /// owned by SwiftData and are not exposed as a second source of truth.
    public let isAvailable: Bool
    public let isFavorite: Bool

    public init(
        id: UUID,
        title: String,
        artist: String,
        album: String,
        albumArtist: String?,
        duration: TimeInterval,
        trackNumber: Int?,
        discNumber: Int?,
        genre: String?,
        year: Int?,
        audioFormat: String,
        artworkSha: String?,
        fileURL: URL,
        fileSize: Int64,
        bitDepth: Int,
        sampleRate: Double,
        channels: Int,
        bitrate: Int?,
        isLossless: Bool,
        dateAdded: Date,
        replayGainTrack: Float? = nil,
        replayGainAlbum: Float? = nil,
        isAvailable: Bool = true,
        isFavorite: Bool = false,
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.duration = duration
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.genre = genre
        self.year = year
        self.audioFormat = audioFormat
        self.artworkSha = artworkSha
        self.fileURL = fileURL
        self.fileSize = fileSize
        self.bitDepth = bitDepth
        self.sampleRate = sampleRate
        self.channels = channels
        self.bitrate = bitrate
        self.isLossless = isLossless
        self.dateAdded = dateAdded
        self.replayGainTrack = replayGainTrack
        self.replayGainAlbum = replayGainAlbum
        self.isAvailable = isAvailable
        self.isFavorite = isFavorite
    }
}

public extension TrackEntity {
    var formattedDuration: String {
        let safeDuration = duration.isFinite ? max(0, duration) : 0
        let wholeSeconds = Int(safeDuration)
        let minutes = wholeSeconds / 60
        let seconds = wholeSeconds % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    var formattedFileSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: fileSize)
    }

    var qualityDescription: String {
        if isLossless {
            if sampleRate > 48000 || bitDepth > 16 {
                return "Hi-Res Lossless"
            }
            return "Lossless"
        }
        return "Lossy"
    }

    func asTrackRepresentation(artwork: Data? = nil) -> Track {
        let track = Track(
            id: id,
            url: fileURL,
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
        track.trackNumber = trackNumber
        track.discNumber = discNumber
        track.genre = genre
        track.year = year
        track.fileSize = fileSize
        track.bitrate = bitrate
        track.albumArtist = albumArtist
        track.replayGainTrack = replayGainTrack
        track.replayGainAlbum = replayGainAlbum
        track.isFavorite = isFavorite
        if !isAvailable {
            track.unavailableCheckCount = 1
            track.unavailableSince = track.dateAdded
            track.availabilityLastCheckedAt = track.dateAdded
        }
        track.artwork = artwork
        return track
    }

    init(track: Track) {
        self.init(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            albumArtist: track.albumArtist,
            duration: track.duration,
            trackNumber: track.trackNumber,
            discNumber: track.discNumber,
            genre: track.genre,
            year: track.year,
            audioFormat: track.audioFormat,
            artworkSha: nil,
            fileURL: track.url,
            fileSize: track.fileSize,
            bitDepth: track.bitDepth,
            sampleRate: track.sampleRate,
            channels: track.channels,
            bitrate: track.bitrate,
            isLossless: track.isLossless,
            dateAdded: track.dateAdded,
            replayGainTrack: track.replayGainTrack,
            replayGainAlbum: track.replayGainAlbum,
            isAvailable: track.fileAvailability.isAvailable,
            isFavorite: track.isFavorite,
        )
    }
}

public struct AlbumEntity: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let title: String
    public let albumArtist: String
    public let trackCount: Int
    public let artworkSha: String?
    public let year: Int?
    public let dateAdded: Date

    public init(
        id: UUID,
        title: String,
        albumArtist: String,
        trackCount: Int,
        artworkSha: String?,
        year: Int?,
        dateAdded: Date,
    ) {
        self.id = id
        self.title = title
        self.albumArtist = albumArtist
        self.trackCount = trackCount
        self.artworkSha = artworkSha
        self.year = year
        self.dateAdded = dateAdded
    }
}

public struct ArtistEntity: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let sortName: String
    public let albumCount: Int
    public let trackCount: Int

    public init(
        id: UUID,
        name: String,
        sortName: String,
        albumCount: Int,
        trackCount: Int,
    ) {
        self.id = id
        self.name = name
        self.sortName = sortName
        self.albumCount = albumCount
        self.trackCount = trackCount
    }
}

public struct PlaylistEntity: Identifiable, Hashable, Sendable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let trackCount: Int

    public init(
        id: UUID,
        name: String,
        description: String?,
        trackCount: Int,
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.trackCount = trackCount
    }
}

public extension PlaylistEntity {
    init(playlist: Playlist) {
        self.init(
            id: playlist.id,
            name: playlist.name,
            description: playlist.playlistDescription,
            trackCount: playlist.trackIds.count,
        )
    }
}
