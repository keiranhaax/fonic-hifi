//
//  AudioSettingsService.swift
//  Fonic HiFi
//
//  Created by Claude on 12/6/25.
//

import Foundation
import SwiftUI

/// Bridges @AppStorage settings to AudioPlaybackSettingsStore and AudioEngineFacade.
/// This service ensures UI-level settings are synchronized with the underlying
/// audio engine configuration.
@MainActor
public final class AudioSettingsService: ObservableObject {
    private let settingsStore: AudioPlaybackSettingsStore

    public init(settingsStore: AudioPlaybackSettingsStore) {
        self.settingsStore = settingsStore
    }

    /// Sync gapless setting from UI to engine store
    public func syncGaplessEnabled(_ enabled: Bool) async {
        await settingsStore.setGaplessEnabled(enabled)
    }

    /// Sync crossfade duration from UI to engine store
    public func syncCrossfadeDuration(_ duration: TimeInterval) async {
        await settingsStore.setCrossfadeDuration(duration)
    }

    /// Sync replay gain mode from UI to engine store
    public func syncReplayGainMode(_ mode: ReplayGainMode) async {
        await settingsStore.setReplayGainMode(mode)
    }

    /// Sync playback rate from UI to engine store
    public func syncPlaybackRate(_ rate: Double) async {
        await settingsStore.setPlaybackRate(rate)
    }
}
