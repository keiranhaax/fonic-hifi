@testable import Fonic_HiFi
import XCTest

final class AudioDeviceTests: XCTestCase {
    func testCapabilityChecksRespectSupportedRatesAndDepths() {
        let device = AudioDevice(
            id: "dac-1",
            name: "Reference DAC",
            isOutput: true,
            supportedSampleRates: [44_100, 96_000, 192_000],
            supportedBitDepths: [16, 24],
            maxChannels: 2,
            supportsBitPerfect: true
        )

        XCTAssertTrue(device.supports(sampleRate: 96_000))
        XCTAssertFalse(device.supports(sampleRate: 48_000))
        XCTAssertTrue(device.supports(bitDepth: 24))
        XCTAssertFalse(device.supports(bitDepth: 32))

        let info = makeInfo(sampleRate: 96_000, bitDepth: 24, channels: 2)
        XCTAssertTrue(device.supports(format: info))

        let tooManyChannels = makeInfo(sampleRate: 96_000, bitDepth: 24, channels: 6)
        XCTAssertFalse(device.supports(format: tooManyChannels))
    }

    func testOptimalBufferSizeClampsWithinBounds() {
        let device = AudioDevice(
            id: "dac-2",
            name: "Studio DAC",
            isOutput: true,
            supportedSampleRates: [44_100, 96_000, 192_000],
            supportedBitDepths: [24],
            maxChannels: 2,
            supportsBitPerfect: true,
            minBufferSize: 128,
            maxBufferSize: 4096,
            preferredBufferSize: 512
        )

        // High sample rate prefers lower latency but respects min buffer size.
        let hiRes = device.optimalBufferSize(for: 192_000)
        XCTAssertGreaterThanOrEqual(hiRes, 128)
        XCTAssertLessThanOrEqual(hiRes, 4096)

        // Standard rate should remain within allowable range and not exceed max.
        let standard = device.optimalBufferSize(for: 44_100)
        XCTAssertGreaterThanOrEqual(standard, 128)
        XCTAssertLessThanOrEqual(standard, 4096)
    }

    func testQualityIndicatorsAndDisplayHelpers() {
        let device = AudioDevice(
            id: "audiophile",
            name: String(repeating: "Long Device Name ", count: 4),
            type: .usbDAC,
            isOutput: true,
            connectionType: .usb,
            supportedSampleRates: [44_100, 192_000],
            supportedBitDepths: [16, 24, 32],
            supportsBitPerfect: true,
            qualityRating: .excellent
        )

        XCTAssertTrue(device.supportsHighResolution)
        XCTAssertTrue(device.isAudiophileGrade)
        XCTAssertTrue(device.capabilityString.contains("kHz"))
        XCTAssertLessThanOrEqual(device.displayName.count, 25)
    }

    func testFactoryHelpersProvideExpectedDefaults() {
        let speaker = AudioDevice.builtInSpeaker()
        XCTAssertEqual(speaker.id, "built-in-speaker")
        XCTAssertTrue(speaker.isOutput)
        XCTAssertEqual(speaker.connectionType, .builtin)
        XCTAssertFalse(speaker.supportsBitPerfect)

        let microphone = AudioDevice.builtInMicrophone()
        XCTAssertFalse(microphone.isOutput)
        XCTAssertEqual(microphone.maxChannels, 1)

        let headphones = AudioDevice.wiredHeadphones()
        XCTAssertEqual(headphones.type, .headphones)
        XCTAssertTrue(headphones.supportsBitPerfect)

        let dac = AudioDevice.usbDAC(name: "Chord Hugo")
        XCTAssertTrue(dac.supportsBitPerfect)
        XCTAssertTrue(dac.supportsHighResolution)
        XCTAssertEqual(dac.connectionType, .usb)
    }

    func testEnumUtilitiesExposeExpectedMetadata() {
        XCTAssertTrue(AudioDeviceType.usbDAC.supportsHighQuality)
        XCTAssertFalse(AudioDeviceType.bluetooth.supportsHighQuality)

        XCTAssertLessThan(AudioConnectionType.bluetooth.typicalLatency, 0.1)
        XCTAssertLessThan(AudioConnectionType.usb.typicalLatency, AudioConnectionType.bluetooth.typicalLatency)

        XCTAssertEqual(DeviceQuality.excellent.description, "Excellent")
        XCTAssertEqual(DeviceQuality.reference.emoji, "🏆")
    }

    // MARK: - Helpers

    private func makeInfo(
        sampleRate: Double,
        bitDepth: UInt16,
        channels: UInt8
    ) -> AudioFileInfo {
        AudioFileInfo(
            url: URL(fileURLWithPath: "/tmp/device-test.flac"),
            format: .flac,
            duration: 120,
            bitDepth: bitDepth,
            sampleRate: sampleRate,
            channels: channels,
            fileSize: 4_000_000
        )
    }
}
