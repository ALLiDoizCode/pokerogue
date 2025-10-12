# Test Strategy and Standards

## Testing Philosophy

**Approach:** **Parity-First Test-Driven Development** - Every game mechanic must be validated against TypeScript reference before implementation acceptance
**Coverage Goals:** 100% behavioral parity validation, 95%+ code coverage for critical game logic
**Test Pyramid:** Heavy integration testing for game mechanics, focused unit tests for mathematical calculations

## Test Types and Organization

### Unit Tests

**Framework:** Custom Lua test framework with TypeScript comparison utilities
**File Convention:** `*.test.lua` files co-located with implementation modules
**Location:** `ao-processes/tests/unit/`
**Coverage Requirement:** 100% for stat calculations, 95% for core game logic

**AI Agent Requirements:**
- Generate tests for all public functions automatically
- Cover edge cases and error conditions systematically  
- Follow AAA pattern (Arrange, Act, Assert) consistently
- Mock all external dependencies including RNG and database access

### Integration Tests

**Scope:** Complete handler workflows including message processing, state updates, and response generation
**Location:** `ao-processes/tests/integration/`
**Test Infrastructure:**
  - **Battle State Management:** In-memory test battle creation and cleanup
  - **Message Simulation:** Mock AO message objects for handler testing  
  - **State Validation:** Automated state consistency checking

### End-to-End Tests

**Framework:** Complete game scenario testing with full AO message simulation using aos-local
**Scope:** Multi-turn battles, Pokemon evolution, save/load cycles, agent interaction
**Environment:** Local AO development environment with aos-local process simulation

## Continuous Testing

**CI Integration:** GitHub Actions workflow executing all test suites on every commit
**Performance Tests:** Automated benchmarking comparing Lua vs TypeScript execution times

---

## Aolite Testing Framework (Stories 2.8-2.11)

### Framework Overview

**Aolite** is the local concurrent AO process emulation framework used for unit testing all 77 AO processes.

**Location:** `development-tools/aolite/`
**Test Location:** `testing/unit/*.test.lua`
**Test Command:** `npm run test:aolite`

**Key Capabilities:**
- Concurrent process emulation using Lua coroutines
- Real AO message passing simulation
- Process state inspection and debugging
- Handler validation and coverage tracking

### Correct Aolite API Pattern

**CRITICAL:** All unit tests MUST use this exact pattern (from `.ai/correct-aolite-test-pattern.lua`):

```lua
-- Required imports
local aolite = require("aolite")  -- Real framework, NOT mock-aolite
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes/my-process.lua"
local processId = "test-my-process"  -- String ID, not object

-- Read process source
local file = io.open(PROCESS_PATH, "r")
if not file then
    error("Failed to open process file: " .. PROCESS_PATH)
end
local processSource = file:read("*all")
file:close()

-- Spawn the process (returns nothing)
local spawnTags = { { name = "On-Boot", value = "Data" } }
aolite.spawnProcess(processId, processSource, spawnTags)

print("🧪 Starting Tests for My Process")
print("Process ID:", processId)

-- Test utility for message passing
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,      -- REQUIRED: sender process ID
        Target = processId,     -- Target process ID
        Action = action,
        Data = data or ""
    }

    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)  -- All tag values must be strings
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)  -- Separate retrieval
end

-- Test 1: Basic functionality
print("📝 Test 1: Process info handler")
local response = sendMessage("Info")
if response and response.Action == "SaveState" then
    print("✅ Test 1 passed")
else
    error("❌ Test 1 failed: Expected SaveState action")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
```

**Critical API Requirements:**
1. ✅ `aolite.spawnProcess(processId, source, tags)` - Returns nothing
2. ✅ `processId` is a string (e.g., "test-my-process")
3. ✅ Include `From: processId` in all messages (REQUIRED)
4. ✅ Use `aolite.send(msg)` then `aolite.getLastMsg(processId)` separately
5. ✅ Use `error()` for test failures with explicit messages
6. ✅ Use `print()` for test output with emojis (📝, ✅, ❌)

### Linear Execution Pattern

**Architecture Constraint:** Aolite uses coroutine-based process emulation with linear test execution.

