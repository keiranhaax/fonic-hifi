//
//  NowPlayingInfo+Extensions.swift
//  Fonic HiFi
//
//  Created by Keiran on 5/27/25.
//

import Foundation
import MediaPlayer
import UIKit

/// Builder for creating Now Playing info dictionaries with type safety
public struct NowPlayingInfoBuilder {
    private var info: [String: Any] = [:]

    public init() {}

    /// Set the track title
    public mutating func setTitle(_ title: String) {
        info[MPMediaItemPropertyTitle] = title
    }

    /// Set the artist name
    public mutating func setArtist(_ artist: String) {
        info[MPMediaItemPropertyArtist] = artist
    }

    /// Set the album name
    public mutating func setAlbum(_ album: String) {
        info[MPMediaItemPropertyAlbumTitle] = album
    }

    /// Set the track artwork
    public mutating func setArtwork(_ image: UIImage?) {
        if let image {
            let artwork = MPMediaItemArtwork(boundsSize: image.size) { _ in image }
            info[MPMediaItemPropertyArtwork] = artwork
        }
    }

    /// Set the track duration in seconds
    public mutating func setDuration(_ duration: TimeInterval) {
        info[MPMediaItemPropertyPlaybackDuration] = duration
    }

    /// Set the current playback time in seconds
    public mutating func setElapsedTime(_ time: TimeInterval) {
        info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = time
    }

    /// Set the playback rate (1.0 = normal speed)
    public mutating func setPlaybackRate(_ rate: Float) {
        info[MPNowPlayingInfoPropertyPlaybackRate] = rate
    }

    /// Set media type (music)
    public mutating func setMediaType() {
        info[MPNowPlayingInfoPropertyMediaType] = MPNowPlayingInfoMediaType.audio.rawValue
    }

    /// Build the final dictionary
    public func build() -> [String: Any] {
        info
    }
}

// MARK: - Track Extension

public extension Track {
    /// Convert track to Now Playing info dictionary
    func toNowPlayingInfo(
        currentTime: TimeInterval = 0,
        playbackRate: Float = 1.0,
        artwork: UIImage? = nil,
    ) -> [String: Any] {
        var builder = NowPlayingInfoBuilder()

        builder.setTitle(title)
        builder.setArtist(artist)
        builder.setAlbum(album)
        builder.setDuration(duration)
        builder.setElapsedTime(currentTime)
        builder.setPlaybackRate(playbackRate)
        builder.setMediaType()

        if let artwork {
            builder.setArtwork(artwork)
        }

        return builder.build()
    }
}
