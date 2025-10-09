# Story 20.1: Aolite Test Framework Migration

**Epic**: Technical Debt Reduction
**Status**: Planning
**Priority**: P1 - High
**Created**: 2025-10-09
**Assignee**: Claude Code

## Overview

Migrate all remaining unit tests (84 files) from custom mock patterns to the official real aolite framework to achieve 100% testing pattern consistency across the codebase.

## Problem Statement

### Current State
- **Total unit tests**: 127 files
- **Using real aolite**: 39 tests (31%) ✅
- **Using custom mocks/patterns**: 84 tests (66%) ❌
- **Other/mixed**: 4 tests (3%)

### Root Cause
Testing pattern misalignment introduced through:
1. Parallel development without coordination (Story 19.6, Story 20)
2. Missing documentation of required test patterns
3. TDD validation only checking file existence, not implementation
4. No template or example to copy from

### Impact
- Inconsistent test behavior and reliability
- Maintenance burden across three different patterns
- New developers confused about which pattern to use
- Tests using custom mocks don't catch AO runtime issues

## Success Criteria

- [ ] 100% of unit tests use real aolite framework (127/127)
- [ ] All tests pass with `npm run test:aolite`
- [ ] CLAUDE.md updated with migration completion status
- [ ] TDD validation enhanced to check framework usage
- [ ] Deprecated `testing/aolite/mock-aolite.lua` removed

## Technical Approach

### Phase 1: Story 19.6 Tests Migration (10 tests)
**Files using `mock-aolite.lua` pattern:**

```bash
testing/unit/encounter-reward-calculation.test.lua
testing/unit/encounter-consequence-calculation.test.lua
testing/unit/encounter-consequence-mitigation.test.lua
testing/unit/encounter-exp-scaling.test.lua
testing/unit/encounter-outcome-validation.test.lua
testing/unit/encounter-rarity-scaling.test.lua
testing/unit/special-event-encounter.test.lua
testing/unit/special-event-reward.test.lua
testing/unit/special-event-consequence.test.lua
testing/unit/special-event-validation.test.lua
```

**Migration Pattern:**
```lua
-- Before (mock-aolite)
package.path = package.path .. ";./testing/aolite/?.lua"
local aolite = require("mock-aolite")
local process = aolite.spawnProcess("name", "./processes/file.lua")
aolite.send(msg, process)
aolite.runScheduler(process)

-- After (real aolite)
local aolite = require("aolite")
local process = aolite.spawnProcess("processes/file.lua")
local response = aolite.send(msg, timeout)
```

### Phase 2: Custom Mock Tests Migration (74 tests)
**Files using custom mock setup:**

Use `grep -L 'require("aolite")' testing/unit/*.test.lua` to identify remaining tests.

**Common custom patterns to replace:**
```lua
-- Pattern A: Manual ao/Handlers setup
if not ao then
    ao = { send = function(msg) end, id = "test_id" }
end
if not Handlers then
    Handlers = { add = function() end }
end
dofile("processes/my-process.lua")

-- Pattern B: describe/it blocks (not supported)
describe("Process", function()
    it("should work", function() end)
end)
```

**Replace with standard aolite pattern** (see CLAUDE.md for full template)

### Phase 3: TDD Validation Enhancement
**Update `scripts/hooks/tdd-pre-commit.sh`:**

```bash
# Add framework validation
check_test_framework() {
    local test_file="$1"
    if ! grep -q 'require("aolite")' "$test_file"; then
        echo "⚠️  WARNING: $test_file does not use real aolite framework"
        echo "   See CLAUDE.md for required test pattern"
        return 1
    fi
    return 0
}
```

### Phase 4: Cleanup
- [ ] Remove `testing/aolite/mock-aolite.lua`
- [ ] Update CLAUDE.md migration status to 100%
- [ ] Archive migration analysis to `.ai/archive/`

## Implementation Checklist

### Story 19.6 Tests (10 files)
- [ ] `encounter-reward-calculation.test.lua`
- [ ] `encounter-consequence-calculation.test.lua`
- [ ] `encounter-consequence-mitigation.test.lua`
- [ ] `encounter-exp-scaling.test.lua`
- [ ] `encounter-outcome-validation.test.lua`
- [ ] `encounter-rarity-scaling.test.lua`
- [ ] `special-event-encounter.test.lua`
- [ ] `special-event-reward.test.lua`
- [ ] `special-event-consequence.test.lua`
- [ ] `special-event-validation.test.lua`