**Pattern Requirements:**
- Tests execute sequentially, top-to-bottom
- Single process spawn per test file
- No describe/it blocks (incompatible with aolite architecture)
- No before_each/after_each hooks
- Inline setup at file start

**Why Linear Execution:**
- describe/it frameworks require test isolation (before_each/after_each)
- Aolite uses single process instance with sequential execution
- Linear pattern resolves architectural incompatibility

### Test Pattern Selection

**Pattern 1: Independent Tests (PREFERRED)**

Use when tests don't depend on execution order or shared state.

```lua
-- Test 1: Query Pikachu (independent)
local response1 = sendMessage("GetSpecies", nil, json.encode({speciesId = 25}))

-- Test 2: Query Mewtwo (independent of Test 1)
local response2 = sendMessage("GetSpecies", nil, json.encode({speciesId = 150}))

-- Test 3: Invalid ID (independent error handling)
local response3 = sendMessage("GetSpecies", nil, json.encode({speciesId = 9999}))
```

**Advantages:**
- ✅ Tests can run in any order
- ✅ Easy to add/remove/reorder tests
- ✅ No state contamination
- ✅ Simple debugging

**Use Cases:** Data queries, read-only operations, stateless handlers

**Pattern 2: State-Dependent Test Sequences (USE CAUTIOUSLY)**

Use when tests intentionally build state across sequence.

```lua
-- Test 1: Initialize battle
local createResponse = sendMessage("CreateBattle", {PlayerId = "player1"})
local battleId = createResponse.BattleId  -- Extract state

-- Test 2: Add Pokemon (DEPENDS on Test 1 state)
local addResponse = sendMessage("AddPokemon", {
    BattleId = battleId,  -- Uses state from Test 1
    PokemonId = "25"
})

-- Test 3: Start battle (DEPENDS on Test 1 and 2)
local startResponse = sendMessage("StartBattle", {BattleId = battleId})
```

**Advantages:**
- ✅ Tests real workflow progression
- ✅ Validates state transitions
- ✅ Mimics actual usage patterns

**Disadvantages:**
- ⚠️ Tests must run in specific order
- ⚠️ Failed test breaks subsequent tests
- ⚠️ Harder to debug specific test

**Use Cases:** Battle flow, dialogue progression, state machines

**Pattern 3: State Reset Between Tests**

Use when tests need isolation but share process instance.

```lua
local stateUtils = require("testing.utils.state-management")

-- Test 1: Create battle
local response1 = sendMessage("CreateBattle", {PlayerId = "p1"})
stateUtils.resetProcessState(processId)  -- Reset after test

-- Test 2: Create battle (isolated from Test 1)
local response2 = sendMessage("CreateBattle", {PlayerId = "p2"})
stateUtils.resetProcessState(processId)  -- Reset after test
```

**Use Cases:** When isolation needed but Pattern 1 insufficient

### Handler Discovery Workflow

**Automated Handler Inspection Tool:** `scripts/inspect-process-handlers.sh`

**Usage:**
```bash
# Inspect process handlers
./scripts/inspect-process-handlers.sh processes/pokemon-species-db.lua

# Output: Handler list with action names and response patterns
```

**ADP v1.0 Info Handler:**

Query process capabilities programmatically:

```lua
-- Query Info handler for self-documentation
local infoResponse = sendMessage("Info")
local processInfo = json.decode(infoResponse.Data)

-- Access capabilities
local handlers = processInfo.handlers
local schemas = processInfo.process.messageSchemas
```

**Benefits:**
- Eliminates manual handler inspection overhead
- Standardizes process self-documentation
- Enables automated test generation
- Reduces test development time from 45-60 min to <30 min

### Handler Coverage Validation

**Coverage Tool:** `scripts/validate-handler-coverage.lua`
**Coverage Command:** `npm run coverage:handlers`
**Coverage Report:** `docs/qa/handler-coverage-report.md`

**Coverage Calculation:**
```
Coverage = (Tested Handlers / Total Handlers) × 100%
```

**Quality Gate:**
- Minimum threshold: 80% handler coverage
- CI/CD blocks merge if coverage decreases
- Per-process exceptions allowed with justification

