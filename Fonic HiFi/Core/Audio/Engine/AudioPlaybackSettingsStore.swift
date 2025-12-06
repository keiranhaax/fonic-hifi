import Foundation

/// Actor responsible for persisting user-configurable playback parameters.
/// Values are stored in `UserDefaults` so they survive application relaunches.
public actor AudioPlaybackSettingsStore {
    private struct DefaultsBox: @unchecked Sendable {
        let value: UserDefaults
    }
    private enum Keys {
        static let crossfadeDuration = "audio.crossfadeDuration"
        static let replayGainMode = "audio.replayGainMode"
        static let playbackRate = "audio.playbackRate"
        static let enableGapless = "enableGaplessPlayback"
        static let equalizerConfiguration = "audio.equalizerConfiguration"
    }

    private let defaults: DefaultsBox

    public init(defaults: UserDefaults = .standard) {
        self.defaults = DefaultsBox(value: defaults)
    }

    public func configuration(merging baseConfiguration: AudioEngineConfiguration) -> AudioEngineConfiguration {
        var config = baseConfiguration

        if let storedCrossfade = defaults.value.object(forKey: Keys.crossfadeDuration) as? Double {
            config = config.with(crossfadeDuration: storedCrossfade)
        }

        if let storedReplayGain = defaults.value.string(forKey: Keys.replayGainMode),
           let mode = ReplayGainMode(rawValue: storedReplayGain) {
            config = config.with(replayGainMode: mode)
        }

        if let storedRate = defaults.value.object(forKey: Keys.playbackRate) as? Double {
            config = config.with(playbackRate: storedRate)
        }

        // Apply gapless setting (defaults to true if not explicitly set)
        config = config.with(enableGapless: isGaplessEnabled())

        return config
    }

    public func setCrossfadeDuration(_ duration: TimeInterval) {
        defaults.value.set(duration, forKey: Keys.crossfadeDuration)
    }

    public func setReplayGainMode(_ mode: ReplayGainMode) {
        defaults.value.set(mode.rawValue, forKey: Keys.replayGainMode)
    }

    public func setPlaybackRate(_ rate: Double) {
        defaults.value.set(rate, forKey: Keys.playbackRate)
    }

    public func crossfadeDuration() -> TimeInterval {
        defaults.value.object(forKey: Keys.crossfadeDuration) as? Double ?? AudioEngineConfiguration.default.crossfadeDuration
    }

    public func replayGainMode() -> ReplayGainMode {
        if let stored = defaults.value.string(forKey: Keys.replayGainMode),
           let mode = ReplayGainMode(rawValue: stored) {
            return mode
        }
        return AudioEngineConfiguration.default.replayGainMode
    }

    public func playbackRate() -> Double {
        defaults.value.object(forKey: Keys.playbackRate) as? Double ?? AudioEngineConfiguration.default.playbackRate
    }

    public func setGaplessEnabled(_ enabled: Bool) {
        defaults.value.set(enabled, forKey: Keys.enableGapless)
    }

    public func isGaplessEnabled() -> Bool {
        // Check if key exists, default to true if not set
        if defaults.value.object(forKey: Keys.enableGapless) == nil {
            return true
        }
        return defaults.value.bool(forKey: Keys.enableGapless)
    }

    // MARK: - Equalizer Configuration

    public func setEqualizerConfiguration(_ configuration: EqualizerConfiguration) {
        if let data = try? JSONEncoder().encode(configuration) {
            defaults.value.set(data, forKey: Keys.equalizerConfiguration)
        }
    }

    public func equalizerConfiguration() -> EqualizerConfiguration {
        guard let data = defaults.value.data(forKey: Keys.equalizerConfiguration),
              let config = try? JSONDecoder().decode(EqualizerConfiguration.self, from: data) else {
            return .default
        }
        return config
    }
}
