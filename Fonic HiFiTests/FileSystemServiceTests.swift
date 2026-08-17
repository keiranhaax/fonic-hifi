@testable import Fonic_HiFi
import Foundation
import XCTest

final class FileSystemServiceTests: XCTestCase {
    private var rootDirectory: URL!

    override func setUp() async throws {
        try await super.setUp()
        rootDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemServiceTests-\(UUID().uuidString)", isDirectory: true)
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

    func testManagedMediaRootAndDescendantsCannotBeDeleted() async throws {
        let musicDirectory = rootDirectory.appendingPathComponent("Music", isDirectory: true)
        let trackURL = musicDirectory.appendingPathComponent("Track.bin")
        try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: trackURL)

        let service = FileSystemService(rootDirectory: rootDirectory)

        do {
            try await service.deleteItems(at: [musicDirectory])
            XCTFail("Expected managed media root deletion to be rejected")
        } catch let error as FileSystemServiceError {
            XCTAssertEqual(error, .libraryOwnedMedia)
        }

        do {
            try await service.deleteItems(at: [trackURL])
            XCTFail("Expected managed media descendant deletion to be rejected")
        } catch let error as FileSystemServiceError {
            XCTAssertEqual(error, .libraryOwnedMedia)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: trackURL.path))
    }

    func testSymlinkResolvingIntoManagedMediaCannotBeDeleted() async throws {
        let musicDirectory = rootDirectory.appendingPathComponent("Music", isDirectory: true)
        let trackURL = musicDirectory.appendingPathComponent("Track.bin")
        let aliasDirectory = rootDirectory.appendingPathComponent("Imported Alias", isDirectory: true)
        try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
        try Data("fixture".utf8).write(to: trackURL)
        try FileManager.default.createSymbolicLink(
            at: aliasDirectory,
            withDestinationURL: musicDirectory
        )

        let service = FileSystemService(rootDirectory: rootDirectory)
        let aliasedTrack = aliasDirectory.appendingPathComponent(trackURL.lastPathComponent)

        do {
            try await service.deleteItems(at: [aliasedTrack])
            XCTFail("Expected a symlink into managed media to be rejected")
        } catch let error as FileSystemServiceError {
            XCTAssertEqual(error, .libraryOwnedMedia)
        }

        XCTAssertTrue(FileManager.default.fileExists(atPath: trackURL.path))
    }

    func testUnrelatedDocumentsMutationRemainsAllowed() async throws {
        let documentURL = rootDirectory.appendingPathComponent("Notes.txt")
        try Data("notes".utf8).write(to: documentURL)
        let service = FileSystemService(rootDirectory: rootDirectory)

        try await service.deleteItems(at: [documentURL])

        XCTAssertFalse(FileManager.default.fileExists(atPath: documentURL.path))
    }

    func testManagedMediaDestinationsCannotBeMutated() async throws {
        let musicDirectory = rootDirectory.appendingPathComponent("Music", isDirectory: true)
        try FileManager.default.createDirectory(at: musicDirectory, withIntermediateDirectories: true)
        let sourceDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileSystemServiceSource-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: sourceDirectory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: sourceDirectory) }
        let sourceURL = sourceDirectory.appendingPathComponent("Source.bin")
        try Data("fixture".utf8).write(to: sourceURL)

        let service = FileSystemService(rootDirectory: rootDirectory)

        do {
            try await service.createDirectory(named: "Nested", in: musicDirectory)
            XCTFail("Expected managed media directory creation to be rejected")
        } catch let error as FileSystemServiceError {
            XCTAssertEqual(error, .libraryOwnedMedia)
        }

        do {
            try await service.copyItems(at: [sourceURL], to: musicDirectory)
            XCTFail("Expected managed media copy destination to be rejected")
        } catch let error as FileSystemServiceError {
            XCTAssertEqual(error, .libraryOwnedMedia)
        }
    }
}
