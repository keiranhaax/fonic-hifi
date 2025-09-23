# iOS 26 Project Configuration Reference (Fonic HiFi Audio Player)

## Target Configuration

### Deployment & Language Settings
- **iOS Deployment Target**: 26.0 (minimum - NO backwards compatibility)
- **Swift Language Version**: 6.2 (strict concurrency enabled)
- **Xcode Version**: 26.0+ (required for iOS 26 SDK)
- **Supported Devices**: iPhone, iPad (iOS 26 ONLY)
- **Architecture Support**: arm64 (Apple Silicon)
- **Platform Focus**: iOS exclusively (not cross-platform)

### Build Settings
```yaml
# Debug Configuration
SWIFT_VERSION: 6.0
IPHONEOS_DEPLOYMENT_TARGET: 26.0
SWIFT_STRICT_CONCURRENCY: complete
SWIFT_UPCOMING_FEATURE_FLAGS: BareSlashRegexLiterals,ConciseMagicFile,ForwardTrailingClosures,ImportObjcForwardDeclarations,DisableOutwardActorInference

# Release Configuration  
SWIFT_COMPILATION_MODE: wholemodule
SWIFT_OPTIMIZATION_LEVEL: -O
GCC_OPTIMIZATION_LEVEL: fast
```

## Required Capabilities & Entitlements

### Core Entitlements (Required)
```xml
<!-- Halie_Heart.entitlements -->
<key>com.apple.developer.healthkit</key>
<true/>
<key>com.apple.developer.healthkit.background-delivery</key>
<true/>
<key>com.apple.security.application-groups</key>
<array>
    <string>group.com.yourteam.haliehealth</string>
</array>
```

### Background Processing
```xml
<key>com.apple.developer.background-tasks</key>
<array>
    <string>BGAppRefreshTaskRequest</string>
    <string>BGProcessingTaskRequest</string>
</array>
```

### CloudKit Integration (Non-HealthKit Data Only)
```xml
<key>com.apple.developer.icloud-services</key>
<array>
    <string>CloudKit</string>
</array>
<key>com.apple.developer.icloud-container-identifiers</key>
<array>
    <string>iCloud.com.yourteam.haliehealth</string>
</array>
```

## Essential Dependencies

### Swift Package Manager Dependencies
```yaml
# Package.swift or Xcode SPM
Dependencies:
  - swift-charts: 1.0+ (Apple's native charting)
  - swift-async-algorithms: 1.0+ (async sequence operations)  
  - swift-collections: 1.1+ (performance collections)
  - swift-log: 1.5+ (structured logging)

# Optional Advanced Dependencies
  - swift-composable-architecture: 1.10+ (TCA architecture)
  - swift-snapshot-testing: 1.15+ (snapshot testing)
```

### System Frameworks (Link Binary)
```yaml
Required:
  - HealthKit.framework
  - HealthKitUI.framework (iOS 26+ authorization UI)
  - BackgroundTasks.framework (background processing)
  - UserNotifications.framework (health alerts)
  - CloudKit.framework (user preferences sync)
  - CoreData.framework (local data persistence)
  - Charts.framework (iOS 16+ native charts)
  
Apple Watch Integration:
  - WatchConnectivity.framework
  - WatchKit.framework (watchOS companion)
```

## Privacy & Info.plist Configuration

### Required Privacy Descriptions
```xml
<!-- Info.plist Privacy Keys -->
<key>NSHealthShareUsageDescription</key>
<string>Access health data to provide personalized insights and track your wellness goals</string>

<key>NSHealthUpdateUsageDescription</key>
<string>Store health measurements and workout data to maintain comprehensive health records</string>

<key>NSHealthClinicalHealthRecordsShareUsageDescription</key>
<string>Access clinical records to provide comprehensive health insights (if applicable)</string>

<key>NSUserNotificationsUsageDescription</key>
<string>Send health reminders and important wellness notifications</string>

<key>NSMotionUsageDescription</key>
<string>Track physical activity and movement patterns for fitness insights</string>
```

