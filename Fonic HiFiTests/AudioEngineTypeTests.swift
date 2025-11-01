@testable import Fonic_HiFi
import XCTest

final class AudioEngineTypeTests: XCTestCase {
    func testDisplayInformationIsNonEmpty() {
        for engine in AudioEngineType.allCases {
            XCTAssertFalse(engine.displayName.isEmpty)
            XCTAssertFalse(engine.description.isEmpty)
        }
    }

    func testPreferredFormatsIncludeExpectedEntries() {
        XCTAssertTrue(AudioEngineType.avAudioEngine.preferredFormats.contains(.mp3))
        XCTAssertTrue(AudioEngineType.avAudioEngine.preferredFormats.contains(.aiff))

        XCTAssertTrue(AudioEngineType.audioKitEngine.preferredFormats.contains(.flac))
        XCTAssertTrue(AudioEngineType.audioKitEngine.preferredFormats.contains(.aac))
    }

    func testCanHandleMatchesEngineCapabilities() {
        XCTAssertTrue(AudioEngineType.avAudioEngine.canHandle(.aac))
        XCTAssertTrue(AudioEngineType.avAudioEngine.canHandle(.alac))
        XCTAssertFalse(AudioEngineType.avAudioEngine.canHandle(.flac))

        XCTAssertTrue(AudioEngineType.audioKitEngine.canHandle(.flac))
        XCTAssertFalse(AudioEngineType.audioKitEngine.canHandle(.dsd))
    }

    func testPerformanceImpactProvidesConsistentMetadata() {
        for impact in [PerformanceImpact.low, .medium, .high] {
            let range = impact.cpuUsageRange
            XCTAssertGreaterThanOrEqual(range.lowerBound, 0)
            XCTAssertFalse(impact.batteryImpactDescription.isEmpty)
        }

        XCTAssertEqual(PerformanceImpact.low.cpuUsageRange, 1 ... 5)
        XCTAssertEqual(PerformanceImpact.medium.cpuUsageRange, 5 ... 15)
        XCTAssertEqual(PerformanceImpact.high.cpuUsageRange, 15 ... 30)
    }
}
