//
//  PlaylistListView.swift
//  Fonic HiFi
//
//  Created by Claude on 5/28/25.
//

import SwiftUI
import SwiftData

/// List view for playlists
struct PlaylistListView: View {
    let playlists: [Playlist]
    @Binding var searchText: String
    @Binding var showingCreatePlaylist: Bool
    
    @State private var selectedPlaylist: Playlist?
    
    var filteredPlaylists: [Playlist] {
        if searchText.isEmpty {
            return playlists
        } else {
            return playlists.filter {
                $0.name.localizedCaseInsensitiveContains(searchText)
            }
        }
    }
    
    var body: some View {
        Group {
            if playlists.isEmpty {
                EmptyPlaylistView(showingCreatePlaylist: $showingCreatePlaylist)
            } else {
                List(filteredPlaylists) { playlist in
                    PlaylistRowView(playlist: playlist)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .onTapGesture {
                            selectedPlaylist = playlist
                        }
                }
                .listStyle(.plain)
            }
        }
        .sheet(item: $selectedPlaylist) { playlist in
            NavigationStack {
                PlaylistDetailView(playlist: playlist, showsDismissButton: true)
            }
        }
        .sheet(isPresented: $showingCreatePlaylist) {
            CreatePlaylistView()
        }
    }
}

/// Empty playlists state
struct EmptyPlaylistView: View {
    @Binding var showingCreatePlaylist: Bool
    
    var body: some View {
        VStack {
            Spacer()
            
            VStack(spacing: 20) {
                Image(systemName: "music.note.list")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("No Playlists")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Text("Create playlists to organize your music")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            Spacer()
        }
    }
}

/// Individual playlist row
struct PlaylistRowView: View {
    let playlist: Playlist
    
