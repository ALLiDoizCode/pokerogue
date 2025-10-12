-- Fusion Management Engine Unit Tests
-- Tests fusion separation algorithms, state persistence, inventory management, validation,
-- component tracking, lifecycle events, and complex scenarios

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.fusion-management-engine"
local processId = "test-fusion-management-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Fusion Management Engine")
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

local function createTestPokemon(withFusion)
    local pokemon = {
        species = "PIKACHU",
        level = 50,
        stats = {130, 105, 95, 110, 100, 120},
        exp = 125000,
        friendship = 220,
        abilities = {"STATIC", "LIGHTNING_ROD"},
        moveset = {}
    }

    if withFusion then
        pokemon.fusionSpecies = "RAICHU"
        pokemon.fusionFormIndex = 0
        pokemon.fusionAbilityIndex = 1
        pokemon.fusionShiny = false
        pokemon.fusionVariant = 0
        pokemon.fusionGender = 1
    end

    return pokemon
end

-- Test 1: Fusion separation algorithms
print("📝 Test 1: Fusion Separation Algorithms")
local fusionPokemon = createTestPokemon(true)
local gameState = {
    pokemon = fusionPokemon,
    parameters = {
        managementPhase = "separation",
        managementType = "component_restoration",
        precisionLevel = "exact"
    }
}
local response1 = sendMessage("SeparateFusion", {}, json.encode(gameState))
if not response1 or response1.Action == "Error" then
    error("❌ Test failed: Expected successful fusion separation")
end
print("✅ Test 1 passed: Fusion separation algorithms")

-- Test 2: Fusion state persistence
print("📝 Test 2: Fusion State Persistence")
local persistData = json.encode({pokemon = fusionPokemon})
local response2 = sendMessage("PersistFusionState", {}, persistData)
if not response2 or response2.Action == "Error" then
    error("❌ Test failed: Expected successful state persistence")
end
print("✅ Test 2 passed: Fusion state persistence")

-- Test 3: Fusion inventory management
print("📝 Test 3: Fusion Inventory Management")
local inventoryData = json.encode({
    player = {
        inventory = {
            items = {},
            money = 5000
        }
    }
})
local response3 = sendMessage("ManageFusionInventory", {}, inventoryData)
if not response3 or response3.Action == "Error" then
    error("❌ Test failed: Expected successful inventory management")
end
print("✅ Test 3 passed: Fusion inventory management")

-- Test 4: Fusion separation validation
print("📝 Test 4: Fusion Separation Validation")
local validationData = json.encode({pokemon = fusionPokemon})
local response4 = sendMessage("ValidateFusionSeparation", {}, validationData)
if not response4 or response4.Action == "Error" then
    error("❌ Test failed: Expected successful validation")
end
print("✅ Test 4 passed: Fusion separation validation")

-- Test 5: Fusion component tracking
print("📝 Test 5: Fusion Component Tracking")
local trackingData = json.encode({pokemon = fusionPokemon})
local response5 = sendMessage("TrackFusionComponent", {}, trackingData)
if not response5 or response5.Action == "Error" then
    error("❌ Test failed: Expected successful component tracking")
end
print("✅ Test 5 passed: Fusion component tracking")

-- Test 6: Fusion lifecycle events
print("📝 Test 6: Fusion Lifecycle Events")
local lifecycleData = json.encode({eventType = "separation"})
local response6 = sendMessage("TriggerFusionLifecycle", {}, lifecycleData)
if not response6 or response6.Action == "Error" then
    error("❌ Test failed: Expected successful lifecycle event trigger")
end
print("✅ Test 6 passed: Fusion lifecycle events")

-- Test 7: Complex fusion management scenarios
print("📝 Test 7: Complex Fusion Management Scenarios")
local scenarioData = json.encode({scenario = "multi_fusion_chain"})
local response7 = sendMessage("ManageFusionScenario", {}, scenarioData)
if not response7 or response7.Action == "Error" then
    error("❌ Test failed: Expected successful scenario management")
end
print("✅ Test 7 passed: Complex fusion management scenarios")

-- Test 8: ADP v1.0 compliance
print("📝 Test 8: ADP v1.0 Compliance")
local response8 = sendMessage("Info")
if not response8 or response8.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState response for Info")
end
print("✅ Test 8 passed: ADP v1.0 compliance")

-- Test 9: Error handling
print("📝 Test 9: Error Handling")
local nonFusionPokemon = createTestPokemon(false)
local errorData = json.encode({pokemon = nonFusionPokemon})
local response9 = sendMessage("SeparateFusion", {}, errorData)
if response9 and response9.Action ~= "Error" then
    error("❌ Test failed: Expected error for non-fusion Pokemon")
end
print("✅ Test 9 passed: Error handling for non-fusion Pokemon")

-- Test 10: Ping handler
print("📝 Test 10: Ping Handler")
local response10 = sendMessage("Ping")
if not response10 or response10.Action ~= "Pong" then
    error("❌ Test failed: Expected Pong response")
end
print("✅ Test 10 passed: Ping handler")

print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
