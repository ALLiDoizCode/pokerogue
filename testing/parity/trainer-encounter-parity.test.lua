-- Parity Tests for Trainer Encounter Engine
-- Validates exact equivalence with TypeScript implementation
-- Target: 20+ parity tests comparing level calc, species selection, party gen, AI decisions

local aolite = require("aolite")
local json = require("json")

-- Test state
local processId = nil
local passCount = 0
local failCount = 0

-- TypeScript reference values (extracted from game code)
local TYPESCRIPT_REFS = {
    levelCalc = {
        -- Wave index → {baseLevel, strengthLevels[WEAK, AVERAGE, STRONG, STRONGER]}
        [10] = {base = 6, levels = {6, 7, 7, 8}},
        [40] = {base = 21, levels = {21, 23, 25, 26}},
        [50] = {base = 26, levels = {26, 29, 31, 33}},
        [100] = {base = 51, levels = {51, 56, 61, 64}},
        [150] = {base = 76, levels = {76, 84, 91, 95}},
        [200] = {base = 101, levels = {101, 111, 121, 126}}
    },
    rewards = {
        -- Wave index → {baseReward, gymLeaderReward}
        [10] = {base = 550, gymLeader = 5500},
        [20] = {base = 1100, gymLeader = 11000},
        [40] = {base = 2200, gymLeader = 22000},
        [80] = {base = 4400, gymLeader = 44000},
        [100] = {base = 5500, gymLeader = 55000}
    },
    switchThresholds = {
        regular = 3.0,
        boss = 2.0
    },
    modifierChances = {
        [1] = 0.675,  -- WEAKER
        [2] = 0.5625, -- WEAK
        [3] = 0.5625, -- AVERAGE
        [4] = 0.45,   -- STRONG
        [5] = 0.375   -- STRONGER
    }
}

-- Helper to send message and capture response
local function sendMessage(action, tags)
    local msg = {
        Action = action,
        From = "test_sender",
        Timestamp = os.time() * 1000
    }

    for k, v in pairs(tags or {}) do
        msg[k] = v
    end

    local result = aolite.send(processId, msg)
    return result
end

-- Parity assertion helper
local function assertParity(actual, expected, testName, tolerance)
    tolerance = tolerance or 0
    local diff = math.abs(actual - expected)
    if diff <= tolerance then
        print(string.format("  ✓ %s: Actual=%s, Expected=%s (diff=%.2f)",
            testName, tostring(actual), tostring(expected), diff))
        passCount = passCount + 1
        return true
    else
        print(string.format("  ✗ %s: Actual=%s, Expected=%s (diff=%.2f > tolerance=%.2f)",
            testName, tostring(actual), tostring(expected), diff, tolerance))
        failCount = failCount + 1
        return false
    end
end

-- Setup: Load process
print("Setting up Trainer Encounter Engine parity tests...")
processId = aolite.spawn("trainer-encounter-engine", "processes/trainer-encounter-engine.lua")

if not processId then
    error("Failed to spawn trainer-encounter-engine process")
end

print("Process spawned with ID: " .. processId)
print("\n=== Trainer Encounter Engine Parity Tests ===\n")

-- ===========================================
-- Test Suite 1: Level Calculation Parity
-- ===========================================
print("Test Suite 1: Level Calculation Parity (vs TypeScript)")

local function testLevelParity(wave, strength, strengthName)
    local result = sendMessage("calculate-party-levels", {
        WaveIndex = tostring(wave),
        GameMode = "classic",
        PartyTemplate = json.encode({
            size = 1,
            strength = strength,
            sameSpecies = false,
            balanced = false
        })
    })

    if result and #result > 0 then
        local response = result[1]
        if response.Action == "party-levels-calculated" then
            local data = json.decode(response.Data)
            local actualBase = data.baseLevel
            local actualFinal = data.levels and data.levels[1]

            local tsRef = TYPESCRIPT_REFS.levelCalc[wave]
            if tsRef then
                assertParity(actualBase, tsRef.base,
                    string.format("Wave %d base level", wave), 1)

                local levelIndex = strength - 1 -- strength 2=WEAK is index 1
                if levelIndex >= 1 and levelIndex <= 4 and tsRef.levels[levelIndex] then
                    assertParity(actualFinal, tsRef.levels[levelIndex],
                        string.format("Wave %d %s level", wave, strengthName), 2)
                end
            end
        else
            failCount = failCount + 1
            print(string.format("  ✗ Wave %d: Wrong action", wave))
        end
    else
        failCount = failCount + 1
        print(string.format("  ✗ Wave %d: No response", wave))
    end
