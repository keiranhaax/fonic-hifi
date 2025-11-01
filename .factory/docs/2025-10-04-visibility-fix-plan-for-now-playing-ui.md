## Visibility Fix Plan for Now Playing UI

### 1. Restore Header Bar Presence
- **Problem**: Screenshot shows album artwork immediately beneath the status bar; chevron/title/AirPlay are invisible despite existing code (lines ~120-165). Background uses `Color.white.opacity(0.001)` which is effectively transparent, so glass tint fails to differentiate content.
- **Change**: Replace the near-transparent fill with a material-backed container.
```swift
.background(
    RoundedRectangle(cornerRadius: 18, style: .continuous)
        .fill(.ultraThinMaterial)
)
```
- **Additional**: Ensure controls stay bright regardless of dominant color by explicitly setting `.foregroundStyle(.white)` on chevron/title, and give the `AirPlayRouteButton` a `.tint(.white)` wrapper so the UIKit view inherits the contrast. Optionally add `.shadow(color: .black.opacity(0.35), radius: 6)` to lift the bar from the background.

### 2. Surface Track Info Action Buttons
- **Problem**: Heart and overflow buttons (lines ~180-220) are missing visually; the screenshot shows only metadata text inside the glass pill. Likely root cause is insufficient contrast plus vertical compression from the compact padding inside the rounded card.
- **Changes**:
  - Increase vertical padding to create breathing room:
    ```swift
    .padding(.horizontal, 24)
    .padding(.vertical, 28)
    ```
  - Force the icon color to solid white and provide a discrete glass chip behind them for legibility:
    ```swift
    Image(...)
        .foregroundStyle(.white)
        .frame(width: 44, height: 44)
        .background(Circle().fill(.white.opacity(0.12)))
    ```
  - Add `.contentShape(Rectangle())` on the wrapping `HStack` to keep touch targets robust.

### 3. Improve Progress Time Label Contrast
- **Problem**: `.foregroundColor(.secondary)` on caption-sized labels blends into the dark glass, making elapsed and duration text disappear.
- **Change**: Switch to semi-opaque white with a monospaced font weight for clarity:
```swift
Text(formatTime(...))
    .font(.caption.monospacedDigit())
    .foregroundStyle(.white.opacity(0.75))
```
- Apply the same to both current-time and duration labels.

### 4. Verification Checklist
1. Build & run on iPhone 16 Pro simulator after changes.
2. Confirm header bar is visible and readable over a variety of dominant colors (dark/bright artwork).
3. Ensure heart/overflow icons display consistently and remain tappable.
4. Verify time labels appear beneath the slider and update during playback.
5. Re-test with monochrome artwork to ensure contrast remains acceptable.
6. Run `make lint` and `make build` prior to exiting feature work.

Let me know if you’d like these visibility tweaks implemented now.