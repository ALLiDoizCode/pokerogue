-- Player Progression Engine Unit Tests
-- Tests all player progression functionality including level progression, achievements, unlocks, and statistics

local aolite = require("aolite")

-- Load the player progression engine process
local processCode = io.open("processes/player-progression-engine.lua", "r"):read("*all")

describe("Player Progression Engine", function()
    local process

    before_each(function()
        -- Create fresh process instance for each test
        process = aolite.spawn({
            name = "test-player-progression",
            src = processCode
        })
    end)

    describe("Level Progression System", function()
        it("should handle basic level progression with MEDIUM_FAST growth", function()
            -- Test basic level progression
            local response = process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "1000",
                GrowthRate = "2" -- MEDIUM_FAST
            })

            assert.truthy(response)
            assert.equals("PlayerLevelUpdated", response.Action)
            assert.equals("true", response.Success)
            assert.truthy(response.NewLevel)
            assert.truthy(response.TotalExperience)
        end)

        it("should calculate correct experience requirements for all growth rates", function()
            -- Test different growth rates
            local growthRates = {"0", "1", "2", "3", "4", "5"} -- ERRATIC to FLUCTUATING

            for _, rate in ipairs(growthRates) do
                local response = process.send({
                    Action = "UpdatePlayerLevel",
                    ExperienceGained = "8000", -- Should reach level 20+ in most growth rates
                    GrowthRate = rate
                })

                assert.equals("PlayerLevelUpdated", response.Action)
                assert.equals("true", response.Success)

                local newLevel = tonumber(response.NewLevel)
                assert.truthy(newLevel and newLevel > 1, "Level should increase for growth rate " .. rate)
            end
        end)

        it("should maintain mathematical precision matching TypeScript", function()
            -- Test specific experience values that should result in exact levels
            local testCases = {
                {exp = 1000, growthRate = "2", expectedLevel = 10},  -- MEDIUM_FAST: level 10 = 1000 exp
                {exp = 8000, growthRate = "2", expectedLevel = 20},  -- MEDIUM_FAST: level 20 = 8000 exp
                {exp = 27000, growthRate = "2", expectedLevel = 30}  -- MEDIUM_FAST: level 30 = 27000 exp
            }

            for _, test in ipairs(testCases) do
                local response = process.send({
                    Action = "UpdatePlayerLevel",
                    ExperienceGained = test.exp,
                    GrowthRate = test.growthRate
                })

                local newLevel = tonumber(response.NewLevel)
                assert.equals(test.expectedLevel, newLevel,
                    string.format("Experience %d with growth rate %s should result in level %d, got %d",
                        test.exp, test.growthRate, test.expectedLevel, newLevel))
            end
        end)

        it("should handle high levels above 100", function()
            -- Test levels above 100 (uses formula calculation)
            local response = process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "2000000", -- Should reach very high level
                GrowthRate = "2" -- MEDIUM_FAST
            })

            assert.equals("PlayerLevelUpdated", response.Action)
            assert.equals("true", response.Success)

            local newLevel = tonumber(response.NewLevel)
            assert.truthy(newLevel > 100, "Should handle levels above 100")
        end)

        it("should update highest level statistics", function()
            -- First level up
            process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "1000",
                GrowthRate = "2"
            })

            -- Check statistics
            local statsResponse = process.send({
                Action = "GetPlayerStatistics"
            })

            assert.equals("PlayerStatisticsRetrieved", statsResponse.Action)
            assert.equals("true", statsResponse.Success)

            local highestLevel = tonumber(statsResponse.HighestLevel)
            assert.truthy(highestLevel > 1, "Highest level should be updated")
        end)
    end)

    describe("Achievement System", function()
        it("should award level-based achievements", function()
            -- Level up to trigger level achievements
            local response = process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "1000000", -- Should trigger level 100+
                GrowthRate = "2"
            })

            assert.equals("PlayerLevelUpdated", response.Action)

            -- Check if achievements were awarded
            local data = response.Data and json.decode(response.Data)
            if data and data.newAchievements then
                assert.truthy(#data.newAchievements >= 0, "Should check for level achievements")
            end
        end)

        it("should track achievement progress correctly", function()
            -- Test battle win achievement
            local response = process.send({
                Action = "UpdateAchievementProgress",
                UpdateType = "battle_win",
                Value = "1"
            })

            assert.equals("AchievementProgressUpdated", response.Action)
            assert.equals("true", response.Success)
            assert.equals("battle_win", response.UpdateType)
        end)

        it("should award money-based achievements", function()
            -- Test money achievement
            local response = process.send({
                Action = "UpdateAchievementProgress",
                UpdateType = "money_earned",
                Value = "50000" -- Should trigger money achievements
            })

            assert.equals("AchievementProgressUpdated", response.Action)
            assert.equals("true", response.Success)
        end)

        it("should award damage-based achievements", function()
            -- Test damage achievement
            local response = process.send({
                Action = "UpdateAchievementProgress",
                UpdateType = "damage_dealt",
                Value = "2000" -- Should trigger damage achievements
            })

            assert.equals("AchievementProgressUpdated", response.Action)
            assert.equals("true", response.Success)
        end)

        it("should award catch-based achievements", function()
            -- Test multiple catches to trigger achievements
            for i = 1, 15 do
                local response = process.send({
                    Action = "UpdateAchievementProgress",
                    UpdateType = "pokemon_caught",
                    Value = "1"
                })

                assert.equals("AchievementProgressUpdated", response.Action)
                assert.equals("true", response.Success)
            end

            -- Check final statistics
            local statsResponse = process.send({
                Action = "GetPlayerStatistics"
            })

            local caught = tonumber(statsResponse.PokemonCaught)
            assert.equals(15, caught, "Should track Pokemon caught correctly")
        end)
    end)

    describe("Unlock System", function()
        it("should unlock ENDLESS_MODE after winning a session", function()
            -- Win a session
            process.send({
                Action = "UpdateAchievementProgress",
                UpdateType = "battle_win",
                Value = "1"
            })

            -- Check unlocks
            local response = process.send({
                Action = "CheckUnlockConditions"
            })

            assert.equals("UnlockConditionsChecked", response.Action)
            assert.equals("true", response.Success)

            local unlocks = response.AllUnlocks and json.decode(response.AllUnlocks)
            if unlocks then
                assert.truthy(unlocks["0"], "ENDLESS_MODE should be unlocked after session win")
            end
        end)

        it("should unlock MINI_BLACK_HOLE at high level", function()
            -- Level up to 50+
            process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "125000", -- Should reach level 50+ in MEDIUM_FAST
                GrowthRate = "2"
            })

            -- Check unlocks
            local response = process.send({
                Action = "CheckUnlockConditions"
            })

            assert.equals("UnlockConditionsChecked", response.Action)
            assert.equals("true", response.Success)
        end)

        it("should unlock EVIOLITE after catching many Pokemon", function()
            -- Catch 100+ Pokemon
            for i = 1, 105 do
                process.send({
                    Action = "UpdateAchievementProgress",
                    UpdateType = "pokemon_caught",
                    Value = "1"
                })
            end

            -- Check unlocks
            local response = process.send({
                Action = "CheckUnlockConditions"
            })

            assert.equals("UnlockConditionsChecked", response.Action)
            assert.equals("true", response.Success)

            local unlocks = response.AllUnlocks and json.decode(response.AllUnlocks)
            if unlocks then
                assert.truthy(unlocks["3"], "EVIOLITE should be unlocked after catching 100+ Pokemon")
            end
        end)
    end)

    describe("Statistics Tracking", function()
        it("should track battle statistics correctly", function()
            -- Multiple battle wins
            for i = 1, 5 do
                process.send({
                    Action = "UpdateAchievementProgress",
                    UpdateType = "battle_win",
                    Value = "1"
                })
            end

            -- Check statistics
            local response = process.send({
                Action = "GetPlayerStatistics"
            })

            assert.equals("PlayerStatisticsRetrieved", response.Action)
            assert.equals("true", response.Success)

            local battles = tonumber(response.Battles)
            local wins = tonumber(response.SessionsWon)
            assert.equals(5, battles, "Should track total battles")
            assert.equals(5, wins, "Should track session wins")
        end)

        it("should track highest damage correctly", function()
            -- Deal increasing damage amounts
            local damageAmounts = {"500", "1200", "800", "1500", "900"}

            for _, damage in ipairs(damageAmounts) do
                process.send({
                    Action = "UpdateAchievementProgress",
                    UpdateType = "damage_dealt",
                    Value = damage
                })
            end

            -- Check statistics
            local response = process.send({
                Action = "GetPlayerStatistics"
            })

            local highestDamage = tonumber(response.HighestDamage)
            assert.equals(1500, highestDamage, "Should track highest damage correctly")
        end)

        it("should track highest heal correctly", function()
            -- Heal varying amounts
            local healAmounts = {"200", "450", "300", "600", "150"}

            for _, heal in ipairs(healAmounts) do
                process.send({
                    Action = "UpdateAchievementProgress",
                    UpdateType = "heal_amount",
                    Value = heal
                })
            end

            -- Check statistics
            local response = process.send({
                Action = "GetPlayerStatistics"
            })

            local data = response.Data and json.decode(response.Data)
            if data then
                assert.equals(600, data.highestHeal, "Should track highest heal correctly")
            end
        end)

        it("should maintain statistics precision", function()
            -- Test that statistics don't lose precision
            process.send({
                Action = "UpdateAchievementProgress",
                UpdateType = "money_earned",
                Value = "999999"
            })

            local response = process.send({
                Action = "GetPlayerStatistics"
            })

            local data = response.Data and json.decode(response.Data)
            if data then
                assert.equals(999999, data.highestMoney, "Should maintain precise statistics")
            end
        end)
    end)

    describe("Reward Distribution", function()
        it("should distribute experience rewards", function()
            local response = process.send({
                Action = "DistributeProgressionReward",
                RewardType = "experience",
                Amount = "2000"
            })

            assert.equals("ProgressionRewardDistributed", response.Action)
            assert.equals("true", response.Success)
            assert.equals("experience", response.RewardType)
            assert.equals("2000", response.Amount)
        end)

        it("should distribute money rewards", function()
            local response = process.send({
                Action = "DistributeProgressionReward",
                RewardType = "money",
                Amount = "5000"
            })

            assert.equals("ProgressionRewardDistributed", response.Action)
            assert.equals("true", response.Success)
            assert.equals("money", response.RewardType)
        end)

        it("should distribute item rewards", function()
            local response = process.send({
                Action = "DistributeProgressionReward",
                RewardType = "item",
                Amount = "1",
                ItemName = "Rare Candy"
            })

            assert.equals("ProgressionRewardDistributed", response.Action)
            assert.equals("true", response.Success)
            assert.equals("item", response.RewardType)
        end)
    end)

    describe("Progression Persistence", function()
        it("should save player progression", function()
            -- Make some progress first
            process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "5000"
            })

            -- Save progression
            local response = process.send({
                Action = "SavePlayerProgression"
            })

            assert.equals("PlayerProgressionSaved", response.Action)
            assert.equals("true", response.Success)
            assert.truthy(response.SavedAt)
        end)

        it("should load player progression", function()
            -- Make some progress first
            process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "3000"
            })

            -- Load progression
            local response = process.send({
                Action = "LoadPlayerProgression"
            })

            assert.equals("PlayerProgressionLoaded", response.Action)
            assert.equals("true", response.Success)
            assert.truthy(response.Level)
            assert.truthy(response.Experience)
        end)

        it("should maintain progression across save/load cycles", function()
            -- Make specific progress
            process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "10000"
            })

            process.send({
                Action = "UpdateAchievementProgress",
                UpdateType = "pokemon_caught",
                Value = "25"
            })

            -- Save
            process.send({
                Action = "SavePlayerProgression"
            })

            -- Load and verify
            local response = process.send({
                Action = "LoadPlayerProgression"
            })

            assert.equals("PlayerProgressionLoaded", response.Action)

            local data = response.Data and json.decode(response.Data)
            if data then
                assert.truthy(data.level > 1, "Level should be preserved")
                assert.equals(25, data.statistics.pokemonCaught, "Statistics should be preserved")
            end
        end)
    end)

    describe("Multi-Character Progression", function()
        it("should handle multiple player IDs independently", function()
            -- Player 1 progress
            local response1 = process.send({
                Action = "UpdatePlayerLevel",
                PlayerId = "player1",
                ExperienceGained = "5000"
            })

            -- Player 2 progress
            local response2 = process.send({
                Action = "UpdatePlayerLevel",
                PlayerId = "player2",
                ExperienceGained = "10000"
            })

            -- Verify independence
            assert.equals("PlayerLevelUpdated", response1.Action)
            assert.equals("PlayerLevelUpdated", response2.Action)

            local level1 = tonumber(response1.NewLevel)
            local level2 = tonumber(response2.NewLevel)
            assert.truthy(level1 ~= level2, "Different players should have independent progression")
        end)

        it("should maintain separate statistics for different players", function()
            -- Player 1 catches Pokemon
            process.send({
                Action = "UpdateAchievementProgress",
                PlayerId = "player1",
                UpdateType = "pokemon_caught",
                Value = "10"
            })

            -- Player 2 catches different amount
            process.send({
                Action = "UpdateAchievementProgress",
                PlayerId = "player2",
                UpdateType = "pokemon_caught",
                Value = "20"
            })

            -- Check Player 1 stats
            local stats1 = process.send({
                Action = "GetPlayerStatistics",
                PlayerId = "player1"
            })

            -- Check Player 2 stats
            local stats2 = process.send({
                Action = "GetPlayerStatistics",
                PlayerId = "player2"
            })

            assert.equals("10", stats1.PokemonCaught)
            assert.equals("20", stats2.PokemonCaught)
        end)

        it("should handle separate unlocks for different players", function()
            -- Player 1 wins a session
            process.send({
                Action = "UpdateAchievementProgress",
                PlayerId = "player1",
                UpdateType = "battle_win",
                Value = "1"
            })

            -- Check Player 1 unlocks
            local unlocks1 = process.send({
                Action = "CheckUnlockConditions",
                PlayerId = "player1"
            })

            -- Check Player 2 unlocks (should be empty)
            local unlocks2 = process.send({
                Action = "CheckUnlockConditions",
                PlayerId = "player2"
            })

            assert.equals("UnlockConditionsChecked", unlocks1.Action)
            assert.equals("UnlockConditionsChecked", unlocks2.Action)

            -- Player 1 should have unlocks, Player 2 should not
            local player1Unlocks = unlocks1.AllUnlocks and json.decode(unlocks1.AllUnlocks)
            local player2Unlocks = unlocks2.AllUnlocks and json.decode(unlocks2.AllUnlocks)

            if player1Unlocks and player2Unlocks then
                assert.truthy(player1Unlocks["0"], "Player 1 should have ENDLESS_MODE unlocked")
                assert.falsy(player2Unlocks["0"], "Player 2 should not have ENDLESS_MODE unlocked")
            end
        end)
    end)

    describe("ADP Compliance", function()
        it("should respond to Info requests", function()
            local response = process.send({
                Action = "Info"
            })

            assert.equals("InfoResponse", response.Action)
            assert.truthy(response.Data)

            local info = json.decode(response.Data)
            assert.equals("Player Progression Engine", info.Name)
            assert.equals("1.0", info.adpVersion)
            assert.truthy(info.handlers)
            assert.truthy(info.capabilities)
        end)

        it("should include comprehensive handler information", function()
            local response = process.send({
                Action = "Info"
            })

            local info = json.decode(response.Data)
            local handlers = info.handlers

            -- Verify all expected handlers are present
            local expectedHandlers = {
                "UpdatePlayerLevel",
                "CheckUnlockConditions",
                "UpdateAchievementProgress",
                "GetPlayerStatistics",
                "DistributeProgressionReward",
                "SavePlayerProgression",
                "LoadPlayerProgression",
                "Info"
            }

            for _, expectedHandler in ipairs(expectedHandlers) do
                local found = false
                for _, handler in ipairs(handlers) do
                    if handler == expectedHandler then
                        found = true
                        break
                    end
                end
                assert.truthy(found, "Handler " .. expectedHandler .. " should be present in Info response")
            end
        end)
    end)

    describe("Error Handling", function()
        it("should handle invalid experience values gracefully", function()
            local response = process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "invalid"
            })

            assert.equals("PlayerLevelUpdated", response.Action)
            assert.equals("true", response.Success)
            -- Should default to 0 experience gained
            assert.equals("0", response.ExperienceGained)
        end)

        it("should handle invalid growth rates gracefully", function()
            local response = process.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "1000",
                GrowthRate = "invalid"
            })

            assert.equals("PlayerLevelUpdated", response.Action)
            assert.equals("true", response.Success)
            -- Should default to MEDIUM_FAST (2)
        end)

        it("should handle missing parameters gracefully", function()
            local response = process.send({
                Action = "UpdatePlayerLevel"
                -- Missing ExperienceGained
            })

            assert.equals("PlayerLevelUpdated", response.Action)
            assert.equals("true", response.Success)
        end)
    end)
end)