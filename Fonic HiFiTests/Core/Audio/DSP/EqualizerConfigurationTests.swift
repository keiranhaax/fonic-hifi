@testable import Fonic_HiFi
import XCTest

final class EqualizerConfigurationTests: XCTestCase {
    func testDefaultConfiguration_has10Bands() {
        let config = EqualizerConfiguration.default
        XCTAssertEqual(config.bands.count, 10)
    }

    func testBands_haveCorrectFrequencies() {
        let config = EqualizerConfiguration.default
        let expectedFrequencies: [Float] = [32, 64, 125, 250, 500, 1000, 2000, 4000, 8000, 16000]
        for (index, band) in config.bands.enumerated() {
            XCTAssertEqual(band.frequency, expectedFrequencies[index])
        }
    }

    func testEQBand_clampsGainToValidRange() {
        let band = EQBand(frequency: 1000, gain: 20)
        XCTAssertEqual(band.gain, 12) // Max is +12 dB

        let band2 = EQBand(frequency: 1000, gain: -20)
        XCTAssertEqual(band2.gain, -12) // Min is -12 dB
    }

    func testDefaultConfiguration_isDisabled() {
        let config = EqualizerConfiguration.default
        XCTAssertFalse(config.isEnabled)
    }

    func testPresets_containsFlat() {
        XCTAssertNotNil(EqualizerConfiguration.presets["Flat"])
    }

    func testPresets_containsBassBoost() {
        let bassBoost = EqualizerConfiguration.presets["Bass Boost"]
        XCTAssertNotNil(bassBoost)
        // Bass boost should have elevated low frequencies
        XCTAssertGreaterThan(bassBoost?.bands[0].gain ?? 0, 0)
    }
}
