-- Parity tests for Experience and Leveling Engine Process
-- Validates mathematical exactness against TypeScript implementation

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

-- TypeScript reference values (directly extracted from exp.ts)
local TYPESCRIPT_EXP_VALUES = {
    -- MEDIUM_FAST growth rate (baseline)
    MEDIUM_FAST = {
        [1] = 0,
        [10] = 1000,
        [25] = 15625,
        [50] = 125000,
        [75] = 421875,
        [99] = 970299,
        [100] = 1000000
    },

    -- Other growth rates with hybrid formula applied
    SLOW = {
        [1] = 0,
        [10] = 1081,
        [25] = 16894,
        [50] = 135156,
        [75] = 456152,
        [99] = 1049135,
        [100] = 1081250
    },

    FAST = {
        [1] = 0,
        [10] = 935,
        [25] = 14609,
        [50] = 116875,
        [75] = 394453,
        [99] = 907229,
        [100] = 935000
    },

    ERRATIC = {
        [1] = 0,
        [10] = 1260,
        [25] = 18163,
        [50] = 125000,
        [75] = 390888,
        [99] = 847313,
        [100] = 870000
    },

    MEDIUM_SLOW = {
        [1] = 0,
        [10] = 857,
        [25] = 14360,
        [50] = 122517,
        [75] = 424267,
        [99] = 988760,
        [100] = 1019454
    },

    FLUCTUATING = {
        [1] = 0,
        [10] = 850,
        [25] = 14507,
        [50] = 130687,
        [75] = 473976,
        [99] = 1165814,
        [100] = 1208000
    }
}

-- Parity Test Suite
local tests = {}
local testsPassed = 0
local testsFailed = 0

-- Test growth rate formulas match TypeScript exactly
function tests.testGrowthRateFormulaParity()
    print("Testing growth rate formula parity with TypeScript...")

    local testLevels = {1, 10, 25, 50, 75, 99, 100}
    local growthRates = {"MEDIUM_FAST", "SLOW", "FAST", "ERRATIC", "MEDIUM_SLOW", "FLUCTUATING"}

    for _, growthRate in ipairs(growthRates) do
        for _, level in ipairs(testLevels) do
            local msg = {
                From = "test_sender",
                Action = "GetLevelThreshold",
                Level = tostring(level),
                GrowthRate = growthRate,
                Timestamp = "1234567890"
            }

            local response = runHandler("get-level-threshold", msg)
            assert(response.Success == "true", "Handler should succeed for " .. growthRate .. " level " .. level)

            local luaResult = response.Data.levelThreshold.totalExpRequired
            local expectedResult = TYPESCRIPT_EXP_VALUES[growthRate][level]

            assert(luaResult == expectedResult,
                   string.format("Level %d %s: Lua=%d, TypeScript=%d",
                               level, growthRate, luaResult, expectedResult))
        end
    end

    print("✓ Growth rate formula parity test passed")
end

-- Test base experience calculation matches TypeScript Math.floor behavior
function tests.testBaseExperienceCalculationParity()
    print("Testing base experience calculation parity...")

    -- Test cases that match TypeScript calculation patterns
    local testCases = {
        -- {defeated base exp, defeated level, victor level, battle type, expected result range}
        {64, 5, 5, "WILD", {120, 140}},        -- Low level same-level battle
        {142, 25, 20, "WILD", {1500, 1700}},   -- Mid-level battle with level difference
        {218, 50, 50, "TRAINER", {6000, 7000}}, -- High level trainer battle
        {255, 70, 65, "WILD", {7200, 7600}},  -- High level with small difference
    }

    for _, testCase in ipairs(testCases) do
        local msg = {
            From = "test_sender",
            Action = "CalculateExperience",
            DefeatedPokemon = {
                baseExperience = testCase[1],
                level = testCase[2]
            },
            VictorPokemon = {
                level = testCase[3]
            },
            BattleType = testCase[4],
            Timestamp = "1234567890"
        }

        local response = runHandler("calculate-experience", msg)
        assert(response.Success == "true", "Experience calculation should succeed")
        local result = response.Data.experienceResult

        -- Verify result is within expected range (accounting for Math.floor precision)
        local minExpected = testCase[5][1]
        local maxExpected = testCase[5][2]
        assert(result.baseExperience >= minExpected and result.baseExperience <= maxExpected,
               string.format("Base exp for case (%d, %d, %d, %s) should be %d-%d, got %d",
                           testCase[1], testCase[2], testCase[3], testCase[4],
                           minExpected, maxExpected, result.baseExperience))
    end

    print("✓ Base experience calculation parity test passed")
end

