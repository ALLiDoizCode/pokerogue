-- Entry Hazard Engine Integration Test
-- Tests entry hazard system integration with battle flow

local aolite = require('aolite')

print("🧪 Running Entry Hazard Integration Tests...")
print("===============================================")

-- Test 1: Basic Integration Test
local function testBasicIntegration()
    print("🔬 Testing basic entry hazard integration...")
    
    -- Load the entry hazard process
    local process = aolite.spawnProcess("processes/entry-hazard-engine.lua")
    
    if not process then
        error("Failed to spawn entry hazard process")
    end
    
    -- Test placing spikes
    local placeResult = aolite.send(process.id, {
        Action = "PlaceEntryHazard",
        HazardType = "SPIKES",
        Side = "PLAYER", 
        BattleId = "test_battle_123",
        SourceId = "456",
        SourceMove = "SPIKES",
        Timestamp = "1234567890"
    })
    
    if not placeResult or not placeResult.success then
        error("Failed to place hazard: " .. tostring(placeResult and placeResult.error or "unknown error"))
    end
    
    print("✓ Successfully placed spikes")
    
    -- Test hazard activation
    local pokemonData = {
        stats = { hp = 100 },
        types = { "NORMAL" },
        ability = nil
    }
    
    local activateResult = aolite.send(process.id, {
        Action = "ActivateEntryHazards",
        PokemonData = require('json').encode(pokemonData),
        Side = "PLAYER",
        BattleId = "test_battle_123",
        Timestamp = "1234567890"
    })
    
    if not activateResult or not activateResult.success then
        error("Failed to activate hazards: " .. tostring(activateResult and activateResult.error or "unknown error"))
    end
    
    print("✓ Successfully activated entry hazards")
    
    return true
end

-- Test 2: Performance Test
local function testPerformance()
    print("🔬 Testing entry hazard performance...")
    
    local process = aolite.spawnProcess("processes/entry-hazard-engine.lua")
    
    local startTime = os.clock()
    
    -- Place multiple hazards quickly
    for i = 1, 10 do
        local result = aolite.send(process.id, {
            Action = "PlaceEntryHazard", 
            HazardType = "SPIKES",
            Side = "PLAYER",
            BattleId = "perf_test_" .. i,
            SourceId = "789",
            SourceMove = "SPIKES",
            Timestamp = tostring(1234567890 + i)
        })
        
        if not result or not result.success then
            error("Performance test failed at iteration " .. i)
        end
    end
    
    local endTime = os.clock()
    local duration = (endTime - startTime) * 1000 -- Convert to milliseconds
    
    print("✓ Placed 10 hazards in " .. string.format("%.2f", duration) .. "ms")
    
    if duration > 50 then -- Should be under 50ms per story requirements
        error("Performance test failed: " .. duration .. "ms exceeds 50ms limit")
    end
    
    return true
end

-- Test 3: Multi-Hazard Test
local function testMultipleHazardTypes()
    print("🔬 Testing multiple hazard types...")
    
    local process = aolite.spawnProcess("processes/entry-hazard-engine.lua")
    
    local hazardTypes = {"SPIKES", "STEALTH_ROCK", "TOXIC_SPIKES", "STICKY_WEB"}
    
    for _, hazardType in ipairs(hazardTypes) do
        local result = aolite.send(process.id, {
            Action = "PlaceEntryHazard",
            HazardType = hazardType,
            Side = "ENEMY",
            BattleId = "multi_hazard_test",
            SourceId = "101",
            SourceMove = hazardType,
            Timestamp = "1234567890"
        })
        
        if not result or not result.success then
            error("Failed to place " .. hazardType .. ": " .. tostring(result and result.error or "unknown error"))
        end
    end
    
    print("✓ Successfully placed all 4 hazard types")
    
    -- Test activation of all hazards
    local pokemonData = {
        stats = { hp = 100 },
        types = { "FIRE", "FLYING" }, -- Will take 4x damage from Stealth Rock
        ability = nil
    }
    
    local activateResult = aolite.send(process.id, {
        Action = "ActivateEntryHazards", 
        PokemonData = require('json').encode(pokemonData),
        Side = "ENEMY",
        BattleId = "multi_hazard_test",
        Timestamp = "1234567890"
    })
    
    if not activateResult or not activateResult.success then
        error("Failed to activate multiple hazards: " .. tostring(activateResult and activateResult.error or "unknown error"))
    end
    
    print("✓ Successfully activated multiple hazard types")
    
    return true
end

-- Test 4: ADP Compliance Test
local function testADPCompliance()
    print("🔬 Testing ADP v1.0 compliance...")
    
    local process = aolite.spawnProcess("processes/entry-hazard-engine.lua")
    
    local infoResult = aolite.send(process.id, {
        Action = "Info",
        Timestamp = "1234567890"
    })
    
    if not infoResult or not infoResult.success then
        error("ADP Info handler failed: " .. tostring(infoResult and infoResult.error or "unknown error"))
    end
    
    -- Parse response data to check ADP compliance
    local infoData = require('json').decode(infoResult.data or "{}")
    
    if not infoData.process or infoData.process.adpVersion ~= "1.0" then
        error("Process is not ADP v1.0 compliant")
    end
    
    if not infoData.handlers or #infoData.handlers < 4 then
        error("Process does not expose required handlers")
    end
    
    print("✓ Process is ADP v1.0 compliant")
    
    return true
end

-- Run all tests
local tests = {
    {"Basic Integration", testBasicIntegration},
    {"Performance", testPerformance},
    {"Multiple Hazard Types", testMultipleHazardTypes},
    {"ADP Compliance", testADPCompliance}
}

local passed = 0
local failed = 0

for _, test in ipairs(tests) do
    local testName, testFunc = test[1], test[2]
    
    local success, error = pcall(testFunc)
    
    if success then
        print("✅ " .. testName .. " - PASSED")
        passed = passed + 1
    else
        print("❌ " .. testName .. " - FAILED: " .. tostring(error))
        failed = failed + 1
    end
    print("")
end

print("===============================================")
print("📊 Integration Test Results:")
print("  ✅ Passed: " .. passed)
print("  ❌ Failed: " .. failed)
print("  📈 Total:  " .. (passed + failed))

if failed == 0 then
    print("🎉 All integration tests passed!")
    return true
else
    print("💥 Some integration tests failed!")
    return false
end