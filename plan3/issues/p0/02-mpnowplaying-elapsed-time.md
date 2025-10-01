# P0-2: MPNowPlayingInfo Elapsed Time Update

**Priority:** P0 (Critical - iOS media app requirement)
**Files:**
- `Core/Audio/Engine/AudioEngineFacade.swift:930` (progress timer)
- `Core/Audio/Engine/AudioEngineFacade.swift:738` (updateNowPlayingInfo)
- `Core/Audio/Services/AudioSessionManager.swift` (changePlaybackPositionCommand)

**Issue:** `MPNowPlayingInfoPropertyElapsedPlaybackTime` hardcoded to 0, never updates
**Impact:** Lock screen scrubber doesn't move, Control Center inaccurate
**Risk:** App Store rejection for incomplete media controls

## Current State

```swift
// AudioEngineFacade.swift:738-749
private func updateNowPlayingInfo(track: Track, duration: TimeInterval) async {
    let nowPlayingInfo: [String: Any] = [
        MPMediaItemPropertyTitle: track.title,
        MPMediaItemPropertyAlbumTitle: track.album,
        MPMediaItemPropertyArtist: track.artist,
        MPMediaItemPropertyPlaybackDuration: duration,
        MPNowPlayingInfoPropertyElapsedPlaybackTime: 0,  // ❌ NEVER UPDATED
        MPNowPlayingInfoPropertyPlaybackRate: playbackRate,
    ]

    await sessionManager.updateNowPlayingInfo(nowPlayingInfo)
}
```

## Root Cause

Elapsed time set once when track starts, but never updated during playback. Progress timer (line 930) doesn't update Now Playing info.

## Implementation Steps

### Step 1: Update Elapsed Time in Progress Timer

```swift
// AudioEngineFacade.swift:930
progressTimer.start(pollInterval: 0.2) { [weak self] in
    guard let self else { return }

    Task { @MainActor in
        if case .playing(let currentTime, let duration) = await self.stateManager.currentState {
            // Existing progress update...

            // NEW: Update Now Playing elapsed time
            var info = MPNowPlayingInfoCenter.default().nowPlayingInfo ?? [:]
            info[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
            info[MPNowPlayingInfoPropertyPlaybackRate] = 1.0
            await self.sessionManager.updateNowPlayingInfo(info)
        }
    }
}
```

### Step 2: Verify Scrubber Command Wiring

`AudioSessionManager` already enables `changePlaybackPositionCommand` and forwards seeks to the delegate (`Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift:200`). Confirm the delegate path updates playback position in `AudioEngineFacade` and adjust only if regressions appear.

## Dependencies

- **Blocks:** None
- **Blocked by:** None
- **Requires:** Physical device for testing (lock screen not in simulator)

## Time Estimate

- Implementation: 1-1.5 hours
- Device testing: 1-1.5 hours
- **Total:** 2-3 hours

## Risk Assessment

- **MEDIUM:** Bidirectional sync complexity
  - **Mitigation:** Unit test seek → info → seek roundtrip
- **HIGH:** Device testing required
  - **Mitigation:** Book device 2 days in advance

## Success Criteria

- [ ] Elapsed time updates every 200ms (progress timer)
- [ ] changePlaybackPositionCommand handler confirmed to relay seeks end-to-end
- [ ] Scrubbing updates playback position
- [ ] Playback rate updates on pause (0.0) and play (1.0)
- [ ] Device test: Lock screen scrubber tracks position ✅
- [ ] Device test: Scrubbing seeks correctly ✅
- [ ] `scripts/verify-fixes.sh` shows P0-2 ✅

## Device Testing Required

- [ ] TC-2.3: Scrubber updates every second
- [ ] TC-2.4: Scrubber position accurate
- [ ] TC-2.5: Scrubber seeking works
- [ ] TC-5.1: Control Center matches lock screen

**Note:** Must test on physical device - simulator doesn't show lock screen controls

## Rollback Procedure

```bash
git checkout HEAD -- "Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift"
git checkout HEAD -- "Fonic HiFi/Core/Audio/Services/AudioSessionManager.swift"
# Rollback time: ~15 seconds
```
