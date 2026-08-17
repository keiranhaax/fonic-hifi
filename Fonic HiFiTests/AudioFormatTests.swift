@testable import Fonic_HiFi
import XCTest

final class AudioFormatTests: XCTestCase {
    func testFromURLHandlesM4AExtension() {
        let m4aURL = URL(fileURLWithPath: "/test/song.m4a")
        let format = AudioFormat.from(url: m4aURL)
        XCTAssertEqual(
            format,
            .aac,
            "An M4A extension is only a container hint; codec inspection may refine it to ALAC"
        )
    }

    func testFromURLHandlesMP3Extension() {
        let mp3URL = URL(fileURLWithPath: "/test/song.mp3")
        let format = AudioFormat.from(url: mp3URL)
        XCTAssertEqual(format, .mp3)
    }

    func testFromURLHandlesUnknownExtension() {
        let unknownURL = URL(fileURLWithPath: "/test/song.xyz")
        let format = AudioFormat.from(url: unknownURL)
        XCTAssertNil(format, "Unknown extensions should return nil")
    }

    func testFromURLIsCaseInsensitive() {
        let upperURL = URL(fileURLWithPath: "/test/song.M4A")
        let format = AudioFormat.from(url: upperURL)
        XCTAssertEqual(format, .aac, "Extension matching should be case-insensitive")
    }
}
