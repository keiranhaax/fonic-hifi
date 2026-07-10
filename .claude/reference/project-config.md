# Fonic HiFi Project Configuration Reference

Use the checked-in Xcode project and SwiftPM lockfile as the source of truth. Do
not change signing, capabilities, deployment targets, bundle identifiers, or
dependencies without explicit scope and verification.

## Project and targets

- Project: `Fonic HiFi.xcodeproj`
- App scheme: `Fonic HiFi`
- Targets: `Fonic HiFi`, `Fonic HiFi Widget`, `Fonic HiFiTests`, and
  `Fonic HiFiUITests`
- Deployment target: iOS 26.0 for all four targets
- Swift language mode: Swift 6 with complete strict-concurrency checking
- Supported device family: iPhone

The project uses file-system-synchronized groups. Files added under an existing
target root are normally discovered without editing `project.pbxproj`.

## Dependency

AudioKit is the only SwiftPM dependency. Its exact version and revision are
pinned in:

`Fonic HiFi.xcodeproj/project.xcworkspace/xcshareddata/swiftpm/Package.resolved`

Do not update or resolve it incidentally during unrelated work.

## App configuration

- Source plist: `Fonic HiFi/Info.plist`
- Entitlements: `Fonic HiFi/Fonic_HiFi.entitlements`
- Background mode: audio playback
- Shared App Group: `group.ai.keiranlabs.Fonic-HiFi`
- SwiftData storage is local; CloudKit is disabled in the current data stack.

The app plist currently declares Live Activities and the app entitlements
currently declare the development APNs environment. These are existing project
facts, not approval to alter them; their product/signing disposition is tracked
separately in the remediation ledger.

## Widget configuration

- Source plist: `Fonic HiFi Widget/Info.plist`
- Entitlements: `Fonic HiFi Widget/Fonic_HiFi_Widget.entitlements`
- Extension point: `com.apple.widgetkit-extension`
- Shared App Group: `group.ai.keiranlabs.Fonic-HiFi`

App and widget shared payload types currently exist in both target roots. Keep
their keys and Codable wire format compatible.

## Verification

Use XcodeBuildMCP project discovery before builds. Confirm the main project,
both schemes, an available simulator, and a temporary DerivedData path. The
repository `Makefile` is not authoritative when its selected Xcode or simulator
destination differs from the installed host toolchain.
