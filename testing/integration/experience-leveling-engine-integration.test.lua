-- Integration tests for Experience and Leveling Engine Process
-- Tests complete battle experience flow and complex scenarios

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
local function runHandler(handlerName, msg)
    lastMessage = nil
    handlers[handlerName](msg)
    return lastMessage
end

-- Integration Test Suite
local tests = {}
local testsPassed = 0
local testsFailed = 0

-- Test complete battle experience flow
function tests.testCompleteBattleExperienceFlow()
    print("Testing complete battle experience flow...")

    -- Step 1: Calculate experience from defeating a Pokemon
    local msg = {
        From = "test_sender",
        Action = "CalculateExperience",
        DefeatedPokemon = {
            baseExperience = 150,
            level = 45
        },
        VictorPokemon = {
            level = 38
        },
        BattleType = "TRAINER",
        Modifiers = {
            hasLuckyEgg = true
        },
        ParticipatingPokemon = {"pokemon_1"},
        AllPartyPokemon = {
            {id = "pokemon_1", hp = 100},
            {id = "pokemon_2", hp = 100},
            {id = "pokemon_3", hp = 0},  -- Fainted
            {id = "pokemon_4", hp = 100}
        },
        Timestamp = "1234567890"
    }

    local response = runHandler("calculate-experience", msg)
    assert(response.Success == "true", "Experience calculation should succeed")
    local expResult = response.Data.experienceResult

    -- Verify trainer battle and Lucky Egg bonuses are applied
    local expectedBaseMultiplier = 1.5 * 1.5  -- Trainer battle * Lucky Egg
    assert(expResult.modifiedExperience > expResult.baseExperience, "Modifiers should increase experience")

    -- Step 2: Apply experience to the Pokemon and check for level up
    msg = {
        From = "test_sender",
        Action = "ApplyExperience",
        PokemonId = "pokemon_1",
        ExperienceGained = tostring(expResult.modifiedExperience),
        CurrentExp = "85000",
        CurrentLevel = "38",
        GrowthRate = "MEDIUM_FAST",
        Pokemon = {
            id = "pokemon_1",
            level = 38,
            exp = 85000,
            ivs = {hp = 20, attack = 25, defense = 15, spatk = 30, spdef = 20, speed = 25},
            evs = {hp = 0, attack = 0, defense = 0, spatk = 0, spdef = 0, speed = 0},
            natureMod = {attack = 1.1, defense = 0.9, spatk = 1.0, spdef = 1.0, speed = 1.0}
        },
        SpeciesBaseStats = {
            hp = 78,
            attack = 84,
            defense = 78,
            spatk = 109,
            spdef = 85,
            speed = 100
        },
        Timestamp = "1234567890"
    }

    response = runHandler("apply-experience", msg)
    assert(response.Success == "true", "Experience application should succeed")
    local levelResult = response.Data.experienceResult

    -- Check that Pokemon likely leveled up (high experience gain)
    if levelResult.leveledUp then
        print("  ✓ Pokemon leveled up from " .. levelResult.oldLevel .. " to " .. levelResult.newLevel)
        assert(levelResult.newLevel > levelResult.oldLevel, "New level should be higher")
        assert(levelResult.newExp > 85000, "Experience should increase")
    end

    print("✓ Complete battle experience flow test passed")
end

-- Test party-wide EXP Share distribution
function tests.testPartyExpShareDistribution()
    print("Testing party-wide EXP Share distribution...")

    local totalExp = 3000
    local allPartyPokemon = {
        {id = "p1", hp = 120},
        {id = "p2", hp = 85},
        {id = "p3", hp = 0},    -- Fainted
        {id = "p4", hp = 200},
        {id = "p5", hp = 150},
        {id = "p6", hp = 90}
    }

    -- Test with EXP Share enabled
    local msg = {
        From = "test_sender",
        Action = "DistributeExperience",
        TotalExp = tostring(totalExp),
        ParticipatingPokemon = {"p1", "p2"},  -- Only 2 participated
        AllPartyPokemon = allPartyPokemon,
        HasExpShare = "true",
        Timestamp = "1234567890"
    }

    local response = runHandler("distribute-experience", msg)
    assert(response.Success == "true", "Distribution should succeed")
    local result = response.Data.distributionResult

    -- With EXP Share, all non-fainted Pokemon should get full exp
    assert(result.distribution[1] == totalExp, "Participating Pokemon 1 should get full exp")
    assert(result.distribution[2] == totalExp, "Participating Pokemon 2 should get full exp")
    assert(result.distribution[3] == 0, "Fainted Pokemon should get 0 exp")
    assert(result.distribution[4] == totalExp, "Non-participating Pokemon should get full exp with EXP Share")
    assert(result.distribution[5] == totalExp, "Non-participating Pokemon should get full exp with EXP Share")
    assert(result.distribution[6] == totalExp, "Non-participating Pokemon should get full exp with EXP Share")

    -- Test without EXP Share
    msg.HasExpShare = "false"
    response = runHandler("distribute-experience", msg)
    result = response.Data.distributionResult

    -- Without EXP Share, only participants should get exp (split)
    local expectedExpPerParticipant = math.floor(totalExp / 2)  -- 2 participants
    assert(result.distribution[1] == expectedExpPerParticipant, "Participant 1 should get split exp")
    assert(result.distribution[2] == expectedExpPerParticipant, "Participant 2 should get split exp")
    assert(result.distribution[3] == 0, "Fainted Pokemon should get 0 exp")
    assert(result.distribution[4] == 0, "Non-participant should get 0 exp without EXP Share")

    print("✓ Party-wide EXP Share distribution test passed")
