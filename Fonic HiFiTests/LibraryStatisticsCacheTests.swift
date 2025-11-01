@testable import Fonic_HiFi
import SwiftData
import XCTest

@MainActor
final class LibraryStatisticsCacheTests: XCTestCase {
    private func makeInMemoryContainer() throws -> ModelContainer {
        let schema = Schema(SchemaV2.models)
        let configuration = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: true,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    private func seedTracks(_ count: Int, dataManager: DataManager) throws {
        for index in 0 ..< count {
            let track = Track(
                url: URL(fileURLWithPath: "/tmp/cache-track-\(index).flac"),
                title: "Track-\(index)",
                artist: "Artist-\(index)",
                album: "Album-\(index % 3)",
                audioFormat: "FLAC",
                duration: 200,
                sampleRate: 48_000,
                bitDepth: 24,
                channels: 2,
                isLossless: true
            )

            track.fileSize = 4_000_000
            dataManager.mainContext.insert(track)
        }

        try dataManager.mainContext.save()
    }

    func testDataManagerCacheAvoidsRecomputation() async throws {
        let container = try makeInMemoryContainer()
        let dataManager = DataManager(container: container, isFallback: false)
        dataManager.libraryStatisticsCacheTTL = 5
        try seedTracks(5, dataManager: dataManager)

        _ = try await dataManager.getLibraryStatistics()
        XCTAssertEqual(dataManager.libraryStatisticsComputationCount, 1)

        _ = try await dataManager.getLibraryStatistics()
        XCTAssertEqual(dataManager.libraryStatisticsComputationCount, 1)
    }

    func testDataManagerCacheExpiresAfterTTL() async throws {
        let container = try makeInMemoryContainer()
        let dataManager = DataManager(container: container, isFallback: false)
        dataManager.libraryStatisticsCacheTTL = 0.05
        try seedTracks(2, dataManager: dataManager)

        _ = try await dataManager.getLibraryStatistics()
        XCTAssertEqual(dataManager.libraryStatisticsComputationCount, 1)

        try await Task.sleep(nanoseconds: 100_000_000)

        _ = try await dataManager.getLibraryStatistics()
        XCTAssertEqual(dataManager.libraryStatisticsComputationCount, 2)
    }

    func testRepositoryCacheAvoidsRecomputation() async throws {
        let container = try makeInMemoryContainer()
        let dataManager = DataManager(container: container, isFallback: false)
        try seedTracks(3, dataManager: dataManager)

        let repository = SwiftDataLibraryRepository(container: container)
        await repository.updateStatisticsCacheTTL(5)

        _ = try await repository.libraryStatistics()
        let firstCount = await repository.statisticsComputationCount
        XCTAssertEqual(firstCount, 1)

        _ = try await repository.libraryStatistics()
        let secondCount = await repository.statisticsComputationCount
        XCTAssertEqual(secondCount, 1)
    }
}
