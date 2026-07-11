@testable import Fonic_HiFi
import Foundation
import SwiftData
import XCTest

final class RecentSearchesActorTests: XCTestCase {
    private var container: ModelContainer!
    private var actor: RecentSearchesActor!

    override func setUpWithError() throws {
        try super.setUpWithError()
        let schema = Schema([RecentSearch.self])
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        container = try ModelContainer(for: schema, configurations: [configuration])
        actor = RecentSearchesActor(modelContainer: container)
    }

    override func tearDownWithError() throws {
        container = nil
        actor = nil
        try super.tearDownWithError()
    }

    func testAddSearchKeepsLatestTwentyEntries() async throws {
        for index in 0..<25 {
            try await actor.addSearch("query-\(index)")
        }

        let results = try await actor.getRecentSearches(limit: 30)
        XCTAssertEqual(results.count, 20)
        XCTAssertEqual(results.first?.query, "query-24")
        XCTAssertEqual(results.last?.query, "query-5")
    }

    func testUpdateResultCountPersists() async throws {
        try await actor.addSearch("ambient")
        try await actor.updateResultCount(for: "ambient", count: 42)

        let results = try await actor.getRecentSearches(limit: 1)
        XCTAssertEqual(results.first?.resultCount, 42)
    }

    func testAddSearchUpsertsNormalizedQueryAndMovesItToFront() async throws {
        try await actor.addSearch("Ambient")
        try await actor.updateResultCount(for: "ambient", count: 12)
        try await actor.addSearch("Focus")
        try await actor.addSearch("  AMBIENT\n")

        let results = try await actor.getRecentSearches(limit: 10)
        XCTAssertEqual(results.count, 2)
        XCTAssertEqual(results.map(\.query), ["Ambient", "Focus"])
        XCTAssertEqual(results.first?.resultCount, 12)
    }

    func testAddSearchIgnoresEmptyNormalizedQuery() async throws {
        try await actor.addSearch(" \n\t ")

        let results = try await actor.getRecentSearches(limit: 10)
        XCTAssertTrue(results.isEmpty)
    }

    func testRemoveSearchDeletesMatchingEntry() async throws {
        try await actor.addSearch("first")
        try await actor.addSearch("second")

        var all = try await actor.getRecentSearches(limit: 10)
        XCTAssertEqual(all.count, 2)

        if let first = all.last { // most recent is "second"
            try await actor.removeSearch(first)
        }

        all = try await actor.getRecentSearches(limit: 10)
        XCTAssertEqual(all.count, 1)
        XCTAssertEqual(all.first?.query, "second")
    }

    func testRemoveSearchUsesPersistentIdentityAfterUpsert() async throws {
        try await actor.addSearch("Ambient")
        let initialResults = try await actor.getRecentSearches(limit: 1)
        let original = try XCTUnwrap(initialResults.first)

        try await actor.addSearch(" ambient ")
        try await actor.removeSearch(original)

        let results = try await actor.getRecentSearches(limit: 10)
        XCTAssertTrue(results.isEmpty)
    }

    func testClearAllSearchesRemovesEverything() async throws {
        try await actor.addSearch("one")
        try await actor.addSearch("two")
        try await actor.clearAllSearches()

        let results = try await actor.getRecentSearches(limit: 10)
        XCTAssertTrue(results.isEmpty)
    }
}
