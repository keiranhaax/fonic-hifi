import Foundation
import Observation

@MainActor
@Observable
final class SmartSearchPlaybackState {
    private(set) var errorMessage: String?

    func play(
        _ track: Track,
        using action: @MainActor (Track) async throws -> Void
    ) async {
        errorMessage = nil
        do {
            try await action(track)
        } catch is CancellationError {
            return
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func reportUnavailable() {
        errorMessage = "Playback is unavailable. Please try again."
    }

    func clearError() {
        errorMessage = nil
    }
}
