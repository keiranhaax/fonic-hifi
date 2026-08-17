//
//  TrackDataActor+Playlists.swift
//  Fonic HiFi
//

import Foundation
import SwiftData

struct PlaylistTrackSnapshot: Identifiable, Equatable, Sendable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
}

struct PlaylistMutationSnapshot: Equatable, Sendable {
    let id: UUID
    let name: String
    let playlistDescription: String?
    let isSmart: Bool
    let tracks: [PlaylistTrackSnapshot]
}

struct PlaylistEditorState: Equatable, Sendable {
    let playlist: PlaylistMutationSnapshot
    let libraryTracks: [PlaylistTrackSnapshot]

    var availableTracks: [PlaylistTrackSnapshot] {
        let existingIDs = Set(playlist.tracks.map(\.id))
        return libraryTracks.filter { !existingIDs.contains($0.id) }
    }
}

protocol PlaylistMutationStore: Sendable {
    func createPlaylist(
        name: String,
        description: String?,
        isSmart: Bool
    ) async throws -> PlaylistMutationSnapshot

    func playlistEditorState(playlistID: UUID) async throws -> PlaylistEditorState

    func addTracks(
        trackIDs: [UUID],
        toPlaylist playlistID: UUID
    ) async throws -> PlaylistEditorState

    func removeTracks(
        trackIDs: [UUID],
        fromPlaylist playlistID: UUID
    ) async throws -> PlaylistEditorState

    func movePlaylistTracks(
        playlistID: UUID,
        fromOffsets: [Int],
        toOffset: Int
    ) async throws -> PlaylistEditorState
}

extension TrackDataActor: PlaylistMutationStore {
    func createPlaylist(
        name: String,
        description: String?,
        isSmart: Bool
    ) async throws -> PlaylistMutationSnapshot {
        try requireMutationAllowed()
        let normalizedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw PlaylistMutationError.emptyName
        }

        let normalizedDescription = description?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let playlist = Playlist(
            name: normalizedName,
            playlistDescription: normalizedDescription?.isEmpty == true ? nil : normalizedDescription,
            type: isSmart ? .smart : .static
        )
        modelContext.insert(playlist)

