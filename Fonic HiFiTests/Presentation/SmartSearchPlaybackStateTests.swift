import Foundation
import Testing
@testable import Fonic_HiFi

@Suite("Smart Search Playback State Tests")
struct SmartSearchPlaybackStateTests {
    @Test("Playback failures become visible")
    @MainActor
    func playbackFailureBecomesVisible() async {
        let state = SmartSearchPlaybackState()

        await state.play(makeTrack()) { _ in
            throw SmartSearchPlaybackTestError.failed
        }

        #expect(state.errorMessage == "Playback unavailable")
    }

    @Test("Cancellation does not become an error")
    @MainActor
    func cancellationIsNotAnError() async {
        let state = SmartSearchPlaybackState()

        await state.play(makeTrack()) { _ in throw CancellationError() }

        #expect(state.errorMessage == nil)
    }

    @Test("Successful playback clears an earlier error")
    @MainActor
    func successfulPlaybackClearsError() async {
        let state = SmartSearchPlaybackState()
        state.reportUnavailable()
        var playedTrackID: UUID?
        let track = makeTrack()

        await state.play(track) { playedTrackID = $0.id }

        #expect(playedTrackID == track.id)
        #expect(state.errorMessage == nil)
    }

    @MainActor
    private func makeTrack() -> Track {
        Track(
            url: URL(fileURLWithPath: "/tmp/smart-search.flac"),
            title: "Result",
            audioFormat: "FLAC"
        )
    }
}

private enum SmartSearchPlaybackTestError: LocalizedError {
    case failed

    var errorDescription: String? { "Playback unavailable" }
}
