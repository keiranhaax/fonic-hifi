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
    private let logger = Log.logger(.dataTrackActor)

    // MARK: - Helpers

    private func resolveTrack(with id: PersistentIdentifier) throws -> Track {
        if let registered: Track = modelContext.registeredModel(for: id) {
            return registered
        }

        var descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.persistentModelID == id
            }
        )
        descriptor.fetchLimit = 1

        let fetched: [Track]
        do {
            fetched = try modelContext.fetch(descriptor)
        } catch {
            throw TrackDataError.fetchFailed(error)
        }

        guard let track = fetched.first else {
            throw TrackDataError.trackNotFound(id)
        }

        return track
    }

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
        track.sourceURLBookmark = metadata.sourceBookmark
        track.sourceURLString = metadata.sourceURL?.absoluteString
        track.sourceURLHash = metadata.sourceURLHash ?? metadata.sourceURL?.librarySourceHash()
        track.sourceBookmarkHash = metadata.sourceBookmarkHash
        if track.sourceURLHash == nil, let source = metadata.sourceURL {
            track.sourceURLHash = source.librarySourceHash()
        }
        if track.sourceBookmarkHash == nil, let bookmark = metadata.sourceBookmark {
            track.sourceBookmarkHash = bookmark.sha256Hex()
        }

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
            track.sourceURLBookmark = metadata.sourceBookmark
            track.sourceURLString = metadata.sourceURL?.absoluteString
            track.sourceURLHash = metadata.sourceURLHash ?? metadata.sourceURL?.librarySourceHash()
            track.sourceBookmarkHash = metadata.sourceBookmarkHash
            if track.sourceURLHash == nil, let source = metadata.sourceURL {
                track.sourceURLHash = source.librarySourceHash()
            }
            if track.sourceBookmarkHash == nil, let bookmark = metadata.sourceBookmark {
                track.sourceBookmarkHash = bookmark.sha256Hex()
            }

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
    public func trackExists(for url: URL, bookmark: Data? = nil) throws -> PersistentIdentifier? {
        let normalizedHash = url.librarySourceHash()
        let absoluteSource = url.absoluteString
        let bookmarkHash = bookmark?.sha256Hex()

        let predicate: Predicate<Track>
        if let bookmarkHash {
            predicate = #Predicate<Track> { track in
                track.sourceBookmarkHash == bookmarkHash ||
                    track.sourceURLHash == normalizedHash ||
                    track.sourceURLString == absoluteSource ||
                    track.url == url
            }
        } else {
            predicate = #Predicate<Track> { track in
                track.sourceURLHash == normalizedHash ||
                    track.sourceURLString == absoluteSource ||
                    track.url == url
            }
        }

        let fetchDescriptor = FetchDescriptor<Track>(predicate: predicate)

        do {
            let tracks = try modelContext.fetch(fetchDescriptor)
            return tracks.first?.persistentModelID
        } catch {
            logger.error("Failed to check track existence: \(error.localizedDescription)")
            throw TrackDataError.fetchFailed(error)
        }
    }

    /// Load all known source hashes for batch duplicate detection
    /// - Returns: SourceHashCache containing all known identifiers
    public func loadSourceHashCache() async throws -> SourceHashCache {
        logger.info("Loading source hash cache for duplicate detection")

        var urlHashes = Set<String>()
        var bookmarkHashes = Set<String>()
        var urlStrings = Set<String>()

        // Fetch full Track models in batches (SwiftData doesn't support field projection)
        let batchSize = 500
        var offset = 0

        while true {
            var descriptor = FetchDescriptor<Track>()
            descriptor.fetchOffset = offset
            descriptor.fetchLimit = batchSize

            let tracks = try modelContext.fetch(descriptor)
            if tracks.isEmpty { break }

            // Extract only the fields we need
            for track in tracks {
                if let hash = track.sourceURLHash {
                    urlHashes.insert(hash)
                }
                if let hash = track.sourceBookmarkHash {
                    bookmarkHashes.insert(hash)
                }
                if let str = track.sourceURLString {
                    urlStrings.insert(str)
                }
            }

            if tracks.count < batchSize { break }
            offset += tracks.count
        }

        logger.info("Loaded \(urlHashes.count) URL hashes, \(bookmarkHashes.count) bookmark hashes")

        return SourceHashCache(
            urlHashes: urlHashes,
            bookmarkHashes: bookmarkHashes,
            urlStrings: urlStrings
        )
    }

    /// Get track metadata by persistent identifier
    /// - Parameter id: PersistentIdentifier of the track
    /// - Returns: TrackMetadata if found
    /// - Throws: TrackDataError if not found or fetch fails
    public func getTrackMetadata(for id: PersistentIdentifier) throws -> TrackMetadata {
        let track = try resolveTrack(with: id)

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
            sourceURL: track.sourceURLString.flatMap { URL(string: $0) },
            sourceBookmark: track.sourceURLBookmark,
            sourceURLHash: track.sourceURLHash,
            sourceBookmarkHash: track.sourceBookmarkHash,
            isFavorite: track.isFavorite,
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
        let track = try resolveTrack(with: id)

        modelContext.delete(track)

        do {
            try modelContext.save()
            logger.info("Successfully deleted track: \(track.id)")
        } catch {
            logger.error("Failed to delete track: \(error.localizedDescription)")
            throw TrackDataError.deleteFailed(error)
        }
    }

    /// Get recently played tracks sorted by last played date
    /// - Parameter limit: Maximum number of tracks to return
    /// - Returns: Array of Tracks sorted by lastPlayed descending
    public func getRecentlyPlayed(limit: Int) throws -> [Track] {
        var descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.lastPlayed != nil
            },
            sortBy: [SortDescriptor(\Track.lastPlayed, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch recently played tracks: \(error.localizedDescription)")
            throw TrackDataError.fetchFailed(error)
        }
    }

    /// Get most listened tracks sorted by play count
    /// - Parameter limit: Maximum number of tracks to return
    /// - Returns: Array of Tracks sorted by playCount descending
    public func getMostListened(limit: Int) throws -> [Track] {
        var descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.playCount > 0
            },
            sortBy: [SortDescriptor(\Track.playCount, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch most listened tracks: \(error.localizedDescription)")
            throw TrackDataError.fetchFailed(error)
        }
    }

    /// Get favorite albums sorted by date added
    /// - Parameter limit: Maximum number of albums to return
    /// - Returns: Array of Albums that are marked as favorite
    public func getFavoriteAlbums(limit: Int) throws -> [Album] {
        var descriptor = FetchDescriptor<Album>(
            predicate: #Predicate<Album> { album in
                album.isFavorite == true
            },
            sortBy: [SortDescriptor(\Album.dateAdded, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            logger.error("Failed to fetch favorite albums: \(error.localizedDescription)")
            throw TrackDataError.fetchFailed(error)
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
        let track = try resolveTrack(with: id)

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
        let track = try resolveTrack(with: id)

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

    /// Toggle the favorite status of a track
    /// - Parameter trackId: PersistentIdentifier of the track
    /// - Throws: TrackDataError if track not found or update fails
    public func toggleFavorite(trackId: PersistentIdentifier) throws {
        let track = try resolveTrack(with: trackId)
        track.isFavorite.toggle()

        do {
            try modelContext.save()
            Log.logger(.data).info("Toggled favorite for track")
        } catch {
            logger.error("Failed to toggle favorite: \(error.localizedDescription)")
            throw TrackDataError.updateFailed(error)
        }
    }
}

// MARK: - Supporting Types

/// Cache of known source identifiers for fast duplicate detection
/// Sendable because it crosses actor boundary when returned from TrackDataActor
/// Task-confined within FileImportProcessor - no locks needed
public struct SourceHashCache: Sendable {
    private(set) var urlHashes: Set<String>
    private(set) var bookmarkHashes: Set<String>
    private(set) var urlStrings: Set<String>

    public init(urlHashes: Set<String> = [], bookmarkHashes: Set<String> = [], urlStrings: Set<String> = []) {
        self.urlHashes = urlHashes
        self.bookmarkHashes = bookmarkHashes
        self.urlStrings = urlStrings
    }

    public func contains(urlHash: String?, bookmarkHash: String?, urlString: String?) -> Bool {
        if let hash = urlHash, urlHashes.contains(hash) { return true }
        if let hash = bookmarkHash, bookmarkHashes.contains(hash) { return true }
        if let str = urlString, urlStrings.contains(str) { return true }
        return false
    }

    /// Add new hashes after successful import (prevents duplicates within same batch)
    public mutating func addEntry(urlHash: String?, bookmarkHash: String?, urlString: String?) {
        if let hash = urlHash { urlHashes.insert(hash) }
        if let hash = bookmarkHash { bookmarkHashes.insert(hash) }
        if let str = urlString { urlStrings.insert(str) }
    }
}

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
    public let sourceURL: URL?
    public let sourceBookmark: Data?
    public let sourceURLHash: String?
    public let sourceBookmarkHash: String?
    public let replayGainTrack: Float?
    public let replayGainAlbum: Float?
    public let isFavorite: Bool

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
        sourceURL: URL? = nil,
        sourceBookmark: Data? = nil,
        sourceURLHash: String? = nil,
        sourceBookmarkHash: String? = nil,
        replayGainTrack: Float? = nil,
        replayGainAlbum: Float? = nil,
        isFavorite: Bool = false,
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
        self.sourceURL = sourceURL
        self.sourceBookmark = sourceBookmark
        self.sourceURLHash = sourceURLHash
        self.sourceBookmarkHash = sourceBookmarkHash
        self.replayGainTrack = replayGainTrack
        self.replayGainAlbum = replayGainAlbum
        self.isFavorite = isFavorite
    }
}

public extension TrackMetadata {
    func withSourceInfo(
        sourceURL: URL,
        sourceBookmark: Data?,
        sourceURLHash: String? = nil,
        sourceBookmarkHash: String? = nil
    ) -> TrackMetadata {
        let resolvedURLHash = sourceURLHash ?? sourceURL.librarySourceHash()
        let resolvedBookmarkHash = sourceBookmarkHash ?? sourceBookmark?.sha256Hex()

        return TrackMetadata(
            url: url,
            title: title,
            artist: artist,
            album: album,
            albumArtist: albumArtist,
            genre: genre,
            year: year,
            trackNumber: trackNumber,
            discNumber: discNumber,
            composer: composer,
            conductor: conductor,
            audioFormat: audioFormat,
            duration: duration,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            bitrate: bitrate,
            channels: channels,
            isLossless: isLossless,
            artwork: artwork,
            lyrics: lyrics,
            comment: comment,
            sourceURL: sourceURL,
            sourceBookmark: sourceBookmark,
            sourceURLHash: resolvedURLHash,
            sourceBookmarkHash: resolvedBookmarkHash,
            replayGainTrack: replayGainTrack,
            replayGainAlbum: replayGainAlbum,
            isFavorite: isFavorite,
        )
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
