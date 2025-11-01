@testable import Fonic_HiFi
import CoreFoundation
import SwiftData
import XCTest

@MainActor
final class LibraryStatisticsPerformanceTests: XCTestCase {
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

    private func makeDataManager(container: ModelContainer) async -> DataManager {
        await MainActor.run {
            DataManager(container: container, isFallback: false)
        }
    }

    func testStatisticsAggregationPerformance() async throws {
        let container = try makeInMemoryContainer()
        let dataManager = await makeDataManager(container: container)
        let totalTracks = 10_000
        dataManager.libraryStatisticsCacheTTL = 10

        var expectedDuration: TimeInterval = 0
        var expectedFileSize: Int64 = 0
        var expectedLossless = 0
        var expectedHiRes = 0

        try await MainActor.run {
            for index in 0 ..< totalTracks {
                let isLossless = index % 2 == 0
                let isHiRes = isLossless && index % 4 == 0
                let duration = TimeInterval(180 + (index % 45))
                let fileSize = Int64(4_000_000 + (index % 1_000))

                let track = Track(
                    url: URL(fileURLWithPath: "/tmp/perf-track-\(index).flac"),
                    title: "Track-\(index)",
                    artist: "Artist-\(index % 50)",
                    album: "Album-\(index % 100)",
                    audioFormat: isLossless ? "FLAC" : "AAC",
                    duration: duration,
                    sampleRate: isHiRes ? 96_000 : 44_100,
                    bitDepth: isHiRes ? 24 : 16,
                    channels: 2,
                    isLossless: isLossless
                )

                track.fileSize = fileSize
                track.playCount = index % 10
                dataManager.mainContext.insert(track)

                expectedDuration += duration
                expectedFileSize += fileSize
                if isLossless { expectedLossless += 1 }
                if isHiRes { expectedHiRes += 1 }
            }
            try dataManager.mainContext.save()
        }

        let start = CFAbsoluteTimeGetCurrent()
        let statistics = try await dataManager.getLibraryStatistics()
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(statistics.trackCount, totalTracks)
        XCTAssertEqual(statistics.losslessTrackCount, expectedLossless)
        XCTAssertEqual(statistics.hiResTrackCount, expectedHiRes)
        XCTAssertEqual(statistics.totalDuration, expectedDuration, accuracy: 0.0001)
        XCTAssertEqual(statistics.totalFileSize, expectedFileSize)
        XCTAssertLessThan(elapsed, 1.8, "Statistics aggregation should remain performant for large libraries")
        XCTAssertEqual(dataManager.libraryStatisticsComputationCount, 1)

        let cachedStart = CFAbsoluteTimeGetCurrent()
        let cachedStatistics = try await dataManager.getLibraryStatistics()
        let cachedElapsed = CFAbsoluteTimeGetCurrent() - cachedStart

        XCTAssertEqual(cachedStatistics.trackCount, totalTracks)
        XCTAssertLessThan(cachedElapsed, 0.1, "Cached statistics should return near-instantly")
        XCTAssertEqual(dataManager.libraryStatisticsComputationCount, 1)
    }
}
