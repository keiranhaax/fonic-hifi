# Current Apple requirements and guidance for an iOS 26 local-audio app

**Audit date / source access date:** 2026-07-09
**Research scope:** Current, audit-relevant Apple requirements and guidance for the iOS 26 release line.
**Authority policy:** Official Apple Developer Documentation, App Review Guidelines, App Store Connect Help, Apple Support, and Apple developer sessions only. Repository-bundled notes were not used as authority.
**Retained official sources:** **45 official Apple URLs**: 40 current/in-scope sources plus 5 iOS 27 URLs grouped into 3 scope-boundary records.

## Conclusion

The current upload gate is unambiguous: since **2026-04-28**, App Store Connect uploads must be built with **Xcode 26 or later and an iOS 26 SDK or later**. This is a build-SDK requirement, not a statement that an app's deployment target must be iOS 26.

For a local music player, the highest-value audit checks are: valid and complete privacy-manifest declarations for every required-reason API and affected dependency; privacy-label and in-app privacy-policy accuracy; a deliberate export-compliance answer; legitimate use of the audio background mode with an `.playback` audio session; correct interruption, route-disconnect, engine-reconfiguration, and media-server-reset recovery; accurate Now Playing state and remote-command handling; common-task accessibility under VoiceOver, large Dynamic Type, contrast, Reduced Motion, Reduce Transparency, and 44-by-44-point hit targets; and verification that custom UI remains legible under iOS 26 Liquid Glass, including the Clear and Tinted appearances added in iOS 26.1.

On iOS 26, Foundation Models means the **on-device `SystemLanguageModel`**. It requires Apple-Intelligence-capable hardware, a supported language/region, Apple Intelligence enabled, downloaded model assets, and a runtime fallback for unavailability. On-device inference can work offline and keep data local, but tools written by the app can still transmit data and must be audited separately. The new `NowPlaying` framework, `PrivateCloudComputeLanguageModel`, generic `LanguageModel` provider protocol, and Xcode 27/UIScene launch requirement are **iOS 27 beta material and are out of the current release scope**.

This is a requirements/source dossier, not a repository finding report; it makes no claim that any repository file passes or violates these requirements.

## Current release boundary as of 2026-07-09

- Latest listed non-beta iOS 26 build: **iOS 26.5.2 (23F84), 2026-06-29**.
- Current iOS 26 beta: **iOS 26.6 beta 4 (23G5057c), 2026-07-06**.
- Next major OS is pre-release: **iOS 27.0 beta 3 (24A5380h), 2026-07-06**.
- Therefore, iOS 26.6 behavior is useful for forward testing but is not a production requirement, and iOS 27-only APIs must not be treated as available to the audited iOS 26 app.

## Audit requirements matrix

| Area | Current status | Audit interpretation |
|---|---|---|
| Upload SDK | Mandatory | Upload with Xcode 26+ and iOS 26 SDK+; do not confuse SDK minimum with deployment target. |
| Required-reason APIs | Mandatory when used | Every used covered category needs an approved, truthful reason in the correct bundle's `PrivacyInfo.xcprivacy`; fingerprinting is prohibited. |
| Listed third-party SDK manifests/signatures | Mandatory when applicable | Listed SDKs need valid manifests; binary dependencies need signatures in Apple's stated cases. |
| App privacy details | Mandatory for submission | App Store Connect disclosures must cover the app and third parties and stay accurate. Purely on-device processing is not “collected” unless data or a derivation leaves the device. |
| Privacy policy | Mandatory for every app | Link it in App Store Connect and make it easily accessible in-app, even for an offline app. |
| Export compliance | Mandatory determination | Answer the encryption question accurately; use `ITSAppUsesNonExemptEncryption` to encode the result and provide documentation/code when required. |
| Background audio | Allowed only for intended playback | Use `.playback` plus the Audio/AirPlay/PiP background mode; do not use audio as a general keepalive. |
| Audio recovery | Expected platform behavior | Handle interruption start/end, headphone disconnect privacy, dynamic route formats, engine resets, and media-services resets. |
| Now Playing / remote controls | Expected media integration | Publish accurate metadata/state at significant changes, register relevant commands, disable unsupported commands, and return meaningful statuses. |
| Accessibility Nutrition Labels | Voluntary on the audit date | Apple says they will become mandatory later but provides no current enforcement date; any published label must be accurate per device/common task. |
| Accessibility implementation | Strong Apple expectation | Common tasks should work with VoiceOver; support at least 200% text for a Larger Text claim; test contrast, motion, transparency, and hit targets. |
| Liquid Glass | Current iOS 26 design behavior | Standard controls adopt it when rebuilt; custom backgrounds/metrics can conflict. Test Clear/Tinted, light/dark, Increased Contrast, Reduce Transparency, and Reduce Motion. |
| Foundation Models | Available conditionally on iOS 26 | Use `SystemLanguageModel`; always check availability and provide a non-generative fallback. Do not assume all iOS 26 devices qualify. |
| iOS 27 technologies | Out of scope | `NowPlaying`, PCC, generic model providers, and Xcode 27-only launch/adaptivity changes are beta-only for this audit. |

