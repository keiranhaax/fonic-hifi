//
//  FileSystemService.swift
//  Fonic HiFi
//

import Foundation
import OSLog

protocol FileSystemServicing: Sendable {
    func listDirectory(at directory: URL) async throws -> [FileItem]
    func createDirectory(named name: String, in directory: URL) async throws
    func copyItems(at sourceURLs: [URL], to directory: URL) async throws
    func deleteItems(at urls: [URL]) async throws
}

enum FileSystemServiceError: LocalizedError, Equatable, Sendable {
    case outsideRoot
    case libraryOwnedMedia
    case invalidFolderName
    case listFailed
    case createDirectoryFailed
    case copyFailed
    case deleteFailed

    var errorDescription: String? {
        switch self {
        case .outsideRoot:
            "The requested location is outside the File Manager root."
        case .libraryOwnedMedia:
            "Music is managed by the library and cannot be changed here."
        case .invalidFolderName:
            "Enter a folder name without path separators."
        case .listFailed:
            "The folder contents could not be loaded."
        case .createDirectoryFailed:
            "The folder could not be created."
        case .copyFailed:
            "One or more files could not be copied."
        case .deleteFailed:
            "One or more items could not be deleted."
        }
    }
}

struct FileItem: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let url: URL
    let isDirectory: Bool
    let size: Int64
    let dateModified: Date

    var fileExtension: String {
        url.pathExtension.lowercased()
    }

    var isAudioFile: Bool {
        AudioFormat.isSupportedFileExtension(fileExtension)
    }

    var fileTypeIcon: String {
        if isDirectory {
            "folder.fill"
        } else if isAudioFile {
            "music.note"
        } else {
            "doc.fill"
        }
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: size, countStyle: .file)
    }
}

