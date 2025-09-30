//
//  TrackDataActor.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import OSLog
import SwiftData

/// ModelActor for handling Track data operations in a concurrency-safe manner
@ModelActor
public actor TrackDataActor {
    private let logger = Logger(subsystem: "com.fonichifi.data", category: "TrackDataActor")

    // MARK: - Track Creation

    /// Create a new Track from extracted metadata
    /// - Parameter metadata: Sendable metadata extracted from audio file
    /// - Returns: PersistentIdentifier of the created Track
    /// - Throws: TrackDataError if creation fails
    public func createTrack(from metadata: TrackMetadata) throws -> PersistentIdentifier {
        logger.info("Creating track: \(metadata.title)")

        let track = Track(
            url: metadata.url,
            title: metadata.title,
            artist: metadata.artist,
            album: metadata.album,
            audioFormat: metadata.audioFormat,
            duration: metadata.duration,
            sampleRate: metadata.sampleRate,
            bitDepth: metadata.bitDepth,
            channels: metadata.channels,
            isLossless: metadata.isLossless,
        )

        // Set additional metadata properties
        track.albumArtist = metadata.albumArtist
        track.genre = metadata.genre
        track.year = metadata.year
        track.trackNumber = metadata.trackNumber
        track.discNumber = metadata.discNumber
        track.composer = metadata.composer
        track.conductor = metadata.conductor
        track.comments = metadata.comment
        track.lyrics = metadata.lyrics
        track.artwork = metadata.artwork
        track.bitrate = metadata.bitrate

        modelContext.insert(track)

        do {
            try modelContext.save()
            logger.info("Successfully created track: \(track.id)")
            return track.persistentModelID
        } catch {
            logger.error("Failed to save track: \(error.localizedDescription)")
            throw TrackDataError.saveFailed(error)
        }
    }

    /// Create multiple tracks from metadata array
    /// - Parameter metadataArray: Array of TrackMetadata
    /// - Returns: Array of PersistentIdentifiers for created tracks
    /// - Throws: TrackDataError if any creation fails
    public func createTracks(from metadataArray: [TrackMetadata]) throws -> [PersistentIdentifier] {
        logger.info("Creating \(metadataArray.count) tracks")

        var identifiers: [PersistentIdentifier] = []

        for metadata in metadataArray {
            let track = Track(
                url: metadata.url,
                title: metadata.title,
                artist: metadata.artist,
                album: metadata.album,
                audioFormat: metadata.audioFormat,
                duration: metadata.duration,
                sampleRate: metadata.sampleRate,
                bitDepth: metadata.bitDepth,
                channels: metadata.channels,
                isLossless: metadata.isLossless,
            )

            // Set additional metadata properties
            track.albumArtist = metadata.albumArtist
            track.genre = metadata.genre
            track.year = metadata.year
            track.trackNumber = metadata.trackNumber
            track.discNumber = metadata.discNumber
            track.composer = metadata.composer
            track.conductor = metadata.conductor
            track.comments = metadata.comment
            track.lyrics = metadata.lyrics
            track.artwork = metadata.artwork
            track.bitrate = metadata.bitrate

            modelContext.insert(track)
            identifiers.append(track.persistentModelID)
        }

        do {
            try modelContext.save()
            logger.info("Successfully created \(identifiers.count) tracks")
            return identifiers
        } catch {
            logger.error("Failed to save tracks: \(error.localizedDescription)")
            throw TrackDataError.batchSaveFailed(error)
        }
    }

    // MARK: - Track Queries

    /// Check if a track exists for the given URL
    /// - Parameter url: File URL to check
    /// - Returns: PersistentIdentifier if track exists, nil otherwise
    public func trackExists(for url: URL) throws -> PersistentIdentifier? {
        let fetchDescriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.url == url
            },
        )

        do {
            let tracks = try modelContext.fetch(fetchDescriptor)
            return tracks.first?.persistentModelID
        } catch {
            logger.error("Failed to check track existence: \(error.localizedDescription)")
            throw TrackDataError.fetchFailed(error)
        }
    }

    /// Get track metadata by persistent identifier
    /// - Parameter id: PersistentIdentifier of the track
    /// - Returns: TrackMetadata if found
    /// - Throws: TrackDataError if not found or fetch fails
    public func getTrackMetadata(for id: PersistentIdentifier) throws -> TrackMetadata {
        guard let track: Track = modelContext.registeredModel(for: id) else {
            throw TrackDataError.trackNotFound(id)
        }

        return TrackMetadata(
            url: track.url,
            title: track.title,
            artist: track.artist,
            album: track.album,
            albumArtist: track.albumArtist,
            genre: track.genre,
            year: track.year,
            trackNumber: track.trackNumber,
            discNumber: track.discNumber,
            composer: track.composer,
            conductor: track.conductor,
            audioFormat: track.audioFormat,
            duration: track.duration,
            sampleRate: track.sampleRate,
            bitDepth: track.bitDepth,
            bitrate: track.bitrate,
            channels: track.channels,
            isLossless: track.isLossless,
            artwork: track.artwork,
            lyrics: track.lyrics,
            comment: track.comments,
        )
    }

    /// Get all tracks count
    /// - Returns: Total number of tracks in the library
    public func getTracksCount() throws -> Int {
        let fetchDescriptor = FetchDescriptor<Track>()

        do {
            let tracks = try modelContext.fetch(fetchDescriptor)
            return tracks.count
        } catch {
            logger.error("Failed to get tracks count: \(error.localizedDescription)")
            throw TrackDataError.fetchFailed(error)
        }
    }

    /// Delete a specific track by identifier
    /// - Parameter id: PersistentIdentifier of the track to delete
    /// - Throws: TrackDataError if deletion fails
    public func deleteTrack(_ id: PersistentIdentifier) throws {
        guard let track: Track = modelContext.registeredModel(for: id) else {
            throw TrackDataError.trackNotFound(id)
        }

        modelContext.delete(track)

        do {
            try modelContext.save()
            logger.info("Successfully deleted track: \(track.id)")
        } catch {
            logger.error("Failed to delete track: \(error.localizedDescription)")
            throw TrackDataError.deleteFailed(error)
        }
    }

    /// Remove tracks that have missing files
    /// - Returns: Number of tracks removed
    public func cleanupMissingFiles() throws -> Int {
        let fetchDescriptor = FetchDescriptor<Track>()

        do {
            let tracks = try modelContext.fetch(fetchDescriptor)
            var removedCount = 0

            for track in tracks {
                if !FileManager.default.fileExists(atPath: track.url.path) {
                    modelContext.delete(track)
                    removedCount += 1
                }
            }

            if removedCount > 0 {
                try modelContext.save()
                logger.info("Cleaned up \(removedCount) missing files")
            }

            return removedCount
        } catch {
            logger.error("Failed to cleanup missing files: \(error.localizedDescription)")
            throw TrackDataError.cleanupFailed(error)
        }
    }

    // MARK: - Track Updates

    /// Update track playback statistics
    /// - Parameters:
    ///   - id: PersistentIdentifier of the track
    ///   - playCount: New play count
    ///   - lastPlayed: Last played date
    public func updatePlaybackStats(for id: PersistentIdentifier, playCount: Int, lastPlayed: Date) throws {
        guard let track: Track = modelContext.registeredModel(for: id) else {
            throw TrackDataError.trackNotFound(id)
        }

        track.playCount = playCount
        track.lastPlayed = lastPlayed

        do {
            try modelContext.save()
            logger.debug("Updated playback stats for track: \(track.title)")
        } catch {
            logger.error("Failed to update playback stats: \(error.localizedDescription)")
            throw TrackDataError.updateFailed(error)
        }
    }

    /// Update track user data
    /// - Parameters:
    ///   - id: PersistentIdentifier of the track
    ///   - rating: User rating (1-5)
    ///   - isFavorite: Favorite status
    ///   - userTags: User-defined tags
    public func updateUserData(for id: PersistentIdentifier, rating: Int?, isFavorite: Bool, userTags: [String]) throws {
        guard let track: Track = modelContext.registeredModel(for: id) else {
            throw TrackDataError.trackNotFound(id)
        }

        track.rating = rating
        track.isFavorite = isFavorite
        track.userTags = userTags

        do {
            try modelContext.save()
            logger.debug("Updated user data for track: \(track.title)")
        } catch {
            logger.error("Failed to update user data: \(error.localizedDescription)")
            throw TrackDataError.updateFailed(error)
        }
    }
}