## Current required-reason API categories most relevant to this app

Apple's live `NSPrivacyAccessedAPIType` documentation currently enumerates five categories. The following mappings are especially relevant to a local audio app; reason selection must follow the app's actual execution path, not this example list.

| Category | Common audited use | Current user-facing reasons likely to be relevant |
|---|---|---|
| `NSPrivacyAccessedAPICategoryFileTimestamp` | Imported-track dates and metadata | `C617.1` for files in the app/app-group/CloudKit container; `3B52.1` for files or directories the user specifically granted access to. |
| `NSPrivacyAccessedAPICategorySystemBootTime` | Playback timers, elapsed-time calculations, AVFAudio event timestamp conversion | `35F9.1` for elapsed time/timers; `8FFB.1` for absolute timestamps for in-app UIKit/AVFAudio events. |
| `NSPrivacyAccessedAPICategoryDiskSpace` | Import preflight, cache eviction, displaying available storage | `E174.1` to make an observable write/delete decision based on space; `85F4.1` to display disk-space information. |
| `NSPrivacyAccessedAPICategoryActiveKeyboards` | Only if the app customizes visible text-entry UI based on active keyboards | `54BD.1` for observable UI customization; otherwise this category is normally irrelevant to a player. |
| `NSPrivacyAccessedAPICategoryUserDefaults` | Preferences and app/widget shared settings | `CA92.1` for app-only defaults; `1C8F.1` for members of the same App Group. |

The same official page says Apple updates this list over time. Re-check it immediately before release and inspect the generated Xcode privacy report and final archive, including extensions and dynamic libraries.

# Official source records

## Submission, privacy, and export compliance

### APPLE-SRC-001 — SDK minimum requirements
- **Official URL:** https://developer.apple.com/news/upcoming-requirements/?id=02032026a
- **Publication/update date:** Effective 2026-04-28; announcement published 2026-02-03.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Every App Store Connect upload now needs Xcode 26+ and the iOS 26 SDK+; this does not itself set the deployment target.
- **Excerpt:** “Since April 28, 2026 … Apps uploaded to App Store Connect must be built with Xcode 26 or later using an SDK for iOS 26…”

### APPLE-SRC-002 — Privacy manifest files
- **Official URL:** https://developer.apple.com/documentation/bundleresources/privacy-manifest-files
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** `PrivacyInfo.xcprivacy` records collected-data types, tracking domains/status, and required-reason API categories; it must be a target resource and use the required name.
- **Excerpt:** “The privacy manifest is a property list that records … The types of data collected … [and] The required reasons APIs your app or third-party SDK uses.”

### APPLE-SRC-003 — Adding a privacy manifest to an app or SDK
- **Official URL:** https://developer.apple.com/documentation/bundleresources/adding-a-privacy-manifest-to-your-app-or-third-party-sdk
- **Publication/update date:** Not stated; requirement date on page is 2025-02-12.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Invalid manifests cause App Store Connect rejection; manifests for the listed commonly used SDKs must be valid and correctly located in the bundle.
- **Excerpt:** “App Store Connect rejects app submissions that include invalid privacy manifest files.”

