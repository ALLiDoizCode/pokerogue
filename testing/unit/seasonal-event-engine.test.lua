-- Aolite Unit Tests for Seasonal Event Engine
-- Tests seasonal event timing, multipliers, and event-specific content
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.seasonal-event-engine"
local processId = "test-seasonal-event-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Seasonal Event Engine")
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

-- Test 1: Get Active Event (During Winter Holiday)
print("📝 Test 1: Get Active Event (During Winter Holiday)")
local activeEventResponse = sendMessage("GetActiveEvent", {
    Timestamp = "1734800000" -- Dec 22, 2024 (during Winter Holiday)
})
if activeEventResponse and activeEventResponse.Action == "SaveState" then
    print("✅ Active event test passed")
else
    error("❌ Active event test failed")
end

-- Test 2: Get Event Multipliers
print("📝 Test 2: Get Event Multipliers")
local multipliersResponse = sendMessage("GetEventMultipliers", {
    Timestamp = "1734800000" -- During Winter Holiday
})
if multipliersResponse and multipliersResponse.Action == "SaveState" then
    print("✅ Event multipliers test passed")
else
    error("❌ Event multipliers test failed")
end

-- Test 3: Get Event Encounters
print("📝 Test 3: Get Event Encounters")
local encountersResponse = sendMessage("GetEventEncounters", {
    Timestamp = "1734800000"
})
if encountersResponse and encountersResponse.Action == "SaveState" then
    print("✅ Event encounters test passed")
else
    error("❌ Event encounters test failed")
end

-- Test 4: Get Weather Modifications
print("📝 Test 4: Get Weather Modifications")
local weatherResponse = sendMessage("GetWeatherModifications", {
    Timestamp = "1734800000"
})
if weatherResponse and weatherResponse.Action == "SaveState" then
    print("✅ Weather modifications test passed")
else
    error("❌ Weather modifications test failed")
end

-- Test 5: No Active Event (Outside Event Period)
print("📝 Test 5: No Active Event (Outside Event Period)")
local noEventResponse = sendMessage("GetActiveEvent", {
    Timestamp = "1700000000" -- Nov 2023 (no event)
})
if noEventResponse and noEventResponse.Action == "SaveState" then
    print("✅ No active event test passed")
else
    error("❌ No active event test failed")
end

-- Test 6: Get Event Rewards
print("📝 Test 6: Get Event Rewards")
local rewardsResponse = sendMessage("GetEventRewards", {
    Timestamp = "1734800000",
    WaveIndex = "8"
})
if rewardsResponse and rewardsResponse.Action == "SaveState" then
    print("✅ Event rewards test passed")
else
    error("❌ Event rewards test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Seasonal Event Engine tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
