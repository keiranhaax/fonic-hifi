//
//  SettingsView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//

import SwiftUI

struct SettingsView: View {
    @Environment(\.dataManager) private var dataManager
    @Environment(\.importService) private var importService
    @State private var selectedTab = 0
    
    var body: some View {
        List {
                // File Manager Section
                Section {
                    NavigationLink(destination: FileManagerView()) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("File Manager")
                                    .font(.headline)
                                Text("Browse and manage your audio files")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Storage")
                }
                
                // Import Section
                Section {
                    NavigationLink(destination: FileImportView()) {
                        HStack {
                            Image(systemName: "square.and.arrow.down.fill")
                                .foregroundColor(.green)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Import Files")
                                    .font(.headline)
                                Text("Add new music to your library")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Library")
                }
                
                // Audio Settings Section
                Section {
                    NavigationLink(destination: AudioSettingsView()) {
                        HStack {
                            Image(systemName: "speaker.wave.3.fill")
                                .foregroundColor(.orange)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Audio Settings")
                                    .font(.headline)
                                Text("Configure audio quality and output")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("Playback")
                }
                
                // App Settings Section
                Section {
                    NavigationLink(destination: AppSettingsView()) {
                        HStack {
                            Image(systemName: "gearshape.fill")
                                .foregroundColor(.gray)
                                .frame(width: 24)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Settings")
                                    .font(.headline)
                                Text("General app preferences")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding(.vertical, 4)
                    }
                } header: {
                    Text("General")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
    }
}

#Preview {
    SettingsView()
        .dataManager(DataManager.makePreviewDataManager())
        .importService(DataManager.makePreviewImportService())
}