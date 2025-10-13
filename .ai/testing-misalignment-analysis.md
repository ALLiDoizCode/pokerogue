# Testing Pattern Misalignment Analysis

## Executive Summary

There are **THREE different testing patterns** being used across the codebase, creating inconsistency and confusion:

### Pattern Distribution (127 total unit tests):
1. **Real aolite** (~57 tests, 45%) - ✅ CORRECT - Official framework
2. **Mock-based custom** (~47 tests, 37%) - ⚠️ INCONSISTENT - Story 19/20 pattern
3. **mock-aolite** (~10 tests, 8%) - ⚠️ HYBRID - Story 19.6 pattern
4. **Other/mixed** (~13 tests, 10%)

---

## The Three Testing Patterns

### Pattern 1: Real Aolite (CORRECT - Established Standard)
**Used by**: Core processes (Epic 16, 17, early stories)
**Location**: `testing/unit/abilities-nature-manager.test.lua` (example)

```lua
local aolite = require("aolite")  -- Real framework from development-tools/
local json = require("json")

local process = aolite.spawnProcess(PROCESS_PATH)
local response = aolite.send(msg, timeout)
```

**Characteristics:**
- Uses actual aolite framework from `development-tools/aolite/`
- Real process spawning and message passing
- Proper isolation and cleanup
- **This is the official standard**

---

### Pattern 2: Custom Mock-Based (INCONSISTENT - Story 19/20)
**Used by**: Story 20 (community events, seasonal events, modifier engine)
**Location**: `testing/unit/community-event-creation.test.lua` (original)

```lua
local json = require("json")

-- Mock AO environment
if not ao then
  ao = {
    send = function(msg)
      print("Mock ao.send:", json.encode(msg))
    end,
    id = "test_process_id"
  }
end

if not Handlers then
  Handlers = {
    _handlers = {},
    add = function(name, matcher, handler)
      Handlers._handlers[name] = {matcher = matcher, handler = handler}
    end
  }
end

-- Load the process directly
dofile("processes/community-event-engine.lua")
```

**Characteristics:**
- No aolite dependency
- Manual mock setup in each test file
- Direct process loading with `dofile()`
- Tests run inline, not through framework
- **NOT consistent with established pattern**

**Why it exists:**
- Story 20 was likely developed independently
- Developer may not have been aware of aolite standard
- Faster to write without framework setup
- Works for basic validation but lacks:
  - Proper process isolation
  - Message queue simulation
  - Scheduler execution
  - Concurrent process testing

---

### Pattern 3: Mock-Aolite (HYBRID - Story 19.6)
**Used by**: Story 19.6 (encounter rewards/consequences)
**Location**: `testing/unit/encounter-reward-calculation.test.lua`

```lua
package.path = package.path .. ";./testing/aolite/?.lua"
local aolite = require("mock-aolite")  -- Lightweight mock

local process = aolite.spawnProcess("encounter-reward-engine", "./processes/encounter-reward-engine.lua")
aolite.send(msg, process)
aolite.runScheduler(process)
```

**Characteristics:**
- Uses `testing/aolite/mock-aolite.lua` (created Oct 8, 2025)
- API-compatible with real aolite
- Lightweight implementation
- No external dependencies
- **Hybrid approach - cleaner than Pattern 2, but not standard**

**Why it exists:**
- Story 19.6 needed aolite-like API without full framework
- `mock-aolite.lua` provides minimal implementation
- Allows tests to look like real aolite tests
- Easier migration path to real aolite

---

## Root Cause Analysis

### Why the Misalignment Happened:

1. **Timing**: Story 20 developed in parallel with Story 19.6
   - Story 20 commit: c295573e4 (Oct 9, 14:50)
   - Story 19.6 commit: 42a5831d1 (unknown, but before Story 20)
   - Different developers or different development sessions

2. **Documentation Gap**:
   - CLAUDE.md specifies test types but not implementation patterns
   - No explicit "use real aolite" requirement documented
   - Examples scattered across codebase

3. **Evolution**:
   - Early stories (Epic 16, 17) established real aolite pattern
   - Later stories (19.6) created mock-aolite for independence
   - Story 20 went rogue with custom mocks

4. **TDD Validation Failure**:
   - TDD script only checks file existence, not content
   - No validation of test framework usage
   - Pattern inconsistency not caught by CI

---

## Impact Analysis

### Current State Issues:

