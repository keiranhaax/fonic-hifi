# Performance Optimization Targets [UNVERIFIED]

These are optimization targets, not verified measurements. Profile first with `make profile-cpu` and `make profile-memory`.

## Optimization Targets

1. **LibraryImportService**: Batch SwiftData operations
2. **AudioQueueManager**: Preload next track metadata
3. **AudioEngineFacade**: Cache engine instances
4. **TrackDataActor**: Implement pagination for large libraries

## Known Performance Issues

- Engine switching latency spikes on first switch (~100ms)
- SwiftData relationship faulting on large libraries

## Known Memory Issues

- AudioKit DSP chain retains references (workaround: periodic cleanup in facade)

## Profiling Commands

```bash
make profile-cpu      # CPU profiling
make profile-memory   # Memory profiling
make profile-audio    # Audio-specific profiling
```
