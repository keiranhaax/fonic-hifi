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

    public init(container: ModelContainer) {
        self.container = container
    }

    // MARK: - LibraryRepository

    public func tracks(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<TrackEntity> {
        let context = makeContext()
        var descriptor = FetchDescriptor<Track>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = max(0, page * pageSize)

        if let query = normalized(searchQuery) {
            descriptor.predicate = #Predicate<Track> { track in
                track.title.localizedStandardContains(query) ||
                    track.artist.localizedStandardContains(query) ||
                    track.album.localizedStandardContains(query) ||
                    (track.albumArtist?.localizedStandardContains(query) ?? false) ||
                    (track.genre?.localizedStandardContains(query) ?? false)
            }
        }

        let results = try context.fetch(descriptor)
        let totalCount = try context.fetchCount(descriptor.withoutLimit())
        let mapped = results.map(TrackEntity.init(track:))
        let hasMore = (descriptor.fetchOffset ?? 0) + mapped.count < totalCount
        return Page(items: mapped, hasMore: hasMore, nextPage: page + 1, totalCount: totalCount)
    }

    public func albums(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<AlbumEntity> {
        let context = makeContext()
        var descriptor = FetchDescriptor<Album>(sortBy: [SortDescriptor(\.title)])
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = max(0, page * pageSize)

        if let query = normalized(searchQuery) {
            descriptor.predicate = #Predicate<Album> { album in
                album.title.localizedStandardContains(query) ||
                    album.albumArtist.localizedStandardContains(query)
            }
        }

        let results = try context.fetch(descriptor)
        let totalCount = try context.fetchCount(descriptor.withoutLimit())
        let mapped = results.map { album in
            AlbumEntity(
                id: album.id,
                title: album.title,
                albumArtist: album.albumArtist,
                trackCount: album.trackCount,
                artworkSha: nil,
                year: album.year,
                dateAdded: album.dateAdded,
            )
        }
        let hasMore = (descriptor.fetchOffset ?? 0) + mapped.count < totalCount
        return Page(items: mapped, hasMore: hasMore, nextPage: page + 1, totalCount: totalCount)
    }

    public func artists(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<ArtistEntity> {
        let context = makeContext()
        var descriptor = FetchDescriptor<Artist>(sortBy: [SortDescriptor(\.sortName)])
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = max(0, page * pageSize)

        if let query = normalized(searchQuery) {
            descriptor.predicate = #Predicate<Artist> { artist in
                artist.name.localizedStandardContains(query) ||
                    artist.sortName.localizedStandardContains(query)
            }
        }

        let results = try context.fetch(descriptor)
        let totalCount = try context.fetchCount(descriptor.withoutLimit())
        let mapped = results.map { artist in
            ArtistEntity(
                id: artist.id,
                name: artist.name,
                sortName: artist.sortName,
                albumCount: artist.albumCount,
                trackCount: artist.trackCount,
            )
        }
        let hasMore = (descriptor.fetchOffset ?? 0) + mapped.count < totalCount
        return Page(items: mapped, hasMore: hasMore, nextPage: page + 1, totalCount: totalCount)
    }

    public func playlists(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<PlaylistEntity> {
        let context = makeContext()
        var descriptor = FetchDescriptor<Playlist>(sortBy: [SortDescriptor(\.name)])
        descriptor.fetchLimit = pageSize
        descriptor.fetchOffset = max(0, page * pageSize)

        if let query = normalized(searchQuery) {
            descriptor.predicate = #Predicate<Playlist> { playlist in
                playlist.name.localizedStandardContains(query) ||
                    (playlist.playlistDescription?.localizedStandardContains(query) ?? false)
            }
        }

        let results = try context.fetch(descriptor)
        let totalCount = try context.fetchCount(descriptor.withoutLimit())
        let mapped = results.map { PlaylistEntity(playlist: $0) }
        let hasMore = (descriptor.fetchOffset ?? 0) + mapped.count < totalCount
        return Page(items: mapped, hasMore: hasMore, nextPage: page + 1, totalCount: totalCount)
    }

    public func recentAdditions(limit: Int) async throws -> [TrackEntity] {
        let context = makeContext()
        var descriptor = FetchDescriptor<Track>(sortBy: [SortDescriptor(\.dateAdded, order: .reverse)])
        descriptor.fetchLimit = limit
        let tracks = try context.fetch(descriptor)
        return tracks.map(TrackEntity.init(track:))
    }

    public func libraryStatistics() async throws -> LibraryStatisticsEntity {
        let context = makeContext()
        let trackCount = try context.fetchCount(FetchDescriptor<Track>())
        let albumCount = try context.fetchCount(FetchDescriptor<Album>())
        let artistCount = try context.fetchCount(FetchDescriptor<Artist>())
        let playlistCount = try context.fetchCount(FetchDescriptor<Playlist>())

        let tracks = try context.fetch(FetchDescriptor<Track>())
        var duration: TimeInterval = 0
        var fileSize: Int64 = 0
        var losslessCount = 0
        var hiResCount = 0

        for track in tracks {
            duration += track.duration
            fileSize += track.fileSize
            if track.isLossless { losslessCount += 1 }
            if track.isLossless, track.sampleRate > 48000 || track.bitDepth > 16 {
                hiResCount += 1
            }
        }

        return LibraryStatisticsEntity(
            trackCount: trackCount,
            albumCount: albumCount,
            artistCount: artistCount,
            playlistCount: playlistCount,
            totalDuration: duration,
            totalFileSize: fileSize,
            losslessTrackCount: losslessCount,
            hiResTrackCount: hiResCount,
        )
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

private extension FetchDescriptor {
    func withoutLimit() -> Self {
        var copy = self
        copy.fetchLimit = nil
        copy.fetchOffset = nil
        return copy
    }
}
