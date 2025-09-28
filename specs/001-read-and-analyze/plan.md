
# Implementation Plan: Codebase Analysis and Documentation Review

**Branch**: `001-read-and-analyze` | **Date**: 2025-09-26 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-read-and-analyze/spec.md`

## Execution Flow (/plan command scope)
```
1. Load feature spec from Input path
   → If not found: ERROR "No feature spec at {path}"
2. Fill Technical Context (scan for NEEDS CLARIFICATION)
   → Detect Project Type from file system structure or context (web=frontend+backend, mobile=app+api)
   → Set Structure Decision based on project type
3. Fill the Constitution Check section based on the content of the constitution document.
4. Evaluate Constitution Check section below
   → If violations exist: Document in Complexity Tracking
   → If no justification possible: ERROR "Simplify approach first"
   → Update Progress Tracking: Initial Constitution Check
5. Execute Phase 0 → research.md
   → If NEEDS CLARIFICATION remain: ERROR "Resolve unknowns"
6. Execute Phase 1 → contracts, data-model.md, quickstart.md, agent-specific template file (e.g., `CLAUDE.md` for Claude Code, `.github/copilot-instructions.md` for GitHub Copilot, `GEMINI.md` for Gemini CLI, `QWEN.md` for Qwen Code or `AGENTS.md` for opencode).
7. Re-evaluate Constitution Check section
   → If new violations: Refactor design, return to Phase 1
   → Update Progress Tracking: Post-Design Constitution Check
