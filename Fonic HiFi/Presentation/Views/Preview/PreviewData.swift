//
//  PreviewData.swift
//  Fonic HiFi
//
//  Created by Assistant on 9/23/25.
//

import Foundation
import SwiftData

/// Standardized preview data for SwiftUI previews
enum PreviewData {
    // MARK: - Sample Track Data

    static func makeSampleTrack() -> Track {
        Track(
            url: URL(fileURLWithPath: "/Music/Classical/Beethoven/moonlight.flac"),
            title: "Moonlight Sonata",
            artist: "Ludwig van Beethoven",
            album: "Classical Collection",
            audioFormat: "FLAC",
            duration: 335.0,
            sampleRate: 44100,
            bitDepth: 16,
            channels: 2,
            isLossless: true,
        )
    }

    static func makeSampleTrackModern() -> Track {
        Track(
            url: URL(fileURLWithPath: "/Music/Electronic/SynthwaveArtist/electric_dreams.mp3"),
            title: "Electric Dreams",
            artist: "Synthwave Artist",
            album: "Neon Nights",
            audioFormat: "MP3",
            duration: 245.0,
            sampleRate: 48000,
            bitDepth: 24,
            channels: 2,
            isLossless: false,
        )
    }

    // MARK: - Sample File Names

    static let sampleFileName = "moonlight_sonata.flac"
    static let sampleFileNameMP3 = "electric_dreams.mp3"
    static let sampleFileNameAAC = "modern_track.m4a"
}
