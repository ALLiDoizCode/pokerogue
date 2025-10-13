-- Unit tests for Experience and Leveling Engine Process
-- Tests all experience calculations, level thresholds, and stat recalculation

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.experience-leveling-engine"
local processId = "test-experience-leveling-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Experience and Leveling Engine")
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

local testsPassed = 0
local testsFailed = 0

-- Test 1: Growth Rate Formulas
print("📝 Test 1: Growth Rate Formulas")
local levelThreshold = sendMessage("GetLevelThreshold", {
    Level = "50",
    GrowthRate = "MEDIUM_FAST"
})
if levelThreshold and levelThreshold.Action == "SaveState" then
    local thresholdData = json.decode(levelThreshold.Data or "{}")
    if thresholdData.levelThreshold and thresholdData.levelThreshold.totalExpRequired == 125000 then
        print("✅ Test passed: MEDIUM_FAST growth rate correct")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Growth rate calculation incorrect")
    end
else
    error("❌ Test failed: GetLevelThreshold handler failed")
end

-- Test 2: Base Experience Calculation
print("📝 Test 2: Base Experience Calculation")
local expCalc = sendMessage("CalculateExperience", nil, json.encode({
    DefeatedPokemon = {
        baseExperience = 100,
        level = 50
    },
    VictorPokemon = {
        level = 50
    },
    BattleType = "WILD"
}))
if expCalc and expCalc.Action == "SaveState" then
    local expData = json.decode(expCalc.Data or "{}")
    if expData.experienceResult and expData.experienceResult.baseExperience > 0 then
        print("✅ Test passed: Base experience calculation works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Experience calculation incorrect")
    end
else
    error("❌ Test failed: CalculateExperience handler failed")
end

-- Test 3: Experience Modifiers (Lucky Egg)
print("📝 Test 3: Experience Modifiers")
local modifierCalc = sendMessage("CalculateExperience", nil, json.encode({
    DefeatedPokemon = {
        baseExperience = 100,
        level = 50
    },
    VictorPokemon = {
        level = 50
    },
    BattleType = "WILD",
    Modifiers = {
        hasLuckyEgg = true
    }
}))
if modifierCalc and modifierCalc.Action == "SaveState" then
    local modData = json.decode(modifierCalc.Data or "{}")
    if modData.experienceResult and modData.experienceResult.modifiedExperience then
        print("✅ Test passed: Experience modifiers work")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Modifiers incorrect")
    end
else
    error("❌ Test failed: Experience modifiers test failed")
end

-- Test 4: Experience Distribution
print("📝 Test 4: Experience Distribution")
local distResult = sendMessage("DistributeExperience", {
    TotalExp = "1000",
    ParticipatingPokemon = json.encode({"p1", "p2"}),
    AllPartyPokemon = json.encode({
        {id = "p1", hp = 100},
        {id = "p2", hp = 100},
        {id = "p3", hp = 0}
    }),
    HasExpShare = "false"
})
if distResult and distResult.Action == "SaveState" then
    local distData = json.decode(distResult.Data or "{}")
    if distData.distributionResult and distData.distributionResult.distribution then
        print("✅ Test passed: Experience distribution works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Distribution incorrect")
    end
else
    error("❌ Test failed: DistributeExperience handler failed")
end

-- Test 5: Level Up Detection
print("📝 Test 5: Level Up Detection")
local levelUpResult = sendMessage("ApplyExperience", {
    PokemonId = "test_pokemon",
    ExperienceGained = "5000",
    CurrentExp = "122000",
    CurrentLevel = "49",
    GrowthRate = "MEDIUM_FAST"
})
if levelUpResult and levelUpResult.Action == "SaveState" then
    local levelUpData = json.decode(levelUpResult.Data or "{}")
    if levelUpData.experienceResult and levelUpData.experienceResult.leveledUp == true then
        print("✅ Test passed: Level up detection works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Level up detection incorrect")
    end
else
    error("❌ Test failed: ApplyExperience handler failed")
end

-- Test 6: Level Cap Enforcement
print("📝 Test 6: Level Cap Enforcement")
local capResult = sendMessage("ApplyExperience", {
    PokemonId = "test_pokemon",
    ExperienceGained = "100000",
    CurrentExp = "950000",
    CurrentLevel = "99",
    GrowthRate = "MEDIUM_FAST"
})
if capResult and capResult.Action == "SaveState" then
    local capData = json.decode(capResult.Data or "{}")
    if capData.experienceResult and capData.experienceResult.newLevel == 100 then
        print("✅ Test passed: Level cap enforcement works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Level cap incorrect")
    end
else
    error("❌ Test failed: Level cap test failed")
end

-- Test 7: Stat Recalculation
print("📝 Test 7: Stat Recalculation")
local statResult = sendMessage("CalculateLevelUpStats", nil, json.encode({
    Pokemon = {
        id = "test_pokemon",
        ivs = {hp = 31, attack = 31, defense = 31, spatk = 31, spdef = 31, speed = 31},
        evs = {hp = 0, attack = 0, defense = 0, spatk = 0, spdef = 0, speed = 0},
        natureMod = {attack = 1.1, defense = 0.9, spatk = 1.0, spdef = 1.0, speed = 1.0}
    },
    OldLevel = "50",
    NewLevel = "51",
    SpeciesBaseStats = {
        hp = 100,
        attack = 100,
        defense = 100,
        spatk = 100,
        spdef = 100,
        speed = 100
    }
}))
if statResult and statResult.Action == "SaveState" then
    local statData = json.decode(statResult.Data or "{}")
    if statData.levelUpResult and statData.levelUpResult.statIncreases then
        print("✅ Test passed: Stat recalculation works")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Stat recalculation incorrect")
    end
else
    error("❌ Test failed: CalculateLevelUpStats handler failed")
end

-- Test 8: Edge Cases - Level 1
print("📝 Test 8: Edge Cases - Level 1")
local level1Result = sendMessage("GetLevelThreshold", {
    Level = "1",
    GrowthRate = "MEDIUM_FAST"
})
if level1Result and level1Result.Action == "SaveState" then
    local level1Data = json.decode(level1Result.Data or "{}")
    if level1Data.levelThreshold and level1Data.levelThreshold.totalExpRequired == 0 then
        print("✅ Test passed: Level 1 edge case handled")
        testsPassed = testsPassed + 1
    else
        error("❌ Test failed: Level 1 edge case incorrect")
    end
else
    error("❌ Test failed: Level 1 test failed")
end

-- Test 9: Error Handling
print("📝 Test 9: Error Handling")
local errorResult = sendMessage("GetLevelThreshold", {
    Level = "101",
    GrowthRate = "MEDIUM_FAST"
})
if errorResult and errorResult.Action == "Error" then
    print("✅ Test passed: Error handling works")
    testsPassed = testsPassed + 1
else
    error("❌ Test failed: Error handling not working")
end

print("==================================================")
print("Test Results:")
print("  Passed: " .. testsPassed)
print("  Failed: " .. testsFailed)
print("  Total:  " .. (testsPassed + testsFailed))

if testsFailed == 0 then
    print("\n🎉 All tests passed!")
    print("✅ Test file executed successfully: " .. PROCESS_PATH)
else
    error("\n❌ Some tests failed!")
end
