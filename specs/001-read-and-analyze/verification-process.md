# Verification Process Documentation

## Overview
This document describes the process for adding verification tags to the Fonic HiFi codebase documentation.

## Verification Tag Types

### [Verified-Code]
Used when a claim has been directly verified against the actual codebase.
- **When to use**: Statement verified by examining Swift files in the repository
- **Format**: `[Verified-Code: FileName.swift:LineNumber]` when specific location known
- **Example**: `@MainActor [Verified-Code: AudioEngineFacade.swift:19]`

### [Verified-Apple]
Used when information comes from official Apple documentation.
- **When to use**: iOS/Swift features documented in Apple's official resources
- **Format**: `[Verified-Apple]` or `[Verified-Apple: Source]`
- **Example**: `Swift 6.2 concurrency features [Verified-Apple]`

### [Unverified]
Used when a claim cannot be verified or evidence is insufficient.
- **When to use**:
  - Code referenced but not found
  - Claims about future features
  - Performance metrics without measurements
- **Format**: `[Unverified]`
- **Example**: `Tests have minimal coverage [Unverified]`

## Verification Process Steps

1. **Identify Technical Claims**
   - Any statement about code structure
   - Performance metrics
   - Implementation details
   - API usage

2. **Search for Evidence**
   - Use `Glob` to find referenced files
   - Use `Read` to verify specific code snippets
   - Check Apple documentation via MCP tools
   - Verify file paths and line numbers

3. **Apply Appropriate Tag**
   - Add tag immediately after the claim
   - Include file and line number when possible
   - Be specific about what was verified

4. **Document Unverifiable Claims**
   - Mark with [Unverified]
   - Note why verification wasn't possible
   - Flag for future verification

## Examples

### Good Verification
```markdown
AudioEngineFacade uses @MainActor [Verified-Code: AudioEngineFacade.swift:19]
```

### Incomplete Verification
```markdown
Performance target < 10ms [Unverified]
```

### Apple Documentation
```markdown
AVAudioSession categories for background playback [Verified-Apple]
```

## Tools for Verification

- **Code Search**: `make search PATTERN='pattern'`
- **File Finding**: `make find-files PATTERN='*.swift'`
- **Apple Docs**: `mcp__apple-rag-mcp__search` or `mcp__sosumi__fetchAppleDocumentation`
- **Direct Reading**: `Read` tool with file path

## Maintenance

- Review verification tags quarterly
- Update when code changes
- Remove [Unverified] tags when evidence found
- Add new tags as documentation expands

## Statistics Tracking

Track verification progress:
- Total claims in documentation
- Claims with [Verified-Code] tags
- Claims with [Verified-Apple] tags
- Claims with [Unverified] tags
- Percentage verified

## Quality Standards

- Every technical claim must have a verification tag
- Prefer specific file:line references over general verification
- Update tags when code moves or changes
- Document verification failures for transparency