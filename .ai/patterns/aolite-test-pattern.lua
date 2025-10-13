-- Aolite Test Pattern (REQUIRED)
-- This is the authoritative pattern for all AO process unit tests

-- Required imports
local aolite = require("aolite")  -- Real framework from development-tools/
local json = require("json")

-- Test configuration (Pattern 1: Module Path - RECOMMENDED)
local PROCESS_PATH = "processes.my-process"  -- Dot notation, no .lua extension
local processId = "test-my-process"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for My Process")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,      -- REQUIRED: sender process ID
        Target = processId,     -- Target process ID
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

-- Test 1: Basic functionality
print("📝 Test 1: Process info handler")
local response = sendMessage("Info")
if response and response.Action == "InfoResponse" then
    print("✅ Test 1 passed")
else
    error("❌ Test 1 failed: Expected InfoResponse action")
end

-- Test 2: Error handling
print("📝 Test 2: Error handling for invalid input")
local errorResponse = sendMessage("ProcessData", {
    InvalidParam = "test"
})
if errorResponse and errorResponse.Action == "Error" then
    print("✅ Test 2 passed - Error handling works")
else
    error("❌ Test 2 failed: Expected Error action")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)

-- ALTERNATIVE PATTERN: String Source (use only when needed)
--[[
local PROCESS_PATH = "processes/my-process.lua"
local file = io.open(PROCESS_PATH, "r")
if not file then error("Failed to open: " .. PROCESS_PATH) end
local processSource = file:read("*all")
file:close()
local spawnTags = { { name = "On-Boot", value = "Data" } }
aolite.spawnProcess(processId, processSource, spawnTags)
]]