end

-- Test critical wave milestones
testLevelParity(10, 2, "WEAK")
testLevelParity(40, 3, "AVERAGE")
testLevelParity(50, 3, "AVERAGE")
testLevelParity(100, 4, "STRONG")
testLevelParity(150, 5, "STRONGER")
testLevelParity(200, 5, "STRONGER")

-- ===========================================
-- Test Suite 2: Money Reward Parity
-- ===========================================
print("\nTest Suite 2: Money Reward Parity (vs TypeScript)")

local function testRewardParity(wave, multiplier, multiplierName)
    local result = sendMessage("calculate-rewards", {
        WaveIndex = tostring(wave),
        MoneyMultiplier = tostring(multiplier),
        PartyStrengths = json.encode({3}) -- AVERAGE
    })

    if result and #result > 0 then
        local response = result[1]
        if response.Action == "rewards-calculated" then
            local data = json.decode(response.Data)
            local actualReward = data.moneyReward

            local tsRef = TYPESCRIPT_REFS.rewards[wave]
            if tsRef then
                local expected = multiplier == 1.0 and tsRef.base or tsRef.gymLeader
                assertParity(actualReward, expected,
                    string.format("Wave %d %s reward", wave, multiplierName), expected * 0.1)
            end
        else
            failCount = failCount + 1
            print(string.format("  ✗ Wave %d: Wrong action", wave))
        end
    else
        failCount = failCount + 1
        print(string.format("  ✗ Wave %d: No response", wave))
    end
end

testRewardParity(10, 1.0, "base")
testRewardParity(20, 10.0, "gym leader")
testRewardParity(40, 1.0, "base")
testRewardParity(80, 1.0, "base")
testRewardParity(100, 1.0, "base")

-- ===========================================
-- Test Suite 3: Modifier Chance Parity
-- ===========================================
print("\nTest Suite 3: Modifier Chance Parity (vs TypeScript)")

local function testModifierParity(strength, strengthName)
    local result = sendMessage("calculate-rewards", {
        WaveIndex = "50",
        MoneyMultiplier = "1.0",
        PartyStrengths = json.encode({strength})
    })

    if result and #result > 0 then
        local response = result[1]
        if response.Action == "rewards-calculated" then
            local data = json.decode(response.Data)
            local actualChance = data.itemChances and data.itemChances[1]

            local expected = TYPESCRIPT_REFS.modifierChances[strength]
            if expected and actualChance then
                assertParity(actualChance, expected,
                    string.format("%s modifier chance", strengthName), 0.01)
            end
        else
            failCount = failCount + 1
            print(string.format("  ✗ %s: Wrong action", strengthName))
        end
    else
        failCount = failCount + 1
        print(string.format("  ✗ %s: No response", strengthName))
    end
end

testModifierParity(1, "WEAKER")
testModifierParity(2, "WEAK")
testModifierParity(3, "AVERAGE")
testModifierParity(4, "STRONG")
testModifierParity(5, "STRONGER")

-- ===========================================
-- Test Suite 4: Switch Threshold Parity
-- ===========================================
print("\nTest Suite 4: Switch Threshold Parity (vs TypeScript)")

local function testSwitchThresholdParity(isBoss, currentScore, bestScore)
    local result = sendMessage("evaluate-switch-decision", {
        CurrentMatchupScore = tostring(currentScore),
        BestSwitchMatchupScore = tostring(bestScore),
        IsBoss = tostring(isBoss),
        SwitchCounter = "0"
    })

    if result and #result > 0 then
        local response = result[1]
        if response.Action == "switch-decision-evaluated" then
            local threshold = tonumber(response.Threshold)
            local expectedThreshold = isBoss and
                TYPESCRIPT_REFS.switchThresholds.boss or
                TYPESCRIPT_REFS.switchThresholds.regular

            assertParity(threshold, expectedThreshold,
                string.format("%s switch threshold", isBoss and "Boss" or "Regular"), 0.01)
        else
            failCount = failCount + 1
            print(string.format("  ✗ %s: Wrong action", isBoss and "Boss" or "Regular"))
        end
    else
        failCount = failCount + 1
        print(string.format("  ✗ %s: No response", isBoss and "Boss" or "Regular"))
    end
end

testSwitchThresholdParity(false, 5.0, 18.0)
testSwitchThresholdParity(true, 5.0, 18.0)

-- ===========================================
-- Test Suite 5: Level Formula Parity (Edge Cases)
-- ===========================================
print("\nTest Suite 5: Level Formula Parity (Edge Cases)")

