# Fonic HiFi Device Testing Protocol

**Version:** 1.0
**Last Updated:** 2025-09-30
**Purpose:** Validate P0 fixes on physical iOS device

## Prerequisites

### Environment
- **Device:** iPhone 14 Pro or newer
- **OS:** iOS 26.0+
- **Build:** Latest from Xcode (post-P0 fixes)
- **Test Files:** 3+ audio files, 3+ minutes duration each
- **Duration:** 2-hour uninterrupted testing session
- **Location:** Quiet environment

### Setup Checklist
- [ ] Device fully charged
- [ ] Test audio files in Files app
- [ ] Airplane mode ready (for offline testing)
- [ ] Bluetooth headphones paired
- [ ] Wired headphones available
- [ ] Xcode device console connected for logs

## Test Suite (20 Test Cases)

### Background Audio (4 tests)

#### TC-1.1: Home Button Audio Continuation
1. Build and install app on device
2. Play track
3. Press home button
4. Wait 30 seconds
5. **Expected:** Audio continues playing
6. **Result:** ☐ PASS ☐ FAIL

#### TC-1.2: Lock Screen Audio Continuation
1. Play track
2. Lock device (power button)
3. Wait 30 seconds
4. **Expected:** Audio continues playing
5. **Result:** ☐ PASS ☐ FAIL

#### TC-1.3: Silent Switch Audio Playback
1. Enable silent switch (physical switch ON)
2. Play track
3. **Expected:** Audio plays (not silenced)
4. **Result:** ☐ PASS ☐ FAIL

#### TC-1.4: Extended Background Playback
1. Play track
2. Press home button
3. Wait 5 minutes
4. **Expected:** Audio still playing after 5 min
5. **Result:** ☐ PASS ☐ FAIL

---

### Lock Screen (7 tests)

#### TC-2.1: Metadata Display
1. Play track
2. Lock device
3. **Expected:** Title, artist, album visible on lock screen
4. **Result:** ☐ PASS ☐ FAIL

#### TC-2.2: Artwork Display
1. Play track with album artwork
2. Lock device
3. **Expected:** Artwork displays correctly
4. **Result:** ☐ PASS ☐ FAIL

#### TC-2.3: Scrubber Position Updates
1. Play track
2. Lock device
3. Observe scrubber for 30 seconds
4. **Expected:** Scrubber position updates smoothly every second
5. **Result:** ☐ PASS ☐ FAIL

#### TC-2.4: Scrubber Position Accuracy
1. Play track
2. Lock device
3. Note scrubber position at 1:00
4. Unlock and check app
5. **Expected:** App shows same position (±1 second)
6. **Result:** ☐ PASS ☐ FAIL

#### TC-2.5: Scrubber Seeking
1. Play track
2. Lock device
3. Drag scrubber to 50% position
4. **Expected:** Playback jumps to 50%, continues from there
5. **Result:** ☐ PASS ☐ FAIL

#### TC-2.6: Play/Pause Button
1. Play track
2. Lock device
3. Tap pause button
4. Tap play button
5. **Expected:** Playback pauses and resumes correctly
6. **Result:** ☐ PASS ☐ FAIL

#### TC-2.7: Next/Previous Buttons
1. Play track in playlist
2. Lock device
3. Tap next track button
4. Tap previous track button
5. **Expected:** Track navigation works correctly
6. **Result:** ☐ PASS ☐ FAIL

---

### Interruptions (4 tests)

#### TC-3.1: Phone Call Pause
1. Play track
2. Receive or initiate phone call
3. **Expected:** Playback pauses immediately
4. **Result:** ☐ PASS ☐ FAIL

#### TC-3.2: Phone Call Resume
1. Play track
2. Receive phone call
3. End call
4. **Expected:** Playback resumes (if shouldResume flag set)
5. **Result:** ☐ PASS ☐ FAIL

#### TC-3.3: Siri Activation Pause
1. Play track
2. Activate Siri ("Hey Siri" or button)
3. **Expected:** Playback pauses
4. **Result:** ☐ PASS ☐ FAIL

#### TC-3.4: Alarm Pause
1. Play track
2. Set alarm for 1 minute
3. Wait for alarm
4. **Expected:** Playback pauses when alarm fires
5. **Result:** ☐ PASS ☐ FAIL

---

### Route Changes (4 tests)

#### TC-4.1: Headphones Plug
1. Play track on speaker
2. Plug in headphones
3. **Expected:** Audio switches to headphones, continues playing
4. **Result:** ☐ PASS ☐ FAIL

#### TC-4.2: Headphones Unplug
1. Play track on headphones
2. Unplug headphones
3. **Expected:** Playback pauses (oldDeviceUnavailable)
4. **Result:** ☐ PASS ☐ FAIL

#### TC-4.3: Bluetooth Connect
1. Play track on speaker
2. Connect Bluetooth headphones
3. **Expected:** Audio switches to Bluetooth, continues playing
4. **Result:** ☐ PASS ☐ FAIL

#### TC-4.4: Bluetooth Disconnect
1. Play track on Bluetooth headphones
2. Disconnect Bluetooth
3. **Expected:** Playback pauses
4. **Result:** ☐ PASS ☐ FAIL

---

### Control Center (1 test)

#### TC-5.1: Control Center Controls
1. Play track
2. Swipe down Control Center
3. Verify metadata matches lock screen
4. Test play/pause button
5. **Expected:** Metadata accurate, controls work
6. **Result:** ☐ PASS ☐ FAIL

---

## Pass Criteria

**PASS:** ALL 20 tests must PASS
**FAIL:** ANY test fails → Investigate and fix before production

## Results Summary

**Test Date:** __________
**Tester:** __________
**Device:** __________
**iOS Version:** __________
**Build:** __________

**Results:**
- Total Tests: 20
- Passed: ____
- Failed: ____
- **Overall:** ☐ PASS ☐ FAIL

**Failed Tests (if any):**
1. _______________
2. _______________
3. _______________

**Notes:**
_______________________________________________________________
_______________________________________________________________
_______________________________________________________________
