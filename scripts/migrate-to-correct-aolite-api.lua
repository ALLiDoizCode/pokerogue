#!/usr/bin/env lua

-- Migration Script: Correct Aolite API Pattern
-- Migrates test files from incorrect API to correct real aolite API
--
-- INCORRECT PATTERN:
--   local process = aolite.spawnProcess(PROCESS_PATH)
--   local msg = { Target = process.id, ... }
--   return aolite.send(msg, timeout)
--
-- CORRECT PATTERN:
--   local processId = "test-name"
--   local file = io.open(PROCESS_PATH, "r")
--   local source = file:read("*all")
--   file:close()
--   aolite.spawnProcess(processId, source, tags)
--   aolite.send({ From = processId, Target = processId, ... })
--   return aolite.getLastMsg(processId)

local function migrateTestFile(filePath)
    print("Migrating: " .. filePath)

    -- Read the file
    local file = io.open(filePath, "r")
    if not file then
        error("Failed to open file: " .. filePath)
    end
    local content = file:read("*all")
    file:close()

    -- Extract PROCESS_PATH value
    local processPath = content:match('PROCESS_PATH%s*=%s*"([^"]+)"')
    if not processPath then
        print("  ⚠️  Could not find PROCESS_PATH, skipping")
        return false
    end

    -- Generate processId from process path
    local processName = processPath:match("processes/([^%.]+)%.lua")
    local processId = "test-" .. processName

    -- Step 1: Replace process spawning
    local newContent = content

    -- Remove TEST_TIMEOUT line (no longer needed)
    newContent = newContent:gsub("local TEST_TIMEOUT[^\n]+\n", "")

    -- Replace process spawning block
    local spawnPattern = "local PROCESS_PATH = \"([^\"]+)\"\n\n%-%- Initialize test process\nlocal process = aolite%.spawnProcess%(PROCESS_PATH%)\nif not process then\n    error%(\"Failed to spawn process from \" %.%. PROCESS_PATH%)\nend"

    local spawnReplacement = string.format([[local PROCESS_PATH = "%s"
local processId = "%s"

-- Read process source
local file = io.open(PROCESS_PATH, "r")
if not file then
    error("Failed to open process file: " .. PROCESS_PATH)
end
local processSource = file:read("*all")
file:close()

-- Spawn the process
local spawnTags = { { name = "On-Boot", value = "Data" } }
aolite.spawnProcess(processId, processSource, spawnTags)]], processPath, processId)

    newContent = newContent:gsub(spawnPattern, spawnReplacement)

    -- Step 2: Replace print("Process ID:", process.id) with print("Process ID:", processId)
    newContent = newContent:gsub('print%("Process ID:", process%.id%)', 'print("Process ID:", processId)')

    -- Step 3: Replace sendMessage function
    local sendMsgPattern = "local function sendMessage%(action, tags, data, timeout%)\n    local msg = {\n        Target = process%.id,\n        Action = action,\n        Data = data or \"\",\n        Timestamp = tostring%(os%.time%(%) %* 1000%)\n    }%s*\n%s*%-%- Add additional tags\n    if tags then\n        for k, v in pairs%(tags%) do\n            msg%[k%] = tostring%(v%)\n        end\n    end%s*\n%s*return aolite%.send%(msg, timeout or TEST_TIMEOUT%)\nend"

    local sendMsgReplacement = [[local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end]]

    newContent = newContent:gsub(sendMsgPattern, sendMsgReplacement)

    -- Step 4: Update comment header to indicate correct API
    newContent = newContent:gsub("Compatible with aolite testing framework", "Compatible with aolite testing framework (CORRECT API)")

    -- Write the migrated content
    local outFile = io.open(filePath, "w")
    if not outFile then
        error("Failed to write to file: " .. filePath)
    end
    outFile:write(newContent)
    outFile:close()

    print("  ✅ Migrated successfully")
    return true
end

-- Main execution
local function main()
    local testFiles = {
        -- Phase 1: Story 19.6 tests (11 files)
        "testing/unit/encounter-reward-calculation.test.lua",
        "testing/unit/encounter-consequence-calculation.test.lua",
        "testing/unit/encounter-consequence-mitigation.test.lua",
        "testing/unit/encounter-exp-scaling.test.lua",
        "testing/unit/encounter-outcome-validation.test.lua",
        "testing/unit/encounter-rarity-scaling.test.lua",
        "testing/unit/special-event-duration.test.lua",
        "testing/unit/special-event-effects.test.lua",
        "testing/unit/special-event-encounters.test.lua",
        "testing/unit/special-event-rewards.test.lua",
        "testing/unit/special-event-trigger.test.lua",

        -- Add more files as needed...
    }

    print("🚀 Starting Aolite API Migration")
    print("Total files to migrate: " .. #testFiles)
    print("")

    local successCount = 0
    local failureCount = 0

    for _, filePath in ipairs(testFiles) do
        local success, err = pcall(function()
            return migrateTestFile(filePath)
        end)

        if success and err then
            successCount = successCount + 1
        else
            failureCount = failureCount + 1
            if not success then
                print("  ❌ Error: " .. tostring(err))
            end
        end
    end

    print("")
    print("=" .. string.rep("=", 60))
    print(string.format("Migration Complete: %d succeeded, %d failed", successCount, failureCount))
    print("=" .. string.rep("=", 60))
end

-- Run if executed directly
if arg[0]:match("migrate%-to%-correct%-aolite%-api%.lua$") then
    main()
end

return {
    migrateTestFile = migrateTestFile
}
