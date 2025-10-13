-- ===================================================================
-- UNIT TESTS: Narrative Progress Validation
-- ===================================================================
-- Purpose: Test progress validation logic (frequency, progression, continuity)
-- Framework: aolite (Story 2.10 optimized pattern)
-- Story: 19.4 - Story State & Narrative Progress Migration
-- ===================================================================

local aolite = require("aolite")
local json = require("json")

-- Test configuration (Story 2.10 optimized pattern)
local PROCESS_PATH = "processes.narrative-state-engine"
local processId = "test-narrative-progress-validation"
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Narrative Progress Validation")
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

-- Test 1: Validate frequency within limits
print("📝 Test 1: Validate frequency within limits")
sendMessage("RecordEncounterCompletion", {
    EncounterType = "101",  -- Unique type for Test 1
    Tier = "0",
    WaveIndex = "10",
    SelectedOption = "0",
    NarrativeId = "test-narrative-1"
})
local response1 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "20",
    ValidationType = "frequency",
    NarrativeId = "test-narrative-1",
    Data = json.encode({
        encounterType = 101,  -- Match unique type
        maxAllowed = 2
    })
})
if response1 and response1.Action == "SaveState" and response1.Data then
    local data1 = json.decode(response1.Data)
    if data1.valid == true and data1.progressPercentage == 50 then
        print("✅ Test 1 passed")
    else
        error("❌ Test 1 failed: Expected valid=true, progressPercentage=50")
    end
else
    error("❌ Test 1 failed: Expected SaveState with Data")
end

-- Test 2: Invalidate frequency at limit
print("📝 Test 2: Invalidate frequency at limit")
for i = 1, 2 do
    sendMessage("RecordEncounterCompletion", {
        EncounterType = "102",  -- Unique type for Test 2
        Tier = "0",
        WaveIndex = tostring(i * 10),
        SelectedOption = "0",
        NarrativeId = "test-narrative-2"
    })
end
local response2 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "30",
    ValidationType = "frequency",
    NarrativeId = "test-narrative-2",
    Data = json.encode({
        encounterType = 102,  -- Match unique type
        maxAllowed = 2
    })
})
if response2 and response2.Data then
    local data2 = json.decode(response2.Data)
    if data2.valid == false and data2.progressPercentage == 100 then
        print("✅ Test 2 passed")
    else
        error("❌ Test 2 failed: Expected valid=false, progressPercentage=100")
    end
else
    error("❌ Test 2 failed: Expected SaveState with Data")
end

-- Test 3: Validate progression when ahead of expected encounters
print("📝 Test 3: Validate progression when ahead of expected encounters")
for i = 1, 5 do
    sendMessage("RecordEncounterCompletion", {
        EncounterType = tostring(102 + i),  -- Unique types 103-107 for Test 3
        Tier = "0",
        WaveIndex = tostring(i * 5),
        SelectedOption = "0",
        NarrativeId = "test-narrative-3"
    })
end
local response3 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "30",
    ValidationType = "progression",
    NarrativeId = "test-narrative-3",
    Data = json.encode({})
})
if response3 and response3.Data then
    local data3 = json.decode(response3.Data)
    if data3.valid == true and data3.totalEncounters > data3.expectedEncounters then
        print("✅ Test 3 passed")
    else
        error("❌ Test 3 failed: Expected valid=true with totalEncounters > expectedEncounters")
    end
else
    error("❌ Test 3 failed: Expected SaveState with Data")
end

-- Test 4: Invalidate progression when behind expected encounters
print("📝 Test 4: Invalidate progression when behind expected encounters")
sendMessage("RecordEncounterCompletion", {
    EncounterType = "104",  -- Unique type for Test 4
    Tier = "0",
    WaveIndex = "10",
    SelectedOption = "0",
    NarrativeId = "test-narrative-4"
})
local response4 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "200",  -- High wave to ensure we're behind (expects 20, we have ~10)
    ValidationType = "progression",
    NarrativeId = "test-narrative-4",
    Data = json.encode({})
})
if response4 and response4.Data then
    local data4 = json.decode(response4.Data)
    if data4.valid == false and data4.totalEncounters < data4.expectedEncounters then
        print("✅ Test 4 passed")
    else
        error("❌ Test 4 failed: Expected valid=false with totalEncounters < expectedEncounters")
    end
else
    error("❌ Test 4 failed: Expected SaveState with Data")
end

-- Test 5: Validate continuity with valid state
print("📝 Test 5: Validate continuity with valid state")
local response5 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "20",
    ValidationType = "continuity",
    NarrativeId = "test-narrative-5",
    Data = json.encode({})
})
if response5 and response5.Action == "SaveState" and response5.Data then
    local data5 = json.decode(response5.Data)
    if data5.valid == true and data5.progressPercentage == 100 then
        print("✅ Test 5 passed")
    else
        error("❌ Test 5 failed: Expected valid=true, progressPercentage=100")
    end
else
    error("❌ Test 5 failed: Expected SaveState with Data")
end

-- Test 6: Maintain continuity after spawn chance adjustments
print("📝 Test 6: Maintain continuity after spawn chance adjustments")
sendMessage("UpdateSpawnProbability", {
    AdjustmentAmount = "50",
    NarrativeId = "test-narrative-6"
})
local response6 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "30",
    ValidationType = "continuity",
    NarrativeId = "test-narrative-6",
    Data = json.encode({})
})
if response6 and response6.Data then
    local data6 = json.decode(response6.Data)
    if data6.valid == true and data6.progressPercentage == 100 then
        print("✅ Test 6 passed")
    else
        error("❌ Test 6 failed: Expected valid=true, progressPercentage=100")
    end
