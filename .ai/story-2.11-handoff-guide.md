# Story 2.11 Migration Handoff Guide

## Quick Status
- ✅ 25/82 tests complete (30%)
- ✅ 2/6 files fully passing
- ⏳ 3.5 files remaining (2-3 hours estimated)

## Completed Files (Use as Templates)
1. `testing/unit/event-species-collection.test.lua` - 10 tests PASSING
2. `testing/unit/event-species-generation.test.lua` - 15 tests PASSING

## Remaining Work

### File 3: narrative-progress-validation.test.lua (30 min)
**Status**: Migrated but needs Data parsing fixes
**Issue**: Tests 3-6, 9, 12-13 expect response fields as tags, but they're in Data JSON

**Fix Pattern** (apply to failing tests):
```lua
-- ❌ OLD (incorrect):
if response3 and response3.Valid == "true" then

-- ✅ NEW (correct):
if response3 and response3.Data then
    local data3 = json.decode(response3.Data)
    if data3.valid == true then
```

**Tests needing fixes**: 3, 4, 5, 6, 9, 12, 13

### File 4: narrative-queued-encounters.test.lua (60-75 min)
**Status**: Not started
**Process**: narrative-state-engine
**Handlers**: QueueEncounter, GetQueuedEncounters, DequeueEncounter
**Pattern**: Same as narrative-progress-validation (responses in Data JSON)

### File 5: narrative-spawn-probability.test.lua (60-75 min)
**Status**: Not started
**Process**: narrative-state-engine
**Handlers**: UpdateSpawnProbability, RecordEncounterCompletion
**Pattern**: Same as narrative-progress-validation (responses in Data JSON)

### File 6: fusion-content-engine.test.lua (90-120 min)
**Status**: Not started
**Process**: fusion-content-engine
**Handlers**: GenerateFusionName, GenerateFusionMovePool, ValidateFusionContent, ResolveFusionContentConflicts, CalculateContentPrecision
**Complexity**: Most complex file (19 tests, fusion logic)

## Migration Template

```lua
-- Header (copy from completed files)
local aolite = require("aolite")
local json = require("json")

-- Test configuration (Story 2.10 optimized pattern)
local PROCESS_PATH = "processes.PROCESS_NAME"
local processId = "test-PROCESS_NAME"
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for PROCESS_NAME")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,  -- REQUIRED
        Target = processId,
        Action = action,
        Data = data or ""
    }
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end
    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test N: Description
print("📝 Test N: Description")
local responseN = sendMessage("ActionName", {
    Param1 = "value",
    UniqueId = "test-scenario-N"  -- State isolation
})
if responseN and responseN.Data then
    local dataN = json.decode(responseN.Data)
    if dataN.expectedField == expectedValue then
        print("✅ Test N passed")
    else
        error("❌ Test N failed: Expected X, got Y")
    end
else
    error("❌ Test N failed: Expected valid response")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ N/N DESCRIPTION tests completed")
```

## Key Migration Steps

1. **Remove describe/it blocks** → Linear test execution
2. **Update spawning**: Use module path pattern
3. **Add state isolation**: Unique IDs per test
4. **Fix message format**: Include `From` and `Target`
5. **Parse Data JSON**: Most responses have data in Data field
6. **Convert assertions**: `assert.are.equal()` → `if/else with error()`

## Common Patterns

### State Isolation IDs
- seasonal-event-engine: `EventId = "test-event-N"`
- narrative-state-engine: `NarrativeId = "test-narrative-N"`
- fusion-content-engine: `FusionId = "test-fusion-N"`

### Response Parsing
```lua
-- For responses with Data JSON:
if response and response.Data then
    local data = json.decode(response.Data)
    -- Access data.field
end

-- For error responses:
if response and response.Action == "Error" then
    if string.match(response.Error or "", "expected text") then
        print("✅ Test passed")
    end
end
```

### Loop Patterns (from original tests)
```lua
-- Original describe/it loop:
for i = 1, 3 do
    it("should X", function()
        -- test
    end)
end

-- Migrated linear loop:
for i = 1, 3 do
    sendMessage("Action", {
        Param = tostring(i),
        UniqueId = "test-scenario-" .. i
    })
end
-- Then validate after loop
```

## Testing Commands

**Test single file:**
```bash
export LUA_PATH="./?.lua;./testing/unit/?.lua;./testing/aolite/?.lua;./processes/?.lua;./test/unit/?.lua;./development-tools/aolite/lua/?/init.lua;./development-tools/aolite/lua/?.lua;./development-tools/aolite/lua/aolite/?.lua;./development-tools/aolite/lua/aolite/lib/?.lua;./development-tools/aolite/lua/aolite/factories/?.lua" && lua testing/unit/FILE_NAME.test.lua
```

**Test all migrated files:**
```bash
npm run test:aolite
```

## Completion Checklist

- [ ] Fix narrative-progress-validation.test.lua (Tests 3-6, 9, 12-13)
- [ ] Migrate narrative-queued-encounters.test.lua (12 tests)
- [ ] Migrate narrative-spawn-probability.test.lua (13 tests)
- [ ] Migrate fusion-content-engine.test.lua (19 tests)
- [ ] Run `npm run test:aolite` - verify 82/82 tests pass
- [ ] Update story status to "Done"
- [ ] Update story File List section
- [ ] Run pre-commit validation

## Quick Debug Tips

**If test fails with "Expected X":**
1. Add debug output: `print("Response:", json.encode(response))`
2. Check if field is in Data JSON vs direct tag
3. Verify state isolation (unique IDs used?)

**If handler not found:**
1. Check handler name spelling/case
2. Run: `./scripts/inspect-process-handlers.sh PROCESS_NAME`
3. Verify Action name matches handler exactly

**If state accumulates between tests:**
1. Add unique ID to each test: `NarrativeId = "test-scenario-N"`
2. Increment N for each test scenario

## Reference Files
- ✅ `testing/unit/event-species-collection.test.lua` (simple, 10 tests)
- ✅ `testing/unit/event-species-generation.test.lua` (medium, 15 tests)
- 📖 `.ai/correct-aolite-test-pattern.lua` (pattern template)
- 📋 `docs/stories/2.11.story.md` (full handoff notes)

## Success Criteria
- All 82 tests passing
- No describe/it blocks remaining
- All tests use Story 2.10 optimized pattern (module path spawning)
- State isolation applied consistently
- Pre-commit validation passes
