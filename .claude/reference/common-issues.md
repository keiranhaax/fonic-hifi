# iOS Health App Development - Common Issues & Solutions

## 🩺 HealthKit Integration Issues

### Permission Sheet Appearing Repeatedly

**Problem:** The HealthKit permission sheet shows up every time the app opens, even after users have granted or denied permissions.

**Causes:**
- iOS bug affecting some users (iOS 14-16)
- Incorrect authorization flow implementation
- Not properly handling authorization state checks

**Solution:**
```swift
class HealthKitManager {
    private let healthStore = HKHealthStore()
    
    func requestHealthKitPermissions() async throws {
        // Check if HealthKit is available
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }
        
        // Define the health data types to read
        let typesToRead: Set<HKObjectType> = [
            HKQuantityType(.heartRate),
            HKQuantityType(.stepCount)
        ]
        
        // Check current authorization status before requesting
        let heartRateStatus = healthStore.authorizationStatus(for: HKQuantityType(.heartRate))
        
        // Only request if not already determined
        if heartRateStatus == .notDetermined {
            try await healthStore.requestAuthorization(toShare: nil, read: typesToRead)
        }
    }
}
```

**Workaround:** Direct users to toggle permissions manually in Settings > Privacy & Security > Health > Your App.

### Authorization Status Always "Not Authorized"

**Problem:** `authorizationStatus(for:)` returns `.notDetermined` or appears as "not authorized" despite user granting permissions.

**Root Cause:** Apple's privacy design - you cannot definitively determine if read permissions were denied.

**Solution:**
```swift
func checkHealthKitAccess() async -> Bool {
    // Instead of relying on authorization status, attempt to read data
    let heartRateType = HKQuantityType(.heartRate)
    
    let query = HKSampleQuery(
        sampleType: heartRateType,
        predicate: nil,
        limit: 1,
        sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
    ) { _, samples, error in
        if let error = error {
            // Handle specific error types
            if error.localizedDescription.contains("Authorization not determined") {
                // Request permissions
            }
        }
        
        // If we get samples or no error, permissions are granted
        let hasPermission = samples != nil || error == nil
    }
    
    healthStore.execute(query)
}
```

### Background Delivery Not Triggering App Launches

**Problem:** `enableBackgroundDelivery(for:frequency:)` doesn't launch the app when new health data is available, especially on iOS 15+.

**Critical Dependencies:**
1. Background App Refresh must be enabled in Settings
2. App must not be force-quit by user
3. iOS power management affects delivery frequency

**Solution:**
```swift
class HealthKitBackgroundManager {
    private let healthStore = HKHealthStore()
    
    func setupBackgroundDelivery() async throws {
        let stepType = HKQuantityType(.stepCount)
        
        // Enable background delivery
        try await healthStore.enableBackgroundDelivery(
            for: stepType,
            frequency: .immediate
        )
        
        // Set up observer query with proper configuration
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] query, completionHandler, error in
            
            // CRITICAL: Call completion handler immediately
            completionHandler()
            
            if let error = error {
                print("Observer query error: \(error)")
                return
            }
            
            // Process new data
            Task {
                await self?.processNewStepData()
            }
        }
        
        healthStore.execute(query)
    }
    
    private func processNewStepData() async {
        // Process in background with time limit
        let bgTask = UIApplication.shared.beginBackgroundTask(withName: "ProcessHealthData") {
            // Handle expiration
        }
        
        defer {
            UIApplication.shared.endBackgroundTask(bgTask)
        }
        
        // Your processing logic here
    }
}
```

**iOS 15+ Workaround:**
```swift
// Set up local notifications as fallback
func scheduleHealthDataReminder() {
    let content = UNMutableNotificationContent()
    content.title = "Check Your Health Data"
    content.body = "Open the app to sync your latest health information"
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true)
    let request = UNNotificationRequest(identifier: "health-sync", content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request)
}
```

### "Protected Health Data Inaccessible" When Device Locked

**Problem:** Health data queries fail when device is locked, even for previously authorized data.

