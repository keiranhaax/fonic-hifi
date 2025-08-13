# Swift Patterns Reference - iOS Health App Development

## Architecture Patterns

### MVVM with SwiftUI
- Use `@StateObject` for ViewModels to ensure single instance per view
- Apply `@MainActor` to ViewModels for UI thread safety
- Implement `@Published` properties for reactive UI updates

```swift
@MainActor
class HealthDashboardViewModel: ObservableObject {
    @Published var heartRateData: [HeartRateReading] = []
    @Published var isLoading = false
    
    private let healthRepository: HealthRepositoryProtocol
    
    init(healthRepository: HealthRepositoryProtocol) {
        self.healthRepository = healthRepository
    }
    
    func loadHealthData() async {
        isLoading = true
        defer { isLoading = false }
        
        do {
            heartRateData = try await healthRepository.fetchHeartRateData()
        } catch {
            // Handle error
        }
    }
}
```

### Clean Architecture Layers
- **Presentation**: SwiftUI Views + ViewModels
- **Domain**: Business logic, use cases, entities
- **Data**: Repository implementations, HealthKit integration

### Repository Pattern
```swift
protocol HealthRepositoryProtocol {
    func fetchHeartRateData() async throws -> [HeartRateReading]
}

class HealthRepository: HealthRepositoryProtocol {
    private let healthKitManager: HealthKitManager
    
    func fetchHeartRateData() async throws -> [HeartRateReading] {
        return try await healthKitManager.queryHeartRate()
    }
}
```

### Coordinator Pattern
```swift
class AppCoordinator: ObservableObject {
    @Published var currentScreen: Screen = .dashboard
    
    enum Screen {
        case dashboard, heartRate, sleep, settings
    }
    
    func navigate(to screen: Screen) {
        currentScreen = screen
    }
}
```

## Modern Swift Patterns

### Async/Await HealthKit Operations
```swift
actor HealthKitManager {
    private let healthStore = HKHealthStore()
    
    func queryHeartRate() async throws -> [HeartRateReading] {
        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: HKQuantityType(.heartRate), 
                                    predicate: nil, limit: 100,
                                    sortDescriptors: []) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    let readings = samples?.compactMap { /* transform */ } ?? []
                    continuation.resume(returning: readings)
                }
            }
            healthStore.execute(query)
        }
    }
}
```

### TaskGroup for Parallel Queries
```swift
func fetchAllHealthData() async throws -> HealthDashboardData {
    return try await withThrowingTaskGroup(of: Any.self) { group in
        group.addTask { try await healthKitManager.queryHeartRate() }
        group.addTask { try await healthKitManager.querySleepData() }
        group.addTask { try await healthKitManager.queryStepCount() }
        
        var heartRate: [HeartRateReading] = []
        var sleepData: [SleepReading] = []
        var stepCount: [StepReading] = []
        
        for try await result in group {
            // Process results
        }
        
        return HealthDashboardData(heartRate: heartRate, sleep: sleepData, steps: stepCount)
    }
}
```

### Combine Integration
```swift
class HealthDataService: ObservableObject {
    @Published var latestHeartRate: Double = 0
    private var cancellables = Set<AnyCancellable>()
    
    func startMonitoring() {
        Timer.publish(every: 30, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                Task {
                    await self.updateHeartRate()
                }
            }
            .store(in: &cancellables)
    }
}
```

## Dependency Injection

### Environment-Based DI
```swift
struct ContentView: View {
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var healthRepository = HealthRepository()
    
    var body: some View {
        NavigationView {
            // Views
        }
        .environmentObject(coordinator)
        .environmentObject(healthRepository)
    }
}
```

## Key Implementation Guidelines

- Always check `HKHealthStore.isHealthDataAvailable()` before HealthKit operations
- Use `@MainActor` for UI-bound classes and methods
- Implement proper error handling with `Result<T, Error>` types
- Apply actor isolation for thread-safe health data processing
- Use weak references in HealthKit completion handlers to prevent retain cycles
- Implement background task handling for iOS 15+ health data updates