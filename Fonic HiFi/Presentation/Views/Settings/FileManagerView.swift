//
//  FileManagerView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//

import SwiftUI

@MainActor
struct FileManagerView: View {
    @EnvironmentObject private var importService: LibraryImportService
    @Environment(\.editMode) private var editMode
    @Environment(\.locale) private var locale
    @State private var viewModel: FileManagerViewModel

    init(viewModel: FileManagerViewModel = .live()) {
        self.viewModel = viewModel
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(spacing: 0) {
            directoryHeader(sortOption: $viewModel.sortOption)

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)

                TextField("Search files...", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
            }
            .padding(.horizontal)

            if viewModel.isLoading {
                ProgressView("Loading...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(selection: $viewModel.selectedItems) {
                    ForEach(viewModel.filteredContents, id: \.id) { item in
                        let isLibraryManaged = viewModel.isLibraryManaged(item)
                        FileRowView(
                            item: item,
                            isEditing: editMode?.wrappedValue.isEditing == true,
                            onTap: {
                                Task {
                                    await viewModel.open(item)
                                }
                            },
                            onLongPress: {
                                viewModel.showDetails(for: item)
                            }
                        )
                        .tag(item)
                        .selectionDisabled(isLibraryManaged)
                        .overlay(alignment: .topTrailing) {
                            if isLibraryManaged {
                                Image(systemName: "lock.shield.fill")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .accessibilityHidden(true)
                            }
                        }
                        .accessibilityValue(
                            isLibraryManaged ? "Library-managed music" : ""
                        )
                        .accessibilityHint(
                            isLibraryManaged
                                ? "Managed by the music library and unavailable for file operations."
                                : ""
                        )
                    }
                }
                .refreshable {
                    await viewModel.loadDirectoryContents()
                }
            }

            if !viewModel.selectedItems.isEmpty {
                selectionToolbar
            }
        }
        .navigationTitle("File Manager")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                EditButton()
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                actionsMenu
            }
        }
        .task {
            await viewModel.loadDirectoryContents()
        }
        .fileImporter(
            isPresented: $viewModel.showingFileImporter,
            allowedContentTypes: AudioImportContentTypes.all,
            allowsMultipleSelection: true
        ) { result in
            Task {
                await viewModel.handlePickerResult(result)
            }
        }
        .alert("Delete Files", isPresented: $viewModel.showingDeleteConfirmation) {
            Button("Delete", role: .destructive) {
                Task {
                    await viewModel.deleteSelectedFiles()
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text(verbatim: LocalizedFormatters.deleteFilesConfirmation(
                viewModel.selectedItems.count,
                locale: locale
            ))
        }
        .alert("New Folder", isPresented: $viewModel.showingNewFolderPrompt) {
            TextField("Folder Name", text: $viewModel.newFolderName)
            Button("Create") {
                Task {
                    await viewModel.createFolder()
                }
            }
            Button("Cancel", role: .cancel) {
                viewModel.newFolderName = ""
            }
        } message: {
            Text("Enter a name for the new folder.")
        }
        .alert(item: $viewModel.pickerFailure) { failure in
            Alert(
                title: Text(failure.title),
                message: Text(failure.message),
                primaryButton: .default(Text("Try Again")) {
                    viewModel.showingFileImporter = true
                },
                secondaryButton: .cancel()
            )
        }
        .alert(item: $viewModel.failure) { failure in
            Alert(
                title: Text(operationFailureTitle(for: failure)),
                message: Text(verbatim: failure.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .sheet(item: $viewModel.selectedFileForDetails) { file in
            FileDetailsView(file: file)
        }
        .sheet(isPresented: $viewModel.showingImportProgress) {
            ImportProgressView()
                .importService(importService)
                .interactiveDismissDisabled(importService.isImporting)
        }
    }

    private func directoryHeader(sortOption: Binding<SortOption>) -> some View {
        HStack {
            Button("Back") {
                Task {
                    await viewModel.navigateToParent()
                }
            }
            .disabled(viewModel.isRootDirectory)

            Spacer()

            Text(viewModel.currentDirectory.lastPathComponent)
                .font(.headline)
                .lineLimit(1)

            Spacer()

            Menu {
                Picker("Sort by", selection: sortOption) {
                    ForEach(SortOption.allCases, id: \.self) { option in
                        Label {
                            Text(option.displayName)
                        } icon: {
                            Image(systemName: option.iconName)
                        }
                        .tag(option)
                    }
                }
            } label: {
                Image(systemName: "arrow.up.arrow.down")
            }
            .accessibilityLabel("Sort files")
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
    }

    private var selectionToolbar: some View {
        HStack {
            Button {
                viewModel.requestDeleteSelectedFiles()
            } label: {
                Label {
                    Text(verbatim: LocalizedFormatters.deleteFileCount(
                        viewModel.selectedItems.count,
                        locale: locale
                    ))
                } icon: {
                    Image(systemName: "trash")
                }
            }
            .foregroundStyle(.red)
            .accessibilityIdentifier("DeleteSelectedFilesButton")

            Spacer()

            Button("Import Selected") {
                let urls = viewModel.selectedAudioURLsForImport()
                guard !urls.isEmpty else { return }
                importService.importFiles(from: urls)
            }
            .disabled(
                viewModel.selectedItems.filter(\.isAudioFile).isEmpty
                    || importService.isImporting
            )
        }
        .padding()
        .background(Color(uiColor: .systemGray6))
    }

    private var actionsMenu: some View {
        Menu {
            Button {
                viewModel.showingFileImporter = true
            } label: {
                Label("Import Files", systemImage: "square.and.arrow.down")
            }

            Button {
                viewModel.showingNewFolderPrompt = true
            } label: {
                Label("New Folder", systemImage: "folder.badge.plus")
            }

            Button {
                Task {
                    await viewModel.loadDirectoryContents()
                }
            } label: {
                Label("Refresh", systemImage: "arrow.clockwise")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
        }
        .accessibilityLabel("File actions")
    }

    private func operationFailureTitle(
        for failure: FileManagerFailure
    ) -> LocalizedStringResource {
        failure.isCancellation ? "Operation Cancelled" : "File Operation Failed"
    }
}

#Preview {
    let previewDataManager = DataManager.makePreviewDataManager()
    let importService = DataManager.makePreviewImportService()

    if let previewDataManager, let importService {
        FileManagerView()
            .dataManager(previewDataManager)
            .importService(importService)
    } else {
        Text("Preview unavailable")
    }
}
