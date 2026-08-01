//
//  PlaylistEditorViewModel.swift
//  Fonic HiFi
//

import Combine
import Foundation

@MainActor
final class PlaylistEditorViewModel: ObservableObject {
    @Published private(set) var state: PlaylistEditorState?
    @Published private(set) var isLoading = false
    @Published private(set) var isSaving = false
    @Published var alert: PlaylistEditorAlert?

    private let playlistID: UUID
    private let store: any PlaylistMutationStore
    private let mutationGate = AsyncSemaphore(value: 1)

    init(playlistID: UUID, store: any PlaylistMutationStore) {
        self.playlistID = playlistID
        self.store = store
    }

    var availableTracks: [PlaylistTrackSnapshot] {
        state?.availableTracks ?? []
    }

    func load() async {
        guard state == nil, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            state = try await store.playlistEditorState(playlistID: playlistID)
        } catch {
            present(error)
        }
    }

    func addTracks(_ trackIDs: [UUID]) async -> Bool {
        await performMutation {
            try await store.addTracks(trackIDs: trackIDs, toPlaylist: playlistID)
        }
    }

    func removeTracks(at offsets: IndexSet) async {
        guard let state else { return }
        let trackIDs = offsets.compactMap { offset in
            state.playlist.tracks.indices.contains(offset) ? state.playlist.tracks[offset].id : nil
        }
        guard !trackIDs.isEmpty else { return }

        _ = await performMutation {
            try await store.removeTracks(trackIDs: trackIDs, fromPlaylist: playlistID)
        }
    }

    func moveTracks(fromOffsets: IndexSet, toOffset: Int) async {
        guard !fromOffsets.isEmpty else { return }
        _ = await performMutation {
            try await store.movePlaylistTracks(
                playlistID: playlistID,
                fromOffsets: Array(fromOffsets),
                toOffset: toOffset
            )
        }
    }

    private func performMutation(
        _ operation: () async throws -> PlaylistEditorState
    ) async -> Bool {
        do {
            try await mutationGate.acquire()
        } catch {
            return false
        }

        isSaving = true

        do {
            state = try await operation()
            await mutationGate.release()
            isSaving = false
            return true
        } catch {
            await mutationGate.release()
            isSaving = false
            present(error)
            return false
        }
    }

    private func present(_ error: Error) {
        alert = PlaylistEditorAlert(
            message: (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        )
    }
}

struct PlaylistEditorAlert: Identifiable, Equatable {
    let id = UUID()
    let message: String
}
