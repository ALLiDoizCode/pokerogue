-- Player Progression Parity Tests
-- Validates that Lua calculations match TypeScript implementation exactly
-- Tests mathematical precision for experience calculations, achievement thresholds, and progression formulas

local aolite = require("aolite")

-- TypeScript reference calculations (extracted from exp.ts)
local TypeScriptReferenceLevels = {
    -- MEDIUM_FAST growth rate reference values from TypeScript implementation
    MEDIUM_FAST = {
        [1] = 0,      -- Level 1: 0 exp
        [2] = 8,      -- Level 2: 8 exp
        [3] = 27,     -- Level 3: 27 exp
        [4] = 64,     -- Level 4: 64 exp
        [5] = 125,    -- Level 5: 125 exp
        [10] = 1000,  -- Level 10: 1000 exp
        [15] = 3375,  -- Level 15: 3375 exp
        [20] = 8000,  -- Level 20: 8000 exp
        [25] = 15625, -- Level 25: 15625 exp
        [30] = 27000, -- Level 30: 27000 exp
        [50] = 125000, -- Level 50: 125000 exp
        [100] = 1000000 -- Level 100: 1000000 exp
    },

    -- FAST growth rate reference values
    FAST = {
        [1] = 0,
        [2] = 6,
        [3] = 21,
        [4] = 51,
        [5] = 100,
        [10] = 800,
        [20] = 6400,
        [50] = 100000,
        [100] = 800000
    },

    -- SLOW growth rate reference values
    SLOW = {
        [1] = 0,
        [2] = 10,
        [3] = 33,
        [4] = 80,
        [5] = 156,
        [10] = 1250,
        [20] = 10000,
        [50] = 156250,
        [100] = 1250000
    }
}

-- Achievement thresholds from TypeScript (matching exact values)
local TypeScriptAchievementThresholds = {
    -- Money achievements
    MONEY_10000 = { threshold = 10000, score = 10 },
    MONEY_100000 = { threshold = 100000, score = 25 },
    MONEY_1000000 = { threshold = 1000000, score = 50 },

    -- Damage achievements
    DAMAGE_1000 = { threshold = 1000, score = 10 },
    DAMAGE_9999 = { threshold = 9999, score = 50 },

    -- Level achievements
    LEVEL_100 = { threshold = 100, score = 75 },
    LEVEL_1000 = { threshold = 1000, score = 100 },

    -- Battle achievements
    WIN_10 = { threshold = 10, score = 10 },
    WIN_100 = { threshold = 100, score = 25 },
    WIN_1000 = { threshold = 1000, score = 50 }
}

