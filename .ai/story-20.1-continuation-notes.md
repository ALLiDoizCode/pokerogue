# Story 20.1: Aolite Test Migration - Continuation Notes

## Session Summary (2025-10-09 Afternoon)

### What Happened

**Problem Discovered**: When validating the previously migrated tests, discovered that ALL 123 tests were migrated using an **incorrect API pattern** that doesn't match the real aolite framework.

**Root Cause**:
- Original pattern created in commit 227b95c09 without consulting real aolite documentation
- Pattern documented in CLAUDE.md and used for all subsequent migrations
- Real aolite framework was never actually loaded (missing `init.lua`)
- Tests only ran against mock-aolite which had the same incorrect API

### Work Completed This Session

1. ✅ **Diagnosed API Incompatibility**
   - Real aolite wasn't loading (missing init.lua)
   - Created `development-tools/aolite/lua/aolite/init.lua`
   - Fixed package paths in `scripts/run-aolite-tests.lua`

2. ✅ **Root Cause Analysis**
   - Traced incorrect pattern to commit 227b95c09
   - Documented full timeline in story file
   - Identified why it appeared to work (mock had same wrong API)

3. ✅ **Created Correct Pattern**
   - Studied real aolite examples
   - Created authoritative template: `.ai/correct-aolite-test-pattern.lua`
   - Validated pattern works with real framework

4. ✅ **Migrated Reference File**
   - Successfully migrated `testing/unit/pokemon-species-db.test.lua`
   - Validated tests pass with correct API
   - Serves as template for remaining migrations

5. ✅ **Updated Documentation**
   - CLAUDE.md: Updated with correct pattern and warnings
   - Story file: Documented root cause, progress, and continuation plan
   - Created migration task spec: `.ai/re-migration-task.md`

### Current State

**Files Needing Re-Migration**: 138 test files
- 116 unit tests
- 15 parity tests
- 4 performance tests
- 3 others

**Files Already Correct**:
- `testing/unit/pokemon-species-db.test.lua` ✅
- `testing/unit/data-process-template.test.lua` (deprecated, skips tests)

**Estimated Remaining Work**: 8-12 hours

## Continuation Instructions

### Reference Files (Use These!)

1. **Template**: `.ai/correct-aolite-test-pattern.lua`
   - Authoritative correct pattern
   - Copy/adapt for new migrations

2. **Working Example**: `testing/unit/pokemon-species-db.test.lua`
   - Real test that passes with correct API
   - Shows full implementation

3. **Migration Spec**: `.ai/re-migration-task.md`
   - Detailed transformation instructions
   - Key changes documented

### Key API Differences to Fix

**INCORRECT (current state of 137 files):**
```lua
local process = aolite.spawnProcess(PROCESS_PATH)
local msg = { Target = process.id, Action = "Test", Timestamp = ... }
return aolite.send(msg, timeout)
```

**CORRECT (what they should be):**
```lua
local processId = "test-name"
local file = io.open(PROCESS_PATH, "r")
local source = file:read("*all")
file:close()
aolite.spawnProcess(processId, source, tags)

local msg = { From = processId, Target = processId, Action = "Test" }
aolite.send(msg)
return aolite.getLastMsg(processId)
```

### Recommended Approach

**Option 1: Parallel Agents** (Fastest)
- Use Task tool to launch 10-12 agents in parallel
- Assign 10-15 files per agent
- Each agent uses `.ai/re-migration-task.md` as spec
- Reference `pokemon-species-db.test.lua` for guidance
- Estimated: 2-3 hours total

**Option 2: Batch Processing** (Most Reliable)
- Migrate files in batches of 10-15
- Validate each batch with `npm run test:aolite`
- Fix any issues before next batch
- Estimated: 8-10 hours total

**Option 3: Automated Script** (Risky)
- Use `scripts/migrate-to-correct-aolite-api.lua` (partially written)
- Requires extensive regex pattern matching
- High risk of edge cases
- Still need manual validation
- Estimated: 6-8 hours total

