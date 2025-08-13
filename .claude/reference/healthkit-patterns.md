# HealthKit Patterns Reference

## Authorization Patterns

### Complete Authorization Flow
```swift
func requestHealthKitAuthorization() async throws {
    guard HKHealthStore.isHealthDataAvailable() else {
        throw HealthKitError.notAvailable
    }
    
    let readTypes = Set(HealthMetricType.allCases.map { $0.sampleType })
    try await healthStore.requestAuthorization(toShare: [], read: readTypes)
}

func checkAuthorizationStatus(for type: HKQuantityType) -> HKAuthorizationStatus {
    return healthStore.authorizationStatus(for: type)
}
```

### Background Observer Pattern
```swift
func setupBackgroundObserver() {
    let heartRateType = HKQuantityType(.heartRate)
    let observerQuery = HKObserverQuery(sampleType: heartRateType, predicate: nil) { [weak self] query, completionHandler, error in
        DispatchQueue.main.async {
            self?.handleBackgroundUpdate()
        }
        completionHandler()
    }
    healthStore.execute(observerQuery)
    healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
        // Handle background delivery setup
    }
}
```

## Query Strategies

### Statistics Query for Aggregated Data
```swift
func fetchWeeklyHeartRateStatistics() async throws -> HKStatistics? {
    let heartRateType = HKQuantityType(.heartRate)
    let calendar = Calendar.current
    let endDate = Date()
    let startDate = calendar.date(byAdding: .day, value: -7, to: endDate)!
    
    let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
    
    return try await withCheckedThrowingContinuation { continuation in
        let query = HKStatisticsQuery(quantityType: heartRateType,
                                    quantitySamplePredicate: predicate,
                                    options: [.discreteAverage, .discreteMin, .discreteMax]) { _, statistics, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                continuation.resume(returning: statistics)
            }
        }
        healthStore.execute(query)
    }
}
```

### Anchored Object Query for Incremental Updates
```swift
func fetchIncrementalHeartRateData(from anchor: HKQueryAnchor?) async throws -> (samples: [HKQuantitySample], newAnchor: HKQueryAnchor) {
    let heartRateType = HKQuantityType(.heartRate)
    
    return try await withCheckedThrowingContinuation { continuation in
        let query = HKAnchoredObjectQuery(type: heartRateType,
                                        predicate: nil,
                                        anchor: anchor,
                                        limit: HKObjectQueryNoLimit) { _, samples, deletedObjects, newAnchor, error in
            if let error = error {
                continuation.resume(throwing: error)
            } else {
                let heartRateSamples = samples?.compactMap { $0 as? HKQuantitySample } ?? []
                continuation.resume(returning: (heartRateSamples, newAnchor ?? HKQueryAnchor(fromValue: 0)))
            }
        }
        healthStore.execute(query)
    }
}
```

## Error Handling Patterns

### Comprehensive Error Handling
```swift
enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case notAuthorized
    case dataUnavailable
    case queryFailed(Error)
    case deviceLocked
    
    var errorDescription: String? {
        switch self {
        case .notAvailable:
            return "HealthKit is not available on this device"
        case .notAuthorized:
            return "HealthKit access not authorized"
        case .dataUnavailable:
            return "Health data is currently unavailable"
        case .queryFailed(let error):
            return "HealthKit query failed: \(error.localizedDescription)"
        case .deviceLocked:
            return "Health data is inaccessible while device is locked"
        }
    }
}

func handleHealthKitError(_ error: Error) {
    if let hkError = error as? HKError {
        switch hkError.code {
        case .errorHealthDataUnavailable:
            // Handle device lock or data unavailability
            break
        case .errorNotAuthorized:
            // Prompt user to grant permissions
            break
        default:
            // Handle other HealthKit errors
            break
        }
    }
}
```

## Testing Patterns

### Mock HealthKit Store
```swift
protocol HealthStoreProtocol {
    func requestAuthorization(toShare: Set<HKSampleType>?, read: Set<HKObjectType>?) async throws
    func execute(_ query: HKQuery)
}

class MockHealthKitStore: HealthStoreProtocol {
    var mockSamples: [HKSample] = []
    var authorizationStatus: HKAuthorizationStatus = .notDetermined
    
    func requestAuthorization(toShare: Set<HKSampleType>?, read: Set<HKObjectType>?) async throws {
        authorizationStatus = .sharingAuthorized
    }
    
    func execute(_ query: HKQuery) {
        if let sampleQuery = query as? HKSampleQuery {
            sampleQuery.resultsHandler?(query, mockSamples, nil)
        }
    }
}
```

### Unit Test Example
```swift
func testHeartRateAnalysis() async throws {
    let mockStore = MockHealthKitStore()
    let analyzer = HeartRateAnalyzer(store: mockStore)
    
    // Setup mock data
    let heartRateValue = HKQuantity(unit: HKUnit.count().unitDivided(by: .minute()), doubleValue: 72.0)
    let heartRateSample = HKQuantitySample(type: HKQuantityType(.heartRate),
                                         quantity: heartRateValue,
                                         start: Date().addingTimeInterval(-3600),
                                         end: Date())
    mockStore.mockSamples = [heartRateSample]
    
    let result = try await analyzer.analyzeLastWeek()
    XCTAssertEqual(result.average, 72.0, accuracy: 0.1)
}
```