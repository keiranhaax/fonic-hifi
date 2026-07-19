# CP-02 — Configuration, security, privacy-manifest, and CI phase

- Recorded: 2026-07-11
- Baseline report-level claims covered: 7
- Canonical root causes provisionally established: 3
- Source changes: none
- Sub-agent concurrency: one completed run; no overlap

## Provisional dispositions pending final lead pass

1. PCFG-001 and PSR-001 describe one public credential-exposure root cause. Merge the duplicate report records and downgrade the canonical severity from Critical to High because four non-placeholder credential-shaped values are confirmed in tracked public files, but current validity, privilege, scope, revocation, billing impact, and protected data were deliberately not tested.
2. PCFG-002 and PSR-002 describe one missing first-party Required Reason API manifest root cause. Merge the duplicate report records and downgrade the canonical severity from Critical to High. Active app and widget paths use covered APIs, both are separate executables, no source PrivacyInfo.xcprivacy exists, and Apple states undeclared covered API use is rejected by App Store Connect. This is a confirmed distribution blocker, not demonstrated code execution, disclosure, or irreversible user harm.
3. PCFG-003, PSR-003, and TRV-001 describe one CI toolchain-selection root cause. Merge the duplicate report records and retain High. The workflow selects Xcode 16.1, the Makefile exports /Applications/Xcode.app, the current macos-15 image maps that alias to Xcode 16.4, and the repository requires iOS 26. A public CI run for the exact audited SHA failed at build and skipped tests and coverage.

## Lead validation and corrections

- Independently parsed the known local-tool JSON files without emitting raw values. Confirmed four non-placeholder credential records and one sensitive non-public address in tracked paths. No authentication attempt was made.
- Confirmed direct app and widget App Group UserDefaults use, direct app standard UserDefaults use, file-timestamp access, system-uptime access, separate app/extension executable targets, and no repository PrivacyInfo.xcprivacy file.
- Confirmed the active import path copies a selected file into the app container before metadata extraction. Therefore the earlier proposed 3B52.1 reason is not established by that import path and must not be carried forward automatically.
- Confirmed the workflow and Makefile conflict and current runner image aliases from the live GitHub runner-image inventory.
- Confirmed GitHub Actions run 28900146035 is for the audited SHA, concluded failure, failed at Build project, and skipped tests and coverage.
- Qualified one sub-agent statement: the CI annotations show iOS 26 deployment-target warnings under an iOS 18.5-capable toolchain, but the terminal build failure annotation also cites a missing app icon set. The toolchain defect remains independently confirmed; the build failure is not attributed solely to the toolchain.

## Runtime boundary

Credential liveness, App Store Connect upload behavior, generated privacy reports, archive contents, Xcode compilation, simulator behavior, and physical-device behavior remain UNVERIFIED.
