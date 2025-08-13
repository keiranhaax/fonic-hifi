# HealthKit Integration Reference

## Authorization Patterns

### Core Authorization Setup
- **Always check availability first**: `HKHealthStore.isHealthDataAvailable()` before any operations
- **Granular permissions**: Request only needed data types to respect user privacy
- **Authorization states**: `.notDetermined`, `.denied`, `.sharingAuthorized`, `.sharingDenied`

```swift
guard HKHealthStore.isHealthDataAvailable() else {
    // HealthKit not available (iPad, etc.)
    return
}

let healthStore = HKHealthStore()
let readTypes: Set<HKObjectType> = [
    HKQuantityType(.heartRate),
    HKQuantityType(.stepCount),
    HKCategoryType(.sleepAnalysis)
]

// Check current authorization status
let heartRateAuth = healthStore.authorizationStatus(for: HKQuantityType(.heartRate))

// Request authorization
try await healthStore.requestAuthorization(toShare: [], read: readTypes)
```

### iOS 18 Async/Await Authorization
```swift
@MainActor
func requestHealthAuthorization() async throws {
    let readTypes: Set<HKObjectType> = [/* your types */]
    try await healthStore.requestAuthorization(toShare: [], read: readTypes)
}
```

### Background Delivery Setup
```swift
// Enable background delivery for specific types
func enableBackgroundDelivery() async throws {
    try await healthStore.enableBackgroundDelivery(
        for: HKQuantityType(.heartRate),
        frequency: .immediate
    )
}
```

## Supported Health Metrics (30+)

### Heart & Cardiovascular
- `HKQuantityType(.heartRate)` - Heart rate (BPM)
- `HKQuantityType(.heartRateVariabilitySDNN)` - Heart rate variability
- `HKQuantityType(.restingHeartRate)` - Resting heart rate
- `HKQuantityType(.walkingHeartRateAverage)` - Walking heart rate
- `HKQuantityType(.heartRateRecoveryOneMinute)` - Recovery heart rate
- `HKQuantityType(.bloodPressureSystolic)` - Systolic blood pressure
- `HKQuantityType(.bloodPressureDiastolic)` - Diastolic blood pressure

### Sleep & Recovery
- `HKCategoryType(.sleepAnalysis)` - Sleep stages and duration
- `HKQuantityType(.oxygenSaturation)` - Blood oxygen (SpO2)
- `HKCategoryType(.appleStandHour)` - Stand hours

### Activity & Exercise
- `HKQuantityType(.stepCount)` - Daily steps
- `HKQuantityType(.distanceWalkingRunning)` - Walking/running distance
- `HKQuantityType(.flightsClimbed)` - Flights of stairs
- `HKQuantityType(.activeEnergyBurned)` - Active calories
- `HKQuantityType(.basalEnergyBurned)` - Basal calories
- `HKQuantityType(.exerciseTime)` - Exercise minutes
- `HKQuantityType(.appleExerciseTime)` - Apple Watch exercise time

### Body Measurements
- `HKQuantityType(.bodyMass)` - Weight
- `HKQuantityType(.bodyMassIndex)` - BMI
- `HKQuantityType(.bodyFatPercentage)` - Body fat percentage
- `HKQuantityType(.leanBodyMass)` - Lean body mass
- `HKQuantityType(.waistCircumference)` - Waist circumference
- `HKQuantityType(.height)` - Height

### Workout & Fitness
- `HKWorkoutType()` - Workout sessions
- `HKQuantityType(.vo2Max)` - VO2 Max
- `HKQuantityType(.workoutEffortScore)` - Training load (iOS 17+)

### Vitals & Clinical
- `HKQuantityType(.bodyTemperature)` - Body temperature
- `HKQuantityType(.respiratoryRate)` - Respiratory rate
- `HKQuantityType(.bloodGlucose)` - Blood glucose
- `HKCategoryType(.menstrualFlow)` - Menstrual tracking

## Query Patterns

### HKSampleQuery - Individual Samples
```swift
let heartRateType = HKQuantityType(.heartRate)
let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
let limit = 100

let query = HKSampleQuery(
    sampleType: heartRateType,
    predicate: nil,  // or date range predicate
    limit: limit,
    sortDescriptors: [sortDescriptor]
) { query, samples, error in
    guard let samples = samples as? [HKQuantitySample] else { return }
    
    for sample in samples {
        let heartRate = sample.quantity.doubleValue(for: .count().unitDivided(by: .minute()))
        let date = sample.startDate
        // Process heart rate data
    }
}

healthStore.execute(query)
```

