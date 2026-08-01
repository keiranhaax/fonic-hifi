@testable import Fonic_HiFi
import Foundation
import XCTest

@MainActor
final class FileManagerViewModelTests: XCTestCase {
    private var rootDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileManagerViewModelTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: rootDirectory,
            withIntermediateDirectories: true
        )
    }

    override func tearDown() async throws {
        if let rootDirectory {
            try? FileManager.default.removeItem(at: rootDirectory)
        }
        rootDirectory = nil
        try await super.tearDown()
    }

    func testListSearchAndSortUseObservableSnapshot() async throws {
        let older = rootDirectory.appendingPathComponent("Alpha.mp3")
        let newer = rootDirectory.appendingPathComponent("Beta.flac")
        try Data(repeating: 1, count: 4).write(to: older)
        try Data(repeating: 2, count: 12).write(to: newer)
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 100)],
            ofItemAtPath: older.path
        )
        try FileManager.default.setAttributes(
            [.modificationDate: Date(timeIntervalSince1970: 200)],
            ofItemAtPath: newer.path
        )

        let viewModel = makeViewModel()
        await viewModel.loadDirectoryContents()

        XCTAssertEqual(viewModel.filteredContents.map(\.name), ["Alpha.mp3", "Beta.flac"])

        viewModel.searchText = "beta"
        XCTAssertEqual(viewModel.filteredContents.map(\.name), ["Beta.flac"])

        viewModel.searchText = ""
        viewModel.sortOption = .date
        XCTAssertEqual(viewModel.filteredContents.map(\.name), ["Beta.flac", "Alpha.mp3"])

        viewModel.sortOption = .size
        XCTAssertEqual(viewModel.filteredContents.map(\.name), ["Beta.flac", "Alpha.mp3"])
    }

    func testServiceCreatesFolderAndUsesCollisionSafeCopyNames() async throws {
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileManagerSource-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: sourceDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: sourceDirectory) }

        let source = sourceDirectory.appendingPathComponent("Track.mp3")
        let contents = Data("audio fixture".utf8)
        try contents.write(to: source)

        let service = FileSystemService(rootDirectory: rootDirectory)
        try await service.createDirectory(named: "Music", in: rootDirectory)
        try await service.copyItems(at: [source, source], to: rootDirectory)

        let items = try await service.listDirectory(at: rootDirectory)
        XCTAssertEqual(
            Set(items.map(\.name)),
            Set(["Music", "Track.mp3", "Track copy 1.mp3"])
        )
        XCTAssertEqual(
            try Data(contentsOf: rootDirectory.appendingPathComponent("Track copy 1.mp3")),
            contents
        )
    }

    func testServiceRejectsLocationsOutsideConfiguredRoot() async {
        let service = FileSystemService(rootDirectory: rootDirectory)

        do {
            _ = try await service.listDirectory(
                at: rootDirectory.deletingLastPathComponent()
            )
            XCTFail("Expected an outside-root failure")
        } catch let error as FileSystemServiceError {
            XCTAssertEqual(error, .outsideRoot)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        let escapeLink = rootDirectory.appendingPathComponent("Outside")
        do {
            try FileManager.default.createSymbolicLink(
                at: escapeLink,
                withDestinationURL: rootDirectory.deletingLastPathComponent()
            )
            _ = try await service.listDirectory(at: escapeLink)
            XCTFail("Expected a symlink escape to be rejected")
        } catch let error as FileSystemServiceError {
            XCTAssertEqual(error, .outsideRoot)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testServiceRejectsPathTraversalFolderName() async {
        let service = FileSystemService(rootDirectory: rootDirectory)

        do {
            try await service.createDirectory(named: "../Outside", in: rootDirectory)
            XCTFail("Expected an invalid-folder-name failure")
        } catch let error as FileSystemServiceError {
            XCTAssertEqual(error, .invalidFolderName)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testServiceCopyFailureLeavesNoDestination() async throws {
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileManagerDirectorySource-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: sourceDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: sourceDirectory) }

        let service = FileSystemService(rootDirectory: rootDirectory)

        do {
            try await service.copyItems(at: [sourceDirectory], to: rootDirectory)
            XCTFail("Expected a copy failure for a directory source")
        } catch let error as FileSystemServiceError {
            XCTAssertEqual(error, .copyFailed)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(
            FileManager.default.fileExists(
                atPath: rootDirectory.appendingPathComponent(sourceDirectory.lastPathComponent).path
            )
        )
    }

    func testServiceCancellationRemovesPartialDestination() async throws {
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileManagerCancellationSource-\(UUID().uuidString)")
        try FileManager.default.createDirectory(
            at: sourceDirectory,
            withIntermediateDirectories: true
        )
        defer { try? FileManager.default.removeItem(at: sourceDirectory) }

        let source = sourceDirectory.appendingPathComponent("Large.mp3")
        try Data(repeating: 7, count: 512 * 1024).write(to: source)

        let service = FileSystemService(
            rootDirectory: rootDirectory,
            copyBufferSize: 1
        )
        let destination = rootDirectory.appendingPathComponent(source.lastPathComponent)
        let operation = Task {
            try await service.copyItems(at: [source], to: rootDirectory)
        }

        for _ in 0 ..< 10000 {
            if FileManager.default.fileExists(atPath: destination.path) {
                break
            }
            await Task.yield()
        }
        XCTAssertTrue(FileManager.default.fileExists(atPath: destination.path))

        operation.cancel()
        do {
            try await operation.value
            XCTFail("Expected the copy task to be cancelled")
        } catch is CancellationError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertFalse(FileManager.default.fileExists(atPath: destination.path))
    }

    func testDeleteUpdatesContentsAndSelection() async throws {
        let file = rootDirectory.appendingPathComponent("Delete Me.mp3")
        try Data("fixture".utf8).write(to: file)

        let viewModel = makeViewModel()
        await viewModel.loadDirectoryContents()
        let item = try XCTUnwrap(viewModel.directoryContents.first)
        viewModel.selectedItems = [item]

        await viewModel.deleteSelectedFiles()

        XCTAssertTrue(viewModel.selectedItems.isEmpty)
        XCTAssertTrue(viewModel.directoryContents.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testFailureSurfacesTypedPresentationState() async {
        let viewModel = FileManagerViewModel(
            rootDirectory: rootDirectory,
            service: FailingFileSystemService()
        )

        await viewModel.loadDirectoryContents()

        XCTAssertEqual(viewModel.failure?.operation, .load)
        XCTAssertEqual(
            viewModel.failure?.message,
            FileSystemServiceError.listFailed.errorDescription
        )
        XCTAssertEqual(viewModel.failure?.isCancellation, false)
    }

    func testFailedDirectoryNavigationKeepsPreviousDirectory() async {
        let viewModel = FileManagerViewModel(
            rootDirectory: rootDirectory,
            service: FailingFileSystemService()
        )
        let childURL = rootDirectory.appendingPathComponent("Child", isDirectory: true)
        let item = FileItem(
            id: childURL.absoluteString,
            name: childURL.lastPathComponent,
            url: childURL,
            isDirectory: true,
            size: 0,
            dateModified: .distantPast
        )

        await viewModel.open(item)

        XCTAssertEqual(viewModel.currentDirectory, rootDirectory.standardizedFileURL)
        XCTAssertEqual(viewModel.failure?.operation, .load)
    }

    func testCopyCancellationSurfacesTypedState() async {
        let viewModel = FileManagerViewModel(
            rootDirectory: rootDirectory,
            service: SuspendedFileSystemService()
        )
        let operation = Task {
            await viewModel.copyImportedFiles([
                rootDirectory.appendingPathComponent("Source.mp3"),
            ])
        }

        await Task.yield()
        operation.cancel()
        await operation.value

        XCTAssertEqual(viewModel.failure?.operation, .copy)
        XCTAssertEqual(viewModel.failure?.isCancellation, true)
    }

    private func makeViewModel() -> FileManagerViewModel {
        FileManagerViewModel(
            rootDirectory: rootDirectory,
            service: FileSystemService(rootDirectory: rootDirectory)
        )
    }
}

private struct FailingFileSystemService: FileSystemServicing {
    func listDirectory(at _: URL) async throws -> [FileItem] {
        throw FileSystemServiceError.listFailed
    }

    func createDirectory(named _: String, in _: URL) async throws {
        throw FileSystemServiceError.createDirectoryFailed
    }

    func copyItems(at _: [URL], to _: URL) async throws {
        throw FileSystemServiceError.copyFailed
    }

    func deleteItems(at _: [URL]) async throws {
        throw FileSystemServiceError.deleteFailed
    }
}

private struct SuspendedFileSystemService: FileSystemServicing {
    func listDirectory(at _: URL) async throws -> [FileItem] {
        []
    }

    func createDirectory(named _: String, in _: URL) async throws {}

    func copyItems(at _: [URL], to _: URL) async throws {
        try await Task.sleep(for: .seconds(60))
    }

    func deleteItems(at _: [URL]) async throws {}
}
