# Required-Reason API Inventory

Verified against Apple's `NSPrivacyAccessedAPIType` documentation on 2026-07-11. This inventory covers direct production-source use in the app and widget targets; test, sample, archived, and audit sources are not shipped.

Apple references:

- [Privacy manifest files](https://developer.apple.com/documentation/bundleresources/privacy-manifest-files)
- [Required-reason API categories and approved reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitype)

## Fonic HiFi app target

| Category | Approved reason | Direct call sites | Execution path and justification |
| --- | --- | --- | --- |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `CA92.1` | `FonicHiFiApp.init`; `Metrics.enabled`; `DataManager.backfillAlbumArtistRelationshipsIfNeeded`; `QueueState` persistence; `AudioEngineFacade` preference/monitoring; `AudioEngineFactory`; `AudioPlaybackSettingsStore`; `AudioMonitorReporter` | Reads and writes preferences, migration flags, queue state, and diagnostics settings that are private to the app. |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `1C8F.1` | `Shared/WidgetConstants.UserDefaults.appGroup`; `WidgetTrackInfo`; `WidgetPlaybackState`; `AppGroupManager` | Shares Now Playing, queue, and artwork state only with the Fonic widget through the configured App Group. |
| `NSPrivacyAccessedAPICategoryFileTimestamp` | `C617.1` | `FileManagerView.loadDirectoryContents`; `MetadataExtractionService.extractTrackMetadata`; `Track.init`; `RecentSearchMigrationPlan.V1.Track.init` | Reads modification/creation metadata for files already copied into the app container, including the app Documents browser and migration snapshots. Imported source files are copied before metadata extraction. |
| `NSPrivacyAccessedAPICategorySystemBootTime` | `35F9.1` | `SystemMetricsCollector` sampling, interval, and timestamp methods | Uses `ProcessInfo.systemUptime` only for elapsed in-app diagnostic intervals and bounded sample timestamps; the value is not sent off-device. |

No direct app-target use was found for the covered Disk Space or Active Keyboards categories. The current import discovery path does not read timestamps from document-picker URLs before copying, so reason `3B52.1` is not currently applicable.

## Fonic HiFi Widget target

| Category | Approved reason | Direct call sites | Execution path and justification |
| --- | --- | --- | --- |
| `NSPrivacyAccessedAPICategoryUserDefaults` | `1C8F.1` | `Shared/WidgetConstants.UserDefaults.appGroup`; `WidgetTrackInfo`; `WidgetPlaybackState` | Reads app-published playback and queue payloads from the Fonic App Group to render widget timelines and intents. |

No direct widget-target use was found for File Timestamp, System Boot Time, Disk Space, or Active Keyboards.

Adjacent metadata matches were reviewed: `WidgetArtworkCache` and `Track` read `.fileSizeKey`, `FileImportProcessor` reads `.isRegularFileKey`, and `AudioFormatDetectionManager` reads `.size`. Those keys are not APIs in Apple's current File Timestamp or Disk Space lists; the timestamp reads alongside them remain mapped above.

## Verification probes

Run both probes whenever production APIs or target membership changes:

```sh
rg -n --glob '*.{swift,m,mm,c,cc,cpp,h,hpp}' 'UserDefaults|NSUserDefaults|creationDate|modificationDate|fileModificationDate|contentModificationDateKey|creationDateKey|systemUptime|mach_absolute_time|volumeAvailableCapacity|volumeTotalCapacity|systemFreeSize|systemSize|statfs\(|statvfs\(|fstatfs\(|fstatvfs\(|activeInputModes' 'Fonic HiFi' 'Fonic HiFi Widget'

rg -n --glob '*.{swift,m,mm,c,cc,cpp,h,hpp}' 'NSPrivacyAccessedAPI|PrivacyInfo\.xcprivacy|suiteName:|attributesOfItem|resourceValues\(forKeys:' 'Fonic HiFi' 'Fonic HiFi Widget'
```

Each match must map to a target, category, execution path, and approved reason above before the manifests are changed. Dependency-owned use must be checked separately in Xcode's generated privacy report because it is not represented by these source-root probes.
