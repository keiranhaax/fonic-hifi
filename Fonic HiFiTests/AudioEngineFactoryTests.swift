@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioEngineFactoryTests: XCTestCase {
    private let preferenceKey = AudioEnginePreference.storageKey

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

    func testEnabledEQRequiresAVAudioEngineForCompatibleFormat() throws {
        let preferences = try makePreferences()
        preferences.set(AudioEngineType.audioKitEngine.rawValue, forKey: preferenceKey)
        let factory = AudioEngineFactory(preferences: preferences)
        let configuration = AudioEngineConfiguration(
            performanceMode: .balanced,
            equalizerEnabled: true
        )

        XCTAssertEqual(
            factory.selectEngineType(for: .aac, configuration: configuration),
            .avAudioEngine
        )
    }

    func testEnabledEQPreservesFormatFallbackWhenNoEQEngineCanDecode() throws {
        let preferences = try makePreferences()
        preferences.set(AudioEngineType.avAudioEngine.rawValue, forKey: preferenceKey)
        let factory = AudioEngineFactory(preferences: preferences)
        let configuration = AudioEngineConfiguration(equalizerEnabled: true)

        // AVAudioEngine intentionally does not claim FLAC decoding. The
        // factory keeps AudioKit for format compatibility and the manager
        // reports EQ unsupported rather than lying about capability.
        XCTAssertEqual(
            factory.selectEngineType(for: .flac, configuration: configuration),
            .audioKitEngine
        )
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

    func testLegacyAudioKitPreferenceOverridesPerformanceModeAndMigrates() throws {
        let preferences = try makePreferences()
        preferences.set("AudioKit", forKey: preferenceKey)

        let factory = AudioEngineFactory(preferences: preferences)
        let configuration = AudioEngineConfiguration(performanceMode: .efficiency)

        let engine = factory.selectEngineType(for: .aac, configuration: configuration)

        XCTAssertEqual(engine, .audioKitEngine)
        XCTAssertEqual(preferences.string(forKey: preferenceKey), AudioEngineType.audioKitEngine.rawValue)
    }

    func testCanonicalAudioKitPreferenceSelectsAudioKit() throws {
        let preferences = try makePreferences()
        preferences.set(AudioEngineType.audioKitEngine.rawValue, forKey: preferenceKey)

        let factory = AudioEngineFactory(preferences: preferences)
        let configuration = AudioEngineConfiguration(performanceMode: .efficiency)

        let engine = factory.selectEngineType(for: .flac, configuration: configuration)

        XCTAssertEqual(engine, .audioKitEngine)
    }

    func testAVAudioEnginePreferenceOverridesBalancedModeWhenCompatible() throws {
        let preferences = try makePreferences()
        preferences.set(AudioEngineType.avAudioEngine.rawValue, forKey: preferenceKey)

        let factory = AudioEngineFactory(preferences: preferences)
        let configuration = AudioEngineConfiguration(performanceMode: .balanced)

        let engine = factory.selectEngineType(for: .aac, configuration: configuration)

        XCTAssertEqual(engine, .avAudioEngine)
    }

    func testIncompatibleAVAudioEnginePreferenceFallsBackDeterministically() throws {
        let preferences = try makePreferences()
        preferences.set(AudioEngineType.avAudioEngine.rawValue, forKey: preferenceKey)

        let factory = AudioEngineFactory(preferences: preferences)
        let configuration = AudioEngineConfiguration(performanceMode: .balanced)

        let engine = factory.selectEngineType(for: .flac, configuration: configuration)

        XCTAssertEqual(engine, .audioKitEngine)
    }

    func testUnavailableAudioKitPreferenceFallsBackToNativeEngine() throws {
        let preferences = try makePreferences()
        preferences.set(AudioEngineType.audioKitEngine.rawValue, forKey: preferenceKey)

        let factory = AudioEngineFactory(preferences: preferences)
        factory.registerEngine(.audioKitEngine, isAvailable: false)
        let configuration = AudioEngineConfiguration(performanceMode: .balanced)

        let engine = factory.selectEngineType(for: .aac, configuration: configuration)

        XCTAssertEqual(engine, .avAudioEngine)
    }

    func testUnknownPreferenceProducesTypedFallbackAndUsesAutomaticSelection() throws {
        let preferences = try makePreferences()
        preferences.set("FutureEngine", forKey: preferenceKey)

        let storedPreference = AudioEnginePreference(
            storedValue: preferences.string(forKey: preferenceKey)
        )
        let factory = AudioEngineFactory(preferences: preferences)
        let configuration = AudioEngineConfiguration(performanceMode: .balanced)

        let engine = factory.selectEngineType(for: .aac, configuration: configuration)

        XCTAssertEqual(storedPreference, .unsupported)
        XCTAssertEqual(engine, .audioKitEngine)
    }

    func testMakeEngineForURLUsesInjectedFormatDetector() async throws {
        let url = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("factory-injection")
            .appendingPathExtension("wav")

        let detectedInfo = AudioFileInfo(
            url: url,
            format: .wav,
            duration: 30,
            bitDepth: 16,
            sampleRate: 44_100,
            channels: 2,
            fileSize: 4_096
        )
        let detector = StubFormatDetectionService(fileInfo: detectedInfo)
        let factory = AudioEngineFactory(formatDetector: detector)
        let configuration = AudioEngineConfiguration(performanceMode: .efficiency)

        let engine = try await factory.makeEngine(for: url, configuration: configuration)

        XCTAssertTrue(engine is AVAudioEngineAdapter)
        let calls = await detector.detectCallCount()
        XCTAssertEqual(calls, 1)
    }

    private func makePreferences() throws -> UserDefaults {
        let suiteName = "AudioEngineFactoryTests.\(UUID().uuidString)"
        let preferences = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        preferences.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        }
        return preferences
    }
}

private actor StubFormatDetectionService: FormatDetectionService {
    private let fileInfo: AudioFileInfo
    private var calls = 0

    init(fileInfo: AudioFileInfo) {
        self.fileInfo = fileInfo
    }

    func detectFormat(at _: URL) async throws -> AudioFileInfo {
        calls += 1
        return fileInfo
    }

    func validateFile(at _: URL) async -> Bool { true }
    func isFormatSupported(_: AudioFormat) -> Bool { true }

    func getFormatCapabilities(_: AudioFormat) -> FormatCapabilities? {
        FormatCapabilities(
            maxSampleRate: 192_000,
            maxBitDepth: 24,
            supportsMultiChannel: true,
            supportsArtwork: true,
            supportsChapters: false,
            requiresSpecializedDecoder: false
        )
    }

    func detectCallCount() -> Int { calls }
}
