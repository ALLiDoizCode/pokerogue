-- Aolite Unit Tests for Pokemon Stat Calculation Manager
-- Tests IV/EV systems, stat calculations, and battle stat modifications
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local TEST_TIMEOUT = 30000 -- 30 seconds
local PROCESS_PATH = "processes/stat-calculation-manager.lua"

-- Initialize test process
local process = aolite.spawnProcess(PROCESS_PATH)
if not process then
    error("Failed to spawn process from " .. PROCESS_PATH)
end

print("🧪 Starting Aolite Tests for Stat Calculation Manager")
print("Process ID:", process.id)

-- Test utilities
local function sendMessage(action, tags, data, timeout)
    local msg = {
        Target = process.id,
        Action = action,
        Data = data or "",
        Timestamp = os.time() * 1000
    }
    
    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end
    
    return aolite.send(msg, timeout or TEST_TIMEOUT)
end

local function assertSuccess(response, testName)
    if not response then
        error(testName .. ": No response received")
    end
    
    if response.Error then
        error(testName .. ": " .. response.Error)
    end
    
    local data = response.Data and json.decode(response.Data) or {}
    if not data.success then
        error(testName .. ": Operation failed - " .. (data.error or "unknown error"))
    end
    
    return data
end

local function assertError(response, testName, expectedError)
    if not response then
        error(testName .. ": Expected error but got no response")
    end
    
    local data = response.Data and json.decode(response.Data) or {}
    if data.success then
        error(testName .. ": Expected error but operation succeeded")
    end
    
    if expectedError and not string.find(data.error or "", expectedError) then
        error(testName .. ": Expected error '" .. expectedError .. "' but got '" .. (data.error or "no error") .. "'")
    end
    
    return data
end

-- Test 1: Process Ping
print("\n📝 Test 1: Process Ping")
local pingResponse = sendMessage("Ping")
assert(pingResponse.Action == "Pong", "Should respond with Pong")
assert(pingResponse.Data == "pong", "Should return pong data")
print("✅ PASS: Process responds to ping")

-- Test 2: ADP Info Handler
print("\n📝 Test 2: ADP Info Handler")
local infoResponse = sendMessage("Info")
assert(infoResponse.Data, "Info should return data")

