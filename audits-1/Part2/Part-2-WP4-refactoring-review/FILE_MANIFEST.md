# Part 2 Work Package 4 file manifest

- Archive: `Part-2-WP4-refactoring-review.zip`
- Repository commit reviewed: `459db9bfd18d17960e8fd2ff8defc4701085532e`
- Scope: new Work Package 4 continuation deliverables only
- Repository source changes included: none

| File | Why included | Bytes | Lines | SHA-256 |
|---|---|---:|---:|---|
| `CONTINUATION_MANIFEST.md` | Durable continuation record of completed and remaining steps, inspected and changed files, commands, and limitations. | 9678 | 173 | `c03b7e430b15ac4af2b6619b1149cd488da512fd89e1289b7a3a0981d3c00147` |
| `checkpoints/01_BASELINE_CHECKPOINT.md` | Baseline checkpoint for the supplied archive, exact repository revision, environment, and initial scope lock. | 3420 | 72 | `528cb68b9d87e6a38ca4e9335e6e0cf32223737b387aa32e2990ea303a5f768d` |
| `checkpoints/02_DELEGATION_CHECKPOINT.md` | Records the single narrow sub-agent attempt and why no delegated claim was accepted. | 1158 | 24 | `8e1c3fde9b59cbd2bbd720fc74203b797f57251d69db5446f11f6e15ea04cdc7` |
| `checkpoints/03_CANDIDATE_MAPPING_CHECKPOINT.md` | Durable checkpoint after evidence-backed candidate mapping and rejection/defer decisions. | 2790 | 58 | `d42601e43463c2e7d8d30c623b7f998e787ca0e2be778a05de10276448b5f489` |
| `checkpoints/04_REPORT_AND_PLAN_CHECKPOINT.md` | Checkpoint after opportunity ranking and completion of the report, findings record, and phased plan. | 1559 | 50 | `344b77d6c3f9c9feea45ff11ee56c81be52c5d8abef8465501d3c8b70edbc972` |
| `checkpoints/05_VERIFICATION_CHECKPOINT.md` | Records successful static checks and unavailable Apple/Xcode checks without overstating results. | 1187 | 38 | `2956ac86fca32c08a948df2a0e4558c2c2f45c5a4b1e1ce5e24e83d9fb1f6295` |
| `checkpoints/06_PREPACKAGE_CHECKPOINT.md` | Prepackage scope, result counts, cleanliness, and archive-exclusion checkpoint. | 1156 | 27 | `37f2af62c5eff2af574b9460a95aa7525fed516d1eaa18bc48481d500aadad8f` |
| `evidence/01_SWIFT_MECHANICAL_INVENTORY.csv` | Mechanical metrics for all 325 Swift files used only to generate candidates, not as finding proof by itself. | 25939 | 326 | `e9195c6d420d406be8ba5d53751e32499db6b238f6cc942d3e1a9e3c3b073125` |
| `evidence/02_SYMBOL_REFERENCE_COUNTS.csv` | Reference counts and file lists for the main candidate ownership boundaries. | 7318 | 19 | `eb18b57ad2e78d2bcb2f3d06459e0ec10254e7cbcfe553bc6f06aa8576e88040` |
| `evidence/03_WIDGET_CONTRACT_COMPARISON.md` | Exact hashes and unified diffs proving three app/widget contract pairs are body-identical. | 1937 | 72 | `4c13f8b220ff68341c39ed9da87f8da1b0febbffaa2fb810722b3b2daef7ceb7` |
| `evidence/04_SOURCE_EVIDENCE_INDEX.md` | File/line excerpts, active call paths, test boundaries, official sources, and rejected-candidate evidence. | 18862 | 424 | `36d17123dafc1d229aed7f87c5908c226dc62fc94c04966aa400e51fa39d2fa3` |
| `evidence/05_CANDIDATE_MAP.md` | Prioritized retained, rejected, and deferred candidate map. | 4400 | 34 | `e116ea5436d87412ade22aa5f9e4dd269eabf23454508dc90c5be88f58de03f6` |
| `evidence/06_STATIC_VERIFICATION.json` | Machine-readable result of 23 targeted static evidence checks. | 3242 | 122 | `377202bd91989dc1f7b3d427d4546d6629ed6400b5cf123a461e987d50e2b162` |
| `evidence/07_VERIFICATION_COMMANDS.md` | Commands actually run, results, unavailable checks, and claims boundary. | 2983 | 91 | `7937ea14b0c59115a0685b0e65108dad07eefb2507ae71bc076217e4d37f30b4` |
| `plans/01_PHASED_REFACTORING_PLAN.md` | Agent-ready implementation order, exact boundaries, preserve/do-not-touch guardrails, tests, and rollback guidance. | 18820 | 383 | `76eff348a82d96e91a56fcfcd6db7abddd5d0bcc3c67d5bd14a8fd05c0b183b1` |
| `reports/01_WORK_PACKAGE_4_REFACTORING_REVIEW.md` | Standalone Work Package 4 report with eight retained opportunities and six rejected/deferred candidates. | 30717 | 686 | `8f144ec2e70a9daf168352957a85107eb1d6b860d1ac7c8cbac492f3ba93dbfa` |
| `reports/02_REFACTORING_FINDINGS.json` | Structured refactoring findings and disposition record for machine or agent consumption. | 14378 | 359 | `942207a47852a78e64bc01ba59fe78da8f1b4cbbc06daf66514ce2334ab49377` |
| `FILE_MANIFEST.md` | Lists every file in this ZIP, why it is included, and integrity metadata. | self | self | self-referential |

## Explicit exclusions

- Full repository and all unchanged source files
- Supplied checkpoint ZIP and its extracted contents
- Previously delivered reports
- Build products, caches, DerivedData, dependency checkouts, and work scripts
- Minimal source changes, because none were needed or authorized
