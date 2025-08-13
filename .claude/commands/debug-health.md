# Debug Health Issues Workflow

Use this command to systematically debug HealthKit and health data related issues.

## Diagnostic Steps

### 1. HealthKit Availability & Authorization
- [ ] Check `HKHealthStore.isHealthDataAvailable()`
- [ ] Verify authorization status for each health data type
- [ ] Confirm Info.plist has NSHealthShareUsageDescription
- [ ] Test authorization flow on real device

### 2. Device State Verification
- [ ] Check if device is locked (health data inaccessible when locked)
- [ ] Verify iOS version compatibility with used HealthKit features
- [ ] Test on multiple device types (iPhone, Apple Watch)
- [ ] Check background app refresh settings

### 3. Query Debugging
- [ ] Add detailed logging to all HealthKit queries
- [ ] Verify query predicates and date ranges
- [ ] Check query limits and sorting descriptors
- [ ] Test with simplified queries first

### 4. Background Processing
- [ ] Verify BackgroundTasks framework setup
- [ ] Check background modes in Info.plist
- [ ] Test observer query completion handlers
- [ ] Monitor background delivery frequency

### 5. Data Validation
- [ ] Verify Core Data model compatibility
- [ ] Check for data transformation errors
- [ ] Validate health metric calculations
- [ ] Test edge cases (no data, old data)

## Debugging Commands

### Monitor HealthKit Logs
```bash
# Real device logs
log stream --predicate 'subsystem == "com.apple.healthkit"' --level debug

# Simulator logs (limited HealthKit functionality)
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.apple.healthkit"'
```

### Test Authorization
```swift
func debugAuthorization() {
    let types = [HKQuantityType(.heartRate), HKQuantityType(.stepCount)]
    
    for type in types {
        let status = healthStore.authorizationStatus(for: type)
        print("Authorization for \(type): \(status.rawValue)")
    }
}
```

### Test Query Performance
```swift
func debugQueryPerformance() {
    let startTime = CFAbsoluteTimeGetCurrent()
    
    // Your HealthKit query here
    
    let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
    print("Query completed in \(timeElapsed) seconds")
}
```

### Memory Profiling
```bash
# Profile memory usage
instruments -t "Allocations" -D health_memory.trace HalieHeart.app

# Monitor for leaks
instruments -t "Leaks" -D health_leaks.trace HalieHeart.app
```

## Common Issues & Solutions

### "Protected health data is inaccessible"
- **Cause**: Device is locked or health data is disabled
- **Solution**: Check device lock state, handle gracefully in UI

### Background delivery not working
- **Cause**: iOS 15+ reduced background delivery reliability  
- **Solution**: Implement local notifications as fallback

### Slow queries on large datasets
- **Cause**: Querying large date ranges without proper optimization
- **Solution**: Use HKStatisticsQuery for aggregated data, implement pagination

### Memory issues with health data
- **Cause**: Loading too much health data into memory
- **Solution**: Implement batching, use NSFetchedResultsController for large datasets

### Authorization keeps prompting
- **Cause**: Requesting authorization multiple times unnecessarily
- **Solution**: Check authorization status before requesting

## Testing Checklist

### Real Device Testing
- [ ] Test on iPhone (primary testing)
- [ ] Test with Apple Watch paired
- [ ] Test with device locked/unlocked
- [ ] Test with low battery mode
- [ ] Test with restricted health access

### iOS Version Testing
- [ ] Test on iOS 15+ (background changes)
- [ ] Test on iOS 16+ (new HealthKit features)
- [ ] Test on iOS 17+ (latest improvements)

### Edge Case Testing
- [ ] No health data available
- [ ] Very old health data (years ago)
- [ ] Large amounts of health data
- [ ] Corrupted or invalid health data
- [ ] Network connectivity issues