### HKStatisticsQuery - Aggregated Data
```swift
let stepsType = HKQuantityType(.stepCount)
let sumOption = HKStatisticsOptions.cumulativeSum
let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)

let query = HKStatisticsQuery(
    quantityType: stepsType,
    quantitySamplePredicate: predicate,
    options: sumOption
) { query, statistics, error in
    guard let sum = statistics?.sumQuantity() else { return }
    let totalSteps = sum.doubleValue(for: .count())
}

healthStore.execute(query)
```

### HKObserverQuery - Real-time Updates
```swift
let heartRateType = HKQuantityType(.heartRate)

let observerQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { query, completionHandler, error in
    // New heart rate data available - perform additional queries
    self.fetchLatestHeartRate()
    completionHandler()
}

healthStore.execute(observerQuery)
```

### Background Delivery Configuration
```swift
func setupBackgroundObserver() async throws {
    let heartRateType = HKQuantityType(.heartRate)
    
    // Enable background delivery
    try await healthStore.enableBackgroundDelivery(
        for: heartRateType,
        frequency: .immediate
    )
    
    // Set up observer query
    let observerQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { query, completionHandler, error in
        Task {
            await self.processNewHeartRateData()
            completionHandler()
        }
    }
    
    healthStore.execute(observerQuery)
}
```

## iOS 18 Updates

### Enhanced Async/Await Support
- All query completion handlers now have async equivalents
- `requestAuthorization` now supports `async throws`
- Background delivery setup with `async enableBackgroundDelivery`

### Performance Improvements
- Optimized query execution for large datasets
- Reduced memory footprint for statistics queries
- Enhanced background processing efficiency

### New Health Metrics (iOS 17-18)
- `HKQuantityType(.workoutEffortScore)` - Training load and effort
- Enhanced sleep analysis with more granular stages
- Improved menstrual health tracking

## Critical Limitations & Restrictions

### Device Lock Restrictions
- **Health data inaccessible when device is locked**
- Must handle `.protectedHealthDataInaccessible` errors gracefully
- Background queries may fail if device has been locked too long

```swift
func handleHealthKitError(_ error: Error) {
    if let hkError = error as? HKError {
        switch hkError.code {
        case .dataUnavailable:
            // Device likely locked - retry later
            scheduleRetry()
        case .userCancelled:
            // User denied authorization
            handleDeniedAccess()
        default:
            break
        }
    }
}
```

### CloudKit Storage Prohibition
- **NEVER store HealthKit data in CloudKit or iCloud**
- Apple explicitly prohibits cloud storage of health data
- Use local Core Data with CloudKit for non-health metadata only

### Background Delivery Reliability
- Background delivery not guaranteed in iOS 15+
- Apps may not receive updates if backgrounded too long
- Implement local notifications as fallback mechanism

```swift
// Fallback for missed background updates
func scheduleHealthDataCheck() {
    let content = UNMutableNotificationContent()
    content.title = "Health Data Update"
    content.body = "Sync your latest health data"
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: true)
    let request = UNNotificationRequest(identifier: "health-sync", content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request)
}
```

### Privacy & Compliance Requirements
- **Data minimization**: Only request necessary health types
- **Granular permissions**: Allow users to deny specific data types
- **Transparency**: Clear privacy labels in App Store Connect
- **HIPAA considerations**: Implement additional safeguards if handling PHI

### Authorization Edge Cases
```swift
func checkAuthorizationStatus() -> Bool {
    let heartRateAuth = healthStore.authorizationStatus(for: HKQuantityType(.heartRate))
    
    switch heartRateAuth {
    case .notDetermined:
        // Need to request authorization
        return false
    case .denied:
        // User explicitly denied - show settings redirect
        return false
    case .sharingAuthorized:
        // Can read data
        return true
    case .sharingDenied:
        // User denied sharing but may have allowed reading
        return true
    @unknown default:
        return false
    }
}
```

## Best Practices

### Error Handling
- Always handle `.dataUnavailable` for locked devices
- Implement retry mechanisms for temporary failures
- Gracefully degrade functionality when permissions denied

### Performance Optimization
- Use `HKStatisticsQuery` instead of `HKSampleQuery` for aggregated data
- Implement date range predicates to limit query scope
- Cache frequently accessed data locally (non-HealthKit storage)

### Testing Requirements
- **Real device testing mandatory** - HealthKit limited on simulator
- Test with actual health data, not mock data
- Verify background delivery on different iOS versions
- Test Apple Watch connectivity scenarios

### Memory Management
- Use weak references in query completion handlers
- Properly stop and deallocate observer queries
- Monitor memory usage during large data processing

This reference provides comprehensive HealthKit integration guidance for iOS health app development, covering authorization, supported metrics, query patterns, iOS 18 updates, and critical limitations to ensure compliant and reliable health data access.