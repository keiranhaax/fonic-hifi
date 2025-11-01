@testable import Fonic_HiFi
import XCTest

final class AudioFileInfoTests: XCTestCase {
    func testFormattingHelpers() {
        let info = makeInfo(
            duration: 185,
            bitDepth: 24,
            sampleRate: 96_000,
            fileSize: 12_345_678
        )

        XCTAssertEqual(info.formattedDuration, "3:05")
        XCTAssertEqual(info.formattedSampleRate, "96 kHz")
        XCTAssertEqual(info.formattedBitDepth, "24-bit")
        XCTAssertEqual(info.technicalDescription, "FLAC 96 kHz/24-bit")
        XCTAssertTrue(info.formattedFileSize.contains("MB"))
    }

    func testMetadataAccessorsAndParsing() {
        let metadata: [String: String] = [
            "title": "Track Title",
            "artist": "Artist Name",
            "album": "Album Name",
            "albumArtist": "Album Artist",
            "trackNumber": "5/12",
            "discNumber": "2",
            "year": "2024",
            "genre": "Jazz",
            "composer": "Composer",
            "comment": "Great track",
            "artworkEmbedded": "true",
        ]

        let info = makeInfo(metadata: metadata)

        XCTAssertEqual(info.title, "Track Title")
        XCTAssertEqual(info.artist, "Artist Name")
        XCTAssertEqual(info.album, "Album Name")
        XCTAssertEqual(info.albumArtist, "Album Artist")
        XCTAssertEqual(info.trackNumber, 5)
        XCTAssertEqual(info.totalTracks, 12)
        XCTAssertEqual(info.discNumber, 2)
        XCTAssertEqual(info.year, 2024)
        XCTAssertEqual(info.genre, "Jazz")
        XCTAssertEqual(info.composer, "Composer")
        XCTAssertEqual(info.comment, "Great track")
        XCTAssertTrue(info.hasArtwork)
    }

    func testQualityRatingAndValidity() {
        let standard = makeInfo(format: .mp3, bitDepth: 16, sampleRate: 44_100)
        XCTAssertEqual(standard.qualityRating, .standard)
        XCTAssertTrue(standard.isValid)

        let cd = makeInfo(format: .flac, bitDepth: 16, sampleRate: 44_100)
        XCTAssertEqual(cd.qualityRating, .compactDisc)

        let hiRes = makeInfo(bitDepth: 24, sampleRate: 192_000)
        XCTAssertEqual(hiRes.qualityRating, .highResolution)

        let invalid = AudioFileInfo(
            url: URL(fileURLWithPath: "/tmp/invalid.flac"),
            format: .flac,
            duration: 0,
            bitDepth: 0,
            sampleRate: 0,
            channels: 0,
            fileSize: 0
        )
        XCTAssertFalse(invalid.isValid)
    }

    func testFactoryHelpers() {
        let unknown = AudioFileInfo.unknown(url: URL(fileURLWithPath: "/tmp/missing.wav"))
        XCTAssertEqual(unknown.format, .unknown)
        XCTAssertFalse(unknown.isValid)

        let minimal = AudioFileInfo.minimal(
            url: URL(fileURLWithPath: "/tmp/sample.flac"),
            format: .flac,
            duration: 123
        )

        XCTAssertEqual(minimal.bitDepth, 16)
        XCTAssertEqual(minimal.sampleRate, 44_100)
        XCTAssertEqual(minimal.channels, 2)
        XCTAssertTrue(minimal.isValid)
    }

    func testMetadataMutations() {
        let base = makeInfo(metadata: ["artist": "Original"])

        let replaced = base.withMetadata(["artist": "New Artist"])
        XCTAssertEqual(replaced.artist, "New Artist")

        let appended = base.addingMetadata(["album": "Great Album"])
        XCTAssertEqual(appended.artist, "Original")
        XCTAssertEqual(appended.album, "Great Album")
    }

    func testDebugDescriptionContainsKeyDetails() {
        let info = makeInfo(duration: 200, fileSize: 9_876_543)
        let description = info.debugDescription

        XCTAssertTrue(description.contains("AudioFileInfo"))
        XCTAssertTrue(description.contains("FLAC"))
        XCTAssertTrue(description.contains("Valid: true"))
    }

    // MARK: - Helpers

    private func makeInfo(
        format: AudioFormat = .flac,
        duration: TimeInterval = 180,
        bitDepth: UInt16 = 24,
        sampleRate: Double = 96_000,
        channels: UInt8 = 2,
        fileSize: UInt64 = 5_000_000,
        bitrate: UInt64? = 2_000_000,
        metadata: [String: String] = [:]
    ) -> AudioFileInfo {
        AudioFileInfo(
            url: URL(fileURLWithPath: "/tmp/sample.flac"),
            format: format,
            duration: duration,
            bitDepth: bitDepth,
            sampleRate: sampleRate,
            channels: channels,
            fileSize: fileSize,
            bitrate: bitrate,
            metadata: metadata,
            codec: "FLAC",
            container: "FLAC",
            supportsGapless: true,
            timestamp: Date(timeIntervalSince1970: 0)
        )
    }
}
