# Quick Reference

## 🎯 Current Implementation Phase
Following the 32-step implementation plan from the PDF.

## 🚀 Quick Commands

### Build & Run
```bash
# Build and run
cmd+R

# Clean build
cmd+shift+K

# Run tests
cmd+U

# Profile performance
cmd+I
```

### Key Files to Start
1. `/App/FonicHiFiApp.swift` - Entry point
2. `/Presentation/Views/Library/LibraryView.swift` - Main library
3. `/Core/Audio/AudioEngine/AudioEngineService.swift` - Playback
4. `/Domain/Models/Track.swift` - Core data model

## 📱 Core Components Status

### ✅ MVP Features
- [ ] Core Music Library (Steps 1-16)
  - [ ] Project setup and architecture
  - [ ] File import and scanning
  - [ ] Library browsing
  - [ ] Search and filtering
- [ ] Advanced Playback Engine (Steps 8-12)
  - [ ] Audio engine implementation
  - [ ] DSP and processing
  - [ ] Waveform visualization
  - [ ] Queue management
- [ ] Smart Playlists (Steps 17-18)
  - [ ] Filter engine
  - [ ] Playlist management
- [ ] Metadata Editor (Steps 19-20)
  - [ ] Single file editing
  - [ ] Batch operations

### 🔄 Post-MVP Features
- [ ] Cloud Integration (Step 25-26)
- [ ] Advanced Audio (Step 27)
- [ ] Security Features (Step 28)

## 🎨 UI Color Scheme
```swift
// Dark mode colors
Background: #000000
Surface: #0A0A0A
Primary: #FF6B35
Secondary: #4ECDC4
Text: #FFFFFF
Muted: #666666
```

## 🎵 Supported Formats
| Format | Decoder | Bit-Perfect | Priority |
|--------|---------|-------------|----------|
| FLAC   | SFBAudioEngine | ✅ | High |
| ALAC   | AVAudioEngine | ✅ | High |
| WAV    | AVAudioEngine | ✅ | Medium |
| AIFF   | AVAudioEngine | ✅ | Medium |
| DSD    | SFBAudioEngine | ✅ | Low |
| MP3    | AVAudioEngine | ❌ | Low |

## 🔧 Performance Targets
- App launch: < 2 seconds
- Library scan: 1000 tracks/minute
- Scrolling: 60 fps
- Memory: < 200MB for 10k library
- Battery: 8 hours playback (balanced)

## 🐛 Debug Helpers
```swift
// Enable verbose logging
Logger.shared.logLevel = .verbose

// Force bit-perfect validation
AudioEngine.validateBitPerfect = true

// Show performance overlay
Debug.showPerformanceOverlay = true

// Simulate large library
TestData.generateLibrary(tracks: 10000)
```

## 📋 Testing Checklist
- [ ] Import 100+ files
- [ ] Scroll 10k track list
- [ ] Play FLAC 24/192
- [ ] Edit batch metadata
- [ ] Create smart playlist
- [ ] Test with VoiceOver
- [ ] Check memory leaks
- [ ] Verify bit-perfect

## 🚨 Common Gotchas
1. **Audio Session**: Must configure before playback
2. **File Permissions**: Request access before import
3. **Memory**: Downsample large artwork
4. **Threading**: UI updates on main thread only
5. **Background**: Register tasks in Info.plist

## 📞 Key Protocols
```swift
// Core service protocols
AudioEngineService
LibraryManagerService  
MetadataEditorService
SmartPlaylistService

// Repository protocols
ILibraryRepository
IPlaybackRepository
IPlaylistRepository
IMetadataRepository
```

## 🎯 Next Steps
1. Complete current implementation step
2. Run tests for completed components
3. Profile performance
4. Update progress in this file
5. Move to next step

---
*Last Updated: [Update when making progress]*
*Current Step: 1 - Project Creation and Base Architecture*