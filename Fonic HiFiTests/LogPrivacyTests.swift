@testable import Fonic_HiFi
import XCTest

final class LogPrivacyTests: XCTestCase {
    func testFilenameFromURLReturnsLastPathComponent() {
        let url = URL(fileURLWithPath: "/Users/example/Music/Album/Track.flac")
        XCTAssertEqual(LogPrivacy.filename(url), "Track.flac")
    }

    func testFilenameFromStringHandlesNestedPathsAndUnicode() {
        let path = "/Volumes/📀/Classical/Symphony No. 5.aiff"
        XCTAssertEqual(LogPrivacy.filename(path), "Symphony No. 5.aiff")
    }

    func testTruncatedReturnsOriginalWhenWithinLimit() {
        let value = "Short description"
        XCTAssertEqual(LogPrivacy.truncated(value, limit: 40), value)
    }

    func testTruncatedLimitsLengthAndAppendsEllipsis() {
        let value = String(repeating: "x", count: 100)
        let result = LogPrivacy.truncated(value, limit: 12)
        XCTAssertEqual(result, String(value.prefix(12)) + "…")
        XCTAssertEqual(result.count, 13)
    }
}
