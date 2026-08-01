//
//  LocalizedWidgetText.swift
//  Fonic HiFi Widget
//
//  Localize display composition without changing the Codable widget payload.
//

import Foundation

enum LocalizedWidgetText {
    static func artistAlbum(
        artist: String,
        album: String,
        locale: Locale
    ) -> String {
        guard !album.isEmpty else { return artist }
        return String(
            localized: "\(artist) — \(album)",
            locale: locale,
            comment: "Artist and album metadata; translators may reorder placeholders and punctuation"
        )
    }

    static func titleArtist(
        title: String,
        artist: String,
        locale: Locale
    ) -> String {
        guard !artist.isEmpty else { return title }
        return String(
            localized: "\(title) • \(artist)",
            locale: locale,
            comment: "Track title and artist metadata; translators may reorder placeholders and punctuation"
        )
    }
}
