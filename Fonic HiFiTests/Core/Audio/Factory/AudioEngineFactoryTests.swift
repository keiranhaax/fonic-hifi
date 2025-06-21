//
//  AudioEngineFactoryTests.swift
//  Fonic HiFiTests
//
//  Created by Keiran on 5/27/25.
//

import XCTest
@testable import Fonic_HiFi

@MainActor
final class AudioEngineFactoryTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: AudioEngineFactory!
    fileprivate var mockFormatDetector: MockFormatDetectionService!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        mockFormatDetector = MockFormatDetectionService()
        sut = AudioEngineFactory(formatDetector: mockFormatDetector)
    }
    
    override func tearDown() async throws {
        sut = nil
        mockFormatDetector = nil
        try await super.tearDown()
    }
    
    // MARK: - Engine Selection Tests
    
    func testSelectsAVAudioEngineForStandardFormats() async throws {
        // Given standard formats
        let standardFormats: [AudioFormat] = [.mp3, .aac, .alac, .wav, .aiff]
        let config = AudioEngineConfiguration()
        
        // When creating engines
        for format in standardFormats {
            let engine = try await sut.makeEngine(for: format, configuration: config)
            
            // Then AVAudioEngine should be selected
            XCTAssertTrue(engine is AVAudioEngineAdapter, 
                         "Expected AVAudioEngineAdapter for \(format.displayName)")
        }
    }
    
    func testSelectsSFBAudioEngineForHighResFormats() async throws {
        // Given high-res format and SFBAudioEngine available
        sut.registerEngine(.sfbAudioEngine, isAvailable: true)
        let config = AudioEngineConfiguration(performanceMode: .quality)
        
        // When creating engine for FLAC
        let engine = try await sut.makeEngine(for: .flac, configuration: config)
        
        // Then SFBAudioEngine should be selected
        XCTAssertTrue(engine is SFBAudioEngineAdapter,
                     "Expected SFBAudioEngineAdapter for FLAC")
    }
    
    func testFallsBackToFFmpegWhenNeeded() async throws {
        // Given unsupported format and FFmpeg available
        sut.registerEngine(.ffmpegEngine, isAvailable: true)
        let config = AudioEngineConfiguration()
        
        // When creating engine for APE without SFBAudioEngine
        let engine = try await sut.makeEngine(for: .ape, configuration: config)
        
        // Then FFmpeg should be selected
        XCTAssertTrue(engine is FFmpegEngineAdapter,
                     "Expected FFmpegEngineAdapter as fallback")
    }
    
    func testThrowsErrorWhenNoEngineAvailable() async throws {
        // Given FLAC format with no specialized engines
        sut.registerEngine(.sfbAudioEngine, isAvailable: false)
        sut.registerEngine(.ffmpegEngine, isAvailable: false)
        let config = AudioEngineConfiguration()
        
        // When/Then - should still work with AVAudioEngine as last resort
        let engine = try await sut.makeEngine(for: .flac, configuration: config)
        XCTAssertTrue(engine is AVAudioEngineAdapter,
                     "Expected AVAudioEngineAdapter as last resort")
    }
    
    // MARK: - Performance Mode Tests
    
    func testEfficiencyModePreferNativeEngine() async throws {
        // Given efficiency mode and multiple engines available
        sut.registerEngine(.sfbAudioEngine, isAvailable: true)
        let config = AudioEngineConfiguration(performanceMode: .efficiency)
        
        // When creating engine for supported format
        let engine = try await sut.makeEngine(for: .wav, configuration: config)
        
        // Then native engine should be preferred
        XCTAssertTrue(engine is AVAudioEngineAdapter,
                     "Expected AVAudioEngineAdapter in efficiency mode")
    }
    
    func testQualityModePreferSpecializedEngine() async throws {
        // Given quality mode and specialized engine available
        sut.registerEngine(.sfbAudioEngine, isAvailable: true)
        let config = AudioEngineConfiguration(performanceMode: .quality)
        
        // When creating engine for high-res format
        let engine = try await sut.makeEngine(for: .flac, configuration: config)
        
        // Then specialized engine should be preferred
        XCTAssertTrue(engine is SFBAudioEngineAdapter,
                     "Expected SFBAudioEngineAdapter in quality mode")
    }
    
    // MARK: - URL-based Creation Tests
    
    func testCreateEngineFromURL() async throws {
        // Given a mock file URL
        let url = URL(fileURLWithPath: "/tmp/test.mp3")
        mockFormatDetector.mockFileInfo = AudioFileInfo(
            url: url,
            format: .mp3,
            duration: 180,
            bitDepth: 16,
            sampleRate: 44100,
            channels: 2,
            fileSize: 7200000,
            bitrate: 320000
        )
        
        let config = AudioEngineConfiguration()
        
        // When creating engine from URL
        let engine = try await sut.makeEngine(for: url, configuration: config)
        
        // Then appropriate engine should be created
        XCTAssertTrue(engine is AVAudioEngineAdapter)
    }
    
    // MARK: - Registration Tests
    
    func testEngineRegistration() {
        // Given
        XCTAssertTrue(sut.isEngineAvailable(.avAudioEngine))
        XCTAssertFalse(sut.isEngineAvailable(.sfbAudioEngine))
        
        // When registering
        sut.registerEngine(.sfbAudioEngine, isAvailable: true)
        
        // Then
        XCTAssertTrue(sut.isEngineAvailable(.sfbAudioEngine))
    }
    
    func testAvailableEngineTypes() {
        // Given default state
        var available = sut.availableEngineTypes()
        XCTAssertEqual(available.count, 1)
        XCTAssertTrue(available.contains(.avAudioEngine))
        
        // When registering more engines
        sut.registerEngine(.sfbAudioEngine, isAvailable: true)
        sut.registerEngine(.ffmpegEngine, isAvailable: true)
        
        // Then
        available = sut.availableEngineTypes()
        XCTAssertEqual(available.count, 3)
    }
    
    // MARK: - Diagnostics Tests
    
    func testDiagnostics() {
        // Given
        sut.registerEngine(.sfbAudioEngine, isAvailable: true)
        
        // When getting diagnostics
        let diagnostics = sut.diagnostics(for: .flac)
        
        // Then
        XCTAssertEqual(diagnostics.format, .flac)
        XCTAssertEqual(diagnostics.preferredEngine, .sfbAudioEngine)
        XCTAssertTrue(diagnostics.isPreferredAvailable)
        XCTAssertFalse(diagnostics.alternativeEngines.isEmpty)
    }
}

