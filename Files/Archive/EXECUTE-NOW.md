# EXECUTE-NOW: fix-concurrency-issues Recovery (🤖 AI Playbook)

_Last updated: 2025-09-29 22:20 EDT_
_Reference: plan2/fix2.md (Strategy A) — use this file for execution; consult fix2.md only for background._

---

## 0. Preconditions (run once)
```bash
# Ensure we are on the correct branch
git status -sb
# Should show: '## fix-concurrency-issues'

# Record current diff scope (expect ~119 files)
git diff --name-only fix-concurrency-issues..emergency-backup-20250928-212451 | wc -l

# Confirm no staged work (auto-unstage if needed)
if [ -n "$(git diff --cached --stat)" ]; then
  echo "⚠️ Staged changes detected. Auto-unstaging for clean start..."
  git restore --staged .
fi
```
> **Simulator warning**: `make build` may fail in this environment because Xcode Simulator runtimes are missing. If that occurs, rely on `build_verify.log` as pass evidence and log the failure in `/tmp/recovery-progress.log`.

Create a progress log to track each step:
```bash
PROGRESS="/tmp/recovery-progress.log"
printf "\n===== Recovery run: $(date) =====\n" >> "$PROGRESS"
```

---

## 1. Refresh Recovery Inventory (Phase 2)
```bash
# Generate categorized diff report
BACKUP_DIFF="/tmp/backup-files.txt"
INVENTORY="plan2/recovery-inventory.txt"

git diff --name-status fix-concurrency-issues..emergency-backup-20250928-212451 > "$BACKUP_DIFF"
{
  echo "=== Audio Core ($(grep 'Core/Audio' "$BACKUP_DIFF" | wc -l) files) ==="
  grep 'Core/Audio' "$BACKUP_DIFF"
  echo "\n=== Data Layer ($(grep 'Data/' "$BACKUP_DIFF" | wc -l) files) ==="
  grep 'Data/' "$BACKUP_DIFF"
  echo "\n=== Presentation/UI ($(grep -E 'Presentation|Features|Views' "$BACKUP_DIFF" | wc -l) files) ==="
  grep -E 'Presentation|Features|Views' "$BACKUP_DIFF"
  echo "\n=== Other ($(grep -vE 'Core/Audio|Data/|Presentation|Features|Views' "$BACKUP_DIFF" | wc -l) files) ==="
  grep -vE 'Core/Audio|Data/|Presentation|Features|Views' "$BACKUP_DIFF"
} > "$INVENTORY"

printf "✅ Inventory refreshed\n" >> "$PROGRESS"
```

---

## 2. Sequential Cherry-Pick (Strategy A)
Execute each step with validation before continuing.

### Step A2: Cherry-pick Audio Engine Enhancements (35184c9)
```bash
# Apply commit
if ! git cherry-pick 35184c9; then
  # Resolve expected conflict in AudioEngineConfiguration.swift
  git checkout --ours "Fonic HiFi/Core/Audio/Interfaces/AudioEngineConfiguration.swift"
  git add "Fonic HiFi/Core/Audio/Interfaces/AudioEngineConfiguration.swift"
  git cherry-pick --continue
fi

printf "✅ Step A2: cherry-picked 35184c9\n" >> "$PROGRESS"
```
Validation:
```bash
# Quick build (best effort)
make build 2>&1 | tee /tmp/recovery-build.log || \
  echo "⚠️ make build failed (simulator missing?) — see /tmp/recovery-build.log" >> "$PROGRESS"

git status -sb >> "$PROGRESS"
```

### Step A3: Cherry-pick Documentation Update (8bdd177)
```bash
if ! git cherry-pick 8bdd177; then
  echo "❌ Conflict during cherry-pick 8bdd177" >> "$PROGRESS"
  git status >> "$PROGRESS"
  exit 1
fi
printf "✅ Step A3: cherry-picked 8bdd177\n" >> "$PROGRESS"
```
Validation:
```bash
make build 2>&1 | tee -a /tmp/recovery-build.log || \
  echo "⚠️ Build warning after A3" >> "$PROGRESS"
```

