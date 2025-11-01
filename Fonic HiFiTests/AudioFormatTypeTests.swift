@testable import Fonic_HiFi
import XCTest

final class AudioFormatTypeTests: XCTestCase {
    func testFromFileExtensionResolvesCaseInsensitively() {
        XCTAssertEqual(AudioFormatType.from(fileExtension: "FLAC"), .flac)
        XCTAssertEqual(AudioFormatType.from(fileExtension: "m4a"), .alac)
        XCTAssertEqual(AudioFormatType.from(fileExtension: "OpUs"), .opus)
        XCTAssertEqual(AudioFormatType.from(fileExtension: "unknown"), .unknown)
    }

    func testLosslessAndCompressedCollectionsMatchDeclaredFormats() {
        let losslessSet = Set(AudioFormatType.losslessFormats)
        XCTAssertEqual(losslessSet, [.flac, .alac, .aiff, .wav, .ape, .dsd, .wavpack])

        let compressedSet = Set(AudioFormatType.compressedFormats)
        XCTAssertEqual(compressedSet, [.mp3, .aac, .ogg, .opus])

        XCTAssertTrue(losslessSet.isDisjoint(with: compressedSet))
        XCTAssertFalse(losslessSet.contains(.unknown))
        XCTAssertFalse(compressedSet.contains(.unknown))
    }

    func testHighResolutionFormatsIncludeExpectedMembers() {
        let highRes = Set(AudioFormatType.highResolutionFormats)
        XCTAssertTrue(highRes.isSuperset(of: [.flac, .alac, .aiff, .wav, .dsd]))
        XCTAssertFalse(highRes.contains(.mp3))
        XCTAssertFalse(highRes.contains(.aac))
    }

    func testComparableRanksLosslessBeforeLossyAndByBitDepth() throws {
        let ordered = AudioFormatType.allCases.sorted()

        guard
            let flacIndex = ordered.firstIndex(of: .flac),
            let wavIndex = ordered.firstIndex(of: .wav),
            let mp3Index = ordered.firstIndex(of: .mp3),
            let opusIndex = ordered.firstIndex(of: .opus)
        else {
            XCTFail("Missing expected cases in ordering")
            return
        }

        XCTAssertLessThan(flacIndex, mp3Index)
        XCTAssertLessThan(wavIndex, opusIndex)

        let alacIndex = try XCTUnwrap(ordered.firstIndex(of: .alac))
        let aacIndex = try XCTUnwrap(ordered.firstIndex(of: .aac))
        XCTAssertLessThan(alacIndex, aacIndex)

        let wavPackIndex = try XCTUnwrap(ordered.firstIndex(of: .wavpack))
        let unknownIndex = try XCTUnwrap(ordered.firstIndex(of: .unknown))
        XCTAssertLessThan(wavPackIndex, unknownIndex)
    }
}