### Background Modes
```xml
<key>UIBackgroundModes</key>
<array>
    <string>background-app-refresh</string>
    <string>background-processing</string>
    <string>remote-notification</string>
    <string>healthkit</string>
</array>
```

### App Transport Security (if API integration)
```xml
<key>NSAppTransportSecurity</key>
<dict>
    <key>NSAllowsArbitraryLoads</key>
    <false/>
    <key>NSExceptionDomains</key>
    <dict>
        <key>your-health-api.com</key>
        <dict>
            <key>NSExceptionRequiresForwardSecrecy</key>
            <false/>
            <key>NSExceptionMinimumTLSVersion</key>
            <string>TLSv1.2</string>
        </dict>
    </dict>
</dict>
```

## Build Configurations

### Debug Configuration
```yaml
Code Signing:
  - CODE_SIGN_STYLE: Automatic
  - DEVELOPMENT_TEAM: [Your Team ID]
  - CODE_SIGN_IDENTITY: Apple Development

Compiler Flags:
  - DEBUG: 1
  - SWIFT_ACTIVE_COMPILATION_CONDITIONS: DEBUG
  - GCC_PREPROCESSOR_DEFINITIONS: DEBUG=1

Performance:
  - SWIFT_OPTIMIZATION_LEVEL: -Onone
  - GCC_OPTIMIZATION_LEVEL: 0
```

### Release Configuration  
```yaml
Code Signing:
  - CODE_SIGN_STYLE: Manual (recommended for App Store)
  - PROVISIONING_PROFILE_SPECIFIER: [Distribution Profile]
  - CODE_SIGN_IDENTITY: Apple Distribution

Optimization:
  - SWIFT_OPTIMIZATION_LEVEL: -O
  - GCC_OPTIMIZATION_LEVEL: fast
  - SWIFT_COMPILATION_MODE: wholemodule
  - DEAD_CODE_STRIPPING: YES
```

### HealthKit Code Signing Requirements
```yaml
# Provisioning Profile Must Include:
- HealthKit capability enabled
- App Groups capability (for watchOS sync)
- Push Notifications capability
- Background App Refresh capability

# Team Requirements:
- Apple Developer Program membership (paid)
- HealthKit cannot be used with ad-hoc distribution
- App Store or TestFlight distribution required
```

## Project Structure (Clean Architecture)

### Recommended Folder Organization
```
HalieHeart/
├── App/
│   ├── HalieHeartApp.swift           # App entry point
│   ├── AppDelegate.swift             # Background tasks
│   └── SceneDelegate.swift           # Scene lifecycle
├── Core/
│   ├── HealthKit/                    # HealthKit abstractions
│   │   ├── HealthKitManager.swift
│   │   ├── HealthDataType.swift      
│   │   └── BackgroundDelivery.swift
│   ├── Persistence/                  # Core Data stack
│   │   ├── PersistenceController.swift
│   │   ├── Models/                   
│   │   └── Migrations/
│   ├── Network/                      # API layer (if needed)
│   └── Extensions/                   # System extensions
├── Domain/
│   ├── Entities/                     # Health domain models
│   ├── UseCases/                     # Business logic
│   ├── Repositories/                 # Data layer protocols
│   └── Services/                     # Domain services
├── Presentation/
│   ├── Dashboard/                    # Main health dashboard
│   ├── HeartRate/                    # Heart rate features
│   ├── Sleep/                        # Sleep tracking
│   ├── Activity/                     # Activity tracking
│   ├── Shared/                       # Reusable UI components
│   └── Navigation/                   # App navigation
├── Resources/
│   ├── Assets.xcassets/
│   ├── Localizable.strings
│   └── Info.plist
└── Tests/
    ├── UnitTests/
    ├── IntegrationTests/
    └── UITests/
```

