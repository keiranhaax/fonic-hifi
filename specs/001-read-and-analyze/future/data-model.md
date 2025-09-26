# Data Model: Codebase Documentation System

**Date**: 2025-09-26
**Feature**: Codebase Analysis and Documentation Review

## Entity Definitions

### DocumentationSection
Represents a major section of the codebase guide.

**Fields**:
- `id: String` - Unique identifier (e.g., "audio-subsystem")
- `title: String` - Display title
- `path: String` - File system path to markdown file
- `order: Int` - Display order in navigation
- `lastUpdated: Date` - Last modification timestamp
- `completeness: Float` - Coverage percentage (0.0 to 1.0)
- `verificationStatus: VerificationLevel` - Overall verification status

**Relationships**:
- `subsections: [DocumentationSection]` - Child sections
- `components: [Component]` - Related code components
- `conflicts: [ConflictRecord]` - Documented conflicts

**Validation Rules**:
- Title must be non-empty
- Path must exist in repository
- Completeness must be between 0.0 and 1.0
- Order must be unique within parent section

### Component
Represents a documented code component (class, module, etc).

**Fields**:
- `id: String` - Unique identifier
- `name: String` - Component name
- `type: ComponentType` - Type (class, protocol, module, etc)
- `filePath: String` - Source code location
- `lineNumber: Int?` - Optional line number reference
- `isPublicAPI: Bool` - Whether part of public API
- `documentation: String` - Markdown documentation
- `verificationTag: VerificationTag` - Verification status

**Relationships**:
- `section: DocumentationSection` - Parent documentation section
- `dependencies: [Component]` - Components this depends on
- `usages: [CodeExample]` - Example usages

**Validation Rules**:
- Name must match actual code component
- FilePath must exist in repository
- Public API components require documentation
- Verification tag is mandatory

### VerificationTag
Represents the verification status of a technical claim.

**Fields**:
- `type: VerificationType` - Type of verification
- `timestamp: Date` - When verified
- `source: String?` - Source reference (file path or URL)
- `verifiedBy: String?` - Who/what verified (human or tool)
- `note: String?` - Additional context

**Types (enum)**:
- `VerifiedCode` - Verified against repository
- `VerifiedApple` - Verified against Apple docs
- `Unverified` - Not yet verified

**Validation Rules**:
- Type is required
- Timestamp must not be future
- VerifiedCode requires source file path
- VerifiedApple requires documentation URL

### ConflictRecord
Documents conflicting recommendations from different sources.

**Fields**:
- `id: String` - Unique identifier
- `topic: String` - What the conflict is about
- `options: [ConflictOption]` - Available options
- `resolution: ConflictOption?` - Chosen resolution
- `verificationTag: VerificationTag?` - Verification of resolution

**Relationships**:
- `section: DocumentationSection` - Where documented

**Validation Rules**:
- At least 2 options required
- Resolution must be one of the options
- Resolution requires verification tag

### ConflictOption
Represents one option in a conflict.

**Fields**:
- `source: String` - Source of recommendation (AI agent name)
- `recommendation: String` - What was recommended
- `pros: [String]` - Advantages
- `cons: [String]` - Disadvantages
- `codeAligned: Bool` - Whether matches current implementation

**Validation Rules**:
- Source and recommendation required
- At least one pro or con required

### CodeExample
Represents a code snippet example.

**Fields**:
- `id: String` - Unique identifier
- `title: String` - Example title
- `code: String` - Code snippet
- `language: String` - Programming language
- `filePath: String?` - Optional source file reference
- `explanation: String?` - Optional explanation

**Relationships**:
- `component: Component` - Related component

**Validation Rules**:
- Code must be non-empty
- Language must be valid (swift, bash, etc)

## Enumerations

### ComponentType
```
enum ComponentType {
    case class
    case struct
    case protocol
    case enum
    case module
    case function
    case property
}
```

### VerificationLevel
```
enum VerificationLevel {
    case fullyVerified    // 100% verified
    case mostlyVerified   // >80% verified
    case partiallyVerified // 50-80% verified
    case minimallyVerified // <50% verified
    case unverified       // 0% verified
}
```

## State Transitions

### Documentation Update Flow
```
1. Draft -> Review
   - Triggered by: PR creation
   - Validation: Coverage metrics met

2. Review -> Verified
   - Triggered by: Verification process
   - Validation: All claims tagged

3. Verified -> Published
   - Triggered by: PR merge
   - Validation: No unresolved conflicts

4. Published -> Outdated
   - Triggered by: Code changes
   - Action: Mark for update
```

### Verification State Machine
```
Unverified -> Pending
   - Triggered by: Verification request

Pending -> VerifiedCode
   - Triggered by: Code inspection
   - Requires: File path reference

Pending -> VerifiedApple
   - Triggered by: Documentation check
   - Requires: Apple doc URL

Pending -> Failed
   - Triggered by: Unable to verify
   - Action: Remain as Unverified
```

## Relationships Summary

```
DocumentationSection (1) ─────> (*) Component
        |                              |
        ├──> (*) ConflictRecord       ├──> (*) CodeExample
        |           |                  |
        └──> (*) subsections          └──> (*) dependencies

VerificationTag ──> Component, ConflictRecord
```

## Coverage Calculation

```swift
struct CoverageMetrics {
    let totalPublicAPIs: Int
    let documentedAPIs: Int
    let verifiedAPIs: Int

    var coveragePercentage: Float {
        Float(documentedAPIs) / Float(totalPublicAPIs)
    }

    var verificationPercentage: Float {
        Float(verifiedAPIs) / Float(documentedAPIs)
    }

    var isComplete: Bool {
        coveragePercentage >= 0.8  // 80% requirement
    }
}
```

## Validation Rules Summary

1. **Completeness**: 80% of public APIs must be documented
2. **Verification**: Every technical claim requires a verification tag
3. **Conflicts**: All conflicts must document pros/cons
4. **Updates**: Documentation updates required per PR affecting architecture
5. **References**: All code references must include file paths
6. **Currency**: Last updated timestamp must reflect latest relevant PR