### File Lists

**Priority 1: Story 19.6 Tests** (11 files)
```
testing/unit/encounter-reward-calculation.test.lua
testing/unit/encounter-consequence-calculation.test.lua
testing/unit/encounter-consequence-mitigation.test.lua
testing/unit/encounter-exp-scaling.test.lua
testing/unit/encounter-outcome-validation.test.lua
testing/unit/encounter-rarity-scaling.test.lua
testing/unit/special-event-duration.test.lua
testing/unit/special-event-effects.test.lua
testing/unit/special-event-encounters.test.lua
testing/unit/special-event-rewards.test.lua
testing/unit/special-event-trigger.test.lua
```

**Priority 2: Core Systems** (20 files)
```
testing/unit/battle-engine.test.lua
testing/unit/damage-calculation-engine.test.lua
testing/unit/pokemon-instance-manager.test.lua
testing/unit/moves-database.test.lua
testing/unit/items-database.test.lua
testing/unit/abilities-database.test.lua
testing/unit/capture-engine.test.lua
testing/unit/evolution-engine.test.lua
testing/unit/weather-system-engine.test.lua
testing/unit/status-effects-engine.test.lua
testing/unit/trainer-encounter-engine.test.lua
testing/unit/wild-encounter-engine.test.lua
testing/unit/fusion-battle-engine.test.lua
testing/unit/tera-type-engine.test.lua
testing/unit/coordinator-process.test.lua
testing/unit/battle-state-manager.test.lua
testing/unit/pc-storage-manager.test.lua
testing/unit/unlockable-content-engine.test.lua
testing/unit/daily-run-generation.test.lua
testing/unit/game-mode-creation.test.lua
```

**Full List**: See story file or run:
```bash
grep -l 'require("aolite")' testing/unit/*.test.lua testing/parity/*.test.lua testing/performance/*.test.lua 2>/dev/null | sort
```

### Validation Commands

```bash
# Test specific file
npm run test:aolite 2>&1 | grep -A 10 "filename.test.lua"

# Count successes/failures
npm run test:aolite 2>&1 | grep -c "PASSED"
npm run test:aolite 2>&1 | grep -c "FAILED"

# Get failed file list
npm run test:aolite 2>&1 | grep "❌.*FAILED"
```

### Success Criteria

- ✅ All 138 files migrated to correct API
- ✅ All tests pass: `npm run test:aolite` exits 0
- ✅ No references to `process.id`, `TEST_TIMEOUT`, or `Timestamp`
- ✅ All files use `processId` string and `getLastMsg()`
- ✅ CLAUDE.md updated (already done)
- ✅ Story status: "Ready for Review"

### Files Created This Session

```
development-tools/aolite/lua/aolite/init.lua
.ai/correct-aolite-test-pattern.lua
.ai/re-migration-task.md
.ai/story-20.1-continuation-notes.md (this file)
scripts/migrate-to-correct-aolite-api.lua (partial)
```

### Files Modified This Session

```
scripts/run-aolite-tests.lua (fixed package paths)
testing/unit/pokemon-species-db.test.lua (migrated to correct API)
CLAUDE.md (updated with correct pattern and warnings)
docs/stories/story-20.1-aolite-test-migration.md (documented progress and root cause)
```

## Quick Start for Next Session

1. Read this file
2. Review reference: `testing/unit/pokemon-species-db.test.lua`
3. Choose migration approach (recommend: parallel agents)
4. Start with Priority 1 files (11 Story 19.6 tests)
5. Validate batch before proceeding
6. Continue through remaining 126 files
7. Run full test suite validation
8. Update story status to "Ready for Review"

## Important Notes

- **Do NOT use the old pattern in CLAUDE.md** - it's marked as incorrect
- **Always test with real aolite** - `npm run test:aolite`
- **Reference pokemon-species-db.test.lua** - it's the only correct example
- **Include `From: processId`** - required by real aolite API
- **No `process.id`** - processId is a string, not an object

Good luck with the continuation! 🚀
