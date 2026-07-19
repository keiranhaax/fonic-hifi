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
    @Environment(\.importService) private var importService

    @State private var showingFilePicker = false
    @State private var selectedURLs: [URL] = []

    private let logger = Log.logger(.importService)

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                if selectedURLs.isEmpty {
                    EmptyImportView(showingFilePicker: $showingFilePicker)
                } else {
                    SelectedFilesView(
                        selectedURLs: $selectedURLs,
                        showingFilePicker: $showingFilePicker
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
                        guard let importService else { return }
                        Task {
                            importService.importFiles(from: selectedURLs)
                            dismiss()
                        }
                    }
                    .disabled(selectedURLs.isEmpty || importService?.isImporting == true)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: supportedAudioTypes + [.folder],
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch result {
        case let .success(urls):
            selectedURLs.append(contentsOf: urls)
        case let .failure(error):
            logger.error("File selection failed: \(error.localizedDescription, privacy: .private)")
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
            UTType(filenameExtension: "aif") ?? .data,
        ]
    }
}

/// Empty state view when no files are selected
struct EmptyImportView: View {
    @Binding var showingFilePicker: Bool

    var body: some View {
        VStack(spacing: 40) {
            Image(systemName: "music.note.list")
                .font(.system(size: 80))
                .foregroundColor(.secondary)

            VStack(spacing: 16) {
                Text("Import Your Music")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Select audio files or folders to import into your library")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            Button(action: { showingFilePicker = true }) {
                Label("Add Files & Folders", systemImage: "folder.badge.plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .padding(.horizontal, 40)
        }
        .padding()
    }
}

/// View showing selected files before import
struct SelectedFilesView: View {
    @Binding var selectedURLs: [URL]
    @Binding var showingFilePicker: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("\(selectedURLs.count) items selected")
                    .font(.headline)

                Button("Add More") {
                    showingFilePicker = true
                }
                .buttonStyle(.bordered)
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
            "folder.fill"
        } else {
            "music.note"
        }
    }
}

#Preview {
    if let importService = DataManager.makePreviewImportService() {
        FileImportView()
            .importService(importService)
    } else {
        FileImportView()
    }
}
