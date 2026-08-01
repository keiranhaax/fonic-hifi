@testable import Fonic_HiFi
import XCTest

final class AudioFormatTypeTests: XCTestCase {
    func testFromFileExtensionResolvesCaseInsensitively() {
        XCTAssertEqual(AudioFormatType.from(fileExtension: "FLAC"), .flac)
        XCTAssertEqual(AudioFormatType.from(fileExtension: "m4a"), .aac)
        XCTAssertEqual(AudioFormatType.from(fileExtension: "OpUs"), .unknown)
        XCTAssertEqual(AudioFormatType.from(fileExtension: "unknown"), .unknown)
    }

    func testLosslessAndCompressedCollectionsMatchDeclaredFormats() {
        let losslessSet = Set(AudioFormatType.losslessFormats)
        XCTAssertEqual(losslessSet, [.flac, .alac, .aiff, .wav])

        let compressedSet = Set(AudioFormatType.compressedFormats)
        XCTAssertEqual(compressedSet, [.mp3, .aac])

        XCTAssertTrue(losslessSet.isDisjoint(with: compressedSet))
        XCTAssertFalse(losslessSet.contains(.unknown))
        XCTAssertFalse(compressedSet.contains(.unknown))
    }

    func testHighResolutionFormatsIncludeExpectedMembers() {
        let highRes = Set(AudioFormatType.highResolutionFormats)
        XCTAssertEqual(highRes, [.flac, .alac, .aiff, .wav])
        XCTAssertFalse(highRes.contains(.mp3))
        XCTAssertFalse(highRes.contains(.aac))
    }

    func testComparableRanksLosslessBeforeLossyAndByBitDepth() throws {
        let ordered = AudioFormatType.allCases.sorted()

        guard
            let flacIndex = ordered.firstIndex(of: .flac),
            let wavIndex = ordered.firstIndex(of: .wav),
            let mp3Index = ordered.firstIndex(of: .mp3),
            let aacIndex = ordered.firstIndex(of: .aac)
        else {
            XCTFail("Missing expected cases in ordering")
            return
        }

        XCTAssertLessThan(flacIndex, mp3Index)
        XCTAssertLessThan(wavIndex, aacIndex)

        let alacIndex = try XCTUnwrap(ordered.firstIndex(of: .alac))
        XCTAssertLessThan(alacIndex, aacIndex)

        let unknownIndex = try XCTUnwrap(ordered.firstIndex(of: .unknown))
        XCTAssertLessThan(aacIndex, unknownIndex)
    }

    func testImportableExtensionsHaveARepresentablePlaybackPath() {
        for fileExtension in AudioFormat.supportedExtensions {
            let url = URL(fileURLWithPath: "/fixture.\(fileExtension)")
            let format = AudioFormat.from(url: url)
            XCTAssertNotNil(format, "Missing format representation for .\(fileExtension)")
            XCTAssertTrue(
                AudioEngineType.allCases.contains { engine in
                    format.map(engine.canHandle) ?? false
                },
                "Missing playback path for .\(fileExtension)"
            )
        }
    }

    func testUnsupportedFormatsAreNotAdvertisedForImport() {
        for fileExtension in ["ape", "dsd", "dsf", "dff", "wv", "ogg", "opus", "wma"] {
            XCTAssertFalse(AudioFormat.isSupportedFileExtension(fileExtension))
            XCTAssertEqual(AudioFormatType.from(fileExtension: fileExtension), .unknown)
        }
    }
}
