# TODO: Refresh plan3 Documentation To Match Current Codebase

- [x] Update `plan3/issues/p0/02-mpnowplaying-elapsed-time.md` so it acknowledges the existing `changePlaybackPositionCommand` handler and narrows the remaining work to wiring elapsed-time updates inside `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`.
- [x] Revise or retire `plan3/issues/p0/03-try-removal.md`, since there are no `try!` call sites left; adjust `plan3/scripts/verify-fixes.sh` to avoid false positives from `Entry!` suffixes.
- [x] Mark `plan3/issues/p0/04-mach-api-guard.md` (and any tracking tables) as complete because `AVAudioEngineAdapter` already wraps Mach APIs with `#if canImport(Mach)`.
