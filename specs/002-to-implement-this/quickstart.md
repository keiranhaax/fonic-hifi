# Quickstart Guide - Fonic HiFi Improvements

**Version**: 1.0
**Date**: 2025-09-26
**Purpose**: Validate the critical improvements implementation

## Prerequisites

- Xcode 26 with iOS 26 SDK
- iPhone 16 Pro Simulator (iOS 26.0)
- Sample audio files in various formats (MP3, FLAC, ALAC, AAC)
- At least 100 test tracks for performance testing

## Setup

1. **Clone and Build**
```bash
git checkout 002-to-implement-this
make clean
make build
```

2. **Verify Build Success**
```bash
make build-verify
# Should complete without errors
```

3. **Launch Simulator**
```bash
make simulator-boot
make run
```

## Validation Scenarios

### 1. Concurrency Stability (FR-001, FR-005)

**Test Thread Safety**:
1. Launch the app
2. Start playing a track
3. Rapidly switch between tracks 10 times
4. Background and foreground the app during playback
5. **Expected**: No crashes, smooth transitions

**Verify Fix**:
```bash
# Check for concurrency violations in logs
make logs-stream | grep "actor executor assumption"
# Should return no results
```

### 2. Remote Commands (FR-002)

**Test Control Center**:
1. Start playing a track
2. Open Control Center (swipe down from top-right)
3. Use play/pause/skip controls
4. **Expected**: Immediate response to all commands

**Test Lock Screen**:
1. Play a track and lock the device (Cmd+L in simulator)
2. View lock screen controls
3. Test play/pause/skip
4. **Expected**: Controls work, Now Playing info displays correctly

### 3. Audio Interruptions (FR-003)

**Simulate Phone Call**:
1. Start playback
2. In simulator: Device → Trigger Incoming Call
3. Accept the call
4. End the call
5. **Expected**: Playback pauses on call, resumes after

### 4. Error Handling (FR-004)

**Test Invalid File**:
1. Attempt to import a corrupted audio file
2. **Expected**: User-friendly error message, no crash

**Test Initialization Failure**:
1. Launch app with audio route unavailable
2. **Expected**: Graceful degradation with clear message

### 5. Performance - Large Library (FR-007, FR-010)

**Import Performance**:
1. Select 1000+ tracks to import
2. Monitor UI responsiveness during import
3. **Expected**:
   - UI remains at 60fps
   - Progress updates every 0.2s
   - Can navigate app during import

**Search Performance**:
```bash
# Time library search
make benchmark-search
```
**Expected**: <150ms for 100k tracks

### 6. Data Relationships (FR-008)

**Test Album/Artist Queries**:
1. Navigate to an artist
2. View all albums by that artist
3. View all tracks in an album
4. **Expected**: All relationships load correctly

### 7. Queue Management (FR-009, FR-020, FR-021)

**Test Shuffle Persistence**:
1. Enable shuffle and play 5 tracks
2. Force quit the app
3. Relaunch
4. **Expected**: Shuffle sequence preserved

**Test Queue State**:
1. Add 10 tracks to queue
2. Skip to track 5
3. Change repeat mode to "All"
4. Background the app
5. **Expected**: Queue position and mode preserved

### 8. Memory Management (FR-016, FR-023)

**Monitor Memory**:
```bash
make memory-graph
# During playback, check for leaks
```

**Engine Switching**:
1. Play MP3 (uses AVAudioEngine)
2. Play FLAC (switches to AudioKit)
3. Repeat 10 times
4. **Expected**: No memory growth

### 9. Bit-Perfect Validation (FR-017)

**Test High-Res Audio**:
1. Connect USB DAC (if available)
2. Play 96kHz/24-bit FLAC file
3. Check diagnostics screen
4. **Expected**: Shows "Bit-Perfect: ✓"

### 10. User Experience (FR-025, FR-026, FR-027, FR-028)

**Visual Feedback**:
1. Start a long import (500+ files)
2. **Expected**: Progress bar with file count

**Error Messages**:
1. Try to play unsupported format
2. **Expected**: "This audio format is not supported" (not technical error)

**Background Playback**:
1. Start playback
2. Open another app
3. **Expected**: Audio continues, Now Playing updated

## Performance Benchmarks

Run the full benchmark suite:
```bash
make benchmark-all
```

### Target Metrics
- ✅ App Launch: <2 seconds
- ✅ Audio Latency: <50ms
- ✅ Memory Usage: <200MB typical
- ✅ Search 100k tracks: <150ms
- ✅ UI Frame Rate: 60fps constant

## Monitoring

### View Metrics Dashboard
```bash
# Real-time performance monitoring
make monitor-performance

# Memory tracking
make memory-leaks

# Audio diagnostics
make profile-audio
```

### Check Crash Rate
```bash
# Parse logs for crashes
make logs-show | grep "Terminating app"
```
Target: <0.1% crash rate

## Troubleshooting

### Issue: Remote commands not working
**Solution**: Verify `AudioSessionManager.enableRemoteCommands()` is called in `AudioEngineFacade.initialize()`

### Issue: UI freezes during import
**Solution**: Check that `LibraryImportService` file I/O is off @MainActor

### Issue: Memory growing during playback
**Solution**: Verify `[weak self]` in all timer/callback closures

### Issue: Relationships not loading
**Solution**: Confirm @Relationship macros added to Album.swift and Artist.swift

## Regression Testing

After each change:
1. Run quickstart scenarios 1-10
2. Check performance benchmarks
3. Monitor crash rate for 100 operations
4. Verify memory stays under 200MB

## Sign-off Checklist

- [ ] All 10 validation scenarios pass
- [ ] Performance metrics meet targets
- [ ] No memory leaks detected
- [ ] Crash rate <0.1%
- [ ] Remote commands functional
- [ ] Large library handling smooth
- [ ] Error messages user-friendly
- [ ] Background playback works

## Next Steps

Once all validations pass:
1. Run `/tasks` to generate implementation tasks
2. Execute tasks in priority order
3. Re-run quickstart after each week's tasks
4. Document any issues found

---
*This quickstart guide validates the implementation of 28 functional requirements for the Fonic HiFi critical improvements.*