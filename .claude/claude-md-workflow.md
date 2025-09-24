# Development Workflow

## Initial Setup
1. Create Xcode project: iOS 18+, Swift 6, SwiftUI lifecycle
2. Configure build settings: strict concurrency, recommended warnings
3. Set up directory structure as per architecture
4. Add package dependencies: AudioKit (required), TagLib (optional future metadata tooling)
5. Initialize SwiftLint for code consistency
6. Create .gitignore for Swift/iOS

## Development Flow

### Feature Development
1. **Explore**: Read existing code, understand dependencies
2. **Plan**: Think through implementation, edge cases
3. **Code**: Implement incrementally, test as you go
4. **Commit**: Clear commit messages, reference issues

### Adding New Features
- Start with domain models and use cases
- Implement repository interfaces
- Create data layer implementation
- Build ViewModels with business logic
- Design SwiftUI views last
- Add comprehensive tests

### Code Review Checklist
- [ ] Follows MVVM architecture
- [ ] Proper error handling
- [ ] Memory leaks checked
- [ ] Accessibility implemented
- [ ] Performance profiled
- [ ] Tests written

## Common Tasks

### Adding Audio Format Support
1. Create decoder in `/Core/Audio/AudioFormats/`
2. Update `AudioEngineService` selection logic
3. Add format badge in UI components
4. Update supported formats documentation
5. Test with sample files
6. Profile performance impact

### Implementing New View
1. Create SwiftUI view file
2. Create corresponding ViewModel
3. Define @Published properties
4. Implement data loading
5. Handle loading/error states
6. Add accessibility labels
7. Test with Dynamic Type

### Database Schema Changes
1. Update SwiftData models
2. Implement migration logic
3. Test with existing data
4. Update repositories
5. Verify performance
6. Document changes

### Performance Optimization
1. Profile with Instruments
2. Identify bottlenecks
3. Implement caching
4. Add background processing
5. Measure improvement
6. Test battery impact

## Testing Workflow

### Unit Testing
```bash
# Run all tests
xcodebuild test -scheme FonicHiFi

# Run specific test class
xcodebuild test -scheme FonicHiFi -only-testing:FonicHiFiTests/LibraryTests

# Generate coverage report
xcodebuild test -scheme FonicHiFi -enableCodeCoverage YES
```

### Manual Testing
- Import various format files
- Test with 10k+ track library
- Verify bit-perfect output
- Check memory usage
- Test all gestures
- Verify accessibility

### Performance Testing
- Use Time Profiler for CPU
- Use Allocations for memory
- Test scrolling at 60fps
- Measure app launch time
- Profile battery usage
- Check thermal state

## Debugging Tips

### Audio Issues
- Enable audio session logging
- Check format compatibility
- Verify buffer sizes
- Monitor hardware changes
- Log decoder selection
- Test with external DAC

### Database Issues
- Enable SwiftData logging
- Check migration logs
- Verify indexes
- Profile query performance
- Monitor memory usage
- Test concurrent access

### UI Performance
- Enable Core Animation debugging
- Check view hierarchy
- Profile main thread
- Identify redundant updates
- Optimize image loading
- Test on older devices

## Build & Distribution

### Debug Builds
```bash
xcodebuild -scheme FonicHiFi -configuration Debug
```

### Release Builds
```bash
xcodebuild -scheme FonicHiFi -configuration Release
xcodebuild archive -scheme FonicHiFi -archivePath FonicHiFi.xcarchive
```

### TestFlight Preparation
1. Increment build number
2. Update release notes
3. Run full test suite
4. Profile release build
5. Create archive
6. Upload to App Store Connect

## Troubleshooting

### Common Issues
- **Audio not playing**: Check audio session category
- **Metadata not saving**: Verify file permissions
- **Slow library scan**: Check indexing, batch size
- **Memory warnings**: Review image caching
- **Crashes**: Check concurrency, force unwraps

### Debug Commands
```bash
# Clean build folder
xcodebuild clean -scheme FonicHiFi

# Reset simulator
xcrun simctl erase all

# View device logs
xcrun simctl spawn booted log stream --predicate 'subsystem == "com.fonicHiFi"'
```

## Git Workflow

### Branch Strategy
- `main`: Stable releases only
- `develop`: Integration branch
- `feature/*`: New features
- `bugfix/*`: Bug fixes
- `release/*`: Release preparation

### Commit Messages
```
feat: Add FLAC decoder support
fix: Resolve memory leak in waveform generation
docs: Update API documentation
test: Add unit tests for playlist service
perf: Optimize library scanning
refactor: Extract audio engine interface
```

## Continuous Improvement
- Weekly performance profiling
- Monthly accessibility audit
- Regular dependency updates
- User feedback integration
- Code coverage > 80%
- Documentation updates