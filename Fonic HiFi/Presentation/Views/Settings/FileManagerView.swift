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
    
    @State private var currentDirectory: URL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
    @State private var directoryContents: [FileItem] = []
    @State private var selectedItems: Set<FileItem> = []
    @State private var isLoading = false
    @State private var showingDeleteConfirmation = false
    @State private var showingFileImporter = false
    @State private var searchText = ""
    @State private var sortOption: SortOption = .name
    @State private var showingDetails = false
    @State private var selectedFileForDetails: FileItem?
    
    private var filteredContents: [FileItem] {
        let filtered = searchText.isEmpty ? directoryContents : directoryContents.filter { 
            $0.name.localizedCaseInsensitiveContains(searchText) 
        }
        
        return filtered.sorted { first, second in
            switch sortOption {
            case .name:
                return first.name.localizedCaseInsensitiveCompare(second.name) == .orderedAscending
            case .date:
                return first.dateModified > second.dateModified
            case .size:
                return first.size > second.size
            case .type:
                return first.fileExtension.localizedCaseInsensitiveCompare(second.fileExtension) == .orderedAscending
            }
        }
    }
    
    var body: some View {
        NavigationStack {
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
                                onLongPress: { showFileDetails(item) }
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
                        .disabled(selectedItems.filter { $0.isAudioFile }.isEmpty)
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                }
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
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .alert("Delete Files", isPresented: $showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await deleteFilesConfirmed()
                }
            }
            Button("Cancel", role: .cancel) { }
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
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return currentDirectory.path == documentsURL.path
    }
    
    private func loadDirectoryContents() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(at: currentDirectory, includingPropertiesForKeys: [
                .contentModificationDateKey,
                .fileSizeKey,
                .isDirectoryKey
            ])
            
            var items: [FileItem] = []
            
            for url in contents {
                let resourceValues = try url.resourceValues(forKeys: [
                    .contentModificationDateKey,
                    .fileSizeKey,
                    .isDirectoryKey
                ])
                
                let item = FileItem(
                    id: url.absoluteString,
                    name: url.lastPathComponent,
                    url: url,
                    isDirectory: resourceValues.isDirectory ?? false,
                    size: Int64(resourceValues.fileSize ?? 0),
                    dateModified: resourceValues.contentModificationDate ?? Date()
                )
                
                items.append(item)
            }
            
            await MainActor.run {
                self.directoryContents = items
            }
            
        } catch {
            print("Error loading directory contents: \(error)")
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
                print("Error deleting file \(item.name): \(error)")
            }
        }
        
        selectedItems.removeAll()
        await loadDirectoryContents()
    }
    
    private func importSelectedFiles() {
        let audioFiles = selectedItems.filter { $0.isAudioFile }
        let urls = audioFiles.map { $0.url }
        
        Task {
            guard let importService = importService else { return }
            await importService.importFiles(from: urls)
        }
        
        selectedItems.removeAll()
    }
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            // Copy files to documents directory
            Task {
                await copyFilesToDocuments(urls)
                await loadDirectoryContents()
            }
        case .failure(let error):
            print("File import error: \(error)")
        }
    }
    
    private func copyFilesToDocuments(_ urls: [URL]) async {
        for url in urls {
            await copyItemToCurrentDirectory(url)
        }
    }
    
    private func copyItemToCurrentDirectory(_ url: URL) async {
        let targetDirectory = currentDirectory
        await Task.detached(priority: .utility) {
            let fileManager = FileManager.default
            let destinationURL = uniqueDestinationURL(for: url, in: targetDirectory, fileManager: fileManager)
            guard url.standardizedFileURL != destinationURL.standardizedFileURL else {
                return
            }
            let didAccess = url.startAccessingSecurityScopedResource()
            defer {
                if didAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            do {
                if fileManager.fileExists(atPath: destinationURL.path) {
                    print("Destination already exists at \(destinationURL.lastPathComponent), skipping copy")
                    return
                }
                try fileManager.copyItem(at: url, to: destinationURL)
            } catch {
                print("Error copying file \(url.lastPathComponent): \(error)")
            }
        }.value
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
                print("Error creating folder: \(error)")
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
            return "folder.fill"
        } else if isAudioFile {
            return "music.note"
        } else {
            return "doc.fill"
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
        case .name: return "Name"
        case .date: return "Date Modified"
        case .size: return "Size"
        case .type: return "Type"
        }
    }
    
    var iconName: String {
        switch self {
        case .name: return "textformat"
        case .date: return "calendar"
        case .size: return "arrow.up.arrow.down"
        case .type: return "doc"
        }
    }
}

#Preview {
    FileManagerView()
        .dataManager(DataManager.makePreviewDataManager())
        .importService(DataManager.makePreviewImportService())
}