**Solution:**
```swift
func queryHealthDataWithLockHandling() {
    let heartRateType = HKQuantityType(.heartRate)
    
    let query = HKSampleQuery(
        sampleType: heartRateType,
        predicate: nil,
        limit: 100,
        sortDescriptors: nil
    ) { query, samples, error in
        
        if let error = error as NSError? {
            if error.code == HKError.databaseInaccessible.rawValue {
                // Device is locked - schedule retry
                DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                    self.queryHealthDataWithLockHandling()
                }
                return
            }
        }
        
        // Process samples
        self.processSamples(samples)
    }
    
    healthStore.execute(query)
}
```

## 🧠 Performance & Memory Issues

### Retain Cycles with HealthKit Query Completion Handlers

**Problem:** Memory leaks when HealthKit queries retain `self` in completion handlers.

**Solution:**
```swift
class HealthDataManager {
    private let healthStore = HKHealthStore()
    
    func fetchHeartRateData() {
        let heartRateType = HKQuantityType(.heartRate)
        
        let query = HKSampleQuery(
            sampleType: heartRateType,
            predicate: nil,
            limit: 1000,
            sortDescriptors: nil
        ) { [weak self] query, samples, error in  // Use [weak self]
            
            guard let self = self else { return }
            
            if let error = error {
                self.handleError(error)
                return
            }
            
            self.processSamples(samples)
        }
        
        healthStore.execute(query)
    }
}
```

### Memory Spikes When Loading Large Health Datasets

**Problem:** Loading months or years of health data causes memory spikes and app crashes.

**Solution - Paginated Loading:**
```swift
class PaginatedHealthDataLoader {
    private let healthStore = HKHealthStore()
    private let pageSize = 1000
    
    func loadHealthDataInBatches(
        for type: HKQuantityType,
        from startDate: Date,
        to endDate: Date
    ) async throws -> [HKQuantitySample] {
        
        var allSamples: [HKQuantitySample] = []
        var currentDate = startDate
        
        let calendar = Calendar.current
        
        while currentDate < endDate {
            let nextDate = calendar.date(byAdding: .day, value: 7, to: currentDate) ?? endDate
            
            let predicate = HKQuery.predicateForSamples(
                withStart: currentDate,
                end: min(nextDate, endDate),
                options: .strictStartDate
            )
            
            let batchSamples = try await loadBatch(for: type, predicate: predicate)
            allSamples.append(contentsOf: batchSamples)
            
            currentDate = nextDate
            
            // Yield to prevent blocking
            await Task.yield()
        }
        
        return allSamples
    }
    
    private func loadBatch(for type: HKQuantityType, predicate: NSPredicate) async throws -> [HKQuantitySample] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: pageSize,
                sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)]
            ) { _, samples, error in
                
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                continuation.resume(returning: samples as? [HKQuantitySample] ?? [])
            }
            
            healthStore.execute(query)
        }
    }
}
```

### Observer Query Leaks When Views Are Deallocated

**Problem:** HKObserverQuery instances continue running after their owning view controller is deallocated.

**Solution:**
```swift
class HealthObserverManager {
    private let healthStore = HKHealthStore()
    private var activeQueries: [HKQuery] = []
    
    deinit {
        stopAllQueries()
    }
    
    func startObserving(_ type: HKQuantityType) {
        let query = HKObserverQuery(sampleType: type, predicate: nil) { [weak self] query, completion, error in
            completion()
            
            guard let self = self else { return }
            // Handle new data
        }
        
        activeQueries.append(query)
        healthStore.execute(query)
    }
    
    private func stopAllQueries() {
        activeQueries.forEach { healthStore.stop($0) }
        activeQueries.removeAll()
    }
}
```

## ⌚ Apple Watch Connectivity Problems

### Data Sync Delays Between iPhone and Apple Watch

**Problem:** Health data can take minutes or hours to sync between devices.

