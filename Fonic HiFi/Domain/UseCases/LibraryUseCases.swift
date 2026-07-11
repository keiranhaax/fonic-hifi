//
//  LibraryUseCases.swift
//  Fonic HiFi
//
//  Created by Codex on 3/6/26.
//
//  Application use cases that orchestrate repository access. These mirror the
//  scenarios covered by the functional requirements (pagination, efficient
//  search, statistics).
//

import Foundation

public struct LibraryPaginationConfiguration: Sendable {
    public let pageSize: Int
    public let prefetchThreshold: Int

    public init(pageSize: Int = 100, prefetchThreshold: Int = 20) {
        self.pageSize = pageSize
        self.prefetchThreshold = prefetchThreshold
    }
}

public protocol FetchTracksPageUseCase: Sendable {
    func tracksPage(page: Int, query: String?) async throws -> Page<TrackEntity>
}

public protocol FetchAlbumsPageUseCase: Sendable {
    func albumsPage(page: Int, query: String?) async throws -> Page<AlbumEntity>
}

public protocol FetchArtistsPageUseCase: Sendable {
    func artistsPage(page: Int, query: String?) async throws -> Page<ArtistEntity>
}

public protocol FetchPlaylistsPageUseCase: Sendable {
    func playlistsPage(page: Int, query: String?) async throws -> Page<PlaylistEntity>
}

public protocol LoadLibraryStatisticsUseCase: Sendable {
    func libraryStatistics() async throws -> LibraryStatisticsEntity
}

public struct DefaultLibraryUseCases: FetchTracksPageUseCase, FetchAlbumsPageUseCase, FetchArtistsPageUseCase, FetchPlaylistsPageUseCase, LoadLibraryStatisticsUseCase, Sendable {
    private let repository: LibraryRepository
    private let configuration: LibraryPaginationConfiguration

    public init(repository: LibraryRepository, configuration: LibraryPaginationConfiguration = .init()) {
        self.repository = repository
        self.configuration = configuration
    }

    public func tracksPage(page: Int, query: String?) async throws -> Page<TrackEntity> {
        try await repository.tracks(page: page, pageSize: configuration.pageSize, searchQuery: query)
    }

    public func albumsPage(page: Int, query: String?) async throws -> Page<AlbumEntity> {
        try await repository.albums(page: page, pageSize: configuration.pageSize, searchQuery: query)
    }

    public func artistsPage(page: Int, query: String?) async throws -> Page<ArtistEntity> {
        try await repository.artists(page: page, pageSize: configuration.pageSize, searchQuery: query)
    }

    public func playlistsPage(page: Int, query: String?) async throws -> Page<PlaylistEntity> {
        try await repository.playlists(page: page, pageSize: configuration.pageSize, searchQuery: query)
    }

    public func libraryStatistics() async throws -> LibraryStatisticsEntity {
        try await repository.libraryStatistics()
    }
}