else
    error("❌ Test 6 failed: Expected SaveState with Data")
end

-- Test 7: Return error for unknown validation type
print("📝 Test 7: Return error for unknown validation type")
local response7 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "20",
    ValidationType = "unknown_type",
    NarrativeId = "test-narrative-7",
    Data = json.encode({})
})
if response7 and response7.Action == "Error" and response7.Error and string.find(response7.Error, "Unknown validation type") then
    print("✅ Test 7 passed")
else
    error("❌ Test 7 failed: Expected Error with 'Unknown validation type'")
end

-- Test 8: Return error when required parameters missing
print("📝 Test 8: Return error when required parameters missing")
local response8 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "20",
    NarrativeId = "test-narrative-8"
    -- ValidationType missing
})
if response8 and response8.Action == "Error" and response8.Error and string.find(response8.Error, "required") then
    print("✅ Test 8 passed")
else
    error("❌ Test 8 failed: Expected Error mentioning 'required'")
end

-- Test 9: Respect custom maxAllowed in frequency validation
print("📝 Test 9: Respect custom maxAllowed in frequency validation")
for i = 1, 3 do
    sendMessage("RecordEncounterCompletion", {
        EncounterType = "109",  -- Unique type for Test 9
        Tier = "0",
        WaveIndex = tostring(i * 10),
        SelectedOption = "0",
        NarrativeId = "test-narrative-9"
    })
end
local response9 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "40",
    ValidationType = "frequency",
    NarrativeId = "test-narrative-9",
    Data = json.encode({
        encounterType = 109,  -- Match unique type
        maxAllowed = 5
    })
})
if response9 and response9.Data then
    local data9 = json.decode(response9.Data)
    if data9.valid == true and data9.progressPercentage == 60 then
        print("✅ Test 9 passed")
    else
        error("❌ Test 9 failed: Expected valid=true, progressPercentage=60")
    end
else
    error("❌ Test 9 failed: Expected SaveState with Data")
end

-- Test 10: Track multi-part encounter with option selections
print("📝 Test 10: Track multi-part encounter with option selections")
sendMessage("RecordEncounterCompletion", {
    EncounterType = "10",
    Tier = "2",
    WaveIndex = "15",
    SelectedOption = "0",
    NarrativeId = "test-narrative-10"
})
sendMessage("RecordEncounterCompletion", {
    EncounterType = "10",
    Tier = "2",
    WaveIndex = "25",
    SelectedOption = "1",
    NarrativeId = "test-narrative-10"
})
local response10 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "30",
    ValidationType = "frequency",
    NarrativeId = "test-narrative-10",
    Data = json.encode({
        encounterType = 10,
        maxAllowed = 3
    })
})
if response10 and response10.Data then
    local result10 = json.decode(response10.Data)
    if result10.currentCount == 2 and result10.maxCount == 3 and result10.valid == true then
        print("✅ Test 10 passed")
    else
        error("❌ Test 10 failed: Expected currentCount=2, maxCount=3, valid=true")
    end
else
    error("❌ Test 10 failed: Expected valid Data response")
end

-- Test 11: Persist option selections across encounters
print("📝 Test 11: Persist option selections across encounters")
sendMessage("RecordEncounterCompletion", {
    EncounterType = "5",
    Tier = "1",
    WaveIndex = "10",
    SelectedOption = "2",
    NarrativeId = "test-narrative-11"
})
local response11 = sendMessage("GetEncounterHistory", {
    NarrativeId = "test-narrative-11"
})
if response11 and response11.Data then
    local history = json.decode(response11.Data)
    if #history > 0 then
        -- Find the encounter we just added (EncounterType 5, Tier 1, SelectedOption 2)
        local found = false
        for i, entry in ipairs(history) do
            if entry.type == 5 and entry.tier == 1 and entry.selectedOption == 2 then
                found = true
                break
            end
        end
        if found then
            print("✅ Test 11 passed")
        else
            error("❌ Test 11 failed: Could not find encounter with type=5, tier=1, selectedOption=2")
        end
    else
        error("❌ Test 11 failed: History is empty")
    end
else
    error("❌ Test 11 failed: Expected valid history response")
end

-- Test 12: Handle progression validation at wave 0
print("📝 Test 12: Handle progression validation at wave 0")
local response12 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "0",
    ValidationType = "progression",
    NarrativeId = "test-narrative-12",
    Data = json.encode({})
})
if response12 and response12.Data then
    local data12 = json.decode(response12.Data)
    if data12.valid == true then
        print("✅ Test 12 passed")
    else
        error("❌ Test 12 failed: Expected valid=true for wave 0")
    end
else
    error("❌ Test 12 failed: Expected SaveState with Data")
end

-- Test 13: Use default maxAllowed (2) when not specified
print("📝 Test 13: Use default maxAllowed when not specified")
sendMessage("RecordEncounterCompletion", {
    EncounterType = "7",
    Tier = "1",
    WaveIndex = "15",
    SelectedOption = "0",
    NarrativeId = "test-narrative-13"
})
local response13 = sendMessage("ValidateNarrativeProgress", {
    CurrentWave = "20",
    ValidationType = "frequency",
    NarrativeId = "test-narrative-13",
    Data = json.encode({
        encounterType = 7
        -- maxAllowed not specified
    })
})
if response13 and response13.Data then
    local result13 = json.decode(response13.Data)
    if result13.maxCount == 2 and result13.valid == true then
        print("✅ Test 13 passed")
    else
        error("❌ Test 13 failed: Expected maxCount=2 (default), valid=true")
    end
else
    error("❌ Test 13 failed: Expected valid Data response")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ 13/13 Narrative Progress Validation tests completed")
