//
//  SwiftDataLibraryRepository.swift
//  Fonic HiFi
//
//  Created by Codex on 3/6/26.
//
//  Simplified SwiftData-backed implementation of the LibraryRepository.
//  Provides basic paging and search support by bridging existing SwiftData
//  models to the domain entities.
//

import Foundation
import SwiftData

public actor SwiftDataLibraryRepository: LibraryRepository {
    private let container: ModelContainer
    private var statisticsCache = LibraryStatisticsCache()

    public init(container: ModelContainer) {
        self.container = container
    }

    var statisticsComputationCount: Int {
        statisticsCache.computationCount
    }

    // MARK: - LibraryRepository

    public func tracks(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<TrackEntity> {
        let context = makeContext()
        var descriptor = FetchDescriptor<Track>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])

        if let query = normalized(searchQuery) {
            descriptor.predicate = #Predicate<Track> { track in
                track.title.localizedStandardContains(query) ||
                    track.artist.localizedStandardContains(query) ||
                    track.album.localizedStandardContains(query) ||
                    (track.albumArtist?.localizedStandardContains(query) ?? false) ||
                    (track.genre?.localizedStandardContains(query) ?? false)
            }
        }

        let fetch = PaginatedModelFetch(
            descriptor: descriptor,
            page: page,
            pageSize: pageSize,
        )
        let result = try fetch.execute(in: context)
        let mapped = result.items.map(TrackEntity.init(track:))
        return Page(items: mapped, hasMore: result.hasMore, nextPage: page + 1)
    }

    public func albums(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<AlbumEntity> {
        let context = makeContext()
        var descriptor = FetchDescriptor<Album>(sortBy: [SortDescriptor(\.title)])
        descriptor.relationshipKeyPathsForPrefetching = [\Album.tracks]

        if let query = normalized(searchQuery) {
            descriptor.predicate = #Predicate<Album> { album in
                album.title.localizedStandardContains(query) ||
                    album.albumArtist.localizedStandardContains(query)
            }
        }

        let fetch = PaginatedModelFetch(
            descriptor: descriptor,
            page: page,
            pageSize: pageSize,
        )
        let result = try fetch.execute(in: context)
        let trackCounts = Dictionary(
            uniqueKeysWithValues: result.items.map { album in
                (album.id, album.tracks.count)
            }
        )
        let mapped = result.items.map { album in
            AlbumEntity(
                id: album.id,
                title: album.title,
                albumArtist: album.albumArtist,
                trackCount: trackCounts[album.id, default: 0],
                artworkSha: nil,
                year: album.year,
                dateAdded: album.dateAdded,
            )
        }
        return Page(items: mapped, hasMore: result.hasMore, nextPage: page + 1)
    }

    public func artists(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<ArtistEntity> {
        let context = makeContext()
        var descriptor = FetchDescriptor<Artist>(sortBy: [SortDescriptor(\.sortName)])
        descriptor.relationshipKeyPathsForPrefetching = [\Artist.albums, \Artist.tracks]

        if let query = normalized(searchQuery) {
            descriptor.predicate = #Predicate<Artist> { artist in
                artist.name.localizedStandardContains(query) ||
                    artist.sortName.localizedStandardContains(query)
            }
        }

        let fetch = PaginatedModelFetch(
            descriptor: descriptor,
            page: page,
            pageSize: pageSize,
        )
        let result = try fetch.execute(in: context)
        let relationshipCounts = Dictionary(
            uniqueKeysWithValues: result.items.map { artist in
                (artist.id, (albums: artist.albums.count, tracks: artist.tracks.count))
            }
        )
        let mapped = result.items.map { artist in
            let counts = relationshipCounts[artist.id] ?? (albums: 0, tracks: 0)
            return ArtistEntity(
                id: artist.id,
                name: artist.name,
                sortName: artist.sortName,
                albumCount: counts.albums,
                trackCount: counts.tracks,
            )
        }
        return Page(items: mapped, hasMore: result.hasMore, nextPage: page + 1)
    }

    public func playlists(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<PlaylistEntity> {
        let context = makeContext()
        var descriptor = FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\.name)])

        if let query = normalized(searchQuery) {
            descriptor.predicate = #Predicate<Playlist> { playlist in
                playlist.name.localizedStandardContains(query) ||
                    (playlist.playlistDescription?.localizedStandardContains(query) ?? false)
            }
        }

        let fetch = PaginatedModelFetch(
            descriptor: descriptor,
            page: page,
            pageSize: pageSize,
        )
        let result = try fetch.execute(in: context)
        let mapped = result.items.map { PlaylistEntity(playlist: $0) }
        return Page(items: mapped, hasMore: result.hasMore, nextPage: page + 1)
    }

    public func recentAdditions(limit: Int) async throws -> [TrackEntity] {
        let context = makeContext()
        var descriptor = FetchDescriptor<Track>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        descriptor.fetchLimit = limit
        let tracks = try context.fetch(descriptor)
        return tracks.map(TrackEntity.init(track:))
    }

    public func libraryStatistics() async throws -> LibraryStatisticsEntity {
        let now = Date()

        let context = makeContext()
        let aggregate = try statisticsCache.statistics(in: context, now: now)

        let statistics = LibraryStatisticsEntity(
            trackCount: aggregate.trackCount,
            albumCount: aggregate.albumCount,
            artistCount: aggregate.artistCount,
            playlistCount: aggregate.playlistCount,
            totalDuration: aggregate.totalDuration,
            totalFileSize: aggregate.totalFileSize,
            losslessTrackCount: aggregate.losslessTrackCount,
            hiResTrackCount: aggregate.hiResTrackCount
        )
        return statistics
    }

    func invalidateLibraryStatisticsCache() {
        statisticsCache.invalidate()
    }

    func updateStatisticsCacheTTL(_ ttl: TimeInterval) {
        statisticsCache.updateTTL(ttl)
    }

    // MARK: - Helpers

    private func makeContext() -> ModelContext {
        let context = ModelContext(container)
        context.autosaveEnabled = false
        return context
    }

    private func normalized(_ query: String?) -> String? {
        guard let query, !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        return query.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
