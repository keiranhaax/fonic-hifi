//
//  BitPerfectValidatorTests.swift
//  Fonic HiFiTests
//
//  Created by Claude on 5/27/25.
//

import XCTest
import AVFoundation
@testable import Fonic_HiFi

@MainActor
final class BitPerfectValidatorTests: XCTestCase {
    
    var validator: BitPerfectValidator!
    var mockAudioSession: MockAVAudioSession!
    
    override func setUp() {
        super.setUp()
        mockAudioSession = MockAVAudioSession()
        validator = BitPerfectValidator(audioSession: mockAudioSession)
    }
    
    override func tearDown() {
        validator = nil
        mockAudioSession = nil
        super.tearDown()
    }
    
    // MARK: - Helper Methods
    
    private func createMockAudioFileInfo(
        format: AudioFormat = .flac,
        sampleRate: Int = 96000,
        bitDepth: Int = 24,
        channels: Int = 2
    ) -> AudioFileInfo {
        return AudioFileInfo(
            format: format,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            channels: channels,
            bitrate: nil,
            duration: 180.0,
            fileSize: 50_000_000
        )
    }
    
    private func createMockAudioDevice(
        id: String = "test_device",
        name: String = "Test DAC",
        type: AudioDeviceType = .usb,
        maxBitDepth: Int = 24,
        supportedSampleRates: [Int] = [44100, 48000, 96000, 192000]
    ) -> AudioDevice {
        return AudioDevice(
            id: id,
            name: name,
            supportedSampleRates: supportedSampleRates,
            maxBitDepth: maxBitDepth,
            isDefault: true,
            type: type
        )
    }
    
    // MARK: - Basic Validation Tests
    
    func testBitPerfectValidation_PerfectMatch() async {
        // Given
        let sourceFormat = createMockAudioFileInfo(sampleRate: 48000, bitDepth: 16)
        let device = createMockAudioDevice(supportedSampleRates: [44100, 48000])
        
        mockAudioSession.sampleRate = 48000
        mockAudioSession.outputVolume = 1.0
        mockAudioSession.isOtherAudioPlaying = false
        
        // When
        let result = await validator.validateBitPerfectPlayback(
            sourceFormat: sourceFormat,
            outputDevice: device
        )
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertTrue(result.sampleRateMatches)
        XCTAssertTrue(result.bitDepthMatches)
        XCTAssertTrue(result.channelCountMatches)
        XCTAssertNil(result.mismatchReason)
        XCTAssertTrue(result.validationIssues.isEmpty)
        XCTAssertTrue(result.volumeIsOptimal)
        XCTAssertEqual(result.compatibilityScore, 1.0)
    }
    
    func testBitPerfectValidation_SampleRateMismatch() async {
        // Given
        let sourceFormat = createMockAudioFileInfo(sampleRate: 96000, bitDepth: 24)
        let device = createMockAudioDevice(supportedSampleRates: [44100, 48000])
        
        mockAudioSession.sampleRate = 48000 // Different from source
        mockAudioSession.outputVolume = 1.0
        
        // When
        let result = await validator.validateBitPerfectPlayback(
            sourceFormat: sourceFormat,
            outputDevice: device
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.sampleRateMatches)
        XCTAssertEqual(result.mismatchReason, .sampleRateMismatch)
        XCTAssertFalse(result.validationIssues.isEmpty)
        
        let sampleRateIssue = result.validationIssues.first { $0.type == .formatMismatch }
        XCTAssertNotNil(sampleRateIssue)
        XCTAssertTrue(sampleRateIssue?.canAutoResolve ?? false)
    }
    
    func testBitPerfectValidation_VolumeNotUnity() async {
        // Given
        let sourceFormat = createMockAudioFileInfo(sampleRate: 48000, bitDepth: 16)
        let device = createMockAudioDevice()
        
        mockAudioSession.sampleRate = 48000
        mockAudioSession.outputVolume = 0.8 // Not at 100%
        
        // When
        let result = await validator.validateBitPerfectPlayback(
            sourceFormat: sourceFormat,
            outputDevice: device
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.volumeIsOptimal)
        XCTAssertEqual(result.mismatchReason, .systemVolumeNotUnity)
        
        let volumeIssue = result.validationIssues.first { $0.type == .volumeScaling }
        XCTAssertNotNil(volumeIssue)
        XCTAssertEqual(result.systemVolume, 0.8)
    }
    
