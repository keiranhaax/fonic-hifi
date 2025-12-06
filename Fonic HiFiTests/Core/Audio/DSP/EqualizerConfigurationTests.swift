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

    func testEQBand_clampsBandwidthToAppleValidRange() {
        // Test lower bound
        let tooNarrow = EQBand(frequency: 1000, gain: 0, bandwidth: 0.01)
        XCTAssertEqual(tooNarrow.bandwidth, 0.05, "Bandwidth should be clamped to minimum 0.05")

        // Test upper bound
        let tooWide = EQBand(frequency: 1000, gain: 0, bandwidth: 10.0)
        XCTAssertEqual(tooWide.bandwidth, 5.0, "Bandwidth should be clamped to maximum 5.0")

        // Test valid value passes through
        let valid = EQBand(frequency: 1000, gain: 0, bandwidth: 1.0)
        XCTAssertEqual(valid.bandwidth, 1.0, "Valid bandwidth should pass through unchanged")
    }

    func testEQBand_clampsFrequencyToAudibleRange() {
        // Test lower bound
        let tooLow = EQBand(frequency: 5, gain: 0, bandwidth: 1.0)
        XCTAssertEqual(tooLow.frequency, 20, "Frequency should be clamped to minimum 20 Hz")

        // Test upper bound
        let tooHigh = EQBand(frequency: 25000, gain: 0, bandwidth: 1.0)
        XCTAssertEqual(tooHigh.frequency, 20000, "Frequency should be clamped to maximum 20000 Hz")

        // Test valid value passes through
        let valid = EQBand(frequency: 1000, gain: 0, bandwidth: 1.0)
        XCTAssertEqual(valid.frequency, 1000, "Valid frequency should pass through unchanged")
    }

    // MARK: - Automatic Gain Compensation Tests

    func testPreampGain_reducesWhenBoosting() {
        var bands = EqualizerConfiguration.default.bands
        bands[0] = EQBand(frequency: 32, gain: 12.0)  // Max boost
        bands[1] = EQBand(frequency: 64, gain: 6.0)

        let config = EqualizerConfiguration(bands: bands, isEnabled: true)

        XCTAssertEqual(config.preampGain, -12.0, accuracy: 0.01, "Preamp should reduce by max boost")
    }

    func testPreampGain_zeroWhenCutting() {
        var bands = EqualizerConfiguration.default.bands
        bands[0] = EQBand(frequency: 32, gain: -12.0)  // Cut only

        let config = EqualizerConfiguration(bands: bands, isEnabled: true)

        XCTAssertEqual(config.preampGain, 0.0, "Preamp should be 0 when only cutting")
    }
}