### APPLE-SRC-004 — Third-party SDK requirements
- **Official URL:** https://developer.apple.com/support/third-party-SDK-requirements/
- **Publication/update date:** Not stated; living support page.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Developers remain responsible for dependency code; every listed SDK version/repackaging needs a manifest in the stated submission cases, and listed binary dependencies also need signatures.
- **Excerpt:** “You must include the privacy manifest for any SDK listed below … Signatures are also required in these cases where the listed SDKs are used as binary dependencies.”

### APPLE-SRC-005 — Describing use of required-reason APIs
- **Official URL:** https://developer.apple.com/documentation/bundleresources/describing-use-of-required-reason-api
- **Publication/update date:** Not stated; living documentation. Enforcement date on page is 2024-05-01.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** A covered API category and approved reason must be declared by the bundle that uses it; an SDK cannot rely on the host app's manifest; declared uses must match visible functionality and cannot support tracking.
- **Excerpt:** “Starting May 1, 2024, apps that don’t describe their use of required reason API in their privacy manifest file aren’t accepted by App Store Connect.”

### APPLE-SRC-006 — Current categories and approved reasons (`NSPrivacyAccessedAPIType`)
- **Official URL:** https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** The current list comprises File Timestamp, System Boot Time, Disk Space, Active Keyboards, and User Defaults, with per-category reason codes. Particularly relevant codes include `C617.1`, `3B52.1`, `35F9.1`, `8FFB.1`, `E174.1`, `85F4.1`, `CA92.1`, and `1C8F.1`.
- **Excerpt:** For `E174.1`: “Declare this reason to check whether there is sufficient disk space to write files, or to check whether the disk space is low so that the app can delete files…”

### APPLE-SRC-007 — Privacy updates for App Store submissions
- **Official URL:** https://developer.apple.com/news/?id=3d8a9yyh
- **Publication/update date:** 2024-02-29.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Since 2024-05-01, approved reasons are required for listed APIs used by app code; requirements also reach newly added listed SDKs and their binary signatures.
- **Excerpt:** “Starting May 1: You’ll need to include approved reasons for the listed APIs used by your app’s code to upload a new or updated app…”

### APPLE-SRC-008 — App Privacy Details
- **Official URL:** https://developer.apple.com/app-store/app-privacy-details/
- **Publication/update date:** Not stated; living App Store guidance.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** App Store Connect privacy answers are required for new apps/updates and include third-party practices. Data processed only on-device is not “collected”; off-device derivations must be evaluated separately.
- **Excerpt:** “Data that is processed only on device is not ‘collected’ and does not need to be disclosed in your answers. If you derive anything from that data and send it off device, the resulting data should be considered separately.”

### APPLE-SRC-009 — App Review Guidelines, privacy and background services
- **Official URL:** https://developer.apple.com/app-store/review/guidelines/
- **Publication/update date:** Last updated 2026-06-08.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** All apps need an in-app and App Store privacy-policy link; sharing personal data with third-party AI requires clear disclosure and explicit permission; background audio may only be used for its intended purpose.
- **Excerpt:** “All apps must include a link to their privacy policy in the App Store Connect metadata field and within the app in an easily accessible manner.” Also: “Multitasking apps may only use background services for their intended purposes: VoIP, audio playback, location, task completion, local notifications, etc.”

### APPLE-SRC-010 — Overview of export compliance
- **Official URL:** https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance/
- **Publication/update date:** Not stated; living App Store Connect Help.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Any app that uses, accesses, contains, implements, or incorporates encryption must make an export-compliance determination and answer the App Store Connect questions; documentation depends on the algorithm and distribution.
- **Excerpt:** “If your app uses, accesses, contains, implements, or incorporates encryption … you need to determine your export compliance requirements in App Store Connect.”

### APPLE-SRC-011 — `ITSAppUsesNonExemptEncryption`
- **Official URL:** https://developer.apple.com/documentation/bundleresources/information-property-list/itsappusesnonexemptencryption
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Set the key to `NO` only if the app and linked libraries use no encryption or only exempt encryption; set it to `YES` for non-exempt encryption, normally with Apple's compliance code. Omitting it causes a questionnaire per version.
- **Excerpt:** “Set the value … to `NO` … [if] your app—including any third-party libraries you link against—either uses no encryption, or only uses encryption that’s exempt…”