        try savePlaylistMutation(operation: "create")
        return makePlaylistSnapshot(playlist)
    }

    func playlistEditorState(playlistID: UUID) async throws -> PlaylistEditorState {
        let playlist = try resolvePlaylist(with: playlistID)
        return try makePlaylistEditorState(playlist)
    }

    func addTracks(
        trackIDs: [UUID],
        toPlaylist playlistID: UUID
    ) async throws -> PlaylistEditorState {
        try requireMutationAllowed()
        let playlist = try resolveStaticPlaylist(with: playlistID)
        let requestedIDs = trackIDs.reduce(into: [UUID]()) { result, trackID in
            if !result.contains(trackID) {
                result.append(trackID)
            }
        }

        guard !requestedIDs.isEmpty else {
            return try makePlaylistEditorState(playlist)
        }

        let tracks = try resolveTracks(with: requestedIDs)
        let tracksByID = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, $0) })
        if let missingID = requestedIDs.first(where: { tracksByID[$0] == nil }) {
            throw PlaylistMutationError.trackNotFound(missingID)
        }
        var didChange = false

        for trackID in requestedIDs {
            guard let track = tracksByID[trackID] else {
                throw PlaylistMutationError.trackNotFound(trackID)
            }
            if !playlist.trackIds.contains(trackID) {
                playlist.trackIds.append(trackID)
                didChange = true
            }
            if !playlist.tracks.contains(where: { $0.id == trackID }) {
                playlist.tracks.append(track)
                didChange = true
            }
        }

        guard didChange else {
            return try makePlaylistEditorState(playlist)
        }
        playlist.dateModified = Date()

        try savePlaylistMutation(operation: "add tracks")
        return try makePlaylistEditorState(playlist)
    }

    func removeTracks(
        trackIDs: [UUID],
        fromPlaylist playlistID: UUID
    ) async throws -> PlaylistEditorState {
        try requireMutationAllowed()
        let playlist = try resolveStaticPlaylist(with: playlistID)
        let removedIDs = Set(trackIDs)
        guard !removedIDs.isEmpty, playlist.trackIds.contains(where: removedIDs.contains) else {
            return try makePlaylistEditorState(playlist)
        }

        playlist.trackIds.removeAll(where: removedIDs.contains)
        playlist.tracks.removeAll { removedIDs.contains($0.id) }
        playlist.dateModified = Date()

        try savePlaylistMutation(operation: "remove tracks")
        return try makePlaylistEditorState(playlist)
    }

    func movePlaylistTracks(
        playlistID: UUID,
        fromOffsets: [Int],
        toOffset: Int
    ) async throws -> PlaylistEditorState {
        try requireMutationAllowed()
        let playlist = try resolveStaticPlaylist(with: playlistID)
        let offsets = Array(Set(fromOffsets)).sorted()

        guard !offsets.isEmpty else {
            return try makePlaylistEditorState(playlist)
        }
        guard
            offsets.allSatisfy(playlist.trackIds.indices.contains),
            (0 ... playlist.trackIds.count).contains(toOffset)
        else {
            throw PlaylistMutationError.invalidMove
        }

        let movedIDs = offsets.map { playlist.trackIds[$0] }
        for offset in offsets.reversed() {
            playlist.trackIds.remove(at: offset)
        }

        let removedBeforeDestination = offsets.filter { $0 < toOffset }.count
        let insertionIndex = toOffset - removedBeforeDestination
        playlist.trackIds.insert(contentsOf: movedIDs, at: insertionIndex)
        playlist.dateModified = Date()

        try savePlaylistMutation(operation: "reorder tracks")
        return try makePlaylistEditorState(playlist)
    }

    private func resolvePlaylist(with id: UUID) throws -> Playlist {
        var descriptor = FetchDescriptor<Playlist>(
            predicate: #Predicate<Playlist> { playlist in
                playlist.id == id
            }
        )
        descriptor.fetchLimit = 1

        do {
            guard let playlist = try modelContext.fetch(descriptor).first else {
                throw PlaylistMutationError.playlistNotFound(id)
            }
            return playlist
        } catch let error as PlaylistMutationError {
            throw error
        } catch {
            throw PlaylistMutationError.persistenceFailure(
                operation: "fetch playlist",
                reason: error.localizedDescription
            )
        }
    }

    private func resolveStaticPlaylist(with id: UUID) throws -> Playlist {
        let playlist = try resolvePlaylist(with: id)
        guard playlist.type == .static else {
            throw PlaylistMutationError.smartPlaylistIsReadOnly
        }
        return playlist
    }

    private func resolveTracks(with ids: [UUID]) throws -> [Track] {
        let descriptor = FetchDescriptor<Track>(
            predicate: #Predicate<Track> { track in
                ids.contains(track.id)
            }
        )

        do {
            return try modelContext.fetch(descriptor)
        } catch {
            throw PlaylistMutationError.persistenceFailure(
                operation: "fetch tracks",
                reason: error.localizedDescription
            )
        }
    }

    private func makePlaylistEditorState(_ playlist: Playlist) throws -> PlaylistEditorState {
        let descriptor = FetchDescriptor<Track>(
            sortBy: [
                SortDescriptor(\Track.title),
                SortDescriptor(\Track.artist),
            ]
        )

        do {
            let libraryTracks = try modelContext.fetch(descriptor).map(makeTrackSnapshot)
            return PlaylistEditorState(
                playlist: makePlaylistSnapshot(playlist),
                libraryTracks: libraryTracks
            )
        } catch {
            throw PlaylistMutationError.persistenceFailure(
                operation: "refresh playlist",
                reason: error.localizedDescription
            )
        }
    }

    private func makePlaylistSnapshot(_ playlist: Playlist) -> PlaylistMutationSnapshot {
        let tracksByID = playlist.tracks.reduce(into: [UUID: Track]()) { result, track in
            result[track.id] = track
        }
        let orderedTracks = playlist.trackIds.compactMap { trackID in
            tracksByID[trackID].map(makeTrackSnapshot)
        }

        return PlaylistMutationSnapshot(
            id: playlist.id,
            name: playlist.name,
            playlistDescription: playlist.playlistDescription,
            isSmart: playlist.type == .smart,
            tracks: orderedTracks
        )
    }

    private func makeTrackSnapshot(_ track: Track) -> PlaylistTrackSnapshot {
        PlaylistTrackSnapshot(
            id: track.id,
            title: track.title,
            artist: track.artist,
            album: track.album,
            duration: track.duration
        )
    }

    private func savePlaylistMutation(operation: String) throws {
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            throw PlaylistMutationError.persistenceFailure(
                operation: operation,
                reason: error.localizedDescription
            )
        }
    }
}

enum PlaylistMutationError: LocalizedError, Equatable, Sendable {
    case emptyName
    case playlistNotFound(UUID)
    case trackNotFound(UUID)
    case smartPlaylistIsReadOnly
    case invalidMove
    case persistenceFailure(operation: String, reason: String)

    var errorDescription: String? {
        switch self {
        case .emptyName:
            "Enter a playlist name."
        case .playlistNotFound:
            "The playlist is no longer available."
        case .trackNotFound:
            "One of the selected tracks is no longer available."
        case .smartPlaylistIsReadOnly:
            "Smart playlist contents are managed by their rules."
        case .invalidMove:
            "The playlist order changed before the move could be saved."
        case let .persistenceFailure(operation, reason):
            "Unable to \(operation): \(reason)"
        }
    }
}
