//
//  Track.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation

/// Temporary placeholder for Track model
/// TODO: This will be moved to Domain layer and properly implemented
public struct Track: Identifiable, Sendable {
    public let id: UUID
    public let title: String
    public let artist: String?
    public let album: String?
    public let url: URL
    public let duration: TimeInterval
    public let format: AudioFormat
    
    public init(
        id: UUID = UUID(),
        title: String,
        artist: String? = nil,
        album: String? = nil,
        url: URL,
        duration: TimeInterval,
        format: AudioFormat
    ) {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.url = url
        self.duration = duration
        self.format = format
    }
}