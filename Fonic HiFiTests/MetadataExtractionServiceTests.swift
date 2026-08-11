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

private struct StubMetadataAssetLoader: MetadataAssetLoading {
    let snapshot: MetadataAssetSnapshot

    func load(from _: URL) async throws -> MetadataAssetSnapshot {
        snapshot
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

    func testExtractTrackMetadataReadsNumberTuplesFromM4AFixtures() async throws {
        for fixture in M4ATupleFixture.allCases {
            let url = try fixture.write(testCase: self)
            let detected = AudioFileInfo.create(url: url, format: fixture.audioFormat)
            let service = MetadataExtractionService(
                formatDetectionService: StubFormatDetectionService(results: [url: detected])
            )

            let metadata = try await service.extractTrackMetadata(from: url)

            XCTAssertEqual(metadata.trackNumber, 3, fixture.rawValue)
            XCTAssertEqual(metadata.totalTracks, 12, fixture.rawValue)
            XCTAssertEqual(metadata.discNumber, 2, fixture.rawValue)
            XCTAssertEqual(metadata.totalDiscs, 3, fixture.rawValue)
        }
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

    func testExtractYearUsesUTF16RangeForUnicodeMetadata() async throws {
        let url = try makePCMTestAudioFile(testCase: self)
        let detected = AudioFileInfo.create(
            url: url,
            format: .wav,
            sampleRate: 44_100,
            bitDepth: 16,
            channels: 2,
            bitrate: 1_411_200,
            duration: 0.25
        )
        let snapshot = MetadataAssetSnapshot(
            duration: 0.25,
            metadata: [
                MetadataItemSnapshot(
                    commonKey: "creationDate",
                    identifier: nil,
                    key: nil,
                    stringValue: "Música 2024",
                    dataValue: nil
                ),
            ],
            commonMetadata: []
        )
        let service = MetadataExtractionService(
            formatDetectionService: StubFormatDetectionService(results: [url: detected]),
            metadataLoader: StubMetadataAssetLoader(snapshot: snapshot)
        )

        let metadata = try await service.extractTrackMetadata(from: url)

        XCTAssertEqual(metadata.year, 2024)
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

    func testExtractReplayGainReadsTrackAndAlbumTagFixtures() async throws {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())
        let trackGain = AVMutableMetadataItem()
        trackGain.key = "REPLAYGAIN_TRACK_GAIN" as NSString
        trackGain.value = "-6.5 dB" as NSString
        let albumGain = AVMutableMetadataItem()
        albumGain.key = "REPLAYGAIN_ALBUM_GAIN" as NSString
        albumGain.value = "-4.25 dB" as NSString

        let result = try await service.extractReplayGain(from: [trackGain, albumGain])

        XCTAssertEqual(try XCTUnwrap(result.track), -6.5, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(result.album), -4.25, accuracy: 0.001)
    }

    // MARK: - iTunes Number Tuple Tests

    func testParseITunesNumberTupleReadsNumberAndTotal() {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())
        let trackTuple = Data([0x00, 0x00, 0x00, 0x03, 0x00, 0x0C, 0x00, 0x00])
        let discTuple = Data([0x00, 0x00, 0x00, 0x02, 0x00, 0x03, 0x00, 0x00])

        let track = service.parseITunesNumberTuple(trackTuple)
        let disc = service.parseITunesNumberTuple(discTuple)

        XCTAssertEqual(track.number, 3)
        XCTAssertEqual(track.total, 12)
        XCTAssertEqual(disc.number, 2)
        XCTAssertEqual(disc.total, 3)
    }

    func testParseITunesNumberTupleHandlesZeroAndShortData() {
        let service = MetadataExtractionService(formatDetectionService: StubFormatDetectionService())

        let zeroTuple = service.parseITunesNumberTuple(Data(repeating: 0, count: 8))
        let numberOnlyTuple = service.parseITunesNumberTuple(Data([0x00, 0x00, 0x00, 0x07]))
        let shortTuple = service.parseITunesNumberTuple(Data([0x00, 0x00, 0x00]))

        XCTAssertNil(zeroTuple.number)
        XCTAssertNil(zeroTuple.total)
        XCTAssertEqual(numberOnlyTuple.number, 7)
        XCTAssertNil(numberOnlyTuple.total)
        XCTAssertNil(shortTuple.number)
        XCTAssertNil(shortTuple.total)
    }
}

private enum M4ATupleFixture: String, CaseIterable {
    case aac
    case alac

