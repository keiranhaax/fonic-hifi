//
//  FormatDetectionTests.swift
//  Fonic HiFiTests
//
//  Created by Keiran on 5/27/25.
//

import XCTest
@testable import Fonic_HiFi

@MainActor
final class FormatDetectionTests: XCTestCase {
    
    // MARK: - Properties
    
    var sut: AudioFormatDetectionManager!
    
    // MARK: - Setup
    
    override func setUp() async throws {
        try await super.setUp()
        sut = AudioFormatDetectionManager.shared
    }
    
    override func tearDown() async throws {
        sut.clearAdapters()
        sut = nil
        try await super.tearDown()
    }
    
    // MARK: - Format Support Tests
    
    func testSupportsStandardFormats() {
        // Given standard audio formats
        let standardFormats: [AudioFormat] = [.mp3, .aac, .alac, .wav, .aiff]
        
        // When checking support
        for format in standardFormats {
            let isSupported = sut.isFormatSupported(format)
            
            // Then all should be supported
            XCTAssertTrue(isSupported, "\(format.displayName) should be supported")
        }
    }
    
    func testFormatCapabilities() {
        // Given various formats
        let formats = AudioFormat.allCases
        
        // When getting capabilities
        for format in formats {
            let capabilities = sut.getFormatCapabilities(format)
            
            // Then capabilities should be defined
            XCTAssertNotNil(capabilities, "\(format.displayName) should have defined capabilities")
            
            if let caps = capabilities {
                XCTAssertGreaterThan(caps.maxSampleRate, 0)
                XCTAssertGreaterThan(caps.maxBitDepth, 0)
            }
        }
    }
    
    // MARK: - Detection Tests
    
    func testDetectFormatWithInvalidURL() async {
        // Given a non-existent file
        let url = URL(fileURLWithPath: "/tmp/nonexistent.mp3")
        
        // When detecting format
        do {
            _ = try await sut.detectFormat(at: url)
            XCTFail("Should throw error for non-existent file")
        } catch {
            // Then should throw fileNotFound error
            XCTAssertTrue(error is DetectionError)
            if case DetectionError.fileNotFound = error {
                // Success
            } else {
                XCTFail("Should throw fileNotFound error")
            }
        }
    }
    
    func testValidateFileWithInvalidURL() async {
        // Given a non-existent file
        let url = URL(fileURLWithPath: "/tmp/nonexistent.mp3")
        
        // When validating
        let isValid = await sut.validateFile(at: url)
        
        // Then should return false
        XCTAssertFalse(isValid)
    }
    
    // MARK: - Mock Tests
    
    func testDetectFormatWithMockFile() async throws {
        // TODO: Add test with mock audio file
        // This would require creating a test audio file or mocking AVAsset
        
        // Example structure:
        // Given a mock MP3 file
        // let mockURL = createMockMP3File()
        
        // When detecting format
        // let info = try await sut.detectFormat(at: mockURL)
        
        // Then verify properties
        // XCTAssertEqual(info.format, .mp3)
        // XCTAssertEqual(info.sampleRate, 44100)
        // XCTAssertEqual(info.bitDepth, 16)
        // XCTAssertEqual(info.channels, 2)
    }
    
    // MARK: - Adapter Tests
    
    func testRegisterCustomAdapter() {
        // Given a custom adapter
        let mockAdapter = MockFormatDetectionAdapter()
        
        // When registering
        sut.registerAdapter(mockAdapter)
        
        // Then format should be supported
        XCTAssertTrue(sut.isFormatSupported(.flac))
    }
    
    func testClearAdapters() {
        // Given registered adapters
        let mockAdapter = MockFormatDetectionAdapter()
        sut.registerAdapter(mockAdapter)
        
        // When clearing adapters
        sut.clearAdapters()
        
        // Then specialized formats should not be supported
        // (unless AVAsset supports them)
        // This test assumes FLAC requires adapter
        XCTAssertFalse(sut.isFormatSupported(.flac))
    }
}

// MARK: - Mock Adapter

private final class MockFormatDetectionAdapter: FormatDetectionAdapter {
    let supportedFormats: [AudioFormat] = [.flac]
    
    func detectFormat(at url: URL) async throws -> AudioFileInfo {
        return AudioFileInfo(
            url: url,
            format: .flac,
            duration: 180,
            bitDepth: 24,
            sampleRate: 96000,
            channels: 2,
            fileSize: 50_000_000,
            bitrate: nil
        )
    }
}