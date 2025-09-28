# Mock & Placeholder Data Analysis

## Summary
Comprehensive analysis of all mock, placeholder, stub, and test data in the Fonic HiFi project. Removing mock engines requires coordinated updates (factory, enum, settings). Detection adapters remain placeholder-only. Hardcoded strings are confined to previews. Availability guards and TODOs persist across production and sample targets.

## 1. Stub Engine Implementations

### FFmpegEngineAdapter.swift
**Status:** STUB ONLY - No actual FFmpeg implementation
**Location:** `/Fonic HiFi/Core/Audio/Engines/FFmpegEngineAdapter.swift`

**Mock Variables:**
- `mockDuration: TimeInterval = 0`
- `mockCurrentTime: TimeInterval = 0`
- `mockVolume: Float = 1.0`

**Issues:**
- Line 11: "This is a STUB implementation - will be replaced when FFmpegKit dependency is added"
- Line 42: "// TODO: Initialize FFmpegKit when dependency is added"
- Line 49: "// TODO: Get actual time from FFmpeg decoder"
- Line 56: "// TODO: Get actual duration from FFmpeg"
- Line 92: "// TODO: Implement with FFmpegKit"
- Line 99: Mock duration hardcoded to 240.0 (4 minutes)
- Line 202: Returns "Mock codec info for \(format.displayName)"
- 15+ TODO comments throughout the file

**Dependencies to update if removed:**
- `AudioEngineFactory` instantiates this adapter (`/Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift:204-206`).
- `AudioEngineType` exposes the `.ffmpegEngine` case (`/Fonic HiFi/Core/Audio/Factory/AudioEngineType.swift:19-90`).
- Audio settings picker still offers "FFmpegEngine" as a user preference via the `preferredAudioEngine` string (`/Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:18-31`).

### SFBAudioEngineAdapter.swift
**Status:** STUB ONLY - No actual SFBAudioEngine implementation
**Location:** `/Fonic HiFi/Core/Audio/Engines/SFBAudioEngineAdapter.swift`

**Mock Variables:**
- `mockDuration: TimeInterval = 0`
- `mockCurrentTime: TimeInterval = 0`
- `mockVolume: Float = 1.0`

**Issues:**
- Line 11: "This is a STUB implementation - will be replaced when SFBAudioEngine dependency is added"
- Line 39: "// TODO: Initialize SFBAudioEngine when dependency is added"
- Line 46: "// TODO: Get actual time from SFBAudioEngine"
- Line 53: "// TODO: Get actual duration from SFBAudioEngine"
- Line 99: Mock duration hardcoded to 180.0 (3 minutes)
- 12+ TODO comments throughout the file

**Dependencies to update if removed:**
- `AudioEngineFactory` constructs this adapter (`/Fonic HiFi/Core/Audio/Factory/AudioEngineFactory.swift:200-203`).
- `AudioEngineType` includes `.sfbAudioEngine` and related metadata (`/Fonic HiFi/Core/Audio/Factory/AudioEngineType.swift:18-88`).
- Audio settings picker exposes the option (`/Fonic HiFi/Presentation/Views/Settings/AudioSettingsView.swift:21-23`).

## 2. Hardcoded Test/Preview Data

> All occurrences below live inside `#Preview` scaffolding. Decide whether previews may keep literals or should load shared preview fixtures (e.g., via `PreviewTrack.sample`).

### DebugTrackRowView.swift
**Location:** `/Fonic HiFi/Presentation/Views/Debug/DebugTrackRowView.swift`
```swift
Line 95: title: "Test Track",
Line 96: artist: "Test Artist",
Line 97: album: "Test Album",
```

### TrackRowView.swift
**Location:** `/Fonic HiFi/Presentation/Views/Library/TrackRowView.swift`
```swift
Line 86: title: "Sample Track",
Line 87: artist: "Sample Artist",
Line 88: album: "Sample Album",
```

### FileDetailsView.swift
**Location:** `/Fonic HiFi/Presentation/Views/Settings/FileDetailsView.swift`
```swift
Line 305: name: "Sample Song.mp3"
```

### AccessibilityEnhancements.swift
**Location:** `/Fonic HiFi/Presentation/Views/Components/AccessibilityEnhancements.swift`
```swift
Line 436: Text("Example Song - Artist Name")
Line 440: trackTitle: "Example Song",
Line 441: artist: "Artist Name",
```

### iOS26_Features_Documentation.swift
**Location:** `/Fonic HiFi/Presentation/Views/Components/iOS26_Features_Documentation.swift`
```swift
Line 263: Text("Example Song")
Line 282: trackTitle: "Example Song",
Line 283: artist: "Artist Name",
```

