@testable import Fonic_HiFi
import SwiftData
import XCTest

final class MigrationPlanTests: XCTestCase {
    @MainActor
    func testMigrationBackfillsBookmarkHashes() throws {
        let schema = Schema(SchemaV2.models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )

        let container = try ModelContainer(for: schema, configurations: [configuration])
        let context = container.mainContext

        let bookmark = Data("migration-bookmark".utf8)

        let track = Track(
            url: URL(fileURLWithPath: "/tmp/library/track.flac"),
            title: "Track",
            artist: "Artist",
            album: "Album",
            audioFormat: "FLAC",
            duration: 120,
            sampleRate: 44_100,
            bitDepth: 16,
            channels: 2,
            isLossless: true
        )
        track.sourceURLBookmark = bookmark
        track.sourceBookmarkHash = nil
        track.sourceURLString = "file:///tmp/original/track.flac"
        track.sourceURLHash = nil

        context.insert(track)
        try context.save()

        try RecentSearchMigrationPlan.migrateTrackBookmarkHashes(in: context)

        XCTAssertEqual(track.sourceBookmarkHash, bookmark.sha256Hex())

        if let sourceString = track.sourceURLString,
           let sourceURL = URL(string: sourceString) {
            XCTAssertEqual(track.sourceURLHash, sourceURL.librarySourceHash())
        } else {
            XCTFail("Expected source URL string to be preserved")
        }
    }
}