    func testBitPerfectValidation_DeviceNotCapable() async {
        // Given
        let sourceFormat = createMockAudioFileInfo(sampleRate: 192000, bitDepth: 32)
        let device = createMockAudioDevice(
            maxBitDepth: 16,
            supportedSampleRates: [44100, 48000]
        )
        
        mockAudioSession.sampleRate = 48000
        mockAudioSession.outputVolume = 1.0
        
        // When
        let result = await validator.validateBitPerfectPlayback(
            sourceFormat: sourceFormat,
            outputDevice: device
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.deviceSupportsFormat)
        XCTAssertEqual(result.mismatchReason, .sampleRateMismatch) // First detected issue
        
        let deviceIssue = result.validationIssues.first { $0.type == .deviceLimitation }
        XCTAssertNotNil(deviceIssue)
        XCTAssertFalse(deviceIssue?.canAutoResolve ?? true)
    }
    
    // MARK: - Format Validation Tests
    
    func testValidateFormat_MP3() async {
        // Given
        let format = AudioFormat.mp3
        let sampleRate = 44100
        let bitDepth = 16
        
        mockAudioSession.sampleRate = Double(sampleRate)
        mockAudioSession.outputVolume = 1.0
        
        // When
        let result = await validator.validateFormat(
            format,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            outputDevice: nil
        )
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.expectedSampleRate, sampleRate)
        XCTAssertEqual(result.expectedBitDepth, bitDepth)
    }
    
    func testValidateFormat_FLAC_HighRes() async {
        // Given
        let format = AudioFormat.flac
        let sampleRate = 192000
        let bitDepth = 24
        
        mockAudioSession.sampleRate = 48000 // Device limitation
        mockAudioSession.outputVolume = 1.0
        
        // When
        let result = await validator.validateFormat(
            format,
            sampleRate: sampleRate,
            bitDepth: bitDepth,
            outputDevice: nil
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.sampleRateMatches)
        XCTAssertEqual(result.mismatchReason, .sampleRateMismatch)
    }
    
    // MARK: - Device Analysis Tests
    
    func testGetCurrentDeviceCapabilities_BuiltInSpeaker() async {
        // Given
        mockAudioSession.mockCurrentRoute(portType: .builtInSpeaker, portName: "Speaker")
        
        // When
        let capabilities = await validator.getCurrentDeviceCapabilities()
        
        // Then
        XCTAssertEqual(capabilities.maxBitDepth, 16)
        XCTAssertEqual(capabilities.supportedSampleRates, [44100, 48000])
        XCTAssertEqual(capabilities.maxChannels, 2)
        XCTAssertTrue(capabilities.supportsHardwareVolume)
        XCTAssertFalse(capabilities.supportsExclusiveMode)
    }
    
    func testGetCurrentDeviceCapabilities_USB_DAC() async {
        // Given
        mockAudioSession.mockCurrentRoute(portType: .USB, portName: "High-Quality DAC")
        
        // When
        let capabilities = await validator.getCurrentDeviceCapabilities()
        
        // Then
        XCTAssertEqual(capabilities.maxBitDepth, 24)
        XCTAssertEqual(capabilities.supportedSampleRates, [44100, 48000, 96000, 192000])
        XCTAssertEqual(capabilities.maxChannels, 2)
        XCTAssertTrue(capabilities.supportsHardwareVolume)
        XCTAssertFalse(capabilities.supportsExclusiveMode)
    }
    
    func testGetCurrentDeviceCapabilities_BluetoothA2DP() async {
        // Given
        mockAudioSession.mockCurrentRoute(portType: .bluetoothA2DP, portName: "AirPods Pro")
        
        // When
        let capabilities = await validator.getCurrentDeviceCapabilities()
        
        // Then
        XCTAssertEqual(capabilities.maxBitDepth, 16)
        XCTAssertEqual(capabilities.supportedSampleRates, [44100, 48000])
        XCTAssertEqual(capabilities.maxChannels, 2)
        XCTAssertTrue(capabilities.supportsHardwareVolume)
        XCTAssertFalse(capabilities.supportsExclusiveMode)
    }
    
    func testGetAvailableDevicesWithCapabilities() async {
        // Given
        mockAudioSession.mockMultipleOutputs([
            (.builtInSpeaker, "Speaker"),
            (.USB, "External DAC"),
            (.bluetoothA2DP, "Bluetooth Headphones")
        ])
        
        // When
        let devicesWithCapabilities = await validator.getAvailableDevicesWithCapabilities()
        
        // Then
        XCTAssertEqual(devicesWithCapabilities.count, 3)
        
        let speakerDevice = devicesWithCapabilities.first { $0.device.type == .builtInSpeaker }
        XCTAssertNotNil(speakerDevice)
        XCTAssertEqual(speakerDevice?.capabilities.maxBitDepth, 16)
        
        let usbDevice = devicesWithCapabilities.first { $0.device.type == .usb }
        XCTAssertNotNil(usbDevice)
        XCTAssertEqual(usbDevice?.capabilities.maxBitDepth, 24)
        
        let bluetoothDevice = devicesWithCapabilities.first { $0.device.type == .bluetooth }
        XCTAssertNotNil(bluetoothDevice)
        XCTAssertEqual(bluetoothDevice?.capabilities.maxBitDepth, 16)
    }
    
    func testSupportsBitPerfectPlayback() async {
        // Given
        let usbDevice = createMockAudioDevice(type: .usb)
        let bluetoothDevice = createMockAudioDevice(type: .bluetooth)
        let builtInDevice = createMockAudioDevice(type: .builtInSpeaker)
        
        // When
        let usbSupported = await validator.supportseBitPerfectPlayback(device: usbDevice)
        let bluetoothSupported = await validator.supportseBitPerfectPlayback(device: bluetoothDevice)
        let builtInSupported = await validator.supportseBitPerfectPlayback(device: builtInDevice)
        
        // Then
        XCTAssertTrue(usbSupported)
        XCTAssertFalse(bluetoothSupported)
        XCTAssertFalse(builtInSupported)
    }
    
    // MARK: - DAC Compatibility Tests
    
    func testUpdateDACCompatibility() async {
        // Given
        let dacInfo = DACCompatibilityInfo(
            deviceIdentifier: "test_dac_001",
            manufacturer: "Test Audio",
            modelName: "Premium DAC",
            connectionInterface: .usb,
            maxSampleRate: 384000,
            maxBitDepth: 32,
            supportsBitPerfect: true,
            supportsDSD: true
        )
        
        // When
        await validator.updateDACCompatibility(dacInfo)
        let retrieved = await validator.getDACCompatibility(for: "test_dac_001")
        
        // Then
        XCTAssertNotNil(retrieved)
        XCTAssertEqual(retrieved?.manufacturer, "Test Audio")
        XCTAssertEqual(retrieved?.modelName, "Premium DAC")
        XCTAssertEqual(retrieved?.maxSampleRate, 384000)
        XCTAssertEqual(retrieved?.maxBitDepth, 32)
        XCTAssertTrue(retrieved?.supportsBitPerfect ?? false)
        XCTAssertTrue(retrieved?.supportsDSD ?? false)
    }
    
    func testClearDACCompatibilityCache() async {
        // Given
        let dacInfo = DACCompatibilityInfo.genericUSBDAC()
        await validator.updateDACCompatibility(dacInfo)
        
        // Verify it exists
        let beforeClear = await validator.getDACCompatibility(for: dacInfo.deviceIdentifier)
        XCTAssertNotNil(beforeClear)
        
        // When
        await validator.clearDACCompatibilityCache()
        
        // Then
        let afterClear = await validator.getDACCompatibility(for: dacInfo.deviceIdentifier)
        XCTAssertNil(afterClear)
    }
    
    // MARK: - Analysis Tests
    
    func testAnalyzeAudioPath_Optimal() async {
        // Given
        mockAudioSession.mockCurrentRoute(portType: .USB, portName: "High-End DAC")
        mockAudioSession.outputVolume = 1.0
        mockAudioSession.isOtherAudioPlaying = false
        
        // When
        let analysis = await validator.analyzeAudioPath()
        
        // Then
        XCTAssertTrue(analysis.isBitPerfect)
        XCTAssertEqual(analysis.qualityScore, 1.0)
        XCTAssertTrue(analysis.limitations.isEmpty)
        XCTAssertTrue(analysis.processingStages.isEmpty)
    }
    
    func testAnalyzeAudioPath_Bluetooth() async {
        // Given
        mockAudioSession.mockCurrentRoute(portType: .bluetoothA2DP, portName: "AirPods")
        mockAudioSession.outputVolume = 1.0
        
        // When
        let analysis = await validator.analyzeAudioPath()
        
        // Then
        XCTAssertFalse(analysis.isBitPerfect)
        XCTAssertLessThan(analysis.qualityScore, 1.0)
        XCTAssertFalse(analysis.limitations.isEmpty)
        
        let bluetoothLimitation = analysis.limitations.first { 
            $0.type == .systemLimitation 
        }
        XCTAssertNotNil(bluetoothLimitation)
        XCTAssertTrue(bluetoothLimitation?.description.contains("Bluetooth") ?? false)
    }
    
    func testAnalyzeAudioPath_VolumeNotMax() async {
        // Given
        mockAudioSession.mockCurrentRoute(portType: .USB, portName: "DAC")
        mockAudioSession.outputVolume = 0.7
        
        // When
        let analysis = await validator.analyzeAudioPath()
        
        // Then
        XCTAssertFalse(analysis.isBitPerfect)
        XCTAssertLessThan(analysis.qualityScore, 1.0)
        
        let volumeLimitation = analysis.limitations.first { 
            $0.type == .configurationIssue 
        }
        XCTAssertNotNil(volumeLimitation)
        XCTAssertTrue(volumeLimitation?.description.contains("volume") ?? false)
    }
    
    func testGetOptimalConfiguration() async {
        // Given
        let sourceFormat = createMockAudioFileInfo(sampleRate: 96000, bitDepth: 24)
        mockAudioSession.sampleRate = 48000
        mockAudioSession.outputVolume = 0.8
        
        // When
        let recommendations = await validator.getOptimalConfiguration(for: sourceFormat)
        
        // Then
        XCTAssertFalse(recommendations.requiredChanges.isEmpty)
        
        let sampleRateChange = recommendations.requiredChanges.first { 
            $0.setting == "Sample Rate" 
        }
        XCTAssertNotNil(sampleRateChange)
        
        let volumeChange = recommendations.requiredChanges.first { 
            $0.setting == "System Volume" 
        }
        XCTAssertNotNil(volumeChange)
        XCTAssertEqual(volumeChange?.recommendedValue, "100%")
    }
    
    func testAnalyzeAudioSession_Optimal() async {
        // Given
        mockAudioSession.category = .playback
        mockAudioSession.sampleRate = 48000
        mockAudioSession.isOtherAudioPlaying = false
        
        // When
        let analysis = await validator.analyzeAudioSession()
        
        // Then
        XCTAssertTrue(analysis.isOptimal)
        XCTAssertTrue(analysis.issues.isEmpty)
        XCTAssertEqual(analysis.currentSettings["category"] as? String, AVAudioSession.Category.playback.rawValue)
    }
    
    func testAnalyzeAudioSession_SuboptimalCategory() async {
        // Given
        mockAudioSession.category = .ambient
        mockAudioSession.sampleRate = 48000
        
        // When
        let analysis = await validator.analyzeAudioSession()
        
        // Then
        XCTAssertFalse(analysis.isOptimal)
        XCTAssertFalse(analysis.issues.isEmpty)
        
        let categoryIssue = analysis.issues.first
        XCTAssertNotNil(categoryIssue)
        XCTAssertTrue(categoryIssue?.description.contains("category") ?? false)
        
        let categoryRecommendation = analysis.recommendations.first
        XCTAssertNotNil(categoryRecommendation)
        XCTAssertTrue(categoryRecommendation?.recommendation.contains("playback") ?? false)
    }
    
    func testAnalyzeRequiredConversion() async {
        // Given
        let sourceFormat = createMockAudioFileInfo(sampleRate: 192000, bitDepth: 32, channels: 6)
        let deviceCapabilities = DeviceCapabilities(
            supportedSampleRates: [44100, 48000, 96000],
            maxBitDepth: 24,
            maxChannels: 2
        )
        
        // When
        let analysis = await validator.analyzeRequiredConversion(
            sourceFormat: sourceFormat,
            outputCapabilities: deviceCapabilities
        )
        
        // Then
        XCTAssertTrue(analysis.conversionRequired)
        XCTAssertTrue(analysis.conversionTypes.contains(.sampleRate))
        XCTAssertTrue(analysis.conversionTypes.contains(.bitDepth))
        XCTAssertTrue(analysis.conversionTypes.contains(.channelCount))
        XCTAssertEqual(analysis.qualityImpact, .moderate)
        XCTAssertGreaterThan(analysis.performanceImpact, 0.0)
        XCTAssertFalse(analysis.alternatives.isEmpty)
    }
    
    func testGetSupportedOutputFormats() async {
        // Given
        mockAudioSession.mockCurrentRoute(portType: .USB, portName: "High-End DAC")
        
        // When
        let formats = await validator.getSupportedOutputFormats()
        
        // Then
        XCTAssertFalse(formats.isEmpty)
        
        // Should include common formats
        let cd_quality = formats.first { 
            $0.sampleRate == 44100 && $0.bitDepth == 16 && $0.channels == 2 
        }
        XCTAssertNotNil(cd_quality)
        
        let high_res = formats.first { 
            $0.sampleRate == 96000 && $0.bitDepth == 24 && $0.channels == 2 
        }
        XCTAssertNotNil(high_res)
    }
    
    // MARK: - Real-time Validation Tests
    
    func testValidateRealTime() async {
        // Given
        let sourceFormat = createMockAudioFileInfo(sampleRate: 48000, bitDepth: 16)
        mockAudioSession.sampleRate = 48000
        mockAudioSession.outputVolume = 1.0
        mockAudioSession.mockCurrentRoute(portType: .USB, portName: "Real-time DAC")
        
        // When
        let result = await validator.validateRealTime(
            audioSession: mockAudioSession,
            sourceFormat: sourceFormat
        )
        
        // Then
        XCTAssertTrue(result.isValid)
        XCTAssertEqual(result.expectedSampleRate, 48000)
        XCTAssertEqual(result.actualSampleRate, 48000)
        XCTAssertNotNil(result.deviceInfo)
        XCTAssertEqual(result.deviceInfo?.name, "Real-time DAC")
    }
    
    // MARK: - Edge Cases Tests
    
    func testValidation_EmptyOutputRoute() async {
        // Given
        let sourceFormat = createMockAudioFileInfo()
        mockAudioSession.mockEmptyRoute()
        
        // When
        let result = await validator.validateBitPerfectPlayback(
            sourceFormat: sourceFormat,
            outputDevice: nil
        )
        
        // Then
        // Should handle gracefully with default capabilities
        XCTAssertNotNil(result)
        XCTAssertEqual(result.expectedSampleRate, sourceFormat.sampleRate)
    }
    
    func testValidation_ExtremeHighResolution() async {
        // Given
        let sourceFormat = createMockAudioFileInfo(
            sampleRate: 768000, // Extremely high
            bitDepth: 32,
            channels: 8
        )
        mockAudioSession.sampleRate = 48000
        
        // When
        let result = await validator.validateBitPerfectPlayback(
            sourceFormat: sourceFormat,
            outputDevice: nil
        )
        
        // Then
        XCTAssertFalse(result.isValid)
        XCTAssertFalse(result.sampleRateMatches)
        XCTAssertFalse(result.channelCountMatches)
        XCTAssertGreaterThan(result.validationIssues.count, 0)
    }
    
    func testValidation_CachingBehavior() async {
        // Given
        let sourceFormat = createMockAudioFileInfo()
        mockAudioSession.sampleRate = Double(sourceFormat.sampleRate)
        mockAudioSession.outputVolume = 1.0
        
        // When - First validation
        let result1 = await validator.validateBitPerfectPlayback(
            sourceFormat: sourceFormat,
            outputDevice: nil
        )
        
        // When - Second validation immediately after (should use cache)
        let result2 = await validator.validateBitPerfectPlayback(
            sourceFormat: sourceFormat,
            outputDevice: nil
        )
        
        // Then
        XCTAssertEqual(result1.timestamp, result2.timestamp) // Should be same cached result
        XCTAssertEqual(result1.isValid, result2.isValid)
    }
    
    // MARK: - DACCompatibilityInfo Tests
    
    func testDACCompatibilityInfo_AppleBuiltIn() {
        // When
        let appleBuiltIn = DACCompatibilityInfo.appleBuiltIn()
        
        // Then
        XCTAssertEqual(appleBuiltIn.manufacturer, "Apple")
        XCTAssertEqual(appleBuiltIn.modelName, "Built-in Audio")
        XCTAssertFalse(appleBuiltIn.supportsBitPerfect)
        XCTAssertEqual(appleBuiltIn.maxSampleRate, 48000)
        XCTAssertEqual(appleBuiltIn.maxBitDepth, 16)
        XCTAssertEqual(appleBuiltIn.qualityRating, .basic)
    }
    
    func testDACCompatibilityInfo_GenericUSB() {
        // When
        let genericUSB = DACCompatibilityInfo.genericUSBDAC()
        
        // Then
        XCTAssertEqual(genericUSB.manufacturer, "Generic")
        XCTAssertEqual(genericUSB.modelName, "USB DAC")
        XCTAssertTrue(genericUSB.supportsBitPerfect)
        XCTAssertEqual(genericUSB.maxSampleRate, 192000)
        XCTAssertEqual(genericUSB.maxBitDepth, 24)
        XCTAssertGreaterThan(genericUSB.qualityRating.rawValue, DACQualityRating.basic.rawValue)
    }
    
    func testDACCompatibilityInfo_QualityRating() {
        // Given
        let basicDAC = DACCompatibilityInfo(
            deviceIdentifier: "basic",
            manufacturer: "Basic",
            modelName: "Entry DAC",
            connectionInterface: .usb,
            maxSampleRate: 48000,
            maxBitDepth: 16
        )
        
        let referenceDAC = DACCompatibilityInfo(
            deviceIdentifier: "reference",
            manufacturer: "Reference",
            modelName: "Ultra DAC",
            connectionInterface: .usb,
            maxSampleRate: 768000,
            maxBitDepth: 32,
            supportsBitPerfect: true,
            supportsExclusiveMode: true,
            supportsDSD: true,
            supportsMQA: true,
            signalToNoiseRatio: 135.0
        )
        
        // Then
        XCTAssertEqual(basicDAC.qualityRating, .basic)
        XCTAssertEqual(referenceDAC.qualityRating, .reference)
        XCTAssertTrue(referenceDAC.isAudiophileGrade)
        XCTAssertFalse(basicDAC.isAudiophileGrade)
    }
    
    // MARK: - BitPerfectValidationResult Tests
    
    func testBitPerfectValidationResult_ComputedProperties() {
        // Given
        let result = BitPerfectValidationResult(
            isValid: false,
            expectedSampleRate: 96000,
            actualSampleRate: 48000,
            expectedBitDepth: 24,
            actualBitDepth: 16,
            hasAudioProcessing: true,
            systemVolume: 0.8
        )
        
        // Then
        XCTAssertFalse(result.sampleRateMatches)
        XCTAssertFalse(result.bitDepthMatches)
        XCTAssertFalse(result.criticalParametersMatch)
        XCTAssertFalse(result.volumeIsOptimal)
        XCTAssertLessThan(result.compatibilityScore, 1.0)
        XCTAssertTrue(result.statusSummary.contains("failed") || result.statusSummary.contains("required"))
    }
    
    func testBitPerfectValidationResult_DetailedReport() {
        // Given
        let deviceInfo = DeviceValidationInfo(
            id: "test_device",
            name: "Test DAC",
            type: .usb,
            isDefault: true,
            capabilities: DeviceCapabilities(supportedSampleRates: [48000], maxBitDepth: 24, maxChannels: 2),
            connectionType: .usb
        )
        
        let result = BitPerfectValidationResult(
            isValid: false,
            expectedSampleRate: 96000,
            actualSampleRate: 48000,
            expectedBitDepth: 24,
            actualBitDepth: 16,
            mismatchReason: .sampleRateMismatch,
            deviceInfo: deviceInfo,
            systemVolume: 0.9
        )
        
        // When
        let report = result.detailedReport
        
        // Then
        XCTAssertTrue(report.contains("Bit-Perfect Validation Report"))
        XCTAssertTrue(report.contains("INVALID"))
        XCTAssertTrue(report.contains("96000Hz"))
        XCTAssertTrue(report.contains("48000Hz"))
        XCTAssertTrue(report.contains("MISMATCH"))
        XCTAssertTrue(report.contains("Test DAC"))
        XCTAssertTrue(report.contains("90%")) // Volume
    }
}