end

-- Test multiple level-ups in single battle (rare candy scenario)
function tests.testMultipleLevelUps()
    print("Testing multiple level-ups in single battle...")

    local msg = {
        From = "test_sender",
        Action = "ApplyExperience",
        PokemonId = "test_pokemon",
        ExperienceGained = "75000",  -- Large experience gain
        CurrentExp = "100000",
        CurrentLevel = "46",
        GrowthRate = "MEDIUM_FAST",
        Timestamp = "1234567890"
    }

    local response = runHandler("apply-experience", msg)
    assert(response.Success == "true", "Large experience gain should succeed")
    local result = response.Data.experienceResult

    assert(result.leveledUp == true, "Pokemon should level up")
    assert(result.levelsGained > 1, "Pokemon should gain multiple levels")
    assert(result.newLevel > 46, "Pokemon should reach higher level")

    -- Verify experience calculations
    assert(result.newExp == result.oldExp + result.experienceGained, "Experience should be calculated correctly")

    print("  ✓ Pokemon gained " .. result.levelsGained .. " levels")
    print("✓ Multiple level-ups test passed")
end

-- Test complex modifier stacking
function tests.testComplexModifierStacking()
    print("Testing complex modifier stacking...")

    local msg = {
        From = "test_sender",
        Action = "CalculateExperience",
        DefeatedPokemon = {
            baseExperience = 100,
            level = 50
        },
        VictorPokemon = {
            level = 45
        },
        BattleType = "TRAINER",
        Modifiers = {
            hasLuckyEgg = true,
            isTraded = true,
            isDifferentLanguage = true,
            hasAffectionBonus = true,
            expPowerLevel = 2
        },
        Timestamp = "1234567890"
    }

    local response = runHandler("calculate-experience", msg)
    assert(response.Success == "true", "Complex modifier calculation should succeed")
    local result = response.Data.experienceResult

    -- With all these bonuses, experience should be significantly higher than base
    local minimumExpected = result.baseExperience * 2  -- Conservative estimate
    assert(result.modifiedExperience > minimumExpected, "Complex modifiers should significantly boost experience")

    -- Test individual modifier effects by comparison
    msg.Modifiers = nil
    local baseResponse = runHandler("calculate-experience", msg)
    local baseResult = baseResponse.Data.experienceResult

    assert(result.modifiedExperience > baseResult.modifiedExperience, "Modifiers should increase over base")

    print("  ✓ Modified exp: " .. result.modifiedExperience .. " vs base: " .. baseResult.modifiedExperience)
    print("✓ Complex modifier stacking test passed")
end

-- Test level 100 cap enforcement with experience overflow
function tests.testLevel100CapEnforcement()
    print("Testing level 100 cap enforcement...")

    local msg = {
        From = "test_sender",
        Action = "ApplyExperience",
        PokemonId = "max_level_pokemon",
        ExperienceGained = "50000",
        CurrentExp = "999000",
        CurrentLevel = "100",
        GrowthRate = "MEDIUM_FAST",
        Timestamp = "1234567890"
    }

    local response = runHandler("apply-experience", msg)
    assert(response.Success == "true", "Level 100 experience should succeed")
    local result = response.Data.experienceResult

    assert(result.newLevel == 100, "Pokemon should remain at level 100")
    assert(result.leveledUp == false, "Pokemon should not level up from max level")
    assert(result.newExp == 1000000, "Experience should cap at maximum for growth rate")
    assert(result.expToNextLevel == 0, "Should have 0 exp to next level at cap")

    print("✓ Level 100 cap enforcement test passed")
end

