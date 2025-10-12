-- Unit tests for egg-move-learning-engine.lua using aolite
-- Tests core functions: move validation, priority calculation, slot management

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.egg-move-learning-engine"
local processId = "test-egg-move-learning-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Egg Move Learning Engine")
print("Process ID:", processId)

-- Test utilities
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

-- ============================================================================
-- TEST SUITE: Egg Move Learning Engine
-- ============================================================================

print("\n=== Egg Move Learning Engine Tests ===\n")

-- Test 1: Info handler returns process capabilities
print("📝 Test 1: Info handler returns capabilities")
local response = sendMessage("Info")
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
local data = json.decode(response.Data)
if data.process.name ~= "Egg Move Learning Engine" then
    error("❌ Test failed: Expected process name 'Egg Move Learning Engine'")
end
if data.process.adpVersion ~= "1.0" then
    error("❌ Test failed: Expected ADP version '1.0'")
end
print("✅ Test passed")

-- Test 2: InheritEggMoves validates player ID
print("📝 Test 2: InheritEggMoves validates player ID")
response = sendMessage("InheritEggMoves", {
    Parent1Id = "parent1",
    Parent2Id = "parent2",
    OffspringSpeciesId = "1"
})
if not response or response.Action ~= "Error" then
    error("❌ Test failed: Expected Error action")
end
if response.Error ~= "Invalid player ID" then
    error("❌ Test failed: Expected error message 'Invalid player ID'")
end
print("✅ Test passed")

-- Test 3: InheritEggMoves validates parent IDs
print("📝 Test 3: InheritEggMoves validates parent IDs")
response = sendMessage("InheritEggMoves", {
    PlayerId = "player123",
    Parent1Id = "",
    Parent2Id = "parent2",
    OffspringSpeciesId = "1"
})
if not response or response.Action ~= "Error" then
    error("❌ Test failed: Expected Error action")
end
if response.Error ~= "Invalid Parent1Id" then
    error("❌ Test failed: Expected error message 'Invalid Parent1Id'")
end
print("✅ Test passed")

-- Test 4: InheritEggMoves inherits moves successfully
print("📝 Test 4: InheritEggMoves inherits moves successfully")
response = sendMessage("InheritEggMoves", {
    PlayerId = "player123",
    Parent1Id = "parent1",
    Parent2Id = "parent2",
    OffspringSpeciesId = "1"
})
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.Success ~= "true" then
    error("❌ Test failed: Expected Success = 'true'")
end
if not response.InheritedMoves then
    error("❌ Test failed: Expected InheritedMoves tag")
end
local moves = json.decode(response.InheritedMoves)
if #moves > 4 then
    error("❌ Test failed: Should not exceed 4 moves")
end
print("✅ Test passed")

-- Test 5: ValidateMoveLearn validates move ID
print("📝 Test 5: ValidateMoveLearn validates move ID")
response = sendMessage("ValidateMoveLearn", {
    PlayerId = "player123",
    PokemonId = "pokemon1",
    MoveId = "invalid"
})
if not response or response.Action ~= "Error" then
    error("❌ Test failed: Expected Error action")
end
if response.Error ~= "Invalid move ID" then
    error("❌ Test failed: Expected error message 'Invalid move ID'")
end
print("✅ Test passed")

-- Test 6: ValidateMoveLearn validates slot number
print("📝 Test 6: ValidateMoveLearn validates slot number")
response = sendMessage("ValidateMoveLearn", {
    PlayerId = "player123",
    PokemonId = "pokemon1",
    MoveId = "1",
    SlotToReplace = "5"
})
if not response or response.Action ~= "Error" then
    error("❌ Test failed: Expected Error action")
end
if response.Error ~= "Invalid slot number (must be 1-4)" then
    error("❌ Test failed: Expected error message 'Invalid slot number (must be 1-4)'")
end
print("✅ Test passed")

-- Test 7: ValidateMoveLearn validates successfully
print("📝 Test 7: ValidateMoveLearn validates successfully")
response = sendMessage("ValidateMoveLearn", {
    PlayerId = "player123",
    PokemonId = "pokemon1",
    MoveId = "14"
})
if not response or response.Action ~= "MoveLearnValidated" then
    error("❌ Test failed: Expected MoveLearnValidated action")
end
if response.Valid ~= "true" then
    error("❌ Test failed: Expected Valid = 'true'")
end
if response.Success ~= "true" then
    error("❌ Test failed: Expected Success = 'true'")
end
print("✅ Test passed")

-- Test 8: GetEggMovePool returns egg move pool
print("📝 Test 8: GetEggMovePool returns egg move pool")
response = sendMessage("GetEggMovePool", {
    PlayerId = "player123",
    SpeciesId = "1"
})
if not response or response.Action ~= "EggMovePool" then
    error("❌ Test failed: Expected EggMovePool action")
end
if response.SpeciesId ~= "1" then
    error("❌ Test failed: Expected SpeciesId = '1'")
end
data = json.decode(response.Data)
if type(data.availableMoves) ~= "table" then
    error("❌ Test failed: Expected availableMoves to be table")
end
if type(data.priority) ~= "table" then
    error("❌ Test failed: Expected priority to be table")
end
print("✅ Test passed")

-- Test 9: ManageMoveSlots validates operation type
print("📝 Test 9: ManageMoveSlots validates operation type")
response = sendMessage("ManageMoveSlots", {
    PlayerId = "player123",
    PokemonId = "pokemon1",
    Operation = "invalid"
})
if not response or response.Action ~= "Error" then
    error("❌ Test failed: Expected Error action")
end
if not string.find(response.Error, "Invalid operation") then
    error("❌ Test failed: Expected error message containing 'Invalid operation'")
end
print("✅ Test passed")

-- Test 10: ManageMoveSlots manages slots successfully
print("📝 Test 10: ManageMoveSlots manages slots successfully")
response = sendMessage("ManageMoveSlots", {
    PlayerId = "player123",
    PokemonId = "pokemon1",
    Operation = "add",
    MoveId = "14"
})
if not response or response.Action ~= "MoveSlotsUpdated" then
    error("❌ Test failed: Expected MoveSlotsUpdated action")
end
if response.Success ~= "true" then
    error("❌ Test failed: Expected Success = 'true'")
end
moves = json.decode(response.CurrentMoves)
if type(moves) ~= "table" then
    error("❌ Test failed: Expected CurrentMoves to be table")
end
if #moves ~= 4 then
    error("❌ Test failed: Expected 4 move slots, got " .. tostring(#moves))
end
print("✅ Test passed")

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
