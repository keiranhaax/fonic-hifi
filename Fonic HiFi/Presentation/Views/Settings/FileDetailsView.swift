//
//  FileDetailsView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//

import SwiftUI
import AVFoundation

struct FileDetailsView: View {
    let file: FileItem
    @EnvironmentObject private var importService: LibraryImportService
    @Environment(\.dismiss) private var dismiss
    
    @State private var audioMetadata: AudioMetadata?
    @State private var isLoadingMetadata = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // File Header
                    VStack(spacing: 12) {
                        Image(systemName: file.fileTypeIcon)
                            .font(.system(size: 60))
                            .foregroundColor(iconColor)
                        
                        Text(file.name)
                            .font(.title2)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)
                        
                        if file.isAudioFile {
                            Text(file.fileExtension.uppercased())
                                .font(.caption)
                                .fontWeight(.medium)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .foregroundColor(.blue)
                                .cornerRadius(6)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                    
                    // File Information
                    VStack(alignment: .leading, spacing: 16) {
                        SectionHeaderView(title: "File Information")
                        
                        DetailRowView(label: "Name", value: file.name)
                        DetailRowView(label: "Size", value: file.formattedSize)
                        DetailRowView(label: "Modified", value: DateFormatter.longDateTime.string(from: file.dateModified))
                        DetailRowView(label: "Path", value: file.url.path)
                        
                        if !file.isDirectory {
                            DetailRowView(label: "Type", value: file.fileExtension.uppercased())
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    
                    // Audio Metadata (if audio file)
                    if file.isAudioFile {
                        VStack(alignment: .leading, spacing: 16) {
                            SectionHeaderView(title: "Audio Information")
                            
                            if isLoadingMetadata {
                                HStack {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                    Text("Loading metadata...")
                                        .foregroundColor(.secondary)
                                }
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding()
                            } else if let metadata = audioMetadata {
                                AudioMetadataView(metadata: metadata)
                            } else {
                                Text("No metadata available")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .center)
                                    .padding()
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemBackground))
                        .cornerRadius(12)
                    }
                    
                    // Actions
                    if file.isAudioFile {
                        VStack(spacing: 12) {
                            Button(action: importFile) {
                                HStack {
                                    Image(systemName: "square.and.arrow.down")
                                    Text("Import to Library")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.blue)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            
                            Button(action: shareFile) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("Share File")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.green)
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(12)
                    }
                }
                .padding()
            }
            .navigationTitle("File Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            if file.isAudioFile {
                await loadAudioMetadata()
            }
        }
    }
    
    private var iconColor: Color {
        if file.isDirectory {
            return .blue
        } else if file.isAudioFile {
            return .green
        } else {
            return .gray
        }
    }
    
    private func loadAudioMetadata() async {
        isLoadingMetadata = true
        defer { isLoadingMetadata = false }
        
        do {
            let asset = AVAsset(url: file.url)
            let duration = try await asset.load(.duration)
            
            await MainActor.run {
                self.audioMetadata = AudioMetadata(
                    duration: duration.seconds,
                    title: file.name.replacingOccurrences(of: ".\(file.fileExtension)", with: ""),
                    artist: nil,
                    album: nil,
                    genre: nil,
                    year: nil
                )
            }
        } catch {
            print("Error loading audio metadata: \(error)")
            await MainActor.run {
                self.audioMetadata = AudioMetadata(
                    duration: nil,
                    title: file.name.replacingOccurrences(of: ".\(file.fileExtension)", with: ""),
                    artist: nil,
                    album: nil,
                    genre: nil,
                    year: nil
                )
            }
        }
    }
    
    private func importFile() {
        Task {
            await importService.importFiles(from: [file.url])
            await MainActor.run {
                dismiss()
            }
        }
    }
    
    private func shareFile() {
        let activityVC = UIActivityViewController(activityItems: [file.url], applicationActivities: nil)
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let rootViewController = windowScene.windows.first?.rootViewController {
            rootViewController.present(activityVC, animated: true)
        }
    }
}

// MARK: - Supporting Views

struct SectionHeaderView: View {
    let title: String
    
    var body: some View {
        Text(title)
            .font(.headline)
            .fontWeight(.semibold)
    }
}

struct DetailRowView: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
                .frame(width: 80, alignment: .leading)
            
            Text(value)
                .fontWeight(.medium)
            
            Spacer()
        }
    }
}

struct AudioMetadataView: View {
    let metadata: AudioMetadata
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let duration = metadata.formattedDuration {
                DetailRowView(label: "Duration", value: duration)
            }
            
            if let title = metadata.title {
                DetailRowView(label: "Title", value: title)
            }
            
            if let artist = metadata.artist {
                DetailRowView(label: "Artist", value: artist)
            }
            
            if let album = metadata.album {
                DetailRowView(label: "Album", value: album)
            }
            
            if let genre = metadata.genre {
                DetailRowView(label: "Genre", value: genre)
            }
            
            if let year = metadata.year {
                DetailRowView(label: "Year", value: year)
            }
        }
    }
}

// MARK: - Supporting Types

struct AudioMetadata {
    let duration: Double?
    let title: String?
    let artist: String?
    let album: String?
    let genre: String?
    let year: String?
    
    var formattedDuration: String? {
        guard let duration = duration else { return nil }
        
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Extensions

extension DateFormatter {
    static let longDateTime: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()
}

#Preview {
    FileDetailsView(
        file: FileItem(
            id: "1",
            name: "Sample Song.mp3",
            url: URL(fileURLWithPath: "/path/to/song.mp3"),
            isDirectory: false,
            size: 3_500_000,
            dateModified: Date()
        )
    )
    .environmentObject(DataManager.makePreviewImportService())
}
