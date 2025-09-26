-- Unit tests for Experience and Leveling Engine Process
-- Tests all experience calculations, level thresholds, and stat recalculation

-- Mock AO environment
local lastMessage
ao = {
    send = function(msg)
        lastMessage = msg
    end,
    id = "test_process_id"
}

-- Mock Handlers
local handlers = {}
Handlers = {
    add = function(name, matcher, handler)
        handlers[name] = handler
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value
            end
        end
    }
}

-- Mock JSON
json = {
    encode = function(t) return t end,
    decode = function(s) return s end
}

-- Load the process
dofile("processes/experience-leveling-engine.lua")

-- Test helper functions
local function assertAlmostEqual(actual, expected, tolerance)
    tolerance = tolerance or 0.001
    assert(math.abs(actual - expected) < tolerance,
           string.format("Expected %f but got %f", expected, actual))
end

local function runHandler(handlerName, msg)
    lastMessage = nil
    handlers[handlerName](msg)
    return lastMessage
end

-- Test Suite
local tests = {}
local testsPassed = 0
local testsFailed = 0

-- Test growth rate formulas for known values
function tests.testGrowthRateFormulas()
    print("Testing growth rate formulas...")

    -- Test MEDIUM_FAST (most straightforward)
    local msg = {
        From = "test_sender",
        Action = "GetLevelThreshold",
        Level = "50",
        GrowthRate = "MEDIUM_FAST",
        Timestamp = "1234567890"
    }

    local response = runHandler("get-level-threshold", msg)
    assert(response.Success == "true", "Handler should succeed")
    local result = response.Data.levelThreshold
    assert(result.totalExpRequired == 125000, "Level 50 MEDIUM_FAST should require 125000 exp")

    -- Test SLOW growth rate
    msg.GrowthRate = "SLOW"
    response = runHandler("get-level-threshold", msg)
    result = response.Data.levelThreshold
    assert(result.totalExpRequired == 135156, "Level 50 SLOW should require 135156 exp")

    -- Test ERRATIC growth rate
    msg.GrowthRate = "ERRATIC"
    response = runHandler("get-level-threshold", msg)
    result = response.Data.levelThreshold
    assert(result.totalExpRequired == 125000, "Level 50 ERRATIC should require 125000 exp")

    print("✓ Growth rate formulas test passed")
end

-- Test base experience calculation
function tests.testBaseExperienceCalculation()
    print("Testing base experience calculation...")

    local msg = {
        From = "test_sender",
        Action = "CalculateExperience",
        DefeatedPokemon = {
            baseExperience = 100,
            level = 50
        },
        VictorPokemon = {
            level = 50
        },
        BattleType = "WILD",
        Timestamp = "1234567890"
    }

    local response = runHandler("calculate-experience", msg)
    assert(response.Success == "true", "Handler should succeed")
    local result = response.Data.experienceResult
    assert(result.baseExperience > 0, "Base experience should be positive")

    -- Test trainer battle bonus
    msg.BattleType = "TRAINER"
    response = runHandler("calculate-experience", msg)
    result = response.Data.experienceResult
    local trainerExp = result.modifiedExperience

    msg.BattleType = "WILD"
    response = runHandler("calculate-experience", msg)
    result = response.Data.experienceResult
    local wildExp = result.modifiedExperience

    assertAlmostEqual(trainerExp / wildExp, 1.5, 0.01)

    print("✓ Base experience calculation test passed")
end

-- Test experience modifiers
function tests.testExperienceModifiers()
    print("Testing experience modifiers...")

    local msg = {
        From = "test_sender",
        Action = "CalculateExperience",
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
        },
        Timestamp = "1234567890"
    }

    local response = runHandler("calculate-experience", msg)
    assert(response.Success == "true", "Handler should succeed")
    local resultWithLuckyEgg = response.Data.experienceResult.modifiedExperience

    -- Test without Lucky Egg
    msg.Modifiers = nil
    response = runHandler("calculate-experience", msg)
    local resultWithoutLuckyEgg = response.Data.experienceResult.modifiedExperience

    assertAlmostEqual(resultWithLuckyEgg / resultWithoutLuckyEgg, 1.5, 0.01)

    -- Test traded Pokemon bonus
    msg.Modifiers = {
        isTraded = true,
        isDifferentLanguage = false
    }
    response = runHandler("calculate-experience", msg)
    local tradedResult = response.Data.experienceResult.modifiedExperience
    assertAlmostEqual(tradedResult / resultWithoutLuckyEgg, 1.5, 0.01)

    -- Test different language traded bonus
    msg.Modifiers.isDifferentLanguage = true
    response = runHandler("calculate-experience", msg)
    local diffLangResult = response.Data.experienceResult.modifiedExperience
    assertAlmostEqual(diffLangResult / resultWithoutLuckyEgg, 1.7, 0.01)

    print("✓ Experience modifiers test passed")
end

