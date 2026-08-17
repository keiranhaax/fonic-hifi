import Darwin
import Foundation

private struct HarnessFailure: Error, CustomStringConvertible {
    let description: String
}

private enum FixtureFile {
    static let playbackState = "playback-state.json"
    static let trackInfo = "track-info.json"
    static let upNextTracks = "up-next-tracks.json"
}

private enum FixtureValues {
    static let currentPlaybackState = WidgetPlaybackState(
        isPlaying: true,
        currentTime: 73.25,
        duration: 181.5,
        shuffleEnabled: true,
        repeatMode: "all",
        hasNext: true,
        hasPrevious: true,
        timestamp: date("2026-07-21T12:34:56Z"),
        playbackRate: 1.25
    )

    static let currentTrackInfo = WidgetTrackInfo(
        id: uuid("BBA7D79F-59C9-405E-AB92-B701D6869788"),
        title: "Current Contract",
        artist: "Fonic Verifier",
        album: "Bidirectional",
        duration: 181.5,
        artworkKey: "current-artwork",
        audioFormat: "ALAC",
        isLossless: true
    )

    static let currentUpNextTracks = [
        WidgetTrackInfo(
            id: uuid("EBF01717-E528-44A3-B777-3F55D8E943ED"),
            title: "Next One",
            artist: "Fonic Verifier",
            album: "Bidirectional",
            duration: 205,
            artworkKey: nil,
            audioFormat: "FLAC",
            isLossless: true
        ),
        WidgetTrackInfo(
            id: uuid("0BAA36BA-3A8E-43E1-AF16-04BE1B60945A"),
            title: "Next Two",
            artist: "Fixture Artist",
            album: "",
            duration: 97.75,
            artworkKey: "next-two-artwork",
            audioFormat: "AAC",
            isLossless: false
        ),
    ]

    static let legacyPlaybackState = WidgetPlaybackState(
        isPlaying: false,
        currentTime: 42.5,
        duration: 245.75,
        shuffleEnabled: false,
        repeatMode: "one",
        hasNext: true,
        hasPrevious: false,
        timestamp: date("2025-11-26T17:00:52Z"),
        playbackRate: 1.0
    )

    static let legacyTrackInfo = WidgetTrackInfo(
        id: uuid("F876A81A-0D36-46E7-B7E6-CBC6B82772F7"),
        title: "Legacy Contract",
        artist: "Baseline Artist",
        album: "Version One",
        duration: 245.75,
        artworkKey: "legacy-artwork",
        audioFormat: "FLAC",
        isLossless: true
    )

    static let legacyUpNextTracks = [
        WidgetTrackInfo(
            id: uuid("99E45757-4C66-4080-93B1-2AC2E18C74F4"),
            title: "Legacy Next",
            artist: "Baseline Artist",
            album: "Version One",
            duration: 190,
            artworkKey: nil,
            audioFormat: "MP3",
            isLossless: false
        ),
        WidgetTrackInfo(
            id: uuid("06F6343F-3301-4AB8-A02E-E26032FE7EAF"),
            title: "Legacy Lossless",
            artist: "Archive Artist",
            album: "Version One",
            duration: 301.25,
            artworkKey: "legacy-lossless-artwork",
            audioFormat: "ALAC",
            isLossless: true
        ),
    ]

    private static func date(_ value: String) -> Date {
        guard let date = ISO8601DateFormatter().date(from: value) else {
            preconditionFailure("Invalid fixture date: \(value)")
        }
        return date
    }

    private static func uuid(_ value: String) -> UUID {
        guard let uuid = UUID(uuidString: value) else {
            preconditionFailure("Invalid fixture UUID: \(value)")
        }
        return uuid
    }
}

@main
private enum WidgetContractFixtureHarness {
    static func main() {
        do {
            try run()
        } catch {
            FileHandle.standardError.write(Data("[FAIL] \(error)\n".utf8))
            Darwin.exit(EXIT_FAILURE)
        }
    }

