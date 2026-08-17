//
//  PlaylistEditorView.swift
//  Fonic HiFi
//

import SwiftUI

struct PlaylistEditorView: View {
    @StateObject private var viewModel: PlaylistEditorViewModel
    @State private var showingTrackPicker = false

    init(playlist: PlaylistEntity, store: any PlaylistMutationStore) {
        _viewModel = StateObject(
            wrappedValue: PlaylistEditorViewModel(
                playlistID: playlist.id,
                store: store
            )
        )
    }

    var body: some View {
        Group {
            if let state = viewModel.state {
                playlistContent(state.playlist)
            } else if viewModel.isLoading {
                ProgressView("Loading playlist…")
            } else {
                ContentUnavailableView(
                    "Playlist Unavailable",
                    systemImage: "music.note.list",
                    description: Text("The playlist could not be loaded.")
                )
            }
        }
        .navigationTitle(viewModel.state?.playlist.name ?? "Playlist")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if let playlist = viewModel.state?.playlist, !playlist.isSmart {
                ToolbarItemGroup(placement: .primaryAction) {
                    if !playlist.tracks.isEmpty {
                        EditButton()
                    }

                    Button {
                        showingTrackPicker = true
                    } label: {
                        Label("Add Tracks", systemImage: "plus")
                    }
                    .disabled(viewModel.isSaving)
                }
            }
        }
        .sheet(isPresented: $showingTrackPicker) {
            PlaylistTrackPickerView(
                tracks: viewModel.availableTracks,
                isSaving: viewModel.isSaving
            ) { trackID in
                await viewModel.addTracks([trackID])
            }
        }
        .alert(item: $viewModel.alert) { alert in
            Alert(
                title: Text("Unable to Update Playlist"),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .task {
            await viewModel.load()
        }
    }

    private func playlistContent(_ playlist: PlaylistMutationSnapshot) -> some View {
        List {
            Section {
                PlaylistEditorHeader(playlist: playlist)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
            }

            if playlist.isSmart {
                ContentUnavailableView(
                    "Smart Playlist",
                    systemImage: "sparkles",
                    description: Text("Its tracks are managed automatically by playlist rules.")
                )
            } else if playlist.tracks.isEmpty {
                ContentUnavailableView(
                    "Empty Playlist",
                    systemImage: "music.note",
                    description: Text("Use Add Tracks to choose music from your library.")
                )
            } else {
                Section("Tracks") {
                    ForEach(playlist.tracks) { track in
                        PlaylistEditorTrackRow(track: track)
                    }
                    .onDelete { offsets in
                        Task {
                            await viewModel.removeTracks(at: offsets)
                        }
                    }
                    .onMove { offsets, destination in
                        Task {
                            await viewModel.moveTracks(
                                fromOffsets: offsets,
                                toOffset: destination
                            )
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .overlay {
            if viewModel.isSaving {
                ProgressView()
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }
}

private struct PlaylistEditorHeader: View {
    let playlist: PlaylistMutationSnapshot

    var body: some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 16)
                .fill(playlist.isSmart ? Color.purple.opacity(0.25) : Color.accentColor.opacity(0.25))
                .frame(width: 112, height: 112)
                .overlay {
                    Image(systemName: playlist.isSmart ? "gearshape.fill" : "music.note.list")
                        .font(.system(size: 42, weight: .semibold))
                        .foregroundStyle(playlist.isSmart ? Color.purple : Color.accentColor)
                }

            Text(playlist.name)
                .font(.title3)
                .fontWeight(.semibold)
                .multilineTextAlignment(.center)

            if let description = playlist.playlistDescription, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            Label("\(playlist.tracks.count) Tracks", systemImage: "music.note")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical)
    }
}

private struct PlaylistEditorTrackRow: View {
    let track: PlaylistTrackSnapshot

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(track.title)
                .font(.body)
                .lineLimit(1)

            Text(track.artist)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .frame(minHeight: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(track.title), by \(track.artist)")
    }
}

private struct PlaylistTrackPickerView: View {
    let tracks: [PlaylistTrackSnapshot]
    let isSaving: Bool
    let onAdd: (UUID) async -> Bool

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if tracks.isEmpty {
                    ContentUnavailableView(
                        "No Tracks to Add",
                        systemImage: "checkmark.circle",
                        description: Text("Every library track is already in this playlist.")
                    )
                } else {
                    List(tracks) { track in
                        Button {
                            Task {
                                if await onAdd(track.id) {
                                    dismiss()
                                }
                            }
                        } label: {
                            HStack {
                                PlaylistEditorTrackRow(track: track)
                                Spacer()
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(Color.accentColor)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .disabled(isSaving)
                        .accessibilityHint("Adds this track to the playlist")
                    }
                }
            }
            .navigationTitle("Add Tracks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}