-- Test party experience distribution
function tests.testExperienceDistribution()
    print("Testing experience distribution...")

    local allPartyPokemon = {
        {id = "p1", hp = 100},
        {id = "p2", hp = 100},
        {id = "p3", hp = 0},  -- Fainted
        {id = "p4", hp = 100},
        {id = "p5", hp = 100},
        {id = "p6", hp = 100}
    }

    local msg = {
        From = "test_sender",
        Action = "DistributeExperience",
        TotalExp = "1000",
        ParticipatingPokemon = {"p1", "p2"},
        AllPartyPokemon = allPartyPokemon,
        HasExpShare = "false",
        Timestamp = "1234567890"
    }

    local response = runHandler("distribute-experience", msg)
    assert(response.Success == "true", "Handler should succeed")
    local result = response.Data.distributionResult

    -- Check classic distribution
    assert(result.distribution[1] == 500, "Participant 1 should get 500 exp")
    assert(result.distribution[2] == 500, "Participant 2 should get 500 exp")
    assert(result.distribution[3] == 0, "Fainted Pokemon should get 0 exp")
    assert(result.distribution[4] == 0, "Non-participant should get 0 exp")

    -- Test modern EXP Share
    msg.HasExpShare = "true"
    response = runHandler("distribute-experience", msg)
    result = response.Data.distributionResult

    assert(result.distribution[1] == 1000, "All active Pokemon should get full exp with EXP Share")
    assert(result.distribution[2] == 1000, "All active Pokemon should get full exp with EXP Share")
    assert(result.distribution[3] == 0, "Fainted Pokemon should still get 0 exp")
    assert(result.distribution[4] == 1000, "Non-participants should get full exp with EXP Share")

    print("✓ Experience distribution test passed")
end

-- Test level up detection
function tests.testLevelUpDetection()
    print("Testing level up detection...")

    local msg = {
        From = "test_sender",
        Action = "ApplyExperience",
        PokemonId = "test_pokemon",
        ExperienceGained = "5000",
        CurrentExp = "122000",
        CurrentLevel = "49",
        GrowthRate = "MEDIUM_FAST",
        Timestamp = "1234567890"
    }

    local response = runHandler("apply-experience", msg)
    assert(response.Success == "true", "Handler should succeed")
    local result = response.Data.experienceResult

    assert(result.leveledUp == true, "Pokemon should level up")
    assert(result.newLevel == 50, "Pokemon should reach level 50")
    assert(result.levelsGained == 1, "Should gain 1 level")
    assert(result.newExp == 127000, "New exp should be 127000")

    -- Test multiple level ups
    msg.ExperienceGained = "50000"
    msg.CurrentExp = "100000"
    msg.CurrentLevel = "46"

    response = runHandler("apply-experience", msg)
    result = response.Data.experienceResult

    assert(result.leveledUp == true, "Pokemon should level up multiple times")
    assert(result.newLevel > 46, "Pokemon should gain multiple levels")
    assert(result.levelsGained > 1, "Should gain multiple levels")

    print("✓ Level up detection test passed")
end

-- Test level cap enforcement
function tests.testLevelCapEnforcement()
    print("Testing level cap enforcement...")

    local msg = {
        From = "test_sender",
        Action = "ApplyExperience",
        PokemonId = "test_pokemon",
        ExperienceGained = "100000",
        CurrentExp = "950000",
        CurrentLevel = "99",
        GrowthRate = "MEDIUM_FAST",
        Timestamp = "1234567890"
    }

    local response = runHandler("apply-experience", msg)
    assert(response.Success == "true", "Handler should succeed")
    local result = response.Data.experienceResult

    assert(result.newLevel == 100, "Pokemon should cap at level 100")
    assert(result.newExp == 1000000, "Experience should cap at max for growth rate")
    assert(result.expToNextLevel == 0, "Should have 0 exp to next level at cap")

    print("✓ Level cap enforcement test passed")
end

-- Test stat recalculation on level up
function tests.testStatRecalculation()
    print("Testing stat recalculation on level up...")

    local pokemon = {
        id = "test_pokemon",
        ivs = {hp = 31, attack = 31, defense = 31, spatk = 31, spdef = 31, speed = 31},
        evs = {hp = 0, attack = 0, defense = 0, spatk = 0, spdef = 0, speed = 0},
        natureMod = {attack = 1.1, defense = 0.9, spatk = 1.0, spdef = 1.0, speed = 1.0}
    }

    local speciesBaseStats = {
        hp = 100,
        attack = 100,
        defense = 100,
        spatk = 100,
        spdef = 100,
        speed = 100
    }

    local msg = {
        From = "test_sender",
        Action = "CalculateLevelUpStats",
        Pokemon = pokemon,
        OldLevel = "50",
        NewLevel = "51",
        SpeciesBaseStats = speciesBaseStats,
        Timestamp = "1234567890"
    }

    local response = runHandler("calculate-levelup-stats", msg)
    assert(response.Success == "true", "Handler should succeed")
    local result = response.Data.levelUpResult

    -- Check that stat increases are positive
    assert(result.statIncreases.hp > 0, "HP should increase")
    assert(result.statIncreases.attack >= 0, "Attack should increase or stay same")
    assert(result.statIncreases.defense >= 0, "Defense should increase or stay same")
    assert(result.statIncreases.spatk >= 0, "Special Attack should increase or stay same")
    assert(result.statIncreases.spdef >= 0, "Special Defense should increase or stay same")
    assert(result.statIncreases.speed >= 0, "Speed should increase or stay same")

    -- Check new stats are reasonable
    assert(result.newStats.hp > 150, "HP should be reasonable for level 51")
    assert(result.newStats.attack > 100, "Attack should be affected by nature")
    assert(result.newStats.defense < result.newStats.attack, "Defense should be lower due to nature")

    print("✓ Stat recalculation test passed")