    var audioFormat: AudioFormat {
        switch self {
        case .aac: .aac
        case .alac: .alac
        }
    }

    func write(testCase: XCTestCase) throws -> URL {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("tuple-\(rawValue).m4a")
        let data = try XCTUnwrap(Data(base64Encoded: base64, options: .ignoreUnknownCharacters))
        try data.write(to: url)
        testCase.addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return url
    }

    private var base64: String {
        switch self {
        case .aac:
            """
            AAAAHGZ0eXBNNEEgAAACAE00QSBpc29taXNvMgAAAAhmcmVlAAADSW1kYXTeAgBMYXZjNjIuMjguMTAxAAIwaFtorVsLT5q8CF5M
            qQmIQRvg//cNJbh424t2do3699h/pfvflvifgv1P+qzQUUDwV3RGMorGz9aoDEp5kKPYdHN9aR2Vu19OW4so623be7p0t0z9S8x6
            jyR4BKJiQUkYIbvmEJ0MnDn5UoERxSTiWo2ixvjeHfP1KXQdnzBANZ7+4jtPCDKXuLjPN9cNyeqZHLuiWM3mGY69nmPQYaee5Ktm
            DFHRUtzaHPdSUw6h2bSMYbpclm7RpyPPljw6rF369XVm+XPt2ZlPtw49Lkz3aNOTZ78dOVku/Xq6s3y5yT5lFldGdyWWzS3MtzS5
            GN1NU9jxfJPmUWV0Z3JZbNLcy3NLkY3U1T2PF8k+ZRZXRnclls0tzLc0uRjdTVPY8XyT2FFj0Z2ots0tzLc0uRjDVT2PF7z2FFj0
            Z2ots0tzS3NLleN1NWVjxe89hRY9GdqLbRLcy3NLkYwYwYwYwpIropIpIsNLc0uV9V1NWVjz3yT2PPY8+dqLbRLc0tzS5X1XHVlY
            897z2PPY8+dqLbRLc0tzS5XjcdWVjz3vPY89jz52kuFziHEuDz/xslyKOQ6DxQnpugEtHsSHH8yTy3IyW005DoeiJ8Y56Sg8fuzi
            5PgfFSVLhxDmJyfN+TkMLzojusmT45siFbkBHhmKJ9D3xDgHQSOH4UT49YIbDjpHK7wnzvBEOU81Jr5eS4ZPIcS4LafGSXIIZDn/
            Fiek6CS0myIcgy/AAOA0LGkykzP/GVvGW0tqvPMlUiEIED27Z/yv3bmv9z39rf0n3bi/8T39o/wX6Vxn6DdRViqKsVREqdUklqkg
            39r/+v2Xy3/6/IuZJapKYLRViqKsVAiSWqSS1SQaFoqxVFWK6S1J9Z8Eklqkg0qirFUVYqBAm5zm3Ocy2ZWufK1AhW5zm3Ocy2ZW
            ufK1zxT7nObc5zLZla58rXOhW5zm3Ocy3srXPla50K3Oc25zmWzK1z5WoIp9znNuc5qHsrXPla50K3Oc25zmWzK1z5WudCtznNuc
            5lsytc+VrnQrc5zbnJlsma58rUCJ9znNuc5qHsrXPla54p9znNuc5qHsrXPla54p9znNwAAAA0Ntb292AAAAbG12aGQAAAAAAAAA
            AAAAAAAAAAPoAAAAFAABAAABAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAA
            AAAAAAAAAAAAAAAAAAAAAAACAAACLXRyYWsAAABcdGtoZAAAAAMAAAAAAAAAAAAAAAEAAAAAAAAAFAAAAAAAAAAAAAAAAQEAAAAA
            AQAAAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAEAAAAAAAAAAAAAAAAAAACRlZHRzAAAAHGVsc3QAAAAAAAAAAQAAABQAAAQA
            AAEAAAAAAaVtZGlhAAAAIG1kaGQAAAAAAAAAAAAAAAAAAB9AAAAEoFXEAAAAAAAtaGRscgAAAAAAAAAAc291bgAAAAAAAAAAAAAA
            AFNvdW5kSGFuZGxlcgAAAAFQbWluZgAAABBzbWhkAAAAAAAAAAAAAAAkZGluZgAAABxkcmVmAAAAAAAAAAEAAAAMdXJsIAAAAAEA
            AAEUc3RibAAAAGpzdHNkAAAAAAAAAAEAAABabXA0YQAAAAAAAAABAAAAAAAAAAAAAQAQAAAAAB9AAAAAAAA2ZXNkcwAAAAADgICA
            JQABAASAgIAXQBUAAAAAAK/jAACv4wWAgIAFFYhW5QAGgICAAQIAAAAgc3R0cwAAAAAAAAACAAAAAQAABAAAAAABAAAAoAAAABxz
            dHNjAAAAAAAAAAEAAAABAAAAAgAAAAEAAAAcc3RzegAAAAAAAAAAAAAAAgAAAjgAAAEJAAAAFHN0Y28AAAAAAAAAAQAAACwAAAAa
            c2dwZAEAAAByb2xsAAAAAgAAAAH//wAAABxzYmdwAAAAAHJvbGwAAAABAAAAAgAAAAEAAACidWR0YQAAAJptZXRhAAAAAAAAACFo
            ZGxyAAAAAAAAAABtZGlyYXBwbAAAAAAAAAAAAAAAAG1pbHN0AAAAJal0b28AAAAdZGF0YQAAAAEAAAAATGF2ZjYyLjEyLjEwMQAA
            ACB0cmtuAAAAGGRhdGEAAAAAAAAAAAAAAAMADAAAAAAAIGRpc2sAAAAYZGF0YQAAAAAAAAAAAAAAAgADAAA=
            """
        case .alac:
            """
            AAAAHGZ0eXBNNEEgAAACAE00QSBpc29taXNvMgAAAAhmcmVlAAAAum1kYXQAABAAAAFAAAALDADR/uwA0/98AE3/6A/4Vq/8Jjv4
            u7mC/pMJAUDBcrDsGRARwcV1hBM1gvGUApJCkALkkqJ6cajkIIIRVIb79Msw51qs9eWkBBJyXbrtdVqymxWcsJRgg8bred2PSyUA
            UbnJ8WxyMbQAK21ZiLrKR1CHTSChCWggmWZi9cXPjRZwz67D8+tJoKOi0OP2PO8OrlFBVZmPMhzlHw421zPG8W3oGRHJYNJwAAAC
            621vb3YAAABsbXZoZAAAAAAAAAAAAAAAAAAAA+gAAAAUAAEAAAEAAAAAAAAAAAAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAA
            AAAAAAAAQAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAIAAAHVdHJhawAAAFx0a2hkAAAAAwAAAAAAAAAAAAAAAQAAAAAA
            AAAUAAAAAAAAAAAAAAABAQAAAAABAAAAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAQAAAAAAAAAAAAAAAAAAAJGVkdHMAAAAc
            ZWxzdAAAAAAAAAABAAAAFAAAAAAAAQAAAAABTW1kaWEAAAAgbWRoZAAAAAAAAAAAAAAAAAAAH0AAAACgVcQAAAAAAC1oZGxyAAAA
            AAAAAABzb3VuAAAAAAAAAAAAAAAAU291bmRIYW5kbGVyAAAAAPhtaW5mAAAAEHNtaGQAAAAAAAAAAAAAACRkaW5mAAAAHGRyZWYA
            AAAAAAAAAQAAAAx1cmwgAAAAAQAAALxzdGJsAAAAWHN0c2QAAAAAAAAAAQAAAEhhbGFjAAAAAAAAAAEAAAAAAAAAAAABABAAAAAA
            H0AAAAAAACRhbGFjAAAAAAAAEAAAECgKDgEAAAAAIAQAAfQAAAAfQAAAABhzdHRzAAAAAAAAAAEAAAABAAAAoAAAABxzdHNjAAAA
            AAAAAAEAAAABAAAAAQAAAAEAAAAUc3RzegAAAAAAAACyAAAAAQAAABRzdGNvAAAAAAAAAAEAAAAsAAAAonVkdGEAAACabWV0YQAA
            AAAAAAAhaGRscgAAAAAAAAAAbWRpcmFwcGwAAAAAAAAAAAAAAABtaWxzdAAAACWpdG9vAAAAHWRhdGEAAAABAAAAAExhdmY2Mi4x
            Mi4xMDEAAAAgdHJrbgAAABhkYXRhAAAAAAAAAAAAAAADAAwAAAAAACBkaXNrAAAAGGRhdGEAAAAAAAAAAAAAAAIAAwAA
            """
        }
    }
}
