//
//  FileImportView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import OSLog
import SwiftUI

/// Main file import view with document picker and folder selection
struct FileImportView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var importService: LibraryImportService

    @State private var showingFilePicker = false
    @State private var selectedURLs: [URL] = []
    @State private var pickerFailure: ImportPickerFailure?

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
                        importService.importFiles(from: selectedURLs)
                    }
                    .disabled(selectedURLs.isEmpty || importService.isImporting)
                }
            }
            .fileImporter(
                isPresented: $showingFilePicker,
                allowedContentTypes: AudioImportContentTypes.all + [.folder],
                allowsMultipleSelection: true
            ) { result in
                handleFileSelection(result)
            }
            .alert(item: $pickerFailure) { failure in
                Alert(
                    title: Text(failure.title),
                    message: Text(failure.message),
                    primaryButton: .default(Text("Try Again")) {
                        showingFilePicker = true
                    },
                    secondaryButton: .cancel()
                )
            }
        }
    }

    private func handleFileSelection(_ result: Result<[URL], Error>) {
        switch ImportPickerSelection.resolve(result, surface: .fileSelection) {
        case let .selected(urls):
            selectedURLs.append(contentsOf: urls)
        case let .failed(failure):
            if case let .failure(error) = result {
                logger.error("File selection failed: \(error.localizedDescription, privacy: .private)")
            }
            pickerFailure = failure
        }
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
        Text("Preview unavailable")
    }
}
