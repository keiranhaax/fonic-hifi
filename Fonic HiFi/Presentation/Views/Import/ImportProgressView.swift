//
//  ImportProgressView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftUI

/// View showing import progress with cancel option
struct ImportProgressView: View {
    @Environment(\.importService) private var importService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Progress indicator
                ProgressSection(
                    progress: importService?.importProgress ?? 0.0,
                    filesProcessed: importService?.filesProcessed ?? 0,
                    totalFiles: importService?.totalFiles ?? 0,
                )

                // Status message
                Text(importService?.statusMessage ?? "No import service available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                // Error summary if any
                if !(importService?.importErrors.isEmpty ?? true) {
                    ErrorSummaryView(errors: importService?.importErrors ?? [])
                }

                Spacer()

                // Action buttons
                HStack(spacing: 16) {
                    if importService?.isImporting == true {
                        Button("Cancel Import") {
                            importService?.cancelImport()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    } else {
                        Button("Done") {
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                    }
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
            .navigationTitle("Importing Music")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if importService?.isImporting != true {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}

/// Progress visualization section
struct ProgressSection: View {
    let progress: Double
    let filesProcessed: Int
    let totalFiles: Int

    var body: some View {
        VStack(spacing: 20) {
            // Circular progress
            ZStack {
                Circle()
                    .stroke(Color.secondary.opacity(0.2), lineWidth: 8)
                    .frame(width: 120, height: 120)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut, value: progress)

                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.title)
                        .fontWeight(.semibold)

                    Text("\(filesProcessed)/\(totalFiles)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Linear progress bar
            ProgressView(value: progress)
                .progressViewStyle(.linear)
                .frame(maxWidth: 250)
        }
    }
}

/// Error summary view
struct ErrorSummaryView: View {
    let errors: [ImportError]
    @State private var showingErrorDetails = false

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                Text("\(errors.count) files failed to import")
                    .font(.subheadline)
                    .foregroundColor(.orange)
            }

            Button("View Details") {
                showingErrorDetails = true
            }
            .font(.caption)
            .sheet(isPresented: $showingErrorDetails) {
                ImportErrorDetailsView(errors: errors)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal)
    }
}

/// Detailed error view
struct ImportErrorDetailsView: View {
    let errors: [ImportError]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(errors) { error in
                VStack(alignment: .leading, spacing: 8) {
                    if let url = error.url {
                        Text(url.lastPathComponent)
                            .font(.headline)
                    }

                    Text(error.message)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(error.error.localizedDescription)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                .padding(.vertical, 4)
            }
            .navigationTitle("Import Errors")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    let importService = DataManager.makePreviewImportService()
    if importService != nil {
        ImportProgressView()
            .importService(importService)
    } else {
        ImportProgressView()
    }
}
