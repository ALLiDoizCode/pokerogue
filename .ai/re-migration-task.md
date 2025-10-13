# Aolite Test Re-Migration Task

## Objective
Migrate assigned test files from incorrect aolite API to correct API.

## Reference: Correct Pattern

**BEFORE (Incorrect - currently in files):**
```lua
local aolite = require("aolite")
local json = require("json")

local TEST_TIMEOUT = 30000
local PROCESS_PATH = "processes/my-process.lua"

local process = aolite.spawnProcess(PROCESS_PATH)
if not process then
    error("Failed to spawn process from " .. PROCESS_PATH)
end

print("Process ID:", process.id)

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
```

**AFTER (Correct - what files should become):**
```lua
local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes/my-process.lua"
local processId = "test-my-process"  -- Extract from PROCESS_PATH

-- Read process source
local file = io.open(PROCESS_PATH, "r")
if not file then
    error("Failed to open process file: " .. PROCESS_PATH)
end
local processSource = file:read("*all")
file:close()

-- Spawn the process
local spawnTags = { { name = "On-Boot", value = "Data" } }
aolite.spawnProcess(processId, processSource, spawnTags)

print("Process ID:", processId)

local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
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
```

## Key Changes Required

1. **Remove** `TEST_TIMEOUT` variable
2. **Add** `processId` variable (derive from PROCESS_PATH: `"processes/foo.lua"` → `"test-foo"`)
3. **Add** file reading logic to load process source code
4. **Change** `aolite.spawnProcess(PROCESS_PATH)` to `aolite.spawnProcess(processId, processSource, spawnTags)`
5. **Change** `process.id` references to `processId`
6. **Change** `sendMessage` function:
   - Remove `timeout` parameter
   - Add `From: processId` field
   - Remove `Timestamp` field
   - Replace `return aolite.send(msg, timeout or TEST_TIMEOUT)` with `aolite.send(msg); return aolite.getLastMsg(processId)`
7. **Update** header comment to include "(CORRECT API)"

## Example Migration

See `/Users/jonathangreen/Documents/pokerogue/testing/unit/pokemon-species-db.test.lua` for complete reference.

## Validation

Each migrated file should:
1. Use `processId` string variable, not `process` object
2. Read process source from file using `io.open()`
3. Call `aolite.spawnProcess(processId, processSource, spawnTags)`
4. `sendMessage` includes `From: processId`
5. Retrieve responses with `aolite.getLastMsg(processId)`
6. No references to `process.id`, `TEST_TIMEOUT`, or `Timestamp`

## Files to Migrate
[Agent will receive specific file list]