// MARK: - Mock Format Detection Service

fileprivate final class MockFormatDetectionService: FormatDetectionService {
    var mockFileInfo: AudioFileInfo?
    var shouldThrow = false
    
    func detectFormat(at url: URL) async throws -> AudioFileInfo {
        if shouldThrow {
            throw DetectionError.unknownFormat(url)
        }
        
        return mockFileInfo ?? AudioFileInfo(
            url: url,
            format: .mp3,
            duration: 180,
            bitDepth: 16,
            sampleRate: 44100,
            channels: 2,
            fileSize: 2880000,
            bitrate: 128000
        )
    }
    
    func validateFile(at url: URL) async -> Bool {
        return !shouldThrow
    }
    
    func isFormatSupported(_ format: AudioFormat) -> Bool {
        return true
    }
    
    func getFormatCapabilities(_ format: AudioFormat) -> FormatCapabilities? {
        return FormatCapabilities(
            maxSampleRate: 192000,
            maxBitDepth: 32,
            supportsMultiChannel: true,
            supportsArtwork: true,
            supportsChapters: false,
            requiresSpecializedDecoder: format.requiresSpecialEngine
        )
    }
}

// MARK: - AudioEngineType Tests

final class AudioEngineTypeTests: XCTestCase {
    
    func testEngineTypeProperties() {
        // Test display names
        XCTAssertEqual(AudioEngineType.avAudioEngine.displayName, "Native Audio Engine")
        XCTAssertEqual(AudioEngineType.sfbAudioEngine.displayName, "High-Resolution Audio Engine")
        XCTAssertEqual(AudioEngineType.ffmpegEngine.displayName, "Universal Audio Engine")
        
        // Test performance impact
        XCTAssertEqual(AudioEngineType.avAudioEngine.performanceImpact, .low)
        XCTAssertEqual(AudioEngineType.sfbAudioEngine.performanceImpact, .medium)
        XCTAssertEqual(AudioEngineType.ffmpegEngine.performanceImpact, .high)
    }
    
    func testFormatHandling() {
        // AVAudioEngine
        XCTAssertTrue(AudioEngineType.avAudioEngine.canHandle(.mp3))
        XCTAssertTrue(AudioEngineType.avAudioEngine.canHandle(.aac))
        XCTAssertFalse(AudioEngineType.avAudioEngine.canHandle(.flac))
        
        // SFBAudioEngine
        XCTAssertTrue(AudioEngineType.sfbAudioEngine.canHandle(.flac))
        XCTAssertTrue(AudioEngineType.sfbAudioEngine.canHandle(.dsd))
        XCTAssertFalse(AudioEngineType.sfbAudioEngine.canHandle(.mp3))
        
        // FFmpegEngine
        XCTAssertTrue(AudioEngineType.ffmpegEngine.canHandle(.mp3))
        XCTAssertTrue(AudioEngineType.ffmpegEngine.canHandle(.flac))
        XCTAssertTrue(AudioEngineType.ffmpegEngine.canHandle(.ape))
    }
    
    func testPerformanceImpact() {
        let low = PerformanceImpact.low
        XCTAssertEqual(low.cpuUsageRange.lowerBound, 1)
        XCTAssertEqual(low.cpuUsageRange.upperBound, 5)
        XCTAssertEqual(low.batteryImpactDescription, "Minimal battery impact")
        
        let high = PerformanceImpact.high
        XCTAssertEqual(high.cpuUsageRange.lowerBound, 15)
        XCTAssertEqual(high.cpuUsageRange.upperBound, 30)
        XCTAssertEqual(high.batteryImpactDescription, "Higher battery consumption")
    }
}