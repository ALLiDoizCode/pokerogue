-- Form Persistence Engine Unit Tests
-- Tests for duration tracking, save/load persistence, reversion logic, and priority resolution

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.form-persistence-engine"
local processId = "test-form-persistence-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Form Persistence Engine")
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

-- Test 1: Track Temporary Battle-Only Forms
print("📝 Test 1: Temporary Battle-Only Forms")
local battleResult = sendMessage("ProcessFormPersistence", {
    PokemonId = "test_pokemon_1",
    FormType = "mega",
    Duration = "1"
}, json.encode({
    pokemon = {
        id = "test_pokemon_1",
        speciesId = "492"
    }
}))
if battleResult and battleResult.Action == "SaveState" then
    if battleResult.Success == "true" and battleResult.PersistenceType == "battle_only" then
        print("✅ Test passed: Battle-only forms tracked")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Battle-only form tracking incorrect")
    end
else
    error("❌ Test failed: ProcessFormPersistence handler failed")
end

-- Test 2: Track Timed Forms
print("📝 Test 2: Timed Forms (Hoopa Unbound)")
local timedResult = sendMessage("ProcessFormPersistence", {
    PokemonId = "test_pokemon_1",
    SpeciesId = "720",
    FormType = "unbound",
    Duration = "259200"
}, json.encode({
    pokemon = {
        id = "test_pokemon_1"
    }
}))
if timedResult and timedResult.Action == "SaveState" then
    if timedResult.Success == "true" and timedResult.Duration == "259200" then
        print("✅ Test passed: Timed forms tracked")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Timed form tracking incorrect")
    end
else
    error("❌ Test failed: Timed form test failed")
end

-- Test 3: Battle-End Expiration
print("📝 Test 3: Battle-End Expiration")
local expirationResult = sendMessage("CheckFormExpiration", {
    PokemonId = "test_pokemon_1",
    BattleEnded = "true"
}, json.encode({
    pokemon = {
        id = "test_pokemon_1",
        currentForm = "mega",
        formPersistenceData = {
            type = "battle_only",
            expirationCondition = "battle_end",
            revertToForm = "base"
        }
    }
}))
if expirationResult and expirationResult.Action == "SaveState" then
    if expirationResult.FormReverted == "true" then
        print("✅ Test passed: Battle-end expiration works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Battle-end expiration incorrect")
    end
else
    error("❌ Test failed: CheckFormExpiration handler failed")
end

-- Test 4: Save Form State (Permanent Forms)
print("📝 Test 4: Save Form State")
local saveResult = sendMessage("SaveFormState", nil, json.encode({
    pokemon = {
        id = "test_pokemon_1",
        speciesId = "483",
        currentForm = "origin",
        heldItem = "ADAMANT_ORB",
        formPersistenceData = {
            type = "permanent",
            persistThroughSave = true,
            requiredItem = "ADAMANT_ORB"
        }
    }
}))
if saveResult and saveResult.Action == "SaveState" then
    if saveResult.FormPersisted == "true" then
        print("✅ Test passed: Form state saved")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Form state save incorrect")
    end
else
    error("❌ Test failed: SaveFormState handler failed")
end

-- Test 5: Load Form State
print("📝 Test 5: Load Form State")
local loadResult = sendMessage("LoadFormState", {
    PokemonId = "test_pokemon_1"
}, json.encode({
    persistentForms = {
        ["test_pokemon_1"] = {
            form = "origin",
            persistenceData = {
                type = "permanent",
                requiredItem = "ADAMANT_ORB"
            },
            timestamp = 1234567800
        }
    },
    pokemon = {
        id = "test_pokemon_1",
        heldItem = "ADAMANT_ORB"
    }
}))
if loadResult and loadResult.Action == "SaveState" then
    if loadResult.FormRestored == "true" then
        print("✅ Test passed: Form state loaded")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Form state load incorrect")
    end
else
    error("❌ Test failed: LoadFormState handler failed")
end

-- Test 6: Manual Form Reversion
print("📝 Test 6: Manual Form Reversion")
local revertResult = sendMessage("RevertForm", {
    PokemonId = "test_pokemon_1",
    CancellationTrigger = "manual"
}, json.encode({
    pokemon = {
        id = "test_pokemon_1",
        currentForm = "sky",
        formPersistenceData = {
            revertToForm = "land"
        }
    }
}))
if revertResult and revertResult.Action == "SaveState" then
    if revertResult.FormReverted == "true" and revertResult.CancellationTrigger == "manual" then
        print("✅ Test passed: Manual reversion works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Manual reversion incorrect")
    end
else
    error("❌ Test failed: RevertForm handler failed")
end

-- Test 7: Validate Form Conditions (Shaymin Sky)
print("📝 Test 7: Validate Form Conditions")
local validationResult = sendMessage("ValidateFormConditions", {
    PokemonId = "test_pokemon_1",
    SpeciesId = "492",
    FormType = "sky",
    IsDay = "true",
    IsFrozen = "false"
})
if validationResult and validationResult.Action == "ValidationResult" then
    if validationResult.Valid == "true" then
        print("✅ Test passed: Form conditions validated")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Form validation incorrect")
    end
else
    error("❌ Test failed: ValidateFormConditions handler failed")
end

-- Test 8: Reject Invalid Conditions
print("📝 Test 8: Reject Invalid Form Conditions")
local invalidResult = sendMessage("ValidateFormConditions", {
    PokemonId = "test_pokemon_1",
    SpeciesId = "492",
    FormType = "sky",
    IsDay = "false"
})
if invalidResult and invalidResult.Action == "ValidationResult" then
    if invalidResult.Valid == "false" then
        print("✅ Test passed: Invalid conditions rejected")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Invalid condition validation incorrect")
    end
else
    error("❌ Test failed: Invalid condition test failed")
end

-- Test 9: Error Handling
print("📝 Test 9: Error Handling")
local errorResult = sendMessage("ProcessFormPersistence", {}) -- Missing required fields
if errorResult and errorResult.Action == "Error" then
    print("✅ Test passed: Error handling works")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Error handling not working")
end

-- Test 10: ADP v1.0 Compliance
print("📝 Test 10: ADP v1.0 Compliance")
local infoResult = sendMessage("Info")
if infoResult and infoResult.Action == "SaveState" then
    print("✅ Test passed: Info handler works")
    testsPassed = testsPassed + 1
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
