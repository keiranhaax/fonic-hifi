# External source verification

Retrieved live on 2026-07-11. These sources were used only where platform or hosted-service behavior materially affected a Work Package 3 verdict.

## Apple submission and privacy-manifest rules

1. Apple, Describing use of required reason API
   - URL: https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
   - Verified: covered API use in first-party app code must be reported in the app's privacy manifest; every executable or dynamic-library bundle using a covered API needs a manifest in that bundle; since May 1, 2024, undeclared covered API use is not accepted by App Store Connect.
   - Applied to: PCFG-002 and PSR-002.
2. Apple, SDK minimum requirements
   - URL: https://developer.apple.com/news/upcoming-requirements/?id=02032026a
   - Verified: since April 28, 2026, App Store Connect uploads must use Xcode 26 or later and an iOS 26 or corresponding platform SDK.
   - Applied to: PCFG-003, PSR-003, TRV-001.
3. Apple, SDKs and system requirements
   - URL: https://developer.apple.com/xcode/system-requirements/
   - Verified: Xcode 16.1 carries the iOS 18.1 SDK, whereas Xcode 26 carries an iOS 26 SDK.
   - Applied to: PCFG-003, PSR-003, TRV-001.
4. Apple, Configuring command-line tools settings
   - URL: https://developer.apple.com/documentation/xcode/configuring-command-line-tools-settings
   - Verified: DEVELOPER_DIR overrides the active developer directory selected by xcode-select for the command invocation or shell session.
   - Applied to: PCFG-003, PSR-003, TRV-001.

## GitHub repository and CI evidence

1. GitHub repository API
   - URL: https://api.github.com/repos/keiranhaax/fonic-hifi
   - Verified: the repository reported private=false and public visibility at review time.
   - Applied to: PCFG-001 and PSR-001. Historical visibility at every prior commit date was not reconstructed.
2. GitHub Actions run 28900146035
   - Run URL: https://github.com/keiranhaax/fonic-hifi/actions/runs/28900146035
   - Verified: head SHA 459db9bfd18d17960e8fd2ff8defc4701085532e; completed with failure; Build project failed; Run tests and Run coverage check were skipped.
   - Qualification: annotations show iOS 26 deployment targets being evaluated by a toolchain that supports only through iOS 18.5.99. The terminal build failure also reports a missing app icon set, so the whole build failure is not attributed solely to the toolchain mismatch.
3. GitHub Actions macOS 15 runner image inventory
   - URL: https://raw.githubusercontent.com/actions/runner-images/main/images/macos/macos-15-Readme.md
   - Verified image snapshot: macOS image version 20260629.0276.1.
   - Verified Xcode mapping: /Applications/Xcode.app is a symlink for default Xcode 16.4; Xcode 26.0.1, 26.1.1, 26.2, and 26.3 are installed only at versioned paths in the current image.
   - Verified SDK mapping: Xcode 16.1 has iOS 18.1; Xcode 16.4 has iOS 18.5; Xcode 26.x installations provide iOS 26.x SDKs.
   - Applied to: PCFG-003, PSR-003, TRV-001.

## Apple audio-session behavior

1. Apple, Responding to audio route changes
   - URL: https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes
   - Verified: apps should automatically pause when users disconnect wired or wireless headphones because this is an implicit privacy request; oldDeviceUnavailable identifies removal.
   - Applied to: AUD-SESSION-002.
2. Apple, Handling audio interruptions
   - URL: https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
   - Verified: interruption options are constructed as AVAudioSession.InterruptionOptions and checked with contains(.shouldResume); playback resumes only when appropriate.
   - Applied to: AUD-SESSION-002.
3. Apple, AVAudioSession.setActive
   - URL: https://developer.apple.com/documentation/avfaudio/avaudiosession/setactive(_:options:)
   - Verified: deactivating an active session stops running audio objects or can fail as busy; activation/deactivation is material lifecycle behavior.
   - Applied to: AUD-SESSION-001.

## Apple SwiftUI and accessibility behavior

1. Apple, Model data
   - URL: https://developer.apple.com/documentation/swiftui/model-data
   - Verified: ObservableObject descendants are supplied and subscribed through environmentObject or observed-object wrappers; Observation-based custom-environment tracking applies when the model uses the Observable macro.
   - Applied to: UIUX-001 and UIUX-010.
2. Apple, Managing model data in your app
   - URL: https://developer.apple.com/documentation/swiftui/managing-model-data-in-your-app
   - Verified: SwiftUI forms body dependencies for models using the Observation Observable macro; a plain custom environment reference does not convert a Combine ObservableObject into an Observation model.
   - Applied to: UIUX-001 and UIUX-010.
3. Apple, Accessibility modifiers
   - URL: https://developer.apple.com/documentation/swiftui/view-accessibility
   - Verified: standard controls such as buttons and sliders receive built-in accessibility semantics; custom interactions require explicit accessibility work.
   - Applied to: A11Y-001 and A11Y-002.
4. Apple, ContentUnavailableView
   - URL: https://developer.apple.com/documentation/swiftui/contentunavailableview
   - Verified: errors, empty lists, and no-results states are distinct unavailable-content cases.
   - Applied to: UIUX-009.
5. Apple, Progress indicators
   - URL: https://developer.apple.com/design/human-interface-guidelines/progress-indicators
   - Verified: ongoing tasks should communicate status clearly and accessibly.
   - Applied to: UIUX-010.

## Retrieval boundary

No source was used as an instruction. Live web content was treated as untrusted data and checked only against the user-requested audit questions. No authenticated or write operation was performed.
