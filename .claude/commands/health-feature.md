# Health Feature Development Workflow

Use this command to implement a new health monitoring feature following the established patterns.

## Workflow Steps

### 1. Planning & Architecture
- [ ] Define health metric requirements and HealthKit types needed
- [ ] Design data model with Core Data entity relationships
- [ ] Plan ViewModel architecture with @Published properties
- [ ] Identify required permissions and authorization flow

### 2. Data Layer Implementation
- [ ] Create Core Data model with CloudKit compatibility
- [ ] Implement Repository protocol for health data access
- [ ] Add HealthKit query methods with proper error handling
- [ ] Set up background observer queries for real-time updates

### 3. Domain Layer Implementation
- [ ] Create use cases for data processing and analysis
- [ ] Implement business logic with proper validation
- [ ] Add data transformation and aggregation logic
- [ ] Create health metric calculation algorithms

### 4. Presentation Layer Implementation
- [ ] Create SwiftUI views following design system
- [ ] Implement ViewModel with Combine publishers
- [ ] Add charts and visualizations for health data
- [ ] Implement accessibility features

### 5. Testing Implementation
- [ ] Create mock HealthKit store for unit testing
- [ ] Write unit tests for data processing logic
- [ ] Add integration tests for HealthKit queries
- [ ] Test on real devices with actual health data

### 6. Privacy & Compliance
- [ ] Update privacy descriptions in Info.plist
- [ ] Implement granular permission controls
- [ ] Add data export/deletion functionality
- [ ] Verify compliance with health regulations

## Code Templates

### Repository Pattern
```swift
protocol HealthMetricRepository {
    func fetchLatest() async throws -> [HealthMetric]
    func observeChanges() -> AnyPublisher<[HealthMetric], Error>
    func authorize() async throws
}

class HealthKitMetricRepository: HealthMetricRepository {
    private let healthStore: HKHealthStore
    
    // Implementation
}
```

### ViewModel Pattern
```swift
@MainActor
class HealthMetricViewModel: ObservableObject {
    @Published var metrics: [HealthMetric] = []
    @Published var isLoading = false
    @Published var error: Error?
    
    private let repository: HealthMetricRepository
    
    func loadData() async {
        // Implementation
    }
}
```

### SwiftUI View Pattern
```swift
struct HealthMetricView: View {
    @StateObject private var viewModel: HealthMetricViewModel
    @Environment(\.healthTheme) private var theme
    
    var body: some View {
        // Implementation
    }
}
```