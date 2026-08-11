@testable import Fonic_HiFi
import Foundation
import Testing

@Suite("Failure Presentation State Tests")
struct FailurePresentationStateTests {
    struct PickerFailureScenario: Sendable {
        let surface: ImportPickerSurface
        let expectedTitle: String
        let expectedMessageFragment: String
    }

    struct ImportAutoDismissScenario: Sendable {
        let statusMessage: String
        let totalFiles: Int
        let hasErrors: Bool
        let isImportComplete: Bool
        let expected: Bool
    }

    @Test("Home load failures are distinct from empty content and retryable")
    @MainActor
    func homeLoadFailureInjection() throws {
        var state = HomeLoadPresentationState()

        state.recordFailure(hasContent: false)
        let initialFailure = try #require(state.failure)
        #expect(initialFailure.context == .initial)
        #expect(initialFailure.title == "Couldn't Load Home")
        #expect(initialFailure.message.contains("Try again"))

        state.beginRequest()
        #expect(state.failure == nil)

        state.recordFailure(hasContent: true)
        let refreshFailure = try #require(state.failure)
        #expect(refreshFailure.context == .refresh)
        #expect(refreshFailure.title == "Home Couldn't Refresh")
        #expect(refreshFailure.message.contains("existing music"))

        state.clearFailure()
        #expect(state.failure == nil)
    }

    @Test("Standard search failures retain a retry query instead of presenting no results")
    @MainActor
    func standardSearchFailureInjection() throws {
        var state = StandardSearchPresentationState()

        state.recordFailure(query: "ambient")
        let requestFailure = try #require(state.failure)
        #expect(requestFailure.query == "ambient")
        #expect(requestFailure.title == "Search Failed")
        #expect(requestFailure.message.contains("Try again"))

        state.beginSearch()
        #expect(state.failure == nil)

        state.recordUnavailable(query: "jazz")
        let unavailable = try #require(state.failure)
        #expect(unavailable.query == "jazz")
        #expect(unavailable.title == "Search Unavailable")

        state.recordSuccess()
        #expect(state.failure == nil)
    }

    @Test(
        "Picker failures become surface-specific recoverable alerts",
        arguments: [
            PickerFailureScenario(
                surface: .fileSelection,
                expectedTitle: "Unable to Select Files",
                expectedMessageFragment: "your selection"
            ),
            PickerFailureScenario(
                surface: .fileManager,
                expectedTitle: "Unable to Import Files",
                expectedMessageFragment: "import request"
            ),
        ]
    )
    func pickerFailureInjection(_ scenario: PickerFailureScenario) {
        let result = ImportPickerSelection.resolve(
            .failure(FailurePresentationTestError.injected),
            surface: scenario.surface
        )

        guard case let .failed(failure) = result else {
            Issue.record("Expected injected picker failure", severity: .error)
            return
        }

        #expect(failure.surface == scenario.surface)
        #expect(failure.title == scenario.expectedTitle)
        #expect(failure.message.contains(scenario.expectedMessageFragment))
        #expect(failure.message.contains("Try again"))
    }

    @Test("Picker success returns the selected URLs without an error state")
    func pickerSuccess() {
        let urls = [
            URL(fileURLWithPath: "/tmp/one.flac"),
            URL(fileURLWithPath: "/tmp/two.wav"),
        ]

        let result = ImportPickerSelection.resolve(
            .success(urls),
            surface: .fileSelection
        )

        #expect(result == .selected(urls))
    }

    @Test("Import progress snapshots expose live counts and completion failures")
    func importProgressAndCompletionErrors() throws {
        let running = ImportProgressPresentationState(
            progress: 0.25,
            filesProcessed: 1,
            totalFiles: 4,
            statusMessage: "Processed 1 of 4 files",
            isImporting: true,
            isImportComplete: false,
            errors: []
        )
        let importError = ImportError(
            url: URL(fileURLWithPath: "/tmp/broken.flac"),
            error: FailurePresentationTestError.injected,
            message: "Failed to import file"
        )
        let completed = ImportProgressPresentationState(
            progress: 1,
            filesProcessed: 4,
            totalFiles: 4,
            statusMessage: "Import completed: 3 imported, 0 skipped, 1 failed",
            isImporting: false,
            isImportComplete: true,
            errors: [importError]
        )

        #expect(running.isImporting)
        #expect(running.progress == 0.25)
        #expect(running.filesProcessed == 1)
        #expect(running.totalFiles == 4)
        #expect(running.failedFileCount == 0)

        #expect(!completed.isImporting)
        #expect(completed.progress == 1)
        #expect(completed.failedFileCount == 1)
        let firstError = try #require(completed.errors.first)
        #expect(firstError.message == "Failed to import file")
    }

    @Test(
        "Only clean import completion dismisses automatically",
        arguments: [
            ImportAutoDismissScenario(
                statusMessage: "Import completed: 2 imported, 0 skipped, 0 failed",
                totalFiles: 2,
                hasErrors: false,
                isImportComplete: true,
                expected: true
            ),
            ImportAutoDismissScenario(
                statusMessage: "Import completed: 0 imported, 2 skipped, 0 failed",
                totalFiles: 2,
                hasErrors: false,
                isImportComplete: true,
                expected: true
            ),
            ImportAutoDismissScenario(
                statusMessage: "Import cancelled",
                totalFiles: 2,
                hasErrors: false,
                isImportComplete: false,
                expected: false
            ),
            ImportAutoDismissScenario(
                statusMessage: "No audio files found",
                totalFiles: 0,
                hasErrors: false,
                isImportComplete: false,
                expected: false
            ),
            ImportAutoDismissScenario(
                statusMessage: "Import completed: 1 imported, 0 skipped, 1 failed",
                totalFiles: 2,
                hasErrors: true,
                isImportComplete: true,
                expected: false
            ),
            ImportAutoDismissScenario(
                statusMessage: "Importation terminée",
                totalFiles: 2,
                hasErrors: false,
                isImportComplete: true,
                expected: true
            ),
            ImportAutoDismissScenario(
                statusMessage: "Import completed: 2 imported, 0 skipped, 0 failed",
                totalFiles: 2,
                hasErrors: false,
                isImportComplete: false,
                expected: false
            ),
        ]
    )
    func importAutoDismissPolicy(_ scenario: ImportAutoDismissScenario) {
        let errors = scenario.hasErrors ? [
            ImportError(
                url: URL(fileURLWithPath: "/tmp/broken.flac"),
                error: FailurePresentationTestError.injected,
                message: "Failed to import file"
            ),
        ] : []
        let state = ImportProgressPresentationState(
            progress: 1,
            filesProcessed: scenario.totalFiles,
            totalFiles: scenario.totalFiles,
            statusMessage: scenario.statusMessage,
            isImporting: false,
            isImportComplete: scenario.isImportComplete,
            errors: errors
        )

        #expect(state.shouldAutoDismiss == scenario.expected)
    }
}

private enum FailurePresentationTestError: Error {
    case injected
}