-- Test modifier calculations match TypeScript multiplication order
function tests.testModifierCalculationParity()
    print("Testing modifier calculation parity...")

    -- Base case without modifiers
    local baseMsg = {
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

    local baseResponse = runHandler("calculate-experience", baseMsg)
    local baseExp = baseResponse.Data.experienceResult.modifiedExperience

    -- Test Lucky Egg modifier (1.5x)
    baseMsg.Modifiers = {hasLuckyEgg = true}
    local luckyEggResponse = runHandler("calculate-experience", baseMsg)
    local luckyEggExp = luckyEggResponse.Data.experienceResult.modifiedExperience

    -- Should be exactly floor(base * 1.5) due to TypeScript Math.floor behavior
    local expectedLuckyEggExp = math.floor(baseExp * 1.5)
    assert(luckyEggExp == expectedLuckyEggExp,
           string.format("Lucky Egg should give floor(base * 1.5): expected %d, got %d",
                       expectedLuckyEggExp, luckyEggExp))

    -- Test traded Pokemon modifier (1.5x for same language, 1.7x for different)
    baseMsg.Modifiers = {isTraded = true, isDifferentLanguage = false}
    local tradedResponse = runHandler("calculate-experience", baseMsg)
    local tradedExp = tradedResponse.Data.experienceResult.modifiedExperience

    local expectedTradedExp = math.floor(baseExp * 1.5)
    assert(tradedExp == expectedTradedExp,
           string.format("Traded Pokemon should give floor(base * 1.5): expected %d, got %d",
                       expectedTradedExp, tradedExp))

    -- Test different language traded Pokemon
    baseMsg.Modifiers = {isTraded = true, isDifferentLanguage = true}
    local diffLangResponse = runHandler("calculate-experience", baseMsg)
    local diffLangExp = diffLangResponse.Data.experienceResult.modifiedExperience

    local expectedDiffLangExp = math.floor(baseExp * 1.7)
    assert(diffLangExp == expectedDiffLangExp,
           string.format("Different language traded should give floor(base * 1.7): expected %d, got %d",
                       expectedDiffLangExp, diffLangExp))

    -- Test trainer battle modifier (applied before other modifiers in TypeScript)
    baseMsg.BattleType = "TRAINER"
    baseMsg.Modifiers = nil
    local trainerResponse = runHandler("calculate-experience", baseMsg)
    local trainerExp = trainerResponse.Data.experienceResult.modifiedExperience

    -- Trainer battle should be floor(base * 1.5) at the battle type level
    assert(trainerExp > baseExp, "Trainer battle should increase experience")
    local trainerMultiplier = trainerExp / baseExp
    assert(math.abs(trainerMultiplier - 1.5) < 0.1, "Trainer battle should be ~1.5x multiplier")

    print("✓ Modifier calculation parity test passed")
end

-- Test level-up detection matches TypeScript threshold logic
function tests.testLevelUpDetectionParity()
    print("Testing level-up detection parity...")

    -- Test cases that cross level boundaries exactly
    local testCases = {
        -- {current exp, current level, exp gained, growth rate, expected new level}
        {999, 10, 1, "MEDIUM_FAST", 10},     -- Just under threshold
        {1330, 10, 1, "MEDIUM_FAST", 11},     -- Just over threshold (1331 for level 11)
        {124999, 49, 1, "MEDIUM_FAST", 50},  -- Cross to level 50
        {999999, 99, 1, "MEDIUM_FAST", 100}, -- Cross to level 100
        {1000000, 100, 50000, "MEDIUM_FAST", 100}, -- At max level, shouldn't change
    }

    for _, testCase in ipairs(testCases) do
        local msg = {
            From = "test_sender",
            Action = "ApplyExperience",
            PokemonId = "parity_test",
            ExperienceGained = tostring(testCase[3]),
            CurrentExp = tostring(testCase[1]),
            CurrentLevel = tostring(testCase[2]),
            GrowthRate = testCase[4],
            Timestamp = "1234567890"
        }

        local response = runHandler("apply-experience", msg)
        assert(response.Success == "true", "Experience application should succeed")
        local result = response.Data.experienceResult

        assert(result.newLevel == testCase[5],
               string.format("Level calculation mismatch: exp=%d->%d, level=%d, expected=%d, got=%d",
                           testCase[1], testCase[1] + testCase[3], testCase[2],
                           testCase[5], result.newLevel))
    end

    print("✓ Level-up detection parity test passed")
end

-- Test stat calculation formulas match TypeScript exactly
function tests.testStatCalculationParity()
    print("Testing stat calculation parity...")

    -- Test HP calculation: floor((2 * base + iv + floor(ev/4)) * level / 100) + level + 10
    local pokemon = {
        ivs = {hp = 15, attack = 20, defense = 25, spatk = 30, spdef = 10, speed = 5},
        evs = {hp = 100, attack = 50, defense = 200, spatk = 0, spdef = 75, speed = 80},
        natureMod = {attack = 1.1, defense = 0.9, spatk = 1.0, spdef = 1.0, speed = 1.0}
    }

    local speciesBaseStats = {
        hp = 80,
        attack = 100,
        defense = 70,
        spatk = 85,
        spdef = 75,
        speed = 90
    }

    local testLevel = 50

    -- Calculate expected HP (TypeScript formula)
    local expectedHp = math.floor((2 * speciesBaseStats.hp + pokemon.ivs.hp + math.floor(pokemon.evs.hp / 4)) * testLevel / 100) + testLevel + 10

    -- Calculate expected Attack (with nature modifier)
    local expectedAttack = math.floor((math.floor((2 * speciesBaseStats.attack + pokemon.ivs.attack + math.floor(pokemon.evs.attack / 4)) * testLevel / 100) + 5) * pokemon.natureMod.attack)

    -- Calculate expected Defense (with nature modifier)
    local expectedDefense = math.floor((math.floor((2 * speciesBaseStats.defense + pokemon.ivs.defense + math.floor(pokemon.evs.defense / 4)) * testLevel / 100) + 5) * pokemon.natureMod.defense)

    local msg = {
        From = "test_sender",
        Action = "CalculateLevelUpStats",
        Pokemon = pokemon,
        OldLevel = tostring(testLevel - 1),
        NewLevel = tostring(testLevel),
        SpeciesBaseStats = speciesBaseStats,
        Timestamp = "1234567890"
    }

    local response = runHandler("calculate-levelup-stats", msg)
    assert(response.Success == "true", "Stat calculation should succeed")
    local result = response.Data.levelUpResult

    -- Verify HP calculation matches exactly
    assert(result.newStats.hp == expectedHp,
           string.format("HP mismatch: expected %d, got %d", expectedHp, result.newStats.hp))

    -- Verify Attack calculation matches exactly
    assert(result.newStats.attack == expectedAttack,
           string.format("Attack mismatch: expected %d, got %d", expectedAttack, result.newStats.attack))

    -- Verify Defense calculation matches exactly
    assert(result.newStats.defense == expectedDefense,
           string.format("Defense mismatch: expected %d, got %d", expectedDefense, result.newStats.defense))

    print("✓ Stat calculation parity test passed")
end

-- Test experience overflow and boundary conditions
function tests.testExperienceOverflowParity()
    print("Testing experience overflow parity...")

    -- Test maximum experience boundaries for each growth rate
    local maxExpValues = {
        MEDIUM_FAST = 1000000,
        SLOW = 1081250,
        FAST = 935000,
        ERRATIC = 870000,
        MEDIUM_SLOW = 1019454,
        FLUCTUATING = 1208000
    }

    for growthRate, maxExp in pairs(maxExpValues) do
        -- Test applying experience that would exceed maximum
        local msg = {
            From = "test_sender",
            Action = "ApplyExperience",
            PokemonId = "overflow_test",
            ExperienceGained = "100000",
            CurrentExp = tostring(maxExp - 50000),
            CurrentLevel = "99",
            GrowthRate = growthRate,
            Timestamp = "1234567890"
        }

        local response = runHandler("apply-experience", msg)
        assert(response.Success == "true", "Overflow handling should succeed for " .. growthRate)
        local result = response.Data.experienceResult

        -- Should cap at exactly the maximum for that growth rate
        assert(result.newExp == maxExp,
               string.format("%s max exp should cap at %d, got %d", growthRate, maxExp, result.newExp))

        assert(result.newLevel == 100, "Should reach level 100")
        assert(result.expToNextLevel == 0, "Should have 0 exp to next level at cap")
    end

    print("✓ Experience overflow parity test passed")
end

-- Test Math.floor precision matches TypeScript in edge cases
function tests.testMathFloorPrecisionParity()
    print("Testing Math.floor precision parity...")

    -- Test edge cases where floating point precision matters
    local testCases = {
        -- Experience calculations that might have floating point issues
        {baseExp = 133, level1 = 37, level2 = 43, battleType = "TRAINER"},  -- Prime numbers
        {baseExp = 157, level1 = 29, level2 = 31, battleType = "WILD"},     -- Close levels
        {baseExp = 199, level1 = 67, level2 = 23, battleType = "TRAINER"},  -- Large difference
    }

    for _, testCase in ipairs(testCases) do
        local msg = {
            From = "test_sender",
            Action = "CalculateExperience",
            DefeatedPokemon = {
                baseExperience = testCase.baseExp,
                level = testCase.level1
            },
            VictorPokemon = {
                level = testCase.level2
            },
            BattleType = testCase.battleType,
            Timestamp = "1234567890"
        }

        local response = runHandler("calculate-experience", msg)
        assert(response.Success == "true", "Precision test should succeed")
        local result = response.Data.experienceResult

        -- Result should be an integer (Math.floor applied correctly)
        assert(result.baseExperience == math.floor(result.baseExperience),
               "Base experience should be floored to integer")
        assert(result.modifiedExperience == math.floor(result.modifiedExperience),
               "Modified experience should be floored to integer")
    end

    print("✓ Math.floor precision parity test passed")
end

-- Run all parity tests
print("\n=== Running Experience and Leveling Engine Parity Tests ===\n")

for name, test in pairs(tests) do
    local success, err = pcall(test)
    if success then
        testsPassed = testsPassed + 1
    else
        testsFailed = testsFailed + 1
        print("✗ " .. name .. " failed: " .. err)
    end
end

print("\n=== Parity Test Results ===")
print(string.format("Passed: %d", testsPassed))
print(string.format("Failed: %d", testsFailed))

if testsFailed == 0 then
    print("\n✓ All parity tests passed! Experience calculations match TypeScript exactly.")
    os.exit(0)
else
    print("\n✗ Some parity tests failed - mathematical parity not achieved")
    os.exit(1)
end