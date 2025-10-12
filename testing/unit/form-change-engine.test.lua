-- Form Change Engine Unit Tests
-- Tests all form change functionality with aolite

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.form-change-engine"
local processId = "test-form-change-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Form Change Engine")
print("Process ID:", processId)

local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
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

local testsPassed = 0
local testsFailed = 0

-- Test 1: Darmanitan Zen Mode Trigger
print("📝 Test 1: Darmanitan Zen Mode Trigger at 50% HP")
local zenResult = sendMessage("ProcessFormChange", {
    PokemonId = "pokemon_1",
    SpeciesId = "555",
    TriggerType = "hp"
}, json.encode({
    pokemon = {
        id = "pokemon_1",
        hp = 50,
        maxHp = 100,
        stats = {hp = 105, attack = 140, defense = 55, spAttack = 30, spDefense = 55, speed = 95}
    }
}))
if zenResult and zenResult.Action == "FormChangeResult" then
    print("✅ Test passed: Darmanitan Zen Mode trigger handled")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: ProcessFormChange handler failed")
end

-- Test 2: Castform Weather Form
print("📝 Test 2: Castform Sunny Form")
local castformResult = sendMessage("ProcessFormChange", {
    PokemonId = "pokemon_2",
    SpeciesId = "351",
    TriggerType = "weather"
}, json.encode({
    weather = "SUNNY",
    pokemon = {
        id = "pokemon_2",
        ability = "FORECAST"
    }
}))
if castformResult and castformResult.Action == "FormChangeResult" then
    print("✅ Test passed: Castform weather form change handled")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Castform form change failed")
end

-- Test 3: Meloetta Relic Song Toggle
print("📝 Test 3: Meloetta Relic Song Toggle")
local meloettaResult = sendMessage("ProcessFormChange", {
    PokemonId = "pokemon_3",
    SpeciesId = "648",
    TriggerType = "move"
}, json.encode({
    moveId = "RELIC_SONG",
    pokemon = {
        id = "pokemon_3",
        currentForm = 0
    }
}))
if meloettaResult and meloettaResult.Action == "FormChangeResult" then
    print("✅ Test passed: Meloetta Relic Song toggle handled")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Meloetta form change failed")
end

-- Test 4: Aegislash Stance Change
print("📝 Test 4: Aegislash Stance Change to Blade Form")
local aegislashResult = sendMessage("ProcessFormChange", {
    PokemonId = "pokemon_4",
    SpeciesId = "681",
    TriggerType = "pre_move"
}, json.encode({
    moveCategory = "PHYSICAL",
    pokemon = {
        id = "pokemon_4"
    }
}))
if aegislashResult and aegislashResult.Action == "FormChangeResult" then
    print("✅ Test passed: Aegislash stance change handled")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Aegislash stance change failed")
end

-- Test 5: Stat Recalculation
print("📝 Test 5: Stat Recalculation")
local statsResult = sendMessage("RecalculateStats", {
    SpeciesId = "555",
    FormIndex = "1"
}, json.encode({
    hp = 75,
    stats = {hp = 105, attack = 140, defense = 55, spAttack = 30, spDefense = 55, speed = 95}
}))
if statsResult and statsResult.Action == "StatsRecalculated" then
    print("✅ Test passed: Stat recalculation handled")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: RecalculateStats handler failed")
end

-- Test 6: Ability Update
print("📝 Test 6: Ability Update")
local abilityResult = sendMessage("UpdateAbility", {
    SpeciesId = "555",
    FormIndex = "1"
})
if abilityResult and abilityResult.Action == "AbilityUpdated" then
    if abilityResult.PrimaryAbility == "ZEN_MODE" then
        print("✅ Test passed: Ability updated correctly")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Ability value incorrect")
    end
else
    error("❌ Test failed: UpdateAbility handler failed")
end

-- Test 7: Form Data Retrieval
print("📝 Test 7: Form Data Retrieval")
local formDataResult = sendMessage("GetFormData", {
    PokemonId = "pokemon_1",
    SpeciesId = "555"
})
if formDataResult and formDataResult.Action == "FormData" then
    if formDataResult.HasForms == "true" then
        print("✅ Test passed: Form data retrieved")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Form data incorrect")
    end
else
    error("❌ Test failed: GetFormData handler failed")
end

-- Test 8: Species Without Forms
print("📝 Test 8: Species Without Forms")
local noFormsResult = sendMessage("GetFormData", {
    PokemonId = "pokemon_unknown",
    SpeciesId = "999"
})
if noFormsResult and noFormsResult.HasForms == "false" then
    print("✅ Test passed: No forms case handled")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: No forms case incorrect")
end

-- Test 9: Error Handling
print("📝 Test 9: Error Handling")
local errorResult = sendMessage("ProcessFormChange", {}) -- Missing required fields
if errorResult and errorResult.Action == "Error" then
    print("✅ Test passed: Error handling works")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Error handling not working")
end

-- Test 10: ADP Compliance
print("📝 Test 10: ADP Compliance")
local infoResult = sendMessage("Info")
if infoResult and infoResult.Action == "Info" then
    local infoStr = infoResult.Data or ""
    if infoStr:find('"ProtocolVersion":"1.0"') and infoStr:find('"Name":"Form Change Engine"') then
        print("✅ Test passed: ADP v1.0 compliant")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: ADP compliance incorrect")
    end
else
    error("❌ Test failed: Info handler failed")
end

print("==================================================")
print("Test Results:")
print("  Passed: " .. testsPassed)
print("  Failed: " .. testsFailed)
print("  Total:  " .. (testsPassed + testsFailed))

if testsFailed == 0 then
    print("\n🎉 All tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
else
    error("\n❌ Some tests failed!")
end