1. **Maintenance Burden**
   - Three different patterns to maintain
   - New developers confused about which to use
   - Inconsistent test behavior

2. **Test Quality Variation**
   - Real aolite: Full process isolation, scheduler, message queues
   - mock-aolite: Basic process emulation
   - Custom mocks: No isolation, limited validation

3. **Migration Risk**
   - 47 tests using custom mock pattern
   - Need migration to real aolite
   - Potential test failures during migration

4. **CI/CD Complexity**
   - Different test execution paths
   - Inconsistent failure modes
   - Harder to debug issues

---

## Recommended Solution

### Short Term (Immediate):
✅ **DONE** - Fixed Story 20 tests to use real aolite (commit 227b95c09)
✅ **DONE** - Fixed narrative-encounter-history.test.lua syntax

### Medium Term (Next Sprint):
1. **Standardize on Real Aolite**
   - Migrate all custom mock tests to real aolite
   - Target: Story 20 feature tests (7 tests)
   - Target: Story 19.6 tests (10 tests using mock-aolite)

2. **Update Documentation**
   - Add explicit test pattern to CLAUDE.md
   - Create test template file
   - Document aolite usage

3. **Enhance TDD Validation**
   - Check for `require("aolite")` in test files
   - Warn on custom mock patterns
   - Validate test structure

### Long Term (Future):
1. **Deprecate mock-aolite.lua**
   - Mark as deprecated
   - Migrate all users to real aolite
   - Remove from codebase

2. **Test Pattern Linting**
   - Add linting rule for test structure
   - Enforce real aolite usage
   - Prevent pattern drift

---

## Migration Strategy

### Phase 1: Critical Path (Week 1)
- [x] Fix Story 20 process-level tests (seasonal-event, modifier, community-event)
- [x] Fix narrative-encounter-history.test.lua
- [ ] Verify all tests pass with real aolite

### Phase 2: Story 20 Feature Tests (Week 2)
- [ ] Migrate community-event-creation.test.lua
- [ ] Migrate community-contribution-tracking.test.lua
- [ ] Migrate community-reward-distribution.test.lua
- [ ] Migrate event-species-generation.test.lua
- [ ] Migrate event-species-collection.test.lua

### Phase 3: Story 19.6 Tests (Week 3)
- [ ] Migrate encounter-reward-calculation.test.lua
- [ ] Migrate encounter-consequence-calculation.test.lua
- [ ] Migrate encounter-consequence-mitigation.test.lua
- [ ] Migrate encounter-exp-scaling.test.lua
- [ ] Migrate encounter-outcome-validation.test.lua
- [ ] Migrate encounter-rarity-scaling.test.lua
- [ ] Migrate special-event-* tests

### Phase 4: Documentation & Prevention (Week 4)
- [ ] Update CLAUDE.md with explicit test pattern
- [ ] Create test template file
- [ ] Add TDD validation for test framework usage
- [ ] Remove deprecated mock-aolite.lua

---

## Lessons Learned

1. **Establish Clear Standards Early**
   - Document testing patterns explicitly
   - Provide templates and examples
   - Enforce through CI/CD

2. **Cross-Story Coordination**
   - Share patterns across parallel development
   - Code review for consistency
   - Regular pattern audits

3. **Progressive Enhancement**
   - Don't create new frameworks without justification
   - Use existing tools when available
   - Document deviations with reasoning

4. **Validation Beyond Existence**
   - Check test content, not just presence
   - Validate framework usage
   - Enforce patterns through tooling

---

## Appendix: Test Pattern Examples

### Example: Real Aolite (STANDARD)
```lua
local aolite = require("aolite")
local json = require("json")

local TEST_TIMEOUT = 30000
local PROCESS_PATH = "processes/my-process.lua"

local process = aolite.spawnProcess(PROCESS_PATH)
if not process then
    error("Failed to spawn process from " .. PROCESS_PATH)
end

local function sendMessage(action, tags, data, timeout)
    local msg = {
        Target = process.id,
        Action = action,
        Data = data or "",
        Timestamp = tostring(os.time() * 1000)
    }
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end
    return aolite.send(msg, timeout or TEST_TIMEOUT)
end

-- Test 1
print("📝 Test 1: Handler Test")
local response = sendMessage("Ping")
if response and response.Action == "Pong" then
    print("✅ Test passed")
else
    error("❌ Test failed")
end
```

---

**Generated**: 2025-10-09
**Author**: Claude Code Analysis
**Status**: Active Investigation
