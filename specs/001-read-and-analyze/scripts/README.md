# Documentation Analysis Scripts

This directory contains utility scripts for analyzing and maintaining the Fonic HiFi documentation.

## Prerequisites

- Bash shell (macOS/Linux)
- Basic Unix utilities (grep, find, wc)
- Read access to the Fonic HiFi repository

## Available Scripts

### 1. count-public-apis.sh

**Purpose**: Count public APIs in Swift source files to measure what needs documentation.

**Usage**:
```bash
./count-public-apis.sh [directory]
```

**Output**:
- Total Swift files count
- Breakdown of public classes, structs, protocols, enums, functions, and variables
- List of major components (files with 3+ public declarations)

**Example**:
```bash
cd /path/to/Fonic-HiFi
./specs/001-read-and-analyze/scripts/count-public-apis.sh
```

### 2. count-documented-apis.sh

**Purpose**: Count documented APIs in markdown files to measure documentation coverage.

**Usage**:
```bash
./count-documented-apis.sh [directory]
```

**Output**:
- Component mentions in main guide
- Component references in AI analyses
- Component references in Plan files
- Verification tag statistics

**Example**:
```bash
./specs/001-read-and-analyze/scripts/count-documented-apis.sh
```

### 3. check-doc-coverage.sh

**Purpose**: Calculate overall documentation coverage percentage and compare against 80% target.

**Usage**:
```bash
./check-doc-coverage.sh [directory]
```

**Output**:
- Coverage percentage calculation
- Comparison against 80% target
- Verification rate statistics
- Actionable recommendations

**Features**:
- Combines API counts with documentation counts
- Estimates unique documented components
- Shows verification tag distribution
- Provides gap analysis

**Example**:
```bash
./specs/001-read-and-analyze/scripts/check-doc-coverage.sh
```

### 4. find-unverified.sh

**Purpose**: Find all unverified claims in documentation that need verification.

**Usage**:
```bash
./find-unverified.sh [directory]
```

**Output**:
- List of files containing [Unverified] tags
- Line numbers and content of unverified claims
- Potential unverified claims (technical statements without tags)
- Summary statistics

**Use Cases**:
- Identify claims needing verification
- Find technical statements missing tags
- Track verification progress
- Prioritize verification work

**Example**:
```bash
./specs/001-read-and-analyze/scripts/find-unverified.sh
```

### 5. validate-paths.sh

**Purpose**: Verify that file paths mentioned in documentation actually exist in the codebase.

**Usage**:
```bash
./validate-paths.sh [directory]
```

**Output**:
- List of valid and invalid file paths
- Suggestions for where moved files might be
- Directory structure validation
- Path accuracy statistics

**Features**:
- Checks Swift file references
- Validates directory structures
- Suggests correct paths for moved files
- Identifies common path errors

**Example**:
```bash
./specs/001-read-and-analyze/scripts/validate-paths.sh
```

## Making Scripts Executable

Before first use, make all scripts executable:
```bash
chmod +x specs/001-read-and-analyze/scripts/*.sh
```

## Typical Workflow

### 1. Initial Analysis
```bash
# Check current coverage
./check-doc-coverage.sh

# Find what needs documentation
./count-public-apis.sh

# Find what's already documented
./count-documented-apis.sh
```

### 2. Quality Check
```bash
# Verify file paths are correct
./validate-paths.sh

# Find unverified claims
./find-unverified.sh
```

### 3. Progress Tracking
```bash
# Run weekly to track progress
./check-doc-coverage.sh > coverage-$(date +%Y%m%d).txt

# Compare over time
diff coverage-20250926.txt coverage-20251003.txt
```

## Integration with Makefile

These scripts can be integrated into the project's Makefile:

```makefile
doc-coverage:
	@specs/001-read-and-analyze/scripts/check-doc-coverage.sh

doc-verify:
	@specs/001-read-and-analyze/scripts/find-unverified.sh

doc-paths:
	@specs/001-read-and-analyze/scripts/validate-paths.sh

doc-check: doc-coverage doc-verify doc-paths
	@echo "Documentation check complete"
```

## CI/CD Integration

Add to GitHub Actions or other CI systems:

```yaml
- name: Check Documentation Coverage
  run: |
    ./specs/001-read-and-analyze/scripts/check-doc-coverage.sh
    coverage=$(./specs/001-read-and-analyze/scripts/check-doc-coverage.sh | grep "Coverage Percentage" | awk '{print $3}' | tr -d '%')
    if [ "$coverage" -lt 80 ]; then
      echo "Documentation coverage ($coverage%) below 80% target"
      exit 1
    fi
```

## Troubleshooting

### Script Permission Denied
```bash
chmod +x script-name.sh
```

### No Output / Empty Results
- Check you're in the correct directory
- Verify the repository structure matches expected paths
- Ensure markdown files exist in plan2/, Plan/, Files/

### Incorrect Counts
- Scripts use approximations for deduplication
- Manual verification recommended for critical metrics
- Some patterns might not match all code styles

## Maintenance

### Adding New Scripts
1. Create script in this directory
2. Add documentation to this README
3. Make executable: `chmod +x new-script.sh`
4. Test with sample data
5. Add to Makefile if appropriate

### Updating Patterns
- Swift detection patterns in `count-public-apis.sh`
- Documentation patterns in `count-documented-apis.sh`
- Path patterns in `validate-paths.sh`

## Notes

- All scripts are read-only and don't modify files
- Scripts use POSIX-compliant shell for portability
- Counts are approximations due to pattern matching limitations
- Manual review recommended for accuracy-critical decisions

## Support

For issues or improvements:
1. Check script comments for details
2. Review error messages for guidance
3. Consult the documentation style guide
4. Submit improvements as pull requests