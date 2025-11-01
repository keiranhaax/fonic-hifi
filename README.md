# Fonic HiFi 🎵

![iOS 26+](https://img.shields.io/badge/iOS-26%2B-blue)
![Swift 6.2](https://img.shields.io/badge/Swift-6.2-orange)
![SwiftUI iOS 26](https://img.shields.io/badge/SwiftUI-iOS%2026-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

A sophisticated iOS 26 audiophile music player built with Swift 6.2, SwiftUI, and AudioKit, focusing on bit-perfect playback and format versatility.

## Features

### 🎧 Audio Excellence
- **Bit-Perfect Playback**: True lossless audio reproduction
- **Multi-Engine Architecture**: Automatic engine selection based on format
  - AVAudioEngine for standard formats (MP3, AAC, ALAC, WAV, AIFF)
  - AudioKit for FLAC playback and advanced DSP processing
  - Extensible adapter layer for future engines
- **Gapless Playback**: Seamless track transitions
- **High-Resolution Support**: Up to 32-bit/384kHz

### 📚 Format Support
- **Lossless**: ALAC, FLAC, WAV, AIFF
- **Compressed**: MP3, AAC
- **Extensible**: Architecture-ready for additional formats via adapters

### 🎨 Modern SwiftUI Interface
- Native iOS 26 Liquid Glass design using `.glassEffect()` surfaces
- Adaptive layouts tuned for iPhone 16 Pro and larger displays
- Smooth animations with matched geometry effects and timeline scrubbing
- Dark mode-first visuals for OLED panels
- Full VoiceOver, Dynamic Type, and reduced motion accommodations

### 🔒 Privacy-First
- No cloud services or analytics
- All data stored locally
- No network permissions required
- File access limited to user-selected directories

## Architecture

### Swift 6.2 Concurrency
The app opts into Swift 6.2's main-actor-by-default tooling while isolating persistence and playback work behind actors:

```swift
@MainActor: UI components, view models, AudioEngineFacade
TrackDataActor: SwiftData operations, file I/O
AudioSessionManager: AVAudioSession configuration
LibraryImportService: Managed imports and background file I/O
```

### Audio Engine Facade Pattern
Intelligent engine selection based on audio format:

```
AudioEngineFacade (Main coordinator)
├── AVAudioEngineAdapter (MP3, AAC, ALAC, WAV, AIFF)
└── AudioKitEngineAdapter (FLAC playback, advanced DSP)
```

### SwiftUI-Native State Management
- Direct use of `@State`, `@AppStorage`, and custom `@Environment` values
- No unnecessary MVVM abstractions
- Single source of truth via `AudioEngineFacade`
- Feature-based organization

## Requirements

- iOS 26.0+ deployment target (iPhone 16 Pro simulator default)
- iPhone 16 Pro or newer hardware for on-device validation
- Xcode 16.4+ with the Swift 6.2 toolchain
- Homebrew toolchain via `make install-deps` (SwiftLint, SwiftFormat, xcbeautify)

## Installation

### Clone the Repository
```bash
git clone https://github.com/keiranhaax/fonic-hifi.git
cd fonic-hifi
```

### Open in Xcode
```bash
make open
```

### Build and Run
1. Run `make run` to build and launch on the iPhone 16 Pro (iOS 26) simulator.
2. Grant file access permissions when prompted.
3. Connect an external DAC before launch if you want to validate bit-perfect playback.

## Development

### Build & Test Commands

```bash
make build        # Debug build for iPhone 16 Pro (iOS 26)
make test-unit    # Unit + integration test suites
make test-ui      # End-to-end UI flows
make coverage     # Generates coverage report (xccov JSON + HTML bundle)
make coverage-check  # Fails if overall/app targets drop below configured thresholds
make lint         # SwiftLint quality checks
make format       # SwiftFormat auto-formatting
make clean        # Reset derived data and build artifacts
```

### Project Structure

```
Fonic HiFi/
├── Assets.xcassets/              # Design assets
├── Core/
│   └── Audio/                    # Engine facade, adapters, diagnostics
├── Data/
│   ├── Actors/                   # SwiftData model actors
│   ├── Extensions/               # SwiftData helpers (pagination, batching)
│   ├── Migration/                # Schema migration plans
│   ├── Models/                   # SwiftData model definitions
│   └── Services/                 # Library import + metadata services
├── Presentation/
│   ├── Environment/              # SwiftUI environment values
│   ├── Models/                   # Presentation models and fixtures
│   ├── ViewModels/               # Screen-level controllers
│   └── Views/                    # SwiftUI screens and components
├── Utils/                        # Shared helpers and diagnostics utilities
├── ContentView.swift             # Primary SwiftUI entry point
├── FonicHiFiApp.swift            # App lifecycle entry point
└── Fonic_HiFi.entitlements       # Capability configuration
```

### Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Swift 6.2 approachable concurrency with main-actor-by-default mode
- SwiftUI best practices
- Comprehensive documentation for public APIs
- Unit tests for business logic

### Observability & Telemetry

- Logging routes through `Log.logger(_:)` using the category taxonomy defined in `Utils/Logging/Log.swift`.
- Redact file paths and long user-provided strings with `LogPrivacy` helpers before emitting log or metric metadata.
- Optional counters for imports, engine switches, and queue mutations reside in `Utils/Logging/Metrics.swift`; enable them in debug/testing contexts via `Metrics.enable(true)`.
- See `docs/refactor/observability-walkthrough.md` for an end-to-end walkthrough of instrumentation, privacy guards, and validation steps.

## Performance

### Key Metrics
- Audio switch latency: < 10ms
- Library scan: > 1000 tracks/sec
- Memory per 100 tracks: < 1MB
- UI responsiveness: 60fps constant

### Optimization Targets
- Batch SwiftData operations for large libraries
- Preload next track metadata
- Cache audio engine instances
- Implement view pagination

## Roadmap

### In Progress 🚧
- Equalizer UI implementation
- Queue management improvements
- Album art extraction

### Planned Features 📋
- iCloud library sync
- AirPlay 2 support
- Shortcuts integration
- Widget support
- CarPlay interface
- Spatial audio support

### Future Enhancements 🔮
- Music discovery features
- Lyrics display
- Sleep timer
- Crossfade controls
- ReplayGain support

## Known Issues

- Engine switching latency spike on first switch (optimization in progress)
- Memory leak in AudioKit DSP chain (workaround: periodic cleanup)
- SwiftData relationship faulting performance (investigation ongoing)

## Support

For bug reports and feature requests, please use the [GitHub Issues](https://github.com/keiranhaax/fonic-hifi/issues) page.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- [AudioKit](https://audiokit.io/) for DSP capabilities
- SwiftUI community for architecture insights

---

Built with ❤️ for audiophiles who value quality, privacy, and elegant design.
