@testable import Fonic_HiFi
import XCTest

@MainActor
final class ImportValidationScenarioTests: XCTestCase {
    func testHighVolumeScenarioCompletesWithoutErrors() async throws {
        let environment = try makeImportTestEnvironment(
            metadataExtractor: SlowMetadataExtractor(delay: 0.0015),
            fileProcessingConcurrency: 3
        )
        let scenario = try makeNestedAudioDirectory(
            fileCountPerFolder: 12,
            depth: 3,
            branchingFactor: 2,
            duplicateCount: 0,
            testCase: self
        )

        await environment.service.executeImportPipeline(urls: [scenario.root])

        XCTAssertEqual(environment.service.totalFiles, scenario.totalFiles)
        XCTAssertEqual(environment.service.filesProcessed, scenario.totalFiles)
        XCTAssertEqual(environment.service.recentlyImported.count, scenario.totalFiles)
        XCTAssertTrue(environment.service.importErrors.isEmpty)
        XCTAssertEqual(environment.invalidationCount(), scenario.totalFiles)
        XCTAssertEqual(environment.service.importProgress, 1.0, accuracy: 0.0001)
        XCTAssertTrue(environment.service.statusMessage.contains("Import completed"))
    }

    func testDuplicateMixScenarioSkipsPreImportedFiles() async throws {
        let environment = try makeImportTestEnvironment(
            metadataExtractor: TestMetadataExtractor(),
            fileProcessingConcurrency: 2
        )
        let scenario = try makeNestedAudioDirectory(
            fileCountPerFolder: 6,
            depth: 2,
            branchingFactor: 2,
            duplicateCount: 4,
            testCase: self
        )

        try await seedTracks(in: environment, from: scenario.duplicateCandidates)

        await environment.service.executeImportPipeline(urls: [scenario.root])

        let expectedNewImports = scenario.totalFiles - scenario.duplicateCandidates.count
        XCTAssertEqual(environment.service.totalFiles, scenario.totalFiles)
        XCTAssertEqual(environment.service.filesProcessed, scenario.totalFiles)
        XCTAssertEqual(environment.service.recentlyImported.count, expectedNewImports)
        XCTAssertEqual(environment.invalidationCount(), expectedNewImports)
        XCTAssertEqual(environment.service.importErrors.count, scenario.duplicateCandidates.count)
        XCTAssertTrue(environment.service.importErrors.allSatisfy { $0.message.contains("Duplicate") })

        for url in scenario.duplicateCandidates {
            let bookmark = try? url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            let exists = try await environment.trackActor.trackExists(for: url, bookmark: bookmark) != nil
            XCTAssertTrue(exists, "Expected duplicate track to remain in library")
        }
    }
}
