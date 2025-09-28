# Tasks: Codebase Documentation Review and Improvement

**Input**: Existing Markdown documentation in `/plan2/`, `/Files/`, `/Plan/`
**Prerequisites**: Access to repository, understanding of current codebase

## Overview
Manual review and improvement of existing documentation. No automated testing or API development - focuses on documentation accuracy and completeness.

## Format: `[ID] [P?] Description`
- **[P]**: Can run in parallel (independent tasks)
- Include exact file paths in descriptions

## Phase 1: Documentation Audit
- [x] T001 Review plan2/agents/fonic-hifi-codebase-guide.md for accuracy against current code
- [x] T002 [P] Identify and list all incorrect file paths in documentation
- [x] T003 [P] Search for undocumented major components in Fonic HiFi/Core/
- [x] T004 [P] Review Files/Code_Analysis_Report.md for outdated information
- [x] T005 [P] Check Plan/*.md files for consistency with current implementation

## Phase 2: Path Corrections
- [x] T006 Update all references to AudioEngineFacade.swift to correct path (Fonic HiFi/Core/Audio/Engine/)
- [x] T007 Remove references to non-existent Utils/ directory from documentation
- [x] T008 Correct any other file path errors identified in T002
- [x] T009 Update documentation to reflect actual directory structure

## Phase 3: Verification Tag Addition (Manual)
- [x] T010 Add [Verified-Code] tags to claims verified against actual Swift files
- [x] T011 Add [Verified-Apple] tags to claims from official Apple documentation
- [x] T012 Add [Unverified] tags to claims that cannot be verified
- [x] T013 Document the verification process in a README

## Phase 4: Gap Analysis
- [x] T014 Create simple bash script to count public APIs in Swift files
- [x] T015 Create bash script to count documented APIs in markdown files
- [x] T016 Generate gap report showing undocumented public APIs
- [x] T017 Prioritize top 10 undocumented APIs for documentation

## Phase 5: Documentation Improvements
- [x] T018 Document the top 10 undocumented APIs identified in T017
- [x] T019 Add conflict resolution sections where AI analyses disagree
- [x] T020 Update troubleshooting section with actual issues from codebase
- [x] T021 Create documentation style guide for future updates

## Phase 6: Simple Tooling
- [x] T022 Create bash script: check-doc-coverage.sh to calculate documentation coverage
- [x] T023 Create bash script: find-unverified.sh to list unverified claims
- [x] T024 Create bash script: validate-paths.sh to check file path accuracy
- [x] T025 Document how to use these scripts in README

## Phase 7: Final Review
- [x] T026 Review all changes for consistency
- [x] T027 Update main guide's "last updated" timestamp
- [x] T028 Create summary of changes made
- [x] T029 Commit documentation improvements (ready)

## Dependencies
- T001-T005 (audit) should complete before other phases
- T006-T009 (corrections) can proceed after T002
- T010-T013 (tags) can proceed after audit
- T014-T017 (gap analysis) independent
- T018-T021 (improvements) depend on T017
- T022-T025 (tooling) independent
- T026-T029 (review) require all other tasks

## Parallel Example
```bash
# Launch audit tasks in parallel:
T002: Identify incorrect file paths
T003: Search for undocumented components
T004: Review AI analysis reports
T005: Check Plan files consistency
```

## Notes
- All tasks are manual documentation work
- No test infrastructure required
- Scripts are simple bash tools, not complex systems
- Focus on accuracy over automation
- Incremental improvement approach

## Success Criteria
- [ ] All file paths in documentation are correct
- [ ] Major components have basic documentation
- [ ] Verification tags added where feasible
- [ ] Simple coverage script exists
- [ ] Documentation is more accurate than before