8. Plan Phase 2 → Describe task generation approach (DO NOT create tasks.md)
9. STOP - Ready for /tasks command
```

**IMPORTANT**: The /plan command STOPS at step 7. Phases 2-4 are executed by other commands:
- Phase 2: /tasks command creates tasks.md
- Phase 3-4: Implementation execution (manual or via tools)

## Summary
Review and improve the existing Fonic HiFi codebase documentation stored as Markdown files. Focus on identifying gaps, correcting inaccuracies, and incrementally adding verification tags to technical claims. This is a manual documentation improvement process, not an automated system.

## Technical Context
**Language/Version**: Swift 6.2 (iOS 26 project)
**Primary Dependencies**: SwiftUI, SwiftData, AVAudioEngine, AudioKit
**Storage**: Markdown files in repository, version-controlled
**Testing**: No test infrastructure currently exists for documentation validation
**Target Platform**: iOS 26+ (iPhone 16 Pro primary target)
**Project Type**: mobile - iOS application with comprehensive documentation
**Performance Goals**: N/A - Static Markdown files with no performance requirements
**Constraints**: Manual review process, incremental improvement approach
**Scale/Scope**: ~100 Swift files (~25k LOC), 10 AI analyses to reconcile

## Constitution Check
*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

- [x] **Documentation Focus**: Feature is documentation-centric, aligns with maintainability
- [x] **Version Control**: Uses existing Git/Markdown infrastructure
- [x] **Testability**: Clear acceptance criteria for documentation completeness
- [x] **Simplicity**: Leverages existing tools (Markdown, Git) without new dependencies
- [x] **Observability**: Verification tags provide clear traceability

## Project Structure

### Documentation (this feature)
```
specs/[###-feature]/
├── plan.md              # This file (/plan command output)
├── research.md          # Phase 0 output (/plan command)
├── data-model.md        # Phase 1 output (/plan command)
├── quickstart.md        # Phase 1 output (/plan command)
├── contracts/           # Phase 1 output (/plan command)
└── tasks.md             # Phase 2 output (/tasks command - NOT created by /plan)
```

### Source Code (repository root)
```
plan2/
├── agents/
│   └── fonic-hifi-codebase-guide.md   # Primary documentation file
├── prd.md                              # Product requirements
└── roadmap.md                          # Development roadmap

Files/
├── Code_Analysis_Report.md             # AI analysis reports
└── Archive/                            # Historical documentation

Plan/
├── audio.md                            # Audio subsystem docs
├── Sheet.md                            # UI implementation docs
└── Search.md                           # Search feature docs

Fonic HiFi/                             # Main iOS app
├── Core/
│   └── Audio/
│       └── Engine/                     # Note: AudioEngineFacade.swift is here
├── Data/                               # Data layer
├── Presentation/                       # UI layer
└── (No Utils directory exists)

# Note: No test directories exist in the project
```

**Structure Decision**: Mobile iOS application with existing Markdown documentation spread across multiple directories. Primary guide lives in `plan2/agents/` with supplementary docs in `Files/` and `Plan/` directories. No test infrastructure exists.

## Phase 0: Outline & Research
1. **Extract unknowns from Technical Context** above:
   - For each NEEDS CLARIFICATION → research task
   - For each dependency → best practices task
   - For each integration → patterns task

2. **Generate and dispatch research agents**:
   ```
   For each unknown in Technical Context:
     Task: "Research {unknown} for {feature context}"
   For each technology choice:
     Task: "Find best practices for {tech} in {domain}"
   ```

3. **Consolidate findings** in `research.md` using format:
   - Decision: [what was chosen]
   - Rationale: [why chosen]
   - Alternatives considered: [what else evaluated]

**Output**: research.md with all NEEDS CLARIFICATION resolved

## Phase 1: Design & Contracts
*Prerequisites: research.md complete*

1. **Extract entities from feature spec** → `data-model.md`:
   - Entity name, fields, relationships
   - Validation rules from requirements
   - State transitions if applicable

2. **Generate API contracts** from functional requirements:
   - For each user action → endpoint
   - Use standard REST/GraphQL patterns
   - Output OpenAPI/GraphQL schema to `/contracts/`

3. **Generate contract tests** from contracts:
   - One test file per endpoint
   - Assert request/response schemas
   - Tests must fail (no implementation yet)

4. **Extract test scenarios** from user stories:
   - Each story → integration test scenario
   - Quickstart test = story validation steps

5. **Update agent file incrementally** (O(1) operation):
   - Run `.specify/scripts/bash/update-agent-context.sh kilocode`
     **IMPORTANT**: Execute it exactly as specified above. Do not add or remove any arguments.
   - If exists: Add only NEW tech from current plan
   - Preserve manual additions between markers
   - Update recent changes (keep last 3)
   - Keep under 150 lines for token efficiency
   - Output to repository root

**Output**: data-model.md, /contracts/*, failing tests, quickstart.md, agent-specific file

## Phase 2: Task Planning Approach
*This section describes what the /tasks command will do - DO NOT execute during /plan*

**Task Generation Strategy**:
- Load `.specify/templates/tasks-template.md` as base
- Generate tasks from Phase 1 design docs (contracts, data model, quickstart)
- Documentation validation tasks:
  - Verify 80% coverage metric
  - Validate all verification tags
  - Check conflict resolution documentation
  - Test file:line references
- API contract test tasks:
  - Test documentation section retrieval
  - Test component search functionality
  - Test verification workflow
  - Test coverage calculation
- Integration tasks:
  - PR-based update workflow
  - Git hook integration
  - IDE preview validation

**Ordering Strategy**:
- TDD order: Tests before implementation
- Priority order:
  1. Coverage validation tests [P]
  2. Verification tag tests [P]
  3. API endpoint tests [P]
  4. Search functionality
  5. Conflict resolution display
  6. Integration with PR workflow
- Mark [P] for parallel execution (independent tests)

**Estimated Output**: 15-20 numbered, ordered tasks in tasks.md focused on documentation validation and tooling

**IMPORTANT**: This phase is executed by the /tasks command, NOT by /plan

## Phase 3+: Future Implementation
*These phases are beyond the scope of the /plan command*

**Phase 3**: Task execution (/tasks command creates tasks.md)  
**Phase 4**: Implementation (execute tasks.md following constitutional principles)  
**Phase 5**: Validation (run tests, execute quickstart.md, performance validation)

## Complexity Tracking
*Fill ONLY if Constitution Check has violations that must be justified*

No complexity violations - the documentation system leverages existing Markdown and Git infrastructure without introducing new architectural complexity.


## Progress Tracking
*This checklist is updated during execution flow*

**Phase Status**:
- [x] Phase 0: Research complete (/plan command)
- [x] Phase 1: Design complete (/plan command)
- [x] Phase 2: Task planning complete (/plan command - describe approach only)
- [ ] Phase 3: Tasks generated (/tasks command)
- [ ] Phase 4: Implementation complete
- [ ] Phase 5: Validation passed

**Gate Status**:
- [x] Initial Constitution Check: PASS
- [x] Post-Design Constitution Check: PASS
- [x] All NEEDS CLARIFICATION resolved
- [x] Complexity deviations documented (none required)

---
*Based on Constitution v2.1.1 - See `/memory/constitution.md`*
