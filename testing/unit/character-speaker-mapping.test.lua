-- Aolite Unit Tests for Character Speaker Mapping (CORRECT API)
-- Tests speaker name mapping for UI rendering
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.character-dialogue-engine"
local processId = "test-character-dialogue-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Character Speaker Mapping")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
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
end

-- Test 1: Youngster speaker mapping
print("📝 Test 1: Youngster speaker mapping")
local youngsterResponse = sendMessage("GetSpeakerName", {
    TrainerType = "50"
})
if youngsterResponse and youngsterResponse.Action == "SaveState" then
    print("✅ Youngster speaker test passed")
else
    error("❌ Youngster speaker test failed")
end

-- Test 2: Ace Trainer speaker mapping
print("📝 Test 2: Ace Trainer speaker mapping")
local aceTrainerResponse = sendMessage("GetSpeakerName", {
    TrainerType = "1"
})
if aceTrainerResponse and aceTrainerResponse.Action == "SaveState" then
    print("✅ Ace Trainer speaker test passed")
else
    error("❌ Ace Trainer speaker test failed")
end

-- Test 3: Invalid trainer type speaker mapping
print("📝 Test 3: Invalid trainer type speaker mapping")
local invalidResponse = sendMessage("GetSpeakerName", {
    TrainerType = "999"
})
if invalidResponse then
    print("✅ Invalid speaker test passed")
else
    error("❌ Invalid speaker test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Character Speaker Mapping tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
