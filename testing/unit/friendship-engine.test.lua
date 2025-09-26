-- Friendship Engine Unit Tests
-- Tests for friendship calculation, evolution triggers, move effects, and status tracking
-- Uses aolite testing framework with AO process mocking

local aolite = require('aolite')

-- Load the friendship engine process
local friendshipEngineCode = aolite.loadFileAndProcess('../processes/friendship-engine.lua')

describe("Friendship Engine Process", function()
    local processId

    before_each(function()
        -- Spawn a new process for each test to ensure isolation
        processId = aolite.spawnProcess(friendshipEngineCode)
    end)

    after_each(function()
        -- Clean up process after each test
        if processId then
            aolite.killProcess(processId)
        end
    end)

    describe("Process Info Handler (ADP Compliance)", function()
        it("should respond to Info action with process metadata", function()
            local response = aolite.send(processId, {
                Action = "Info",
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)

            local data = response.Data
            assert.is.table(data.process)
            assert.are.equal("Friendship Engine", data.process.name)
            assert.are.equal("1.0", data.process.adpVersion)
            assert.is.table(data.process.capabilities)
            assert.is.table(data.handlers)

            -- Check required handlers are listed
            local capabilities = data.process.capabilities
            assert.contains(capabilities, "CalculateFriendship")
            assert.contains(capabilities, "CheckFriendshipEvolution")
            assert.contains(capabilities, "CalculateFriendshipMoveEffects")
            assert.contains(capabilities, "GetFriendshipStatus")
        end)
    end)

    describe("CalculateFriendship Handler", function()
        it("should calculate friendship gain from battle victory", function()
            local testData = {
                pokemon = {
                    speciesId = 25, -- Pikachu
                    friendship = 50
                },
                parameters = {
                    friendshipAction = "battleVictory",
                    actionContext = "wild"
                }
            }

            local response = aolite.send(processId, {
                Action = "CalculateFriendship",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)
            assert.are.equal("calculateFriendship", response.Operation)
            assert.are.equal("3", response.FriendshipChange) -- FRIENDSHIP_GAIN_FROM_BATTLE = 3
            assert.are.equal("53", response.NewFriendship) -- 50 + 3

            local data = response.Data
            assert.are.equal(3, data.friendshipChange)
            assert.are.equal(53, data.newFriendship)
            assert.are.equal("normal", data.friendshipLevel)
            assert.is.number(data.moveEffects.returnPower)
            assert.is.number(data.moveEffects.frustrationPower)
        end)

        it("should calculate friendship loss from fainting", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 100
                },
                parameters = {
                    friendshipAction = "faint"
                }
            }

            local response = aolite.send(processId, {
                Action = "CalculateFriendship",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)
            assert.are.equal("-5", response.FriendshipChange) -- FRIENDSHIP_LOSS_FROM_FAINT = -5
            assert.are.equal("95", response.NewFriendship) -- 100 - 5
        end)

        it("should apply Soothe Bell modifier to friendship gains", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 50,
                    heldItem = "soothe_bell"
                },
                parameters = {
                    friendshipAction = "battleVictory",
                    actionContext = "wild"
                }
            }

            local response = aolite.send(processId, {
                Action = "CalculateFriendship",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)
            -- Base 3 * 1.5 (soothe bell) = 4.5, floored to 4
            assert.are.equal("4", response.FriendshipChange)
            assert.are.equal("54", response.NewFriendship)
        end)

        it("should enforce rare candy friendship cap", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 198 -- Close to rare candy cap (200)
                },
                parameters = {
                    friendshipAction = "rareCandy"
                }
            }

            local response = aolite.send(processId, {
                Action = "CalculateFriendship",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)
            -- Should be capped at 200, not 198 + 6 = 204
            assert.are.equal("200", response.NewFriendship)
        end)

        it("should enforce absolute friendship bounds (0-255)", function()
            -- Test lower bound
            local testDataLow = {
                pokemon = {
                    speciesId = 25,
                    friendship = 2
                },
                parameters = {
                    friendshipAction = "faint" -- -5 change
                }
            }

            local responseLow = aolite.send(processId, {
                Action = "CalculateFriendship",
                Data = testDataLow,
                From = "test-sender"
            })

            assert.are.equal("0", responseLow.NewFriendship) -- Should be clamped to 0

            -- Test upper bound
            local testDataHigh = {
                pokemon = {
                    speciesId = 25,
                    friendship = 250
                },
                parameters = {
                    friendshipAction = "battleVictory" -- +3 change
                }
            }

            local responseHigh = aolite.send(processId, {
                Action = "CalculateFriendship",
                Data = testDataHigh,
                From = "test-sender"
            })

            assert.are.equal("253", responseHigh.NewFriendship) -- Should be normal, not clamped

            -- Test actual upper bound
            testDataHigh.pokemon.friendship = 254
            local responseMax = aolite.send(processId, {
                Action = "CalculateFriendship",
                Data = testDataHigh,
                From = "test-sender"
            })

            assert.are.equal("255", responseMax.NewFriendship) -- Should be clamped to 255
        end)

        it("should handle invalid pokemon data", function()
            local response = aolite.send(processId, {
                Action = "CalculateFriendship",
                Data = {
                    pokemon = nil
                },
                From = "test-sender"
            })

            assert.are.equal("Error", response.Action)
            assert.is.truthy(response.Error)
        end)

        it("should handle invalid friendship action", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 50
                },
                parameters = {
                    friendshipAction = "invalidAction"
                }
            }

            local response = aolite.send(processId, {
                Action = "CalculateFriendship",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("Error", response.Action)
            assert.is.truthy(response.Error)
            assert.matches("Unknown friendship action", response.Error)
        end)
    end)

    describe("CheckFriendshipEvolution Handler", function()
        it("should confirm evolution when friendship meets threshold", function()
            local testData = {
                pokemon = {
                    speciesId = 133, -- Eevee
                    friendship = 230 -- Above evolution threshold (220)
                },
                parameters = {
                    requiredFriendship = 220
                }
            }

            local response = aolite.send(processId, {
                Action = "CheckFriendshipEvolution",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)
            assert.are.equal("checkFriendshipEvolution", response.Operation)
            assert.are.equal("true", response.CanEvolve)
            assert.are.equal("Evolution conditions met", response.Reason)
            assert.are.equal("230", response.CurrentFriendship)

            local data = response.Data
            assert.is_true(data.canEvolve)
            assert.are.equal("very_high", data.friendshipLevel)
        end)

        it("should reject evolution when friendship is too low", function()
            local testData = {
                pokemon = {
                    speciesId = 133, -- Eevee
                    friendship = 180 -- Below evolution threshold (220)
                },
                parameters = {
                    requiredFriendship = 220
                }
            }

            local response = aolite.send(processId, {
                Action = "CheckFriendshipEvolution",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)
            assert.are.equal("false", response.CanEvolve)
            assert.are.equal("Friendship too low", response.Reason)
            assert.are.equal("180", response.CurrentFriendship)

            local data = response.Data
            assert.is_false(data.canEvolve)
        end)

        it("should check time of day requirements for Espeon/Umbreon", function()
            local testDataDay = {
                pokemon = {
                    speciesId = 133, -- Eevee
                    friendship = 230
                },
                parameters = {
                    timeOfDay = "day",
                    specialRequirements = {
                        timeOfDay = "day"
                    }
                }
            }

            local responseDay = aolite.send(processId, {
                Action = "CheckFriendshipEvolution",
                Data = testDataDay,
                From = "test-sender"
            })

            assert.are.equal("true", responseDay.CanEvolve)

            -- Test wrong time of day
            testDataDay.parameters.specialRequirements.timeOfDay = "night"
            local responseWrongTime = aolite.send(processId, {
                Action = "CheckFriendshipEvolution",
                Data = testDataDay,
                From = "test-sender"
            })

            assert.are.equal("false", responseWrongTime.CanEvolve)
            assert.are.equal("Wrong time of day", responseWrongTime.Reason)
        end)

        it("should check fairy move requirement for Sylveon", function()
            local testData = {
                pokemon = {
                    speciesId = 133, -- Eevee
                    friendship = 230,
                    moveset = {
                        {name = "Tackle", type = "normal"},
                        {name = "Baby-Doll Eyes", type = "fairy"}
                    }
                },
                parameters = {
                    specialRequirements = {
                        fairyMove = true
                    }
                }
            }

            local response = aolite.send(processId, {
                Action = "CheckFriendshipEvolution",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("true", response.CanEvolve)

            -- Test without fairy move
            testData.pokemon.moveset = {
                {name = "Tackle", type = "normal"},
                {name = "Sand Attack", type = "ground"}
            }

            local responseNoFairy = aolite.send(processId, {
                Action = "CheckFriendshipEvolution",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("false", responseNoFairy.CanEvolve)
            assert.are.equal("No Fairy-type move known", responseNoFairy.Reason)
        end)

        it("should use default evolution threshold when none provided", function()
            local testData = {
                pokemon = {
                    speciesId = 133, -- Eevee
                    friendship = 220 -- Exactly at default threshold
                },
                parameters = {} -- No specific threshold
            }

            local response = aolite.send(processId, {
                Action = "CheckFriendshipEvolution",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("true", response.CanEvolve)

            local data = response.Data
            assert.are.equal(220, data.evolutionRequirements.requiredFriendship)
        end)
    end)

    describe("CalculateFriendshipMoveEffects Handler", function()
        it("should calculate Return move power based on friendship", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 255 -- Maximum friendship
                }
            }

            local response = aolite.send(processId, {
                Action = "CalculateFriendshipMoveEffects",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)
            assert.are.equal("calculateFriendshipMoveEffects", response.Operation)

            -- TypeScript formula: Math.floor(255 / 2.5) = Math.floor(102) = 102
            assert.are.equal("102", response.ReturnPower)

            local data = response.Data
            assert.are.equal(102, data.moveEffects.returnPower)
        end)

        it("should calculate Frustration move power (inverse friendship)", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 0 -- Minimum friendship
                }
            }

            local response = aolite.send(processId, {
                Action = "CalculateFriendshipMoveEffects",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)

            -- TypeScript formula: Math.max(102 - Math.floor(0 / 2.5), 1) = Math.max(102 - 0, 1) = 102
            assert.are.equal("102", response.FrustrationPower)

            local data = response.Data
            assert.are.equal(102, data.moveEffects.frustrationPower)
        end)

        it("should calculate mid-range friendship move effects", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 128 -- Mid-range friendship
                }
            }

            local response = aolite.send(processId, {
                Action = "CalculateFriendshipMoveEffects",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)

            -- Return: Math.floor(128 / 2.5) = Math.floor(51.2) = 51
            assert.are.equal("51", response.ReturnPower)

            -- Frustration: Math.max(102 - 51, 1) = 51
            assert.are.equal("51", response.FrustrationPower)

            local data = response.Data
            assert.are.equal(51, data.moveEffects.returnPower)
            assert.are.equal(51, data.moveEffects.frustrationPower)
        end)

        it("should ensure minimum power of 1 for both moves", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 1 -- Very low friendship
                }
            }

            local response = aolite.send(processId, {
                Action = "CalculateFriendshipMoveEffects",
                Data = testData,
                From = "test-sender"
            })

            local data = response.Data
            assert.is_true(data.moveEffects.returnPower >= 1)
            assert.is_true(data.moveEffects.frustrationPower >= 1)
        end)
    end)

    describe("GetFriendshipStatus Handler", function()
        it("should return comprehensive friendship status information", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 180
                }
            }

            local response = aolite.send(processId, {
                Action = "GetFriendshipStatus",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("true", response.Success)
            assert.are.equal("getFriendshipStatus", response.Operation)
            assert.are.equal("180", response.CurrentFriendship)
            assert.are.equal("high", response.FriendshipLevel)
            assert.are.equal("false", response.CanEvolveByFriendship) -- 180 < 220
            assert.are.equal("40", response.ToEvolution) -- 220 - 180

            local data = response.Data
            assert.are.equal(180, data.currentFriendship)
            assert.are.equal("high", data.friendshipLevel)
            assert.is_false(data.canEvolveByFriendship)
            assert.are.equal(40, data.toEvolutionThreshold)
            assert.are.equal(220, data.thresholds.evolution)
            assert.are.equal(255, data.thresholds.maximum)
        end)

        it("should indicate evolution readiness for high friendship", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 240 -- Above evolution threshold
                }
            }

            local response = aolite.send(processId, {
                Action = "GetFriendshipStatus",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("true", response.CanEvolveByFriendship)
            assert.are.equal("0", response.ToEvolution) -- Already meets threshold

            local data = response.Data
            assert.is_true(data.canEvolveByFriendship)
            assert.are.equal(0, data.toEvolutionThreshold)
        end)

        it("should handle pokemon without explicit friendship value", function()
            local testData = {
                pokemon = {
                    speciesId = 25 -- Should use base friendship (50 for Pikachu)
                    -- No friendship field provided
                }
            }

            local response = aolite.send(processId, {
                Action = "GetFriendshipStatus",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("SaveState", response.Action)
            assert.are.equal("50", response.CurrentFriendship) -- Base friendship for Pikachu
            assert.are.equal("normal", response.FriendshipLevel) -- 50 is in 'normal' range
        end)
    end)

    describe("Friendship Level Classification", function()
        it("should classify friendship levels correctly", function()
            local testCases = {
                {friendship = 0, expectedLevel = "very_low"},
                {friendship = 25, expectedLevel = "very_low"},
                {friendship = 50, expectedLevel = "low"},
                {friendship = 99, expectedLevel = "low"},
                {friendship = 100, expectedLevel = "normal"},
                {friendship = 149, expectedLevel = "normal"},
                {friendship = 150, expectedLevel = "high"},
                {friendship = 199, expectedLevel = "high"},
                {friendship = 200, expectedLevel = "very_high"},
                {friendship = 254, expectedLevel = "very_high"},
                {friendship = 255, expectedLevel = "maximum"}
            }

            for _, testCase in ipairs(testCases) do
                local testData = {
                    pokemon = {
                        speciesId = 25,
                        friendship = testCase.friendship
                    }
                }

                local response = aolite.send(processId, {
                    Action = "GetFriendshipStatus",
                    Data = testData,
                    From = "test-sender"
                })

                assert.are.equal(testCase.expectedLevel, response.FriendshipLevel,
                    "Friendship " .. testCase.friendship .. " should be level " .. testCase.expectedLevel)
            end
        end)
    end)

    describe("Input Validation", function()
        it("should reject messages without pokemon data", function()
            local handlers = {"CalculateFriendship", "CheckFriendshipEvolution", "CalculateFriendshipMoveEffects", "GetFriendshipStatus"}

            for _, handlerAction in ipairs(handlers) do
                local response = aolite.send(processId, {
                    Action = handlerAction,
                    Data = {}, -- No pokemon field
                    From = "test-sender"
                })

                assert.are.equal("Error", response.Action, "Handler " .. handlerAction .. " should reject empty pokemon data")
                assert.is.truthy(response.Error)
            end
        end)

        it("should reject invalid species ID", function()
            local testData = {
                pokemon = {
                    speciesId = "invalid", -- String instead of number
                    friendship = 50
                }
            }

            local response = aolite.send(processId, {
                Action = "CalculateFriendship",
                Data = testData,
                From = "test-sender"
            })

            assert.are.equal("Error", response.Action)
            assert.matches("Valid species ID required", response.Error)
        end)

        it("should reject friendship values out of range", function()
            local testDataLow = {
                pokemon = {
                    speciesId = 25,
                    friendship = -10 -- Below 0
                }
            }

            local responseLow = aolite.send(processId, {
                Action = "GetFriendshipStatus",
                Data = testDataLow,
                From = "test-sender"
            })

            assert.are.equal("Error", responseLow.Action)
            assert.matches("Friendship must be between 0 and 255", responseLow.Error)

            local testDataHigh = {
                pokemon = {
                    speciesId = 25,
                    friendship = 300 -- Above 255
                }
            }

            local responseHigh = aolite.send(processId, {
                Action = "GetFriendshipStatus",
                Data = testDataHigh,
                From = "test-sender"
            })

            assert.are.equal("Error", responseHigh.Action)
            assert.matches("Friendship must be between 0 and 255", responseHigh.Error)
        end)
    end)

    describe("Performance and Rate Limiting", function()
        it("should handle multiple requests within rate limit", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 100
                }
            }

            -- Send multiple requests (within rate limit)
            for i = 1, 10 do
                local response = aolite.send(processId, {
                    Action = "GetFriendshipStatus",
                    Data = testData,
                    From = "test-sender-" .. i -- Different senders to avoid rate limiting
                })

                assert.are.equal("SaveState", response.Action, "Request " .. i .. " should succeed")
            end
        end)

        it("should respond quickly to simple requests", function()
            local testData = {
                pokemon = {
                    speciesId = 25,
                    friendship = 100
                }
            }

            local startTime = os.clock()

            local response = aolite.send(processId, {
                Action = "GetFriendshipStatus",
                Data = testData,
                From = "test-sender"
            })

            local endTime = os.clock()
            local elapsed = (endTime - startTime) * 1000 -- Convert to milliseconds

            assert.are.equal("SaveState", response.Action)
            assert.is_true(elapsed < 50, "Response should be under 50ms, was " .. elapsed .. "ms")
        end)
    end)
end)