**Solution - Force Sync:**
```swift
import WatchConnectivity

class WatchHealthSyncManager: NSObject, WCSessionDelegate {
    private let session = WCSession.default
    
    func setupWatchConnectivity() {
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }
    
    func requestWatchHealthDataSync() {
        guard session.isReachable else {
            // Schedule for later when watch is reachable
            scheduleWatchSyncRetry()
            return
        }
        
        let message = ["action": "sync_health_data", "timestamp": Date().timeIntervalSince1970]
        
        session.sendMessage(message, replyHandler: { response in
            print("Watch sync response: \(response)")
        }) { error in
            print("Watch sync error: \(error)")
        }
    }
    
    // WCSessionDelegate methods
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error = error {
            print("Watch session activation error: \(error)")
        }
    }
    
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) {}
}
```

### Background Sync Failures with Apple Watch

**Problem:** Watch workout data doesn't sync when iPhone app is not active.

**Solution - Workout Session Management:**
```swift
import HealthKit
import WatchKit

class WatchWorkoutManager {
    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    
    func startWorkoutSession() throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .running
        configuration.locationType = .outdoor
        
        workoutSession = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        workoutSession?.delegate = self
        
        // Start session and builder
        workoutSession?.startActivity(with: Date())
    }
}

extension WatchWorkoutManager: HKWorkoutSessionDelegate {
    func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
        
        if toState == .ended {
            // Force sync to iPhone
            scheduleHealthDataSync()
        }
    }
    
    func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
        print("Workout session error: \(error)")
    }
    
    private func scheduleHealthDataSync() {
        // Use WKExtension background task
        WKExtension.shared().scheduleBackgroundRefresh(
            withPreferredDate: Date(timeIntervalSinceNow: 30),
            userInfo: ["sync_health": true]
        ) { error in
            if let error = error {
                print("Background refresh scheduling error: \(error)")
            }
        }
    }
}
```

## 🚫 App Store Rejection Issues

### Missing HealthKit UI Integration Indication

**Problem:** App Store rejection: "Your app uses the HealthKit or CareKit APIs but does not indicate integration with the Health app."

**Solution:**
```plist
<!-- Add to Info.plist -->
<key>NSHealthShareUsageDescription</key>
<string>This app reads your health data to provide personalized insights and track your wellness progress.</string>

<key>NSHealthUpdateUsageDescription</key>
<string>This app writes workout and activity data to help you maintain a comprehensive health record.</string>
```

**Additional Requirements:**
- Include Health app screenshots in App Store listing
- Mention Health integration in app description
- Show Health app permission flow in screenshots

### Unnecessary HealthKit Usage Claims

**Problem:** App rejected for claiming HealthKit usage when not actually using health data.

**Solution - Audit HealthKit Usage:**
```swift
// Remove unused HealthKit code and entitlements
// Check these common issues:

// 1. Importing HealthKit but not using it
// import HealthKit  // Remove if unused

// 2. HealthKit entitlement without actual usage
// Remove com.apple.developer.healthkit entitlement if not needed

// 3. Health-related naming without HealthKit integration
// Avoid terms like "health", "medical", "fitness" if not using HealthKit
```

### Third-Party Data Sharing Without Explicit Consent

**Problem:** Sharing health data with third parties without clear user consent.

**Solution - Explicit Consent Flow:**
```swift
class HealthDataSharingManager {
    func requestDataSharingConsent() async -> Bool {
        let alert = UIAlertController(
            title: "Health Data Sharing",
            message: "Do you consent to sharing your anonymized health data with our research partners to improve health insights?",
            preferredStyle: .alert
        )
        
        return await withCheckedContinuation { continuation in
            alert.addAction(UIAlertAction(title: "Allow", style: .default) { _ in
                UserDefaults.standard.set(true, forKey: "health_data_sharing_consent")
                continuation.resume(returning: true)
            })
            
            alert.addAction(UIAlertAction(title: "Don't Allow", style: .cancel) { _ in
                UserDefaults.standard.set(false, forKey: "health_data_sharing_consent")
                continuation.resume(returning: false)
            })
            
            // Present alert
        }
    }
}
```

## 🐛 Common Development Mistakes

