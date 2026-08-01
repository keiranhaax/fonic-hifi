@testable import Fonic_HiFi
import CoreFoundation
import SwiftData
import XCTest

@MainActor
final class LibraryStatisticsPerformanceTests: XCTestCase {
    private struct OnDiskFixture {
        let container: ModelContainer
        let storeURL: URL
    }

    private func makeOnDiskFixture() throws -> OnDiskFixture {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LibraryStatisticsPerformanceTests", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }

        let schema = Schema(versionedSchema: SchemaV3.self)
        let storeURL = directory.appendingPathComponent("Library.store")
        let configuration = ModelConfiguration(
            "LibraryStatisticsPerformanceFixture",
            schema: schema,
            url: storeURL,
            allowsSave: true,
            cloudKitDatabase: .none
        )
        return try OnDiskFixture(
            container: ModelContainer(
                for: schema,
                migrationPlan: FonicHiFiMigrationPlan.self,
                configurations: [configuration]
            ),
            storeURL: storeURL
        )
    }

    private func makeDataManager(container: ModelContainer) async -> DataManager {
        await MainActor.run {
            DataManager(container: container, isFallback: false)
        }
    }

    func testStatisticsAggregationPerformance() async throws {
        let laneStart = CFAbsoluteTimeGetCurrent()
        let laneBudget: TimeInterval = 30
        let fixture = try makeOnDiskFixture()
        let container = fixture.container
        let dataManager = await makeDataManager(container: container)
        let totalTracks = 10_000
        let aggregationBudget: TimeInterval = 1.8
        let cachedReadBudget: TimeInterval = 0.1
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
        XCTAssertTrue(
            FileManager.default.fileExists(atPath: fixture.storeURL.path),
            "The scale baseline must exercise a real on-disk SwiftData store"
        )

        let start = CFAbsoluteTimeGetCurrent()
        let statistics = try await dataManager.getLibraryStatistics()
        let elapsed = CFAbsoluteTimeGetCurrent() - start

        XCTAssertEqual(statistics.trackCount, totalTracks)
        XCTAssertEqual(statistics.losslessTrackCount, expectedLossless)
        XCTAssertEqual(statistics.hiResTrackCount, expectedHiRes)
        XCTAssertEqual(statistics.totalDuration, expectedDuration, accuracy: 0.0001)
        XCTAssertEqual(statistics.totalFileSize, expectedFileSize)
        XCTAssertLessThan(
            elapsed,
            aggregationBudget,
            "On-disk aggregation of \(totalTracks) tracks exceeded the \(aggregationBudget)s baseline"
        )
        XCTAssertEqual(dataManager.libraryStatisticsComputationCount, 1)

        let cachedStart = CFAbsoluteTimeGetCurrent()
        let cachedStatistics = try await dataManager.getLibraryStatistics()
        let cachedElapsed = CFAbsoluteTimeGetCurrent() - cachedStart

        XCTAssertEqual(cachedStatistics.trackCount, totalTracks)
        XCTAssertLessThan(
            cachedElapsed,
            cachedReadBudget,
            "Cached statistics exceeded the \(cachedReadBudget)s baseline"
        )
        XCTAssertEqual(dataManager.libraryStatisticsComputationCount, 1)

        let laneElapsed = CFAbsoluteTimeGetCurrent() - laneStart
        XCTAssertLessThan(
            laneElapsed,
            laneBudget,
            "The complete \(totalTracks)-track scale lane exceeded the \(laneBudget)s CI budget"
        )
    }
}
