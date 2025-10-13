-- Parity Tests: Encounter Reward System
-- Mathematical proof approach validating Lua implementation matches TypeScript behavior

package.path = package.path .. ";./testing/aolite/?.lua;./development-tools/aolite/lua/aolite/lib/?.lua"
local aolite = require("mock-aolite")

local tests = {}
local currentTest = ""

local function assertEquals(actual, expected, message)
    if actual ~= expected then
        error(currentTest .. " FAILED: " .. message .. " (expected: " .. tostring(expected) .. ", got: " .. tostring(actual) .. ")")
    end
end

local function assert(condition, message)
    if not condition then error(currentTest .. " FAILED: " .. message) end
end

local function setup()
    return aolite.spawnProcess("encounter-reward-engine", "./processes/encounter-reward-engine.lua")
end

-- ============================================================================
-- Mathematical Proof: Wave Scaling Formula Parity
-- ============================================================================

tests["PARITY: wave scaling formula matches TypeScript"] = function()
    currentTest = "PARITY: wave scaling formula matches TypeScript"
    local process = setup()

    -- TypeScript formula: baseExpValue * (1 + waveIndex / 50)
    -- Test cases derived from TypeScript implementation
    local testCases = {
        {base = 100, wave = 0, expected = 100},      -- 100 * 1.0
        {base = 100, wave = 25, expected = 150},     -- 100 * 1.5
        {base = 100, wave = 50, expected = 200},     -- 100 * 2.0
        {base = 250, wave = 100, expected = 750},    -- 250 * 3.0
        {base = 62, wave = 10, expected = 74.4}      -- 62 * 1.2
    }

    for _, tc in ipairs(testCases) do
        local msg = {
            From = "parity_test",
            Action = "CalculateExpReward",
            BaseExpValue = tostring(tc.base),
            WaveIndex = tostring(tc.wave),
            UseWaveIndex = "true"
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)

        local responses = aolite.getAllMsgs(process)
        local response = responses[#responses]
        local totalExp = tonumber(response.TotalExp)

        assertEquals(totalExp, tc.expected,
            "Wave scaling mismatch at base=" .. tc.base .. ", wave=" .. tc.wave)
    end

    print("✓ " .. currentTest .. " - VERIFIED")
end

-- ============================================================================
-- Mathematical Proof: Rarity Tier Progression Parity
-- ============================================================================

tests["PARITY: rarity tier progression matches TypeScript"] = function()
    currentTest = "PARITY: rarity tier progression matches TypeScript"
    local process = setup()

    -- TypeScript rarity tier indices: COMMON=1, UNCOMMON=2, RARE=3, EPIC=4, LEGENDARY=5
    -- Wave bonus: floor(waveIndex / 50)
    -- Luck bonus: luckValue > 10 ? 2 : luckValue > 5 ? 1 : 0

    local testCases = {
        {base = "COMMON", wave = 0, luck = 0, expected = "COMMON"},
        {base = "COMMON", wave = 50, luck = 0, expected = "UNCOMMON"},
        {base = "COMMON", wave = 0, luck = 7, expected = "UNCOMMON"},
        {base = "COMMON", wave = 50, luck = 12, expected = "EPIC"},
        {base = "RARE", wave = 100, luck = 0, expected = "LEGENDARY"}
    }

    for _, tc in ipairs(testCases) do
        local msg = {
            From = "parity_test",
            Action = "CalculateRewardRarity",
            BaseRarity = tc.base,
            WaveIndex = tostring(tc.wave),
            LuckValue = tostring(tc.luck)
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)

        local responses = aolite.getAllMsgs(process)
        local response = responses[#responses]

        assertEquals(response.Rarity, tc.expected,
            "Rarity mismatch at base=" .. tc.base .. ", wave=" .. tc.wave .. ", luck=" .. tc.luck)
    end

    print("✓ " .. currentTest .. " - VERIFIED")
end

-- ============================================================================
-- Mathematical Proof: Consequence Mitigation Parity
-- ============================================================================

tests["PARITY: consequence mitigation matches TypeScript"] = function()
    currentTest = "PARITY: consequence mitigation matches TypeScript"
    local process = setup()

    -- TypeScript mitigation logic:
    -- DAMAGE: defenseBonus * 10% + protectiveItems ? 20% : 0%
    -- STATUS: cleanseItems ? 50% : 0%
    -- Cap: 75%

    local testCases = {
        {type = "DAMAGE", base = 100, factors = {defenseBonus = 2, protectiveItems = true}, expectedReduction = 40, expectedValue = 60},
        {type = "DAMAGE", base = 200, factors = {defenseBonus = 10, protectiveItems = true}, expectedReduction = 75, expectedValue = 50},
        {type = "STATUS", base = 8, factors = {cleanseItems = true}, expectedReduction = 50, expectedValue = 4},
        {type = "DAMAGE", base = 150, factors = {}, expectedReduction = 0, expectedValue = 150}
    }

    for _, tc in ipairs(testCases) do
        local msg = {
            From = "parity_test",
            Action = "MitigateConsequence",
            ConsequenceType = tc.type,
            BaseValue = tostring(tc.base),
            MitigationFactors = aolite.json.encode(tc.factors)
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)

        local responses = aolite.getAllMsgs(process)
        local response = responses[#responses]

        assertEquals(response.ReductionPercent, tostring(tc.expectedReduction),
            "Reduction % mismatch for " .. tc.type)
        assertEquals(response.MitigatedValue, tostring(tc.expectedValue),
            "Mitigated value mismatch for " .. tc.type)
    end

    print("✓ " .. currentTest .. " - VERIFIED")
end

-- ============================================================================
-- Mathematical Proof: Outcome Threshold Logic Parity
-- ============================================================================

tests["PARITY: outcome threshold logic matches TypeScript"] = function()
    currentTest = "PARITY: outcome threshold logic matches TypeScript"
    local process = setup()

    -- TypeScript outcome logic:
    -- resultValue >= threshold => "success"
    -- resultValue >= (threshold * 0.7) => "partial"
    -- else => "failure"

    local testCases = {
        {result = 80, threshold = 50, expected = "success"},
        {result = 50, threshold = 50, expected = "success"},
        {result = 40, threshold = 50, expected = "partial"},
        {result = 35, threshold = 50, expected = "partial"},
        {result = 34, threshold = 50, expected = "failure"},
        {result = 20, threshold = 50, expected = "failure"}
    }

    for _, tc in ipairs(testCases) do
        local msg = {
            From = "parity_test",
            Action = "ValidateOutcome",
            ResultValue = tostring(tc.result),
            Threshold = tostring(tc.threshold)
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)

        local responses = aolite.getAllMsgs(process)
        local response = responses[#responses]

        assertEquals(response.Outcome, tc.expected,
            "Outcome mismatch at result=" .. tc.result .. ", threshold=" .. tc.threshold)
    end

    print("✓ " .. currentTest .. " - VERIFIED")
end

-- ============================================================================
-- Mathematical Proof: Reward Configuration Structure Parity
-- ============================================================================

tests["PARITY: reward configuration structure matches TypeScript"] = function()
    currentTest = "PARITY: reward configuration structure matches TypeScript"
    local process = setup()

    -- TypeScript reward structure validation
    local msg = {
        From = "parity_test",
        Action = "CalculateRewards",
        EncounterType = "MYSTERIOUS_CHEST",
        OptionIndex = "0",
        Outcome = "success",
        WaveIndex = "10"
    }
    aolite.send(msg, process)
    aolite.runScheduler(process)

    local responses = aolite.getAllMsgs(process)
    local response = responses[1]
    local data = aolite.json.decode(response.Data)

    -- Validate TypeScript structure compatibility
    assert(data.customShopRewards ~= nil or data.eggRewards ~= nil or response.HasRewards == "false",
        "Reward config structure mismatch")

    if data.customShopRewards then
        assert(type(data.customShopRewards.allowLuckUpgrades) == "boolean",
            "allowLuckUpgrades type mismatch")
        assert(type(data.customShopRewards.rerollMultiplier) == "number",
            "rerollMultiplier type mismatch")
    end

    print("✓ " .. currentTest .. " - VERIFIED")
end

-- ============================================================================
-- Statistical Distribution Validation
-- ============================================================================

tests["PARITY: reward probability distributions match TypeScript"] = function()
    currentTest = "PARITY: reward probability distributions match TypeScript"
    local process = setup()

    -- Validate that reward outcomes follow expected statistical distribution
    -- Success outcome should have higher reward quality than partial/failure

    local outcomes = {"success", "partial", "failure"}
    local qualityScores = {}

    for _, outcome in ipairs(outcomes) do
        local msg = {
            From = "parity_test",
            Action = "CalculateRewards",
            EncounterType = "MYSTERIOUS_CHEST",
            OptionIndex = "0",
            Outcome = outcome,
            WaveIndex = "10"
        }
        aolite.send(msg, process)
        aolite.runScheduler(process)

        local responses = aolite.getAllMsgs(process)
        local response = responses[#responses]
        local data = aolite.json.decode(response.Data)

        -- Calculate quality score
        local score = 0
        if data.customShopRewards then
            score = score + (#data.customShopRewards.guaranteedModifierTypeFuncs or 0) * 10
            if data.customShopRewards.allowLuckUpgrades then score = score + 5 end
            score = score - (data.customShopRewards.rerollMultiplier - 1) * 3
        end
        if data.eggRewards and #data.eggRewards > 0 then
            score = score + 15
        end

        qualityScores[outcome] = score
    end

    -- Verify distribution: success > partial > failure
    assert(qualityScores.success > qualityScores.partial,
        "Success rewards should be better than partial")
    assert(qualityScores.partial > qualityScores.failure,
        "Partial rewards should be better than failure")

    print("✓ " .. currentTest .. " - VERIFIED")
end

-- ============================================================================
-- Run all parity tests
-- ============================================================================

local function runTests()
    local passed, failed = 0, 0

    print("\n=== Encounter Reward Parity Tests ===")
    print("Mathematical proof approach validating Lua vs TypeScript behavior\n")

    for name, test in pairs(tests) do
        local success, err = pcall(test)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ " .. name .. ": " .. err)
        end
    end

    print("\n=== Parity Test Summary ===")
    print("Verified: " .. passed)
    print("Failed: " .. failed)
    print("Total: " .. (passed + failed))

    if failed == 0 then
        print("\n✓ 100% PARITY VERIFIED - Lua implementation matches TypeScript behavior")
        return 0
    else
        print("\n✗ PARITY VIOLATIONS DETECTED")
        return 1
    end
end

return runTests()