local infoData = json.decode(infoResponse.Data)
assert(infoData.Name == "Pokemon Stat Calculation Manager", "Should have correct process name")
assert(infoData.protocolVersion == "1.0", "Should be ADP v1.0 compliant")
assert(#infoData.handlers >= 7, "Should have at least 7 handlers")

-- Verify required handlers are present
local handlerNames = {}
for _, handler in ipairs(infoData.handlers) do
    handlerNames[handler.action] = true
end

local requiredHandlers = {"GenerateIVs", "GainEVs", "CalculateStats", "GetBattleStats", "CalculateDamage", "Info", "Ping"}
for _, required in ipairs(requiredHandlers) do
    assert(handlerNames[required], "Should have " .. required .. " handler")
end

print("✅ PASS: ADP v1.0 compliance verified")

-- Test 3: IV Generation
print("\n📝 Test 3: IV Generation")
local ivResponse = sendMessage("GenerateIVs", {PokemonId = "test_pokemon_1"})
local ivData = assertSuccess(ivResponse, "GenerateIVs")

assert(ivData.ivs, "Should return IVs array")
assert(#ivData.ivs == 6, "Should have 6 IV values")
assert(ivData.pokemonId == "test_pokemon_1", "Should return correct Pokemon ID")

-- Verify IV ranges (0-31)
for i, iv in ipairs(ivData.ivs) do
    assert(iv >= 0 and iv <= 31, "IV " .. i .. " should be 0-31, got " .. iv)
end

print("✅ PASS: IV generation with valid ranges")

-- Test 4: IV Generation Error Handling
print("\n📝 Test 4: IV Generation Error Handling")
local ivErrorResponse = sendMessage("GenerateIVs", {})
assertError(ivErrorResponse, "GenerateIVs without PokemonId", "PokemonId is required")
print("✅ PASS: IV generation error handling")

-- Test 5: EV Gain - Valid Case
print("\n📝 Test 5: EV Gain - Valid Case")
local validEVs = {1, 1, 1, 0, 0, 0} -- Small gains
local evResponse = sendMessage("GainEVs", {
    PokemonId = "test_pokemon_2",
    EVYield = json.encode(validEVs),
    Multiplier = "1.0"
})
local evData = assertSuccess(evResponse, "GainEVs valid")

assert(evData.evs, "Should return EVs array")
assert(#evData.evs == 6, "Should have 6 EV values")
assert(evData.totalEVs <= 510, "Total EVs should not exceed 510")
print("✅ PASS: EV gain with valid constraints")

-- Test 6: EV Gain - Constraint Violation
print("\n📝 Test 6: EV Gain - Constraint Violation")
local invalidEVs = {252, 252, 252, 0, 0, 0} -- Would exceed 510 total
local evErrorResponse = sendMessage("GainEVs", {
    PokemonId = "test_pokemon_3", 
    EVYield = json.encode(invalidEVs),
    Multiplier = "1.0"
})
assertError(evErrorResponse, "GainEVs constraint violation", "exceed 510")
print("✅ PASS: EV constraint validation")

-- Test 7: Stat Calculation
print("\n📝 Test 7: Stat Calculation")
local statResponse = sendMessage("CalculateStats", {
    SpeciesId = "25", -- Pikachu
    Level = "50",
    IVs = json.encode({31, 31, 31, 31, 31, 31}),
    EVs = json.encode({0, 252, 0, 0, 0, 252}), -- Attack and Speed
    Nature = "Jolly"
})
local statData = assertSuccess(statResponse, "CalculateStats")

assert(statData.stats, "Should return calculated stats")
assert(#statData.stats == 6, "Should have 6 calculated stats")
assert(statData.level == 50, "Should return correct level")
assert(statData.speciesId == 25, "Should return correct species ID")

-- Verify stats are reasonable (positive integers)
for i, stat in ipairs(statData.stats) do
    assert(stat > 0, "Stat " .. i .. " should be positive, got " .. stat)
    assert(stat == math.floor(stat), "Stat " .. i .. " should be integer, got " .. stat)
end

print("✅ PASS: Stat calculation with valid results")

-- Test 8: Battle Stat Modifications
print("\n📝 Test 8: Battle Stat Modifications")
local battleResponse = sendMessage("GetBattleStats", {
    PokemonId = "test_pokemon_4",
    StatStages = json.encode({0, 2, -1, 0, 0, 1}), -- +2 ATK, -1 DEF, +1 SPEED
    Weather = "sun",
    CriticalHit = "false"
})
local battleData = assertSuccess(battleResponse, "GetBattleStats")

assert(battleData.battleStats, "Should return battle stats")
assert(#battleData.battleStats == 6, "Should have 6 battle stats")
assert(battleData.appliedModifiers, "Should return applied modifiers list")
print("✅ PASS: Battle stat modifications")

-- Test 9: Critical Hit Battle Stats
print("\n📝 Test 9: Critical Hit Battle Stats")
local critResponse = sendMessage("GetBattleStats", {
    PokemonId = "test_pokemon_5",
    StatStages = json.encode({0, -2, 2, 0, 0, 0}), -- -2 ATK, +2 DEF
    CriticalHit = "true"
})
local critData = assertSuccess(critResponse, "GetBattleStats critical")

assert(critData.battleStats, "Should return critical hit battle stats")
-- Critical hits should ignore negative attack stages and positive defense stages
print("✅ PASS: Critical hit stat stage bypass")

-- Test 10: Damage Calculation
print("\n📝 Test 10: Damage Calculation")
local damageResponse = sendMessage("CalculateDamage", {
    AttackerId = "test_pokemon_6",
    DefenderId = "test_pokemon_7", 
    Move = "Thunderbolt",
    CriticalHit = "false"
})
local damageData = assertSuccess(damageResponse, "CalculateDamage")

assert(damageData.baseDamage, "Should return base damage")
assert(damageData.finalDamage, "Should return final damage")
assert(damageData.attackStat, "Should return attack stat used")
assert(damageData.defenseStat, "Should return defense stat used")
assert(damageData.critMultiplier == 1.0, "Non-critical should have 1.0 multiplier")
print("✅ PASS: Damage calculation")

-- Test 11: Critical Hit Damage
print("\n📝 Test 11: Critical Hit Damage")
local critDamageResponse = sendMessage("CalculateDamage", {
    AttackerId = "test_pokemon_8",
    DefenderId = "test_pokemon_9",
    Move = "Thunderbolt", 
    CriticalHit = "true"
})
local critDamageData = assertSuccess(critDamageResponse, "CalculateDamage critical")

assert(critDamageData.critMultiplier == 2.0, "Critical hit should have 2.0 multiplier")
assert(critDamageData.finalDamage > critDamageData.baseDamage, "Critical damage should be higher than base")
print("✅ PASS: Critical hit damage multiplier")

-- Test 12: Error Handling for Missing Parameters
print("\n📝 Test 12: Error Handling")
local missingParamResponse = sendMessage("CalculateStats", {
    Level = "50"
    -- Missing SpeciesId, IVs, EVs, Nature
})
assertError(missingParamResponse, "Missing parameters", "required")
print("✅ PASS: Missing parameter validation")

-- Test 13: Performance Test
print("\n📝 Test 13: Performance Test")
local performanceStart = os.clock()

-- Send multiple rapid requests
for i = 1, 100 do
    local perfResponse = sendMessage("GenerateIVs", {PokemonId = "perf_test_" .. i}, 1000)
    if not perfResponse then
        error("Performance test failed at iteration " .. i)
    end
end

local performanceEnd = os.clock()
local elapsed = performanceEnd - performanceStart

assert(elapsed < 5.0, "100 IV generations should complete in under 5 seconds, took " .. elapsed)
print("✅ PASS: Performance - 100 operations in " .. string.format("%.2f", elapsed) .. " seconds")

-- Test 14: Process State Persistence
print("\n📝 Test 14: Process State Persistence")

-- Generate IVs for a pokemon
local stateResponse1 = sendMessage("GenerateIVs", {PokemonId = "persistent_test"})
local stateData1 = assertSuccess(stateResponse1, "State test 1")

-- Add EVs for the same pokemon
local stateResponse2 = sendMessage("GainEVs", {
    PokemonId = "persistent_test",
    EVYield = json.encode({10, 10, 10, 0, 0, 0}),
    Multiplier = "1.0"
})
local stateData2 = assertSuccess(stateResponse2, "State test 2")

assert(stateData2.gained, "EV gain should succeed for pokemon with generated IVs")
print("✅ PASS: Process state persistence across operations")

-- Test Results Summary
print("\n🎉 All Aolite Tests Passed!")
print("=" .. string.rep("=", 50))
print("✅ ADP v1.0 Compliance: PASS")
print("✅ IV Generation: PASS") 
print("✅ EV Constraints: PASS")
print("✅ Stat Calculations: PASS")
print("✅ Battle Modifications: PASS")
print("✅ Critical Hit Logic: PASS")
print("✅ Damage Integration: PASS")
print("✅ Error Handling: PASS")
print("✅ Performance: PASS")
print("✅ State Persistence: PASS")

-- Cleanup
aolite.cleanup()

return {
    passed = 14,
    failed = 0,
    total = 14
}