//
//  FileManagerView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//

import SwiftUI
import UniformTypeIdentifiers

struct FileManagerView: View {
    @Environment(\.dataManager) private var dataManager
    @Environment(\.importService) private var importService

    private static let defaultDirectory: URL = {
        if let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            return documentsURL
        }

        let fallback = FileManager.default.temporaryDirectory
        Log.logger(.presentation).error("Documents directory unavailable; using temporary directory fallback at \(fallback.path, privacy: .public)")
        return fallback
    }()

    @State private var currentDirectory: URL = FileManagerView.defaultDirectory
    @State private var directoryContents: [FileItem] = []
    @State private var selectedItems: Set<FileItem> = []
    @State private var isLoading = false
    @State private var showingDeleteConfirmation = false
    @State private var showingFileImporter = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .name
    @State private var showingDetails = false
    @State private var selectedFileForDetails: FileItem?

    private let logger = Log.logger(.presentation)
    private let documentsDirectoryURL = FileManagerView.defaultDirectory

    private var filteredContents: [FileItem] {
        let filtered = searchText.isEmpty ? directoryContents : directoryContents.filter {
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
                first.fileExtension.localizedCaseInsensitiveCompare(second.fileExtension) == .orderedAscending
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Navigation bar
            HStack {
                Button("Back") {
                    navigateToParent()
                }
                .disabled(isRootDirectory)

                Spacer()

                Text(currentDirectory.lastPathComponent)
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Menu {
                    Picker("Sort by", selection: $sortOption) {
                        ForEach(SortOption.allCases, id: \.self) { option in
                            Label(option.displayName, systemImage: option.iconName)
                                .tag(option)
                        }
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                }
            }
            .padding()
            .background(Color(UIColor.systemGray6))

            // Search bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)

                TextField("Search files...", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
            }
            .padding(.horizontal)

            if isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                // File list
                List(selection: $selectedItems) {
                    ForEach(filteredContents, id: \.id) { item in
                        FileRowView(
                            item: item,
                            onTap: { handleItemTap(item) },
                            onLongPress: { showFileDetails(item) },
                        )
                    }
                }
                .refreshable {
                    await loadDirectoryContents()
                }
            }

            // Bottom toolbar
            if !selectedItems.isEmpty {
                HStack {
                    Button(action: deleteSelectedFiles) {
                        HStack {
                            Image(systemName: "trash")
                            Text("Delete (\(selectedItems.count))")
                        }
                    }
                    .foregroundColor(.red)
                    .disabled(selectedItems.isEmpty)

                    Spacer()

                    Button("Import Selected") {
                        importSelectedFiles()
                    }
                    .disabled(selectedItems.filter(\.isAudioFile).isEmpty)
                }
                .padding()
                .background(Color(UIColor.systemGray6))
            }
        }
        .navigationTitle("File Manager")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button(action: { showingFileImporter = true }) {
                        Label("Import Files", systemImage: "square.and.arrow.down")
                    }

                    Button(action: createNewFolder) {
                        Label("New Folder", systemImage: "folder.badge.plus")
                    }

                    Button(action: refreshDirectory) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .task {
            await loadDirectoryContents()
        }
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.audio, .mp3, .wav, .aiff],
            allowsMultipleSelection: true,
        ) { result in
            handleFileImport(result)
        }
        .alert("Delete Files", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteFilesConfirmed()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete \(selectedItems.count) file(s)? This action cannot be undone.")
        }
        .sheet(isPresented: $showingDetails) {
            if let file = selectedFileForDetails {
                FileDetailsView(file: file)
            }
        }
    }

    // MARK: - Private Methods

    private var isRootDirectory: Bool {
        currentDirectory.standardizedFileURL == documentsDirectoryURL.standardizedFileURL
    }

    private func loadDirectoryContents() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .isDirectoryKey,
            ])

            var items: [FileItem] = []

            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isDirectoryKey,
                ])

                let item = FileItem(
                    id: url.absoluteString,
                    name: url.lastPathComponent,
                    url: url,
                    isDirectory: resourceValues.isDirectory ?? false,
                    size: Int64(resourceValues.fileSize ?? 0),
                    dateModified: resourceValues.contentModificationDate ?? Date(),
                )

                items.append(item)
            }

            await MainActor.run {
                directoryContents = items
            }

        } catch {
            logger.error("Failed to load directory contents for \(currentDirectory.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    private func navigateToParent() {
        currentDirectory = currentDirectory.deletingLastPathComponent()
        Task {
            await loadDirectoryContents()
        }
    }

    private func handleItemTap(_ item: FileItem) {
        if item.isDirectory {
            currentDirectory = item.url
            Task {
                await loadDirectoryContents()
            }
        } else {
            // Handle file tap (preview, play, etc.)
            showFileDetails(item)
        }
    }

    private func showFileDetails(_ item: FileItem) {
        selectedFileForDetails = item
        showingDetails = true
    }

    private func deleteSelectedFiles() {
        guard !selectedItems.isEmpty else { return }
        showingDeleteConfirmation = true
    }

    private func deleteFilesConfirmed() async {
        for item in selectedItems {
            do {
                try FileManager.default.removeItem(at: item.url)
            } catch {
                logger.error("Failed to delete file \(item.name, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        }

        selectedItems.removeAll()
        await loadDirectoryContents()
    }

    private func importSelectedFiles() {
        let audioFiles = selectedItems.filter(\.isAudioFile)
        let urls = audioFiles.map(\.url)

        Task {
            guard let importService else { return }
            importService.importFiles(from: urls)
        }

        selectedItems.removeAll()
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            // Copy files to documents directory
            Task {
                await copyFilesToDocuments(urls)
                await loadDirectoryContents()
            }
        case let .failure(error):
            logger.error("File import failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    private func copyFilesToDocuments(_ urls: [URL]) async {
        for url in urls {
            await copyItemToCurrentDirectory(url)
        }
    }

    private func copyItemToCurrentDirectory(_ url: URL) async {
        let targetDirectory = currentDirectory
        let fileManager = FileManager.default
        let destinationURL = uniqueDestinationURL(for: url, in: targetDirectory, fileManager: fileManager)

        // Copy values to avoid capturing MainActor context
        let sourceURL = url
        let targetURL = destinationURL

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            Task.detached(priority: .utility) {
                defer { continuation.resume() }

                guard sourceURL.standardizedFileURL != targetURL.standardizedFileURL else {
                    return
                }
                let didAccess = sourceURL.startAccessingSecurityScopedResource()
                defer {
                    if didAccess {
                        sourceURL.stopAccessingSecurityScopedResource()
                    }
                }
                do {
                    let fm = FileManager.default
                    if fm.fileExists(atPath: targetURL.path) {
                        logger.info("Destination exists at \(targetURL.lastPathComponent, privacy: .public); skipping copy")
                        return
                    }
                    try fm.copyItem(at: sourceURL, to: targetURL)
                } catch {
                    logger.error("Failed to copy file \(sourceURL.lastPathComponent, privacy: .public): \(error.localizedDescription, privacy: .public)")
                }
            }
        }
    }

    private func uniqueDestinationURL(for sourceURL: URL, in directory: URL, fileManager: FileManager) -> URL {
        var destination = directory.appendingPathComponent(sourceURL.lastPathComponent)
        guard fileManager.fileExists(atPath: destination.path) else {
            return destination
        }
        let baseName = destination.deletingPathExtension().lastPathComponent
        let fileExtension = destination.pathExtension
        var attempt = 1
        repeat {
            let suffix = " copy \(attempt)"
            let newName = baseName + suffix
            if fileExtension.isEmpty {
                destination = directory.appendingPathComponent(newName)
            } else {
                destination = directory.appendingPathComponent(newName).appendingPathExtension(fileExtension)
            }
            attempt += 1
        } while fileManager.fileExists(atPath: destination.path)
        return destination
    }

    private func createNewFolder() {
        let alert = UIAlertController(title: "New Folder", message: "Enter folder name", preferredStyle: .alert)

        alert.addTextField { textField in
            textField.placeholder = "Folder Name"
        }

        alert.addAction(UIAlertAction(title: "Create", style: .default) { _ in
            guard let folderName = alert.textFields?.first?.text, !folderName.isEmpty else {
                return
            }

            let folderURL = currentDirectory.appendingPathComponent(folderName)

            do {
                try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: false)
                Task {
                    await loadDirectoryContents()
                }
            } catch {
                logger.error("Failed to create folder \(folderName, privacy: .public): \(error.localizedDescription, privacy: .public)")
            }
        })

        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(alert, animated: true)
        }
    }

    private func refreshDirectory() {
        Task {
            await loadDirectoryContents()
        }
    }
}

// MARK: - Supporting Types

struct FileItem: Identifiable, Hashable {
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
        let audioExtensions = ["mp3", "wav", "aiff", "m4a", "flac", "ogg", "wma"]
        return audioExtensions.contains(fileExtension)
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

enum SortOption: CaseIterable {
    case name, date, size, type

    var displayName: String {
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

#Preview {
    if let previewDataManager = DataManager.makePreviewDataManager(),
       let importService = DataManager.makePreviewImportService() {
        FileManagerView()
            .dataManager(previewDataManager)
            .importService(importService)
    } else {
        Text("Preview unavailable")
    }
}