### APPLE-SRC-012 — Export-compliance documentation matrix
- **Official URL:** https://developer.apple.com/help/app-store-connect/reference/export-compliance-documentation-for-encryption
- **Publication/update date:** Not stated; living App Store Connect Help.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Encryption limited to Apple's operating system requires no App Store Connect documentation; non-OS standard or proprietary algorithms can require declarations/CCATS, with France-specific documentation where applicable.
- **Excerpt:** “Your app uses encryption limited to that within the Apple operating system — No documentation required in App Store Connect.”

## Background audio, session lifecycle, routing, and Now Playing

### APPLE-SRC-013 — Configuring an app for media playback
- **Official URL:** https://developer.apple.com/documentation/avfoundation/configuring-your-app-for-media-playback
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** A media app should use the `.playback` category, activate when playback begins, and enable the Audio, AirPlay, and Picture in Picture background mode for playback through backgrounding or device lock.
- **Excerpt:** “With this mode enabled and your audio session configured, your app is ready to play background audio.”

### APPLE-SRC-014 — Handling audio interruptions
- **Official URL:** https://developer.apple.com/documentation/avfaudio/handling-audio-interruptions
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Observe `interruptionNotification`; on `.began`, reflect the pause; on `.ended`, only resume automatically when appropriate and when `.shouldResume` is present.
- **Excerpt:** “If `options.contains(.shouldResume)` … Resume playback. … [Otherwise] Don’t resume playback.”

### APPLE-SRC-015 — Audio interruption notification lifecycle
- **Official URL:** https://developer.apple.com/documentation/avfaudio/avaudiosession/interruptionnotification
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** A began interruption means the session is inactive; nonmixable sessions should be deactivated when the app goes to background while not using audio.
- **Excerpt:** “If the interruption type is … `began`, the system interrupted your app’s audio session and it’s no longer active.”

### APPLE-SRC-016 — Responding to audio route changes
- **Official URL:** https://developer.apple.com/documentation/avfaudio/responding-to-audio-route-changes
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Playback should continue when headphones connect and automatically pause when they disconnect; custom players should observe route-change reasons and compare current/previous outputs.
- **Excerpt:** “Applications should respect this implicit privacy request and automatically pause playback when users disconnect their headphones.”

### APPLE-SRC-017 — `AVAudioEngineConfigurationChangeNotification`
- **Official URL:** https://developer.apple.com/documentation/avfaudio/avaudioengineconfigurationchangenotification
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** A hardware sample-rate or channel-count change stops and uninitializes the engine; nodes remain attached with old formats, and connections must be rebuilt if formats changed. Do not deallocate synchronously in the callback.
- **Excerpt:** “When … channel count or sample rate [changes], the audio engine stops, uninitializes itself, and issues this notification.”

### APPLE-SRC-018 — Media-services reset recovery
- **Official URL:** https://developer.apple.com/documentation/avfaudio/avaudiosession/mediaserviceswereresetnotification
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Recreate audio objects and restore session category/options/mode after a media-server restart; do not automatically restart playback until user action.
- **Excerpt:** “Respond … by reinitializing your app’s audio objects … and resetting your audio session’s category, options, and mode configuration.”

### APPLE-SRC-019 — Now Playing metadata and playback interactions
- **Official URL:** https://developer.apple.com/videos/play/wwdc2022/110338/
- **Publication/update date:** 2022-06-10 (WWDC22).
- **Accessed:** 2026-07-09.
- **Exact supported claim:** On the current iOS 26 path, use `MPNowPlayingSession` with AVPlayer where applicable or publish manually through `MPNowPlayingInfoCenter`; manual state must be updated on significant changes, and remote commands remain required.
- **Excerpt:** “Updates to this metadata should be made any time significant changes happen during playback, such as a play or pause, the user scrubs … or a new piece of content begins playing. You do not need to update elapsed time periodically.”

### APPLE-SRC-020 — `MPRemoteCommand`
- **Official URL:** https://developer.apple.com/documentation/mediaplayer/mpremotecommand
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Register handlers on applicable commands from the shared command center; explicitly disable unsupported commands so the system does not present unusable controls.
- **Excerpt:** “Disabling a remote command lets the system know that it shouldn’t display any related UI for that command when your app is the Now Playing app.”

