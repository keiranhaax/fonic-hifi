//
//  TrackInfo.swift
//  Fonic HiFi
//
//  Created by Claude on 5/29/25.
//

import Foundation

/// A lightweight, thread-safe representation of track information for UI display
/// This avoids threading issues with SwiftData models
struct TrackInfo: Equatable, Sendable {
    let id: UUID
    let title: String
    let artist: String
    let album: String
    let duration: TimeInterval
    let trackNumber: Int?
    let isLossless: Bool
    let audioFormat: String
    let url: URL
    
    /// Creates a TrackInfo from a Track model
    init(from track: Track) {
        self.id = track.id
        self.title = track.title
        self.artist = track.artist
        self.album = track.album
        self.duration = track.duration
        self.trackNumber = track.trackNumber
        self.isLossless = track.isLossless
        self.audioFormat = track.audioFormat
        self.url = track.url
    }
}