**Coverage Report Format:**
```markdown
# Handler Coverage Report

## Overall Coverage
- Total Handlers: 125
- Tested Handlers: 95
- Coverage: 76%

## Per-Process Coverage
| Process | Handlers | Tested | Coverage |
|---------|----------|--------|----------|
| pokemon-species-db.lua | 5 | 5 | 100% ✅ |
| battle-engine.lua | 15 | 12 | 80% ⚠️ |

## Untested Handlers
### battle-engine.lua
- ApplyWeatherEffect
- RemoveFieldCondition
```

### State Management Utilities

**Library:** `testing/utils/state-management.lua`

**Available Utilities:**
```lua
-- Reset process state between tests
resetProcessState(processId)

-- Validate state matches expectations
local valid, diff = validateState(processId, {hp = 100, level = 50})

-- Snapshot and restore state
local snapshot = snapshotState(processId)
-- ... run test ...
restoreState(processId, snapshot)
```

**State Management Decision Tree:**
1. **Are tests independent?** → No state management needed (Pattern 1)
2. **Do tests intentionally build state?** → State-dependent sequence (Pattern 2)
3. **Do tests need isolation?** → State reset between tests (Pattern 3)

### Test Pattern Validation

**Pre-Commit Hook:** `scripts/hooks/tdd-pre-commit.sh`

**Validation Checks:**
1. ✅ Correct aolite API usage: `aolite.spawnProcess()`, `aolite.send()`, `aolite.getLastMsg()`
2. ✅ Forbidden pattern detection: No describe/it blocks
3. ✅ sendMessage pattern: `From` field required
4. ✅ Tag stringification: All tag values are strings

**CI/CD Integration:**
- Pattern validation in GitHub Actions
- Builds fail on pattern violations
- Detailed error messages with line numbers
- Links to correct pattern reference

### Common Pitfalls to Avoid

**Forbidden Patterns:**
```lua
-- ❌ FORBIDDEN: Old aolite API
local process = aolite.spawnProcess(PROCESS_PATH)  -- Returns object (old)
Target = process.id  -- process.id doesn't exist (old)

-- ❌ FORBIDDEN: describe/it blocks
describe("My Process", function()
    it("should work", function() end)
end)

-- ❌ FORBIDDEN: Missing From field
local msg = {Target = processId, Action = "Test"}
aolite.send(msg)  -- Missing From field

-- ❌ FORBIDDEN: Direct send response retrieval
local response = aolite.send(msg)  -- Doesn't return response
```

**Correct Patterns:**
```lua
-- ✅ CORRECT: New aolite API
aolite.spawnProcess(processId, source, tags)  -- Returns nothing
From = processId, Target = processId  -- Both required

-- ✅ CORRECT: Linear execution
print("📝 Test 1")
local response = sendMessage("Action1")

-- ✅ CORRECT: Include From field
local msg = {From = processId, Target = processId, Action = "Test"}
aolite.send(msg)

-- ✅ CORRECT: Separate send and retrieval
aolite.send(msg)
local response = aolite.getLastMsg(processId)
```

### Success Metrics

**Development Velocity:**
- Target: <30 minutes to write new test for existing process
- Current: Achieved via handler discovery automation

**Test Maintenance:**
- Target: <15 minutes to update test after process changes
- Current: Achieved via action naming conventions

**Test Reliability:**
- Target: 0% flaky tests, 100% reproducible pass/fail
- Current: Linear execution eliminates flakiness

**Handler Coverage:**
- Target: 100% of process handlers validated by at least one test
- Current: 76% (95/125 handlers), tracking enabled

### Training Resources

**Quick Reference:** `docs/guides/tdd-quick-reference.md`
**Test Development Guide:** `docs/guides/test-development-guide.md`
**Test Pattern Template:** `.ai/correct-aolite-test-pattern.lua`
**Troubleshooting Guide:** See Test Development Guide

**Key Commands:**
```bash
# Run unit tests
npm run test:aolite

# Check handler coverage
npm run coverage:handlers

# Inspect process handlers
./scripts/inspect-process-handlers.sh processes/FILE.lua

# Validate test patterns (pre-commit)
./scripts/hooks/tdd-pre-commit.sh
```
