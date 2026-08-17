//
//  TrackDataActor.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import Foundation
import OSLog
import SwiftData

/// Injected boundary for file-provider and protected-data availability checks.
public struct TrackFileAvailabilityChecker: Sendable {
    private let check: @Sendable (URL) -> Bool

    public init(check: @escaping @Sendable (URL) -> Bool) {
        self.check = check
    }

    public func isAvailable(_ url: URL) -> Bool {
        check(url)
    }

    public static let live = TrackFileAvailabilityChecker { url in
        FileManager.default.fileExists(atPath: url.path)
    }
}

/// Conservative policy for converting repeated, long-lived misses into record removal.
public struct MissingFileQuarantinePolicy: Equatable, Sendable {
    public let requiredConsecutiveMisses: Int
    public let minimumUnavailableDuration: TimeInterval

    public init(
        requiredConsecutiveMisses: Int = 3,
        minimumUnavailableDuration: TimeInterval = 7 * 24 * 60 * 60
    ) {
        self.requiredConsecutiveMisses = max(1, requiredConsecutiveMisses)
        self.minimumUnavailableDuration = max(0, minimumUnavailableDuration)
    }

    public static let `default` = MissingFileQuarantinePolicy()

    func permitsRemoval(consecutiveMisses: Int, unavailableSince: Date, now: Date) -> Bool {
        consecutiveMisses >= requiredConsecutiveMisses &&
            now.timeIntervalSince(unavailableSince) >= minimumUnavailableDuration
    }
}

