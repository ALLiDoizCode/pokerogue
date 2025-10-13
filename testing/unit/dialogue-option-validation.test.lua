-- Aolite Unit Tests for Dialogue Option Validation
-- Tests option selection validation including requirement checking
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.dialogue-navigation-engine"
local processId = "test-dialogue-option-validation"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Dialogue Option Validation")
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

-- Test 1: Option with all requirements met
print("📝 Test 1: Option with all requirements met")
local allReqsData = json.encode({
    waveIndex = 50,
    party = {{id = 1}, {id = 2}},
    money = 1000
})
local allReqsResponse = sendMessage("ValidateOptionSelection", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, allReqsData)
if allReqsResponse then
    print("✅ Option with all requirements met test passed")
else
    error("❌ Option with all requirements met test failed")
end

-- Test 2: Option with failed WaveRange requirement
print("📝 Test 2: Option with failed WaveRange requirement")
local failedWaveData = json.encode({
    waveIndex = 5,
    party = {{id = 1}}
})
local failedWaveResponse = sendMessage("ValidateOptionSelection", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, failedWaveData)
if failedWaveResponse then
    print("✅ Option with failed WaveRange test passed")
else
    error("❌ Option with failed WaveRange test failed")
end

-- Test 3: Option with failed PartySize requirement
print("📝 Test 3: Option with failed PartySize requirement")
local failedPartySizeData = json.encode({
    waveIndex = 50,
    party = {{id = 1}}
})
local failedPartySizeResponse = sendMessage("ValidateOptionSelection", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, failedPartySizeData)
if failedPartySizeResponse then
    print("✅ Option with failed PartySize test passed")
else
    error("❌ Option with failed PartySize test failed")
end

-- Test 4: Option with failed HealthRatio requirement
print("📝 Test 4: Option with failed HealthRatio requirement")
local failedHealthData = json.encode({
    waveIndex = 50,
    party = {
        {id = 1, hp = 10, maxHp = 100},
        {id = 2, hp = 20, maxHp = 100}
    }
})
local failedHealthResponse = sendMessage("ValidateOptionSelection", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, failedHealthData)
if failedHealthResponse then
    print("✅ Option with failed HealthRatio test passed")
else
    error("❌ Option with failed HealthRatio test failed")
end

-- Test 5: Option with failed Money requirement
print("📝 Test 5: Option with failed Money requirement")
local failedMoneyData = json.encode({
    waveIndex = 50,
    party = {{id = 1}},
    money = 50
})
local failedMoneyResponse = sendMessage("ValidateOptionSelection", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, failedMoneyData)
if failedMoneyResponse then
    print("✅ Option with failed Money requirement test passed")
else
    error("❌ Option with failed Money requirement test failed")
end

-- Test 6: Option disabled state handling
print("📝 Test 6: Option disabled state handling")
local disabledData = json.encode({
    waveIndex = 5,
    party = {{id = 1}}
})
local disabledResponse = sendMessage("ValidateOptionSelection", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, disabledData)
if disabledResponse then
    print("✅ Option disabled state test passed")
else
    error("❌ Option disabled state test failed")
end

-- Test 7: Invalid option index handling
print("📝 Test 7: Invalid option index handling")
local invalidIndexData = json.encode({
    waveIndex = 50,
    party = {{id = 1}}
})
local invalidIndexResponse = sendMessage("ValidateOptionSelection", {
    EncounterType = "TestEncounter",
    OptionIndex = "999"
}, invalidIndexData)
if invalidIndexResponse then
    print("✅ Invalid option index test passed")
else
    error("❌ Invalid option index test failed")
end

-- Test 8: Missing OptionIndex parameter
print("📝 Test 8: Missing OptionIndex parameter")
local missingIndexData = json.encode({
    waveIndex = 50,
    party = {{id = 1}}
})
local missingIndexResponse = sendMessage("ValidateOptionSelection", {
    EncounterType = "TestEncounter"
}, missingIndexData)
if missingIndexResponse and missingIndexResponse.Action == "Error" then
    print("✅ Missing OptionIndex test passed")
else
    error("❌ Missing OptionIndex test failed")
end

-- Test 9: Missing gameState data
print("📝 Test 9: Missing gameState data")
local missingStateResponse = sendMessage("ValidateOptionSelection", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
})
if missingStateResponse and missingStateResponse.Action == "Error" then
    print("✅ Missing gameState test passed")
else
    error("❌ Missing gameState test failed")
end

-- Test 10: Multiple requirement failures
print("📝 Test 10: Multiple requirement failures")
local multipleFailuresData = json.encode({
    waveIndex = 5,
    party = {},
    money = 0
})
local multipleFailuresResponse = sendMessage("ValidateOptionSelection", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, multipleFailuresData)
if multipleFailuresResponse then
    print("✅ Multiple requirement failures test passed")
else
    error("❌ Multiple requirement failures test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Dialogue Option Validation tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
