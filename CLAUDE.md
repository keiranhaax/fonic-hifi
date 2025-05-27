# Fonic HiFi iOS App

You are working on Fonic HiFi, a high-fidelity music player iOS app focused on audiophile users with privacy-first design.

## Project Overview
- iOS 18+ music player app using Swift 6 and SwiftUI 5
- Focus on bit-perfect audio playback and high-resolution formats
- Offline-first, privacy-focused design with no data collection
- Target audience: audiophiles and music enthusiasts

## Tech Stack
- **UI Framework**: SwiftUI 5
- **Architecture**: MVVM with feature-based modules
- **Database**: SwiftData with Core Data fallback
- **Audio Engines**: AVFoundation (primary), SFBAudioEngine (DSD/APE), FFmpegKit (extended formats)
- **Metadata**: TagLib for parsing/writing

## Build Commands
- `xcodebuild build -scheme FonicHiFi -configuration Debug`: Build debug version
- `xcodebuild test -scheme FonicHiFi`: Run unit tests
- `swift build`: Build using Swift Package Manager (if applicable)
- `pod install`: Install CocoaPods dependencies (if using)

## Code Style
- Use Swift 6 with strict concurrency checking enabled
- Follow MVVM pattern with clear separation of concerns
- Prefer value types (structs) for domain models
- Use async/await for all asynchronous operations
- Implement proper error handling with typed errors
- Document all public APIs with triple-slash comments

## Directory Structure
- `/FonicHiFi/App`: App entry point and configuration
- `/FonicHiFi/Presentation`: Views, ViewModels, UI state
- `/FonicHiFi/Domain`: Models, use cases, interfaces
- `/FonicHiFi/Data`: Repositories, data sources, DTOs
- `/FonicHiFi/Core`: Core services (audio, file system, metadata)
- `/FonicHiFi/Utils`: Extensions, helpers, constants

## Key Features (MVP)
1. **Core Music Library**: Import, organize, and play high-res audio files
2. **Advanced Playback Engine**: Bit-perfect playback with format support
3. **Smart Playlists**: Dynamic playlists with complex filtering
4. **Metadata Editor**: View/edit tags, artwork, lyrics with batch support

## Audio Format Support
- Lossless: FLAC, ALAC, AIFF, WAV
- Compressed: MP3, AAC
- High-res: APE, DSD (via SFBAudioEngine)
- Metadata: ID3, Vorbis, APE tags
- Support for .cue sheets

## Performance Modes
- **Balanced**: Default mode with efficient battery usage
- **Maximum Quality**: Bit-perfect, no compression, full features
- **Battery Saver**: Reduced processing, simplified visuals

## Privacy Requirements
- No data collection or analytics by default
- All processing happens on-device
- External services require explicit opt-in
- Use encrypted local storage for sensitive data
- Implement privacy onboarding screen

## Accessibility
- Full VoiceOver support with meaningful labels
- Dynamic Type support throughout
- Respect reduced motion settings
- WCAG 2.2 AA compliance
- High contrast mode support

## Common Tasks
- When adding new audio format support, update both decoder and UI indicators
- Always test with large libraries (10k+ tracks) for performance
- Ensure background audio session is properly configured
- Validate bit-perfect output with BitPerfectValidatorService
- Run accessibility audit after UI changes

@CLAUDE-ARCHITECTURE.md
@CLAUDE-FEATURES.md
@CLAUDE-WORKFLOW.md