import Foundation

/// Actor responsible for persisting user-configurable playback parameters.
/// Values are stored in `UserDefaults` so they survive application relaunches.
public actor AudioPlaybackSettingsStore {
    private enum Keys {
        static let crossfadeDuration = "audio.crossfadeDuration"
        static let replayGainMode = "audio.replayGainMode"
        static let playbackRate = "audio.playbackRate"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public func configuration(merging baseConfiguration: AudioEngineConfiguration) -> AudioEngineConfiguration {
        var config = baseConfiguration

        if let storedCrossfade = defaults.object(forKey: Keys.crossfadeDuration) as? Double {
            config = config.with(crossfadeDuration: storedCrossfade)
        }

        if let storedReplayGain = defaults.string(forKey: Keys.replayGainMode),
           let mode = ReplayGainMode(rawValue: storedReplayGain)
        {
            config = config.with(replayGainMode: mode)
        }

        if let storedRate = defaults.object(forKey: Keys.playbackRate) as? Double {
            config = config.with(playbackRate: storedRate)
        }

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
           let mode = ReplayGainMode(rawValue: stored)
        {
            return mode
        }
        return AudioEngineConfiguration.default.replayGainMode
    }

    public func playbackRate() -> Double {
        defaults.object(forKey: Keys.playbackRate) as? Double ?? AudioEngineConfiguration.default.playbackRate
    }
}
