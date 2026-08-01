//
//  FileManagerViewModel.swift
//  Fonic HiFi
//

import Foundation
import Observation
import OSLog

enum SortOption: CaseIterable, Sendable {
    case name, date, size, type

    var displayName: LocalizedStringResource {
        switch self {
        case .name: "Name"
        case .date: "Date Modified"
        case .size: "Size"
        case .type: "Type"
        }
    }

    var iconName: String {
        switch self {
        case .name: "textformat"
        case .date: "calendar"
        case .size: "arrow.up.arrow.down"
        case .type: "doc"
        }
    }
}

struct FileManagerFailure: Identifiable, Equatable {
    enum Operation: Equatable {
        case load
        case createFolder
        case copy
        case delete
    }

    let id = UUID()
    let operation: Operation
    let message: String
    let isCancellation: Bool

    static func == (lhs: FileManagerFailure, rhs: FileManagerFailure) -> Bool {
        lhs.operation == rhs.operation
            && lhs.message == rhs.message
            && lhs.isCancellation == rhs.isCancellation
    }
}

@MainActor
@Observable
final class FileManagerViewModel {
    private(set) var currentDirectory: URL
    private(set) var directoryContents: [FileItem] = []
    var selectedItems: Set<FileItem> = []
    private(set) var isLoading = false
    var showingDeleteConfirmation = false
    var showingFileImporter = false
    var showingImportProgress = false
    var pickerFailure: ImportPickerFailure?
    var searchText = ""
    var sortOption: SortOption = .name
    var selectedFileForDetails: FileItem?
    var showingNewFolderPrompt = false
    var newFolderName = ""
    var failure: FileManagerFailure?

    @ObservationIgnored private let rootDirectory: URL
    @ObservationIgnored private let service: any FileSystemServicing
    @ObservationIgnored private let logger = Log.logger(.presentation)
    @ObservationIgnored private var loadGeneration: UInt = 0

    init(
        rootDirectory: URL,
        service: any FileSystemServicing
    ) {
        let root = rootDirectory.standardizedFileURL
        self.rootDirectory = root
        currentDirectory = root
        self.service = service
    }

    static func live() -> FileManagerViewModel {
        let root = FileSystemService.defaultDirectory
        return FileManagerViewModel(
            rootDirectory: root,
            service: FileSystemService(rootDirectory: root)
        )
    }

    var filteredContents: [FileItem] {
        let filtered = searchText.isEmpty
            ? directoryContents
            : directoryContents.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }

        return filtered.sorted { first, second in
            switch sortOption {
            case .name:
                first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            case .date:
                first.dateModified > second.dateModified
            case .size:
                first.size > second.size
            case .type:
                first.fileExtension.localizedCaseInsensitiveCompare(second.fileExtension)
                    == .orderedAscending
            }
        }
    }

    var isRootDirectory: Bool {
        currentDirectory.standardizedFileURL == rootDirectory.standardizedFileURL
    }

    func loadDirectoryContents() async {
        await loadDirectoryContents(at: currentDirectory)
    }

    private func loadDirectoryContents(at directory: URL) async {
        loadGeneration &+= 1
        let generation = loadGeneration
        isLoading = true
        defer {
            if generation == loadGeneration {
                isLoading = false
            }
        }

        do {
            let items = try await service.listDirectory(at: directory)
            try Task.checkCancellation()
            guard generation == loadGeneration else { return }
            currentDirectory = directory
            directoryContents = items
            selectedItems = selectedItems.intersection(Set(items))
        } catch {
            guard generation == loadGeneration else { return }
            present(error, operation: .load)
        }
    }

    func navigateToParent() async {
        guard !isRootDirectory else { return }
        let parentDirectory = currentDirectory.deletingLastPathComponent()
        await loadDirectoryContents(at: parentDirectory)
    }

    func open(_ item: FileItem) async {
        guard item.isDirectory else {
            selectedFileForDetails = item
            return
        }
        await loadDirectoryContents(at: item.url)
    }

    func showDetails(for item: FileItem) {
        selectedFileForDetails = item
    }

    func requestDeleteSelectedFiles() {
        guard !selectedItems.isEmpty else { return }
        showingDeleteConfirmation = true
    }

    func deleteSelectedFiles() async {
        let urls = selectedItems.map(\.url)
        guard !urls.isEmpty else { return }

        do {
            try await service.deleteItems(at: urls)
            selectedItems.removeAll()
            await reloadAfterMutation()
        } catch {
            present(error, operation: .delete)
        }
    }

    func copyImportedFiles(_ urls: [URL]) async {
        guard !urls.isEmpty else { return }

        do {
            try await service.copyItems(at: urls, to: currentDirectory)
            await reloadAfterMutation()
        } catch {
            present(error, operation: .copy)
        }
    }

    func createFolder() async {
        let name = newFolderName
        do {
            try await service.createDirectory(named: name, in: currentDirectory)
            newFolderName = ""
            await reloadAfterMutation()
        } catch {
            present(error, operation: .createFolder)
        }
    }

    func selectedAudioURLsForImport() -> [URL] {
        let urls = selectedItems
            .filter(\.isAudioFile)
            .map(\.url)
        guard !urls.isEmpty else { return [] }

        showingImportProgress = true
        selectedItems.removeAll()
        return urls
    }

    func handlePickerResult(_ result: Result<[URL], Error>) async {
        switch ImportPickerSelection.resolve(result, surface: .fileManager) {
        case let .selected(urls):
            await copyImportedFiles(urls)
        case let .failed(pickerFailure):
            if case let .failure(error) = result {
                logger.error("File import failed: \(error.localizedDescription, privacy: .private)")
            }
            self.pickerFailure = pickerFailure
        }
    }

    private func present(_ error: Error, operation: FileManagerFailure.Operation) {
        if error is CancellationError {
            failure = FileManagerFailure(
                operation: operation,
                message: String(localized: "The file operation was cancelled."),
                isCancellation: true
            )
            return
        }

        let message = (error as? LocalizedError)?.errorDescription
            ?? String(localized: "The file operation could not be completed.")
        failure = FileManagerFailure(
            operation: operation,
            message: message,
            isCancellation: false
        )
        logger.error(
            "File Manager operation failed: \(message, privacy: .private)"
        )
    }

    private func reloadAfterMutation() async {
        let reloadTask = Task { @MainActor [weak self] in
            await self?.loadDirectoryContents()
        }
        await reloadTask.value
    }
}
