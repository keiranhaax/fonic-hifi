# Fonic HiFi 🎵

A sophisticated iOS audiophile music player built with Swift 6, SwiftUI, and AudioKit, focusing on bit-perfect playback and format versatility.

![iOS 18+](https://img.shields.io/badge/iOS-18%2B-blue)
![Swift 6](https://img.shields.io/badge/Swift-6.0-orange)
![SwiftUI](https://img.shields.io/badge/SwiftUI-5.0-green)
![License](https://img.shields.io/badge/License-MIT-yellow)

## Features

### 🎧 Audio Excellence
- **Bit-Perfect Playback**: True lossless audio reproduction
- **Multi-Engine Architecture**: Automatic engine selection based on format
  - AVAudioEngine for standard formats (MP3, AAC, ALAC)
  - AudioKit for DSP-heavy processing and equalizer
  - SFBAudioEngine for high-res formats (FLAC, DSD, MQA)
  - FFmpeg for exotic formats (OGG, OPUS, APE)
- **Gapless Playback**: Seamless track transitions
- **High-Resolution Support**: Up to 32-bit/384kHz

### 📚 Format Support
- **Lossless**: FLAC, ALAC, WAV, AIFF
- **Compressed**: MP3, AAC, OGG Vorbis, Opus
- **High-Res**: DSD (.dsf, .dff), MQA
- **Exotic**: APE, WavPack, TTA

### 🎨 Modern SwiftUI Interface
- Native iOS 18 design language
- Adaptive layouts for all device sizes
- Smooth animations with matched geometry effects
- Dark mode support
- Accessibility features

### 🔒 Privacy-First
- No cloud services or analytics
- All data stored locally
- No network permissions required
- File access limited to user-selected directories

## Architecture

### Swift 6 Concurrency
The app leverages Swift 6's strict concurrency model with clear actor isolation boundaries:

```swift
@MainActor: UI components, ViewModels, AudioEngineFacade
TrackDataActor: SwiftData operations, file I/O
AudioSessionActor: Audio session configuration
```

### Audio Engine Facade Pattern
Intelligent engine selection based on audio format:

```
AudioEngineFacade (Main coordinator)
├── AVAudioEngineAdapter (MP3, AAC, ALAC)
├── AudioKitEngineAdapter (DSP, EQ)
├── SFBAudioEngineAdapter (FLAC, DSD, MQA)
└── FFmpegEngineAdapter (OGG, OPUS, APE)
```

### SwiftUI-Native State Management
- Direct use of `@State`, `@AppStorage`, and custom `@Environment` values
- No unnecessary MVVM abstractions
- Single source of truth via `AudioEngineFacade`
- Feature-based organization

## Requirements

- iOS 18.0+
- iPhone 12 or newer (recommended)
- Xcode 16.0+
- Swift 6.0+

## Installation

### Clone the Repository
```bash
git clone https://github.com/keiranhaax/fonic-hifi.git
cd fonic-hifi
```

### Open in Xcode
```bash
open "Fonic HiFi.xcodeproj"
```

### Build and Run
1. Select your target device or simulator
2. Press `Cmd+R` to build and run
3. Grant file access permissions when prompted

## Development

### Build Commands

```bash
# Debug build
xcodebuild -scheme "Fonic HiFi" -sdk iphonesimulator -configuration Debug build

# Release build
xcodebuild -scheme "Fonic HiFi" -sdk iphonesimulator -configuration Release build

# Run tests
xcodebuild test -scheme "Fonic HiFi" -sdk iphonesimulator

# Clean build
xcodebuild clean -scheme "Fonic HiFi"
```

### Project Structure

```
Fonic HiFi/
├── Core/
│   ├── Audio/           # Audio engine and playback logic
│   ├── Models/          # Data models
│   └── Services/        # Business logic
├── Data/
│   ├── Models/          # SwiftData models
│   └── Actors/          # Concurrency actors
├── Presentation/
│   ├── Views/           # SwiftUI views
│   ├── Components/      # Reusable UI components
│   └── Environment/     # Custom environment values
└── Resources/           # Assets and configurations
```

### Contributing

Contributions are welcome! Please follow these guidelines:

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

### Code Style
- Swift 6 strict concurrency compliance
- SwiftUI best practices
- Comprehensive documentation for public APIs
- Unit tests for business logic

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
- [SFBAudioEngine](https://github.com/sbooth/SFBAudioEngine) for high-res format support
- [FFmpeg](https://ffmpeg.org/) for exotic format decoding
- SwiftUI community for architecture insights

---

Built with ❤️ for audiophiles who value quality, privacy, and elegant design.