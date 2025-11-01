import AVFoundation
@testable import Fonic_HiFi
import XCTest

@MainActor
final class BitPerfectCollaboratorsTests: XCTestCase {
    func testProcessingAnalyzerDetectsMultipleProcessingStages() {
        let analyzer = BitPerfectProcessingAnalyzer()
        let context = AudioSessionProcessingContext(
            isOtherAudioPlaying: true,
            outputVolume: 0.5,
            mode: .voiceChat,
            hasSpatialAudioEnabled: true,
            hasBluetoothOutput: false,
        )

        let detection = analyzer.detectProcessing(context: context)
        let detectedTypes = Set(detection.stages.map(\.type))

        XCTAssertTrue(detection.hasProcessing)
        XCTAssertTrue(detectedTypes.contains(.systemMixer))
        XCTAssertTrue(detectedTypes.contains(.volumeControl))
        XCTAssertTrue(detectedTypes.contains(.voiceProcessing))
        XCTAssertTrue(detectedTypes.contains(.spatialAudio))
        XCTAssertEqual(detection.stages.count, 4)
    }

    func testProcessingAnalyzerDetectsBluetoothCodec() {
        let analyzer = BitPerfectProcessingAnalyzer()
        let context = AudioSessionProcessingContext(
            isOtherAudioPlaying: false,
            outputVolume: 1.0,
            mode: .default,
            hasSpatialAudioEnabled: false,
            hasBluetoothOutput: true,
        )

        let detection = analyzer.detectProcessing(context: context)

        XCTAssertTrue(detection.hasProcessing)
        XCTAssertEqual(detection.stages.map(\.type), [.bluetoothCodec])
    }

    func testDeviceManagerCachesDACCompatibility() async {
        let manager = BitPerfectDeviceManager()
        let dacInfo = DACCompatibilityInfo(
            deviceIdentifier: "dac-test",
            manufacturer: "Acme",
            modelName: "Reference",
            connectionInterface: .usb,
            maxSampleRate: 192_000,
            maxBitDepth: 24,
        )

        await manager.updateDACCompatibility(dacInfo)
        let retrieved = await manager.dacCompatibility(for: "dac-test")

        XCTAssertEqual(retrieved, dacInfo)
    }

    func testDeviceManagerSupportsBitPerfectForHighQualityDevices() async {
        let manager = BitPerfectDeviceManager()
        let usbDevice = AudioDevice(
            id: "usb",
            name: "USB DAC",
            type: .usb,
            isOutput: true,
            connectionType: .usb,
            supportedSampleRates: [44100],
            supportedBitDepths: [16],
            supportsBitPerfect: true,
        )
        let builtInDevice = AudioDevice(
            id: "builtin",
            name: "Built-in Speaker",
            type: .builtIn,
            isOutput: true,
            connectionType: .builtin,
            supportedSampleRates: [44100],
            supportedBitDepths: [16],
            supportsBitPerfect: false,
        )

        let usbSupports = await manager.supportsBitPerfectPlayback(device: usbDevice)
        let builtInSupports = await manager.supportsBitPerfectPlayback(device: builtInDevice)

        XCTAssertTrue(usbSupports)
        XCTAssertFalse(builtInSupports)
    }

    func testRecommendationEngineProducesOptimalSettings() {
        let engine = BitPerfectRecommendationEngine()
        let format = AudioFileInfo(
            url: URL(fileURLWithPath: "/music/test.flac"),
            format: .flac,
            duration: 180,
            bitDepth: 24,
            sampleRate: 96000,
            channels: 2,
            fileSize: 42_000_000,
        )
        let capabilities = DeviceCapabilities(
            supportedSampleRates: [44100, 48000, 96000],
            maxBitDepth: 32,
            maxChannels: 2,
            supportsHardwareVolume: false,
            bypassesSystemMixer: true,
            bufferSizeRange: 128 ... 1024,
            supportsExclusiveMode: true,
        )

        let settings = engine.recommendedSettings(sourceFormat: format, deviceCapabilities: capabilities)

        XCTAssertEqual(settings.sampleRate, 96000)
        XCTAssertEqual(settings.bitDepth, 24)
        XCTAssertEqual(settings.bufferSize, 128)
        XCTAssertTrue(settings.useExclusiveMode)
        XCTAssertTrue(settings.bypassSystemVolume)
        XCTAssertEqual(settings.sessionCategory, AVAudioSession.Category.playback.rawValue)
    }

    func testRecommendationEngineProvidesAlternativesAndConversionAnalysis() {
        let engine = BitPerfectRecommendationEngine()
        let format = AudioFileInfo(
            url: URL(fileURLWithPath: "/music/highres.flac"),
            format: .flac,
            duration: 240,
            bitDepth: 24,
            sampleRate: 192_000,
            channels: 2,
            fileSize: 80_000_000,
        )
        let capabilities = DeviceCapabilities(
            supportedSampleRates: [44100, 48000],
            maxBitDepth: 16,
            maxChannels: 2,
        )

        let alternatives = engine.alternatives(sourceFormat: format, deviceCapabilities: capabilities)
        let analysis = engine.conversionAnalysis(sourceFormat: format, outputCapabilities: capabilities)
        let processingStages = [
            AudioProcessingStage(type: .volumeControl, description: "Volume", affectsBitPerfect: true, performanceImpact: 0.1),
        ]
        let impact = engine.performanceImpact(processingStages: processingStages, sourceFormat: format)
        let improvement = engine.expectedImprovementDescription(for: [
            ConfigurationChange(setting: "System Volume", currentValue: "80%", recommendedValue: "100%", reason: "Prevent scaling"),
        ])

        XCTAssertFalse(alternatives.isEmpty)
        XCTAssertTrue(analysis.conversionRequired)
        XCTAssertTrue(analysis.conversionTypes.contains(.sampleRate))
        XCTAssertTrue(analysis.conversionTypes.contains(.bitDepth))
        XCTAssertEqual(impact, .high)
        XCTAssertTrue(improvement.contains("remove digital volume scaling"))
    }
}
