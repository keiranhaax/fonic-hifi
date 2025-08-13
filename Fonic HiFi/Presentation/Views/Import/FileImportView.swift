//
//  FileImportView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftUI
import UniformTypeIdentifiers

/// Main file import view with document picker and folder selection
struct FileImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var importService: LibraryImportService
    
    @State private var showingDocumentPicker = false
    @State private var showingFolderPicker = false
    @State private var selectedURLs: [URL] = []
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if selectedURLs.isEmpty {
                    EmptyImportView(
                        showingDocumentPicker: $showingDocumentPicker,
                        showingFolderPicker: $showingFolderPicker
                    )
                } else {
                    SelectedFilesView(
                        selectedURLs: $selectedURLs,
                        showingDocumentPicker: $showingDocumentPicker,
                        showingFolderPicker: $showingFolderPicker
                    )
                }
            }
            .navigationTitle("Import Music")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Import") {
                        Task {
                            await importService.importFiles(from: selectedURLs)
                            dismiss()
                        }
                    }
                    .disabled(selectedURLs.isEmpty || importService.isImporting)
                }
            }
            .fileImporter(
                isPresented: $showingDocumentPicker,
                allowedContentTypes: supportedAudioTypes,
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: supportedAudioTypes + [.folder],
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }
        }
    }
    
    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            selectedURLs.append(contentsOf: urls)
        case .failure(let error):
            print("File selection error: \(error.localizedDescription)")
        }
    }
    
    private var supportedAudioTypes: [UTType] {
        [
            .mp3,
            .wav,
            .aiff,
            .mpeg4Audio,
            .audio,
            UTType(filenameExtension: "m4a") ?? .data,
            UTType(filenameExtension: "flac") ?? .data,
            UTType(filenameExtension: "aac") ?? .data,
            UTType(filenameExtension: "ogg") ?? .data,
            UTType(filenameExtension: "opus") ?? .data,
            UTType(filenameExtension: "wv") ?? .data,
            UTType(filenameExtension: "ape") ?? .data,
            UTType(filenameExtension: "aif") ?? .data
        ]
    }
}

/// Empty state view when no files are selected
struct EmptyImportView: View {
    @Binding var showingDocumentPicker: Bool
    @Binding var showingFolderPicker: Bool
    
    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundColor(.secondary)
            
            VStack(spacing: 16) {
                Text("Import Your Music")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Select audio files or browse folders to import into your library")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            VStack(spacing: 12) {
                Button(action: { showingDocumentPicker = true }) {
                    Label("Select Audio Files", systemImage: "doc.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                
                Button(action: { showingFolderPicker = true }) {
                    Label("Browse & Select Files", systemImage: "folder.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

/// View showing selected files before import
struct SelectedFilesView: View {
    @Binding var selectedURLs: [URL]
    @Binding var showingDocumentPicker: Bool
    @Binding var showingFolderPicker: Bool
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("\(selectedURLs.count) items selected")
                    .font(.headline)
                
                HStack(spacing: 12) {
                    Button("Add More Files") {
                        showingDocumentPicker = true
                    }
                    .buttonStyle(.bordered)
                    
                    Button("Browse More") {
                        showingFolderPicker = true
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
            
            Divider()
            
            // File list
            List {
                ForEach(selectedURLs, id: \.self) { url in
                    HStack {
                        Image(systemName: fileIcon(for: url))
                            .foregroundColor(.accentColor)
                        
                        VStack(alignment: .leading, spacing: 2) {
                            Text(url.lastPathComponent)
                                .font(.body)
                                .lineLimit(1)
                            
                            Text(url.deletingLastPathComponent().path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .onDelete { indexSet in
                    selectedURLs.remove(atOffsets: indexSet)
                }
            }
            .listStyle(.plain)
        }
    }
    
    private func fileIcon(for url: URL) -> String {
        if url.hasDirectoryPath {
            return "folder.fill"
        } else {
            return "music.note"
        }
    }
}

#Preview {
    FileImportView()
        .environmentObject(DataManager.makePreviewImportService())
}
