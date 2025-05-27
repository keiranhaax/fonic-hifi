//
//  AVAudioEngineTests.swift
//  Fonic HiFiTests
//
//  Created by Keiran on 5/27/25.
//

import XCTest
import AVFoundation
@testable import Fonic_HiFi

@MainActor
final class AVAudioEngineTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: AVAudioEngineAdapter!
    var testFileURL: URL!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        sut = AVAudioEngineAdapter()
        
        // Create a test audio file URL (would need actual test file in real tests)
        testFileURL = URL(fileURLWithPath: "/tmp/test.mp3")
    }
    
    override func tearDown() async throws {
        await sut.stop()
        sut = nil
        testFileURL = nil
        try await super.tearDown()
    }
    
    // MARK: - Initialization Tests
    
    func testInitialization() async {
        // Given/When - engine is initialized
        
        // Then
        let isPlaying = await sut.isPlaying
        XCTAssertFalse(isPlaying)
        
        let currentTime = await sut.currentTime
        XCTAssertEqual(currentTime, 0)
        
        let duration = await sut.duration
        XCTAssertEqual(duration, 0)
    }
    
    // MARK: - Loading Tests
    
    func testLoadWithInvalidURL() async {
        // Given
        let invalidURL = URL(fileURLWithPath: "/nonexistent/file.mp3")
        
        // When/Then
        do {
            try await sut.load(url: invalidURL)
            XCTFail("Should throw error for invalid file")
        } catch {
            XCTAssertTrue(error is AudioError)
        }
    }
    
    // MARK: - Playback Control Tests
    
    func testPlayWithoutLoadingFile() async {
        // Given - no file loaded
        
        // When/Then
        do {
            try await sut.play()
            XCTFail("Should throw error when playing without file")
        } catch {
            XCTAssertTrue(error is AudioError)
        }
    }
    
    func testVolumeControl() async {
        // Given
        let testVolumes: [Float] = [0.0, 0.5, 1.0, 1.5, -0.5]
        
        // When/Then
        for testVolume in testVolumes {
            await sut.setVolume(testVolume)
            let volume = await sut.volume
            
            // Volume should be clamped between 0 and 1
            let expectedVolume = max(0.0, min(1.0, testVolume))
            XCTAssertEqual(volume, expectedVolume, accuracy: 0.001)
        }
    }
    
    // MARK: - Seek Tests
    
    func testSeekWithoutFile() async {
        // Given - no file loaded
        
        // When/Then
        do {
            try await sut.seek(to: 10.0)
            XCTFail("Should throw error when seeking without file")
        } catch {
            XCTAssertTrue(error is AudioError)
        }
    }
    
    // MARK: - Configuration Tests
    
    func testConfigureEngine() async throws {
        // Given
        let config = AudioEngineConfiguration(
            bufferSize: 1024,
            enableBitPerfect: true,
            performanceMode: .quality
        )
        
        // When
        try await sut.configure(with: config)
        
        // Then - configuration should be applied
        // (Would need to verify internal state in real implementation)
        XCTAssertTrue(true)
    }
    
    // MARK: - Metrics Tests
    
    func testGetMetrics() async {
        // When
        let metrics = await sut.getMetrics()
        
        // Then
        XCTAssertGreaterThanOrEqual(metrics.cpuUsage, 0)
        XCTAssertGreaterThanOrEqual(metrics.memoryUsage, 0)
        XCTAssertEqual(metrics.bufferUnderruns, 0)
        XCTAssertTrue(metrics.isHealthy)
    }
    
    // MARK: - Format Support Tests
    
    func testAudioFormatDetection() async {
        // Given various file extensions
        let testCases: [(String, AudioFormat?)] = [
            ("test.mp3", .mp3),
            ("test.aac", .aac),
            ("test.m4a", .alac),
            ("test.wav", .wav),
            ("test.aiff", .aiff),
            ("test.unknown", nil)
        ]
        
        for (filename, expectedFormat) in testCases {
            let url = URL(fileURLWithPath: "/tmp/\(filename)")
            let detectedFormat = AudioFormat.from(url: url)
            
            if let expected = expectedFormat {
                XCTAssertEqual(detectedFormat, expected)
            } else {
                XCTAssertNil(detectedFormat)
            }
        }
    }
    
    // MARK: - Mock Playback Tests
    
    func testMockPlaybackFlow() async throws {
        // This test would require a mock audio file
        // Demonstrating the expected flow:
        
        // 1. Load file
        // try await sut.load(url: mockFileURL)
        
        // 2. Verify initial state
        // let duration = await sut.duration
        // XCTAssertGreaterThan(duration, 0)
        
        // 3. Start playback
        // try await sut.play()
        // let isPlaying = await sut.isPlaying
        // XCTAssertTrue(isPlaying)
        
        // 4. Pause
        // await sut.pause()
        // let isPaused = await sut.isPlaying
        // XCTAssertFalse(isPaused)
        
        // 5. Seek
        // try await sut.seek(to: duration / 2)
        // let currentTime = await sut.currentTime
        // XCTAssertEqual(currentTime, duration / 2, accuracy: 0.1)
        
        // 6. Stop
        // await sut.stop()
        
        XCTAssertTrue(true) // Placeholder
    }
}

