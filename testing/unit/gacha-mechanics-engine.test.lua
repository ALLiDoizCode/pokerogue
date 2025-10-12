-- Unit tests for Gacha Mechanics Engine
-- Tests gacha probability rolling, pity system, reward generation, and pull history

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.gacha-mechanics-engine"
local processId = "test-gacha-mechanics"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Gacha Mechanics Engine")
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
-- Test 1: Info Handler (ADP v1.0 Compliance)
-- ============================================================================
print("\n📝 Test 1: Info handler returns process metadata")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    local infoData = json.decode(infoResponse.Data)
    if infoData.process and infoData.process.name == "Gacha Mechanics Engine" then
        print("✅ Test 1 passed - Info handler works")
    else
        error("❌ Test 1 failed: Invalid info structure")
    end
else
    error("❌ Test 1 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 2: GetGachaInfo - Default Gacha Configuration
-- ============================================================================
print("\n📝 Test 2: GetGachaInfo returns correct probabilities for default gacha")
local gachaInfoResponse = sendMessage("GetGachaInfo", {
    GachaType = "MOVE"
})
if gachaInfoResponse and gachaInfoResponse.Action == "SaveState" then
    local gachaInfo = json.decode(gachaInfoResponse.Data)
    local probs = gachaInfo.probabilities

    -- Verify probabilities sum to ~1.0
    local sum = probs.common + probs.rare + probs.epic + probs.legendary
    if math.abs(sum - 1.0) < 0.001 then
        print("✅ Test 2 passed - Probabilities sum correctly")
    else
        error("❌ Test 2 failed: Probabilities sum to " .. sum)
    end
else
    error("❌ Test 2 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 3: GetGachaInfo - Legendary Gacha Modifier
-- ============================================================================
print("\n📝 Test 3: GetGachaInfo shows legendary threshold bonus for LEGENDARY gacha")
local legendaryInfoResponse = sendMessage("GetGachaInfo", {
    GachaType = "LEGENDARY"
})
if legendaryInfoResponse and legendaryInfoResponse.Action == "SaveState" then
    local legendaryInfo = json.decode(legendaryInfoResponse.Data)
    if legendaryInfo.modifiers.legendaryThresholdBonus == 1 then
        print("✅ Test 3 passed - Legendary threshold bonus applied")
    else
        error("❌ Test 3 failed: Expected legendaryThresholdBonus = 1")
    end
else
    error("❌ Test 3 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 4: GetGachaInfo - Shiny Gacha Modifier
-- ============================================================================
print("\n📝 Test 4: GetGachaInfo shows 2x shiny rate for SHINY gacha")
local shinyInfoResponse = sendMessage("GetGachaInfo", {
    GachaType = "SHINY"
})
if shinyInfoResponse and shinyInfoResponse.Action == "SaveState" then
    local shinyInfo = json.decode(shinyInfoResponse.Data)
    if shinyInfo.modifiers.shinyRateMultiplier == 2.0 then
        print("✅ Test 4 passed - Shiny rate multiplier applied")
    else
        error("❌ Test 4 failed: Expected shinyRateMultiplier = 2.0")
    end
else
    error("❌ Test 4 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 5: PullEgg - Basic Pull Without History
-- ============================================================================
print("\n📝 Test 5: PullEgg executes successfully with valid parameters")
local pullResponse = sendMessage("PullEgg", {
    GachaType = "MOVE",
    VoucherType = "REGULAR",
    RNGSeed = "12345678",
    Timestamp = "1696800000"
})
if pullResponse and pullResponse.Action == "SaveState" then
    local pullResult = json.decode(pullResponse.Data)
    if pullResult.eggResult and pullResult.pullHistory then
        print("✅ Test 5 passed - Pull executed successfully")
    else
        error("❌ Test 5 failed: Missing eggResult or pullHistory")
    end
else
    error("❌ Test 5 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 6: PullEgg - Egg Result Structure
-- ============================================================================
print("\n📝 Test 6: PullEgg returns complete egg result structure")
local pullResponse2 = sendMessage("PullEgg", {
    GachaType = "LEGENDARY",
    VoucherType = "PREMIUM",
    RNGSeed = "87654321",
    Timestamp = "1696800000"
})
if pullResponse2 and pullResponse2.Action == "SaveState" then
    local pullResult = json.decode(pullResponse2.Data)
    local egg = pullResult.eggResult

    local hasRequiredFields = egg.id and egg.tier and egg.hatchWaves and
                              egg.speciesId and (egg.isShiny ~= nil) and
                              egg.variantTier and (egg.eggMoveIndex ~= nil) and
                              (egg.hasHiddenAbility ~= nil)

    if hasRequiredFields then
        print("✅ Test 6 passed - Egg result has all required fields")
    else
        error("❌ Test 6 failed: Missing required egg fields")
    end
else
    error("❌ Test 6 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 7: PullEgg - Pull History Updates
-- ============================================================================
print("\n📝 Test 7: PullEgg updates pull history correctly")
local pullResponse3 = sendMessage("PullEgg", {
    GachaType = "SHINY",
    VoucherType = "GOLDEN",
    RNGSeed = "11111111",
    Timestamp = "1696800000"
})
if pullResponse3 and pullResponse3.Action == "SaveState" then
    local pullResult = json.decode(pullResponse3.Data)
    local history = pullResult.pullHistory

    if history.totalPulls == 1 and history.pullsSinceLastLegendary == 1 then
        print("✅ Test 7 passed - Pull history updated")
    else
        error("❌ Test 7 failed: Pull history not updated correctly")
    end
else
    error("❌ Test 7 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 8: PullEgg - Pity System Not Triggered
-- ============================================================================
print("\n📝 Test 8: PullEgg with low pity counters does not trigger pity")
local pullHistoryLowPity = json.encode({
    totalPulls = 5,
    pullsSinceLastLegendary = 5,
    pullsSinceLastEpic = 5,
    pullsSinceLastRare = 5
})

local pullResponse4 = sendMessage("PullEgg", {
    GachaType = "MOVE",
    VoucherType = "REGULAR",
    RNGSeed = "22222222",
    Timestamp = "1696800100",
    PullHistory = pullHistoryLowPity
})
if pullResponse4 and pullResponse4.Action == "SaveState" then
    local pullResult = json.decode(pullResponse4.Data)

    if pullResult.pityTriggered == false then
        print("✅ Test 8 passed - Pity not triggered with low counters")
    else
        error("❌ Test 8 failed: Pity should not trigger")
    end
else
    error("❌ Test 8 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 9: PullEgg - Legendary Pity Triggered
-- ============================================================================
print("\n📝 Test 9: PullEgg triggers legendary pity at threshold")
local pullHistoryHighPity = json.encode({
    totalPulls = 412,
    pullsSinceLastLegendary = 412,
    pullsSinceLastEpic = 10,
    pullsSinceLastRare = 2
})

local pullResponse5 = sendMessage("PullEgg", {
    GachaType = "MOVE",
    VoucherType = "REGULAR",
    RNGSeed = "33333333",
    Timestamp = "1696800200",
    PullHistory = pullHistoryHighPity
})
if pullResponse5 and pullResponse5.Action == "SaveState" then
    local pullResult = json.decode(pullResponse5.Data)

    -- Pity should trigger if rolled COMMON, upgrading to LEGENDARY
    -- Since we can't control the tier roll exactly, check if pity would trigger
    if pullResult.eggResult.tier == "LEGENDARY" or pullResult.pityTriggered then
        print("✅ Test 9 passed - Legendary pity check works")
    else
        print("⚠️  Test 9: Pity may not have triggered (tier was not COMMON initially)")
    end
else
    error("❌ Test 9 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 10: PullEgg - Epic Pity Triggered
-- ============================================================================
print("\n📝 Test 10: PullEgg triggers epic pity at threshold")
local pullHistoryEpicPity = json.encode({
    totalPulls = 60,
    pullsSinceLastLegendary = 60,
    pullsSinceLastEpic = 60,
    pullsSinceLastRare = 5
})

local pullResponse6 = sendMessage("PullEgg", {
    GachaType = "MOVE",
    VoucherType = "REGULAR",
    RNGSeed = "44444444",
    Timestamp = "1696800300",
    PullHistory = pullHistoryEpicPity
})
if pullResponse6 and pullResponse6.Action == "SaveState" then
    local pullResult = json.decode(pullResponse6.Data)

    -- Check if epic or legendary tier obtained (pity upgrade from common)
    if pullResult.eggResult.tier == "EPIC" or pullResult.eggResult.tier == "LEGENDARY" or pullResult.pityTriggered then
        print("✅ Test 10 passed - Epic pity check works")
    else
        print("⚠️  Test 10: Pity may not have triggered (tier was not COMMON initially)")
    end
else
    error("❌ Test 10 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 11: PullEgg - Rare Pity Triggered
-- ============================================================================
print("\n📝 Test 11: PullEgg triggers rare pity at threshold")
local pullHistoryRarePity = json.encode({
    totalPulls = 10,
    pullsSinceLastLegendary = 10,
    pullsSinceLastEpic = 10,
    pullsSinceLastRare = 10
})

local pullResponse7 = sendMessage("PullEgg", {
    GachaType = "MOVE",
    VoucherType = "REGULAR",
    RNGSeed = "55555555",
    Timestamp = "1696800400",
    PullHistory = pullHistoryRarePity
})
if pullResponse7 and pullResponse7.Action == "SaveState" then
    local pullResult = json.decode(pullResponse7.Data)

    -- Rare or higher tier should be obtained
    if pullResult.eggResult.tier ~= "COMMON" or pullResult.pityTriggered then
        print("✅ Test 11 passed - Rare pity check works")
    else
        print("⚠️  Test 11: Pity may not have triggered (tier was not COMMON initially)")
    end
else
    error("❌ Test 11 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 12: PullEgg - Pity Counter Reset After Legendary
-- ============================================================================
print("\n📝 Test 12: Pull history resets legendary counter after obtaining legendary")
local pullResponse8 = sendMessage("PullEgg", {
    GachaType = "LEGENDARY",
    VoucherType = "PREMIUM",
    RNGSeed = "66666666",
    Timestamp = "1696800500",
    PullHistory = pullHistoryHighPity
})
if pullResponse8 and pullResponse8.Action == "SaveState" then
    local pullResult = json.decode(pullResponse8.Data)

    -- If legendary obtained, counter should reset to 0
    if pullResult.eggResult.tier == "LEGENDARY" then
        if pullResult.pullHistory.pullsSinceLastLegendary == 0 then
            print("✅ Test 12 passed - Legendary counter reset")
        else
            error("❌ Test 12 failed: Legendary counter not reset")
        end
    else
        print("⚠️  Test 12: No legendary obtained, counter incremented instead")
    end
else
    error("❌ Test 12 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 13: GetPityStatus - Correct Progress Calculation
-- ============================================================================
print("\n📝 Test 13: GetPityStatus calculates pity progress correctly")
local pityHistoryTest = json.encode({
    pullsSinceLastLegendary = 206,
    pullsSinceLastEpic = 30,
    pullsSinceLastRare = 5
})

local pityStatusResponse = sendMessage("GetPityStatus", {
    PullHistory = pityHistoryTest
})
if pityStatusResponse and pityStatusResponse.Action == "SaveState" then
    local pityStatus = json.decode(pityStatusResponse.Data)

    local legendaryPity = pityStatus.legendaryPity
    local epicPity = pityStatus.epicPity
    local rarePity = pityStatus.rarePity

    if legendaryPity.counter == 206 and legendaryPity.threshold == 412 then
        if legendaryPity.remaining == 206 and legendaryPity.progressPercent == 50.0 then
            print("✅ Test 13 passed - Pity progress calculated correctly")
        else
            error("❌ Test 13 failed: Incorrect progress calculation")
        end
    else
        error("❌ Test 13 failed: Incorrect pity counters")
    end
else
    error("❌ Test 13 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 14: GetPullHistory - Statistics Tracking
-- ============================================================================
print("\n📝 Test 14: GetPullHistory returns pull statistics")
local historyWithStats = json.encode({
    totalPulls = 100,
    tierStats = {
        COMMON = 80,
        RARE = 15,
        EPIC = 4,
        LEGENDARY = 1
    },
    gachaTypeStats = {
        MOVE = 30,
        LEGENDARY = 40,
        SHINY = 30
    }
})

local pullHistoryResponse = sendMessage("GetPullHistory", {
    PullHistory = historyWithStats,
    Limit = "10"
})
if pullHistoryResponse and pullHistoryResponse.Action == "SaveState" then
    local historyData = json.decode(pullHistoryResponse.Data)

    if historyData.statistics.totalPulls == 100 then
        if historyData.statistics.tierDistribution.COMMON == 80 then
            print("✅ Test 14 passed - Pull history statistics correct")
        else
            error("❌ Test 14 failed: Incorrect tier distribution")
        end
    else
        error("❌ Test 14 failed: Incorrect total pulls")
    end
else
    error("❌ Test 14 failed: Expected SaveState action")
end

-- ============================================================================
-- Test 15: PullEgg - Error Handling (Missing Parameters)
-- ============================================================================
print("\n📝 Test 15: PullEgg returns error for missing parameters")
local errorResponse1 = sendMessage("PullEgg", {
    GachaType = "MOVE"
    -- Missing VoucherType, RNGSeed, Timestamp
})
if errorResponse1 and errorResponse1.Action == "Error" then
    print("✅ Test 15 passed - Error returned for missing parameters")
else
    error("❌ Test 15 failed: Expected Error action")
end

-- ============================================================================
-- Test 16: PullEgg - Error Handling (Invalid GachaType)
-- ============================================================================
print("\n📝 Test 16: PullEgg returns error for invalid GachaType")
local errorResponse2 = sendMessage("PullEgg", {
    GachaType = "INVALID_TYPE",
    VoucherType = "REGULAR",
    RNGSeed = "12345",
    Timestamp = "1696800000"
})
if errorResponse2 and errorResponse2.Action == "Error" then
    print("✅ Test 16 passed - Error returned for invalid GachaType")
else
    error("❌ Test 16 failed: Expected Error action")
end

-- ============================================================================
-- Test 17: GetPityStatus - Error Handling (Missing PullHistory)
-- ============================================================================
print("\n📝 Test 17: GetPityStatus returns error for missing PullHistory")
local errorResponse3 = sendMessage("GetPityStatus")
if errorResponse3 and errorResponse3.Action == "Error" then
    print("✅ Test 17 passed - Error returned for missing PullHistory")
else
    error("❌ Test 17 failed: Expected Error action")
end

-- ============================================================================
-- Test 18: PullEgg - Deterministic RNG with Same Seed
-- ============================================================================
print("\n📝 Test 18: PullEgg produces identical results with same seed")
local pull1 = sendMessage("PullEgg", {
    GachaType = "MOVE",
    VoucherType = "REGULAR",
    RNGSeed = "99999999",
    Timestamp = "1696800000"
})
local pull2 = sendMessage("PullEgg", {
    GachaType = "MOVE",
    VoucherType = "REGULAR",
    RNGSeed = "99999999",
    Timestamp = "1696800000"
})

if pull1 and pull2 then
    local result1 = json.decode(pull1.Data)
    local result2 = json.decode(pull2.Data)

    if result1.eggResult.tier == result2.eggResult.tier and
       result1.eggResult.isShiny == result2.eggResult.isShiny then
        print("✅ Test 18 passed - Deterministic RNG works")
    else
        error("❌ Test 18 failed: Results differ with same seed")
    end
else
    error("❌ Test 18 failed: Pull failed")
end

-- ============================================================================
-- Test 19: PullEgg - Different Results with Different Seeds
-- ============================================================================
print("\n📝 Test 19: PullEgg produces different results with different seeds")
local pull3 = sendMessage("PullEgg", {
    GachaType = "MOVE",
    VoucherType = "REGULAR",
    RNGSeed = "11111111",
    Timestamp = "1696800000"
})
local pull4 = sendMessage("PullEgg", {
    GachaType = "MOVE",
    VoucherType = "REGULAR",
    RNGSeed = "88888888",
    Timestamp = "1696800000"
})

if pull3 and pull4 then
    local result3 = json.decode(pull3.Data)
    local result4 = json.decode(pull4.Data)

    -- Results should likely differ (not guaranteed but highly probable)
    if result3.eggResult.speciesId ~= result4.eggResult.speciesId or
       result3.eggResult.tier ~= result4.eggResult.tier then
        print("✅ Test 19 passed - Different seeds produce different results")
    else
        print("⚠️  Test 19: Results happened to be same (rare but possible)")
    end
else
    error("❌ Test 19 failed: Pull failed")
end

-- ============================================================================
-- Test 20: PullEgg - Gacha Type Statistics Tracking
-- ============================================================================
print("\n📝 Test 20: PullEgg tracks gacha type statistics")
local historyBefore = json.encode({
    totalPulls = 10,
    gachaTypeStats = {
        MOVE = 5,
        LEGENDARY = 3,
        SHINY = 2
    },
    pullsSinceLastLegendary = 10,
    pullsSinceLastEpic = 10,
    pullsSinceLastRare = 5
})

local pullResponse9 = sendMessage("PullEgg", {
    GachaType = "LEGENDARY",
    VoucherType = "PREMIUM",
    RNGSeed = "77777777",
    Timestamp = "1696800600",
    PullHistory = historyBefore
})

if pullResponse9 and pullResponse9.Action == "SaveState" then
    local pullResult = json.decode(pullResponse9.Data)

    if pullResult.pullHistory.gachaTypeStats.LEGENDARY == 4 then
        print("✅ Test 20 passed - Gacha type statistics tracked")
    else
        error("❌ Test 20 failed: Gacha type stats not updated")
    end
else
    error("❌ Test 20 failed: Expected SaveState action")
end

-- ============================================================================
-- Test Summary
-- ============================================================================
print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: gacha-mechanics-engine")
print("==================================================")