/// ModelActor for handling Track data operations in a concurrency-safe manner
@ModelActor
public actor TrackDataActor {
    static let listeningSessionRetentionInterval: TimeInterval = 365 * 24 * 60 * 60

    // The macro-generated initializer uses the normal policy. The explicit policy
    // initializer below sets this once for recovery-mode authorities.
    private var mutationPolicy: DataMutationPolicy = .normal
    private let logger = Log.logger(.dataTrackActor)
    private let unknownArtistName = "Unknown Artist"
    private let unknownAlbumTitle = "Unknown Album"

    public init(
        modelContainer: ModelContainer,
        mutationPolicy: DataMutationPolicy
    ) {
        let modelContext = ModelContext(modelContainer)
        self.modelExecutor = DefaultSerialModelExecutor(modelContext: modelContext)
        self.modelContainer = modelContainer
        self.mutationPolicy = mutationPolicy
    }

    func requireMutationAllowed() throws {
        guard mutationPolicy == .normal else {
            throw DataMutationError.readOnly
        }
    }

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

    private func normalizedLookupValue(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func resolvedArtistName(_ name: String?) -> String {
        let trimmed = name?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? unknownArtistName : trimmed
    }

    private func resolvedAlbumTitle(_ title: String?) -> String {
        let trimmed = title?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? unknownAlbumTitle : trimmed
    }

    private func resolvedAlbumArtistName(albumArtist: String?, artist: String?) -> String {
        let trimmedAlbumArtist = albumArtist?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedAlbumArtist.isEmpty {
            return trimmedAlbumArtist
        }
        return resolvedArtistName(artist)
    }

    private func normalizedArtistKey(_ name: String) -> String {
        normalizedLookupValue(name)
    }

    private func normalizedAlbumKey(title: String, albumArtist: String) -> String {
        "\(normalizedLookupValue(title))::\(normalizedLookupValue(albumArtist))"
    }

    private func applyTrackMetadata(_ metadata: TrackMetadata, to track: Track) {
        track.albumArtist = metadata.albumArtist
        track.genre = metadata.genre
        track.year = metadata.year
        track.trackNumber = metadata.trackNumber
        track.totalTracks = metadata.totalTracks
        track.discNumber = metadata.discNumber
        track.totalDiscs = metadata.totalDiscs
        track.composer = metadata.composer
        track.conductor = metadata.conductor
        track.comments = metadata.comment
        track.lyrics = metadata.lyrics
        track.artwork = metadata.artwork
        track.bitrate = metadata.bitrate
        track.replayGainTrack = metadata.replayGainTrack
        track.replayGainAlbum = metadata.replayGainAlbum
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
    }

    private func findOrCreateArtist(
        name: String,
        genre: String?,
        cache: inout [String: Artist]
    ) throws -> (artist: Artist, created: Bool) {
        let normalizedName = resolvedArtistName(name)
        let key = normalizedArtistKey(normalizedName)
        if let cached = cache[key] {
            return (cached, false)
        }

        var descriptor = FetchDescriptor<Artist>(
            predicate: #Predicate<Artist> { artist in
                artist.name == normalizedName
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            if let genre, !genre.isEmpty {
                if existing.primaryGenre == nil {
                    existing.primaryGenre = genre
                }
                if !existing.genres.contains(where: { normalizedLookupValue($0) == normalizedLookupValue(genre) }) {
                    existing.genres.append(genre)
                }
            }
            cache[key] = existing
            return (existing, false)
        }

        let artist = Artist(name: normalizedName, primaryGenre: genre)
        if let genre, !genre.isEmpty {
            artist.genres = [genre]
        }
        modelContext.insert(artist)
        cache[key] = artist
        return (artist, true)
    }

    private func findOrCreateAlbum(
        title: String,
        albumArtist: String,
        year: Int?,
        genre: String?,
        artwork: Data?,
        cache: inout [String: Album]
    ) throws -> (album: Album, created: Bool) {
        let normalizedTitle = resolvedAlbumTitle(title)
        let normalizedAlbumArtist = resolvedArtistName(albumArtist)
        let key = normalizedAlbumKey(title: normalizedTitle, albumArtist: normalizedAlbumArtist)
        if let cached = cache[key] {
            return (cached, false)
        }

        var descriptor = FetchDescriptor<Album>(
            predicate: #Predicate<Album> { album in
                album.title == normalizedTitle && album.albumArtist == normalizedAlbumArtist
            }
        )
        descriptor.fetchLimit = 1

        if let existing = try modelContext.fetch(descriptor).first {
            if existing.year == nil {
                existing.year = year
            }
            if let genre, !genre.isEmpty {
                if existing.primaryGenre == nil {
                    existing.primaryGenre = genre
                }
                if !existing.genres.contains(where: { normalizedLookupValue($0) == normalizedLookupValue(genre) }) {
                    existing.genres.append(genre)
                }
            }
            if existing.artwork == nil, let artwork {
                existing.artwork = artwork
                existing.hasEmbeddedArtwork = true
            }
            cache[key] = existing
            return (existing, false)
        }

        let album = Album(
            title: normalizedTitle,
            albumArtist: normalizedAlbumArtist,
            year: year
        )
        if let genre, !genre.isEmpty {
            album.primaryGenre = genre
            album.genres = [genre]
        }
        if let artwork {
            album.artwork = artwork
            album.hasEmbeddedArtwork = true
        }
        modelContext.insert(album)
        cache[key] = album
        return (album, true)
    }

    private func linkAlbumArtistRelationships(
        track: Track,
        albumTitle: String,
        artistName: String,
        albumArtistName: String,
        genre: String?,
        year: Int?,
        artwork: Data?,
        overwriteTrackRelations: Bool,
        artistCache: inout [String: Artist],
        albumCache: inout [String: Album]
    ) throws -> RelationshipLinkResult {
        let artistResult = try findOrCreateArtist(
            name: artistName,
            genre: genre,
            cache: &artistCache
        )
        let albumResult = try findOrCreateAlbum(
            title: albumTitle,
            albumArtist: albumArtistName,
            year: year,
            genre: genre,
            artwork: artwork,
            cache: &albumCache
        )

        var updatedTrack = false

        if overwriteTrackRelations || track.artistRelation == nil {
            if track.artistRelation?.id != artistResult.artist.id {
                track.artistRelation = artistResult.artist
                updatedTrack = true
            }
        }

        if overwriteTrackRelations || track.albumRelation == nil {
            if track.albumRelation?.id != albumResult.album.id {
                track.albumRelation = albumResult.album
                updatedTrack = true
            }
        }

        if albumResult.album.artistRelation?.id != artistResult.artist.id {
            albumResult.album.artistRelation = artistResult.artist
        }

        return RelationshipLinkResult(
            trackUpdated: updatedTrack,
            createdArtist: artistResult.created,
            createdAlbum: albumResult.created
        )
    }

    // MARK: - Track Creation

    private func insertTrackWithoutSaving(
        from metadata: TrackMetadata,
        artistCache: inout [String: Artist],
        albumCache: inout [String: Album]
    ) throws -> Track {
        let resolvedArtist = resolvedArtistName(metadata.artist)
        let resolvedAlbum = resolvedAlbumTitle(metadata.album)
        let resolvedAlbumArtist = resolvedAlbumArtistName(
            albumArtist: metadata.albumArtist,
            artist: metadata.artist
        )

        let track = Track(
            url: metadata.url,
            title: metadata.title,
            artist: resolvedArtist,
            album: resolvedAlbum,
            audioFormat: metadata.audioFormat,
            duration: metadata.duration,
            sampleRate: metadata.sampleRate,
            bitDepth: metadata.bitDepth,
            channels: metadata.channels,
            isLossless: metadata.isLossless,
        )

        applyTrackMetadata(metadata, to: track)
        modelContext.insert(track)

        _ = try linkAlbumArtistRelationships(
            track: track,
            albumTitle: resolvedAlbum,
            artistName: resolvedArtist,
            albumArtistName: resolvedAlbumArtist,
            genre: metadata.genre,
            year: metadata.year,
            artwork: metadata.artwork,
            overwriteTrackRelations: true,
            artistCache: &artistCache,
            albumCache: &albumCache
        )

        return track
    }

    /// Create a new Track from extracted metadata
    /// - Parameter metadata: Sendable metadata extracted from audio file
    /// - Returns: PersistentIdentifier of the created Track
    /// - Throws: TrackDataError if creation fails
    public func createTrack(from metadata: TrackMetadata) throws -> PersistentIdentifier {
        try requireMutationAllowed()
        logger.info("Creating imported track record")

        var artistCache: [String: Artist] = [:]
        var albumCache: [String: Album] = [:]
        let track = try insertTrackWithoutSaving(
            from: metadata,
            artistCache: &artistCache,
            albumCache: &albumCache
        )

        do {
            try modelContext.save()
            logger.info("Successfully created track: \(track.id, privacy: .private(mask: .hash))")
            return track.persistentModelID
        } catch {
            logger.error("Failed to save track: \(error.localizedDescription, privacy: .private)")
            throw TrackDataError.saveFailed(error)
        }
    }

    /// Atomically checks and claims an imported source within this actor's save boundary.
    func claimImportedTrack(from metadata: TrackMetadata) throws -> TrackImportClaimResult {
        try requireMutationAllowed()
        if let sourceURL = metadata.sourceURL,
           try trackExists(for: sourceURL, bookmark: metadata.sourceBookmark) != nil {
            logger.notice("Duplicate imported source claim rejected")
            return .duplicate
        }

        var artistCache: [String: Artist] = [:]
        var albumCache: [String: Album] = [:]
        let track = try insertTrackWithoutSaving(
            from: metadata,
            artistCache: &artistCache,
            albumCache: &albumCache
        )

        do {
            try modelContext.save()
            logger.info("Successfully claimed imported track: \(track.id, privacy: .private(mask: .hash))")
            return .created(track.persistentModelID)
        } catch {
            logger.error("Failed to save claimed track: \(error.localizedDescription, privacy: .private)")
            throw TrackDataError.saveFailed(error)
        }
    }

    /// Create multiple tracks from metadata array
    /// - Parameter metadataArray: Array of TrackMetadata
    /// - Returns: Array of PersistentIdentifiers for created tracks
    /// - Throws: TrackDataError if any creation fails
    public func createTracks(from metadataArray: [TrackMetadata]) throws -> [PersistentIdentifier] {
        try requireMutationAllowed()
        logger.info("Creating \(metadataArray.count, privacy: .public) tracks")

        var identifiers: [PersistentIdentifier] = []
        var artistCache: [String: Artist] = [:]
        var albumCache: [String: Album] = [:]

        for metadata in metadataArray {
            let track = try insertTrackWithoutSaving(
                from: metadata,
                artistCache: &artistCache,
                albumCache: &albumCache
            )
            identifiers.append(track.persistentModelID)
        }

        do {
            try modelContext.save()
            logger.info("Successfully created \(identifiers.count, privacy: .public) tracks")
            return identifiers
        } catch {
            logger.error("Failed to save tracks: \(error.localizedDescription, privacy: .private)")
            throw TrackDataError.batchSaveFailed(error)
        }
    }

    /// Backfill Album/Artist relationships for existing tracks missing relational links.
    /// - Parameter batchSize: Number of updated tracks to save per transaction.
    /// - Returns: Summary of backfill work performed.
    public func backfillAlbumArtistRelationships(batchSize: Int = 200) throws -> AlbumArtistBackfillResult {
        try requireMutationAllowed()
        let effectiveBatchSize = max(1, batchSize)
        logger.info("Starting relationship backfill (batch size: \(effectiveBatchSize, privacy: .public))")

        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.albumRelation == nil || track.artistRelation == nil
            }
        )

        let tracks: [Track]
        do {
            tracks = try modelContext.fetch(descriptor)
        } catch {
            logger.error(
                "Failed to fetch tracks for relationship backfill: \(error.localizedDescription, privacy: .private)"
            )
            throw TrackDataError.fetchFailed(error)
        }

        guard !tracks.isEmpty else {
            return AlbumArtistBackfillResult(
                scannedTracks: 0,
                updatedTracks: 0,
                createdAlbums: 0,
                createdArtists: 0
            )
        }

        var artistCache: [String: Artist] = [:]
        var albumCache: [String: Album] = [:]
        var updatedTracks = 0
        var createdAlbums = 0
        var createdArtists = 0
        var pendingUpdatedTracks = 0

        for track in tracks {
            let resolvedArtist = resolvedArtistName(track.artist)
            let resolvedAlbum = resolvedAlbumTitle(track.album)
            let resolvedAlbumArtist = resolvedAlbumArtistName(
                albumArtist: track.albumArtist,
                artist: track.artist
            )

            let linkResult = try linkAlbumArtistRelationships(
                track: track,
                albumTitle: resolvedAlbum,
                artistName: resolvedArtist,
                albumArtistName: resolvedAlbumArtist,
                genre: track.genre,
                year: track.year,
                artwork: track.artwork,
                overwriteTrackRelations: false,
                artistCache: &artistCache,
                albumCache: &albumCache
            )

            if linkResult.trackUpdated {
                updatedTracks += 1
                pendingUpdatedTracks += 1
            }
            if linkResult.createdArtist {
                createdArtists += 1
            }
            if linkResult.createdAlbum {
                createdAlbums += 1
            }

            if pendingUpdatedTracks >= effectiveBatchSize {
                do {
                    try modelContext.save()
                    pendingUpdatedTracks = 0
                } catch {
                    logger.error(
                        "Failed to save relationship backfill batch: \(error.localizedDescription, privacy: .private)"
                    )
                    throw TrackDataError.saveFailed(error)
                }
            }
        }

        if modelContext.hasChanges {
            do {
                try modelContext.save()
            } catch {
                logger.error(
                    "Failed to save final relationship backfill batch: \(error.localizedDescription, privacy: .private)"
                )
                throw TrackDataError.saveFailed(error)
            }
        }

        logger.info(
            """
            Relationship backfill complete - \
            scanned: \(tracks.count, privacy: .public), \
            updated: \(updatedTracks, privacy: .public), \
            created albums: \(createdAlbums, privacy: .public), \
            created artists: \(createdArtists, privacy: .public)
            """
        )

        return AlbumArtistBackfillResult(
            scannedTracks: tracks.count,
            updatedTracks: updatedTracks,
            createdAlbums: createdAlbums,
            createdArtists: createdArtists
        )
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
            logger.error("Failed to check track existence: \(error.localizedDescription, privacy: .private)")
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

        logger.info(
            "Loaded \(urlHashes.count, privacy: .public) URL hashes, \(bookmarkHashes.count, privacy: .public) bookmark hashes"
        )

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
            totalTracks: track.totalTracks,
            discNumber: track.discNumber,
            totalDiscs: track.totalDiscs,
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
            replayGainTrack: track.replayGainTrack,
            replayGainAlbum: track.replayGainAlbum,
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
            logger.error("Failed to get tracks count: \(error.localizedDescription, privacy: .private)")
            throw TrackDataError.fetchFailed(error)
        }
    }

    /// Delete a specific track by identifier
    /// - Parameter id: PersistentIdentifier of the track to delete
    /// - Throws: TrackDataError if deletion fails
    public func deleteTrack(_ id: PersistentIdentifier) throws {
        try requireMutationAllowed()
        let track = try resolveTrack(with: id)

        modelContext.delete(track)

        do {
            try modelContext.save()
            logger.info("Successfully deleted track: \(track.id, privacy: .private(mask: .hash))")
        } catch {
            logger.error("Failed to delete track: \(error.localizedDescription, privacy: .private)")
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
            logger.error(
                "Failed to fetch recently played tracks: \(error.localizedDescription, privacy: .private)"
            )
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
            logger.error(
                "Failed to fetch most listened tracks: \(error.localizedDescription, privacy: .private)"
            )
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
            logger.error("Failed to fetch favorite albums: \(error.localizedDescription, privacy: .private)")
            throw TrackDataError.fetchFailed(error)
        }
    }

    /// Quarantine temporarily unavailable tracks and remove only records that exceed the policy.
    ///
    /// Managed media is never deleted here. A successful check resets any prior miss window.
    /// - Returns: Number of track records removed after exceeding both thresholds.
    public func cleanupMissingFiles(
        checker: TrackFileAvailabilityChecker = .live,
        policy: MissingFileQuarantinePolicy = .default,
        now: Date = Date(),
        documentsDirectory: URL? = nil
    ) throws -> Int {
        try requireMutationAllowed()
        let fetchDescriptor = FetchDescriptor<Track>()

        do {
            let tracks = try modelContext.fetch(fetchDescriptor)
            var removedCount = 0
            var changedCount = 0

            for track in tracks {
                if checker.isAvailable(track.url) {
                    if track.unavailableCheckCount > 0 ||
                        track.unavailableSince != nil ||
                        track.availabilityLastCheckedAt != nil {
                        track.unavailableCheckCount = 0
                        track.unavailableSince = nil
                        track.availabilityLastCheckedAt = nil
                        changedCount += 1
                    }
                    continue
                }

                if let rebasedURL = ManagedMediaURLResolver.resolveAvailableURL(
                    track.url,
                    documentsDirectory: documentsDirectory
                ),
                    rebasedURL.standardizedFileURL != track.url.standardizedFileURL {
                    track.url = rebasedURL
                    track.unavailableCheckCount = 0
                    track.unavailableSince = nil
                    track.availabilityLastCheckedAt = nil
                    changedCount += 1
                    continue
                }

                let unavailableSince = track.unavailableSince ?? now
                track.unavailableSince = unavailableSince
                track.unavailableCheckCount += 1
                track.availabilityLastCheckedAt = now
                changedCount += 1

                if policy.permitsRemoval(
                    consecutiveMisses: track.unavailableCheckCount,
                    unavailableSince: unavailableSince,
                    now: now
                ) {
                    // Preserve the playlist's scalar ordering contract alongside
                    // SwiftData's nullified relationships.
                    for playlist in track.playlists {
                        playlist.trackIds.removeAll { $0 == track.id }
                        playlist.dateModified = now
                    }
                    modelContext.delete(track)
                    removedCount += 1
                }
            }

            if changedCount > 0 {
                try modelContext.save()
                logger.info(
                    """
                    Missing-file check changed \(changedCount, privacy: .public) records; \
                    removed \(removedCount, privacy: .public) records past policy
                    """
                )
            }

            return removedCount
        } catch {
            logger.error("Failed to cleanup missing files: \(error.localizedDescription, privacy: .private)")
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
        try requireMutationAllowed()
        let track = try resolveTrack(with: id)

        track.playCount = playCount
        track.lastPlayed = lastPlayed

        do {
            try modelContext.save()
            logger.debug("Updated track playback stats")
        } catch {
            logger.error("Failed to update playback stats: \(error.localizedDescription, privacy: .private)")
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
        try requireMutationAllowed()
        let track = try resolveTrack(with: id)

        track.rating = rating
        track.isFavorite = isFavorite
        track.userTags = userTags

        do {
            try modelContext.save()
            logger.debug("Updated track user data")
        } catch {
            logger.error("Failed to update user data: \(error.localizedDescription, privacy: .private)")
            throw TrackDataError.updateFailed(error)
        }
    }

    /// Toggle the favorite status of a track
    /// - Parameter trackId: PersistentIdentifier of the track
    /// - Returns: The persisted favorite status after the toggle
    /// - Throws: TrackDataError if track not found or update fails
    @discardableResult
    public func toggleFavorite(trackId: PersistentIdentifier) throws -> Bool {
        try requireMutationAllowed()
        let track = try resolveTrack(with: trackId)
        track.isFavorite.toggle()

        do {
            try modelContext.save()
            Log.logger(.data).info("Toggled favorite for track")
            return track.isFavorite
        } catch {
            logger.error("Failed to toggle favorite: \(error.localizedDescription, privacy: .private)")
            throw TrackDataError.updateFailed(error)
        }
    }

    // MARK: - Listening Sessions

    /// Record a new listening session
    public func recordListeningSession(
        trackId: UUID,
        startedAt: Date,
        durationListened: TimeInterval,
        trackDuration: TimeInterval,
        completionPercentage: Double,
        wasSkipped: Bool,
        wasCompleted: Bool
    ) throws {
        try requireMutationAllowed()
        let session = ListeningSession(
            trackId: trackId,
            startedAt: startedAt,
            durationListened: durationListened,
            trackDuration: trackDuration,
            completionPercentage: completionPercentage,
            wasSkipped: wasSkipped,
            wasCompleted: wasCompleted
        )
        session.endedAt = Date()

        modelContext.insert(session)

        do {
            try modelContext.save()
            try enforceListeningSessionRetentionPolicy()
            logger.debug("Recorded listening session")
        } catch {
            logger.error("Failed to record listening session: \(error.localizedDescription, privacy: .private)")
            throw TrackDataError.insertFailed(error)
        }
    }

    private func enforceListeningSessionRetentionPolicy() throws {
        let cutoff = Date().addingTimeInterval(-Self.listeningSessionRetentionInterval)
        let descriptor = FetchDescriptor<ListeningSession>(
            predicate: #Predicate<ListeningSession> { session in
                session.startedAt < cutoff
            }
        )
        let expiredSessions = try modelContext.fetch(descriptor)
        guard !expiredSessions.isEmpty else { return }
        for session in expiredSessions {
            modelContext.delete(session)
        }
        try modelContext.save()
    }

    /// Get recent listening sessions
    /// - Parameter limit: Maximum number of sessions to return
    /// - Returns: Array of session data sorted by startedAt descending
    public func getListeningSessions(limit: Int) throws -> [ListeningSessionData] {
        var descriptor = FetchDescriptor<ListeningSession>(
            sortBy: [SortDescriptor(\ListeningSession.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let sessions = try modelContext.fetch(descriptor)
        return sessions.map { ListeningSessionData(from: $0) }
    }

    /// Get the most recent session for a specific track
    /// - Parameter trackId: UUID of the track
    /// - Returns: Most recent session data or nil
    public func getLastSession(for trackId: UUID) throws -> ListeningSessionData? {
        var descriptor = FetchDescriptor<ListeningSession>(
            predicate: #Predicate<ListeningSession> { session in
                session.trackId == trackId
            },
            sortBy: [SortDescriptor(\ListeningSession.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = 1

        let sessions = try modelContext.fetch(descriptor)
        return sessions.first.map { ListeningSessionData(from: $0) }
    }

    /// Get tracks that haven't been played recently (for Rediscover section)
    /// - Parameters:
    ///   - daysSinceLastPlay: Minimum days since last play
    ///   - minimumPlayCount: Minimum play count to qualify as "known"
    ///   - limit: Maximum number of tracks to return
    /// - Returns: Array of track IDs that qualify as neglected
    public func getNeglectedTrackIds(
        daysSinceLastPlay: Int,
        minimumPlayCount: Int,
        limit: Int
    ) throws -> [UUID] {
        let cutoffDate = Calendar.current.date(
            byAdding: .day,
            value: -daysSinceLastPlay,
            to: Date()
        ) ?? Date()

        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.playCount >= minimumPlayCount
            },
            sortBy: [SortDescriptor(\Track.playCount, order: .reverse)]
        )

        let candidates = try modelContext.fetch(descriptor)
        return candidates.lazy
            .filter { track in
                guard let lastPlayed = track.lastPlayed else { return true }
                return lastPlayed < cutoffDate
            }
            .prefix(limit)
            .map(\.id)
    }

    /// Increment play count and update last played for a track
    /// - Parameter trackId: UUID of the track
    public func incrementPlayCount(for trackId: UUID) throws {
        try requireMutationAllowed()
        var descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.id == trackId
            }
        )
        descriptor.fetchLimit = 1

        guard let track = try modelContext.fetch(descriptor).first else {
            logger.warning("Track not found for play count increment")
            return
        }

        track.playCount += 1
        track.lastPlayed = Date()

        do {
            try modelContext.save()
            logger.debug("Incremented track play count to \(track.playCount, privacy: .public)")
        } catch {
            logger.error("Failed to increment play count: \(error.localizedDescription, privacy: .private)")
            throw TrackDataError.updateFailed(error)
        }
    }

    /// Get a track by its UUID
    public func getTrack(by id: UUID) throws -> Track? {
        var descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                track.id == id
            }
        )
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first
    }

    // MARK: - AI Recommendations Support

    /// Get listening sessions filtered by hour range
    /// - Parameters:
    ///   - startHour: Start hour (inclusive, 0-23)
    ///   - endHour: End hour (exclusive, 0-24)
    ///   - limit: Maximum number of sessions to return
    /// - Returns: Sessions that occurred during the specified hours
    public func getSessionsByHourRange(
        startHour: Int,
        endHour: Int,
        limit: Int
    ) throws -> [ListeningSessionData] {
        var descriptor = FetchDescriptor<ListeningSession>(
            predicate: #Predicate<ListeningSession> { session in
                session.hourOfDay >= startHour && session.hourOfDay < endHour
            },
            sortBy: [SortDescriptor(\ListeningSession.startedAt, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let sessions = try modelContext.fetch(descriptor)
        return sessions.map { ListeningSessionData(from: $0) }
    }

    /// Get all track IDs in the library
    /// - Parameter limit: Maximum number of IDs to return
    /// - Returns: Array of track UUIDs
    public func getAllTrackIDs(limit: Int) throws -> [UUID] {
        var descriptor = FetchDescriptor<Track>(
            sortBy: [SortDescriptor(\Track.dateAdded, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let tracks = try modelContext.fetch(descriptor)
        return tracks.map { $0.id }
    }

    /// Get all unique genres from the library
    /// - Returns: Array of distinct genre strings
    public func getUniqueGenres() throws -> [String] {
        let descriptor = FetchDescriptor<Track>()
        let tracks = try modelContext.fetch(descriptor)

        var genres = Set<String>()
        for track in tracks {
            if let genre = track.genre, !genre.isEmpty {
                genres.insert(genre)
            }
        }

        return Array(genres).sorted()
    }

    /// Get track metadata for smart search context
    /// - Parameter limit: Maximum number of tracks to return
    /// - Returns: Array of TrackSearchMetadata
    public func getTrackMetadataForSearch(limit: Int) throws -> [TrackSearchMetadata] {
        var descriptor = FetchDescriptor<Track>(
            sortBy: [SortDescriptor(\Track.playCount, order: .reverse)]
        )
        descriptor.fetchLimit = limit

        let tracks = try modelContext.fetch(descriptor)
        return tracks.map { track in
            TrackSearchMetadata(
                id: track.id,
                title: track.title,
                artist: track.artist,
                genre: track.genre
            )
        }
    }
}

// MARK: - Protocol Conformances

extension TrackDataActor: ListeningSessionRecording {}

private struct RelationshipLinkResult {
    let trackUpdated: Bool
    let createdArtist: Bool
    let createdAlbum: Bool
}

/// Sendable type for track metadata used in smart search
public struct TrackSearchMetadata: Sendable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let genre: String?

    public init(id: UUID, title: String, artist: String, genre: String?) {
        self.id = id
        self.title = title
        self.artist = artist
        self.genre = genre
    }
}

// MARK: - Supporting Types

enum TrackImportClaimResult: Sendable {
    case created(PersistentIdentifier)
    case duplicate
}

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

public struct AlbumArtistBackfillResult: Sendable {
    public let scannedTracks: Int
    public let updatedTracks: Int
    public let createdAlbums: Int
    public let createdArtists: Int

    public init(scannedTracks: Int, updatedTracks: Int, createdAlbums: Int, createdArtists: Int) {
        self.scannedTracks = scannedTracks
        self.updatedTracks = updatedTracks
        self.createdAlbums = createdAlbums
        self.createdArtists = createdArtists
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
    public let totalTracks: Int?
    public let discNumber: Int?
    public let totalDiscs: Int?
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
        totalTracks: Int? = nil,
        discNumber: Int? = nil,
        totalDiscs: Int? = nil,
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
        self.totalTracks = totalTracks
        self.discNumber = discNumber
        self.totalDiscs = totalDiscs
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
            totalTracks: totalTracks,
            discNumber: discNumber,
            totalDiscs: totalDiscs,
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
    case insertFailed(Error)

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
        case let .insertFailed(error):
            "Failed to insert record: \(error.localizedDescription)"
        }
    }
}
