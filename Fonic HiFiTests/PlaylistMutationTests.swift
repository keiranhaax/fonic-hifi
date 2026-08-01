@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

@MainActor
final class PlaylistMutationTests: XCTestCase {
    func testCreateAddReorderAndRemoveSurviveStoreRelaunch() async throws {
        let storeURL = try makeStoreURL()
        let firstTrackID: UUID
        let secondTrackID: UUID
        let thirdTrackID: UUID
        let playlistID: UUID

        do {
            let container = try makeContainer(at: storeURL)
            let context = container.mainContext
            let firstTrack = makeTrack(title: "First")
            let secondTrack = makeTrack(title: "Second")
            let thirdTrack = makeTrack(title: "Third")
            context.insert(firstTrack)
            context.insert(secondTrack)
            context.insert(thirdTrack)
            try context.save()

            firstTrackID = firstTrack.id
            secondTrackID = secondTrack.id
            thirdTrackID = thirdTrack.id

            let actor = TrackDataActor(modelContainer: container)
            let created = try await actor.createPlaylist(
                name: "  Road Trip  ",
                description: "  Driving music  ",
                isSmart: false
            )
            playlistID = created.id

            let added = try await actor.addTracks(
                trackIDs: [firstTrackID, secondTrackID, thirdTrackID, firstTrackID],
                toPlaylist: playlistID
            )
            XCTAssertEqual(
                added.playlist.tracks.map(\.id),
                [firstTrackID, secondTrackID, thirdTrackID]
            )

            let reordered = try await actor.movePlaylistTracks(
                playlistID: playlistID,
                fromOffsets: [2],
                toOffset: 0
            )
            XCTAssertEqual(
                reordered.playlist.tracks.map(\.id),
                [thirdTrackID, firstTrackID, secondTrackID]
            )

            let removed = try await actor.removeTracks(
                trackIDs: [firstTrackID],
                fromPlaylist: playlistID
            )
            XCTAssertEqual(
                removed.playlist.tracks.map(\.id),
                [thirdTrackID, secondTrackID]
            )
        }

        do {
            let relaunchedContainer = try makeContainer(at: storeURL)
            let relaunchedActor = TrackDataActor(modelContainer: relaunchedContainer)
            let state = try await relaunchedActor.playlistEditorState(playlistID: playlistID)

            XCTAssertEqual(state.playlist.name, "Road Trip")
            XCTAssertEqual(state.playlist.playlistDescription, "Driving music")
            XCTAssertEqual(
                state.playlist.tracks.map(\.id),
                [thirdTrackID, secondTrackID]
            )

            let context = relaunchedContainer.mainContext
            let tracks = try context.fetch(FetchDescriptor<Track>())
            let playlists = try context.fetch(FetchDescriptor<Playlist>())
            let playlist = try XCTUnwrap(playlists.first)

            XCTAssertEqual(tracks.count, 3, "Playlist mutations must never delete library tracks")
            XCTAssertEqual(Set(playlist.tracks.map(\.id)), [secondTrackID, thirdTrackID])
            XCTAssertEqual(playlist.trackIds, [thirdTrackID, secondTrackID])
            XCTAssertTrue(
                tracks.first(where: { $0.id == firstTrackID })?.playlists.isEmpty == true,
                "Removing membership must nullify the inverse without deleting the track"
            )

            context.delete(playlist)
            try context.save()
            XCTAssertEqual(
                try context.fetchCount(FetchDescriptor<Track>()),
                3,
                "Deleting a playlist must nullify membership rather than cascade-delete tracks"
            )
        }
    }

    func testSmartPlaylistRejectsManualTrackMutations() async throws {
        let container = try makeInMemoryContainer()
        let track = makeTrack(title: "Managed")
        container.mainContext.insert(track)
        try container.mainContext.save()

        let actor = TrackDataActor(modelContainer: container)
        let playlist = try await actor.createPlaylist(
            name: "Smart",
            description: nil,
            isSmart: true
        )

        do {
            _ = try await actor.addTracks(
                trackIDs: [track.id],
                toPlaylist: playlist.id
            )
            XCTFail("A smart playlist must reject manual membership changes")
        } catch {
            XCTAssertEqual(error as? PlaylistMutationError, .smartPlaylistIsReadOnly)
        }

        let state = try await actor.playlistEditorState(playlistID: playlist.id)
        XCTAssertTrue(state.playlist.tracks.isEmpty)
    }