### Unit Conversion Errors in HealthKit Data

**Problem:** Incorrect unit handling leads to wrong health data values.

**Common Error:**
```swift
// WRONG - Assuming units without checking
let heartRate = sample.quantity.doubleValue(for: .count())  // Wrong unit!
```

**Solution:**
```swift
func processHeartRateSample(_ sample: HKQuantitySample) -> Double? {
    let heartRateUnit = HKUnit.count().unitDivided(by: .minute())
    
    // Always specify the correct unit
    let heartRateValue = sample.quantity.doubleValue(for: heartRateUnit)
    
    return heartRateValue
}

func processBloodPressureSample(_ sample: HKQuantitySample) -> Double? {
    let mmHgUnit = HKUnit.millimeterOfMercury()
    
    // Ensure we're getting mmHg values
    return sample.quantity.doubleValue(for: mmHgUnit)
}
```

### Time Zone Handling Issues

**Problem:** Health data timestamps show incorrect times due to time zone problems.

**Solution:**
```swift
func formatHealthSampleDate(_ sample: HKSample) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    
    // Use the sample's metadata for time zone if available
    if let timeZone = sample.metadata?[HKMetadataKeyTimeZone] as? String {
        formatter.timeZone = TimeZone(identifier: timeZone)
    } else {
        // Fall back to local time zone
        formatter.timeZone = TimeZone.current
    }
    
    return formatter.string(from: sample.startDate)
}

func queryHealthDataForDate(_ date: Date) {
    let calendar = Calendar.current
    let startOfDay = calendar.startOfDay(for: date)
    let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
    
    // Use local time zone for queries
    let predicate = HKQuery.predicateForSamples(
        withStart: startOfDay,
        end: endOfDay,
        options: .strictStartDate
    )
    
    // Execute query...
}
```

### Main Thread Blocking During Health Data Processing

**Problem:** UI freezes when processing large amounts of health data on the main thread.

**Solution:**
```swift
@MainActor
class HealthDataProcessor: ObservableObject {
    @Published var heartRateData: [HeartRateReading] = []
    @Published var isLoading = false
    
    func loadHeartRateData() async {
        isLoading = true
        defer { isLoading = false }
        
        // Perform heavy work on background
        let readings = await withTaskGroup(of: [HeartRateReading].self) { group in
            var allReadings: [HeartRateReading] = []
            
            let dateRanges = createDateRanges() // Split into smaller ranges
            
            for range in dateRanges {
                group.addTask {
                    await self.fetchHeartRateData(for: range)
                }
            }
            
            for await readings in group {
                allReadings.append(contentsOf: readings)
            }
            
            return allReadings
        }
        
        // Update UI on main thread
        self.heartRateData = readings
    }
    
    private func fetchHeartRateData(for dateRange: DateInterval) async -> [HeartRateReading] {
        // Perform HealthKit query on background
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: HKQuantityType(.heartRate),
                predicate: HKQuery.predicateForSamples(
                    withStart: dateRange.start,
                    end: dateRange.end
                ),
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                let readings = (samples as? [HKQuantitySample])?.compactMap { sample in
                    HeartRateReading(from: sample)
                } ?? []
                
                continuation.resume(returning: readings)
            }
            
            HKHealthStore().execute(query)
        }
    }
}
```

## 🔍 Debugging Strategies

### Real Device Testing Requirements vs Simulator Limitations

**Simulator Limitations:**
- No real HealthKit data (only sample data)
- Cannot test background delivery
- No Apple Watch pairing
- No device lock scenarios
- Limited authorization flows

