-- CORRECT Aolite Test Pattern (Real Framework)
-- This is the authoritative template for all aolite-based unit tests
-- Based on official aolite API from development-tools/aolite/examples/

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local TEST_TIMEOUT = 30000 -- 30 seconds (not used with real aolite auto-scheduling)
local PROCESS_PATH = "processes.my-process"  -- Module path (dot notation, no .lua extension)

-- Spawn the process
-- NOTE: aolite supports two spawning patterns:
--   1. String source: aolite.spawnProcess(id, sourceCode, {{"On-Boot", "Data"}})
--   2. Module path: aolite.spawnProcess(id, "processes.my-process") (PREFERRED for tests)
-- Module path pattern is cleaner, matches aolite examples, and reduces boilerplate
local processId = "test-my-process"
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for My Process")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,  -- REQUIRED: sender process ID
        Target = processId,  -- Target process ID
        Action = action,
        Data = data or ""
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    -- Send message (auto-schedules with default aolite config)
    aolite.send(msg)

    -- Retrieve response
    local response = aolite.getLastMsg(processId)
    return response
end

-- Test 1: Basic functionality
print("📝 Test 1: Process initialization (Info handler)")
local response = sendMessage("Info")
if response and response.Action == "InfoResponse" then
    print("✅ Test 1 passed")
else
    error("❌ Test 1 failed: Expected InfoResponse, got " .. tostring(response and response.Action))
end

-- Test 2: Handler with tags
print("📝 Test 2: Handler with custom tags")
local response2 = sendMessage("ProcessData", {
    CustomTag = "value"
}, json.encode({ test = "data" }))
if response2 and response2.Action == "SaveState" then
    print("✅ Test 2 passed")
else
    error("❌ Test 2 failed: Expected SaveState action")
end

-- Test 3: Error handling
print("📝 Test 3: Error handling for invalid input")
local response3 = sendMessage("ProcessData", {
    InvalidParam = "test"
})
if response3 and response3.Action == "Error" then
    print("✅ Test 3 passed - Error handling works")
else
    error("❌ Test 3 failed: Expected Error action")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
