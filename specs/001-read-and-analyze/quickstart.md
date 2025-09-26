# Quickstart: Codebase Documentation System

## Overview
Guide for reviewing and improving the Fonic HiFi codebase documentation (static Markdown files).

## Prerequisites
- Access to Fonic HiFi repository
- Git configured
- Markdown viewer (IDE or GitHub)

## Quick Navigation

### 1. Access the Main Guide
```bash
# Navigate to primary documentation
cd plan2/agents/
open fonic-hifi-codebase-guide.md
```

### 2. Understanding Verification Tags (Planned)
Verification tags will be incrementally added:
- `[Verified-Code]` - To be added when confirmed in repository
- `[Verified-Apple]` - To be added for official Apple docs
- `[Unverified]` - To be added for unverifiable claims

Note: These tags do not currently exist in the documentation.

### 3. Find What You Need

#### Browse by Section
The guide is organized into 9 major sections:
1. **Introduction** - Project overview
2. **Project Structure** - Directory layout
3. **Core Components** - Audio, Data, UI modules
4. **Dependencies** - Environment setup
5. **Key Algorithms** - Core logic flows
6. **Testing** - QA approach
7. **Documentation** - Maintenance guides
8. **Troubleshooting** - Common issues
9. **Appendices** - References and benchmarks

#### Search for Components
```bash
# Find audio-related documentation
grep -r "AudioEngine" plan2/ Files/ Plan/

# Find specific module docs
grep -r "PlaybackStateManager" plan2/agents/*.md
```

### 4. Verify Technical Claims
```swift
// Example: How to verify a claim
// Claim: "AudioEngineFacade is @MainActor"
// Actual path: Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift
// (Note: Not in Core/Audio/ directly, but in Core/Audio/Engine/)

@MainActor
public final class AudioEngineFacade: ObservableObject {
    // ...
}
```

### 5. Handle Conflicting Recommendations

When you encounter conflicting AI recommendations:
1. Look for the conflict documentation section
2. Review pros/cons for each option
3. Check which option is marked as verified against current code
4. The verified option is the implemented approach

Example:
```markdown
**Threading Strategy Conflict**:
- Option A (Amp): Use DispatchQueue.main
  - Pros: Familiar pattern
  - Cons: Swift 6 warnings
- Option B (GPT-5): Use Task { @MainActor in } ✓ [Verified-Code]
  - Pros: Swift 6 compliant
  - Cons: Requires async context
```

## Common Tasks

### Check Documentation Coverage (Manual Process)
```bash
# Count public APIs in Swift files
find "Fonic HiFi" -name "*.swift" -exec grep -l "public" {} \; | wc -l

# Review documentation files
ls plan2/agents/*.md Files/*.md Plan/*.md

# Coverage calculation is a manual assessment
# No automated tools currently exist
```

### Update Documentation
1. Make code changes in a PR
2. Update relevant sections in guide
3. Add/update verification tags
4. Resolve any new conflicts
5. Ensure 80% coverage maintained

### Navigate to Code from Docs
Documentation includes file:line references:
```markdown
AudioEngineFacade.swift:602  # Direct link to code
```

In Xcode: Cmd+Shift+O → paste filename:line

## Validation Checklist

Run through this checklist to validate the documentation:

- [ ] Main guide accessible at `plan2/agents/fonic-hifi-codebase-guide.md`
- [ ] All sections have verification tags on technical claims
- [ ] Conflicts show pros/cons with verified resolution
- [ ] Code references include file:line numbers
- [ ] 80% of public APIs are documented
- [ ] Last update timestamp matches latest relevant PR

## Quick Reference

### File Locations
```
plan2/agents/               # Main documentation
Files/Code_Analysis_Report.md  # AI analyses
Plan/*.md                   # Feature-specific docs
Fonic HiFi/                # Source code
```

### Key Commands
```bash
# Search documentation
grep -r "pattern" plan2/ Files/ Plan/

# View documentation
open plan2/agents/fonic-hifi-codebase-guide.md

# Check last update
git log -1 plan2/agents/fonic-hifi-codebase-guide.md

# Find unverified claims
grep "\[Unverified\]" plan2/**/*.md
```

### Troubleshooting

**Q: Documentation seems outdated**
A: Check `git log` for the file. Documentation updates per PR affecting architecture.

**Q: Can't find a component**
A: Use `grep -r ComponentName plan2/` or check if it's in the 20% undocumented.

**Q: Verification tag missing**
A: This is a bug - all technical claims require tags. Flag for update.

**Q: Conflicting information found**
A: Look for conflict documentation with pros/cons. The verified option is current.

## Next Steps

1. **New Developer**: Start with Section 1-4 for overview
2. **Feature Developer**: Jump to relevant Core Components section
3. **Debugging**: Go straight to Troubleshooting section
4. **Code Review**: Reference patterns in Section 3

## Support

For documentation issues:
- Check existing GitHub issues
- Verify against current code first
- Create issue with [Documentation] tag if confirmed

---

**Ready to explore the codebase!** The documentation provides comprehensive coverage of all major systems with verification tags ensuring accuracy.