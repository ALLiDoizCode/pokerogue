-- TypeScript Parity Tests for Field Condition Engine
-- Validates that Lua implementation matches TypeScript behavior exactly

local aolite = require('aolite')
local json = require('json')

-- Load TypeScript reference behaviors and expected results
local TypeScriptReference = {
    -- Room effect priorities and behaviors from arena-tag.ts
    ROOM_EFFECTS = {
        TRICK_ROOM = {
            priority = 100,
            duration = 5,
            speedReversal = true,
            replaces = {"WONDER_ROOM", "MAGIC_ROOM"}
        },
        WONDER_ROOM = {
            priority = 90,
            duration = 5,
            statSwap = true,
            replaces = {"TRICK_ROOM", "MAGIC_ROOM"}
        },
        MAGIC_ROOM = {
            priority = 80,
            duration = 5,
            itemDisable = true,
            replaces = {"TRICK_ROOM", "WONDER_ROOM"}
        }
    },

    -- Non-room field effects
    FIELD_EFFECTS = {
        GRAVITY = {
            priority = 70,
            duration = 5,
            grounds = true,
            removesFlying = true,
            affects = {"FLOATING", "TELEKINESIS", "FLYING"}
        },
        IMPRISON = {
            priority = 60,
            duration = 999, -- Until source switches out
            moveRestriction = true,
            dynamicTracking = true
        }
    },

    -- Future attack mechanics from arena-tag.ts lines 1400-1500
    FUTURE_ATTACKS = {
        FUTURE_SIGHT = {
            delay = 2,
            moveType = "PSYCHIC",
            usesOriginalStats = true,
            targetSpecific = true
        },
        DOOM_DESIRE = {
            delay = 2,
            moveType = "STEEL",
            usesOriginalStats = true,
            targetSpecific = true
        }
    }
}

-- Setup test environment with TypeScript reference data
local function setupParityTest()
    aolite.setupMockEnvironment()

    -- Load field condition engine process
    local processCode = io.open('/Users/jonathangreen/Documents/pokerogue/processes/field-condition-engine.lua', 'r'):read('*all')
    aolite.eval(processCode)

    return "field_condition_process_parity"
end