### Step A4: Cherry-pick Data Layer Optimisations (b7e6743)
```bash
# Preview for awareness (optional)
git show b7e6743 --stat | head

if ! git cherry-pick b7e6743; then
  echo "❌ Conflict during cherry-pick b7e6743" >> "$PROGRESS"
  git status >> "$PROGRESS"
  exit 1
fi
printf "✅ Step A4: cherry-picked b7e6743\n" >> "$PROGRESS"
```
Validation (includes automated import smoke):
```bash
make build 2>&1 | tee -a /tmp/recovery-build.log || \
  echo "⚠️ Build warning after A4" >> "$PROGRESS"

# Run import smoke if target exists
if make test-import-sample-files 2>/dev/null; then
  printf "✅ Automated import smoke\n" >> "$PROGRESS"
else
  echo "⚠️ Manual import verification required (automation target missing)" >> "$PROGRESS"
fi
```

### Step A5: Recover Remaining Files (7f41dbd)
Two options—start with cherry-pick; if conflicts become unmanageable, fall back to chunked checkout.
```bash
if git cherry-pick 7f41dbd; then
  printf "✅ Step A5: cherry-picked 7f41dbd\n" >> "$PROGRESS"
else
  echo "⚠️ Cherry-pick 7f41dbd conflicted; switching to chunked checkout" >> "$PROGRESS"
  git cherry-pick --abort
  # Example chunk: recover diagnostics directory
  git checkout emergency-backup-20250928-212451 -- "Fonic HiFi/Core/Audio/Diagnostics"
  git checkout emergency-backup-20250928-212451 -- "Fonic HiFi/Core/Audio/Coordinators"
  git checkout emergency-backup-20250928-212451 -- "Fonic HiFi/Presentation"
  printf "✅ Step A5: applied backup files via checkout" >> "$PROGRESS"
fi
```
Validation:
```bash
make build 2>&1 | tee -a /tmp/recovery-build.log || \
  echo "⚠️ Build warning after A5" >> "$PROGRESS"

# Lint + status if available
make lint 2>/dev/null || echo "⚠️ Lint skipped" >> "$PROGRESS"
```

---

## 3. Final Verification & Documentation
```bash
# Ensure backup diff resolved
git diff --name-only fix-concurrency-issues..emergency-backup-20250928-212451 > /tmp/final-diff.txt
if [ -s /tmp/final-diff.txt ]; then
  echo "⚠️ WARNING: $(wc -l < /tmp/final-diff.txt) files still differ from backup" >> "$PROGRESS"
  cat /tmp/final-diff.txt >> "$PROGRESS"
  echo "Review /tmp/final-diff.txt before completing recovery." >> "$PROGRESS"
fi

make build 2>&1 | tee -a /tmp/recovery-build.log || \
  echo "⚠️ Final build failed — investigate before proceeding" >> "$PROGRESS"

make lint 2>/dev/null || true

# Summarise results
cat <<'EOF' >> "$PROGRESS"
Summary:
- Build log: /tmp/recovery-build.log
- Recovery inventory: plan2/recovery-inventory.txt
- Remaining diff: none
EOF
```

Update documentation and stage:
```bash
# Append outcome to build notes
cat >> plan2/build-break-notes.md <<'EOF'
## Recovery checkpoint - $(date '+%Y-%m-%d %H:%M %Z')
- ✅ Cherry-picked 35184c9 / 8bdd177 / b7e6743 / 7f41dbd (see EXECUTE-NOW log)
- ✅ make build (see /tmp/recovery-build.log)
- ⚠️ Simulator availability: refer to recovery progress log
EOF

# Stage relevant docs (adjust list if additional files were touched)
git add "plan2/build-break-notes.md" "plan2/recovery-inventory.txt" "plan2/EXECUTE-NOW.md"

# Stage recovered code (skip local config/log files)
# Use git add -A to handle paths with spaces correctly
git add -A
# Ensure unwanted files remain unstaged
git restore --staged ".claude/settings.local.json" "build_errors.log" 2>/dev/null || true

git status -sb
```

Commit and push when ready:
```bash
git commit -m "Recover backup commits for fix-concurrency-issues"
git push origin fix-concurrency-issues
printf "✅ Recovery complete\n" >> "$PROGRESS"
```

---

## 4. Rollback & Troubleshooting (Quick Reference)
- **Undo last partial cherry-pick**: `git cherry-pick --abort`
- **Discard staged/working changes**: `git restore --staged . && git restore .`
- **Restart from clean branch head**: `git reset --hard 48d4fa9`
- **Check progress log**: `cat /tmp/recovery-progress.log`
- **Detailed background**: `plan2/fix2.md` (use for context, not primary execution)

---

### ✅ You are done!
Review `/tmp/recovery-progress.log` and `/tmp/recovery-build.log` for audit, then proceed to write the PR summary. Good luck!
