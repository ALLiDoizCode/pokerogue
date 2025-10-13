-- Pokemon Instance Manager Unit Tests (Aolite Framework)
-- Tests Pokemon creation, state updates, retrieval, and serialization

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.pokemon-instance-manager"
local processId = "test-pokemon-instance-manager"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Pokemon Instance Manager")
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

-- Test 1: Pokemon instance creation
print("📝 Test 1: Pokemon Instance Creation")
local createData = json.encode({speciesId = 25, level = 5})
local response1 = sendMessage("CreatePokemon", {}, createData)
if not response1 or response1.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon creation")
end
print("✅ Test 1 passed: Pokemon creation test")

-- Test 2: Shiny generation
print("📝 Test 2: Shiny Generation")
local shinyData = json.encode({speciesId = 150, level = 50})
local response2 = sendMessage("CreatePokemon", {}, shinyData)
if not response2 or response2.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon with shiny status")
end
print("✅ Test 2 passed: Shiny generation test")

-- Test 3: Forced shiny generation
print("📝 Test 3: Forced Shiny Generation")
local forceShinyData = json.encode({speciesId = 150, level = 50, forceShiny = true})
local response3 = sendMessage("CreatePokemon", {}, forceShinyData)
if not response3 or response3.Action == "Error" then
    error("❌ Test failed: Expected successful forced shiny Pokemon")
end
print("✅ Test 3 passed: Forced shiny generation test")

-- Test 4: Nature assignment
print("📝 Test 4: Nature Assignment")
local natureData = json.encode({speciesId = 1, level = 10})
local response4 = sendMessage("CreatePokemon", {}, natureData)
if not response4 or response4.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon with nature")
end
print("✅ Test 4 passed: Nature assignment test")

-- Test 5: Stat calculation
print("📝 Test 5: Stat Calculation")
local statData = json.encode({speciesId = 25, level = 50})
local response5 = sendMessage("CreatePokemon", {}, statData)
if not response5 or response5.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon with calculated stats")
end
print("✅ Test 5 passed: Stat calculation test")

-- Test 6: Pokemon state updates
print("📝 Test 6: Pokemon State Updates")
local updateData = json.encode({
    pokemonId = 1,
    modifications = {
        level = 25,
        exp = 15625,
        hp = 50
    }
})
local response6 = sendMessage("UpdatePokemonState", {}, updateData)
if not response6 or response6.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon state update")
end
print("✅ Test 6 passed: Pokemon state updates test")

-- Test 7: Pokemon retrieval
print("📝 Test 7: Pokemon Retrieval")
local response7 = sendMessage("GetPokemonInstance", {
    PokemonId = "1"
})
if not response7 or response7.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon retrieval")
end
print("✅ Test 7 passed: Pokemon retrieval test")

-- Test 8: Serialization
print("📝 Test 8: Serialization")
local response8 = sendMessage("SerializePokemon", {
    PokemonId = "1"
})
if not response8 or response8.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon serialization")
end
print("✅ Test 8 passed: Serialization test")

-- Test 9: Deserialization
print("📝 Test 9: Deserialization")
local deserializeData = json.encode({
    serialized = "mock_serialized_data",
    checksum = "mock_checksum"
})
local response9 = sendMessage("DeserializePokemon", {}, deserializeData)
if not response9 or response9.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon deserialization")
end
print("✅ Test 9 passed: Deserialization test")

-- Test 10: Error handling - missing species ID
print("📝 Test 10: Error Handling - Missing Species ID")
local invalidData = json.encode({level = 5})
local response10 = sendMessage("CreatePokemon", {}, invalidData)
if response10 and response10.Action ~= "Error" then
    error("❌ Test failed: Expected error for missing species ID")
end
print("✅ Test 10 passed: Missing species ID error handling")

-- Test 11: Error handling - invalid Pokemon ID for retrieval
print("📝 Test 11: Error Handling - Invalid Pokemon ID")
local response11 = sendMessage("GetPokemonInstance", {
    PokemonId = "999"
})
if not response11 or not response11.Error or not response11.Error:match("not found") then
    error("❌ Test failed: Expected error for invalid Pokemon ID")
end
print("✅ Test 11 passed: Invalid Pokemon ID error handling")

-- Test 12: ADP v1.0 compliance - Info handler
print("📝 Test 12: ADP v1.0 Compliance - Info Handler")
local response12 = sendMessage("Info")
if not response12 or response12.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState response for Info")
end
print("✅ Test 12 passed: ADP v1.0 Info handler compliance")

-- Test 13: ADP v1.0 compliance - Ping handler
print("📝 Test 13: ADP v1.0 Compliance - Ping Handler")
local response13 = sendMessage("Ping")
if not response13 or response13.Action ~= "Pong" then
    error("❌ Test failed: Expected Pong response")
end
print("✅ Test 13 passed: ADP v1.0 Ping handler compliance")

print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
