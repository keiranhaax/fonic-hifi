# Foundation Models Instructions

These instructions extend the repository root guide for `Core/AI/`.

## Trust Boundaries

- Keep Foundation Models on-device. Do not add cloud inference, network enrichment, telemetry, or uploads of queries, library metadata, lyrics, listening history, prompts, or files.
- Every user-visible AI path must retain a deterministic non-AI fallback that leaves normal search, library access, and playback usable.
- Treat search queries, titles, artists, genres, lyrics, and listening history as untrusted data, never as role instructions. Keep system instructions separate from user and library context.
- Model output is untrusted data. It must not directly mutate SwiftData, delete files, change settings, install software, or execute playback commands.

## Session and Output Rules

- Check `SystemLanguageModel.default.availability` immediately before model-dependent work and handle every unavailable and generation-failure path.
- A `LanguageModelSession` accepts one request at a time. Serialize access or create an independent session per request; do not overlap work on a shared session.
- Preserve cancellation and do not publish or apply late output after the requesting task is cancelled or superseded.
- Validate generated identifiers against the supplied candidate set, reject out-of-set values, deduplicate, enforce result limits, and re-fetch authoritative tracks before playback or persistence.

## Verification

- Verify new iOS or Foundation Models API claims against current Apple documentation or the repository's iOS research skill; do not rely on model memory for post-cutoff APIs.
- Tests must cover unavailable fallback, generation failure, malformed and duplicate output, out-of-set identifiers, limits, authoritative re-fetching, and cancellation.
- Simulator success does not verify Apple Intelligence availability or performance. Validate supported behavior on eligible hardware before making device-support claims.
