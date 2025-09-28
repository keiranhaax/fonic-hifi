//
//  LibraryRepository.swift
//  Fonic HiFi
//
//  Created by Codex on 3/6/26.
//
//  Abstractions for accessing library data. The archived plan expected a
//  repository-centric domain boundary so that SwiftUI views and use cases
//  never touch SwiftData directly. These protocols establish that boundary.
//

import Foundation

public struct Page<Element>: Sendable where Element: Sendable {
    public let items: [Element]
    public let hasMore: Bool
    public let nextPage: Int
    public let totalCount: Int?

    public init(items: [Element], hasMore: Bool, nextPage: Int, totalCount: Int? = nil) {
        self.items = items
        self.hasMore = hasMore
        self.nextPage = nextPage
        self.totalCount = totalCount
    }
}

public protocol LibraryRepository: Sendable {
    func tracks(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<TrackEntity>
    func albums(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<AlbumEntity>
    func artists(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<ArtistEntity>
    func playlists(page: Int, pageSize: Int, searchQuery: String?) async throws -> Page<PlaylistEntity>

    func recentAdditions(limit: Int) async throws -> [TrackEntity]
    func libraryStatistics() async throws -> LibraryStatisticsEntity
}

@MainActor
public protocol LibraryRepositoryFactory {
    func makeLibraryRepository() -> LibraryRepository
}

public struct LibraryStatisticsEntity: Sendable {
    public let trackCount: Int
    public let albumCount: Int
    public let artistCount: Int
    public let playlistCount: Int
    public let totalDuration: TimeInterval
    public let totalFileSize: Int64
    public let losslessTrackCount: Int
    public let hiResTrackCount: Int

    public init(
        trackCount: Int,
        albumCount: Int,
        artistCount: Int,
        playlistCount: Int,
        totalDuration: TimeInterval,
        totalFileSize: Int64,
        losslessTrackCount: Int,
        hiResTrackCount: Int,
    ) {
        self.trackCount = trackCount
        self.albumCount = albumCount
        self.artistCount = artistCount
        self.playlistCount = playlistCount
        self.totalDuration = totalDuration
        self.totalFileSize = totalFileSize
        self.losslessTrackCount = losslessTrackCount
        self.hiResTrackCount = hiResTrackCount
    }
}