    func testAddTracksValidatesAllIDsBeforeChangingPlaylist() async throws {
        let container = try makeInMemoryContainer()
        let track = makeTrack(title: "Available")
        container.mainContext.insert(track)
        try container.mainContext.save()

        let actor = TrackDataActor(modelContainer: container)
        let playlist = try await actor.createPlaylist(
            name: "Atomic",
            description: nil,
            isSmart: false
        )
        let missingID = UUID()

        do {
            _ = try await actor.addTracks(
                trackIDs: [track.id, missingID],
                toPlaylist: playlist.id
            )
            XCTFail("A missing track must reject the complete mutation")
        } catch {
            XCTAssertEqual(error as? PlaylistMutationError, .trackNotFound(missingID))
        }

        let state = try await actor.playlistEditorState(playlistID: playlist.id)
        XCTAssertTrue(state.playlist.tracks.isEmpty)
    }

    func testViewModelUsesMutationResultWithoutSecondRefresh() async {
        let playlistID = UUID()
        let firstTrack = makeTrackSnapshot(title: "First")
        let secondTrack = makeTrackSnapshot(title: "Second")
        let initialState = makeEditorState(
            playlistID: playlistID,
            playlistTracks: [firstTrack],
            libraryTracks: [firstTrack, secondTrack]
        )
        let updatedState = makeEditorState(
            playlistID: playlistID,
            playlistTracks: [firstTrack, secondTrack],
            libraryTracks: [firstTrack, secondTrack]
        )
        let store = PlaylistMutationStoreSpy(
            initialState: initialState,
            mutationState: updatedState
        )
        let viewModel = PlaylistEditorViewModel(playlistID: playlistID, store: store)

        await viewModel.load()
        let didAdd = await viewModel.addTracks([secondTrack.id])

        XCTAssertTrue(didAdd)
        XCTAssertEqual(viewModel.state, updatedState)
        let counts = await store.callCounts()
        XCTAssertEqual(counts.loads, 1)
        XCTAssertEqual(counts.adds, 1)
    }

    private func makeStoreURL() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlaylistMutationTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        return directory.appendingPathComponent("Library.store")
    }

    private func makeContainer(at storeURL: URL) throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let configuration = ModelConfiguration(
            "PlaylistMutationFixture",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: FonicHiFiMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(versionedSchema: SchemaV3.self)
        let configuration = ModelConfiguration(
            "PlaylistMutationFixture",
            schema: schema,
            isStoredInMemoryOnly: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(
            for: schema,
            migrationPlan: FonicHiFiMigrationPlan.self,
            configurations: [configuration]
        )
    }

    private func makeTrack(title: String) -> Track {
        Track(
            url: FileManager.default.temporaryDirectory
                .appendingPathComponent("\(UUID().uuidString).flac"),
            title: title,
            artist: "Fixture Artist",
            album: "Fixture Album",
            audioFormat: "FLAC",
            duration: 180
        )
    }
}

private actor PlaylistMutationStoreSpy: PlaylistMutationStore {
    private let initialState: PlaylistEditorState
    private let mutationState: PlaylistEditorState
    private var loadCount = 0
    private var addCount = 0

    init(initialState: PlaylistEditorState, mutationState: PlaylistEditorState) {
        self.initialState = initialState
        self.mutationState = mutationState
    }

    func createPlaylist(
        name _: String,
        description _: String?,
        isSmart _: Bool
    ) async throws -> PlaylistMutationSnapshot {
        initialState.playlist
    }

    func playlistEditorState(playlistID _: UUID) async throws -> PlaylistEditorState {
        loadCount += 1
        return initialState
    }

    func addTracks(
        trackIDs _: [UUID],
        toPlaylist _: UUID
    ) async throws -> PlaylistEditorState {
        addCount += 1
        return mutationState
    }

    func removeTracks(
        trackIDs _: [UUID],
        fromPlaylist _: UUID
    ) async throws -> PlaylistEditorState {
        mutationState
    }

    func movePlaylistTracks(
        playlistID _: UUID,
        fromOffsets _: [Int],
        toOffset _: Int
    ) async throws -> PlaylistEditorState {
        mutationState
    }

    func callCounts() -> (loads: Int, adds: Int) {
        (loadCount, addCount)
    }
}

private func makeTrackSnapshot(title: String) -> PlaylistTrackSnapshot {
    PlaylistTrackSnapshot(
        id: UUID(),
        title: title,
        artist: "Fixture Artist",
        album: "Fixture Album",
        duration: 180
    )
}

private func makeEditorState(
    playlistID: UUID,
    playlistTracks: [PlaylistTrackSnapshot],
    libraryTracks: [PlaylistTrackSnapshot]
) -> PlaylistEditorState {
    PlaylistEditorState(
        playlist: PlaylistMutationSnapshot(
            id: playlistID,
            name: "Fixture Playlist",
            playlistDescription: nil,
            isSmart: false,
            tracks: playlistTracks
        ),
        libraryTracks: libraryTracks
    )
}