-- Test stat recalculation accuracy across level range
function tests.testStatRecalculationAccuracy()
    print("Testing stat recalculation accuracy...")

    local pokemon = {
        id = "stat_test_pokemon",
        ivs = {hp = 31, attack = 31, defense = 31, spatk = 31, spdef = 31, speed = 31},  -- Perfect IVs
        evs = {hp = 252, attack = 252, defense = 4, spatk = 0, spdef = 0, speed = 0},   -- EV trained
        natureMod = {attack = 1.1, defense = 0.9, spatk = 1.0, spdef = 1.0, speed = 1.0}  -- Adamant nature
    }

    local speciesBaseStats = {
        hp = 108,
        attack = 130,
        defense = 95,
        spatk = 80,
        spdef = 85,
        speed = 102
    }

    -- Test level 50 to 51
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
    assert(response.Success == "true", "Stat calculation should succeed")
    local result = response.Data.levelUpResult

    -- All stats should increase or stay the same
    assert(result.statIncreases.hp >= 2, "HP should increase by at least 2 (high base + EVs)")
    assert(result.statIncreases.attack >= 2, "Attack should increase by at least 2 (high base + EVs + nature)")
    assert(result.statIncreases.defense >= 0, "Defense should increase or stay same")

    -- Attack should be highest due to base stat, EVs, and nature
    assert(result.newStats.attack > result.newStats.spatk, "Attack should be higher than Special Attack")
    assert(result.newStats.attack > result.newStats.defense, "Attack should be higher than Defense (nature bonus)")

    -- HP should be very high due to base stat and EVs
    assert(result.newStats.hp > 200, "HP should be over 200 with perfect IVs and EVs")

    print("  ✓ Level 51 stats - HP: " .. result.newStats.hp .. ", Atk: " .. result.newStats.attack .. ", Def: " .. result.newStats.defense)
    print("✓ Stat recalculation accuracy test passed")
end

-- Test edge cases and error handling
function tests.testEdgeCasesAndErrorHandling()
    print("Testing edge cases and error handling...")

    -- Test missing required parameters
    local msg = {
        From = "test_sender",
        Action = "CalculateExperience",
        -- Missing DefeatedPokemon and VictorPokemon
        Timestamp = "1234567890"
    }

    local response = runHandler("calculate-experience", msg)
    assert(response.Success == "false", "Missing parameters should cause failure")
    assert(response.Error, "Error message should be provided")

    -- Test invalid growth rate
    msg = {
        From = "test_sender",
        Action = "GetLevelThreshold",
        Level = "50",
        GrowthRate = "INVALID_RATE",
        Timestamp = "1234567890"
    }

    response = runHandler("get-level-threshold", msg)
    assert(response.Success == "true", "Invalid growth rate should default to MEDIUM_FAST")

    -- Test invalid level bounds
    msg = {
        From = "test_sender",
        Action = "GetLevelThreshold",
        Level = "101",
        GrowthRate = "MEDIUM_FAST",
        Timestamp = "1234567890"
    }

    response = runHandler("get-level-threshold", msg)
    assert(response.Success == "false", "Level > 100 should be rejected")

    print("✓ Edge cases and error handling test passed")
end

-- Test ADP compliance
function tests.testADPCompliance()
    print("Testing ADP compliance...")

    local msg = {
        From = "test_sender",
        Action = "Info",
        Timestamp = "1234567890"
    }

    local response = runHandler("info", msg)
    assert(response.Success == "true", "Info handler should succeed")
    local processInfo = response.Data.process

    assert(processInfo.name == "Experience and Leveling Engine", "Process name should be correct")
    assert(processInfo.adpVersion == "1.0", "ADP version should be 1.0")
    assert(type(processInfo.capabilities) == "table", "Capabilities should be a table")
    assert(type(processInfo.messageSchemas) == "table", "Message schemas should be defined")

    -- Check required capabilities
    local hasCalculateExperience = false
    local hasApplyExperience = false
    for _, capability in ipairs(processInfo.capabilities) do
        if capability == "CalculateExperience" then hasCalculateExperience = true end
        if capability == "ApplyExperience" then hasApplyExperience = true end
    end
    assert(hasCalculateExperience, "Should have CalculateExperience capability")
    assert(hasApplyExperience, "Should have ApplyExperience capability")

    print("✓ ADP compliance test passed")
end

-- Run all integration tests
print("\n=== Running Experience and Leveling Engine Integration Tests ===\n")

for name, test in pairs(tests) do
    local success, err = pcall(test)
    if success then
        testsPassed = testsPassed + 1
    else
        testsFailed = testsFailed + 1
        print("✗ " .. name .. " failed: " .. err)
    end
end

print("\n=== Integration Test Results ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed == 0 then
    print("\n✓ All integration tests passed!")
    os.exit(0)
else
    print("\n✗ Some integration tests failed")
    os.exit(1)
end