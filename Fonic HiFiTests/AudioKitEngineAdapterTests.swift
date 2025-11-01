@testable import Fonic_HiFi
import XCTest

@MainActor
final class AudioKitEngineAdapterTests: XCTestCase {
    func testSetVolumeClampsBetweenZeroAndOne() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        await adapter.setVolume(1.5)
        let highVolume = await adapter.volume
        XCTAssertEqual(highVolume, 1.0, accuracy: 0.0001)

        await adapter.setVolume(-0.5)
        let lowVolume = await adapter.volume
        XCTAssertEqual(lowVolume, 0.0, accuracy: 0.0001)
    }

    func testIsBitPerfectReflectsConfigurationAndReplayGain() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        try await adapter.configure(with: .bitPerfect)

        await adapter.applyReplayGain(0)
        let bitPerfect = await adapter.isBitPerfect
        XCTAssertTrue(bitPerfect)

        await adapter.applyReplayGain(-6)
        let notBitPerfect = await adapter.isBitPerfect
        XCTAssertFalse(notBitPerfect)
    }

    func testLoadInitializesDurationAndResetsTime() async throws {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            throw XCTSkip("AudioKit engine failed to initialize in test environment")
        }

        let url = try makePCMTestAudioFile(testCase: self)
        try await adapter.load(url: url)

        let duration = await adapter.duration
        XCTAssertGreaterThan(duration, 0)
        let currentTime = await adapter.currentTime
        XCTAssertEqual(currentTime, 0, accuracy: 0.0001)
        let playing = await adapter.isPlaying
        XCTAssertFalse(playing)
    }

    func testSeekWithoutLoadedFileThrows() async {
        let adapter = AudioKitEngineAdapter()
        guard adapter.isInitialized else {
            return
        }

        do {
            try await adapter.seek(to: 1.0)
            XCTFail("Expected seek without loaded file to throw")
        } catch {
            // Expected path
        }
    }
}
