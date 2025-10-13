--[[
  Egg Tier Reward Engine Unit Tests
  Tests tier rolling, species selection, pity system, and reward calculation
  Using aolite framework for AO process testing
]]

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.egg-tier-reward-engine"
local processId = "test-egg-tier-reward"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Egg Tier Reward Engine")
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

local testsPassed = 0
local testsFailed = 0

local function assert_equal(actual, expected, testName)
    if actual == expected then
        print("✅ " .. testName)
        testsPassed = testsPassed + 1
        return true
    else
        print("❌ " .. testName)
        print("   Expected:", expected, "Got:", actual)
        testsFailed = testsFailed + 1
        return false
    end
end

local function assert_true(condition, testName)
    if condition then
        print("✅ " .. testName)
        testsPassed = testsPassed + 1
        return true
    else
        print("❌ " .. testName)
        testsFailed = testsFailed + 1
        return false
    end
end

-- ==============================================================================
-- Test 1: Info Handler (ADP v1.0 compliance)
-- ==============================================================================
print("\n📝 Test 1: Info handler returns process capabilities")
local response = sendMessage("Info")
if assert_equal(response.Action, "SaveState", "Info handler responds with SaveState") then
    local data = json.decode(response.Data)
    assert_equal(data.name, "Egg Tier Reward Engine", "Info includes process name")
    assert_equal(data.version, "1.0.0", "Info includes version")
    assert_equal(data.adpVersion, "1.0", "Info includes ADP version")
    assert_true(#data.handlers > 0, "Info includes handlers list")
end

-- ==============================================================================
-- Test 2: GetTierInfo Handler
-- ==============================================================================
print("\n📝 Test 2: GetTierInfo returns tier metadata")
response = sendMessage("GetTierInfo")
if assert_equal(response.Action, "SaveState", "GetTierInfo responds with SaveState") then
    local data = json.decode(response.Data)
    assert_true(data.tiers ~= nil, "GetTierInfo returns tiers object")
    assert_true(data.tiers["0"] ~= nil, "GetTierInfo includes COMMON tier")
    assert_equal(data.tiers["0"].name, "COMMON", "COMMON tier has correct name")
    assert_equal(data.tiers["0"].hatchWaves, 10, "COMMON tier has 10 hatch waves")
    assert_true(data.tiers["1"] ~= nil, "GetTierInfo includes RARE tier")
    assert_equal(data.tiers["1"].pityThreshold, 9, "RARE tier has pity threshold of 9")
end

-- ==============================================================================
-- Test 3: RollEggTier Handler - Standard Gacha
-- ==============================================================================
print("\n📝 Test 3: RollEggTier for standard gacha")
response = sendMessage("RollEggTier", {
    SourceType = "GACHA_DEFAULT"
})
if assert_equal(response.Action, "SaveState", "RollEggTier responds with SaveState") then
    assert_true(response.Tier ~= nil, "RollEggTier returns Tier")
    assert_true(response.TierName ~= nil, "RollEggTier returns TierName")
    assert_true(response.HatchWaves ~= nil, "RollEggTier returns HatchWaves")
    local tier = tonumber(response.Tier)
    assert_true(tier >= 0 and tier <= 3, "Tier value is in valid range (0-3)")
end

-- ==============================================================================
-- Test 4: RollEggTier Handler - Legendary Gacha (threshold offset)
-- ==============================================================================
print("\n📝 Test 4: RollEggTier for legendary gacha with threshold offset")
response = sendMessage("RollEggTier", {
    SourceType = "GACHA_LEGENDARY"
})
if assert_equal(response.Action, "SaveState", "RollEggTier with legendary source responds") then
    local tier = tonumber(response.Tier)
    assert_true(tier >= 0 and tier <= 3, "Legendary gacha returns valid tier")
end

-- ==============================================================================
-- Test 5: GetSpeciesByTier Handler
-- ==============================================================================
print("\n📝 Test 5: GetSpeciesByTier returns species pool")
response = sendMessage("GetSpeciesByTier", {
    Tier = "0"  -- COMMON tier
})
if assert_equal(response.Action, "SaveState", "GetSpeciesByTier responds with SaveState") then
    local data = json.decode(response.Data)
    assert_equal(data.tier, 0, "GetSpeciesByTier returns correct tier")
    assert_true(data.poolSize > 0, "GetSpeciesByTier returns non-empty species pool")
    assert_true(#data.speciesPool > 0, "Species pool array has entries")
    print(string.format("   COMMON tier has %d species", data.poolSize))
end

-- ==============================================================================
-- Test 6: GetSpeciesByTier for all tiers
-- ==============================================================================
print("\n📝 Test 6: GetSpeciesByTier for all tier values")
for tier = 0, 3 do
    response = sendMessage("GetSpeciesByTier", {
        Tier = tostring(tier)
    })
    if assert_equal(response.Action, "SaveState", string.format("Tier %d query succeeds", tier)) then
        local data = json.decode(response.Data)
        assert_true(data.poolSize > 0, string.format("Tier %d has species", tier))
    end
end

-- ==============================================================================
-- Test 7: RollSpecies Handler
-- ==============================================================================
print("\n📝 Test 7: RollSpecies selects species from tier pool")
response = sendMessage("RollSpecies", {
    Tier = "1"  -- RARE tier
})
if assert_equal(response.Action, "SaveState", "RollSpecies responds with SaveState") then
    assert_true(response.SpeciesId ~= nil, "RollSpecies returns SpeciesId")
    assert_true(response.StarterCost ~= nil, "RollSpecies returns StarterCost")
    assert_equal(response.Tier, "1", "RollSpecies returns correct tier")
    local cost = tonumber(response.StarterCost)
    assert_true(cost >= 4 and cost <= 5, "RARE tier species has cost 4-5")
end

-- ==============================================================================
-- Test 8: ValidateTierProgression Handler
-- ==============================================================================
print("\n📝 Test 8: ValidateTierProgression validates pity counters")
local eggPity = json.encode({
    ["1"] = 5,  -- RARE pity at 5
    ["2"] = 30, -- EPIC pity at 30
    ["3"] = 200 -- LEGENDARY pity at 200
})
response = sendMessage("ValidateTierProgression", {
    EggPity = eggPity
})
if assert_equal(response.Action, "SaveState", "ValidateTierProgression responds") then
    local data = json.decode(response.Data)
    assert_equal(data.valid, true, "Pity counters are valid")
    assert_true(data.pityStatus ~= nil, "ValidateTierProgression returns pity status")
end

-- ==============================================================================
-- Test 9: GetEggMoveIndex Handler
-- ==============================================================================
print("\n📝 Test 9: GetEggMoveIndex returns move slot")
response = sendMessage("GetEggMoveIndex", {
    Tier = "2",  -- EPIC tier
    SourceType = "GACHA_DEFAULT"
})
if assert_equal(response.Action, "SaveState", "GetEggMoveIndex responds with SaveState") then
    assert_true(response.EggMoveIndex ~= nil, "GetEggMoveIndex returns move index")
    local moveIndex = tonumber(response.EggMoveIndex)
    assert_true(moveIndex >= 0 and moveIndex <= 3, "Move index is in valid range (0-3)")
end

-- ==============================================================================
-- Test 10: Error Handling - Missing SourceType
-- ==============================================================================
print("\n📝 Test 10: Error handling for missing SourceType")
response = sendMessage("RollEggTier", {})
assert_equal(response.Action, "Error", "RollEggTier returns Error for missing SourceType")
assert_true(response.Error ~= nil, "Error message is provided")

-- ==============================================================================
-- Test 11: Error Handling - Invalid Tier
-- ==============================================================================
print("\n📝 Test 11: Error handling for invalid tier value")
response = sendMessage("GetSpeciesByTier", {
    Tier = "10"  -- Invalid tier
})
assert_equal(response.Action, "Error", "GetSpeciesByTier returns Error for invalid tier")

-- ==============================================================================
-- Test 12: Pity System - Near Threshold
-- ==============================================================================
print("\n📝 Test 12: Pity system detects near-threshold status")
eggPity = json.encode({
    ["1"] = 8,  -- RARE pity at 8 (threshold is 9)
    ["2"] = 58, -- EPIC pity at 58 (threshold is 59)
    ["3"] = 410 -- LEGENDARY pity at 410 (threshold is 412)
})
response = sendMessage("ValidateTierProgression", {
    EggPity = eggPity
})
if assert_equal(response.Action, "SaveState", "ValidateTierProgression with near-threshold pity") then
    local data = json.decode(response.Data)
    assert_true(data.pityStatus["1"].nearThreshold, "RARE pity near threshold detected")
    assert_true(data.pityStatus["2"].nearThreshold, "EPIC pity near threshold detected")
    assert_true(data.pityStatus["3"].nearThreshold, "LEGENDARY pity near threshold detected")
end

-- ==============================================================================
-- Test 13: Species Weighting - Cost-based Selection
-- ==============================================================================
print("\n📝 Test 13: Species selection uses cost-based weighting")
-- Roll multiple species to verify cost distribution
local costCounts = {[4] = 0, [5] = 0}
for i = 1, 20 do
    response = sendMessage("RollSpecies", {
        Tier = "1"  -- RARE tier (costs 4-5)
    })
    if response.Action == "SaveState" then
        local cost = tonumber(response.StarterCost)
        if costCounts[cost] then
            costCounts[cost] = costCounts[cost] + 1
        end
    end
end
assert_true(costCounts[4] + costCounts[5] > 0, "Species selection returned valid costs")
print(string.format("   Cost distribution: 4=%d, 5=%d", costCounts[4], costCounts[5]))

-- ==============================================================================
-- Test Summary
-- ==============================================================================
print("\n" .. string.rep("=", 60))
print("🎉 Test Summary")
print(string.rep("=", 60))
print(string.format("✅ Passed: %d", testsPassed))
print(string.format("❌ Failed: %d", testsFailed))
print(string.format("📊 Total: %d", testsPassed + testsFailed))

if testsFailed > 0 then
    print("\n⚠️  Some tests failed - review output above")
    error("Test suite failed with " .. testsFailed .. " failures")
else
    print("\n✅ All tests passed!")
end
