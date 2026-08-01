//
//  ImportPresentationState.swift
//  Fonic HiFi
//
//  Deterministic presentation state for file-picker and import surfaces.
//

import Foundation

enum ImportPickerSurface: Equatable, Sendable {
    case fileSelection
    case fileManager

    var failureTitle: String {
        switch self {
        case .fileSelection:
            String(localized: "Unable to Select Files")
        case .fileManager:
            String(localized: "Unable to Import Files")
        }
    }

    var failureMessage: String {
        switch self {
        case .fileSelection:
            String(localized: "The file picker could not complete your selection. Try again.")
        case .fileManager:
            String(localized: "The file picker could not complete the import request. Try again.")
        }
    }
}

struct ImportPickerFailure: Identifiable, Equatable, Sendable {
    let surface: ImportPickerSurface

    var id: ImportPickerSurface {
        surface
    }

    var title: String {
        surface.failureTitle
    }

    var message: String {
        surface.failureMessage
    }
}

enum ImportPickerSelection: Equatable {
    case selected([URL])
    case failed(ImportPickerFailure)

    static func resolve(
        _ result: Result<[URL], Error>,
        surface: ImportPickerSurface
    ) -> Self {
        switch result {
        case let .success(urls):
            .selected(urls)
        case .failure:
            .failed(ImportPickerFailure(surface: surface))
        }
    }
}

struct ImportProgressPresentationState: Equatable {
    let progress: Double
    let filesProcessed: Int
    let totalFiles: Int
    let statusMessage: String
    let isImporting: Bool
    let errors: [ImportError]

    @MainActor
    init(importService: LibraryImportService) {
        self.init(
            progress: importService.importProgress,
            filesProcessed: importService.filesProcessed,
            totalFiles: importService.totalFiles,
            statusMessage: importService.statusMessage,
            isImporting: importService.isImporting,
            errors: importService.importErrors
        )
    }

    init(
        progress: Double,
        filesProcessed: Int,
        totalFiles: Int,
        statusMessage: String,
        isImporting: Bool,
        errors: [ImportError]
    ) {
        self.progress = progress
        self.filesProcessed = filesProcessed
        self.totalFiles = totalFiles
        self.statusMessage = statusMessage
        self.isImporting = isImporting
        self.errors = errors
    }

    var failedFileCount: Int {
        errors.count
    }
}

enum ImportSheetDestination: String, Identifiable {
    case selection
    case progress

    var id: Self {
        self
    }
}

enum ImportSheetPresentation {
    static func resolve(
        current: ImportSheetDestination?,
        isImporting: Bool
    ) -> ImportSheetDestination? {
        isImporting ? .progress : current
    }
}