### Swift Package Modularization (Advanced)
```yaml
# For large projects, consider local Swift packages:
Packages/
├── HealthKitClient/              # HealthKit abstraction
├── ChartsUI/                     # Custom chart components  
├── CoreDataStack/                # Persistence layer
├── DesignSystem/                 # UI components + theme
└── NetworkClient/                # API networking
```

## Test Target Configuration

### Unit Test Setup
```yaml
# HalieHeartTests.xctest
Target Dependencies:
  - HalieHeart (host application)
  
Framework Dependencies:
  - XCTest.framework
  - @testable import HalieHeart
  
Mock Dependencies:
  - MockHealthStore (HealthKit testing)
  - InMemoryPersistenceController (Core Data)
```

### UI Test Configuration
```yaml  
# HalieHeartUITests.xctest
Target Dependencies:
  - HalieHeart (test host)
  
Test Configuration:
  - UI_TESTING: 1 (preprocessor flag)
  - Test data seeding capability
  - Mock HealthKit permissions for simulator
```

## Specific Configuration Examples

### HealthKit Background Delivery Setup
```swift
// BackgroundTasks.plist registration
<key>BGTaskSchedulerPermittedIdentifiers</key>
<array>
    <string>com.yourteam.haliehealth.healthsync</string>
    <string>com.yourteam.haliehealth.analysis</string>
</array>
```

### Core Data + CloudKit Configuration
```yaml
# .xcdatamodeld Configuration:
- Used with CloudKit: YES (for non-HealthKit data only)
- CodeGen: Category/Extension
- Data Model Inspector:
  - Used with CloudKit: Enable for user preferences
  - Disable for any HealthKit-derived data models
```

### WatchOS Companion Configuration (Optional)
```yaml
# If including Apple Watch app:
Watch App Target:
  - WatchOS Deployment Target: 10.0+
  - Bundle Identifier: com.yourteam.haliehealth.watchkitapp
  - Requires Companion iOS App: YES
  
Watch Extension Target:  
  - WatchKit Extension Bundle Identifier: com.yourteam.haliehealth.watchkitextension
  - Frameworks: HealthKit, WatchConnectivity
```

## Build & Distribution Settings

### App Store Configuration
```yaml
App Store Connect Requirements:
  - App Privacy Labels: Complete health data usage disclosure
  - Age Rating: 4+ or 9+ (depending on features)
  - App Category: Health & Fitness
  - HealthKit Integration: Declare all used data types
  
Export Compliance:
  - Uses Encryption: YES (HealthKit data encryption)
  - Export Compliance Code: Obtain if distributing internationally
```

### TestFlight Configuration  
```yaml
Internal Testing:
  - Max 100 internal testers
  - HealthKit works in TestFlight builds
  - Background delivery limitations may apply
  
External Testing:
  - App Review required for HealthKit apps
  - Privacy descriptions must be complete
  - Real device testing essential
```

## Critical Configuration Notes

### HealthKit Limitations
- **Simulator**: HealthKit data limited/mocked - real device required
- **Background**: iOS 15+ has reduced background delivery reliability  
- **Privacy**: Cannot access health data when device is locked
- **CloudKit**: Never sync HealthKit data to CloudKit (Apple restriction)

### Performance Considerations
- **Memory Target**: <100MB for background processing
- **Query Optimization**: Use HKStatisticsQuery for aggregated data
- **Batch Operations**: Process 1,000-5,000 records per Core Data save
- **Background Tasks**: 30-second execution limit for health updates

### Debugging Configuration
```yaml
# Launch Arguments for Development:
-com.apple.CoreData.SQLDebug 1
-com.apple.CoreData.ConcurrencyDebug 1  
-UIViewControllerHierarchyLogging YES
-AppleHealthKitDebugLogging YES
```

This configuration ensures optimal development experience for iOS health apps with modern Swift 6.0 concurrency, comprehensive HealthKit integration, and App Store compliance.