actor FileSystemService: FileSystemServicing {
    static let defaultDirectory: URL = {
        if let documentsURL = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
        ).first {
            return documentsURL
        }

        let fallback = FileManager.default.temporaryDirectory
        Log.logger(.data).error(
            "Documents directory unavailable; using temporary directory fallback"
        )
        return fallback
    }()

    private static let defaultCopyBufferSize = 1_048_576

    /// The import pipeline stores managed media in the Documents/Music subtree.
    /// Keep this derivation in one place so file-manager protection and import
    /// recovery agree about which files are library-owned.
    nonisolated static func managedMediaRoot(for rootDirectory: URL) -> URL {
        rootDirectory.standardizedFileURL
            .appendingPathComponent("Music", isDirectory: true)
            .standardizedFileURL
    }

    nonisolated static func isLibraryManaged(_ url: URL, under rootDirectory: URL) -> Bool {
        let managedRoot = managedMediaRoot(for: rootDirectory)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let candidate = url.standardizedFileURL
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return isSameOrDescendant(candidate, of: managedRoot)
    }

    private let rootDirectory: URL
    private let fileManager: FileManager
    private let copyBufferSize: Int

    init(
        rootDirectory: URL = FileSystemService.defaultDirectory,
        fileManager: FileManager = .default,
        copyBufferSize: Int = FileSystemService.defaultCopyBufferSize
    ) {
        self.rootDirectory = rootDirectory.standardizedFileURL
        self.fileManager = fileManager
        self.copyBufferSize = max(1, copyBufferSize)
    }

    func listDirectory(at directory: URL) async throws -> [FileItem] {
        let directory = try validatedURL(directory)
        try Task.checkCancellation()

        do {
            let resourceKeys: Set<URLResourceKey> = [
                .contentModificationDateKey,
                .fileSizeKey,
                .isDirectoryKey,
            ]
            let contents = try fileManager.contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: Array(resourceKeys)
            )

            return try contents.map { url in
                try Task.checkCancellation()
                let values = try url.resourceValues(forKeys: resourceKeys)
                return FileItem(
                    id: url.standardizedFileURL.absoluteString,
                    name: url.lastPathComponent,
                    url: url,
                    isDirectory: values.isDirectory ?? false,
                    size: Int64(values.fileSize ?? 0),
                    dateModified: values.contentModificationDate ?? .distantPast
                )
            }
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as FileSystemServiceError {
            throw error
        } catch {
            throw FileSystemServiceError.listFailed
        }
    }

    func createDirectory(named name: String, in directory: URL) async throws {
        let directory = try validatedURL(directory)
        try validateMutationDestination(directory)
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty,
              name != ".",
              name != "..",
              !name.contains("/"),
              !name.contains("\0")
        else {
            throw FileSystemServiceError.invalidFolderName
        }

        let destination = try validatedURL(directory.appendingPathComponent(name))
        try validateMutationDestination(destination)
        try Task.checkCancellation()

        do {
            try fileManager.createDirectory(
                at: destination,
                withIntermediateDirectories: false
            )
        } catch {
            throw FileSystemServiceError.createDirectoryFailed
        }
    }

    func copyItems(at sourceURLs: [URL], to directory: URL) async throws {
        let directory = try validatedURL(directory)
        try validateMutationDestination(directory)

        for sourceURL in sourceURLs {
            try Task.checkCancellation()
            try copyItem(at: sourceURL, to: directory)
        }
    }

    func deleteItems(at urls: [URL]) async throws {
        for url in urls {
            try Task.checkCancellation()
            let target = try validatedURL(url)
            guard target.standardizedFileURL != rootDirectory.standardizedFileURL,
                  target.resolvingSymlinksInPath().standardizedFileURL != resolvedRootDirectory
            else {
                throw FileSystemServiceError.outsideRoot
            }
            try validateMutationDestination(target)

            do {
                try fileManager.removeItem(at: target)
            } catch {
                throw FileSystemServiceError.deleteFailed
            }
        }
    }

    private var resolvedRootDirectory: URL {
        rootDirectory.resolvingSymlinksInPath().standardizedFileURL
    }

    private func validateMutationDestination(_ url: URL) throws {
        guard !Self.isLibraryManaged(url, under: rootDirectory) else {
            throw FileSystemServiceError.libraryOwnedMedia
        }
    }

    private func validatedURL(_ url: URL) throws -> URL {
        let candidate = url.standardizedFileURL
        let rootComponents = rootDirectory.pathComponents
        let candidateComponents = candidate.pathComponents
        guard candidateComponents.starts(with: rootComponents) else {
            throw FileSystemServiceError.outsideRoot
        }

        let resolvedRoot = rootDirectory.resolvingSymlinksInPath().standardizedFileURL
        var existingCandidate = rootDirectory
        for component in candidateComponents.dropFirst(rootComponents.count) {
            existingCandidate.appendPathComponent(component)
            guard fileManager.fileExists(atPath: existingCandidate.path) else {
                break
            }

            let resolvedCandidate = existingCandidate
                .resolvingSymlinksInPath()
                .standardizedFileURL
            guard resolvedCandidate.pathComponents.starts(
                with: resolvedRoot.pathComponents
            ) else {
                throw FileSystemServiceError.outsideRoot
            }
        }

        return candidate
    }

    private func copyItem(at sourceURL: URL, to directory: URL) throws {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let source = sourceURL.standardizedFileURL
        let destination = try uniqueDestinationURL(for: source, in: directory)
        guard source != destination else { return }

        do {
            let values = try source.resourceValues(forKeys: [.isDirectoryKey])
            guard values.isDirectory != true else {
                throw FileSystemServiceError.copyFailed
            }
            try copyFileContents(from: source, to: destination)
        } catch is CancellationError {
            try? fileManager.removeItem(at: destination)
            throw CancellationError()
        } catch let error as FileSystemServiceError {
            try? fileManager.removeItem(at: destination)
            throw error
        } catch {
            try? fileManager.removeItem(at: destination)
            throw FileSystemServiceError.copyFailed
        }
    }

    private func copyFileContents(from source: URL, to destination: URL) throws {
        guard fileManager.createFile(atPath: destination.path, contents: nil) else {
            throw FileSystemServiceError.copyFailed
        }

        let sourceHandle = try FileHandle(forReadingFrom: source)
        let destinationHandle = try FileHandle(forWritingTo: destination)
        defer {
            try? sourceHandle.close()
            try? destinationHandle.close()
        }

        while true {
            try Task.checkCancellation()
            guard let data = try sourceHandle.read(upToCount: copyBufferSize),
                  !data.isEmpty
            else {
                break
            }
            try destinationHandle.write(contentsOf: data)
        }
        try Task.checkCancellation()
    }

    private func uniqueDestinationURL(for source: URL, in directory: URL) throws -> URL {
        var destination = try validatedURL(
            directory.appendingPathComponent(source.lastPathComponent)
        )
        try validateMutationDestination(destination)
        guard fileManager.fileExists(atPath: destination.path) else {
            return destination
        }

        let baseName = destination.deletingPathExtension().lastPathComponent
        let fileExtension = destination.pathExtension
        var attempt = 1

        repeat {
            try Task.checkCancellation()
            let name = baseName + " copy \(attempt)"
            let candidate = fileExtension.isEmpty
                ? directory.appendingPathComponent(name)
                : directory.appendingPathComponent(name).appendingPathExtension(fileExtension)
            destination = try validatedURL(candidate)
            try validateMutationDestination(destination)
            attempt += 1
        } while fileManager.fileExists(atPath: destination.path)

        return destination
    }

    private static func isSameOrDescendant(_ candidate: URL, of root: URL) -> Bool {
        let rootComponents = root.pathComponents
        let candidateComponents = candidate.pathComponents
        return candidateComponents.starts(with: rootComponents)
    }
}