    var body: some View {
        HStack(spacing: 12) {
            // Playlist icon
            RoundedRectangle(cornerRadius: 8)
                .fill(playlist.isSmart ? Color.purple.opacity(0.3) : Color.accentColor.opacity(0.3))
                .frame(width: 50, height: 50)
                .overlay(
                    Image(systemName: playlist.isSmart ? "gearshape.fill" : "music.note.list")
                        .foregroundColor(playlist.isSmart ? .purple : .accentColor)
                )
            
            // Playlist info
            VStack(alignment: .leading, spacing: 4) {
                Text(playlist.name)
                    .font(.body)
                    .lineLimit(1)
                
                HStack(spacing: 4) {
                    if playlist.isSmart {
                        Text("Smart Playlist")
                            .font(.caption2)
                            .foregroundColor(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.2))
                            .cornerRadius(4)
                    }
                    
                    Text("\(playlist.trackCount) tracks")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .contentShape(Rectangle())
    }
}

/// Playlist detail view
struct PlaylistDetailView: View {
    let playlist: Playlist
    let showsDismissButton: Bool
    
    @Environment(\.dismiss) private var dismiss
    @Query private var allTracks: [Track]
    
    init(playlist: Playlist, showsDismissButton: Bool = false) {
        self.playlist = playlist
        self.showsDismissButton = showsDismissButton
        _allTracks = Query()
    }
    
    private var playlistTracks: [Track] {
        if playlist.isSmart {
            let filtered = allTracks.filter { matchesSmartFilters(track: $0) }
            return limitSmartTracks(sortTracks(filtered, preserveManualOrder: false))
        } else {
            guard !playlist.trackIds.isEmpty else { return [] }
            let lookup = Dictionary(uniqueKeysWithValues: allTracks.map { ($0.id, $0) })
            let ordered = playlist.trackIds.compactMap { lookup[$0] }
            return sortTracks(ordered, preserveManualOrder: true)
        }
    }
    
    private func limitSmartTracks(_ tracks: [Track]) -> [Track] {
        guard let max = playlist.maxTracks, max > 0 else { return tracks }
        return Array(tracks.prefix(max))
    }
    
    var body: some View {
        let tracks = playlistTracks
        let durationText = formattedDuration(for: tracks)
        
        return List {
            Section {
                headerContent(trackCount: tracks.count, duration: durationText)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            
            if tracks.isEmpty {
                Section {
                    emptyState
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 32)
                }
            } else {
                Section {
                    ForEach(tracks) { track in
                        TrackRowView(track: track)
                            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(playlist.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsDismissButton {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private func headerContent(trackCount: Int, duration: String?) -> some View {
        VStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 12)
                .fill(playlist.isSmart ? Color.purple.opacity(0.25) : Color.accentColor.opacity(0.25))
                .frame(width: 96, height: 96)
                .overlay(
                    Image(systemName: playlist.isSmart ? "gearshape.fill" : "music.note.list")
                        .font(.system(size: 36, weight: .semibold))
                        .foregroundStyle(playlist.isSmart ? Color.purple : Color.accentColor)
                )
            
            Text(playlist.name)
                .font(.title3)
                .fontWeight(.semibold)
            
            if let description = playlist.playlistDescription, !description.isEmpty {
                Text(description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            
            HStack(spacing: 12) {
                if playlist.isSmart {
                    Label("Smart Playlist", systemImage: "sparkles")
                        .font(.caption)
                        .foregroundStyle(Color.purple)
                }
                
                Label("\(trackCount) tracks", systemImage: "music.note")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                
                if let duration {
                    Label(duration, systemImage: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
    
    private func formattedDuration(for tracks: [Track]) -> String? {
        let totalDuration = tracks.reduce(0) { $0 + $1.duration }
        guard totalDuration > 0 else { return nil }
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = totalDuration >= 3_600 ? [.hour, .minute] : [.minute, .second]
        formatter.unitsStyle = .abbreviated
        return formatter.string(from: totalDuration)
    }
    
    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: playlist.isSmart ? "sparkles" : "music.note")
                .font(.system(size: 40))
                .foregroundStyle(.secondary)
            
            Text(playlist.isSmart ? "No matching tracks yet" : "Empty playlist")
                .font(.body)
                .foregroundStyle(.secondary)
            
            if playlist.isSmart {
                Text("Adjust your rules or add more music to see results.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Add tracks from the library to populate this playlist.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal)
    }
    
    private func sortTracks(_ tracks: [Track], preserveManualOrder: Bool) -> [Track] {
        switch playlist.sortOrder {
        case .manual:
            return preserveManualOrder ? tracks : tracks
        case .dateAdded:
            return tracks.sorted { $0.dateAdded > $1.dateAdded }
        case .dateModified:
            return tracks.sorted { $0.dateModified > $1.dateModified }
        case .title:
            return tracks.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .artist:
            return tracks.sorted { $0.artist.localizedCaseInsensitiveCompare($1.artist) == .orderedAscending }
        case .album:
            return tracks.sorted { $0.album.localizedCaseInsensitiveCompare($1.album) == .orderedAscending }
        case .duration:
            return tracks.sorted { $0.duration > $1.duration }
        case .playCount:
            return tracks.sorted { $0.playCount > $1.playCount }
        case .rating:
            return tracks.sorted { ($0.rating ?? 0) > ($1.rating ?? 0) }
        case .sampleRate:
            return tracks.sorted { $0.sampleRate > $1.sampleRate }
        case .random:
            return tracks.shuffled()
        }
    }
    
    private func matchesSmartFilters(track: Track) -> Bool {
        guard !playlist.smartFilters.isEmpty else { return true }
        var result = evaluate(rule: playlist.smartFilters[0], for: track)
        
        for index in 1..<playlist.smartFilters.count {
            let nextResult = evaluate(rule: playlist.smartFilters[index], for: track)
            let logical = playlist.smartFilters[index - 1].logicalOperator
            switch logical {
            case .and:
                result = result && nextResult
            case .or:
                result = result || nextResult
            }
        }
        return result
    }
    
    private func evaluate(rule: SmartPlaylistRule, for track: Track) -> Bool {
        switch rule.field {
        case .title:
            return evaluateString(track.title, rule: rule)
        case .artist:
            return evaluateString(track.artist, rule: rule)
        case .album:
            return evaluateString(track.album, rule: rule)
        case .genre:
            return evaluateString(track.genre, rule: rule)
        case .year:
            return evaluateNumeric(track.year.map(Double.init), rule: rule)
        case .duration:
            return evaluateNumeric(track.duration, rule: rule)
        case .playCount:
            return evaluateNumeric(Double(track.playCount), rule: rule)
        case .rating:
            return evaluateNumeric(track.rating.map(Double.init), rule: rule)
        case .dateAdded:
            return evaluateDate(track.dateAdded, rule: rule)
        case .lastPlayed:
            return evaluateOptionalDate(track.lastPlayed, rule: rule)
        case .audioFormat:
            return evaluateString(track.audioFormat, rule: rule)
        case .sampleRate:
            return evaluateNumeric(track.sampleRate, rule: rule)
        case .bitDepth:
            return evaluateNumeric(Double(track.bitDepth), rule: rule)
        case .isLossless:
            return evaluateBool(track.isLossless, rule: rule)
        case .isFavorite:
            return evaluateBool(track.isFavorite, rule: rule)
        case .fileSize:
            return evaluateNumeric(Double(track.fileSize), rule: rule)
        }
    }
    
    private func evaluateString(_ actual: String?, rule: SmartPlaylistRule) -> Bool {
        guard let actual = actual?.lowercased() else {
            return rule.operator == .notEquals || rule.operator == .notContains
        }
        let value = rule.value.lowercased()
        switch rule.operator {
        case .equals:
            return actual == value
        case .notEquals:
            return actual != value
        case .contains:
            return actual.contains(value)
        case .notContains:
            return !actual.contains(value)
        case .startsWith:
            return actual.hasPrefix(value)
        case .endsWith:
            return actual.hasSuffix(value)
        default:
            return false
        }
    }
    
    private func evaluateNumeric(_ actual: Double, rule: SmartPlaylistRule) -> Bool {
        evaluateNumeric(Optional(actual), rule: rule)
    }
    
    private func evaluateNumeric(_ actual: Double?, rule: SmartPlaylistRule) -> Bool {
        guard let comparison = Double(rule.value) else { return false }
        guard let actual = actual else {
            return rule.operator == .notEquals
        }
        switch rule.operator {
        case .equals:
            return actual == comparison
        case .notEquals:
            return actual != comparison
        case .greaterThan:
            return actual > comparison
        case .greaterThanOrEqual:
            return actual >= comparison
        case .lessThan:
            return actual < comparison
        case .lessThanOrEqual:
            return actual <= comparison
        default:
            return false
        }
    }
    
    private func evaluateBool(_ actual: Bool, rule: SmartPlaylistRule) -> Bool {
        switch rule.operator {
        case .isTrue:
            return actual
        case .isFalse:
            return !actual
        case .equals:
            return actual == (rule.value.lowercased() == "true")
        case .notEquals:
            return actual != (rule.value.lowercased() == "true")
        default:
            return false
        }
    }
    
    private func evaluateDate(_ actual: Date, rule: SmartPlaylistRule) -> Bool {
        switch rule.operator {
        case .inTheLast, .notInTheLast:
            guard let days = Double(rule.value) else { return false }
            let threshold = Date().addingTimeInterval(-days * 86_400)
            let comparison = actual >= threshold
            return rule.operator == .inTheLast ? comparison : !comparison
        case .greaterThan:
            guard let days = Double(rule.value) else { return false }
            let comparisonDate = Date().addingTimeInterval(-days * 86_400)
            return actual > comparisonDate
        case .lessThan:
            guard let days = Double(rule.value) else { return false }
            let comparisonDate = Date().addingTimeInterval(-days * 86_400)
            return actual < comparisonDate
        default:
            return false
        }
    }
    
    private func evaluateOptionalDate(_ actual: Date?, rule: SmartPlaylistRule) -> Bool {
        guard let actual = actual else {
            return rule.operator == .notEquals || rule.operator == .notInTheLast
        }
        return evaluateDate(actual, rule: rule)
    }
}

/// Create playlist view
struct CreatePlaylistView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    
    @State private var playlistName = ""
    @State private var playlistDescription = ""
    @State private var isSmartPlaylist = false
    
    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Playlist Name", text: $playlistName)
                    TextField("Description (optional)", text: $playlistDescription, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section {
                    Toggle("Smart Playlist", isOn: $isSmartPlaylist)
                        .tint(.purple)
                    
                    if isSmartPlaylist {
                        Text("Smart playlists automatically update based on rules you define")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("New Playlist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Create") {
                        createPlaylist()
                    }
                    .disabled(playlistName.isEmpty)
                }
            }
        }
    }
    
    private func createPlaylist() {
        let playlist = Playlist(
            name: playlistName,
            playlistDescription: playlistDescription.isEmpty ? nil : playlistDescription,
            type: isSmartPlaylist ? .smart : .static
        )
        
        modelContext.insert(playlist)
        dismiss()
    }
}

#Preview {
    PlaylistListView(playlists: [], searchText: .constant(""), showingCreatePlaylist: .constant(false))
}