# Branch Recovery Playbook

_Last updated: 2025-09-28_

## 1. Situation Snapshot
- **Backup secured:** `emergency-backup-20250928-212451` (commit `7f41dbd`) contains the full 101-file diff plus the three local commits that were ahead of `origin/main`.
- **Working branch:** `fix-concurrency-issues` rebased on clean `origin/main` (`80ab4e2`). Build now succeeds after restoring the missing `AudioEngineConfiguration` surface.
- **Outstanding issues:**
  - Concurrency violations reappear when reintroducing the `LibraryImportService` changes.
  - Large sets of formatting + functional changes still live only in the backup branch.
  - Feature branches (`001-…`, `002-…`) diverged before the reset and must be reconciled carefully.

## 2. Immediate Priorities
1. **Protect baseline**
   - Keep `emergency-backup-20250928-212451` untouched; use it only for cherry-picking or file checkouts.
   - Work exclusively from `fix-concurrency-issues` until it is green, tested, and ready for PR.
2. **Confirm stability**
   - Run `make build` (already green) and `make test-unit` to document the baseline health before introducing new changes.
3. **Document every step**
   - Append results to `plan2/build-break-notes.md` and update `plan2/next-steps.md` whenever a milestone is hit.

## 3. Incremental Recovery Workflow

### Step 1 – Baseline Verification
- [ ] `make build` (done; keep the log for records).
- [ ] `make test-unit` to ensure integration tests pass on the clean baseline.
- [ ] Commit the configuration restore + documentation once tests are attached (`git commit -m "Restore audio configuration surface"`).

### Step 2 – Reintroduce Concurrency Fixes Safely
- Cherry-pick or checkout only the files related to `LibraryImportService` from the backup branch (`git checkout emergency-backup-... -- <paths>`).
- Refactor the service off `@MainActor`, ensuring background file I/O is isolated and UI updates are marshaled back to the main actor.
- Update dependent view models/environment injections if annotations change.
- Run `make build`, then targeted tests around import flows (if none exist, exercise manual import via simulator).
- Commit with clear messaging (`git commit -m "Refine import service concurrency"`).

### Step 3 – Reapply Functional Changes in Chunks
- Categorize remaining diffs in the backup:
  - Formatting / lint-only updates.
  - Audio engine enhancements (crossfade, replay gain, diagnostics).
  - UI and documentation changes.
- For each category:
  1. `git checkout emergency-backup-... -- <file(s)>`
  2. Run `make build` (quick) and, every few chunks, `make test-unit`.
  3. Stage and commit with scope-specific messages.
- Keep commits small enough to revert individually if needed.

### Step 4 – Integrate Divergent Feature Branches (Optional)
- For each branch (`002-to-implement-this`, etc.):
  - `git checkout <branch>` and `git fetch --all`.
  - `git rebase origin/main` to surface conflicts quickly.
  - Run builds/tests.
  - Merge or cherry-pick into `fix-concurrency-issues` only after the branch works on top of `origin/main`.

### Step 5 – Final Verification and PR Prep
- Ensure working tree is clean on `fix-concurrency-issues`.
- Run `make build`, `make test-unit`, and `make lint`.
- Update `plan2/next-steps.md` with completion notes.
- Push branch (`git push origin fix-concurrency-issues`).
- Draft PR summarizing:
  1. Branch recovery actions.
  2. Concurrency fixes and audio configuration restore.
  3. Test evidence (attach logs or screenshots).

## 4. Risk Mitigations
- Never force-push or reset `emergency-backup-20250928-212451`.
- Avoid merging feature branches directly into `main` until `fix-concurrency-issues` is merged.
- Keep logs (`plan2/build-break-notes.md`) updated so regressions are traceable.
- If new automated tooling rewrites files mid-process, pause and re-verify the backup branch before proceeding.

## 5. Helpful Commands Reference
```bash
# Inspect backup contents without switching branches
git -c core.abbrev=12 log --oneline emergency-backup-20250928-212451

# Compare a file between backup and working branch
git diff fix-concurrency-issues..emergency-backup-20250928-212451 -- <path>

# Selectively restore a file or directory
git checkout emergency-backup-20250928-212451 -- "Fonic HiFi/Presentation/Environment/AudioEnvironment.swift"

# Run focused tests for audio engine
make test-unit TARGET=AudioEngineFacadeSettingsTests
```

Follow this checklist sequentially to avoid regressing the build while recovering the long-lived work.
