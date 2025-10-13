-- Player Progression Engine Integration Tests
-- Tests player progression system integration with other processes and workflows

local aolite = require("aolite")

describe("Player Progression Integration", function()
    local progressionProcess, coordinatorProcess

    before_each(function()
        -- Load player progression engine
        local progressionCode = io.open("processes/player-progression-engine.lua", "r"):read("*all")
        progressionProcess = aolite.spawn({
            name = "test-player-progression",
            src = progressionCode
        })

        -- Mock coordinator process for integration testing
        local coordinatorCode = [[
            local json = require("json")

            -- Mock game state
            if not GameState then
                GameState = {
                    player = {
                        progression = {
                            level = 1,
                            experience = 0
                        }
                    }
                }
            end

            -- Handler to coordinate with progression engine
            Handlers.add("coordinate-progression",
                Handlers.utils.hasMatchingTag("Action", "CoordinateProgression"),
                function(msg)
                    local progressionResult = msg.ProgressionResult
                    if progressionResult then
                        local data = json.decode(progressionResult)
                        if data and data.levelChange then
                            GameState.player.progression.level = data.levelChange.newLevel
                            GameState.player.progression.experience = data.levelChange.totalExperience
                        end
                    end

                    ao.send({
                        Target = msg.From,
                        Action = "ProgressionCoordinated",
                        Success = "true",
                        Data = json.encode(GameState.player.progression)
                    })
                end
            )

            -- Handler to trigger progression updates
            Handlers.add("battle-complete",
                Handlers.utils.hasMatchingTag("Action", "BattleComplete"),
                function(msg)
                    ao.send({
                        Target = msg.From,
                        Action = "BattleCompleteProcessed",
                        Success = "true",
                        ExperienceGained = msg.ExperienceGained or "0"
                    })
                end
            )

            Handlers.add("info",
                Handlers.utils.hasMatchingTag("Action", "Info"),
                function(msg)
                    ao.send({
                        Target = msg.From,
                        Action = "InfoResponse",
                        Data = json.encode({
                            Name = "Mock Coordinator",
                            Description = "Mock coordinator for testing"
                        })
                    })
                end
            )
        ]]

        coordinatorProcess = aolite.spawn({
            name = "test-coordinator",
            src = coordinatorCode
        })
    end)

    describe("Cross-Process Communication", function()
        it("should communicate with coordinator process", function()
            -- Test basic communication
            local response = progressionProcess.send({
                Action = "Info"
            })

            assert.equals("InfoResponse", response.Action)

            local coordResponse = coordinatorProcess.send({
                Action = "Info"
            })

            assert.equals("InfoResponse", coordResponse.Action)
        end)

        it("should handle progression updates from battle completion", function()
            -- Simulate battle completion with experience gain
            local battleResult = coordinatorProcess.send({
                Action = "BattleComplete",
                ExperienceGained = "1500"
            })

            assert.equals("BattleCompleteProcessed", battleResult.Action)
            assert.equals("1500", battleResult.ExperienceGained)

            -- Now update progression based on battle result
            local progressionUpdate = progressionProcess.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = battleResult.ExperienceGained
            })

            assert.equals("PlayerLevelUpdated", progressionUpdate.Action)
            assert.equals("true", progressionUpdate.Success)
        end)

        it("should coordinate progression changes with game state", function()
            -- Make progression change
            local progressionResult = progressionProcess.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "3000"
            })

            assert.equals("PlayerLevelUpdated", progressionResult.Action)

            -- Coordinate with coordinator process
            local coordResult = coordinatorProcess.send({
                Action = "CoordinateProgression",
                ProgressionResult = progressionResult.Data
            })

            assert.equals("ProgressionCoordinated", coordResult.Action)
            assert.equals("true", coordResult.Success)

            local gameState = json.decode(coordResult.Data)
            assert.truthy(gameState.level > 1, "Game state should reflect level progression")
        end)
    end)

    describe("Complete Battle-to-Progression Workflow", function()
        it("should handle complete battle victory workflow", function()
            -- Step 1: Battle completion
            local battleResult = coordinatorProcess.send({
                Action = "BattleComplete",
                ExperienceGained = "2500"
            })

            assert.equals("BattleCompleteProcessed", battleResult.Action)

            -- Step 2: Update player level
            local levelUpdate = progressionProcess.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = battleResult.ExperienceGained
            })

            assert.equals("PlayerLevelUpdated", levelUpdate.Action)

            -- Step 3: Update battle statistics
            local statsUpdate = progressionProcess.send({
                Action = "UpdateAchievementProgress",
                UpdateType = "battle_win",
                Value = "1"
            })

            assert.equals("AchievementProgressUpdated", statsUpdate.Action)

            -- Step 4: Check for unlocks
            local unlockCheck = progressionProcess.send({
                Action = "CheckUnlockConditions"
            })

            assert.equals("UnlockConditionsChecked", unlockCheck.Action)

            -- Step 5: Coordinate final state
            local finalCoord = coordinatorProcess.send({
                Action = "CoordinateProgression",
                ProgressionResult = levelUpdate.Data
            })

            assert.equals("ProgressionCoordinated", finalCoord.Action)

            -- Verify complete workflow success
            local finalStats = progressionProcess.send({
                Action = "GetPlayerStatistics"
            })

            assert.equals("PlayerStatisticsRetrieved", finalStats.Action)
            assert.equals("1", finalStats.SessionsWon)
            assert.equals("1", finalStats.Battles)
        end)

        it("should handle multiple battles with cumulative progression", function()
            local totalExperience = 0
            local totalBattles = 5

            for battle = 1, totalBattles do
                local experienceGain = 800 + (battle * 100) -- Increasing experience

                -- Battle completion
                local battleResult = coordinatorProcess.send({
                    Action = "BattleComplete",
                    ExperienceGained = tostring(experienceGain)
                })

                -- Level update
                local levelUpdate = progressionProcess.send({
                    Action = "UpdatePlayerLevel",
                    ExperienceGained = tostring(experienceGain)
                })

                -- Battle statistics
                progressionProcess.send({
                    Action = "UpdateAchievementProgress",
                    UpdateType = "battle_win",
                    Value = "1"
                })

                totalExperience = totalExperience + experienceGain
            end

            -- Check final state
            local finalStats = progressionProcess.send({
                Action = "GetPlayerStatistics"
            })

            assert.equals(tostring(totalBattles), finalStats.SessionsWon)
            assert.equals(tostring(totalBattles), finalStats.Battles)

            -- Verify level progression
            local progressionLoad = progressionProcess.send({
                Action = "LoadPlayerProgression"
            })

            assert.equals("PlayerProgressionLoaded", progressionLoad.Action)
            local finalLevel = tonumber(progressionLoad.Level)
            assert.truthy(finalLevel > 1, "Should have gained levels from multiple battles")
        end)
    end)

    describe("Achievement-Unlock Integration", function()
        it("should award achievements and trigger unlocks in sequence", function()
            -- Catch Pokemon to trigger catch achievements
            for i = 1, 12 do
                progressionProcess.send({
                    Action = "UpdateAchievementProgress",
                    UpdateType = "pokemon_caught",
                    Value = "1"
                })
            end

            -- Win battles to trigger battle achievements and unlocks
            for i = 1, 3 do
                progressionProcess.send({
                    Action = "UpdateAchievementProgress",
                    UpdateType = "battle_win",
                    Value = "1"
                })
            end

            -- Check achievements and unlocks
            local unlockCheck = progressionProcess.send({
                Action = "CheckUnlockConditions"
            })

            assert.equals("UnlockConditionsChecked", unlockCheck.Action)

            -- Verify statistics reflect all actions
            local stats = progressionProcess.send({
                Action = "GetPlayerStatistics"
            })

            assert.equals("12", stats.PokemonCaught)
            assert.equals("3", stats.SessionsWon)
        end)

        it("should handle progression milestone rewards", function()
            -- Reach a progression milestone (level 10)
            progressionProcess.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "1000" -- Should reach level 10
            })

            -- Distribute milestone reward
            local rewardResult = progressionProcess.send({
                Action = "DistributeProgressionReward",
                RewardType = "experience",
                Amount = "500" -- Bonus experience for milestone
            })

            assert.equals("ProgressionRewardDistributed", rewardResult.Action)
            assert.equals("experience", rewardResult.RewardType)

            -- Check that reward was applied
            local finalProgression = progressionProcess.send({
                Action = "LoadPlayerProgression"
            })

            assert.equals("PlayerProgressionLoaded", finalProgression.Action)
            local totalExp = tonumber(finalProgression.Experience)
            assert.truthy(totalExp >= 1500, "Should include milestone reward experience")
        end)
    end)

    describe("Multi-Character Integration", function()
        it("should handle multi-character progression workflows", function()
            local players = {"player1", "player2", "player3"}

            -- Each player makes different progress
            for i, playerId in ipairs(players) do
                local experienceAmount = 1000 * i -- Different amounts for each

                -- Level progression
                progressionProcess.send({
                    Action = "UpdatePlayerLevel",
                    PlayerId = playerId,
                    ExperienceGained = tostring(experienceAmount)
                })

                -- Battle statistics
                for battle = 1, i do
                    progressionProcess.send({
                        Action = "UpdateAchievementProgress",
                        PlayerId = playerId,
                        UpdateType = "battle_win",
                        Value = "1"
                    })
                end

                -- Pokemon catching
                for catch = 1, i * 5 do
                    progressionProcess.send({
                        Action = "UpdateAchievementProgress",
                        PlayerId = playerId,
                        UpdateType = "pokemon_caught",
                        Value = "1"
                    })
                end
            end

            -- Verify each player has independent progression
            for i, playerId in ipairs(players) do
                local stats = progressionProcess.send({
                    Action = "GetPlayerStatistics",
                    PlayerId = playerId
                })

                assert.equals("PlayerStatisticsRetrieved", stats.Action)
                assert.equals(tostring(i), stats.SessionsWon)
                assert.equals(tostring(i * 5), stats.PokemonCaught)

                local progression = progressionProcess.send({
                    Action = "LoadPlayerProgression",
                    PlayerId = playerId
                })

                assert.equals("PlayerProgressionLoaded", progression.Action)
                local level = tonumber(progression.Level)
                assert.truthy(level > 1, "Player " .. playerId .. " should have leveled up")
            end
        end)

        it("should handle character-specific unlock sequences", function()
            -- Player 1: Focus on levels for MINI_BLACK_HOLE unlock
            progressionProcess.send({
                Action = "UpdatePlayerLevel",
                PlayerId = "player1",
                ExperienceGained = "125000" -- Should reach level 50+
            })

            -- Player 2: Focus on catching for EVIOLITE unlock
            for i = 1, 105 do
                progressionProcess.send({
                    Action = "UpdateAchievementProgress",
                    PlayerId = "player2",
                    UpdateType = "pokemon_caught",
                    Value = "1"
                })
            end

            -- Player 3: Focus on battles for ENDLESS_MODE unlock
            progressionProcess.send({
                Action = "UpdateAchievementProgress",
                PlayerId = "player3",
                UpdateType = "battle_win",
                Value = "1"
            })

            -- Check unlocks for each player
            local unlocks1 = progressionProcess.send({
                Action = "CheckUnlockConditions",
                PlayerId = "player1"
            })

            local unlocks2 = progressionProcess.send({
                Action = "CheckUnlockConditions",
                PlayerId = "player2"
            })

            local unlocks3 = progressionProcess.send({
                Action = "CheckUnlockConditions",
                PlayerId = "player3"
            })

            assert.equals("UnlockConditionsChecked", unlocks1.Action)
            assert.equals("UnlockConditionsChecked", unlocks2.Action)
            assert.equals("UnlockConditionsChecked", unlocks3.Action)

            -- Each player should have different unlocks based on their progression
            local player1Unlocks = unlocks1.AllUnlocks and json.decode(unlocks1.AllUnlocks)
            local player2Unlocks = unlocks2.AllUnlocks and json.decode(unlocks2.AllUnlocks)
            local player3Unlocks = unlocks3.AllUnlocks and json.decode(unlocks3.AllUnlocks)

            if player1Unlocks then
                assert.truthy(player1Unlocks["1"], "Player 1 should unlock MINI_BLACK_HOLE")
            end

            if player2Unlocks then
                assert.truthy(player2Unlocks["3"], "Player 2 should unlock EVIOLITE")
            end

            if player3Unlocks then
                assert.truthy(player3Unlocks["0"], "Player 3 should unlock ENDLESS_MODE")
            end
        end)
    end)

    describe("Persistence and State Management", function()
        it("should maintain state across multiple operations", function()
            local playerId = "integration-test-player"

            -- Sequence of operations
            local operations = {
                {action = "UpdatePlayerLevel", params = {ExperienceGained = "2000"}},
                {action = "UpdateAchievementProgress", params = {UpdateType = "pokemon_caught", Value = "15"}},
                {action = "UpdateAchievementProgress", params = {UpdateType = "battle_win", Value = "1"}},
                {action = "DistributeProgressionReward", params = {RewardType = "experience", Amount = "1000"}},
                {action = "UpdateAchievementProgress", params = {UpdateType = "damage_dealt", Value = "1500"}}
            }

            -- Execute all operations
            for _, op in ipairs(operations) do
                op.params.PlayerId = playerId
                op.params.Action = op.action

                local response = progressionProcess.send(op.params)
                assert.truthy(response, "Operation " .. op.action .. " should succeed")
                assert.equals("true", response.Success)
            end

            -- Save state
            local saveResult = progressionProcess.send({
                Action = "SavePlayerProgression",
                PlayerId = playerId
            })

            assert.equals("PlayerProgressionSaved", saveResult.Action)

            -- Load and verify complete state
            local loadResult = progressionProcess.send({
                Action = "LoadPlayerProgression",
                PlayerId = playerId
            })

            assert.equals("PlayerProgressionLoaded", loadResult.Action)

            local progression = json.decode(loadResult.Data)
            assert.truthy(progression.level > 1, "Should have level progression")
            assert.equals(15, progression.statistics.pokemonCaught, "Should track Pokemon caught")
            assert.equals(1, progression.statistics.sessionsWon, "Should track battle wins")
            assert.equals(1500, progression.statistics.highestDamage, "Should track highest damage")
        end)

        it("should handle concurrent multi-character operations", function()
            local players = {"concurrent1", "concurrent2", "concurrent3"}

            -- Simulate concurrent operations
            for round = 1, 3 do
                for _, playerId in ipairs(players) do
                    -- Level up
                    progressionProcess.send({
                        Action = "UpdatePlayerLevel",
                        PlayerId = playerId,
                        ExperienceGained = tostring(1000 * round)
                    })

                    -- Catch Pokemon
                    progressionProcess.send({
                        Action = "UpdateAchievementProgress",
                        PlayerId = playerId,
                        UpdateType = "pokemon_caught",
                        Value = tostring(round)
                    })

                    -- Save each player's state
                    progressionProcess.send({
                        Action = "SavePlayerProgression",
                        PlayerId = playerId
                    })
                end
            end

            -- Verify all players maintained independent state
            for _, playerId in ipairs(players) do
                local progression = progressionProcess.send({
                    Action = "LoadPlayerProgression",
                    PlayerId = playerId
                })

                assert.equals("PlayerProgressionLoaded", progression.Action)

                local stats = progressionProcess.send({
                    Action = "GetPlayerStatistics",
                    PlayerId = playerId
                })

                assert.equals("6", stats.PokemonCaught) -- 1+2+3 from 3 rounds
                local level = tonumber(progression.Level)
                assert.truthy(level > 1, "Player " .. playerId .. " should have leveled up")
            end
        end)
    end)

    describe("Error Recovery and Resilience", function()
        it("should handle process communication errors gracefully", function()
            -- Test with invalid parameters
            local response = progressionProcess.send({
                Action = "UpdatePlayerLevel",
                ExperienceGained = "invalid_number",
                GrowthRate = "invalid_rate"
            })

            -- Should not crash, should use defaults
            assert.equals("PlayerLevelUpdated", response.Action)
            assert.equals("true", response.Success)
        end)

        it("should maintain data integrity under stress", function()
            local playerId = "stress-test-player"
            local iterations = 10

            -- Rapid-fire operations
            for i = 1, iterations do
                progressionProcess.send({
                    Action = "UpdatePlayerLevel",
                    PlayerId = playerId,
                    ExperienceGained = "100"
                })

                progressionProcess.send({
                    Action = "UpdateAchievementProgress",
                    PlayerId = playerId,
                    UpdateType = "pokemon_caught",
                    Value = "1"
                })
            end

            -- Verify final state consistency
            local finalStats = progressionProcess.send({
                Action = "GetPlayerStatistics",
                PlayerId = playerId
            })

            assert.equals("PlayerStatisticsRetrieved", finalStats.Action)
            assert.equals(tostring(iterations), finalStats.PokemonCaught)

            local progression = progressionProcess.send({
                Action = "LoadPlayerProgression",
                PlayerId = playerId
            })

            local totalExp = tonumber(progression.Experience)
            assert.equals(iterations * 100, totalExp, "Experience should accumulate correctly")
        end)
    end)
end)