    private static func run() throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            throw HarnessFailure(description: "Usage: <probe> <encode-current|decode-current|decode-v1> <payload-directory>")
        }

        try validateConstantsAndDefaults()
        let payloadRoot = URL(fileURLWithPath: arguments[2], isDirectory: true)
        switch arguments[1] {
        case "encode-current":
            try encodeCurrentPayloads(to: payloadRoot)
        case "decode-current":
            try decodePayloads(
                from: payloadRoot,
                expectedPlaybackState: FixtureValues.currentPlaybackState,
                expectedTrackInfo: FixtureValues.currentTrackInfo,
                expectedUpNextTracks: FixtureValues.currentUpNextTracks
            )
        case "decode-v1":
            try decodePayloads(
                from: payloadRoot,
                expectedPlaybackState: FixtureValues.legacyPlaybackState,
                expectedTrackInfo: FixtureValues.legacyTrackInfo,
                expectedUpNextTracks: FixtureValues.legacyUpNextTracks
            )
        default:
            throw HarnessFailure(description: "Unknown probe command: \(arguments[1])")
        }
    }

    private static func validateConstantsAndDefaults() throws {
        try require(
            WidgetConstants.appGroupIdentifier == "group.ai.keiranlabs.Fonic-HiFi",
            "App Group identifier changed"
        )
        try require(WidgetConstants.Keys.playbackState == "widget.playbackState", "Playback-state key changed")
        try require(WidgetConstants.Keys.trackInfo == "widget.trackInfo", "Track-info key changed")
        try require(WidgetConstants.Keys.upNextTracks == "widget.upNextTracks", "Up-next key changed")
        try require(WidgetConstants.Keys.lastUpdated == "widget.lastUpdated", "Last-updated key changed")
        try require(WidgetConstants.WidgetKind.nowPlaying == "NowPlayingWidget", "Widget kind changed")
        try require(WidgetConstants.ArtworkCache.directoryName == "WidgetArtwork", "Artwork directory changed")
        try require(WidgetConstants.ArtworkCache.maxCacheSize == 50 * 1024 * 1024, "Artwork cache size changed")
        try require(WidgetConstants.ArtworkCache.thumbnailSize == 200, "Artwork thumbnail size changed")
        try require(WidgetConstants.ArtworkCache.compressionQuality == 0.7, "Artwork compression changed")
        try require(WidgetConstants.ArtworkCache.liveActivityThumbnailSize == 100, "Live Activity thumbnail size changed")
        try require(WidgetConstants.ArtworkCache.liveActivityCompressionQuality == 0.6, "Live Activity compression changed")
        try require(WidgetConstants.Timeline.minimumRefreshInterval == 60, "Timeline refresh interval changed")
        try require(WidgetConstants.Timeline.debounceInterval == 0.5, "Timeline debounce interval changed")

        let defaultedPlaybackRate = WidgetPlaybackState(
            isPlaying: false,
            currentTime: 0,
            duration: 1,
            shuffleEnabled: false,
            repeatMode: "none",
            hasNext: false,
            hasPrevious: false
        ).playbackRate
        try require(defaultedPlaybackRate == 1.0, "Default playback rate changed")
    }

    private static func encodeCurrentPayloads(to payloadRoot: URL) throws {
        try FileManager.default.createDirectory(at: payloadRoot, withIntermediateDirectories: true)
        let defaults = try isolatedDefaults()
        defer { clear(defaults) }

        FixtureValues.currentPlaybackState.save()
        FixtureValues.currentTrackInfo.save()
        FixtureValues.currentUpNextTracks.saveAsUpNext()
        defaults.synchronize()

        try require(defaults.object(forKey: WidgetConstants.Keys.lastUpdated) is Date, "Playback save omitted lastUpdated")
        try writeStoredData(defaults, key: WidgetConstants.Keys.playbackState, filename: FixtureFile.playbackState, to: payloadRoot)
        try writeStoredData(defaults, key: WidgetConstants.Keys.trackInfo, filename: FixtureFile.trackInfo, to: payloadRoot)
        try writeStoredData(defaults, key: WidgetConstants.Keys.upNextTracks, filename: FixtureFile.upNextTracks, to: payloadRoot)
    }

    private static func decodePayloads(
        from payloadRoot: URL,
        expectedPlaybackState: WidgetPlaybackState,
        expectedTrackInfo: WidgetTrackInfo,
        expectedUpNextTracks: [WidgetTrackInfo]
    ) throws {
        let defaults = try isolatedDefaults()
        defer { clear(defaults) }

        try seed(defaults, key: WidgetConstants.Keys.playbackState, filename: FixtureFile.playbackState, from: payloadRoot)
        try seed(defaults, key: WidgetConstants.Keys.trackInfo, filename: FixtureFile.trackInfo, from: payloadRoot)
        try seed(defaults, key: WidgetConstants.Keys.upNextTracks, filename: FixtureFile.upNextTracks, from: payloadRoot)
        defaults.synchronize()

        try require(WidgetPlaybackState.load() == expectedPlaybackState, "Playback-state payload mismatch")
        try require(WidgetTrackInfo.load() == expectedTrackInfo, "Track-info payload mismatch")
        try require([WidgetTrackInfo].loadUpNext() == expectedUpNextTracks, "Up-next payload mismatch")
    }

    private static func isolatedDefaults() throws -> UserDefaults {
        guard let defaults = UserDefaults.appGroup else {
            throw HarnessFailure(description: "App Group UserDefaults unavailable in contract probe")
        }
        clear(defaults)
        return defaults
    }

    private static func clear(_ defaults: UserDefaults) {
        defaults.removePersistentDomain(forName: WidgetConstants.appGroupIdentifier)
        defaults.synchronize()
    }

    private static func writeStoredData(
        _ defaults: UserDefaults,
        key: String,
        filename: String,
        to payloadRoot: URL
    ) throws {
        guard let data = defaults.data(forKey: key) else {
            throw HarnessFailure(description: "Missing stored payload for key: \(key)")
        }
        try data.write(to: payloadRoot.appendingPathComponent(filename), options: .atomic)
    }

    private static func seed(
        _ defaults: UserDefaults,
        key: String,
        filename: String,
        from payloadRoot: URL
    ) throws {
        let payloadURL = payloadRoot.appendingPathComponent(filename)
        guard FileManager.default.fileExists(atPath: payloadURL.path) else {
            throw HarnessFailure(description: "Missing payload fixture: \(payloadURL.path)")
        }
        defaults.set(try Data(contentsOf: payloadURL), forKey: key)
    }

    private static func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else {
            throw HarnessFailure(description: message)
        }
    }
}
