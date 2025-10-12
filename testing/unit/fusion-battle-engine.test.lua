-- Fusion Battle Engine Unit Tests
-- Tests fusion battle stat calculations, move interactions, type effectiveness,
-- ability activation, AI behavior, status effects, and battle event handling

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.fusion-battle-engine"
local processId = "test-fusion-battle-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Fusion Battle Engine")
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

-- Test 1: Fusion Battle Stat Calculation
print("📝 Test 1: Fusion Battle Stat Calculation")
local statResult = sendMessage("CalculateFusionBattleStats", nil, json.encode({
    pokemon = {
        speciesId = 25,  -- Pikachu
        fusionSpeciesId = 26,  -- Raichu
        level = 50,
        ivs = {31, 31, 31, 31, 31, 31},
        nature = "MODEST"
    },
    battleContext = {
        battleSeed = "test123",
        turn = 1
    }
}))
if statResult and statResult.Action == "SaveState" then
    print("✅ Test passed: Fusion battle stats calculated")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: CalculateFusionBattleStats handler failed")
end

-- Test 2: Move Interaction Processing
print("📝 Test 2: Move Interaction Processing")
local moveResult = sendMessage("ProcessFusionMoveInteraction", nil, json.encode({
    move = {type = "Electric", power = 90, name = "Thunderbolt"},
    attacker = {
        speciesId = 25,
        fusionSpeciesId = 26,
        types = {"Electric"},
        level = 50
    },
    defender = {
        speciesId = 7,
        types = {"Water"},
        level = 50
    }
}))
if moveResult and moveResult.Action == "SaveState" then
    print("✅ Test passed: Move interaction processed")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: ProcessFusionMoveInteraction handler failed")
end

-- Test 3: Type Effectiveness Calculation
print("📝 Test 3: Type Effectiveness Calculation")
local typeResult = sendMessage("CalculateFusionTypeEffectiveness", nil, json.encode({
    attackingTypes = {"Electric"},
    defendingTypes = {"Water", "Flying"}
}))
if typeResult and typeResult.Action == "SaveState" then
    print("✅ Test passed: Type effectiveness calculated")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: CalculateFusionTypeEffectiveness handler failed")
end

-- Test 4: Ability Activation
print("📝 Test 4: Ability Activation")
local abilityResult = sendMessage("ProcessFusionAbilityActivation", nil, json.encode({
    pokemon = {
        abilities = {"OVERGROW", "BLAZE"}
    },
    trigger = "battle_start",
    battleContext = {turn = 1}
}))
if abilityResult and abilityResult.Action == "SaveState" then
    print("✅ Test passed: Ability activation processed")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: ProcessFusionAbilityActivation handler failed")
end

-- Test 5: AI Decision Processing
print("📝 Test 5: AI Decision Processing")
local aiResult = sendMessage("ProcessFusionAIDecision", nil, json.encode({
    pokemon = {
        speciesId = 25,
        fusionSpeciesId = 26,
        types = {"Electric"},
        stats = {123, 119, 68, 99, 85, 120}
    },
    availableMoves = {
        {name = "Tackle", power = 40, type = "Normal"},
        {name = "Thunderbolt", power = 90, type = "Electric"}
    },
    battleState = {
        enemyTypes = {"Water"},
        enemyHP = 0.8
    }
}))
if aiResult and aiResult.Action == "SaveState" then
    print("✅ Test passed: AI decision processed")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: ProcessFusionAIDecision handler failed")
end

-- Test 6: Status Effect Application
print("📝 Test 6: Status Effect Application")
local statusResult = sendMessage("ApplyFusionStatusEffect", nil, json.encode({
    pokemon = {
        speciesId = 25,
        fusionSpeciesId = 26,
        hp = 123
    },
    statusEffect = "BURN",
    battleContext = {
        statusTurns = 5
    }
}))
if statusResult and statusResult.Action == "SaveState" then
    print("✅ Test passed: Status effect applied")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: ApplyFusionStatusEffect handler failed")
end

-- Test 7: Battle Event Processing
print("📝 Test 7: Battle Event Processing")
local eventResult = sendMessage("ProcessFusionBattleEvent", nil, json.encode({
    eventType = "TURN_START",
    battleContext = {
        timestamp = 1234567890,
        turn = 1
    },
    participants = {
        {speciesId = 25, fusionSpeciesId = 26}
    }
}))
if eventResult and eventResult.Action == "SaveState" then
    print("✅ Test passed: Battle event processed")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: ProcessFusionBattleEvent handler failed")
end

-- Test 8: ADP v1.0 Info Handler
print("📝 Test 8: ADP v1.0 Info Handler")
local infoResult = sendMessage("Info")
if infoResult and infoResult.Action == "SaveState" then
    print("✅ Test passed: Info handler works")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Info handler failed")
end

-- Test 9: Health Check Handler
print("📝 Test 9: Health Check Handler")
local healthResult = sendMessage("HealthCheck")
if healthResult and healthResult.Action == "SaveState" then
    print("✅ Test passed: Health check works")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: HealthCheck handler failed")
end

-- Test 10: Invalid Fusion Combination
print("📝 Test 10: Invalid Fusion Combination")
local invalidResult = sendMessage("CalculateFusionBattleStats", nil, json.encode({
    pokemon = {
        speciesId = 25,
        fusionSpeciesId = 25,  -- Same species (invalid)
        level = 50
    }
}))
if invalidResult and invalidResult.Action == "Error" then
    print("✅ Test passed: Invalid fusion rejected")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Invalid fusion not handled")
end

-- Test 11: Missing Required Data
print("📝 Test 11: Missing Required Data")
local missingResult = sendMessage("ProcessFusionMoveInteraction", nil, json.encode({}))
if missingResult and missingResult.Action == "Error" then
    print("✅ Test passed: Missing data error handling works")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Missing data not handled")
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