### APPLE-SRC-021 — Remote command center events
- **Official URL:** https://developer.apple.com/documentation/mediaplayer/remote-command-center-events
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** A Now Playing app should provide Now Playing information and register remote-command actions.
- **Excerpt:** “Ensure your app is eligible to become the Now Playing app by adopting best practices for providing Now Playing info and registering for remote command center actions.”

## Accessibility and Liquid Glass

### APPLE-SRC-022 — Accessibility Nutrition Labels overview
- **Official URL:** https://developer.apple.com/help/app-store-connect/manage-app-accessibility/overview-of-accessibility-nutrition-labels/
- **Publication/update date:** Not stated; living App Store Connect Help.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Labels appear on OS 26+ and are voluntary on the audit date; Apple says they will become mandatory later but gives no date. Claims must be evaluated per supported device and common task and remain accurate under Guideline 2.3.
- **Excerpt:** “Providing these labels will be voluntary to start … You’ll be given ample time and evaluation resources before this is mandatory…”

### APPLE-SRC-023 — VoiceOver evaluation criteria
- **Official URL:** https://developer.apple.com/help/app-store-connect/manage-app-accessibility/voiceover-evaluation-criteria/
- **Publication/update date:** Not stated; living App Store Connect Help.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** To claim VoiceOver support, every common task must be navigable and operable using VoiceOver alone, with perceivable labels/descriptions and accessible alternatives for complex gestures.
- **Excerpt:** “Make sure users can complete all of the common tasks of your app using only VoiceOver, without sighted assistance.”

### APPLE-SRC-024 — Larger Text evaluation criteria
- **Official URL:** https://developer.apple.com/help/app-store-connect/manage-app-accessibility/larger-text-evaluation-criteria/
- **Publication/update date:** Not stated; living App Store Connect Help.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** A Larger Text claim requires at least 200% or the platform maximum, without overlap or severe truncation; Dynamic Type is the preferred implementation for most iOS apps.
- **Excerpt:** “You can indicate that your app supports Larger Text if users can enlarge text to at least 200% or the maximum font size for the system.”

### APPLE-SRC-025 — Sufficient Contrast evaluation criteria
- **Official URL:** https://developer.apple.com/help/app-store-connect/manage-app-accessibility/sufficient-contrast-evaluation-criteria/
- **Publication/update date:** Not stated; living App Store Connect Help.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Test light/dark, Increase Contrast, and Reduce Transparency. Apple's page cites 4.5:1 for most text and 3:1 for non-text state distinctions as common minima.
- **Excerpt:** “You may indicate your app supports Sufficient Contrast if … [it] meets general contrast guidelines by default — usually 4.5 to 1 for most text elements.”

### APPLE-SRC-026 — Reduced Motion evaluation criteria
- **Official URL:** https://developer.apple.com/help/app-store-connect/manage-app-accessibility/reduced-motion-evaluation-criteria/
- **Publication/update date:** Not stated; living App Store Connect Help.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Detect the system setting where possible; disable or alter parallax, animated blur/depth, spinning, multi-axis/multi-speed motion, and uncontrolled ongoing motion while preserving semantic transitions with lower-motion alternatives.
- **Excerpt:** “If your app uses depth simulation (including parallax effects, animated blur, and depth-of-field effects), you should disable or change the animation when the user’s setting indicates a need or preference for reduced motion.”

### APPLE-SRC-027 — Touch hit targets
- **Official URL:** https://developer.apple.com/design/tips/
- **Publication/update date:** Not stated; current Apple design guidance.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Interactive controls should provide at least a 44-by-44-point hit target.
- **Excerpt:** “Create controls that measure at least 44 points x 44 points so they can be accurately tapped with a finger.”

### APPLE-SRC-028 — Adopting Liquid Glass
- **Official URL:** https://developer.apple.com/documentation/technologyoverviews/adopting-liquid-glass
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Standard framework controls adopt Liquid Glass automatically; remove interfering custom backgrounds, avoid hard-coded control metrics, use system colors/contrast variants, label icons, and test display/accessibility settings and devices.
- **Excerpt:** “Test your interface with a variety of display and accessibility settings … reduce transparency or motion … Ensure you test your app’s custom elements, colors, and animations…”

