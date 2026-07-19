# Git Branch Recovery SOP

## When to Create Emergency Backups

- Build failing with complex multi-file changes
- Major refactoring spans multiple sessions
- Before risky git operations (rebase, filter-branch, reset --hard)
- After manual file restoration from previous commits

## Naming Convention

```bash
git branch emergency-backup-YYYYMMDD-HHMMSS
```

## Recovery Strategy: Sequential Cherry-Pick (RECOMMENDED)

1. **Preserve backup branch:** Never force-push or modify backup branches
2. **Work from clean branch:** Ensure working tree is clean before starting recovery
3. **Commit staged changes first:** Always commit any staged work before cherry-picking
4. **Cherry-pick sequentially:** Process commits one at a time with build verification
5. **Handle conflicts:** Use `--ours` for files already manually restored
6. **Document progress:** Update STATUS.md after each phase

## High-Risk Commits (Require Extra Caution)

- Threading changes: Any commit modifying `@MainActor` annotations (verify with manual testing)
- Data layer changes: DataManager, SwiftData models, actors (test import/export)
- Large formatting commits: 50+ files (consider splitting before applying)

## Rollback Procedures

```bash
git reset --soft HEAD^  # Undo last commit (keep changes)
git reset --hard HEAD^  # Undo last commit (discard changes)
git revert COMMIT_SHA   # Revert specific commit
```
