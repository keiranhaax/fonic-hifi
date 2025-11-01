import AVFoundation
@testable import Fonic_HiFi
import XCTest

final class AVAudioEngineConfigTests: XCTestCase {
    func testOptimalBufferSizeMatchesPerformanceModeIntent() {
        XCTAssertEqual(AVAudioEngineConfig.optimalBufferSize(for: .efficiency), 4096)
        XCTAssertEqual(AVAudioEngineConfig.optimalBufferSize(for: .balanced), 512)
        XCTAssertEqual(AVAudioEngineConfig.optimalBufferSize(for: .quality), 2048)
    }

    func testNearestSupportedSampleRateReturnsClosestValue() {
        XCTAssertEqual(AVAudioEngineConfig.nearestSupportedSampleRate(to: 96000), 96000)
        XCTAssertEqual(AVAudioEngineConfig.nearestSupportedSampleRate(to: 47000), 48000)
        XCTAssertEqual(AVAudioEngineConfig.nearestSupportedSampleRate(to: 1000), 44100)
    }

    func testSampleRateConverterSettingsRespectPerformanceMode() {
        let balanced = AVAudioEngineConfig.sampleRateConverterSettings(quality: .balanced)
        let quality = AVAudioEngineConfig.sampleRateConverterSettings(quality: .quality)
        let efficiency = AVAudioEngineConfig.sampleRateConverterSettings(quality: .efficiency)

        XCTAssertEqual(balanced[AVSampleRateConverterAudioQualityKey] as? Int32, Int32(AVAudioQuality.medium.rawValue))
        XCTAssertEqual(quality[AVSampleRateConverterAudioQualityKey] as? Int32, Int32(AVAudioQuality.max.rawValue))
        XCTAssertEqual(efficiency[AVSampleRateConverterAudioQualityKey] as? Int32, Int32(AVAudioQuality.low.rawValue))

        XCTAssertEqual(balanced[AVSampleRateConverterAlgorithmKey] as? String, AVSampleRateConverterAlgorithm_Normal)
    }

    func testRenderQualityAndIoBufferDurationAlignWithMode() {
        XCTAssertEqual(AVAudioEngineConfig.renderQuality(for: .balanced), .high)
        XCTAssertEqual(AVAudioEngineConfig.renderQuality(for: .quality), .max)
        XCTAssertEqual(AVAudioEngineConfig.renderQuality(for: .efficiency), .medium)

        XCTAssertEqual(AVAudioEngineConfig.ioBufferDuration(for: .balanced), 0.005, accuracy: 0.0001)
        XCTAssertEqual(AVAudioEngineConfig.ioBufferDuration(for: .quality), 0.010, accuracy: 0.0001)
        XCTAssertEqual(AVAudioEngineConfig.ioBufferDuration(for: .efficiency), 0.023, accuracy: 0.0001)
    }

    func testFormatSupportAndResamplingDecisions() {
        XCTAssertTrue(AVAudioEngineConfig.isFormatNativelySupported(.aac))
        XCTAssertFalse(AVAudioEngineConfig.isFormatNativelySupported(.flac))

        XCTAssertFalse(AVAudioEngineConfig.needsSampleRateConversion(sourceRate: 44100, outputRate: 44100, allowResampling: true))
        XCTAssertTrue(AVAudioEngineConfig.needsSampleRateConversion(sourceRate: 44100, outputRate: 96000, allowResampling: false))
        XCTAssertFalse(AVAudioEngineConfig.needsSampleRateConversion(sourceRate: 44100, outputRate: 88200, allowResampling: true))
        XCTAssertTrue(AVAudioEngineConfig.needsSampleRateConversion(sourceRate: 44100, outputRate: 96000, allowResampling: true))
    }
}