describe("Field Condition Engine TypeScript Parity Tests", function()

    local processId
    local testBattleId = "parity_battle_789"
    local testTimestamp = "1234567890"

    beforeEach(function()
        processId = setupParityTest()

        -- Clear state between tests
        FieldConditions = {}
        FutureAttacks = {}
        BattleState = {}
    end)

    describe("Room Effect Speed Priority Calculations", function()

        it("should match TypeScript Trick Room speed reversal exactly", function()
            -- Apply Trick Room
            local msg = {
                Id = "parity_001",
                From = "parity_tester",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25", -- Pikachu
                Duration = "5",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(msg)
            local responseData = json.decode(response.Data)

            -- Verify TypeScript parity for priority adjustment
            local expectedPriorityAdjustment = -1 -- TypeScript: speedReversed.value = !speedReversed.value
            assert.equals(expectedPriorityAdjustment, responseData.conditionResult.priorityAdjustment)

            -- Verify condition priority matches TypeScript
            local expectedPriority = TypeScriptReference.ROOM_EFFECTS.TRICK_ROOM.priority
            assert.equals(expectedPriority, responseData.fieldConditionState.priority)

            -- Verify duration matches TypeScript default
            local expectedDuration = TypeScriptReference.ROOM_EFFECTS.TRICK_ROOM.duration
            assert.equals(expectedDuration, responseData.fieldConditionState.turnsRemaining)
        end)

        it("should match TypeScript speed priority check behavior", function()
            -- Apply Trick Room
            local applyMsg = {
                Id = "parity_002",
                From = "parity_tester",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(applyMsg)

            -- Check speed priority (should match TypeScript behavior)
            local checkMsg = {
                Id = "parity_003",
                From = "parity_tester",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "SPEED_PRIORITY",
                PokemonId = "134", -- Vaporeon
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local checkResponse = aolite.sendMessage(checkMsg)
            local checkData = json.decode(checkResponse.Data)

            -- TypeScript: speed calculation is reversed when Trick Room is active
            local expectedSpeedModifier = -1
            assert.equals(expectedSpeedModifier, checkData.effectResults.speedPriorityModifier)
        end)
    end)

    describe("Room Effect Overlap and Replacement Logic", function()

        it("should match TypeScript room replacement behavior exactly", function()
            -- Apply Trick Room (first room)
            local trickRoomMsg = {
                Id = "parity_004",
                From = "parity_tester",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(trickRoomMsg)

            -- Apply Wonder Room (should replace Trick Room per TypeScript logic)
            local wonderRoomMsg = {
                Id = "parity_005",
                From = "parity_tester",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "WONDER_ROOM",
                SourceId = "65",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1000)
            }

            local wonderResponse = aolite.sendMessage(wonderRoomMsg)
            local wonderData = json.decode(wonderResponse.Data)

            -- Verify TypeScript replacement behavior
            assert.equals(true, wonderData.conditionResult.replaced)
            assert.equals(1, #wonderData.conditionResult.removedConditions)
            assert.equals("TRICK_ROOM", wonderData.conditionResult.removedConditions[1].conditionType)

            -- Verify only Wonder Room remains active (TypeScript: immediate removal upon overlap)
            local checkStatsMsg = {
                Id = "parity_006",
                From = "parity_tester",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "STAT_SWAP",
                PokemonId = "25",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1100)
            }

            local checkStatsResponse = aolite.sendMessage(checkStatsMsg)
            local checkStatsData = json.decode(checkStatsResponse.Data)
            assert.equals(true, checkStatsData.effectResults.statsSwapped)

            -- Verify speed priority is NOT reversed (Trick Room removed)
            local checkSpeedMsg = {
                Id = "parity_007",
                From = "parity_tester",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "SPEED_PRIORITY",
                PokemonId = "25",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1200)
            }

            local checkSpeedResponse = aolite.sendMessage(checkSpeedMsg)
            local checkSpeedData = json.decode(checkSpeedResponse.Data)
            assert.equals(1, checkSpeedData.effectResults.speedPriorityModifier) -- Normal speed priority
        end)
    end)

    describe("Gravity Grounding Effects Parity", function()

        it("should match TypeScript Gravity grounding behavior", function()
            local groundedPokemon = {"144", "145", "146"} -- Legendary birds (Flying types)
            local parameters = json.encode({
                groundedPokemon = groundedPokemon
            })

            -- Apply Gravity
            local gravityMsg = {
                Id = "parity_008",
                From = "parity_tester",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "GRAVITY",
                SourceId = "196",
                Parameters = parameters,
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local gravityResponse = aolite.sendMessage(gravityMsg)
            local gravityData = json.decode(gravityResponse.Data)

            -- Verify grounding behavior matches TypeScript
            assert.equals(3, #gravityData.conditionResult.groundedPokemon)

            -- Check grounding effects for Flying-type Pokemon
            local checkGroundingMsg = {
                Id = "parity_009",
                From = "parity_tester",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "GROUNDING",
                PokemonId = "144", -- Articuno (Flying-type)
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local checkGroundingResponse = aolite.sendMessage(checkGroundingMsg)
            local checkGroundingData = json.decode(checkGroundingResponse.Data)

            -- TypeScript: Gravity grounds all Pokemon including Flying-types and Levitate users
            assert.equals(true, checkGroundingData.effectResults.isGrounded)

            -- Verify duration matches TypeScript default (5 turns)
            local expectedDuration = TypeScriptReference.FIELD_EFFECTS.GRAVITY.duration
            assert.equals(expectedDuration, gravityData.fieldConditionState.turnsRemaining)
        end)
    end)

    describe("Imprison Move Restriction Parity", function()

        it("should match TypeScript Imprison behavior exactly", function()
            -- Set up Imprison with specific move restrictions (matches TypeScript logic)
            local affectedPokemon = {
                ["134"] = { -- Vaporeon
                    restrictedMoves = {"TACKLE", "QUICK_ATTACK"}
                },
                ["135"] = { -- Jolteon
                    restrictedMoves = {"TACKLE", "THUNDER_SHOCK"}
                }
            }
            local parameters = json.encode({
                affectedPokemon = affectedPokemon
            })

            local imprisonMsg = {
                Id = "parity_010",
                From = "parity_tester",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "IMPRISON",
                SourceId = "25", -- Pikachu (source)
                Parameters = parameters,
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local imprisonResponse = aolite.sendMessage(imprisonMsg)
            local imprisonData = json.decode(imprisonResponse.Data)

            -- Verify duration matches TypeScript (until source switches out)
            local expectedDuration = TypeScriptReference.FIELD_EFFECTS.IMPRISON.duration
            assert.equals(expectedDuration, imprisonData.fieldConditionState.turnsRemaining)

            -- Test move restriction for Vaporeon using TACKLE
            local checkTackleMsg = {
                Id = "parity_011",
                From = "parity_tester",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "MOVE_RESTRICTION",
                PokemonId = "134", -- Vaporeon
                MoveId = "TACKLE",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local checkTackleResponse = aolite.sendMessage(checkTackleMsg)
            local checkTackleData = json.decode(checkTackleResponse.Data)

            -- TypeScript: Imprison prevents opposing Pokemon from using shared moves
            assert.equals(true, checkTackleData.effectResults.moveRestricted)
            assert.equals(25, checkTackleData.effectResults.imprisonSource) -- Pikachu is the source

            -- Test move restriction for non-shared move
            local checkWaterGunMsg = {
                Id = "parity_012",
                From = "parity_tester",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "MOVE_RESTRICTION",
                PokemonId = "134", -- Vaporeon
                MoveId = "WATER_GUN", -- Not in restricted list
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local checkWaterGunResponse = aolite.sendMessage(checkWaterGunMsg)
            local checkWaterGunData = json.decode(checkWaterGunResponse.Data)

            -- Should NOT be restricted (not in shared move list)
            assert.equals(false, checkWaterGunData.effectResults.moveRestricted)
        end)
    end)

    describe("Future Attack Timing and Execution Parity", function()

        it("should match TypeScript Future Sight timing exactly", function()
            local originalStats = {attack = 65, spatk = 130}
            local attackData = json.encode({
                movePower = 120,
                moveType = "PSYCHIC",
                originalStats = originalStats
            })

            -- Apply Future Sight
            local futureSightMsg = {
                Id = "parity_013",
                From = "parity_tester",
                Target = processId,
                Action = "ApplyFutureAttack",
                AttackType = "FUTURE_SIGHT",
                SourceId = "196", -- Espeon
                TargetId = "25", -- Pikachu
                Damage = "150",
                DelayTurns = "2", -- TypeScript: activates after specific turn count
                AttackData = attackData,
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local futureSightResponse = aolite.sendMessage(futureSightMsg)
            local futureSightData = json.decode(futureSightResponse.Data)

            -- Verify delay matches TypeScript default
            local expectedDelay = TypeScriptReference.FUTURE_ATTACKS.FUTURE_SIGHT.delay
            assert.equals(expectedDelay, futureSightData.futureAttack.turnsRemaining)

            -- Verify attack data preservation (uses original attacker's stats)
            assert.equals(130, futureSightData.futureAttack.attackData.originalStats.spatk)
            assert.equals("PSYCHIC", futureSightData.futureAttack.attackData.moveType)

            -- Advance 1 turn - should NOT execute (TypeScript: needs 2 turns)
            local advanceTurn1Msg = {
                Id = "parity_014",
                From = "parity_tester",
                Target = processId,
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1000)
            }

            local advanceTurn1Response = aolite.sendMessage(advanceTurn1Msg)
            assert.equals("0", advanceTurn1Response.ExecutedCount) -- Should not execute yet

            -- Advance second turn - should execute (matches TypeScript timing)
            local advanceTurn2Msg = {
                Id = "parity_015",
                From = "parity_tester",
                Target = processId,
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 2000)
            }

            local advanceTurn2Response = aolite.sendMessage(advanceTurn2Msg)
            assert.equals("1", advanceTurn2Response.ExecutedCount) -- Should execute now

            local advanceTurn2Data = json.decode(advanceTurn2Response.Data)

            -- Verify execution matches TypeScript behavior
            assert.equals("FUTURE_SIGHT", advanceTurn2Data.executedAttacks[1].attackType)
            assert.equals(196, advanceTurn2Data.executedAttacks[1].sourceId) -- Original attacker
            assert.equals(25, advanceTurn2Data.executedAttacks[1].targetId)
            assert.equals(150, advanceTurn2Data.executedAttacks[1].damage) -- Pre-calculated damage
        end)

        it("should match TypeScript Doom Desire timing exactly", function()
            -- Apply Doom Desire
            local doomDesireMsg = {
                Id = "parity_016",
                From = "parity_tester",
                Target = processId,
                Action = "ApplyFutureAttack",
                AttackType = "DOOM_DESIRE",
                SourceId = "385", -- Jirachi
                TargetId = "144", -- Articuno
                Damage = "140",
                DelayTurns = "2", -- Same as Future Sight in TypeScript
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local doomDesireResponse = aolite.sendMessage(doomDesireMsg)
            local doomDesireData = json.decode(doomDesireResponse.Data)

            -- Verify delay matches TypeScript
            local expectedDelay = TypeScriptReference.FUTURE_ATTACKS.DOOM_DESIRE.delay
            assert.equals(expectedDelay, doomDesireData.futureAttack.turnsRemaining)

            -- Test identical timing behavior to Future Sight
            local advanceTurn1Msg = {
                Id = "parity_017",
                From = "parity_tester",
                Target = processId,
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1000)
            }

            local advanceTurn1Response = aolite.sendMessage(advanceTurn1Msg)
            assert.equals("0", advanceTurn1Response.ExecutedCount)

            local advanceTurn2Msg = {
                Id = "parity_018",
                From = "parity_tester",
                Target = processId,
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 2000)
            }

            local advanceTurn2Response = aolite.sendMessage(advanceTurn2Msg)
            assert.equals("1", advanceTurn2Response.ExecutedCount)

            local advanceTurn2Data = json.decode(advanceTurn2Response.Data)
            assert.equals("DOOM_DESIRE", advanceTurn2Data.executedAttacks[1].attackType)
            assert.equals(385, advanceTurn2Data.executedAttacks[1].sourceId)
        end)
    end)

    describe("Condition Lifecycle and Expiry Parity", function()

        it("should match TypeScript turn counting and expiry exactly", function()
            -- Apply condition with specific duration
            local duration = 3 -- Custom duration for precise testing
            local conditionMsg = {
                Id = "parity_019",
                From = "parity_tester",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25",
                Duration = tostring(duration),
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            aolite.sendMessage(conditionMsg)

            -- Advance turns and verify countdown matches TypeScript behavior
            for turn = 1, duration do
                local advanceTurnMsg = {
                    Id = "parity_020_" .. turn,
                    From = "parity_tester",
                    Target = processId,
                    Action = "AdvanceTurn",
                    BattleId = testBattleId,
                    Timestamp = tostring(tonumber(testTimestamp) + (turn * 1000))
                }

                local advanceResponse = aolite.sendMessage(advanceTurnMsg)

                if turn < duration then
                    -- Should NOT expire yet (TypeScript: decrements but doesn't remove until 0)
                    assert.equals("0", advanceResponse.ExpiredCount)
                else
                    -- Should expire on final turn (TypeScript: removes when turnsRemaining reaches 0)
                    assert.equals("1", advanceResponse.ExpiredCount)

                    local advanceData = json.decode(advanceResponse.Data)
                    assert.equals("TRICK_ROOM", advanceData.expiredConditions[1].conditionType)
                end
            end
        end)
    end)

    describe("Message Protocol and Response Format Parity", function()

        it("should match TypeScript message format exactly", function()
            local msg = {
                Id = "parity_021",
                From = "parity_tester",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "WONDER_ROOM",
                SourceId = "65",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(msg)

            -- Verify response structure matches expected format
            assert.equals("SaveState", response.Action)
            assert.equals("true", response.Success)
            assert.equals("WONDER_ROOM", response.ConditionType)
            assert.equals("true", response.Applied)
            assert.equals("false", response.Replaced) -- No existing room to replace

            -- Verify response data structure
            local responseData = json.decode(response.Data)
            assert.is_not_nil(responseData.fieldConditionState)
            assert.is_not_nil(responseData.conditionResult)
            assert.is_not_nil(responseData.activeConditions)

            -- Verify field condition state structure
            local conditionState = responseData.fieldConditionState
            assert.equals("WONDER_ROOM", conditionState.conditionType)
            assert.equals(5, conditionState.turnsRemaining) -- Default duration
            assert.equals(65, conditionState.sourceId)
            assert.equals(90, conditionState.priority) -- Wonder Room priority
        end)
    end)
end)

print("Field Condition Engine TypeScript parity tests completed")