//
//  LocalizedFormatters.swift
//  Fonic HiFi
//
//  Locale-aware presentation helpers. Keep persisted values and widget payloads
//  language-neutral; localize only at the display boundary.
//

import Foundation

enum LocalizedFormatters {
    static func audioEngineName(
        _ engineType: AudioEngineType?,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        switch engineType {
        case .some(.avAudioEngine):
            return String(
                localized: "Native Audio Engine",
                bundle: bundle,
                locale: locale,
                comment: "Apple AVAudioEngine name shown in Settings"
            )
        case .some(.audioKitEngine):
            return String(
                localized: "AudioKit Engine",
                bundle: bundle,
                locale: locale,
                comment: "AudioKit engine name shown in Settings"
            )
        case nil:
            return String(
                localized: "The current audio engine",
                bundle: bundle,
                locale: locale,
                comment: "Fallback audio engine name shown in Settings"
            )
        }
    }

    static func albumCount(
        _ count: Int,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        return String(
            localized: "\(count) albums",
            bundle: bundle,
            locale: locale,
            comment: "Album count shown in library summaries"
        )
    }

    static func trackCount(
        _ count: Int,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        return String(
            localized: "\(count) tracks",
            bundle: bundle,
            locale: locale,
            comment: "Track count shown in library summaries"
        )
    }

    static func upNextTrackCount(
        _ count: Int,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        return String(
            localized: "Up Next · \(count) tracks",
            bundle: bundle,
            locale: locale,
            comment: "Queue section heading followed by the number of upcoming tracks"
        )
    }

    static func failedImportCount(
        _ count: Int,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        return String(
            localized: "\(count) files failed to import",
            bundle: bundle,
            locale: locale,
            comment: "Summary of files that could not be imported"
        )
    }

    static func deleteFileCount(
        _ count: Int,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        return String(
            localized: "Delete \(count) files",
            bundle: bundle,
            locale: locale,
            comment: "Destructive action label for the selected file count"
        )
    }

    static func deleteFilesConfirmation(
        _ count: Int,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        return String(
            localized: "Are you sure you want to delete \(count) files? This action cannot be undone.",
            bundle: bundle,
            locale: locale,
            comment: "Confirmation before permanently deleting the selected files"
        )
    }

    static func sampleRate(
        _ hertz: Double,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        let number = hertz.formatted(
            .number
                .grouping(.automatic)
                .precision(.fractionLength(0))
                .locale(locale)
        )
        return String(
            localized: "\(number) Hz",
            bundle: bundle,
            locale: locale,
            comment: "Audio sample rate. The placeholder is a locale-formatted number."
        )
    }

    static func frequency(
        _ hertz: Double,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        let number = hertz.formatted(
            .number
                .grouping(.automatic)
                .precision(.fractionLength(0))
                .locale(locale)
        )
        return String(
            localized: "\(number) Hz",
            bundle: bundle,
            locale: locale,
            comment: "Equalizer band frequency. The placeholder is a locale-formatted number."
        )
    }

    static func gain(
        _ decibels: Float,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        let number = Double(decibels).formatted(
            .number
                .precision(.fractionLength(1))
                .locale(locale)
        )
        return String(
            localized: "\(number) dB",
            bundle: bundle,
            locale: locale,
            comment: "Equalizer gain. The placeholder is a signed locale-formatted number."
        )
    }

    static func gainNumber(
        _ decibels: Float,
        locale: Locale = .current
    ) -> String {
        Double(decibels).formatted(
            .number
                .precision(.fractionLength(1))
                .locale(locale)
        )
    }

    static func gainAccessibilityValue(
        _ decibels: Float,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        let number = Double(decibels).formatted(
            .number
                .precision(.fractionLength(1))
                .locale(locale)
        )
        return String(
            localized: "\(number) decibels",
            bundle: bundle,
            locale: locale,
            comment: "VoiceOver value for an equalizer gain control"
        )
    }

    static func crossfadeDuration(
        _ seconds: Int,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        return String(
            localized: "\(seconds) seconds",
            bundle: bundle,
            locale: locale,
            comment: "Crossfade duration value announced by VoiceOver"
        )
    }

    static func artistAlbum(
        artist: String,
        album: String,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        guard !album.isEmpty else { return artist }
        return String(
            localized: "\(artist) — \(album)",
            bundle: bundle,
            locale: locale,
            comment: "Artist and album metadata; translators may reorder placeholders and punctuation"
        )
    }

    static func titleArtist(
        title: String,
        artist: String,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        guard !artist.isEmpty else { return title }
        return String(
            localized: "\(title) • \(artist)",
            bundle: bundle,
            locale: locale,
            comment: "Track title and artist metadata; translators may reorder placeholders and punctuation"
        )
    }

    static func equalizerUnavailable(
        engineName: String,
        locale: Locale = .current,
        bundle: Bundle = .main
    ) -> String {
        return String(
            localized: "\(engineName) does not support equalizer processing. Your setting is saved and will be reapplied when a compatible engine is used.",
            bundle: bundle,
            locale: locale,
            comment: "Equalizer limitation. The placeholder is an audio engine name."
        )
    }
}
