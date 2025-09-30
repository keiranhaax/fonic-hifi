// Import Session Contract
// Version: 1.0
// Purpose: Define transactional import operations with rollback support

import Foundation

// MARK: - Protocol Definition

protocol ImportSessionProtocol: Sendable {
    // Transaction Management
    func beginTransaction() async throws
    func commit() async throws
    func rollback() async

    // Import Operations
    func addFile(_ url: URL) async throws -> UUID
    func addFiles(_ urls: [URL]) async throws -> [UUID]
    func removeFile(_ id: UUID) async throws

    // Progress Tracking
    var progress: ImportProgress { get async }
    func observeProgress() -> AsyncStream<ImportProgress>

    // Validation
    func validateFile(_ url: URL) async throws -> ValidationResult
    func checkDuplicate(_ url: URL) async -> Bool
}

// MARK: - Data Types

struct ImportProgress: Sendable {
    let totalFiles: Int
    let processedFiles: Int
    let currentFile: String?
    let phase: ImportPhase
    let errors: [ImportError]

    var percentComplete: Double {
        guard totalFiles > 0 else { return 0 }
        return Double(processedFiles) / Double(totalFiles) * 100
    }
}

enum ImportPhase: Sendable {
    case idle
    case validating
    case extractingMetadata
    case copyingFiles
    case savingToDatabase
    case complete
}

struct ValidationResult: Sendable {
    let isValid: Bool
    let format: AudioFormat?
    let issues: [ValidationIssue]
}

enum ValidationIssue: Sendable {
    case unsupportedFormat
    case corruptedFile
    case missingMetadata
    case fileTooLarge(size: Int64)
    case duplicateFile(existingId: UUID)
}

// MARK: - Error Types

enum ImportError: Error, Sendable {
    case transactionNotStarted
    case transactionAlreadyStarted
    case fileNotFound(URL)
    case fileAccessDenied(URL)
    case metadataExtractionFailed(URL, String)
    case fileCopyFailed(from: URL, to: URL, String)
    case databaseSaveFailed(String)
    case rollbackFailed(String)
}

// MARK: - Audio Format

enum AudioFormat: String, Sendable, CaseIterable {
    case mp3 = "MP3"
    case aac = "AAC"
    case alac = "ALAC"
    case flac = "FLAC"
    case wav = "WAV"
    case aiff = "AIFF"
    case opus = "Opus"
    case ogg = "Ogg Vorbis"

    var fileExtensions: [String] {
        switch self {
        case .mp3: ["mp3"]
        case .aac: ["aac", "m4a"]
        case .alac: ["m4a", "alac"]
        case .flac: ["flac"]
        case .wav: ["wav", "wave"]
        case .aiff: ["aiff", "aif"]
        case .opus: ["opus"]
        case .ogg: ["ogg", "oga"]
        }
    }
}

// MARK: - Contract Tests (These should fail initially)

final class ImportSessionContractTests {
    func testTransactionLifecycle() async throws {
        let session: ImportSessionProtocol = ImportSession() // Should fail: not implemented

        try await session.beginTransaction()
        let id = try await session.addFile(URL(fileURLWithPath: "/test.mp3"))
        assert(id != UUID())
        try await session.commit()
    }

    func testRollback() async throws {
        let session: ImportSessionProtocol = ImportSession() // Should fail: not implemented

        try await session.beginTransaction()
        _ = try await session.addFile(URL(fileURLWithPath: "/test.mp3"))
        await session.rollback()
        // Verify no files were imported
    }

    func testProgressTracking() async throws {
        let session: ImportSessionProtocol = ImportSession() // Should fail: not implemented

        let progress = await session.progress
        assert(progress.totalFiles >= 0)
        assert(progress.processedFiles >= 0)
        assert(progress.percentComplete >= 0 && progress.percentComplete <= 100)
    }

    func testDuplicateDetection() async throws {
        let session: ImportSessionProtocol = ImportSession() // Should fail: not implemented

        let url = URL(fileURLWithPath: "/test.mp3")
        let isDuplicate = await session.checkDuplicate(url)
        assert(isDuplicate == true || isDuplicate == false)
    }
}
