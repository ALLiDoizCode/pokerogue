-- PC Storage Manager Unit Tests
-- Tests all storage operations, party management, and validation functionality

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.pc-storage-manager"
local processId = "test-pc-storage-manager"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for PC Storage Manager")
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

-- Test 1: Process initialization
print("📝 Test 1: Process Initialization")
local response1 = sendMessage("Info")
if not response1 or response1.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState response for Info")
end
print("✅ Test 1 passed: Process initialization successful")

-- Test 2: Ping handler
print("📝 Test 2: Ping Handler")
local response2 = sendMessage("Ping")
if not response2 or response2.Action ~= "Pong" then
    error("❌ Test failed: Expected Pong response")
end
print("✅ Test 2 passed: Ping handler working")

-- Test 3: Player storage initialization
print("📝 Test 3: Player Storage Initialization")
local response3 = sendMessage("ProcessLogic", {
    Operation = "validateIntegrity"
})
if not response3 or response3.Action == "Error" then
    error("❌ Test failed: Expected successful storage initialization")
end
print("✅ Test 3 passed: Player storage initialization successful")

-- Test 4: Deposit Pokemon
print("📝 Test 4: Deposit Pokemon Operations")
local response4 = sendMessage("ProcessLogic", {
    Operation = "deposit",
    PokemonId = "pokemon_001",
    TargetBox = "1",
    TargetSlot = "1"
})
if not response4 or response4.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon deposit")
end
print("✅ Test 4 passed: Pokemon deposit operations working")

-- Test 5: Deposit to occupied slot (should fail)
print("📝 Test 5: Deposit to Occupied Slot")
local response5 = sendMessage("ProcessLogic", {
    Operation = "deposit",
    PokemonId = "pokemon_002",
    TargetBox = "1",
    TargetSlot = "1"
})
if response5 and response5.Action ~= "Error" then
    error("❌ Test failed: Expected error for occupied slot")
end
print("✅ Test 5 passed: Occupied slot error handling")

-- Test 6: Deposit to auto-selected slot
print("📝 Test 6: Deposit to Auto-Selected Slot")
local response6 = sendMessage("ProcessLogic", {
    Operation = "deposit",
    PokemonId = "pokemon_002",
    TargetBox = "1"
})
if not response6 or response6.Action == "Error" then
    error("❌ Test failed: Expected successful auto-slot deposit")
end
print("✅ Test 6 passed: Auto-slot deposit working")

-- Test 7: Withdraw Pokemon
print("📝 Test 7: Withdraw Pokemon Operations")
local response7 = sendMessage("ProcessLogic", {
    Operation = "withdraw",
    SourceBox = "1",
    SourceSlot = "1",
    TargetSlot = "1"
})
if not response7 or response7.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon withdrawal")
end
print("✅ Test 7 passed: Pokemon withdraw operations working")

-- Test 8: Withdraw from empty slot (should fail)
print("📝 Test 8: Withdraw from Empty Slot")
local response8 = sendMessage("ProcessLogic", {
    Operation = "withdraw",
    SourceBox = "1",
    SourceSlot = "1"
})
if response8 and response8.Action ~= "Error" then
    error("❌ Test failed: Expected error for empty slot withdrawal")
end
print("✅ Test 8 passed: Empty slot withdrawal error handling")

-- Test 9: Swap Pokemon
print("📝 Test 9: Swap Pokemon Operations")
-- First deposit two Pokemon
sendMessage("ProcessLogic", {
    Operation = "deposit",
    PokemonId = "pokemon_swap_001",
    TargetBox = "2",
    TargetSlot = "1"
})
sendMessage("ProcessLogic", {
    Operation = "deposit",
    PokemonId = "pokemon_swap_002",
    TargetBox = "2",
    TargetSlot = "2"
})

local swapData = json.encode({
    operation = "swap",
    sourceLocation = {type = "pc", box = 2, slot = 1},
    targetLocation = {type = "pc", box = 2, slot = 2}
})
local response9 = sendMessage("ProcessLogic", {}, swapData)
if not response9 or response9.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon swap")
end
print("✅ Test 9 passed: Pokemon swap operations working")

-- Test 10: Release Pokemon
print("📝 Test 10: Release Pokemon Operations")
local releaseData = json.encode({
    operation = "release",
    location = {type = "pc", box = 2, slot = 1}
})
local response10 = sendMessage("ProcessLogic", {}, releaseData)
if not response10 or response10.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon release")
end
print("✅ Test 10 passed: Pokemon release operations working")

-- Test 11: Party management - swap positions
print("📝 Test 11: Party Management - Swap Positions (Error Expected)")
-- First add a second Pokemon to party
sendMessage("ProcessLogic", {
    Operation = "withdraw",
    SourceBox = "1",
    SourceSlot = "2",
    TargetSlot = "2"
})
-- Now swap the two party positions
local response11 = sendMessage("ProcessLogic", {
    Operation = "swapPartyPositions",
    Position1 = "1",
    Position2 = "2"
})
if not response11 or response11.Action == "Error" then
    error("❌ Test failed: Expected successful party position swap")
end
print("✅ Test 11 passed: Party position swap working")

-- Test 12: Party management - set lead Pokemon
print("📝 Test 12: Party Management - Set Lead Pokemon")
local response12 = sendMessage("ProcessLogic", {
    Operation = "setLeadPokemon",
    PartyPosition = "1"
})
if not response12 or response12.Action == "Error" then
    error("❌ Test failed: Expected successful lead Pokemon set")
end
print("✅ Test 12 passed: Set lead Pokemon working")

-- Test 13: Search Pokemon
print("📝 Test 13: Search Pokemon Operations")
local searchData = json.encode({
    operation = "search",
    searchCriteria = {}
})
local response13 = sendMessage("ProcessLogic", {}, searchData)
if not response13 or response13.Action == "Error" then
    error("❌ Test failed: Expected successful Pokemon search")
end
print("✅ Test 13 passed: Pokemon search operations working")

-- Test 14: Error handling - missing operation
print("📝 Test 14: Error Handling - Missing Operation")
local response14 = sendMessage("ProcessLogic")
if response14 and response14.Action ~= "Error" then
    error("❌ Test failed: Expected error for missing operation")
end
print("✅ Test 14 passed: Missing operation error handling")

-- Test 15: Error handling - invalid operation
print("📝 Test 15: Error Handling - Invalid Operation")
local response15 = sendMessage("ProcessLogic", {
    Operation = "invalidOperation"
})
if response15 and response15.Action ~= "Error" then
    error("❌ Test failed: Expected error for invalid operation")
end
print("✅ Test 15 passed: Invalid operation error handling")

-- Test 16: Error handling - invalid box number
print("📝 Test 16: Error Handling - Invalid Box Number")
local response16 = sendMessage("ProcessLogic", {
    Operation = "deposit",
    PokemonId = "pokemon_error",
    TargetBox = "99"
})
if response16 and response16.Action ~= "Error" then
    error("❌ Test failed: Expected error for invalid box number")
end
print("✅ Test 16 passed: Invalid box number error handling")

print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
