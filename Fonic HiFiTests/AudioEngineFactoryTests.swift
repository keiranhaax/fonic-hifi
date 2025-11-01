@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioEngineFactoryTests: XCTestCase {
    private let preferenceKey = "preferredAudioEngine"

    override func tearDown() {
        UserDefaults.standard.removeObject(forKey: preferenceKey)
        super.tearDown()
    }

    func testBalancedPerformancePrefersAudioKitWhenAvailable() {
        let factory = AudioEngineFactory()
        let configuration = AudioEngineConfiguration(performanceMode: .balanced)

        let engine = factory.selectEngineType(for: .aac, configuration: configuration)

        XCTAssertEqual(engine, .audioKitEngine)
        XCTAssertTrue(factory.isEngineAvailable(.audioKitEngine))
    }

    func testEfficiencyModeFavorsNativeEngine() {
        let factory = AudioEngineFactory()
        let configuration = AudioEngineConfiguration(performanceMode: .efficiency)

        let engine = factory.selectEngineType(for: .alac, configuration: configuration)

        XCTAssertEqual(engine, .avAudioEngine)
    }

    func testFallsBackToNativeWhenAudioKitUnavailable() {
        let factory = AudioEngineFactory()
        factory.registerEngine(.audioKitEngine, isAvailable: false)

        let configuration = AudioEngineConfiguration(performanceMode: .quality)
        let engine = factory.selectEngineType(for: .flac, configuration: configuration)

        XCTAssertEqual(engine, .avAudioEngine)
        XCTAssertFalse(factory.isEngineAvailable(.audioKitEngine))
    }

    func testUnsupportedFormatFallsBackToNativeEngine() {
        let factory = AudioEngineFactory()
        let configuration = AudioEngineConfiguration(performanceMode: .quality)

        let engine = factory.selectEngineType(for: .dsd, configuration: configuration)

        XCTAssertEqual(engine, .avAudioEngine)
    }

    func testDiagnosticsSurfacesAlternatives() {
        let factory = AudioEngineFactory()
        let diagnostics = factory.diagnostics(for: .aac)

        XCTAssertEqual(diagnostics.preferredEngine, .audioKitEngine)
        XCTAssertTrue(diagnostics.alternativeEngines.contains(.avAudioEngine))
        XCTAssertTrue(diagnostics.isPreferredAvailable)
        XCTAssertFalse(diagnostics.summary.isEmpty)
    }

    func testRegisterEngineUpdatesAvailabilityAndListing() {
        let factory = AudioEngineFactory()
        factory.registerEngine(.audioKitEngine, isAvailable: false)

        XCTAssertFalse(factory.availableEngineTypes().contains(.audioKitEngine))

        factory.registerEngine(.audioKitEngine, isAvailable: true)

        XCTAssertTrue(factory.availableEngineTypes().contains(.audioKitEngine))
    }

    func testUserPreferenceOverridesPerformanceModeWhenEngineAvailable() {
        UserDefaults.standard.set("AudioKit", forKey: preferenceKey)

        let factory = AudioEngineFactory()
        let configuration = AudioEngineConfiguration(performanceMode: .efficiency)

        let engine = factory.selectEngineType(for: .aac, configuration: configuration)

        XCTAssertEqual(engine, .audioKitEngine)
    }
}
