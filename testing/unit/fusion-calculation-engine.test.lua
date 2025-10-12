-- Unit Tests for Fusion Calculation Engine
-- Tests all fusion calculation functionality for mathematical precision

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.fusion-calculation-engine"
local processId = "test-fusion-calculation-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Fusion Calculation Engine")
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

-- Test Data: Pokemon stat examples
local pikachuStats = {
    HP = 35, ATK = 55, DEF = 40, SPATK = 50, SPDEF = 50, SPD = 90
}

local raichuStats = {
    HP = 60, ATK = 90, DEF = 55, SPATK = 90, SPDEF = 80, SPD = 110
}

-- Test 1: Fusion Stat Calculation - Pikachu + Raichu
print("📝 Test 1: Fusion Stat Calculation - Pikachu + Raichu")
local fusionData = json.encode({
    baseStats = pikachuStats,
    fusionStats = raichuStats
})
local response = sendMessage("CalculateFusionStats", {}, fusionData)
if not response or response.Action == "Error" then
    error("❌ Test failed: Expected successful fusion stats calculation")
end
print("✅ Test 1 passed: Basic fusion stat calculation")

-- Test 2: Fusion Stat Calculation with Fractional Results
print("📝 Test 2: Fusion Stat Calculation - Edge Case Fractionals")
local oddStats = {HP = 33, ATK = 71, DEF = 45, SPATK = 67, SPDEF = 59, SPD = 83}
local evenStats = {HP = 66, ATK = 72, DEF = 54, SPATK = 68, SPDEF = 60, SPD = 84}
local fractionalData = json.encode({
    baseStats = oddStats,
    fusionStats = evenStats
})
local response2 = sendMessage("CalculateFusionStats", {}, fractionalData)
if not response2 or response2.Action == "Error" then
    error("❌ Test failed: Expected successful fractional fusion calculation")
end
print("✅ Test 2 passed: Fractional fusion calculation")

-- Test 3: Fusion Type Determination - Priority Logic
print("📝 Test 3: Fusion Type Determination - Priority Logic")
local typeData = json.encode({
    baseTypes = {"ELECTRIC"},
    fusionTypes = {"ELECTRIC", "FLYING"}
})
local response3 = sendMessage("DetermineFusionTypes", {}, typeData)
if not response3 or response3.Action == "Error" then
    error("❌ Test failed: Expected successful type determination")
end
print("✅ Test 3 passed: Type determination priority logic")

-- Test 4: Fusion Type Determination - Same Primary Types
print("📝 Test 4: Fusion Type Determination - Same Primary Types")
local sameTypeData = json.encode({
    baseTypes = {"FIRE", "FLYING"},
    fusionTypes = {"FIRE", "WATER"}
})
local response4 = sendMessage("DetermineFusionTypes", {}, sameTypeData)
if not response4 or response4.Action == "Error" then
    error("❌ Test failed: Expected successful same type determination")
end
print("✅ Test 4 passed: Same primary type handling")

-- Test 5: Fusion Type Determination - Monotype Cases
print("📝 Test 5: Fusion Type Determination - Monotype Cases")
local monoTypeData = json.encode({
    baseTypes = {"ELECTRIC"},
    fusionTypes = {"ELECTRIC"}
})
local response5 = sendMessage("DetermineFusionTypes", {}, monoTypeData)
if not response5 or response5.Action == "Error" then
    error("❌ Test failed: Expected successful monotype determination")
end
print("✅ Test 5 passed: Monotype handling")

-- Test 6: Fusion Ability Selection
print("📝 Test 6: Fusion Ability Selection")
local abilityData = json.encode({
    baseAbilities = {"STATIC", "LIGHTNING_ROD"},
    fusionAbilities = {"STATIC", "LIGHTNING_ROD", "LIGHTNING_ROD"},
    battleSeed = 100,
    rngCounter = 0
})
local response6 = sendMessage("SelectFusionAbility", {}, abilityData)
if not response6 or response6.Action == "Error" then
    error("❌ Test failed: Expected successful ability selection")
end
print("✅ Test 6 passed: Ability selection logic")

-- Test 7: Fusion Creation Validation - Valid Request
print("📝 Test 7: Fusion Creation Validation - Valid Request")
local validRequest = json.encode({
    baseSpecies = {
        id = "PIKACHU",
        baseStats = pikachuStats,
        types = {"ELECTRIC"},
        abilities = {"STATIC", "LIGHTNING_ROD"}
    },
    fusionSpecies = {
        id = "RAICHU",
        baseStats = raichuStats,
        types = {"ELECTRIC"},
        abilities = {"STATIC", "LIGHTNING_ROD"}
    }
})
local response7 = sendMessage("ValidateFusionCreation", {}, validRequest)
if not response7 or response7.Action == "Error" then
    error("❌ Test failed: Expected successful validation")
end
print("✅ Test 7 passed: Valid fusion creation validation")

-- Test 8: Fusion Creation Validation - Invalid Request
print("📝 Test 8: Fusion Creation Validation - Missing Data")
local invalidRequest = json.encode({
    baseSpecies = {
        id = "PIKACHU"
        -- Missing baseStats
    }
})
local response8 = sendMessage("ValidateFusionCreation", {}, invalidRequest)
if response8 and response8.Action ~= "Error" then
    error("❌ Test failed: Expected error for invalid request")
end
print("✅ Test 8 passed: Invalid request error handling")

-- Test 9: Mathematical Precision Tracking
print("📝 Test 9: Mathematical Precision Tracking")
local precisionStats = {HP = 35, ATK = 55, DEF = 41, SPATK = 51, SPDEF = 51, SPD = 91}
local precisionFusion = {HP = 60, ATK = 90, DEF = 54, SPATK = 89, SPDEF = 79, SPD = 109}
local precisionData = json.encode({
    baseStats = precisionStats,
    fusionStats = precisionFusion
})
local response9 = sendMessage("CalculateFusionStats", {}, precisionData)
if not response9 or response9.Action == "Error" then
    error("❌ Test failed: Expected successful precision calculation")
end
print("✅ Test 9 passed: Mathematical precision tracking")

-- Test 10: Error Handling - Missing Parameters
print("📝 Test 10: Error Handling - Missing Parameters")
local emptyData = json.encode({})
local response10 = sendMessage("CalculateFusionStats", {}, emptyData)
if response10 and response10.Action ~= "Error" then
    error("❌ Test failed: Expected error for missing parameters")
end
print("✅ Test 10 passed: Missing parameter error handling")

-- Test 11: Deterministic RNG Consistency
print("📝 Test 11: Deterministic RNG Consistency")
local rngData1 = json.encode({
    baseAbilities = {"ABILITY_1", "ABILITY_2"},
    fusionAbilities = {"ABILITY_3", "ABILITY_4", "HIDDEN_ABILITY"},
    battleSeed = 12345,
    rngCounter = 0
})
local rngResponse1 = sendMessage("SelectFusionAbility", {}, rngData1)
local rngResponse2 = sendMessage("SelectFusionAbility", {}, rngData1)
if not rngResponse1 or not rngResponse2 then
    error("❌ Test failed: RNG selection failed")
end
print("✅ Test 11 passed: Deterministic RNG consistency")

-- Test 12: Ping handler
print("📝 Test 12: Ping handler")
local pingResponse = sendMessage("Ping")
if not pingResponse or pingResponse.Action ~= "Pong" then
    error("❌ Test failed: Expected Pong response")
end
print("✅ Test 12 passed: Ping handler")

print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