## 3. iOS 26 Availability Checks (Should Be Removed)

### BottomSearchBar.swift
```swift
Line 25: if #available(iOS 26, *) {
Line 136: if #available(iOS 26, *) {
```

### LiquidGlassRail.swift
```swift
Line 301: if #available(iOS 26, *) {
Line 325: if #available(iOS 26, *) {
```

### LiquidGlassTabBar.swift
```swift
Line 149: if #available(iOS 26, *) {
Line 169: if #available(iOS 26, *) {
```

### PerformanceOptimizedContainer.swift
```swift
Line 78: if #available(iOS 26, *) {
```

### iOS26_Features_Documentation.swift
```swift
Line 235: @available(iOS 26, *)
```
> Documentation-only view, but project guidelines (`CLAUDE.md`) still require dropping availability attributes.

### Sample Apps
- `/sample/AppleMusicBottomBar/AppleMusicBottomBar/ContentView.swift` - Line 16 (`if #available(iOS 26, *)` and fallback block)
- `/sample/AppleMusicMiniPlayer/AppleMusicMiniPlayer/Helpers/UniversalOverlay.swift` - Line 120
> Removing availability checks requires rewriting fallback branches so the demos still compile when they become iOS26-only.

## 4. TODO Comments

### BitPerfectValidator.swift
```swift
Line 1040: // TODO: Load from user defaults or external database
Line 1045: // TODO: Save to persistent storage
```

### AudioFormatDetectionManager.swift
```swift
Line 292: // TODO: Implement with SFBAudioEngine
Line 302: // TODO: Implement with FFmpegKit
Line 312: // TODO: Implement with TagLib
```
> These adapters are currently unregistered, so removing them or converting them to real implementations has minimal behavior impact but cleans up lingering TODOs.

### Engine Stubs
- Every TODO inside `FFmpegEngineAdapter` and `SFBAudioEngineAdapter` remains until the stubs are replaced or deleted. Clearing the files without addressing the factory/settings references will break builds.

### SearchPlaylistResultsView.swift
```swift
Line 26: // TODO: Navigate to PlaylistDetailView when implemented
```

## 5. Deprecated/Obsolete Files

### TabBarMiniPlayer.swift
**Location:** `/Fonic HiFi/Presentation/Views/Components/TabBarMiniPlayer.swift`
**Status:** File marked as removed but still exists
```swift
Line 5: "Removed in favour of LiquidGlassMiniPlayer accessing the tab bar accessory directly."
```

## 6. Sample/Reference Implementations

### Sample Folder Contents
- `/sample/AppleMusicBottomBar/` - Reference implementation for bottom bar
- `/sample/AppleMusicMiniPlayer/` - Reference implementation for mini player

**Evaluation Needed:** Determine if these are necessary for production or just development references

## 7. Impact Analysis

### Files Affected: 18+
### Lines of Mock Code: ~450
### TODO Comments: 30+
### Hardcoded Test Strings: 15+
### iOS Availability Checks: 10+
### Deprecated Files: 1

## 8. Cleanup Priority

### Critical (Remove Immediately)
1. Stub engine implementations (FFmpegEngineAdapter, SFBAudioEngineAdapter)
2. iOS 26 availability checks (project requirement violation)
3. Deprecated TabBarMiniPlayer.swift

### High Priority
1. Hardcoded test data in preview providers
2. Mock return values in production code

### Medium Priority
1. TODO comments that won't be implemented
2. Sample folder evaluation

### Low Priority
1. Documentation examples (may be useful for reference)

## 9. Verification Commands

Find all mock data:
```bash
make search PATTERN='mock|Mock|MOCK'
```

Find all TODOs:
```bash
make find-todos
```

Find test/sample data:
```bash
make search PATTERN='"Test |"Sample |"Example '
```

Find availability checks:
```bash
make search PATTERN='if #available|@available'
```

## 10. Action Items

1. **Delete Files:**
   - FFmpegEngineAdapter.swift
   - SFBAudioEngineAdapter.swift
   - TabBarMiniPlayer.swift

2. **Remove Code Blocks:**
   - All `if #available(iOS 26, *)` blocks
   - All `@available(iOS 26, *)` annotations

3. **Replace Hardcoded Data:**
   - Update all preview providers to use proper data models
   - Remove literal test strings

4. **Clean TODOs:**
   - Either implement or remove TODO sections
   - No TODOs should remain in production code

5. **Review Sample Folder:**
   - Determine necessity of sample apps
   - Move to separate repository if needed for reference only