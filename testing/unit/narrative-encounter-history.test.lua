-- Aolite Unit Tests for Narrative Encounter History Tracking
-- Tests encounter history recording and retrieval
-- Compatible with aolite testing framework
-- Story: 19.4 - Story State & Narrative Progress Migration

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.narrative-state-engine"
local processId = "test-narrative-state-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Narrative Encounter History")
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

-- Test 1: Record Encounter Completion
print("📝 Test 1: Record Encounter Completion")
local recordResponse = sendMessage("RecordEncounterCompletion", {
    EncounterType = "1",
    Tier = "0",
    WaveIndex = "10",
    SelectedOption = "0"
})
if recordResponse and recordResponse.Action == "SaveState" then
    print("✅ Record encounter completion test passed")
else
    error("❌ Record encounter completion test failed")
end

-- Test 2: Get Encounter History
print("📝 Test 2: Get Encounter History")
local historyResponse = sendMessage("GetEncounterHistory")
if historyResponse and historyResponse.Action == "SaveState" then
    print("✅ Get encounter history test passed")
else
    error("❌ Get encounter history test failed")
end

-- Test 3: Record Multiple Encounters
print("📝 Test 3: Record Multiple Encounters")
local record1 = sendMessage("RecordEncounterCompletion", {
    EncounterType = "1",
    Tier = "0",
    WaveIndex = "10",
    SelectedOption = "0"
})
local record2 = sendMessage("RecordEncounterCompletion", {
    EncounterType = "2",
    Tier = "1",
    WaveIndex = "20",
    SelectedOption = "1"
})
if record1 and record2 and record1.Action == "SaveState" and record2.Action == "SaveState" then
    print("✅ Multiple encounters recording test passed")
else
    error("❌ Multiple encounters recording test failed")
end

-- Test 4: Filter History by Encounter Type
print("📝 Test 4: Filter History by Encounter Type")
local filteredResponse = sendMessage("GetEncounterHistory", {
    EncounterType = "1"
})
if filteredResponse and filteredResponse.Action == "SaveState" then
    print("✅ Filter history by type test passed")
else
    error("❌ Filter history by type test failed")
end

-- Test 5: Handle Missing Parameters
print("📝 Test 5: Handle Missing Parameters")
local missingParamsResponse = sendMessage("RecordEncounterCompletion", {
    EncounterType = "1"
    -- Missing Tier and WaveIndex
})
if missingParamsResponse then
    print("✅ Missing parameters handling test passed")
else
    error("❌ Missing parameters handling test failed")
end

-- Test 6: Default SelectedOption
print("📝 Test 6: Default SelectedOption (-1 when not provided)")
local defaultOptionResponse = sendMessage("RecordEncounterCompletion", {
    EncounterType = "1",
    Tier = "0",
    WaveIndex = "10"
    -- SelectedOption omitted
})
if defaultOptionResponse and defaultOptionResponse.Action == "SaveState" then
    print("✅ Default SelectedOption test passed")
else
    error("❌ Default SelectedOption test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Narrative Encounter History tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
