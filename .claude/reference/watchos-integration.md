# watchOS Integration Reference Guide

## Apple Watch Health Sensors Overview

### Heart Rate Monitoring
**Third-Generation Optical Heart Rate Sensor**
- Uses photoplethysmography technology with green LED lights and photodiodes
- Detects blood flow through wrist by measuring light absorption
- Flashes LED hundreds of times per second for accurate measurements
- Supports heart rate range: 30-210 beats per minute
- Provides continuous background monitoring when enabled

**Electrical Heart Rate Sensor (Series 4+)**
- Enables ECG functionality for single-lead electrocardiogram recordings
- 30-second ECG recordings with AFib detection capability
- ECG app version 1: Detects AFib between 50-120 BPM
- ECG app version 2: Detects AFib between 50-150 BPM
- Clinical accuracy: 99.54% sensitivity for automated AF detection, 100% for manual interpretation
- FDA-approved for AFib screening and detection

### Blood Oxygen Restrictions (2024 Update)
**U.S. Sales Restrictions**
- Blood oxygen functionality DISABLED on Apple Watch Series 9, Series 10, and Ultra 2 sold in U.S. after January 18, 2024 (part numbers ending in LW/A)
- Hardware sensor remains present but disabled via software due to Masimo patent dispute
- Feature may return after August 2028 or through settlement/workaround
- Watches sold before restriction date retain full functionality
- International markets unaffected by restriction

### Activity and Environmental Sensors
**Motion and Position Tracking**
- Accelerometer for movement detection and fall detection
- Gyroscope for orientation and rotation tracking
- GPS (cellular models) and GPS + Galileo (GPS models)
- Barometric altimeter for elevation and stair climbing detection
- Digital Crown with haptic feedback for precise navigation

**Advanced Health Features**
- Sleep stage monitoring and sleep apnea detection (Series 10+)
- Vitals app integration for comprehensive health metrics
- Temperature sensing for cycle tracking and health trends
- Crash detection using multiple sensors for emergency response

## WatchKit App Architecture

### Brief Interactions Design Principles
**Glance-Friendly Interface**
- Design for interactions under 10-15 seconds
- Present most important information immediately
- Use complications for quick data access
- Implement progressive disclosure for detailed information
- Optimize for single-handed use with larger touch targets

**Performance Optimization**
- Minimize app launch time to under 2 seconds
- Cache frequently accessed data locally
- Use lazy loading for complex views
- Implement efficient animation and transitions
- Reduce memory footprint through proper resource management

### Background Processing with Extended Runtime Sessions
**HKWorkoutSession for Fitness Tracking**
```swift
// Primary method for extended runtime during workouts
let configuration = HKWorkoutConfiguration()
configuration.activityType = .running
configuration.locationType = .outdoor

let workoutSession = try HKWorkoutSession(
    healthStore: healthStore,
    configuration: configuration
)

// Provides up to 12 hours of extended runtime
// Only one session can run at a time system-wide
```

**Limitations and Considerations**
- Only one HKWorkoutSession allowed per device at any time
- Starting new session terminates existing sessions from other apps
- App Store Review requires legitimate workout/fitness use case
- Interferes with Activity Rings and increases battery drain
- Not recommended for non-fitness background processing

**WKExtendedRuntimeSession Alternative**
```swift
// For non-workout extended runtime needs
let session = WKExtendedRuntimeSession()
session.delegate = self
session.start()

// Limitations:
// - Watch Connectivity disabled when screen off
// - Shorter runtime than HKWorkoutSession
// - System can terminate based on resource constraints
```

### Complication Updates and Background Refresh
**ClockKit Integration**
- Design complications for at-a-glance information
- Implement timeline provider for future data updates
- Use background app refresh budget efficiently
- Update complications through timeline entries, not real-time data
- Follow privacy guidelines for sensitive health data display

## Data Synchronization Strategies

### Watch Connectivity Framework
**WCSession Setup and Management**
```swift
// Essential setup pattern
if WCSession.isSupported() {
    let session = WCSession.default
    session.delegate = self
    session.activate()
}

// Always check reachability before interactive messaging
guard session.isReachable else {
    // Use background transfer methods instead
    return
}
```

**Application Context vs User Info vs Interactive Messaging**

**Application Context** - Most Recent State Only
```swift
// Use for latest app state that can be overwritten
try session.updateApplicationContext([
    "currentHeartRate": heartRateValue,
    "timestamp": Date.now.timeIntervalSince1970
])

// Pros: Lightweight, always current data
// Cons: Only stores most recent update
// Best for: Current health readings, app state
```

**User Info Transfers** - Queued Background Delivery
```swift
// Use for important data that must be delivered
session.transferUserInfo([
    "workoutData": workoutSummary,
    "healthMetrics": dailyMetrics
])

// Pros: Guaranteed delivery, queued transfers
// Cons: Slower delivery, no real-time guarantee
// Best for: Workout summaries, historical data
```

