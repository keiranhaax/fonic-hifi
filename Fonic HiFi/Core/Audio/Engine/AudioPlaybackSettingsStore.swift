import Foundation

/// Actor responsible for persisting user-configurable playback parameters.
/// Values are stored in `UserDefaults` so they survive application relaunches.
public actor AudioPlaybackSettingsStore {
    private enum Keys {
        static let crossfadeDuration = "audio.crossfadeDuration"
        static let replayGainMode = "audio.replayGainMode"
        static let playbackRate = "audio.playbackRate"
        static let enableGapless = "enableGaplessPlayback"
        static let equalizerConfiguration = "audio.equalizerConfiguration"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public init(suiteName: String) {
        guard let defaults = UserDefaults(suiteName: suiteName) else {
            preconditionFailure("Unable to create audio playback settings suite")
        }
        self.defaults = defaults
    }

    public func configuration(merging baseConfiguration: AudioEngineConfiguration) -> AudioEngineConfiguration {
        var config = baseConfiguration

        if let storedCrossfade = defaults.object(forKey: Keys.crossfadeDuration) as? Double {
            config = config.with(crossfadeDuration: storedCrossfade)
        }

        if let storedReplayGain = defaults.string(forKey: Keys.replayGainMode),
           let mode = ReplayGainMode(rawValue: storedReplayGain) {
            config = config.with(replayGainMode: mode)
        }

        if let storedRate = defaults.object(forKey: Keys.playbackRate) as? Double {
            config = config.with(playbackRate: storedRate)
        }

        // Apply gapless setting (defaults to true if not explicitly set)
        config = config.with(enableGapless: isGaplessEnabled())

        // Engine selection must see the persisted EQ capability requirement,
        // otherwise an AudioKit preference can win before the facade applies
        // the stored band configuration.
        config = config.with(equalizerEnabled: equalizerConfiguration().isEnabled)

        return config
    }

    public func setCrossfadeDuration(_ duration: TimeInterval) {
        defaults.set(duration, forKey: Keys.crossfadeDuration)
    }

    public func setReplayGainMode(_ mode: ReplayGainMode) {
        defaults.set(mode.rawValue, forKey: Keys.replayGainMode)
    }

    public func setPlaybackRate(_ rate: Double) {
        defaults.set(rate, forKey: Keys.playbackRate)
    }

    public func crossfadeDuration() -> TimeInterval {
        defaults.object(forKey: Keys.crossfadeDuration) as? Double ?? AudioEngineConfiguration.default.crossfadeDuration
    }

    public func replayGainMode() -> ReplayGainMode {
        if let stored = defaults.string(forKey: Keys.replayGainMode),
           let mode = ReplayGainMode(rawValue: stored) {
            return mode
        }
        return AudioEngineConfiguration.default.replayGainMode
    }

    public func playbackRate() -> Double {
        defaults.object(forKey: Keys.playbackRate) as? Double ?? AudioEngineConfiguration.default.playbackRate
    }

    public func setGaplessEnabled(_ enabled: Bool) {
        defaults.set(enabled, forKey: Keys.enableGapless)
    }

    public func isGaplessEnabled() -> Bool {
        // Check if key exists, default to true if not set
        if defaults.object(forKey: Keys.enableGapless) == nil {
            return true
        }
        return defaults.bool(forKey: Keys.enableGapless)
    }

    // MARK: - Equalizer Configuration

    public func setEqualizerConfiguration(_ configuration: EqualizerConfiguration) {
        if let data = try? JSONEncoder().encode(configuration) {
            defaults.set(data, forKey: Keys.equalizerConfiguration)
        }
    }

    public func equalizerConfiguration() -> EqualizerConfiguration {
        guard let data = defaults.data(forKey: Keys.equalizerConfiguration),
              let config = try? JSONDecoder().decode(EqualizerConfiguration.self, from: data) else {
            return .default
        }
        return config
    }
}
