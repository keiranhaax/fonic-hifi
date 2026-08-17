# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

Fonic HiFi is an unreleased technical preview. It targets iOS 27 and Xcode 27
and has no tagged releases yet; everything on `main` should be considered
in-development. Current functionality includes:

- Multi-engine audio playback (AVAudioEngine and AudioKit) with automatic
  engine selection per format: ALAC, FLAC, WAV, AIFF, MP3, and AAC
- Gapless playback and high-resolution output paths (hardware verification
  in progress)
- Local-only SwiftData library with folder import, metadata extraction, and
  artwork handling
- SwiftUI interface with iOS 27 Liquid Glass design, artwork-reactive
  theming, and accessibility support
- On-device AI recommendations and smart search via Foundation Models, with
  rule-based fallbacks
- Home Screen and Lock Screen widgets
- Equalizer with DSP processing

No network access, telemetry, or cloud services: all data stays on device.

[Unreleased]: https://github.com/keiranhaax/fonic-hifi/commits/main