// MARK: - Mock Classes

@MainActor
class MockAVAudioSession: AVAudioSession {
    
    var sampleRate: Double = 48000
    var outputVolume: Float = 1.0
    var category: AVAudioSession.Category = .playback
    var mode: AVAudioSession.Mode = .default
    var isOtherAudioPlaying: Bool = false
    
    private var mockOutputs: [MockAudioSessionPortDescription] = []
    
    override var currentRoute: AVAudioSessionRouteDescription {
        return MockAudioSessionRouteDescription(outputs: mockOutputs)
    }
    
    func mockCurrentRoute(portType: AVAudioSession.Port, portName: String, uid: String = "mock_device") {
        let mockPort = MockAudioSessionPortDescription(portType: portType, portName: portName, uid: uid)
        mockOutputs = [mockPort]
    }
    
    func mockMultipleOutputs(_ outputs: [(AVAudioSession.Port, String)]) {
        mockOutputs = outputs.enumerated().map { index, output in
            MockAudioSessionPortDescription(
                portType: output.0,
                portName: output.1,
                uid: "mock_device_\(index)"
            )
        }
    }
    
    func mockEmptyRoute() {
        mockOutputs = []
    }
}

class MockAudioSessionRouteDescription: AVAudioSessionRouteDescription {
    private let mockOutputs: [AVAudioSessionPortDescription]
    
    init(outputs: [AVAudioSessionPortDescription]) {
        self.mockOutputs = outputs
        super.init()
    }
    
    override var outputs: [AVAudioSessionPortDescription] {
        return mockOutputs
    }
}

class MockAudioSessionPortDescription: AVAudioSessionPortDescription {
    private let mockPortType: AVAudioSession.Port
    private let mockPortName: String
    private let mockUID: String
    private let mockChannels: [AVAudioSessionChannelDescription]?
    
    init(
        portType: AVAudioSession.Port,
        portName: String,
        uid: String,
        channelCount: Int = 2
    ) {
        self.mockPortType = portType
        self.mockPortName = portName
        self.mockUID = uid
        
        // Create mock channels
        self.mockChannels = (0..<channelCount).map { _ in
            MockAudioSessionChannelDescription()
        }
        
        super.init()
    }
    
    override var portType: AVAudioSession.Port {
        return mockPortType
    }
    
    override var portName: String {
        return mockPortName
    }
    
    override var uid: String {
        return mockUID
    }
    
    override var channels: [AVAudioSessionChannelDescription]? {
        return mockChannels
    }
}

class MockAudioSessionChannelDescription: AVAudioSessionChannelDescription {
    override init() {
        super.init()
    }
} 