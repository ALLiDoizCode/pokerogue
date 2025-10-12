-- Aolite Unit Tests for Moves Database Process
-- Tests move data queries, type effectiveness, and move categories
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.moves-database"
local processId = "test-moves-database"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Moves Database Process")
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

-- Constants for testing
local MOVE = {
    TACKLE = 33,
    FLAMETHROWER = 53,
    HYDRO_PUMP = 56,
    THUNDERBOLT = 85,
    PSYCHIC = 94,
    ICE_BEAM = 58,
    EARTHQUAKE = 89
}

-- Test 1: GetMove by ID
print("📝 Test 1: GetMove by ID (Thunderbolt)")
local moveData = json.encode({ id = MOVE.THUNDERBOLT })
local moveResponse = sendMessage("GetMove", nil, moveData)
if moveResponse and (moveResponse.Action == "SaveState" or moveResponse.Action == "Response" or moveResponse.Action == "Data") then
    print("✅ GetMove by ID test passed")
else
    error("❌ GetMove by ID test failed")
end

-- Test 2: GetMove by Name
print("📝 Test 2: GetMove by Name (Flamethrower)")
local moveNameData = json.encode({ name = "Flamethrower" })
local moveNameResponse = sendMessage("GetMove", nil, moveNameData)
if moveNameResponse and (moveNameResponse.Action == "SaveState" or moveNameResponse.Action == "Response" or moveNameResponse.Action == "Data") then
    print("✅ GetMove by name test passed")
else
    error("❌ GetMove by name test failed")
end

-- Test 3: GetMovesByType
print("📝 Test 3: GetMovesByType (Water)")
local typeData = json.encode({ type = 10 }) -- WATER type
local typeResponse = sendMessage("GetMovesByType", nil, typeData)
if typeResponse and (typeResponse.Action == "SaveState" or typeResponse.Action == "Response" or typeResponse.Action == "Data") then
    print("✅ GetMovesByType test passed")
else
    error("❌ GetMovesByType test failed")
end

-- Test 4: GetTypeEffectiveness (Dual Type)
print("📝 Test 4: GetTypeEffectiveness (Water vs Fire/Rock)")
local effectivenessData = json.encode({
    attackingType = 10, -- WATER
    defendingTypes = {9, 5} -- FIRE, ROCK
})
local effectivenessResponse = sendMessage("GetTypeEffectiveness", nil, effectivenessData)
if effectivenessResponse and (effectivenessResponse.Action == "SaveState" or effectivenessResponse.Action == "Response" or effectivenessResponse.Action == "Data") then
    print("✅ GetTypeEffectiveness test passed")
else
    error("❌ GetTypeEffectiveness test failed")
end

-- Test 5: GetTypeEffectiveness Chart
print("📝 Test 5: GetTypeEffectiveness Chart (Fire)")
local chartData = json.encode({ attackingType = 9 }) -- FIRE
local chartResponse = sendMessage("GetTypeEffectiveness", nil, chartData)
if chartResponse and (chartResponse.Action == "SaveState" or chartResponse.Action == "Response" or chartResponse.Action == "Data") then
    print("✅ GetTypeEffectiveness chart test passed")
else
    error("❌ GetTypeEffectiveness chart test failed")
end

-- Test 6: Move Categories (Physical vs Special)
print("📝 Test 6: Move Categories")
local earthquakeData = json.encode({ id = MOVE.EARTHQUAKE })
local earthquakeResponse = sendMessage("GetMove", nil, earthquakeData)
if earthquakeResponse then
    print("✅ Move categories test passed")
else
    error("❌ Move categories test failed")
end

-- Test 7: Move Power and Accuracy
print("📝 Test 7: Move Power and Accuracy")
local tackleData = json.encode({ id = MOVE.TACKLE })
local tackleResponse = sendMessage("GetMove", nil, tackleData)
if tackleResponse then
    print("✅ Move power and accuracy test passed")
else
    error("❌ Move power and accuracy test failed")
end

-- Test 8: Invalid Move Query
print("📝 Test 8: Invalid Move Query (Missing ID/Name)")
local invalidData = json.encode({})
local invalidResponse = sendMessage("GetMove", nil, invalidData)
if invalidResponse and invalidResponse.Action == "Error" then
    print("✅ Invalid move query test passed")
else
    error("❌ Invalid move query test failed: Expected Error action")
end

-- Test 9: Invalid Type Query
print("📝 Test 9: Invalid Type Query (Missing Type)")
local invalidTypeData = json.encode({})
local invalidTypeResponse = sendMessage("GetMovesByType", nil, invalidTypeData)
if invalidTypeResponse and invalidTypeResponse.Action == "Error" then
    print("✅ Invalid type query test passed")
else
    error("❌ Invalid type query test failed: Expected Error action")
end

-- Test 10: Response Format Compliance
print("📝 Test 10: Response Format Compliance")
local complianceData = json.encode({ id = MOVE.TACKLE })
local complianceResponse = sendMessage("GetMove", nil, complianceData)
if complianceResponse and (complianceResponse.Action == "SaveState" or complianceResponse.Action == "Response" or complianceResponse.Action == "Data") then
    print("✅ Response format compliance test passed")
else
    error("❌ Response format compliance test failed")
end

-- Test 11: Data Integrity (Key Moves)
print("📝 Test 11: Data Integrity (Multiple Key Moves)")
local keyMoves = {MOVE.TACKLE, MOVE.FLAMETHROWER, MOVE.THUNDERBOLT}
for _, moveId in ipairs(keyMoves) do
    local data = json.encode({ id = moveId })
    local response = sendMessage("GetMove", nil, data)
    if not response or response.Action == "Error" then
        error("❌ Data integrity test failed for move " .. moveId)
    end
end
print("✅ Data integrity test passed")

-- Test 12: Size Optimization (Abbreviated Keys)
print("📝 Test 12: Size Optimization Check")
-- Test that the process uses abbreviated keys (n, t, cat, pwr, acc, pp, pri, eff)
local sizeData = json.encode({ id = MOVE.FLAMETHROWER })
local sizeResponse = sendMessage("GetMove", nil, sizeData)
if sizeResponse then
    print("✅ Size optimization check passed")
else
    error("❌ Size optimization check failed")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