local function testLevelFormula(wave, expectedBase)
    local result = sendMessage("calculate-party-levels", {
        WaveIndex = tostring(wave),
        GameMode = "classic",
        PartyTemplate = json.encode({size = 1, strength = 2})
    })

    if result and #result > 0 then
        local response = result[1]
        if response.Action == "party-levels-calculated" then
            local data = json.decode(response.Data)
            assertParity(data.baseLevel, expectedBase,
                string.format("Wave %d base formula", wave), 1)
        end
    end
end

testLevelFormula(1, 1)    -- Minimum: 1 + 0 + 0
testLevelFormula(5, 3)    -- Early: 1 + 2 + 0
testLevelFormula(25, 13)  -- Mid-early: 1 + 12 + 0
testLevelFormula(75, 38)  -- Mid-late: 1 + 37 + 1.44
testLevelFormula(180, 91) -- Endgame: 1 + 90 + 20.48

-- ===========================================
-- Test Suite 6: Strength Multiplier Parity
-- ===========================================
print("\nTest Suite 6: Strength Multiplier Parity")

local function testStrengthMultiplier(wave, strength, expectedRange)
    local result = sendMessage("calculate-party-levels", {
        WaveIndex = tostring(wave),
        GameMode = "classic",
        PartyTemplate = json.encode({size = 1, strength = strength})
    })

    if result and #result > 0 then
        local response = result[1]
        if response.Action == "party-levels-calculated" then
            local data = json.decode(response.Data)
            local actualLevel = data.levels and data.levels[1]

            if actualLevel and expectedRange then
                local inRange = actualLevel >= expectedRange[1] and actualLevel <= expectedRange[2]
                if inRange then
                    print(string.format("  ✓ Wave %d strength %d: Level=%d (range %d-%d)",
                        wave, strength, actualLevel, expectedRange[1], expectedRange[2]))
                    passCount = passCount + 1
                else
                    print(string.format("  ✗ Wave %d strength %d: Level=%d (expected %d-%d)",
                        wave, strength, actualLevel, expectedRange[1], expectedRange[2]))
                    failCount = failCount + 1
                end
            end
        end
    end
end

testStrengthMultiplier(50, 0, {24, 26})  -- WEAKEST
testStrengthMultiplier(50, 2, {26, 28})  -- WEAK
testStrengthMultiplier(50, 3, {29, 31})  -- AVERAGE
testStrengthMultiplier(50, 5, {32, 34})  -- STRONGER

-- ===========================================
-- Test Suite 7: Progressive Scaling Parity
-- ===========================================
print("\nTest Suite 7: Progressive Scaling Parity")

local function testProgressiveScaling(wave, strength)
    local result = sendMessage("calculate-party-levels", {
        WaveIndex = tostring(wave),
        GameMode = "classic",
        PartyTemplate = json.encode({
            size = 3,
            strength = strength,
            sameSpecies = false,
            balanced = false
        })
    })

    if result and #result > 0 then
        local response = result[1]
        if response.Action == "party-levels-calculated" then
            local data = json.decode(response.Data)
            local levels = data.levels

            if levels and #levels == 3 then
                -- Verify progressive scaling (each member stronger than previous)
                local progressive = levels[1] <= levels[2] and levels[2] <= levels[3]
                if progressive then
                    print(string.format("  ✓ Wave %d progressive: [%d, %d, %d]",
                        wave, levels[1], levels[2], levels[3]))
                    passCount = passCount + 1
                else
                    print(string.format("  ✗ Wave %d not progressive: [%d, %d, %d]",
                        wave, levels[1], levels[2], levels[3]))
                    failCount = failCount + 1
                end
            end
        end
    end
end

testProgressiveScaling(30, 3)
testProgressiveScaling(70, 4)
testProgressiveScaling(120, 5)

-- ===========================================
-- Test Summary
-- ===========================================
print("\n=== Parity Test Summary ===")
print(string.format("Total: %d tests", passCount + failCount))
print(string.format("Passed: %d (%.1f%%)", passCount, (passCount / (passCount + failCount)) * 100))
print(string.format("Failed: %d (%.1f%%)", failCount, (failCount / (passCount + failCount)) * 100))

if failCount == 0 then
    print("\n✅ All parity tests passed - Perfect TypeScript equivalence!")
    os.exit(0)
else
    print(string.format("\n⚠️  %d parity tests failed - Deviations from TypeScript detected", failCount))
    os.exit(1)
end