**Real Device Testing Setup:**
```swift
#if DEBUG
class MockHealthStore: HKHealthStore {
    override func requestAuthorization(toShare typesToShare: Set<HKSampleType>?, read typesToRead: Set<HKObjectType>?) async throws {
        // Mock authorization for simulator testing
        print("Mock: Authorization granted for simulator")
    }
    
    override func execute(_ query: HKQuery) {
        // Provide mock data for simulator
        if let sampleQuery = query as? HKSampleQuery {
            let mockSamples = createMockSamples(for: sampleQuery.sampleType)
            sampleQuery.resultsHandler?(sampleQuery, mockSamples, nil)
        }
    }
}
#endif

class HealthKitManager {
    #if DEBUG
    private let healthStore: HKHealthStore = ProcessInfo.processInfo.environment["SIMULATOR"] != nil ? MockHealthStore() : HKHealthStore()
    #else
    private let healthStore = HKHealthStore()
    #endif
}
```

### HealthKit Debug Logging Patterns

**System Logging:**
```bash
# Terminal command to monitor HealthKit logs
log stream --predicate 'subsystem == "com.apple.healthkit"' --level debug

# Filter for your app specifically
log stream --predicate 'subsystem == "com.apple.healthkit" AND processImagePath CONTAINS "YourApp"'
```

**App-Level Logging:**
```swift
import os.log

class HealthKitLogger {
    private static let subsystem = Bundle.main.bundleIdentifier!
    private static let category = "HealthKit"
    
    static let logger = Logger(subsystem: subsystem, category: category)
    
    static func logQuery(_ query: HKQuery, samples: [HKSample]?) {
        logger.info("HK Query: \(query.description) returned \(samples?.count ?? 0) samples")
    }
    
    static func logError(_ error: Error, context: String) {
        logger.error("HK Error in \(context): \(error.localizedDescription)")
    }
    
    static func logAuthorization(for type: HKObjectType, status: HKAuthorizationStatus) {
        logger.debug("HK Auth for \(type.identifier): \(status.rawValue)")
    }
}
```

### Performance Profiling Techniques

**Memory Profiling:**
```bash
# Use Instruments for memory profiling
instruments -t "Allocations" -D allocations.trace YourApp.app

# Monitor specific health data operations
instruments -t "Time Profiler" -D time_profile.trace YourApp.app
```

**Code-Level Performance Monitoring:**
```swift
class PerformanceMonitor {
    static func measureHealthKitQuery<T>(_ operation: () async throws -> T) async rethrows -> T {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        let result = try await operation()
        
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        HealthKitLogger.logger.info("HK Query took \(timeElapsed) seconds")
        
        // Alert if query takes too long
        if timeElapsed > 5.0 {
            HealthKitLogger.logger.warning("Slow HK query detected: \(timeElapsed)s")
        }
        
        return result
    }
}

// Usage
let samples = await PerformanceMonitor.measureHealthKitQuery {
    try await loadHeartRateData()
}
```

## 🏆 Best Practices Summary

### Essential Patterns
1. **Always check `HKHealthStore.isHealthDataAvailable()`** before any HealthKit operations
2. **Use weak references** in HealthKit completion handlers to prevent retain cycles
3. **Handle device lock state** with proper error handling and retry logic
4. **Test on real devices** - simulator has significant limitations
5. **Paginate large datasets** to prevent memory issues
6. **Implement proper background task handling** for iOS 15+

### Performance Guidelines
- Batch HealthKit queries for better performance
- Use `HKStatisticsQuery` for aggregated data instead of loading all samples
- Cache frequently accessed health data locally
- Monitor memory usage during health data processing
- Use background queues for heavy health data operations

### Privacy & Compliance
- Only request permissions for health data you actually use
- Provide clear, specific usage descriptions
- Handle authorization gracefully (remember: denial looks like no data)
- Implement explicit consent for any third-party data sharing
- Never store HealthKit data in CloudKit or external services

### Community Resources
- [Apple Developer Forums - HealthKit](https://developer.apple.com/forums/tags/healthkit)
- [HealthKit Official Documentation](https://developer.apple.com/documentation/healthkit)
- [WWDC HealthKit Sessions](https://developer.apple.com/videos/healthkit)
- [Stack Overflow HealthKit Questions](https://stackoverflow.com/questions/tagged/healthkit)

---

*Last Updated: July 2025*  
*Sources: Apple Developer Forums, Stack Overflow, GitHub Issues, Real Developer Experiences*