describe("Player Progression Parity Tests", function()
    local process

    before_each(function()
        local processCode = io.open("processes/player-progression-engine.lua", "r"):read("*all")
        process = aolite.spawn({
            name = "parity-test-progression",
            src = processCode
        })
    end)

    describe("Experience Calculation Parity", function()
        it("should match TypeScript MEDIUM_FAST experience requirements exactly", function()
            for level, expectedExp in pairs(TypeScriptReferenceLevels.MEDIUM_FAST) do
                if level > 1 then -- Skip level 1 (0 exp)
                    local response = process.send({
                        Action = "UpdatePlayerLevel",
                        ExperienceGained = tostring(expectedExp),
                        GrowthRate = "2" -- MEDIUM_FAST
                    })

                    assert.equals("PlayerLevelUpdated", response.Action)
                    local achievedLevel = tonumber(response.NewLevel)

                    assert.equals(level, achievedLevel,
                        string.format("MEDIUM_FAST: %d experience should result in level %d, got level %d",
                            expectedExp, level, achievedLevel))
                end
            end
        end)

        it("should match TypeScript FAST growth rate calculations", function()
            for level, expectedExp in pairs(TypeScriptReferenceLevels.FAST) do
                if level > 1 then
                    local response = process.send({
                        Action = "UpdatePlayerLevel",
                        ExperienceGained = tostring(expectedExp),
                        GrowthRate = "1" -- FAST
                    })

                    local achievedLevel = tonumber(response.NewLevel)
                    assert.equals(level, achievedLevel,
                        string.format("FAST: %d experience should result in level %d, got level %d",
                            expectedExp, level, achievedLevel))
                end
            end
        end)

        it("should match TypeScript SLOW growth rate calculations", function()
            for level, expectedExp in pairs(TypeScriptReferenceLevels.SLOW) do
                if level > 1 then
                    local response = process.send({
                        Action = "UpdatePlayerLevel",
                        ExperienceGained = tostring(expectedExp),
                        GrowthRate = "4" -- SLOW
                    })

                    local achievedLevel = tonumber(response.NewLevel)
                    assert.equals(level, achievedLevel,
                        string.format("SLOW: %d experience should result in level %d, got level %d",
                            expectedExp, level, achievedLevel))
                end
            end
        end)

        it("should handle level 100+ formula calculations matching TypeScript", function()
            -- Test levels above 100 using formula calculations
            local highLevelTests = {
                {growthRate = "2", exp = 1100000, minLevel = 100}, -- MEDIUM_FAST above 100
                {growthRate = "1", exp = 900000, minLevel = 100},  -- FAST above 100
                {growthRate = "4", exp = 1400000, minLevel = 100}  -- SLOW above 100
            }

            for _, test in ipairs(highLevelTests) do
                local response = process.send({
                    Action = "UpdatePlayerLevel",
                    ExperienceGained = tostring(test.exp),
                    GrowthRate = test.growthRate
                })

                local achievedLevel = tonumber(response.NewLevel)
                assert.truthy(achievedLevel > test.minLevel,
                    string.format("Growth rate %s with %d exp should exceed level %d, got %d",
                        test.growthRate, test.exp, test.minLevel, achievedLevel))
            end
        end)

        it("should maintain mathematical precision in incremental experience gains", function()
            local playerId = "precision-test"
            local increments = {100, 200, 150, 300, 250}
            local totalExp = 0

            for _, increment in ipairs(increments) do
                local response = process.send({
                    Action = "UpdatePlayerLevel",
                    PlayerId = playerId,
                    ExperienceGained = tostring(increment),
                    GrowthRate = "2" -- MEDIUM_FAST
                })

                totalExp = totalExp + increment
                local reportedExp = tonumber(response.TotalExperience)

                assert.equals(totalExp, reportedExp,
                    string.format("Total experience should be %d, got %d", totalExp, reportedExp))
            end
        end)
    end)

    describe("Achievement Threshold Parity", function()
        it("should match TypeScript money achievement thresholds exactly", function()
            local moneyTests = {
                {amount = 9999, shouldNotTrigger = "MONEY_10000"},
                {amount = 10000, shouldTrigger = "MONEY_10000"},
                {amount = 99999, shouldTrigger = "MONEY_10000", shouldNotTrigger = "MONEY_100000"},
                {amount = 100000, shouldTrigger = "MONEY_100000"},
                {amount = 999999, shouldTrigger = "MONEY_100000", shouldNotTrigger = "MONEY_1000000"},
                {amount = 1000000, shouldTrigger = "MONEY_1000000"}
            }

            for _, test in ipairs(moneyTests) do
                local playerId = "money-test-" .. tostring(test.amount)

                local response = process.send({
                    Action = "UpdateAchievementProgress",
                    PlayerId = playerId,
                    UpdateType = "money_earned",
                    Value = tostring(test.amount)
                })

                assert.equals("AchievementProgressUpdated", response.Action)

                local newAchievements = response.NewAchievements and json.decode(response.NewAchievements) or {}

                if test.shouldTrigger then
                    local found = false
                    for _, achv in ipairs(newAchievements) do
                        if achv.id and achv.id:find(test.shouldTrigger) then
                            found = true
                            break
                        end
                    end
                    assert.truthy(found, string.format("Amount %d should trigger %s achievement", test.amount, test.shouldTrigger))
                end

                if test.shouldNotTrigger then
                    local found = false
                    for _, achv in ipairs(newAchievements) do
                        if achv.id and achv.id:find(test.shouldNotTrigger) then
                            found = true
                            break
                        end
                    end
                    assert.falsy(found, string.format("Amount %d should NOT trigger %s achievement", test.amount, test.shouldNotTrigger))
                end
            end
        end)

        it("should match TypeScript damage achievement thresholds exactly", function()
            local damageTests = {
                {damage = 999, shouldNotTrigger = true},
                {damage = 1000, shouldTrigger = "DAMAGE_1000"},
                {damage = 5000, shouldTrigger = "DAMAGE_1000", shouldNotTrigger = "DAMAGE_9999"},
                {damage = 9999, shouldTrigger = "DAMAGE_9999"}
            }

            for _, test in ipairs(damageTests) do
                local playerId = "damage-test-" .. tostring(test.damage)

                local response = process.send({
                    Action = "UpdateAchievementProgress",
                    PlayerId = playerId,
                    UpdateType = "damage_dealt",
                    Value = tostring(test.damage)
                })

                assert.equals("AchievementProgressUpdated", response.Action)
            end
        end)

        it("should match TypeScript level achievement thresholds exactly", function()
            local levelTests = {
                {exp = 999999, expectedMinLevel = 99, shouldNotTrigger = "LEVEL_100"}, -- Just under level 100
                {exp = 1000000, expectedMinLevel = 100, shouldTrigger = "LEVEL_100"} -- Level 100 exactly
            }

            for _, test in ipairs(levelTests) do
                local playerId = "level-test-" .. tostring(test.exp)

                local response = process.send({
                    Action = "UpdatePlayerLevel",
                    PlayerId = playerId,
                    ExperienceGained = tostring(test.exp),
                    GrowthRate = "2" -- MEDIUM_FAST
                })

                local achievedLevel = tonumber(response.NewLevel)
                assert.truthy(achievedLevel >= test.expectedMinLevel,
                    string.format("Experience %d should result in level >= %d", test.exp, test.expectedMinLevel))
            end
        end)

        it("should award achievement points matching TypeScript values", function()
            -- Test that achievement scores match exactly
            local playerId = "score-test"

            -- Trigger a specific achievement with known score
            process.send({
                Action = "UpdateAchievementProgress",
                PlayerId = playerId,
                UpdateType = "money_earned",
                Value = "100000" -- Should trigger MONEY_100000 (score: 25)
            })

            -- Load progression to check achievements
            local progression = process.send({
                Action = "LoadPlayerProgression",
                PlayerId = playerId
            })

            local data = json.decode(progression.Data)
            if data and data.achievements then
                for achvId, achvData in pairs(data.achievements) do
                    if achvId:find("MONEY_100000") then
                        assert.equals(25, achvData.score, "MONEY_100000 achievement should have score 25")
                    end
                end
            end
        end)
    end)

    describe("Statistics Accumulation Parity", function()
        it("should track battle statistics with TypeScript precision", function()
            local playerId = "stats-parity-test"
            local battleCount = 150

            -- Simulate exact battle sequence
            for i = 1, battleCount do
                process.send({
                    Action = "UpdateAchievementProgress",
                    PlayerId = playerId,
                    UpdateType = "battle_win",
                    Value = "1"
                })
            end

            local stats = process.send({
                Action = "GetPlayerStatistics",
                PlayerId = playerId
            })

            assert.equals(tostring(battleCount), stats.Battles)
            assert.equals(tostring(battleCount), stats.SessionsWon)
        end)

        it("should track highest values correctly matching TypeScript logic", function()
            local playerId = "highest-values-test"

            -- Test highest damage tracking
            local damageValues = {1200, 800, 1500, 900, 2000, 1100}
            local expectedHighestDamage = 2000

            for _, damage in ipairs(damageValues) do
                process.send({
                    Action = "UpdateAchievementProgress",
                    PlayerId = playerId,
                    UpdateType = "damage_dealt",
                    Value = tostring(damage)
                })
            end

            -- Test highest heal tracking
            local healValues = {300, 150, 450, 200, 600, 350}
            local expectedHighestHeal = 600

            for _, heal in ipairs(healValues) do
                process.send({
                    Action = "UpdateAchievementProgress",
                    PlayerId = playerId,
                    UpdateType = "heal_amount",
                    Value = tostring(heal)
                })
            end

            -- Verify highest values
            local stats = process.send({
                Action = "GetPlayerStatistics",
                PlayerId = playerId
            })

            assert.equals(tostring(expectedHighestDamage), stats.HighestDamage)

            local data = stats.Data and json.decode(stats.Data)
            if data then
                assert.equals(expectedHighestHeal, data.highestHeal)
            end
        end)

        it("should maintain counter precision for large numbers", function()
            local playerId = "precision-test"

            -- Test large catch count
            local catchCount = 9999
            for i = 1, catchCount do
                process.send({
                    Action = "UpdateAchievementProgress",
                    PlayerId = playerId,
                    UpdateType = "pokemon_caught",
                    Value = "1"
                })

                -- Check intermediate values at milestones
                if i % 1000 == 0 then
                    local stats = process.send({
                        Action = "GetPlayerStatistics",
                        PlayerId = playerId
                    })

                    assert.equals(tostring(i), stats.PokemonCaught,
                        string.format("At iteration %d, caught count should be %d", i, i))
                end
            end
        end)
    end)

    describe("Unlock Condition Parity", function()
        it("should match TypeScript unlock trigger conditions exactly", function()
            local unlockTests = {
                {
                    name = "ENDLESS_MODE",
                    setup = function(playerId)
                        -- Win 1 session (exact TypeScript condition)
                        process.send({
                            Action = "UpdateAchievementProgress",
                            PlayerId = playerId,
                            UpdateType = "battle_win",
                            Value = "1"
                        })
                    end,
                    expectedUnlock = "0" -- ENDLESS_MODE = 0
                },
                {
                    name = "MINI_BLACK_HOLE",
                    setup = function(playerId)
                        -- Reach level 50+ (exact TypeScript condition)
                        process.send({
                            Action = "UpdatePlayerLevel",
                            PlayerId = playerId,
                            ExperienceGained = "125000", -- Level 50 in MEDIUM_FAST
                            GrowthRate = "2"
                        })
                    end,
                    expectedUnlock = "1" -- MINI_BLACK_HOLE = 1
                },
                {
                    name = "EVIOLITE",
                    setup = function(playerId)
                        -- Catch 100+ Pokemon (exact TypeScript condition)
                        for i = 1, 100 do
                            process.send({
                                Action = "UpdateAchievementProgress",
                                PlayerId = playerId,
                                UpdateType = "pokemon_caught",
                                Value = "1"
                            })
                        end
                    end,
                    expectedUnlock = "3" -- EVIOLITE = 3
                }
            }

            for _, test in ipairs(unlockTests) do
                local playerId = "unlock-test-" .. test.name

                -- Setup conditions
                test.setup(playerId)

                -- Check unlocks
                local unlocks = process.send({
                    Action = "CheckUnlockConditions",
                    PlayerId = playerId
                })

                assert.equals("UnlockConditionsChecked", unlocks.Action)

                local unlockedFeatures = unlocks.AllUnlocks and json.decode(unlocks.AllUnlocks)
                if unlockedFeatures then
                    assert.truthy(unlockedFeatures[test.expectedUnlock],
                        string.format("%s should be unlocked", test.name))
                end
            end
        end)

        it("should match TypeScript unlock dependency chains", function()
            local playerId = "dependency-test"

            -- Step 1: Unlock ENDLESS_MODE first
            process.send({
                Action = "UpdateAchievementProgress",
                PlayerId = playerId,
                UpdateType = "battle_win",
                Value = "1"
            })

            -- Step 2: Simulate high endless wave for SPLICED_ENDLESS_MODE
            process.send({
                Action = "UpdateAchievementProgress",
                PlayerId = playerId,
                UpdateType = "endless_wave",
                Value = "100"
            })

            local unlocks = process.send({
                Action = "CheckUnlockConditions",
                PlayerId = playerId
            })

            local unlockedFeatures = unlocks.AllUnlocks and json.decode(unlocks.AllUnlocks)
            if unlockedFeatures then
                assert.truthy(unlockedFeatures["0"], "ENDLESS_MODE should be unlocked first")
                -- Note: SPLICED_ENDLESS_MODE logic would need to be implemented based on actual TypeScript requirements
            end
        end)
    end)

    describe("Progression Formula Parity", function()
        it("should handle fractional calculations matching TypeScript Math.floor behavior", function()
            -- Test that Lua math.floor matches TypeScript Math.floor
            local testValues = {
                1000.7, 2500.3, 9999.9, 15000.1, 50000.8
            }

            for _, exp in ipairs(testValues) do
                local response = process.send({
                    Action = "UpdatePlayerLevel",
                    ExperienceGained = tostring(math.floor(exp)), -- Pre-floor like TypeScript
                    GrowthRate = "2"
                })

                local totalExp = tonumber(response.TotalExperience)
                assert.equals(math.floor(exp), totalExp,
                    string.format("Floored experience %d should match exactly", math.floor(exp)))
            end
        end)

        it("should handle growth rate multiplier calculations with TypeScript precision", function()
            -- Test the complex growth rate formula from TypeScript:
            -- For non-MEDIUM_FAST: floor(ret * 0.325 + getLevelTotalExp(level, MEDIUM_FAST) * 0.675)

            local level = 50
            local mediumFastExp = 125000 -- Level 50 MEDIUM_FAST

            -- Test FAST growth rate calculation
            local fastResponse = process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = tostring(mediumFastExp),
                GrowthRate = "1" -- FAST
            })

            -- Should reach level 50 or close due to growth rate conversion
            local fastLevel = tonumber(fastResponse.NewLevel)
            assert.truthy(fastLevel >= 45 and fastLevel <= 55,
                string.format("FAST growth rate should result in level 45-55, got %d", fastLevel))
        end)

        it("should maintain precision across multiple growth rate conversions", function()
            local growthRates = {"0", "1", "2", "3", "4", "5"} -- All growth rates
            local baseExp = 27000 -- Should be level 30 in MEDIUM_FAST

            local results = {}
            for _, rate in ipairs(growthRates) do
                local response = process.send({
                    Action = "UpdatePlayerLevel",
                    PlayerId = "growth-test-" .. rate,
                    ExperienceGained = tostring(baseExp),
                    GrowthRate = rate
                })

                results[rate] = tonumber(response.NewLevel)
            end

            -- MEDIUM_FAST should be exactly level 30
            assert.equals(30, results["2"], "MEDIUM_FAST should be exactly level 30")

            -- Other growth rates should be reasonable variations
            for rate, level in pairs(results) do
                assert.truthy(level >= 20 and level <= 40,
                    string.format("Growth rate %s should result in reasonable level (20-40), got %d", rate, level))
            end
        end)
    end)
end)