**Interactive Messaging** - Real-Time Communication
```swift
// Use for immediate bi-directional communication
session.sendMessage(
    ["requestType": "currentLocation"],
    replyHandler: { response in
        // Handle immediate response
    },
    errorHandler: { error in
        // Fallback to background transfer
    }
)

// Pros: Immediate delivery and response
// Cons: Requires both apps active and reachable
// Best for: User-initiated actions, real-time sync
```

### CoreData + CloudKit Limitations on watchOS
**Critical Performance Issues (2024)**
- Sync only reliable when watch on charger with >50% battery
- Initial sync can take hours for large datasets (>10k entities)
- Background tasks terminate after 30 seconds, interrupting sync
- watchOS 10 shows significant sync regression vs previous versions
- System resource management prioritizes battery life over sync performance

**Data Volume Recommendations**
- Keep watch-specific data under 1,000 entities for reliable sync
- Separate watch data from full iPhone dataset
- Use selective sync for essential data only
- Consider hybrid sync strategies for large datasets

### Hybrid Sync Strategies
**WatchConnectivity + CloudKit Backup Pattern**
```swift
// Primary: Watch Connectivity for immediate sync
func syncCriticalData() {
    if WCSession.default.isReachable {
        // Real-time sync via Watch Connectivity
        sendViaWatchConnectivity(data)
    } else {
        // Queue for CloudKit background sync
        queueForCloudKitSync(data)
    }
}

// Secondary: CloudKit for comprehensive backup
func backgroundCloudKitSync() {
    // Sync during charging periods only
    guard isCharging && batteryLevel > 0.5 else { return }
    
    // Batch operations for efficiency
    performBatchCloudKitOperation()
}
```

**Selective Data Strategy**
- Watch: Last 7 days of health data + current readings
- iPhone: Complete historical data + cloud backup
- Sync essential data via Watch Connectivity
- Use CloudKit for comprehensive backup during charging

## Battery Optimization

### Apple's Optimized Battery Charging
**System-Level Optimization**
- Learns daily charging habits to extend battery lifespan
- Determines optimal charge limit vs full charge based on usage patterns
- Available on Apple Watch SE, Series 6+, and Ultra models with watchOS 10+
- Automatically manages charging during extended charging periods

### Low Power Mode Impact on Health Monitoring
**Disabled Features in Low Power Mode**
- Always-on display turns off
- Background heart rate monitoring disabled
- Blood oxygen readings stopped (Series 6+)
- Irregular rhythm notifications paused
- Cellular and Wi-Fi connections limited
- Background app refresh restricted

**Battery Life Extension**
- Standard models: 18 hours → 36 hours (100% increase)
- Apple Watch Ultra 2: 36 hours → 72 hours (100% increase)
- Essential functionality preserved: time, alarms, emergency features

### Sensor Management Strategies
**Intelligent Monitoring Approach**
```swift
// Adaptive sampling based on battery level
func configureHealthMonitoring() {
    let batteryLevel = WKInterfaceDevice.current().batteryLevel
    
    switch batteryLevel {
    case 0.7...1.0:
        // Full monitoring: every 5 minutes
        enableContinuousMonitoring()
    case 0.3..<0.7:
        // Reduced monitoring: every 15 minutes
        enableReducedMonitoring()
    case 0.0..<0.3:
        // Critical mode: user-initiated only
        enableOnDemandMonitoring()
    default:
        break
    }
}
```

**Background Processing Efficiency**
- Use BackgroundTasks framework for scheduled operations
- Batch data processing during charging periods
- Implement energy-efficient algorithms for data analysis
- Minimize unnecessary sensor access and network requests

## Performance Considerations

### Memory Constraints on watchOS
**Physical Limitations**
- Apple Watch has significantly less RAM than iPhone
- S-series chips optimized for efficiency over raw performance
- Limited storage space for local data caching
- System aggressively manages memory for battery preservation

**Development Guidelines**
```swift
// Efficient memory usage patterns
class HealthDataCache {
    // Use lazy loading for expensive operations
    private lazy var processedData = computeExpensiveMetrics()
    
    // Implement memory pressure handling
    func didReceiveMemoryWarning() {
        clearNonEssentialCache()
        releaseHeavyResources()
    }
    
    // Use weak references for delegates
    weak var delegate: HealthDataDelegate?
}
```

### CloudKit Sync Performance Issues
**2024 Known Issues**
- Large datasets (>10k entities) require hours for initial sync
- Sync reliability depends on charging state and battery level >50%
- Background sync tasks terminated after 30 seconds
- watchOS 10 shows significant performance regression

**Mitigation Strategies**
- Migrate to single watchOS app architecture (vs extension)
- Implement incremental sync with smaller batches
- Use Watch Connectivity for immediate sync needs
- Reserve CloudKit for comprehensive backup during charging

### Data Volume Limitations
**Recommended Thresholds**
- **Optimal**: <1,000 entities for smooth sync performance
- **Acceptable**: 1,000-5,000 entities with longer sync times
- **Problematic**: >10,000 entities requiring specialized handling
- **Critical**: >100,000 entities (like 12-hour workout with GPS) need hybrid approach

## Implementation Patterns