### Custom Mock Tests (74 files)
To be identified via:
```bash
grep -L 'require("aolite")' testing/unit/*.test.lua | \
grep -v encounter | \
grep -v special-event | \
grep -v seasonal-event | \
grep -v community-event | \
grep -v modifier-engine | \
grep -v narrative-encounter
```

- [ ] Batch 1: Epic 16 tests (abilities, nature, stat calculation) - ~15 files
- [ ] Batch 2: Epic 17 tests (battle, capture, damage) - ~20 files
- [ ] Batch 3: Epic 18 tests (evolution, breeding, items) - ~15 files
- [ ] Batch 4: Epic 19 tests (achievements, challenges, trainer) - ~12 files
- [ ] Batch 5: Remaining tests (game-state, move, species) - ~12 files

### Validation & Cleanup
- [ ] All tests pass: `npm run test:aolite`
- [ ] Update CLAUDE.md migration status
- [ ] Enhance TDD validation script
- [ ] Remove mock-aolite.lua
- [ ] Archive analysis document

## Testing Strategy

For each migrated test file:
1. Run original test to capture expected output
2. Migrate to real aolite pattern
3. Run migrated test and verify identical behavior
4. Commit migration in small batches (5-10 files per commit)

**Validation command:**
```bash
# Test specific file
npm run test:aolite -- testing/unit/file.test.lua

# Test all files
npm run test:aolite
```

## Migration Commands

```bash
# Identify files needing migration
grep -L 'require("aolite")' testing/unit/*.test.lua > .ai/tests-to-migrate.txt

# Count files by pattern
grep -l 'mock-aolite' testing/unit/*.test.lua | wc -l  # Pattern 3
grep -l 'if not ao then' testing/unit/*.test.lua | wc -l  # Pattern 2

# Run tests before migration
npm run test:aolite 2>&1 | tee .ai/test-output-before.txt

# Run tests after migration
npm run test:aolite 2>&1 | tee .ai/test-output-after.txt
```

## Dependencies

- Real aolite framework: `development-tools/aolite/`
- Test runner: `npm run test:aolite`
- TDD validation: `scripts/hooks/tdd-pre-commit.sh`

## Risks & Mitigation

| Risk | Impact | Mitigation |
|------|--------|------------|
| Test behavior changes during migration | High | Validate each test maintains identical assertions |
| Breaking existing CI/CD | High | Migrate in small batches, run full test suite each commit |
| Missing edge cases | Medium | Compare test output before/after migration |
| Time investment (84 files) | Medium | Batch migrations, automate where possible |

## Related Documents

- **Root Cause Analysis**: `.ai/testing-misalignment-analysis.md`
- **Test Pattern Documentation**: `CLAUDE.md` (lines 36-154)
- **Story 20 Migration**: Commits `227b95c09`, `748f39e47`
- **TDD Validation**: `scripts/hooks/tdd-pre-commit.sh`

## Timeline Estimate

- **Phase 1 (Story 19.6)**: 2-3 hours (10 tests)
- **Phase 2 (Custom mocks)**: 8-10 hours (74 tests, batched)
- **Phase 3 (TDD Enhancement)**: 1 hour
- **Phase 4 (Cleanup)**: 1 hour
- **Total**: 12-15 hours of development time

## Definition of Done

- ✅ All 127 unit tests use real aolite framework
- ✅ `grep -L 'require("aolite")' testing/unit/*.test.lua` returns empty
- ✅ All tests pass: `npm run test:aolite` exits 0
- ✅ CLAUDE.md shows 100% migration completion
- ✅ TDD validation checks framework usage
- ✅ mock-aolite.lua removed from codebase
- ✅ CI/CD passes on all migrations

## Notes

**Completed Prior Work:**
- ✅ Story 20 process tests: 3 files migrated (commit 227b95c09)
- ✅ Story 20 feature tests: 3 files migrated (commit 748f39e47)
- ✅ Analysis document created: `.ai/testing-misalignment-analysis.md`
- ✅ CLAUDE.md updated with test pattern documentation

**Next Steps:**
1. Start with Story 19.6 tests (mock-aolite pattern, cleanest migration)
2. Move to custom mock tests in Epic-sized batches
3. Validate each batch before moving to next
4. Update documentation and cleanup at end
