@testable import Fonic_HiFi
import XCTest

final class BitPerfectFailureReasonTests: XCTestCase {
    func testUserFriendlyDescriptionsAreInformative() {
        let mismatch = BitPerfectFailureReason.sampleRateMismatch(source: 96_000, output: 48_000)
        XCTAssertTrue(mismatch.description.contains("96 kHz"))
        XCTAssertTrue(mismatch.description.contains("48 kHz"))

        let volume = BitPerfectFailureReason.volumeNotUnity(currentVolume: 0.72)
        XCTAssertTrue(volume.userFriendlyDescription.contains("72%"))

        let exclusive = BitPerfectFailureReason.exclusiveAccessBlocked(blockingApp: "Music")
        XCTAssertTrue(exclusive.userFriendlyDescription.contains("Music"))
    }

    func testSeverityAndResolutionClassification() {
        XCTAssertEqual(BitPerfectFailureReason.deviceNotBitPerfect(deviceName: "Speaker").severity, .critical)
        XCTAssertEqual(BitPerfectFailureReason.volumeNotUnity(currentVolume: 0.5).severity, .warning)
        XCTAssertTrue(BitPerfectFailureReason.audioProcessingEnabled(effects: ["EQ"]).isAutoResolvable)
        XCTAssertTrue(BitPerfectFailureReason.volumeNotUnity(currentVolume: 0.5).resolutionSteps.contains(where: { $0.contains("Set system volume") }))
    }

    func testFormatCompatibilityChoosesMostSpecificReason() {
        let info = AudioFileInfo(
            url: URL(fileURLWithPath: "/tmp/track.flac"),
            format: .flac,
            duration: 120,
            bitDepth: 24,
            sampleRate: 192_000,
            channels: 2,
            fileSize: 1024
        )

        let limitedDevice = AudioDevice(
            id: "dac",
            name: "USB DAC",
            type: .usbDAC,
            isOutput: true,
            supportedSampleRates: [44_100, 48_000],
            supportedBitDepths: [16],
            maxChannels: 2,
            supportsBitPerfect: true
        )

        let reason = BitPerfectFailureReason.formatCompatibility(
            sourceFormat: info,
            deviceCapabilities: limitedDevice
        )

        switch reason {
        case let .deviceSampleRateNotSupported(required, _):
            XCTAssertEqual(required, 192_000)
        default:
            XCTFail("Expected sample rate limitation")
        }
    }

    func testGroupingAndMostCriticalHelpers() {
        let reasons: [BitPerfectFailureReason] = [
            .volumeNotUnity(currentVolume: 0.7),
            .deviceNotBitPerfect(deviceName: "Speaker"),
            .audioProcessingEnabled(effects: ["EQ"])
        ]

        let grouped = BitPerfectFailureReason.groupBySeverity(reasons)
        XCTAssertEqual(grouped[.critical]?.count, 1)
        XCTAssertEqual(grouped[.warning]?.count, 1)

        let mostCritical = BitPerfectFailureReason.mostCritical(from: reasons)
        XCTAssertEqual(mostCritical, .deviceNotBitPerfect(deviceName: "Speaker"))
    }
}