### Proper Session Delegate Implementation
```swift
class WatchConnectivityManager: NSObject, WCSessionDelegate {
    static let shared = WatchConnectivityManager()
    private let session = WCSession.default
    
    override init() {
        super.init()
        
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    // MARK: - WCSessionDelegate
    func session(
        _ session: WCSession,
        activationDidCompleteWith activationState: WCSessionActivationState,
        error: Error?
    ) {
        switch activationState {
        case .activated:
            print("Watch Connectivity activated")
        case .inactive:
            print("Watch Connectivity inactive")
        case .notActivated:
            print("Watch Connectivity not activated")
            handleActivationFailure(error)
        @unknown default:
            print("Unknown activation state")
        }
    }
    
    func session(
        _ session: WCSession,
        didReceiveMessage message: [String: Any],
        replyHandler: @escaping ([String: Any]) -> Void
    ) {
        // Handle interactive messages
        processIncomingMessage(message, replyHandler: replyHandler)
    }
    
    func session(
        _ session: WCSession,
        didReceiveUserInfo userInfo: [String: Any]
    ) {
        // Handle background user info transfers
        processUserInfo(userInfo)
    }
    
    #if os(iOS)
    func sessionDidBecomeInactive(_ session: WCSession) {
        // iOS only - handle watch disconnection
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        // iOS only - prepare for new watch pairing
        session.activate()
    }
    #endif
}
```

### Error Handling for Sync Failures
```swift
enum SyncError: Error {
    case watchConnectivityUnavailable
    case cloudKitQuotaExceeded
    case backgroundTaskExpired
    case batteryTooLow
    case deviceNotCharging
}

func handleSyncFailure(_ error: SyncError) {
    switch error {
    case .watchConnectivityUnavailable:
        // Queue for CloudKit background sync
        scheduleCloudKitBackup()
        
    case .cloudKitQuotaExceeded:
        // Implement data cleanup strategy
        cleanupOldHealthData()
        
    case .backgroundTaskExpired:
        // Resume during next charging session
        scheduleChargingSync()
        
    case .batteryTooLow, .deviceNotCharging:
        // Wait for optimal sync conditions
        waitForOptimalSyncConditions()
    }
}
```

### Offline Data Storage Strategies
```swift
protocol HealthDataStorage {
    func store(_ data: HealthData) async throws
    func retrieve(for dateRange: DateInterval) async throws -> [HealthData]
    func syncPendingData() async throws
}

class WatchHealthDataStorage: HealthDataStorage {
    private let container: NSPersistentContainer
    private let syncQueue = DispatchQueue(label: "health.sync", qos: .utility)
    
    func store(_ data: HealthData) async throws {
        // Store locally first
        try await storeLocally(data)
        
        // Attempt immediate sync if possible
        if canSyncImmediately() {
            try await syncToiPhone(data)
        } else {
            // Queue for later sync
            try await queueForSync(data)
        }
    }
    
    private func canSyncImmediately() -> Bool {
        return WCSession.default.isReachable ||
               (isCharging && batteryLevel > 0.5)
    }
}
```

### Real-Time Health Data Display
```swift
@MainActor
class HealthDashboardViewModel: ObservableObject {
    @Published var currentHeartRate: Int = 0
    @Published var isConnected: Bool = false
    
    private let healthStore = HKHealthStore()
    private let connectivityManager = WatchConnectivityManager.shared
    
    func startRealTimeMonitoring() {
        guard HKHealthStore.isHealthDataAvailable() else {
            handleHealthDataUnavailable()
            return
        }
        
        // Set up real-time heart rate query
        let heartRateType = HKQuantityType(.heartRate)
        let query = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] _, _, error in
            Task { @MainActor in
                self?.handleHeartRateUpdate()
            }
        }
        
        healthStore.execute(query)
    }
    
    private func handleHeartRateUpdate() {
        // Update UI with latest heart rate
        fetchLatestHeartRate { [weak self] heartRate in
            Task { @MainActor in
                self?.currentHeartRate = heartRate
            }
        }
    }
}
```

## Best Practices Summary

### Development Workflow
1. **Always Test on Real Device**: Health sensors unavailable in simulator
2. **Handle All Authorization States**: Check HKHealthStore availability first
3. **Implement Graceful Degradation**: App should function without all permissions
4. **Optimize for Battery Life**: Use adaptive monitoring based on battery level
5. **Design for Brief Interactions**: Optimize for 10-15 second usage sessions

### Data Management
1. **Use Hybrid Sync Strategy**: Watch Connectivity + CloudKit backup
2. **Implement Selective Sync**: Essential data only on watch
3. **Batch CloudKit Operations**: During charging periods with >50% battery
4. **Handle Sync Failures Gracefully**: Multiple fallback strategies
5. **Respect Privacy**: Minimal data collection, user control over sharing

### Performance Optimization
1. **Memory Management**: Use weak references, implement memory pressure handling
2. **Background Processing**: Efficient use of extended runtime sessions
3. **Data Caching**: Local storage for frequently accessed health metrics
4. **Network Efficiency**: Minimize unnecessary sync operations
5. **Battery Awareness**: Adaptive functionality based on power state

This comprehensive guide provides the foundation for building robust, efficient, and user-friendly health monitoring features in your watchOS companion app for Halie Heart.