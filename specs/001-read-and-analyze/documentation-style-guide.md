# Documentation Style Guide for Fonic HiFi

## Purpose
This guide ensures consistency and quality across all Fonic HiFi documentation.

## General Principles

### 1. Accuracy First
- Every technical claim must be verifiable
- Use verification tags on all statements
- Update documentation within same PR as code changes
- Remove outdated information immediately

### 2. Clarity Over Completeness
- Write for developers new to the codebase
- Explain "why" before "how"
- Use examples for complex concepts
- Keep paragraphs short (3-4 sentences max)

### 3. Practical Focus
- Include actionable information
- Provide copy-paste code examples
- Link to actual file locations
- Include troubleshooting for common issues

## Verification Tag Standards

### Required Tags
Every technical statement must have one of:
- `[Verified-Code]` - Verified in codebase
- `[Verified-Apple]` - From official Apple docs
- `[Unverified]` - Cannot be verified

### Tag Placement
```markdown
Good: The facade uses @MainActor [Verified-Code: AudioEngineFacade.swift:19]
Bad: The facade uses @MainActor. [Verified-Code]
```

### File References
Always include file and line number when possible:
```markdown
Correct: [Verified-Code: FileName.swift:123]
Acceptable: [Verified-Code: FileName.swift]
Minimal: [Verified-Code]
```

## Component Documentation Template

### For Classes/Structs
```markdown
**ComponentName** (`Path/To/Component.swift`) [Verified-Code: Line X]
- **Purpose**: One-line description of what it does
- **Key Responsibilities**:
  - Responsibility 1
  - Responsibility 2
- **Dependencies**: List of required components
- **Thread Safety**: Actor isolation or threading notes
- **Usage Example**: (if applicable)
```

### For Protocols
```markdown
**ProtocolName** (`Path/To/Protocol.swift`) [Verified-Code]
- **Purpose**: What implementations must provide
- **Required Methods**: Key method signatures
- **Conforming Types**: List of implementations
- **Usage Context**: When to use this protocol
```

## Code Examples

### Do's
```markdown
// Good: Shows actual pattern from codebase
Task { @MainActor in
    self?.updateUI()  // AVAudioEngineAdapter.swift:184
}
```

### Don'ts
```markdown
// Bad: Generic example without context
doSomething()
```

## File Path Conventions

### Always Use Full Paths
```markdown
Correct: `Fonic HiFi/Core/Audio/Engine/AudioEngineFacade.swift`
Wrong: `AudioEngineFacade.swift`
Wrong: `Core/Audio/AudioEngineFacade.swift` (missing Engine/)
```

### Directory Structure
When documenting structure, show hierarchy clearly:
```
Fonic HiFi/
├── Core/
│   └── Audio/
│       ├── Engine/       # Main facade
│       ├── Engines/      # Adapters
│       └── Factory/      # Creation logic
```

## Troubleshooting Sections

### Format
```markdown
**Problem Category**

*Symptom*: What the user sees
- **Cause**: Root cause [Verification]
- **Solution**: How to fix it
- **Code Fix**: Specific file/line to check
- **Verification**: How to confirm fix worked
```

### Example
```markdown
*Symptom*: Audio stops after backgrounding
- **Cause**: Missing background mode [Verified-Code]
- **Solution**: Add `audio` to UIBackgroundModes
- **Code Fix**: Info.plist, line 45
- **Verification**: Check Settings > General > Background App Refresh
```

## Conflict Documentation

When documenting conflicting recommendations:

### Template
```markdown
**Conflict**: Brief description
- **Option A**: Description (Source)
- **Option B**: Description (Source) ✓ [If chosen]
- **Resolution**: What was decided
- **Rationale**: Why this choice was made
```

### Example
```markdown
**Conflict**: Threading strategy
- **Option A**: Use DispatchQueue (Amp)
- **Option B**: Use Task (GPT-5) ✓ [Verified-Code]
- **Resolution**: Task pattern throughout
- **Rationale**: Swift 6 concurrency compliance
```

## Writing Style

### Voice and Tone
- **Active voice**: "The facade manages playback"
- **Present tense**: "The engine handles audio"
- **Direct**: "Fix this by..." not "One might fix..."
- **Technical**: Use proper terminology

### Formatting
- **Bold** for component names
- `Code font` for code elements
- *Italics* for emphasis sparingly
- Bullet points for lists
- Tables for comparisons

### Headings
- **H1 (#)**: Document title only
- **H2 (##)**: Major sections
- **H3 (###)**: Subsections
- **H4 (####)**: Rarely, for deep nesting

## Update Frequency

### When to Update
- **Immediately**: Breaking changes, removed features
- **Same PR**: New features, API changes
- **Weekly**: Verification tag review
- **Monthly**: Full accuracy audit

### Version Tracking
Include in main docs:
```markdown
Last Updated: 2025-09-26
Last Verified: 2025-09-26
Coverage: 80% of public APIs
```

## Common Mistakes to Avoid

1. **Unverified Claims**: "Probably uses X" → Verify or mark [Unverified]
2. **Stale Examples**: Always check examples still compile
3. **Missing Context**: Include enough context for understanding
4. **Over-Documentation**: Don't document obvious things
5. **Under-Documentation**: Don't skip complex patterns
6. **Wrong Paths**: Triple-check all file paths
7. **Missing Dependencies**: List all required components

## Review Checklist

Before committing documentation:
- [ ] All technical claims have verification tags
- [ ] File paths are complete and correct
- [ ] Code examples are from actual codebase
- [ ] Troubleshooting covers real issues
- [ ] No TODO or FIXME comments
- [ ] Conflicts have resolutions
- [ ] Style guide followed

## Tools

### Verification
```bash
# Find unverified claims
grep -r "\[Unverified\]" plan2/ Files/ Plan/

# Check file paths exist
./scripts/validate-paths.sh

# Count documentation coverage
./scripts/check-doc-coverage.sh
```

### Quality Checks
- Run spell checker
- Verify markdown renders correctly
- Check all links work
- Validate code examples compile

## Examples of Good Documentation

See:
- `plan2/agents/fonic-hifi-codebase-guide.md` - Main guide
- `Core/Audio/CLAUDE.md` - Module-specific docs
- This style guide - Meta-documentation

---

Remember: Documentation is code. Treat it with the same care.