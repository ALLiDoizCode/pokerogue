-- Friendship Engine Integration Tests
-- Tests cross-process friendship integration with evolution and battle systems
-- Uses aos-local testing framework for multi-process message flows

local aosLocal = require('aos-local')

-- Load processes
local friendshipEngineCode = aosLocal.loadFileAndProcess('../processes/friendship-engine.lua')
local evolutionEngineCode = aosLocal.loadFileAndProcess('../processes/evolution-engine.lua')

describe("Friendship Engine Integration", function()
    local friendshipProcessId, evolutionProcessId

    before_each(function()
        -- Initialize aos-local environment
        aosLocal.init()

        -- Spawn friendship and evolution processes
        friendshipProcessId = aosLocal.spawnProcess(friendshipEngineCode, "friendship-engine")
        evolutionProcessId = aosLocal.spawnProcess(evolutionEngineCode, "evolution-engine")
    end)

    after_each(function()
        -- Clean up processes
        if friendshipProcessId then
            aosLocal.killProcess(friendshipProcessId)
        end
        if evolutionProcessId then
            aosLocal.killProcess(evolutionProcessId)
        end
        aosLocal.cleanup()
    end)

    describe("Friendship-Evolution Integration Workflow", function()
        it("should complete full friendship evolution workflow for Eevee to Espeon", function()
            -- Initial Eevee state with low friendship
            local initialGameState = {
                pokemon = {
                    speciesId = 133, -- Eevee
                    friendship = 50,
                    level = 25,
                    stats = {hp = 80, attack = 55, defense = 50, specialAttack = 45, specialDefense = 65, speed = 55},
                    ivs = {31, 31, 31, 31, 31, 31},
                    nature = "modest",
                    moveset = {
                        {name = "Tackle", type = "normal"},
                        {name = "Swift", type = "normal"},
                        {name = "Sand Attack", type = "ground"},
                        {name = "Baby-Doll Eyes", type = "fairy"}
                    }
                },
                battleSeed = "integration_test_seed"
            }

            -- Step 1: Multiple battle victories to increase friendship
            local battleCount = 0
            local currentGameState = initialGameState

            repeat
                battleCount = battleCount + 1

                -- Send battle victory action to friendship engine
                local friendshipResponse = aosLocal.send(friendshipProcessId, {
                    Action = "CalculateFriendship",
                    Data = {
                        pokemon = currentGameState.pokemon,
                        parameters = {
                            friendshipAction = "battleVictory",
                            actionContext = "trainer"
                        },
                        battleSeed = currentGameState.battleSeed
                    },
                    From = "test-trainer"
                })

                assert.are.equal("SaveState", friendshipResponse.Action, "Battle " .. battleCount .. " friendship calculation should succeed")

                -- Update game state with new friendship
                local friendshipData = friendshipResponse.Data
                currentGameState.pokemon.friendship = friendshipData.newFriendship

                print("Battle " .. battleCount .. ": Friendship = " .. friendshipData.newFriendship .. " (" .. friendshipData.friendshipLevel .. ")")

            until currentGameState.pokemon.friendship >= 220 or battleCount > 100 -- Safety limit

            assert.is_true(battleCount <= 100, "Should reach evolution friendship within reasonable number of battles")
            assert.is_true(currentGameState.pokemon.friendship >= 220, "Should reach friendship evolution threshold")

            -- Step 2: Check if Espeon evolution is possible (day time)
            local evolutionCheckResponse = aosLocal.send(friendshipProcessId, {
                Action = "CheckFriendshipEvolution",
                Data = {
                    pokemon = currentGameState.pokemon,
                    parameters = {
                        requiredFriendship = 220,
                        timeOfDay = "day",
                        specialRequirements = {
                            timeOfDay = "day"
                        }
                    },
                    battleSeed = currentGameState.battleSeed
                },
                From = "test-trainer"
            })

            assert.are.equal("SaveState", evolutionCheckResponse.Action)
            assert.are.equal("true", evolutionCheckResponse.CanEvolve)

            -- Step 3: Process evolution through evolution engine
            local evolutionTriggerResponse = aosLocal.send(evolutionProcessId, {
                Action = "CheckEvolutionTriggers",
                Data = {
                    pokemon = currentGameState.pokemon,
                    trigger = "level",
                    levelUp = false, -- Not a level-up evolution
                    context = {
                        friendshipEvolution = true,
                        timeOfDay = "day"
                    }
                },
                From = "test-trainer"
            })

            assert.are.equal("SaveState", evolutionTriggerResponse.Action)

            local evolutionData = evolutionTriggerResponse.Data
            if evolutionData.canEvolve then
                -- Process the actual evolution
                local processEvolutionResponse = aosLocal.send(evolutionProcessId, {
                    Action = "ProcessEvolution",
                    Data = {
                        pokemon = currentGameState.pokemon,
                        evolutionTarget = 196, -- Espeon
                        evolutionType = "friendship",
                        preserveStats = true
                    },
                    From = "test-trainer"
                })

                assert.are.equal("SaveState", processEvolutionResponse.Action)

                local evolvedData = processEvolutionResponse.Data
                assert.are.equal(196, evolvedData.pokemon.speciesId) -- Should be Espeon
                assert.is_true(evolvedData.pokemon.friendship >= 220) -- Friendship should be preserved

                print("Evolution successful: Eevee -> Espeon (Friendship: " .. evolvedData.pokemon.friendship .. ")")
            end
        end)

        it("should handle Umbreon evolution (night time)", function()
            local gameState = {
                pokemon = {
                    speciesId = 133, -- Eevee
                    friendship = 230, -- Already high friendship
                    level = 25,
                    moveset = {
                        {name = "Tackle", type = "normal"},
                        {name = "Swift", type = "normal"}
                    }
                },
                battleSeed = "night_evolution_test"
            }

            -- Check night time evolution
            local evolutionCheckResponse = aosLocal.send(friendshipProcessId, {
                Action = "CheckFriendshipEvolution",
                Data = {
                    pokemon = gameState.pokemon,
                    parameters = {
                        timeOfDay = "night",
                        specialRequirements = {
                            timeOfDay = "night"
                        }
                    }
                },
                From = "test-trainer"
            })

            assert.are.equal("SaveState", evolutionCheckResponse.Action)
            assert.are.equal("true", evolutionCheckResponse.CanEvolve)

            local evolutionData = evolutionCheckResponse.Data
            assert.are.equal("Evolution conditions met", evolutionData.reason)
        end)

        it("should handle Sylveon evolution (fairy move requirement)", function()
            local gameState = {
                pokemon = {
                    speciesId = 133, -- Eevee
                    friendship = 230,
                    level = 25,
                    moveset = {
                        {name = "Tackle", type = "normal"},
                        {name = "Baby-Doll Eyes", type = "fairy"}, -- Has fairy move
                        {name = "Swift", type = "normal"}
                    }
                },
                battleSeed = "sylveon_evolution_test"
            }

            -- Check Sylveon evolution requirements
            local evolutionCheckResponse = aosLocal.send(friendshipProcessId, {
                Action = "CheckFriendshipEvolution",
                Data = {
                    pokemon = gameState.pokemon,
                    parameters = {
                        specialRequirements = {
                            fairyMove = true
                        }
                    }
                },
                From = "test-trainer"
            })

            assert.are.equal("SaveState", evolutionCheckResponse.Action)
            assert.are.equal("true", evolutionCheckResponse.CanEvolve)

            -- Verify it fails without fairy move
            gameState.pokemon.moveset = {
                {name = "Tackle", type = "normal"},
                {name = "Swift", type = "normal"} -- No fairy move
            }

            local noFairyResponse = aosLocal.send(friendshipProcessId, {
                Action = "CheckFriendshipEvolution",
                Data = {
                    pokemon = gameState.pokemon,
                    parameters = {
                        specialRequirements = {
                            fairyMove = true
                        }
                    }
                },
                From = "test-trainer"
            })

            assert.are.equal("false", noFairyResponse.CanEvolve)
            assert.are.equal("No Fairy-type move known", noFairyResponse.Reason)
        end)
    end)

    describe("Battle System Integration", function()
        it("should integrate with battle outcomes for friendship changes", function()
            local gameState = {
                pokemon = {
                    speciesId = 25, -- Pikachu
                    friendship = 100,
                    level = 25,
                    hp = 100,
                    stats = {hp = 100, attack = 55, defense = 40, specialAttack = 50, specialDefense = 50, speed = 90}
                },
                battleSeed = "battle_integration_test"
            }

            -- Simulate battle victory
            local battleVictoryResponse = aosLocal.send(friendshipProcessId, {
                Action = "CalculateFriendship",
                Data = {
                    pokemon = gameState.pokemon,
                    parameters = {
                        friendshipAction = "battleVictory",
                        actionContext = "gym" -- Gym battle
                    }
                },
                From = "battle-system"
            })

            assert.are.equal("SaveState", battleVictoryResponse.Action)
            assert.are.equal("3", battleVictoryResponse.FriendshipChange) -- Base gain
            assert.are.equal("103", battleVictoryResponse.NewFriendship)

            -- Update state and simulate fainting
            gameState.pokemon.friendship = 103

            local faintResponse = aosLocal.send(friendshipProcessId, {
                Action = "CalculateFriendship",
                Data = {
                    pokemon = gameState.pokemon,
                    parameters = {
                        friendshipAction = "faint"
                    }
                },
                From = "battle-system"
            })

            assert.are.equal("SaveState", faintResponse.Action)
            assert.are.equal("-5", faintResponse.FriendshipChange) -- Friendship loss
            assert.are.equal("98", faintResponse.NewFriendship)
        end)

        it("should integrate with item usage scenarios", function()
            local gameState = {
                pokemon = {
                    speciesId = 25, -- Pikachu
                    friendship = 180,
                    heldItem = "soothe_bell"
                },
                battleSeed = "item_integration_test"
            }

            -- Use rare candy with Soothe Bell
            local rareCandyResponse = aosLocal.send(friendshipProcessId, {
                Action = "CalculateFriendship",
                Data = {
                    pokemon = gameState.pokemon,
                    parameters = {
                        friendshipAction = "rareCandy"
                    }
                },
                From = "item-system"
            })

            assert.are.equal("SaveState", rareCandyResponse.Action)

            -- Should apply Soothe Bell bonus: floor(6 * 1.5) = 9
            assert.are.equal("9", rareCandyResponse.FriendshipChange)
            assert.are.equal("189", rareCandyResponse.NewFriendship)

            -- Verify rare candy cap is respected
            gameState.pokemon.friendship = 195

            local cappedCandyResponse = aosLocal.send(friendshipProcessId, {
                Action = "CalculateFriendship",
                Data = {
                    pokemon = gameState.pokemon,
                    parameters = {
                        friendshipAction = "rareCandy"
                    }
                },
                From = "item-system"
            })

            assert.are.equal("SaveState", cappedCandyResponse.Action)
            -- Should be capped at 200, not 195 + 9 = 204
            assert.are.equal("200", cappedCandyResponse.NewFriendship)
        end)
    end)

    describe("Move System Integration", function()
        it("should integrate with battle damage calculation for Return/Frustration", function()
            local highFriendshipState = {
                pokemon = {
                    speciesId = 25, -- Pikachu
                    friendship = 255, -- Maximum friendship
                    level = 50,
                    stats = {attack = 90}
                },
                battleSeed = "move_integration_test"
            }

            -- Calculate Return move power
            local returnResponse = aosLocal.send(friendshipProcessId, {
                Action = "CalculateFriendshipMoveEffects",
                Data = highFriendshipState,
                From = "move-system"
            })

            assert.are.equal("SaveState", returnResponse.Action)
            assert.are.equal("102", returnResponse.ReturnPower) -- Max power for Return
            assert.are.equal("1", returnResponse.FrustrationPower) -- Min power for Frustration

            -- Test with low friendship Pokemon
            local lowFriendshipState = {
                pokemon = {
                    speciesId = 25,
                    friendship = 0, -- Minimum friendship
                    level = 50,
                    stats = {attack = 90}
                },
                battleSeed = "move_integration_test_low"
            }

            local frustrationResponse = aosLocal.send(friendshipProcessId, {
                Action = "CalculateFriendshipMoveEffects",
                Data = lowFriendshipState,
                From = "move-system"
            })

            assert.are.equal("SaveState", frustrationResponse.Action)
            assert.are.equal("1", frustrationResponse.ReturnPower) -- Min power for Return
            assert.are.equal("102", frustrationResponse.FrustrationPower) -- Max power for Frustration
        end)

        it("should handle dynamic friendship changes affecting move power", function()
            local gameState = {
                pokemon = {
                    speciesId = 25,
                    friendship = 128, -- Mid-range friendship
                    level = 50
                }
            }

            -- Get initial move powers
            local initialResponse = aosLocal.send(friendshipProcessId, {
                Action = "CalculateFriendshipMoveEffects",
                Data = gameState,
                From = "move-system"
            })

            local initialReturnPower = tonumber(initialResponse.ReturnPower)
            local initialFrustrationPower = tonumber(initialResponse.FrustrationPower)

            -- Increase friendship through battle
            local battleResponse = aosLocal.send(friendshipProcessId, {
                Action = "CalculateFriendship",
                Data = {
                    pokemon = gameState.pokemon,
                    parameters = {
                        friendshipAction = "battleVictory"
                    }
                },
                From = "battle-system"
            })

            -- Update friendship and recalculate move powers
            gameState.pokemon.friendship = battleResponse.Data.newFriendship

            local updatedResponse = aosLocal.send(friendshipProcessId, {
                Action = "CalculateFriendshipMoveEffects",
                Data = gameState,
                From = "move-system"
            })

            local updatedReturnPower = tonumber(updatedResponse.ReturnPower)
            local updatedFrustrationPower = tonumber(updatedResponse.FrustrationPower)

            -- Return power should increase, Frustration power should decrease
            assert.is_true(updatedReturnPower > initialReturnPower, "Return power should increase with friendship")
            assert.is_true(updatedFrustrationPower < initialFrustrationPower, "Frustration power should decrease with friendship")
        end)
    end)

    describe("State Persistence Integration", function()
        it("should maintain friendship values across multiple process interactions", function()
            local gameState = {
                pokemon = {
                    speciesId = 133, -- Eevee
                    friendship = 50,
                    level = 20
                },
                battleSeed = "persistence_test"
            }

            -- Series of friendship-affecting actions
            local actions = {
                {action = "battleVictory", context = "wild", expectedChange = 3},
                {action = "battleVictory", context = "trainer", expectedChange = 3},
                {action = "rareCandy", context = nil, expectedChange = 6},
                {action = "battleVictory", context = "gym", expectedChange = 3}
            }

            local expectedFriendship = 50 -- Starting friendship

            for i, actionData in ipairs(actions) do
                local response = aosLocal.send(friendshipProcessId, {
                    Action = "CalculateFriendship",
                    Data = {
                        pokemon = gameState.pokemon,
                        parameters = {
                            friendshipAction = actionData.action,
                            actionContext = actionData.context
                        }
                    },
                    From = "persistence-test-" .. i
                })

                assert.are.equal("SaveState", response.Action, "Action " .. i .. " should succeed")

                expectedFriendship = expectedFriendship + actionData.expectedChange
                assert.are.equal(tostring(expectedFriendship), response.NewFriendship,
                    "Action " .. i .. " should result in correct friendship value")

                -- Update game state for next action
                gameState.pokemon.friendship = response.Data.newFriendship

                print("After action " .. i .. " (" .. actionData.action .. "): Friendship = " .. response.NewFriendship)
            end

            -- Final verification - get status
            local statusResponse = aosLocal.send(friendshipProcessId, {
                Action = "GetFriendshipStatus",
                Data = gameState,
                From = "persistence-verification"
            })

            assert.are.equal("SaveState", statusResponse.Action)
            assert.are.equal(tostring(expectedFriendship), statusResponse.CurrentFriendship)

            -- Should be in "high" range (150-199)
            assert.are.equal("normal", statusResponse.FriendshipLevel) -- 65 is in normal range (50-149)
        end)
    end)

    describe("Error Handling Integration", function()
        it("should gracefully handle process communication errors", function()
            -- Test with invalid process ID
            local invalidResponse = aosLocal.send("invalid-process-id", {
                Action = "CalculateFriendship",
                Data = {
                    pokemon = {speciesId = 25, friendship = 100},
                    parameters = {friendshipAction = "battleVictory"}
                },
                From = "error-test"
            })

            -- Should handle gracefully (aosLocal might return nil or error response)
            if invalidResponse then
                assert.are.equal("Error", invalidResponse.Action)
            end
        end)

        it("should maintain consistency during error conditions", function()
            local gameState = {
                pokemon = {
                    speciesId = 25,
                    friendship = 100
                }
            }

            -- Send invalid request
            local invalidResponse = aosLocal.send(friendshipProcessId, {
                Action = "CalculateFriendship",
                Data = {
                    pokemon = gameState.pokemon,
                    parameters = {
                        friendshipAction = "invalidAction"
                    }
                },
                From = "error-consistency-test"
            })

            assert.are.equal("Error", invalidResponse.Action)

            -- Verify state remains unchanged - send valid request
            local validResponse = aosLocal.send(friendshipProcessId, {
                Action = "GetFriendshipStatus",
                Data = gameState,
                From = "error-consistency-test"
            })

            assert.are.equal("SaveState", validResponse.Action)
            assert.are.equal("100", validResponse.CurrentFriendship) -- Should be unchanged
        end)
    end)

    describe("Performance Integration", function()
        it("should handle concurrent requests across multiple processes", function()
            local testStates = {}
            local responses = {}

            -- Create multiple test states
            for i = 1, 10 do
                testStates[i] = {
                    pokemon = {
                        speciesId = 25,
                        friendship = 50 + i * 10 -- Varying friendship levels
                    }
                }
            end

            local startTime = os.clock()

            -- Send concurrent requests
            for i = 1, 10 do
                responses[i] = aosLocal.send(friendshipProcessId, {
                    Action = "GetFriendshipStatus",
                    Data = testStates[i],
                    From = "concurrent-test-" .. i
                })
            end

            local endTime = os.clock()
            local totalTime = (endTime - startTime) * 1000 -- Convert to ms

            -- Verify all responses succeeded
            for i = 1, 10 do
                assert.are.equal("SaveState", responses[i].Action, "Concurrent request " .. i .. " should succeed")
            end

            -- Performance check - should handle 10 requests quickly
            assert.is_true(totalTime < 500, "10 concurrent requests should complete in under 500ms, took " .. totalTime .. "ms")

            print("Concurrent performance: " .. totalTime .. "ms for 10 requests")
        end)
    end)
end)