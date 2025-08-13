# iOS Health App Coding Standards

## Swift 6.0 Standards

### Modern Concurrency
- Use `async/await` for all asynchronous operations
- Apply `@MainActor` for UI-bound ViewModels and Views
- Implement `actor` isolation for thread-safe health data access
- Use `TaskGroup` for concurrent HealthKit queries
- Replace completion handlers with async functions

```swift
@MainActor
class HealthDashboardViewModel: ObservableObject {
    @Published var heartRate: Double = 0
    
    func fetchLatestHeartRate() async throws {
        let rate = try await healthService.getLatestHeartRate()
        self.heartRate = rate
    }
}
```

### Strict Concurrency Checking
- Enable strict concurrency checking in project settings
- Use `Sendable` protocol for data types passed between actors
- Apply `@unchecked Sendable` only when absolutely necessary
- Isolate mutable state with actors or @MainActor

## Naming Conventions

### Classes and Structs
- **Services**: `HealthDataRepository`, `SleepAnalysisService`, `HeartRateMonitor`
- **ViewModels**: `DashboardViewModel`, `HeartRateDetailViewModel`
- **Views**: `HealthDashboardView`, `SleepChartView`, `ActivityRingsView`
- **Models**: `HealthMetric`, `SleepSession`, `WorkoutSummary`

### Protocols
- **Data Providing**: `HealthDataProviding`, `ChartDataSource`, `MetricCalculating`
- **Delegate**: `HealthDataDelegate`, `WorkoutSessionDelegate`
- **Repository**: `HealthRepositoryProtocol`, `CoreDataManaging`

### Variables and Methods
- **Boolean**: `isHealthDataAvailable`, `hasPermission`, `canFetchData`
- **Collections**: `heartRateValues`, `sleepSessions`, `workoutHistory`
- **Methods**: `fetchHealthData()`, `processHeartRateVariability()`, `calculateSleepEfficiency()`
- **Async Methods**: `loadHealthMetrics()`, `synchronizeWithHealthKit()`

## Code Organization

### File Structure
- Group related functionality in feature folders
- Separate Views, ViewModels, and Services
- Place protocols in dedicated Protocol files
- Use Extensions for functionality organization

### Guard Statements
- Use guard for early returns and error handling
- Place guard statements at function start for validation
- Prefer guard over nested if-else chains

```swift
func processHealthData(_ samples: [HKSample]) throws -> [HealthMetric] {
    guard !samples.isEmpty else {
        throw HealthError.noDataAvailable
    }
    
    guard samples.allSatisfy({ $0.sampleType == .heartRate }) else {
        throw HealthError.invalidSampleType
    }
    
    return samples.compactMap { convertToHealthMetric($0) }
}
```

### Extensions
- Organize functionality by feature in extensions
- Separate computed properties, methods, and protocol conformance
- Use MARK comments for section organization

```swift
// MARK: - HealthKit Integration
extension HealthDataRepository {
    func requestHealthKitAuthorization() async throws { ... }
}

// MARK: - Data Processing
extension HealthDataRepository {
    func processHeartRateData(_ samples: [HKSample]) -> [HeartRateReading] { ... }
}
```

## Health App Specific Standards

### HealthKit Error Handling
- Always check `HKHealthStore.isHealthDataAvailable()` first
- Handle device lock state explicitly
- Implement comprehensive error types for health operations
- Use Result type for async health operations

```swift
enum HealthKitError: Error {
    case healthDataUnavailable
    case authorizationDenied
    case deviceLocked
    case dataProcessingFailed(String)
}

func fetchHeartRateData() async -> Result<[HeartRateReading], HealthKitError> {
    guard HKHealthStore.isHealthDataAvailable() else {
        return .failure(.healthDataUnavailable)
    }
    // Implementation...
}
```

### Privacy-Compliant Patterns
- Check authorization status before data access
- Handle authorization gracefully with user-friendly messages
- Implement granular permission requests
- Never assume permissions are granted

### Memory Management
- Use weak references in HealthKit completion handlers
- Implement proper cleanup in deinit for observers
- Batch Core Data operations for large datasets
- Monitor memory usage during background processing

```swift
class HealthDataObserver {
    private weak var delegate: HealthDataDelegate?
    
    deinit {
        healthStore.stop(heartRateQuery)
    }
}
```

### Background Processing
- Use BackgroundTasks framework for iOS 15+
- Implement observer queries with proper lifecycle management
- Handle background app refresh settings
- Design for unreliable background delivery

## SwiftLint Configuration

### Enabled Rules
- `line_length`: 120 characters maximum
- `function_body_length`: 50 lines maximum
- `type_body_length`: 300 lines maximum
- `cyclomatic_complexity`: 10 maximum
- `force_unwrapping`: Disabled (use safe unwrapping)
- `implicitly_unwrapped_optional`: Warning level

### Custom Rules
- Require explicit access control for all declarations
- Enforce `final` keyword for non-inheritable classes
- Mandate documentation for public APIs
- Require `// swiftlint:disable rule_name` justification comments

## Documentation Standards

### Public API Documentation
- Use /// for public methods and properties
- Include parameter descriptions and return values
- Document throws behavior and error types
- Provide usage examples for complex methods

```swift
/// Fetches the latest heart rate data from HealthKit
/// - Parameters:
///   - startDate: The start date for data retrieval
///   - endDate: The end date for data retrieval
/// - Returns: Array of heart rate readings
/// - Throws: HealthKitError if data cannot be accessed
func fetchHeartRateData(from startDate: Date, to endDate: Date) async throws -> [HeartRateReading] {
    // Implementation...
}
```

### Code Comments
- Use `// MARK:` for logical section separation
- Add `// TODO:` for future improvements
- Use `// FIXME:` for known issues requiring attention
- Explain complex algorithms and health calculations

## Performance Guidelines

### HealthKit Queries
- Use `HKStatisticsQuery` for aggregated data
- Implement proper predicate filtering to reduce data transfer
- Cache frequently accessed health metrics locally
- Use compound Core Data indexes for 25% query improvement

### Memory Optimization
- Target < 100MB memory usage during background processing
- Implement lazy loading for large health datasets
- Use `NSFetchedResultsController` for efficient UI updates
- Batch save operations every 1,000-5,000 records