### APPLE-SRC-029 — Build a SwiftUI app with the iOS 26 design
- **Official URL:** https://developer.apple.com/videos/play/wwdc2025/323/
- **Publication/update date:** 2025-06-09 (WWDC25).
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Rebuilding with Xcode 26 changes standard app structures, toolbars, controls, search, and sheets; audit each flow and remove unnecessary backgrounds behind sheets/toolbars before adding custom glass.
- **Excerpt:** “The best way to adopt the new design is to use standard app structures, toolbars, search placements, and controls.”

### APPLE-SRC-030 — Build a UIKit app with the iOS 26 design
- **Official URL:** https://developer.apple.com/videos/play/wwdc2025/284/
- **Publication/update date:** 2025-06-09 (WWDC25).
- **Accessed:** 2026-07-09.
- **Exact supported claim:** iOS 26 changes control dimensions and bars; Liquid Glass is an interactive top layer for the most important controls, not a generic blur/material for content.
- **Excerpt:** “Limit Liquid Glass to the most important elements of your app. Where possible, use the system views and controls for the best experience.”

### APPLE-SRC-031 — iOS 26.1 Liquid Glass appearance setting
- **Official URL:** https://support.apple.com/en-us/123075
- **Publication/update date:** Current article published/updated 2026-06-29; iOS 26.1 section describes the change.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Since iOS 26.1, users can choose Clear or Tinted Liquid Glass; Tinted increases material opacity in apps and Lock Screen notifications.
- **Excerpt:** “Liquid Glass setting gives you the option to choose between the default clear look or a new tinted look which increases opacity of the material in apps…”

## Foundation Models and release-significant iOS 26 behavior

### APPLE-SRC-032 — `SystemLanguageModel`
- **Official URL:** https://developer.apple.com/documentation/foundationmodels/systemlanguagemodel
- **Publication/update date:** Not stated; living documentation. DocC availability marks iOS 26.0+.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** `SystemLanguageModel` is the on-device Apple Intelligence text model on iOS 26; Apple updates it in OS updates, and apps must check device/region availability before use. Current docs distinguish model versions for 26.0–26.3, 26.4, and 27.0.
- **Excerpt:** “Apple periodically updates `SystemLanguageModel` in routine OS updates … Before you use the model, you need to verify its availability.”

### APPLE-SRC-033 — Foundation Models generation guidance
- **Official URL:** https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models
- **Publication/update date:** Not stated; living documentation.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Always verify availability and provide fallback; iOS 26's system model has a 4,096-token context window, can take seconds, and complex tasks should be decomposed and measured.
- **Excerpt:** “Always verify model availability first, and plan for a fallback experience in case the model is unavailable.”

### APPLE-SRC-034 — On-device Foundation Models privacy and offline behavior
- **Official URL:** https://developer.apple.com/videos/play/meet-with-apple/205/
- **Publication/update date:** 2025-09-25.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** iOS 26 Foundation Models inference runs locally, can work offline, needs no app API key/account, and must handle device-ineligible, Apple-Intelligence-disabled, and model-not-ready states.
- **Excerpt:** “Because everything runs locally, user data remains private. Your features work entirely offline with no accounts to set up or API keys to manage.”

### APPLE-SRC-035 — Apple Intelligence device, storage, language, and region requirements
- **Official URL:** https://support.apple.com/en-us/121115
- **Publication/update date:** 2026-07-07.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** iPhone support starts at iPhone 15 Pro models and iPhone 16 models or later; Apple Intelligence needs 7 GB of device storage, matching supported device/Siri languages, enabled/downloaded models, and remains region-dependent.
- **Excerpt:** “iPhone 15 Pro models, and iPhone 16 models or later … 7 GB of storage on device … Device language and Siri language set to the same supported language.”

### APPLE-SRC-036 — Deep dive into Foundation Models
- **Official URL:** https://developer.apple.com/videos/play/wwdc2025/301/
- **Publication/update date:** 2025-06-09 (WWDC25).
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Tool calling can expose private local data to app-defined tools; on-device model inference itself preserves locality, but the tool implementation and any web/backend calls remain the app's responsibility.
- **Excerpt:** “Tool calling can let the model call your code to access external data during a request. This can be private information … or even external data from sources on the web.”