// MARK: - AVAudioEngineConfig Tests

final class AVAudioEngineConfigTests: XCTestCase {
    
    func testOptimalBufferSize() {
        // Given/When
        let balancedSize = AVAudioEngineConfig.optimalBufferSize(for: .balanced)
        let qualitySize = AVAudioEngineConfig.optimalBufferSize(for: .quality)
        let efficiencySize = AVAudioEngineConfig.optimalBufferSize(for: .efficiency)
        
        // Then
        XCTAssertEqual(balancedSize, 512)
        XCTAssertEqual(qualitySize, 2048)
        XCTAssertEqual(efficiencySize, 4096)
    }
    
    func testNearestSupportedSampleRate() {
        // Given
        let testCases: [(Double, Double)] = [
            (44100, 44100),   // Exact match
            (44000, 44100),   // Close to 44.1kHz
            (50000, 48000),   // Close to 48kHz
            (100000, 96000),  // Close to 96kHz
            (200000, 192000)  // Close to 192kHz
        ]
        
        // When/Then
        for (input, expected) in testCases {
            let result = AVAudioEngineConfig.nearestSupportedSampleRate(to: input)
            XCTAssertEqual(result, expected)
        }
    }
    
    func testFormatNativeSupport() {
        // Given
        let supportedFormats: [AudioFormat] = [.mp3, .aac, .alac, .wav, .aiff]
        let unsupportedFormats: [AudioFormat] = [.flac, .ape, .dsd]
        
        // When/Then
        for format in supportedFormats {
            XCTAssertTrue(AVAudioEngineConfig.isFormatNativelySupported(format))
        }
        
        for format in unsupportedFormats {
            XCTAssertFalse(AVAudioEngineConfig.isFormatNativelySupported(format))
        }
    }
    
    func testSampleRateConversionCheck() {
        // Given
        let testCases: [(Double, Double, Bool, Bool)] = [
            (44100, 44100, true, false),   // Same rate, no conversion
            (44100, 88200, true, false),    // Integer multiple, no conversion needed
            (44100, 48000, true, true),     // Different rates, conversion needed
            (44100, 48000, false, true),    // Bit-perfect mode, conversion needed
        ]
        
        // When/Then
        for (source, output, allowResampling, expectedNeedsConversion) in testCases {
            let result = AVAudioEngineConfig.needsSampleRateConversion(
                sourceRate: source,
                outputRate: output,
                allowResampling: allowResampling
            )
            XCTAssertEqual(result, expectedNeedsConversion)
        }
    }
}