end

-- Test edge cases
function tests.testEdgeCases()
    print("Testing edge cases...")

    -- Test level 1 threshold
    local msg = {
        From = "test_sender",
        Action = "GetLevelThreshold",
        Level = "1",
        GrowthRate = "MEDIUM_FAST",
        Timestamp = "1234567890"
    }

    local response = runHandler("get-level-threshold", msg)
    assert(response.Success == "true", "Should handle level 1")
    local result = response.Data.levelThreshold
    assert(result.totalExpRequired == 0, "Level 1 should require 0 exp")

    -- Test level 100 threshold
    msg.Level = "100"
    response = runHandler("get-level-threshold", msg)
    assert(response.Success == "true", "Should handle level 100")
    result = response.Data.levelThreshold
    assert(result.totalExpRequired == 1000000, "Level 100 MEDIUM_FAST should require 1000000 exp")

    -- Test invalid level
    msg.Level = "101"
    response = runHandler("get-level-threshold", msg)
    assert(response.Success == "false", "Should reject level > 100")

    msg.Level = "0"
    response = runHandler("get-level-threshold", msg)
    assert(response.Success == "false", "Should reject level < 1")

    print("✓ Edge cases test passed")
end

-- Test all growth rates match TypeScript values
function tests.testAllGrowthRatesParity()
    print("Testing all growth rates for parity...")

    local testCases = {
        {level = 10, growthRate = "MEDIUM_FAST", expected = 1000},
        {level = 25, growthRate = "MEDIUM_FAST", expected = 15625},
        {level = 50, growthRate = "MEDIUM_FAST", expected = 125000},
        {level = 75, growthRate = "MEDIUM_FAST", expected = 421875},
        {level = 100, growthRate = "MEDIUM_FAST", expected = 1000000},

        {level = 10, growthRate = "SLOW", expected = 1081},
        {level = 50, growthRate = "SLOW", expected = 135156},
        {level = 100, growthRate = "SLOW", expected = 1081250},

        {level = 10, growthRate = "FAST", expected = 935},
        {level = 50, growthRate = "FAST", expected = 116875},
        {level = 100, growthRate = "FAST", expected = 935000},

        {level = 10, growthRate = "ERRATIC", expected = 1260},
        {level = 50, growthRate = "ERRATIC", expected = 125000},
        {level = 100, growthRate = "ERRATIC", expected = 870000},

        {level = 10, growthRate = "MEDIUM_SLOW", expected = 857},
        {level = 50, growthRate = "MEDIUM_SLOW", expected = 122517},
        {level = 100, growthRate = "MEDIUM_SLOW", expected = 1019454},

        {level = 10, growthRate = "FLUCTUATING", expected = 850},
        {level = 50, growthRate = "FLUCTUATING", expected = 130687},
        {level = 100, growthRate = "FLUCTUATING", expected = 1208000}
    }

    for _, testCase in ipairs(testCases) do
        local msg = {
            From = "test_sender",
            Action = "GetLevelThreshold",
            Level = tostring(testCase.level),
            GrowthRate = testCase.growthRate,
            Timestamp = "1234567890"
        }

        local response = runHandler("get-level-threshold", msg)
        assert(response.Success == "true", "Handler should succeed for " .. testCase.growthRate)
        local result = response.Data.levelThreshold

        assert(result.totalExpRequired == testCase.expected,
               string.format("Level %d %s should require %d exp, got %d",
                           testCase.level, testCase.growthRate, testCase.expected, result.totalExpRequired))
    end

    print("✓ All growth rates parity test passed")
end

-- Run all tests
print("\n=== Running Experience and Leveling Engine Unit Tests ===\n")

for name, test in pairs(tests) do
    local success, err = pcall(test)
    if success then
        testsPassed = testsPassed + 1
    else
        testsFailed = testsFailed + 1
        print("✗ " .. name .. " failed: " .. err)
    end
end

print("\n=== Test Results ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed == 0 then
    print("\n✓ All tests passed!")
    os.exit(0)
else
    print("\n✗ Some tests failed")
    os.exit(1)
end