### APPLE-SRC-037 — Acceptable-use requirements for Foundation Models
- **Official URL:** https://developer.apple.com/apple-intelligence/acceptable-use-requirements-for-the-foundation-models-framework/
- **Publication/update date:** Not stated; current Apple policy page.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** Apps may not use, prompt, or expose the framework in prohibited ways, including privacy/IP violations, circumvention of guardrails, or high-risk material decisions without human supervision.
- **Excerpt:** “These requirements are for developers that wish to use, prompt, or expose the Foundation Models framework.”

### APPLE-SRC-038 — iOS 26.4 Foundation Models changes
- **Official URL:** https://developer.apple.com/videos/play/wwdc2026/241/
- **Publication/update date:** 2026-06-08 (WWDC26).
- **Accessed:** 2026-07-09.
- **Exact supported claim:** The production iOS 26.4 line added context-size inspection and token-counting APIs and adjusted guardrails to reduce false positives. The remainder of this session's major new capabilities are for the 2027/iOS 27 release and are not current iOS 26 APIs.
- **Excerpt:** “In iOS 26.4, we released new APIs for inspecting the model’s context size and counting the tokens … [and] adjustments in iOS 26.4 to reduce the number of false positives.”

### APPLE-SRC-039 — iOS & iPadOS 26 release notes
- **Official URL:** https://developer.apple.com/documentation/ios-ipados-release-notes/ios-ipados-26-release-notes
- **Publication/update date:** Not stated; release notes for the Xcode 26/iOS 26 SDK.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** iOS 26 introduced Accessibility Nutrition Labels on App Store product pages and the Foundation Models framework; developers must test against SDK-linked behavior changes. No general new iOS 26 exception replaces the audio-session, route, or MediaPlayer guidance above.
- **Excerpt:** “A new Accessibility section has been added to the App Store product pages that highlights accessibility features within apps and games.”

### APPLE-SRC-040 — Apple Developer releases
- **Official URL:** https://developer.apple.com/news/releases/
- **Publication/update date:** Continuously updated; relevant entries dated 2026-06-29 and 2026-07-06.
- **Accessed:** 2026-07-09.
- **Exact supported claim:** The release boundary on the audit date is 26.5.2 stable, 26.6 beta 4, and 27.0 beta 3. Beta behavior must not be represented as a stable current requirement.
- **Excerpt:** “iOS 26.6 beta 4 (23G5057c) — July 6, 2026”; “iOS 26.5.2 (23F84) — June 29, 2026.”

# Explicitly out of current release scope

These official pages are retained only to prevent current Apple documentation from being misapplied to an iOS 26 audit.

### APPLE-OOS-001 — New `NowPlaying` framework is iOS 27 beta only
- **Official URLs:** https://developer.apple.com/documentation/nowplaying/mediasession and https://developer.apple.com/videos/play/wwdc2026/312/
- **Publication/update date:** WWDC session 2026-06-08; DocC is living beta documentation.
- **Accessed:** 2026-07-09.
- **Scope decision:** `MediaSession`, `MediaSessionRepresentable`, and the new `NowPlaying` framework have DocC availability of **iOS 27.0+ beta**. Do not require or propose them for the current iOS 26 release. Continue to audit `MPNowPlayingInfoCenter`, `MPNowPlayingSession`, and `MPRemoteCommandCenter`.
- **Excerpt:** “A local Now Playing session that publishes metadata and commands to the system.”

### APPLE-OOS-002 — Private Cloud Compute and generic model providers are iOS 27 beta only
- **Official URLs:** https://developer.apple.com/documentation/foundationmodels/privatecloudcomputelanguagemodel and https://developer.apple.com/documentation/foundationmodels/languagemodel
- **Publication/update date:** Living beta documentation.
- **Accessed:** 2026-07-09.
- **Scope decision:** DocC availability marks both `PrivateCloudComputeLanguageModel` and the generic `LanguageModel` protocol as **iOS 27.0+ beta**. The iOS 26 audit must not assume PCC, Anthropic/Gemini provider packages, image prompts, dynamic profiles, or the 27 model/context behavior.
- **Excerpt:** PCC is “a variant of Apple Foundation Models that runs on Private Cloud Compute”; this describes the beta API, not an iOS 26 entitlement.

