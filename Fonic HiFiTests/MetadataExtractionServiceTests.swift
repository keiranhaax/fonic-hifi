@testable import Fonic_HiFi
import AVFoundation
import XCTest

private actor StubFormatDetectionService: FormatDetectionService {
    enum StubError: Error { case unavailable }

    var results: [URL: AudioFileInfo]
    var supportedFormats: Set<AudioFormat>

    init(results: [URL: AudioFileInfo] = [:], supportedFormats: Set<AudioFormat> = Set(AudioFormat.allCases)) {
        self.results = results
        self.supportedFormats = supportedFormats
    }

    func detectFormat(at url: URL) async throws -> AudioFileInfo {
        if let info = results[url] {
            return info
        }
        throw StubError.unavailable
    }

    func validateFile(at url: URL) async -> Bool {
        results[url] != nil
    }

    func isFormatSupported(_ format: AudioFormat) -> Bool {
        supportedFormats.contains(format)
    }

    func getFormatCapabilities(_ format: AudioFormat) -> FormatCapabilities? {
        guard isFormatSupported(format) else { return nil }
        return FormatCapabilities(
            maxSampleRate: 192_000,
            maxBitDepth: 32,
            supportsMultiChannel: true,
            supportsArtwork: true,
            supportsChapters: false,
            requiresSpecializedDecoder: false
        )
    }
}

@MainActor
final class MetadataExtractionServiceTests: XCTestCase {
    func testExtractTrackMetadataUsesFormatDetectionResults() async throws {
        let url = try makePCMTestAudioFile(testCase: self)
        let detected = AudioFileInfo.create(
            url: url,
            format: .flac,
            sampleRate: 96_000,
            bitDepth: 24,
            channels: 2,
            bitrate: 2_560_000,
            duration: 0.25
        )
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService(results: [url: detected]))

        let metadata = try await service.extractTrackMetadata(from: url)

        XCTAssertEqual(metadata.url, url)
        XCTAssertEqual(metadata.audioFormat, detected.format.rawValue)
        XCTAssertEqual(metadata.sampleRate, detected.sampleRate)
        XCTAssertEqual(metadata.bitDepth, Int(detected.bitDepth))
        XCTAssertEqual(metadata.channels, Int(detected.channels))
        XCTAssertEqual(metadata.isLossless, detected.isLossless)
        XCTAssertGreaterThan(metadata.duration, 0)
    }

    func testExtractMetadataSkipsFailuresButReturnsSuccesses() async throws {
        let successfulURL = try makePCMTestAudioFile(testCase: self)
        let failingURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")

        let detected = AudioFileInfo.create(url: successfulURL, format: .aac)
        let stub = StubFormatDetectionService(results: [successfulURL: detected])
        let service = MetadataExtractionService(formatDetectionService: stub)

        let results = try await service.extractMetadata(from: [successfulURL, failingURL])

        XCTAssertEqual(results.count, 1)
        XCTAssertEqual(results.first?.url, successfulURL)
        XCTAssertEqual(results.first?.audioFormat, detected.format.rawValue)
    }

    func testExtractTrackMetadataFallsBackWhenDetectionFails() async throws {
        let url = try makePCMTestAudioFile(testCase: self)
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService(results: [:]))

        let metadata = try await service.extractTrackMetadata(from: url)

        XCTAssertEqual(metadata.url, url)
        XCTAssertEqual(metadata.audioFormat, AudioFormatType.unknown.rawValue)
        XCTAssertGreaterThan(metadata.sampleRate, 0)
        XCTAssertGreaterThan(metadata.duration, 0)
    }

    func testExtractTrackMetadataThrowsForMissingFile() async {
        let missingURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("flac")

        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService(results: [:]))

        do {
            _ = try await service.extractTrackMetadata(from: missingURL)
            XCTFail("Expected missing file to throw")
        } catch let error as MetadataExtractionError {
            switch error {
            case .fileNotFound(let url):
                XCTAssertEqual(url, missingURL)
            default:
                XCTFail("Unexpected error: \(error)")
            }
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    // MARK: - Replay Gain Parsing Tests

    func testParseReplayGainValueWithNegativeDB() throws {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())

        let result = try XCTUnwrap(service.parseReplayGainValue("-6.5 dB"))

        XCTAssertEqual(result, -6.5, accuracy: 0.01)
    }

    func testParseReplayGainValueWithPositiveDB() throws {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())

        let result = try XCTUnwrap(service.parseReplayGainValue("+3.2 dB"))

        XCTAssertEqual(result, 3.2, accuracy: 0.01)
    }

    func testParseReplayGainValueWithoutSign() throws {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())

        let result = try XCTUnwrap(service.parseReplayGainValue("2.0 dB"))

        XCTAssertEqual(result, 2.0, accuracy: 0.01)
    }

    func testParseReplayGainValueCaseInsensitive() throws {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())

        let result = try XCTUnwrap(service.parseReplayGainValue("-4.0 DB"))

        XCTAssertEqual(result, -4.0, accuracy: 0.01)
    }

    func testParseReplayGainValueWithExtraWhitespace() throws {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())

        let result = try XCTUnwrap(service.parseReplayGainValue("  -1.5   dB  "))

        XCTAssertEqual(result, -1.5, accuracy: 0.01)
    }

    func testParseReplayGainValueReturnsNilForInvalid() {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())

        let result = service.parseReplayGainValue("invalid")

        XCTAssertNil(result)
    }

    func testParseReplayGainValueReturnsNilForNilInput() {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())

        let result = service.parseReplayGainValue(nil)

        XCTAssertNil(result)
    }

    func testParseReplayGainValueReturnsNilForEmptyString() {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())

        let result = service.parseReplayGainValue("")

        XCTAssertNil(result)
    }
}
