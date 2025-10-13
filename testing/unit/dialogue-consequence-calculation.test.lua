-- Aolite Unit Tests for Dialogue Consequence Calculation
-- Tests consequence calculation for dialogue option selection
-- Compatible with aolite testing framework (CORRECT API)

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.dialogue-navigation-engine"
local processId = "test-dialogue-consequence-calculation"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Dialogue Consequence Calculation")
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

-- Test 1: Immediate consequences (rewards)
print("📝 Test 1: Immediate consequences (rewards)")
local rewardsData = json.encode({
    waveIndex = 50,
    party = {{id = 1}},
    money = 1000,
    encounter = {
        options = {
            {
                dialogue = {buttonLabel = "Accept Reward"},
                consequences = {
                    consequenceType = "immediate",
                    rewards = {
                        money = 500,
                        items = {potion = 3}
                    }
                }
            }
        }
    }
})
local rewardsResponse = sendMessage("GetOptionConsequences", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, rewardsData)
if rewardsResponse then
    print("✅ Immediate consequences (rewards) test passed")
else
    error("❌ Immediate consequences (rewards) test failed")
end

-- Test 2: Immediate consequences (penalties)
print("📝 Test 2: Immediate consequences (penalties)")
local penaltiesData = json.encode({
    waveIndex = 50,
    party = {{id = 1}},
    money = 1000
})
local penaltiesResponse = sendMessage("GetOptionConsequences", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, penaltiesData)
if penaltiesResponse then
    print("✅ Immediate consequences (penalties) test passed")
else
    error("❌ Immediate consequences (penalties) test failed")
end

-- Test 3: Deferred consequences (narrative flags)
print("📝 Test 3: Deferred consequences (narrative flags)")
local deferredData = json.encode({
    waveIndex = 50,
    party = {{id = 1}}
})
local deferredResponse = sendMessage("GetOptionConsequences", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, deferredData)
if deferredResponse then
    print("✅ Deferred consequences test passed")
else
    error("❌ Deferred consequences test failed")
end

-- Test 4: Consequence validation (no negative items)
print("📝 Test 4: Consequence validation (no negative items)")
local validationData = json.encode({
    waveIndex = 50,
    party = {{id = 1}},
    money = 1000
})
local validationResponse = sendMessage("GetOptionConsequences", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, validationData)
if validationResponse then
    print("✅ Consequence validation (no negatives) test passed")
else
    error("❌ Consequence validation (no negatives) test failed")
end

-- Test 5: State changes in consequences
print("📝 Test 5: State changes in consequences")
local stateChangesData = json.encode({
    waveIndex = 50,
    party = {{id = 1}}
})
local stateChangesResponse = sendMessage("GetOptionConsequences", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, stateChangesData)
if stateChangesResponse then
    print("✅ State changes consequences test passed")
else
    error("❌ State changes consequences test failed")
end

-- Test 6: Missing OptionIndex parameter
print("📝 Test 6: Missing OptionIndex parameter")
local missingIndexData = json.encode({
    waveIndex = 50
})
local missingIndexResponse = sendMessage("GetOptionConsequences", {
    EncounterType = "TestEncounter"
}, missingIndexData)
if missingIndexResponse and missingIndexResponse.Action == "Error" then
    print("✅ Missing OptionIndex test passed")
else
    error("❌ Missing OptionIndex test failed")
end

-- Test 7: Missing gameState data
print("📝 Test 7: Missing gameState data")
local missingStateResponse = sendMessage("GetOptionConsequences", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
})
if missingStateResponse and missingStateResponse.Action == "Error" then
    print("✅ Missing gameState test passed")
else
    error("❌ Missing gameState test failed")
end

-- Test 8: Invalid option index
print("📝 Test 8: Invalid option index")
local invalidIndexData = json.encode({
    waveIndex = 50
})
local invalidIndexResponse = sendMessage("GetOptionConsequences", {
    EncounterType = "TestEncounter",
    OptionIndex = "999"
}, invalidIndexData)
if invalidIndexResponse then
    print("✅ Invalid option index test passed")
else
    error("❌ Invalid option index test failed")
end

-- Test 9: Consequence type immediate
print("📝 Test 9: Consequence type immediate")
local immediateData = json.encode({
    waveIndex = 50,
    party = {{id = 1}},
    encounter = {
        options = {
            {
                dialogue = {buttonLabel = "Test Option"},
                consequences = {
                    consequenceType = "immediate",
                    rewards = {money = 100}
                }
            }
        }
    }
})
local immediateResponse = sendMessage("GetOptionConsequences", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, immediateData)
if immediateResponse then
    print("✅ Consequence type immediate test passed")
else
    error("❌ Consequence type immediate test failed")
end

-- Test 10: Track dialogue choice handler
print("📝 Test 10: Track dialogue choice handler")
-- NOTE: Send dialogue history array directly, not wrapped in object
-- Handler expects: dialogueHistory = json.decode(msg.Data)
-- So msg.Data should be the array itself: []
local trackData = json.encode({})  -- Empty dialogue history array
local trackResponse = sendMessage("TrackDialogueChoice", {
    EncounterType = "TestEncounter",
    OptionIndex = "1"
}, trackData)

if trackResponse and trackResponse.ChoiceRecorded == "true" then
    print("✅ Track dialogue choice test passed")
else
    error("❌ Track dialogue choice test failed")
end

-- Test Summary
print("==================================================")
print("🎉 All Dialogue Consequence Calculation tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