// MARK: - Supporting Types

/// Sendable metadata struct for track information
public struct TrackMetadata: Sendable {
    public let url: URL
    public let title: String
    public let artist: String
    public let album: String
    public let albumArtist: String?
    public let genre: String?
    public let year: Int?
    public let trackNumber: Int?
    public let discNumber: Int?
    public let composer: String?
    public let conductor: String?
    public let audioFormat: String
    public let duration: TimeInterval
    public let sampleRate: Double
    public let bitDepth: Int
    public let bitrate: Int?
    public let channels: Int
    public let isLossless: Bool
    public let artwork: Data?
    public let lyrics: String?
    public let comment: String?

    public init(
        url: URL,
        title: String,
        artist: String,
        album: String,
        albumArtist: String? = nil,
        genre: String? = nil,
        year: Int? = nil,
        trackNumber: Int? = nil,
        discNumber: Int? = nil,
        composer: String? = nil,
        conductor: String? = nil,
        audioFormat: String,
        duration: TimeInterval,
        sampleRate: Double,
        bitDepth: Int,
        bitrate: Int? = nil,
        channels: Int,
        isLossless: Bool,
        artwork: Data? = nil,
        lyrics: String? = nil,
        comment: String? = nil,
    ) {
        self.url = url
        self.title = title
        self.artist = artist
        self.album = album
        self.albumArtist = albumArtist
        self.genre = genre
        self.year = year
        self.trackNumber = trackNumber
        self.discNumber = discNumber
        self.composer = composer
        self.conductor = conductor
        self.audioFormat = audioFormat
        self.duration = duration
        self.sampleRate = sampleRate
        self.bitDepth = bitDepth
        self.bitrate = bitrate
        self.channels = channels
        self.isLossless = isLossless
        self.artwork = artwork
        self.lyrics = lyrics
        self.comment = comment
    }
}

/// Errors that can occur during Track data operations
public enum TrackDataError: Error, LocalizedError {
    case trackNotFound(PersistentIdentifier)
    case saveFailed(Error)
    case batchSaveFailed(Error)
    case fetchFailed(Error)
    case updateFailed(Error)
    case cleanupFailed(Error)
    case deleteFailed(Error)

    public var errorDescription: String? {
        switch self {
        case let .trackNotFound(id):
            "Track not found with ID: \(id)"
        case let .saveFailed(error):
            "Failed to save track: \(error.localizedDescription)"
        case let .batchSaveFailed(error):
            "Failed to save multiple tracks: \(error.localizedDescription)"
        case let .fetchFailed(error):
            "Failed to fetch tracks: \(error.localizedDescription)"
        case let .updateFailed(error):
            "Failed to update track: \(error.localizedDescription)"
        case let .cleanupFailed(error):
            "Failed to cleanup tracks: \(error.localizedDescription)"
        case let .deleteFailed(error):
            "Failed to delete track: \(error.localizedDescription)"
        }
    }
}
