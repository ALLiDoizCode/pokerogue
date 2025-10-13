# Aolite Test Re-Migration Task

## Objective
Migrate test files from INCORRECT aolite API pattern to CORRECT aolite API pattern.

## Reference Files
- **Correct Pattern Template**: `.ai/correct-aolite-test-pattern.lua`
- **Successfully Migrated Example**: `testing/unit/pokemon-species-db.test.lua`

## INCORRECT Pattern (What You'll Find)
```lua
local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes/my-process.lua"
local process = aolite.spawnProcess(PROCESS_PATH)  -- ❌ Returns object with .id

local function sendMessage(action, tags, data, timeout)
    local msg = {
        Target = process.id,  -- ❌ process.id doesn't exist
        Action = action,
        Data = data or "",
        Timestamp = tostring(os.time() * 1000)  -- ❌ os.time() forbidden
    }
    -- ...
    return aolite.send(msg, timeout)  -- ❌ send() doesn't return response
end
```

## CORRECT Pattern (What You Must Create)
```lua
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes/my-process.lua"
local processId = "test-my-process"  -- ✅ Derive from process name

-- Read process source
local file = io.open(PROCESS_PATH, "r")
if not file then
    error("Failed to open process file: " .. PROCESS_PATH)
end
local processSource = file:read("*all")
file:close()

-- Spawn the process with source code
local spawnTags = { { name = "On-Boot", value = "Data" } }
aolite.spawnProcess(processId, processSource, spawnTags)  -- ✅ (id, source, tags)

print("🧪 Starting Aolite Tests for My Process")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,      -- ✅ REQUIRED: sender process ID
        Target = processId,     -- ✅ Target process ID
        Action = action,
        Data = data or ""
    }

    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)  -- ✅ Send only, no return value
    return aolite.getLastMsg(processId)  -- ✅ Retrieve separately
end
```

## Key API Changes
1. **spawnProcess signature**: `(processId, source, tags)` not `(path)`
2. **Read source**: Use `io.open()` and `file:read("*all")` to read process source code
3. **Process ID**: String variable (e.g., "test-pokemon-species-db"), not object
4. **Message From field**: REQUIRED, set to `processId`
5. **Message retrieval**: Use `aolite.getLastMsg(processId)` after `aolite.send(msg)`
6. **No Timestamp**: Remove `Timestamp = tostring(os.time() * 1000)` from messages
7. **No TEST_TIMEOUT**: Remove timeout parameters (real aolite auto-schedules)

## Process ID Naming Convention
Derive from process file name:
- `processes/pokemon-species-db.lua` → `"test-pokemon-species-db"`
- `processes/battle-engine.lua` → `"test-battle-engine"`
- `processes/encounter-reward-calculation.lua` → `"test-encounter-reward-calculation"`

## Migration Steps (FOR EACH FILE)

1. **Read the original test file** to understand test structure
2. **Identify PROCESS_PATH** (e.g., "processes/X.lua")
3. **Derive processId** from process name (e.g., "test-X")
4. **Replace aolite.spawnProcess() call** with:
   ```lua
   local processId = "test-X"
   local file = io.open(PROCESS_PATH, "r")
   if not file then
       error("Failed to open process file: " .. PROCESS_PATH)
   end
   local processSource = file:read("*all")
   file:close()

   local spawnTags = { { name = "On-Boot", value = "Data" } }
   aolite.spawnProcess(processId, processSource, spawnTags)
   ```
5. **Update sendMessage() function** to include `From` field and use `getLastMsg()`
6. **Remove all references to `process.id`** → replace with `processId`
7. **Remove `Timestamp` fields** from messages
8. **Remove `TEST_TIMEOUT` variable** and timeout parameters
9. **Preserve all test logic** - only change aolite API usage
10. **Keep print statements** with emojis (📝, ✅, ❌)

## Example Diff (Conceptual)

```diff
-local TEST_TIMEOUT = 30000
 local PROCESS_PATH = "processes/pokemon-species-db.lua"
-local process = aolite.spawnProcess(PROCESS_PATH)
-if not process then
+local processId = "test-pokemon-species-db"
+
+local file = io.open(PROCESS_PATH, "r")
+if not file then
-    error("Failed to spawn process from " .. PROCESS_PATH)
+    error("Failed to open process file: " .. PROCESS_PATH)
 end
+local processSource = file:read("*all")
+file:close()
+
+local spawnTags = { { name = "On-Boot", value = "Data" } }
+aolite.spawnProcess(processId, processSource, spawnTags)

-local function sendMessage(action, tags, data, timeout)
+local function sendMessage(action, tags, data)
     local msg = {
-        Target = process.id,
+        From = processId,
+        Target = processId,
         Action = action,
         Data = data or ""
-        Timestamp = tostring(os.time() * 1000)
     }

     if tags then
         for k, v in pairs(tags) do
             msg[k] = tostring(v)
         end
     end

-    return aolite.send(msg, timeout or TEST_TIMEOUT)
+    aolite.send(msg)
+    return aolite.getLastMsg(processId)
 end
```

## Critical Rules
- ✅ PRESERVE all test logic and assertions
- ✅ PRESERVE all print statements
- ✅ PRESERVE test structure (linear execution with error())
- ✅ ONLY change aolite API calls
- ❌ DO NOT add describe/it blocks
- ❌ DO NOT change test names or descriptions
- ❌ DO NOT skip or remove tests

## Validation
After migration, the test file should:
1. Run successfully with `npm run test:aolite -- testing/unit/FILE.test.lua`
2. Contain `From = processId` in sendMessage function
3. Contain `aolite.getLastMsg(processId)` for response retrieval
4. NOT contain `process.id`, `Timestamp`, or `TEST_TIMEOUT`

## Your Task
You will be given a list of 10-15 test files. For EACH file:
1. Read the file
2. Apply the migration pattern above
3. Write the migrated file back
4. Move to the next file

**DO NOT attempt to run tests** - just migrate the files. Testing will be done in batch after all migrations complete.
