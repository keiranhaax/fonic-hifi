@testable import Fonic_HiFi
import XCTest

final class AudioFormatTests: XCTestCase {
    func testFromURLHandlesM4AExtension() {
        let m4aURL = URL(fileURLWithPath: "/test/song.m4a")
        let format = AudioFormat.from(url: m4aURL)
        // Match AudioFormatType behavior: m4a -> alac
        XCTAssertEqual(format, .alac, "M4A container should map to ALAC codec (matching AudioFormatType)")
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
        XCTAssertEqual(format, .alac, "Extension matching should be case-insensitive")
    }
}
