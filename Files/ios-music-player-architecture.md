# iOS Music Player App - System Architecture

## Overview
This document outlines the system architecture for an iOS Music Player application, with clear distinction between MVP features (solid) and Post-MVP features (dashed).

## Architecture Layers

### 1. Presentation Layer

#### SwiftUI Views
- Library View
- Player View
- Settings View

#### ViewModels
- MVVM Pattern
- ObservableObject
- @MainActor

#### UI State
- State Management
- Combine Framework
- SwiftUI Lifecycle

#### Accessibility
- Dynamic Type
- VoiceOver Support
- WCAG 2.2 AA

### 2. Domain Layer

#### Library Manager
- Import/Export
- Organization
- Scanning

#### Playback Controller
- Queue Management
- Playback States
- Gapless Control

#### Metadata Service
- Tag Management
- Artwork Handling
- Lyrics Processing

#### Smart Playlist
- Filter Engine
- Boolean Logic
- Dynamic Updates

#### Audio Processing
- EQ & Effects
- Gain Control
- DSP Pipeline

### 3. Data Layer

#### Local Storage
- SwiftData
- Core Data Fallback
- Persistent Store

#### File System
- File Management
- Import/Export
- Sandboxed Access

#### Cloud Storage (Post-MVP)
- Adapters
- OAuth Integration
- FileProvider API

#### Caching System
- Encrypted Cache
- Streaming Buffer
- Artwork Cache

### 4. Core Services

#### Audio Engine
- AVFoundation
- Audio Session
- Bit-perfect Output

#### Format Decoders
- SFBAudioEngine
- FFmpegKit
- FLAC/ALAC/DSD/APE

#### Metadata Parser
- TagLib
- ID3/Vorbis
- Cue Sheet Support

#### Background Tasks
- Library Scanning
- Waveform Generation
- Background Audio

### 5. External Integrations (Post-MVP)

#### Cloud Storage
- Google Drive
- Dropbox
- OneDrive

#### Streaming Services
- Qobuz
- Open API
- Adaptive Streaming

#### Local Network
- Bonjour/mDNS
- Library Sharing
- Wi-Fi Sync

#### Optional Analytics
- Self-hosted PostHog
- Opt-in Only
- Anonymized Data

## Implementation Notes

### MVP Features
All components marked as solid in the architecture diagram are part of the Minimum Viable Product release.

### Post-MVP Features
Components marked as dashed are planned for future releases after the MVP launch.

### Key Technologies
- **UI Framework**: SwiftUI with MVVM architecture
- **Audio Engine**: AVFoundation with SFBAudioEngine for advanced format support
- **Data Persistence**: SwiftData (with Core Data fallback)
- **Background Processing**: iOS Background Tasks framework
- **Accessibility**: Full WCAG 2.2 AA compliance

### Architecture Principles
1. **Separation of Concerns**: Clear layer boundaries with defined responsibilities
2. **Dependency Injection**: Loose coupling between components
3. **Protocol-Oriented Design**: Interfaces for extensibility
4. **Reactive Programming**: Combine framework for state management
5. **Privacy-First**: Encrypted caching and optional analytics