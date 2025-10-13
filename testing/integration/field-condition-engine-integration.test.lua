-- Integration Tests for Field Condition Engine
-- Tests multi-process message flow and complex field condition scenarios

local aolite = require('aolite')
local json = require('json')

-- Setup test environment
local function setupIntegrationTest()
    aolite.setupMockEnvironment()

    -- Load field condition engine process
    local processCode = io.open('/Users/jonathangreen/Documents/pokerogue/processes/field-condition-engine.lua', 'r'):read('*all')
    aolite.eval(processCode)

    return "field_condition_process_1"
end

describe("Field Condition Engine Integration Tests", function()

    local processId
    local testBattleId = "integration_battle_456"
    local testTimestamp = "1234567890"

    beforeEach(function()
        processId = setupIntegrationTest()

        -- Clear state between tests
        FieldConditions = {}
        FutureAttacks = {}
        BattleState = {}
    end)

    describe("Complex Room Effect Scenarios", function()

        it("should handle sequential room effect applications with proper replacement", function()
            -- Apply Trick Room
            local trickRoomMsg = {
                Id = "msg_001",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25", -- Pikachu
                SourceMove = "TRICK_ROOM",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local trickRoomResponse = aolite.sendMessage(trickRoomMsg)
            assert.equals("SaveState", trickRoomResponse.Action)
            assert.equals("true", trickRoomResponse.Success)

            -- Apply Wonder Room (should replace Trick Room)
            local wonderRoomMsg = {
                Id = "msg_002",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "WONDER_ROOM",
                SourceId = "65", -- Alakazam
                SourceMove = "WONDER_ROOM",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1000)
            }

            local wonderRoomResponse = aolite.sendMessage(wonderRoomMsg)
            assert.equals("true", wonderRoomResponse.Replaced)

            local wonderRoomData = json.decode(wonderRoomResponse.Data)
            assert.equals(true, wonderRoomData.conditionResult.replaced)
            assert.equals(1, #wonderRoomData.conditionResult.removedConditions)
            assert.equals("TRICK_ROOM", wonderRoomData.conditionResult.removedConditions[1].conditionType)

            -- Apply Magic Room (should replace Wonder Room)
            local magicRoomMsg = {
                Id = "msg_003",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "MAGIC_ROOM",
                SourceId = "196", -- Espeon
                SourceMove = "MAGIC_ROOM",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 2000)
            }

            local magicRoomResponse = aolite.sendMessage(magicRoomMsg)
            assert.equals("true", magicRoomResponse.Replaced)

            local magicRoomData = json.decode(magicRoomResponse.Data)
            assert.equals("WONDER_ROOM", magicRoomData.conditionResult.removedConditions[1].conditionType)

            -- Verify only Magic Room is active
            local checkMsg = {
                Id = "msg_004",
                From = "battle_coordinator",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "ITEM_RESTRICTION",
                PokemonId = "25",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local checkResponse = aolite.sendMessage(checkMsg)
            local checkData = json.decode(checkResponse.Data)
            assert.equals(true, checkData.effectResults.itemsDisabled)
        end)

        it("should handle multiple non-room conditions simultaneously", function()
            -- Apply Gravity
            local gravityMsg = {
                Id = "msg_005",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "GRAVITY",
                SourceId = "196", -- Espeon
                Parameters = json.encode({
                    groundedPokemon = {"144", "145", "146"} -- Legendary birds
                }),
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local gravityResponse = aolite.sendMessage(gravityMsg)
            assert.equals("true", gravityResponse.Success)
            assert.equals("false", gravityResponse.Replaced)

            -- Apply Imprison
            local imprisonMsg = {
                Id = "msg_006",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "IMPRISON",
                SourceId = "25", -- Pikachu
                Parameters = json.encode({
                    affectedPokemon = {
                        ["134"] = {restrictedMoves = {"TACKLE", "THUNDER_SHOCK"}},
                        ["135"] = {restrictedMoves = {"QUICK_ATTACK"}}
                    }
                }),
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 500)
            }

            local imprisonResponse = aolite.sendMessage(imprisonMsg)
            assert.equals("true", imprisonResponse.Success)
            assert.equals("false", imprisonResponse.Replaced)

            -- Apply Trick Room (should not affect Gravity or Imprison)
            local trickRoomMsg = {
                Id = "msg_007",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "65", -- Alakazam
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1000)
            }

            local trickRoomResponse = aolite.sendMessage(trickRoomMsg)
            assert.equals("true", trickRoomResponse.Success)

            -- Verify all three conditions are active
            local priorityMsg = {
                Id = "msg_008",
                From = "battle_coordinator",
                Target = processId,
                Action = "ProcessFieldConditionInteractions",
                InteractionType = "PRIORITY",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local priorityResponse = aolite.sendMessage(priorityMsg)
            local priorityData = json.decode(priorityResponse.Data)
            assert.equals(3, #priorityData.interactionResults.sortedConditions)

            -- Verify priority order: TRICK_ROOM (100) > GRAVITY (70) > IMPRISON (60)
            assert.equals("TRICK_ROOM", priorityData.interactionResults.resolutionOrder[1].conditionType)
            assert.equals("GRAVITY", priorityData.interactionResults.resolutionOrder[2].conditionType)
            assert.equals("IMPRISON", priorityData.interactionResults.resolutionOrder[3].conditionType)
        end)
    end)

    describe("Future Attack Coordination", function()

        it("should handle multiple future attacks with different timing", function()
            -- Schedule Future Sight with 2-turn delay
            local futureSightMsg = {
                Id = "msg_009",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFutureAttack",
                AttackType = "FUTURE_SIGHT",
                SourceId = "196", -- Espeon
                TargetId = "25", -- Pikachu
                Damage = "150",
                DelayTurns = "2",
                AttackData = json.encode({
                    movePower = 120,
                    moveType = "PSYCHIC",
                    originalStats = {attack = 65, spatk = 130}
                }),
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local futureSightResponse = aolite.sendMessage(futureSightMsg)
            assert.equals("true", futureSightResponse.Success)
            assert.equals("true", futureSightResponse.Scheduled)

            -- Schedule Doom Desire with 2-turn delay
            local doomDesireMsg = {
                Id = "msg_010",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFutureAttack",
                AttackType = "DOOM_DESIRE",
                SourceId = "385", -- Jirachi
                TargetId = "144", -- Articuno
                Damage = "140",
                DelayTurns = "2",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 500)
            }

            local doomDesireResponse = aolite.sendMessage(doomDesireMsg)
            assert.equals("true", doomDesireResponse.Success)

            -- Schedule another Future Sight with 1-turn delay
            local secondFutureSightMsg = {
                Id = "msg_011",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFutureAttack",
                AttackType = "FUTURE_SIGHT",
                SourceId = "65", -- Alakazam
                TargetId = "134", -- Vaporeon
                Damage = "130",
                DelayTurns = "1",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1000)
            }

            local secondFutureSightResponse = aolite.sendMessage(secondFutureSightMsg)
            assert.equals("true", secondFutureSightResponse.Success)

            -- Advance 1 turn - should execute second Future Sight only
            local advanceTurn1Msg = {
                Id = "msg_012",
                From = "battle_coordinator",
                Target = processId,
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1500)
            }

            local advanceTurn1Response = aolite.sendMessage(advanceTurn1Msg)
            assert.equals("1", advanceTurn1Response.ExecutedCount)

            local advanceTurn1Data = json.decode(advanceTurn1Response.Data)
            assert.equals(1, #advanceTurn1Data.executedAttacks)
            assert.equals("FUTURE_SIGHT", advanceTurn1Data.executedAttacks[1].attackType)
            assert.equals(65, advanceTurn1Data.executedAttacks[1].sourceId)
            assert.equals(134, advanceTurn1Data.executedAttacks[1].targetId)

            -- Advance another turn - should execute remaining two attacks
            local advanceTurn2Msg = {
                Id = "msg_013",
                From = "battle_coordinator",
                Target = processId,
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 2000)
            }

            local advanceTurn2Response = aolite.sendMessage(advanceTurn2Msg)
            assert.equals("2", advanceTurn2Response.ExecutedCount)

            local advanceTurn2Data = json.decode(advanceTurn2Response.Data)
            assert.equals(2, #advanceTurn2Data.executedAttacks)

            -- Verify both attacks executed
            local attackTypes = {}
            for _, attack in ipairs(advanceTurn2Data.executedAttacks) do
                attackTypes[attack.attackType] = true
            end
            assert.is_true(attackTypes["FUTURE_SIGHT"])
            assert.is_true(attackTypes["DOOM_DESIRE"])
        end)
    end)

    describe("Complex Multi-Effect Scenarios", function()

        it("should handle field conditions with future attacks and turn progression", function()
            -- Apply Trick Room (5 turns)
            local trickRoomMsg = {
                Id = "msg_014",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25",
                Duration = "3",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            aolite.sendMessage(trickRoomMsg)

            -- Apply Gravity (5 turns)
            local gravityMsg = {
                Id = "msg_015",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "GRAVITY",
                SourceId = "196",
                Duration = "2",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 100)
            }

            aolite.sendMessage(gravityMsg)

            -- Schedule Future Sight
            local futureSightMsg = {
                Id = "msg_016",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFutureAttack",
                AttackType = "FUTURE_SIGHT",
                SourceId = "196",
                TargetId = "25",
                Damage = "120",
                DelayTurns = "2",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 200)
            }

            aolite.sendMessage(futureSightMsg)

            -- Advance Turn 1
            local advanceTurn1Msg = {
                Id = "msg_017",
                From = "battle_coordinator",
                Target = processId,
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1000)
            }

            local advanceTurn1Response = aolite.sendMessage(advanceTurn1Msg)
            assert.equals("0", advanceTurn1Response.ExecutedCount) -- No attacks execute yet
            assert.equals("0", advanceTurn1Response.ExpiredCount) -- No conditions expire yet

            -- Check that both conditions are still active with reduced turns
            local checkSpeedMsg = {
                Id = "msg_018",
                From = "battle_coordinator",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "SPEED_PRIORITY",
                PokemonId = "25",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1100)
            }

            local checkSpeedResponse = aolite.sendMessage(checkSpeedMsg)
            local checkSpeedData = json.decode(checkSpeedResponse.Data)
            assert.equals(-1, checkSpeedData.effectResults.speedPriorityModifier) -- Trick Room still active

            -- Advance Turn 2
            local advanceTurn2Msg = {
                Id = "msg_019",
                From = "battle_coordinator",
                Target = processId,
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 2000)
            }

            local advanceTurn2Response = aolite.sendMessage(advanceTurn2Msg)
            assert.equals("1", advanceTurn2Response.ExecutedCount) -- Future Sight executes
            assert.equals("1", advanceTurn2Response.ExpiredCount) -- Gravity expires (was set to 2 turns)

            local advanceTurn2Data = json.decode(advanceTurn2Response.Data)
            assert.equals("FUTURE_SIGHT", advanceTurn2Data.executedAttacks[1].attackType)
            assert.equals("GRAVITY", advanceTurn2Data.expiredConditions[1].conditionType)

            -- Advance Turn 3
            local advanceTurn3Msg = {
                Id = "msg_020",
                From = "battle_coordinator",
                Target = processId,
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 3000)
            }

            local advanceTurn3Response = aolite.sendMessage(advanceTurn3Msg)
            assert.equals("0", advanceTurn3Response.ExecutedCount) -- No more attacks
            assert.equals("1", advanceTurn3Response.ExpiredCount) -- Trick Room expires

            local advanceTurn3Data = json.decode(advanceTurn3Response.Data)
            assert.equals("TRICK_ROOM", advanceTurn3Data.expiredConditions[1].conditionType)

            -- Verify no conditions remain active
            local finalCheckMsg = {
                Id = "msg_021",
                From = "battle_coordinator",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "SPEED_PRIORITY",
                PokemonId = "25",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 3100)
            }

            local finalCheckResponse = aolite.sendMessage(finalCheckMsg)
            local finalCheckData = json.decode(finalCheckResponse.Data)
            assert.equals(1, finalCheckData.effectResults.speedPriorityModifier) -- Normal speed priority restored
        end)

        it("should handle Imprison with Pokemon switching scenarios", function()
            -- Apply Imprison
            local imprisonMsg = {
                Id = "msg_022",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "IMPRISON",
                SourceId = "25", -- Pikachu source
                Parameters = json.encode({
                    affectedPokemon = {
                        ["134"] = {restrictedMoves = {"TACKLE", "QUICK_ATTACK"}},
                        ["135"] = {restrictedMoves = {"TACKLE", "THUNDER_SHOCK"}}
                    }
                }),
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            aolite.sendMessage(imprisonMsg)

            -- Check move restriction for Vaporeon
            local checkVaporeonMsg = {
                Id = "msg_023",
                From = "battle_coordinator",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "MOVE_RESTRICTION",
                PokemonId = "134",
                MoveId = "TACKLE",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 100)
            }

            local checkVaporeonResponse = aolite.sendMessage(checkVaporeonMsg)
            local checkVaporeonData = json.decode(checkVaporeonResponse.Data)
            assert.equals(true, checkVaporeonData.effectResults.moveRestricted)
            assert.equals(25, checkVaporeonData.effectResults.imprisonSource)

            -- Check move restriction for Jolteon
            local checkJolteonMsg = {
                Id = "msg_024",
                From = "battle_coordinator",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "MOVE_RESTRICTION",
                PokemonId = "135",
                MoveId = "THUNDER_SHOCK",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 200)
            }

            local checkJolteonResponse = aolite.sendMessage(checkJolteonMsg)
            local checkJolteonData = json.decode(checkJolteonResponse.Data)
            assert.equals(true, checkJolteonData.effectResults.moveRestricted)

            -- Check non-restricted move for Vaporeon
            local checkWaterGunMsg = {
                Id = "msg_025",
                From = "battle_coordinator",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "MOVE_RESTRICTION",
                PokemonId = "134",
                MoveId = "WATER_GUN",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 300)
            }

            local checkWaterGunResponse = aolite.sendMessage(checkWaterGunMsg)
            local checkWaterGunData = json.decode(checkWaterGunResponse.Data)
            assert.equals(false, checkWaterGunData.effectResults.moveRestricted)
        end)
    end)

    describe("Error Handling and Edge Cases", function()

        it("should handle multiple battle contexts simultaneously", function()
            local battle1Id = "battle_001"
            local battle2Id = "battle_002"

            -- Apply different conditions to different battles
            local battle1TrickRoomMsg = {
                Id = "msg_026",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25",
                BattleId = battle1Id,
                Timestamp = testTimestamp
            }

            local battle2GravityMsg = {
                Id = "msg_027",
                From = "battle_coordinator",
                Target = processId,
                Action = "ApplyFieldCondition",
                ConditionType = "GRAVITY",
                SourceId = "196",
                BattleId = battle2Id,
                Timestamp = testTimestamp
            }

            aolite.sendMessage(battle1TrickRoomMsg)
            aolite.sendMessage(battle2GravityMsg)

            -- Check effects are isolated to respective battles
            local checkBattle1Msg = {
                Id = "msg_028",
                From = "battle_coordinator",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "SPEED_PRIORITY",
                PokemonId = "25",
                BattleId = battle1Id,
                Timestamp = tostring(tonumber(testTimestamp) + 100)
            }

            local checkBattle1Response = aolite.sendMessage(checkBattle1Msg)
            local checkBattle1Data = json.decode(checkBattle1Response.Data)
            assert.equals(-1, checkBattle1Data.effectResults.speedPriorityModifier)

            local checkBattle2Msg = {
                Id = "msg_029",
                From = "battle_coordinator",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "GROUNDING",
                PokemonId = "144",
                BattleId = battle2Id,
                Timestamp = tostring(tonumber(testTimestamp) + 200)
            }

            local checkBattle2Response = aolite.sendMessage(checkBattle2Msg)
            local checkBattle2Data = json.decode(checkBattle2Response.Data)
            assert.equals(true, checkBattle2Data.effectResults.isGrounded)

            -- Verify cross-battle isolation
            local crossCheckMsg = {
                Id = "msg_030",
                From = "battle_coordinator",
                Target = processId,
                Action = "CheckFieldConditionEffects",
                CheckType = "GROUNDING",
                PokemonId = "144",
                BattleId = battle1Id, -- Check battle1 for gravity effect
                Timestamp = tostring(tonumber(testTimestamp) + 300)
            }

            local crossCheckResponse = aolite.sendMessage(crossCheckMsg)
            local crossCheckData = json.decode(crossCheckResponse.Data)
            assert.equals(false, crossCheckData.effectResults.isGrounded) -- No gravity in battle1
        end)
    end)
end)

print("Field Condition Engine integration tests completed")