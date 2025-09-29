//
//  FileRowView.swift
//  Fonic HiFi
//
//  Created by Assistant on 12/22/24.
//

import SwiftUI

struct FileRowView: View {
    let item: FileItem
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // File icon
            Image(systemName: item.fileTypeIcon)
                .font(.title2)
                .foregroundColor(iconColor)
                .frame(width: 24, height: 24)

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)

                HStack {
                    if !item.isDirectory {
                        Text(item.formattedSize)
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Text(RelativeDateTimeFormatter().localizedString(for: item.dateModified, relativeTo: Date()))
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }

            Spacer()

            // Audio file indicator
            if item.isAudioFile {
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.caption)
                        .foregroundColor(.blue)

                    Text(item.fileExtension.uppercased())
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .foregroundColor(.blue)
                        .cornerRadius(4)
                }
            }

            // Directory indicator
            if item.isDirectory {
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            onTap()
        }
        .onLongPressGesture {
            onLongPress()
        }
    }

    private var iconColor: Color {
        if item.isDirectory {
            .blue
        } else if item.isAudioFile {
            .green
        } else {
            .gray
        }
    }
}

#Preview {
    List {
        FileRowView(
            item: FileItem(
                id: "1",
                name: "My Song.mp3",
                url: URL(fileURLWithPath: "/path/to/song.mp3"),
                isDirectory: false,
                size: 3_500_000,
                dateModified: Date(),
            ),
            onTap: {},
            onLongPress: {},
        )

        FileRowView(
            item: FileItem(
                id: "2",
                name: "Music Folder",
                url: URL(fileURLWithPath: "/path/to/folder"),
                isDirectory: true,
                size: 0,
                dateModified: Date(),
            ),
            onTap: {},
            onLongPress: {},
        )
    }
}
