# TODO: Refresh plan3 Documentation To Match Current Codebase

- [x] Update `plan3/issues/p0/02-mpnowplaying-elapsed-time.md` so it acknowledges the existing `changePlaybackPositionCommand` handler and narrows the remaining work to wiring elapsed-time updates inside `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`. ✅ **COMPLETED 2025-09-30**
- [x] Revise or retire `plan3/issues/p0/03-try-removal.md`, since there are no `try!` call sites left; adjust `plan3/scripts/verify-fixes.sh` to avoid false positives from `Entry!` suffixes. ✅ **COMPLETED 2025-09-30**
- [x] Mark `plan3/issues/p0/04-mach-api-guard.md` (and any tracking tables) as complete because `AVAudioEngineAdapter` already wraps Mach APIs with `#if canImport(Mach)`. ✅ **COMPLETED 2025-09-30**

## Implementation Complete (2025-09-30)

All 4 P0 fixes have been successfully implemented:

1. ✅ **P0-1**: LibraryImportService threading - FileImportProcessor actor created, file I/O delegated
2. ✅ **P0-2**: MPNowPlayingInfo elapsed time - Updates every 200ms in progress timer
3. ✅ **P0-3**: try! removal - Already complete, verification script fixed
4. ✅ **P0-4**: Mach API guard - Already complete with `#if canImport(Mach)`

**Verification**: All checks passing via `plan3/scripts/verify-fixes.sh`