### APPLE-OOS-003 — Xcode 27 / iOS 27 UIKit launch and adaptivity changes
- **Official URL:** https://developer.apple.com/videos/play/wwdc2026/278/
- **Publication/update date:** 2026-06-08 (WWDC26).
- **Accessed:** 2026-07-09.
- **Scope decision:** The `UIScene`-required launch behavior, fully resizable mirrored/iPad iPhone apps, new orientation semantics, and new bar/sidebar APIs are presented in the context of building with the **iOS 27 SDK**. They are prudent future-readiness checks but not current Xcode 26/iOS 26 release blockers.
- **Excerpt:** “Build your app with the iOS 27 SDK …”

## Rejected or qualified candidate claims

1. **“Every iOS 26 app must set deployment target 26.0.” — Rejected.** Apple's upload rule sets the build SDK/toolchain minimum, not the deployment target.
2. **“Every app always needs a privacy manifest.” — Qualified.** A manifest is mandatory when app or SDK code uses required-reason APIs and for Apple's listed SDK cases; an invalid included manifest is itself rejectable. App Store privacy answers and a privacy policy are separate requirements.
3. **“Accessibility Nutrition Labels are already a submission blocker.” — Rejected for 2026-07-09.** Apple still describes them as voluntary initially and gives no mandatory date; published claims must nevertheless be accurate.
4. **“On-device Foundation Models are available on every iOS 26 device.” — Rejected.** Availability depends on Apple Intelligence hardware, region/language, settings, storage/assets, and model readiness.
5. **“Foundation Models means data can never leave the device.” — Rejected as a blanket claim.** On-device inference is local, but app-defined tools, analytics, logs, third-party SDKs, or network fallbacks can transmit prompts, library metadata, or derivatives.
6. **“Use the new `NowPlaying` framework now.” — Rejected for this release.** It is iOS 27 beta; iOS 26 uses MediaPlayer-era Now Playing APIs.
7. **“PCC is a current iOS 26 fallback.” — Rejected.** `PrivateCloudComputeLanguageModel` is iOS 27 beta.
8. **“An iOS 27 beta behavior proves an iOS 26 defect.” — Rejected.** Keep iOS 26.6 and iOS 27 observations as separate forward-compatibility checks.

## Open build/device checks for the parent audit

These are validation targets, not claims of successful testing:

1. Archive with a supported stable Xcode 26 toolchain and verify the archive's SDK, deployment target, embedded manifests, signatures, entitlements, and generated privacy report.
2. Scan app, extensions, packages, and binaries for all five current required-reason categories and map each call site to an approved reason in the owning bundle.
3. Compare the final App Store privacy answers and in-app privacy policy against actual logging, diagnostics, artwork/metadata access, imports, analytics, Foundation Models tools, and third-party SDK behavior.
4. Complete App Store Connect's export questionnaire from the final dependency graph; verify the `ITSAppUsesNonExemptEncryption` value and any compliance code/documentation.
5. On devices, test foreground/background/lock playback; interruption begin/end with and without `.shouldResume`; phone/Siri/alarm interruptions; headphone/Bluetooth/USB connect and disconnect; AirPlay transitions; sample-rate/channel-count changes; media-services reset; and UI/Now Playing synchronization after every transition.
6. Verify Lock Screen, Control Center, accessory, Siri, and CarPlay command paths for play, pause, previous/next, seek/scrub, queue boundaries, failure statuses, metadata changes, elapsed time, artwork, and command enablement.
7. Run all common tasks with VoiceOver, Voice Control, Switch Control as applicable, keyboard access, Dynamic Type through at least 200% and AX5, Bold Text, Increase Contrast, Reduce Transparency, Reduce Motion, Clear/Tinted Liquid Glass, light/dark appearance, and 44-by-44-point hit targets.
8. Exercise Foundation Models on an eligible physical iPhone and an ineligible iOS 26 device, with Apple Intelligence disabled, model assets downloading/not ready, low storage, supported/unsupported locales, airplane mode, guardrail refusal, context overflow, and app-defined tool failures. Confirm a complete deterministic non-model fallback for the offline player.
9. Forward-test on iOS 26.6 beta separately, but do not elevate beta-only behavior to a release finding without reproduction on 26.5.2 or corroborating current documentation.
