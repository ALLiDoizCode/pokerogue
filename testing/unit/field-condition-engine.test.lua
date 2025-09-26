-- Unit Tests for Field Condition Engine
-- Tests field condition application, priority resolution, state persistence, and future attacks

local aolite = require('aolite')

-- Mock AO environment setup
aolite.setupMockEnvironment()

-- Load the field condition engine process
local processCode = io.open('/Users/jonathangreen/Documents/pokerogue/processes/field-condition-engine.lua', 'r'):read('*all')
aolite.eval(processCode)

describe("Field Condition Engine Unit Tests", function()

    local testBattleId = "test_battle_123"
    local testTimestamp = "1234567890"

    beforeEach(function()
        -- Clear state between tests
        FieldConditions = {}
        FutureAttacks = {}
        BattleState = {}
    end)

    describe("ApplyFieldCondition Handler", function()

        it("should apply Trick Room condition successfully", function()
            local msg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25", -- Pikachu
                SourceMove = "TRICK_ROOM",
                Side = "BOTH",
                Duration = "5",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(msg)

            assert.equals("SaveState", response.Action)
            assert.equals("true", response.Success)
            assert.equals("TRICK_ROOM", response.ConditionType)
            assert.equals("true", response.Applied)

            local responseData = json.decode(response.Data)
            assert.equals("TRICK_ROOM", responseData.fieldConditionState.conditionType)
            assert.equals(5, responseData.fieldConditionState.turnsRemaining)
            assert.equals(25, responseData.fieldConditionState.sourceId)
            assert.equals(-1, responseData.conditionResult.priorityAdjustment)
        end)

        it("should apply Wonder Room condition successfully", function()
            local msg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "WONDER_ROOM",
                SourceId = "65", -- Alakazam
                SourceMove = "WONDER_ROOM",
                Side = "BOTH",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(msg)

            assert.equals("SaveState", response.Action)
            assert.equals("true", response.Success)
            assert.equals("WONDER_ROOM", response.ConditionType)

            local responseData = json.decode(response.Data)
            assert.equals("WONDER_ROOM", responseData.fieldConditionState.conditionType)
            assert.equals(90, responseData.fieldConditionState.priority)
        end)

        it("should replace existing room effect with newer room", function()
            -- First apply Trick Room
            local trickRoomMsg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(trickRoomMsg)

            -- Then apply Wonder Room (should replace Trick Room)
            local wonderRoomMsg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "WONDER_ROOM",
                SourceId = "65",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1000)
            }

            local response = aolite.sendMessage(wonderRoomMsg)

            assert.equals("true", response.Replaced)

            local responseData = json.decode(response.Data)
            assert.equals(true, responseData.conditionResult.replaced)
            assert.equals(1, #responseData.conditionResult.removedConditions)
            assert.equals("TRICK_ROOM", responseData.conditionResult.removedConditions[1].conditionType)
        end)

        it("should apply Gravity condition successfully", function()
            local groundedPokemon = {"25", "144", "145"}
            local parameters = json.encode({
                groundedPokemon = groundedPokemon
            })

            local msg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "GRAVITY",
                SourceId = "196", -- Espeon
                SourceMove = "GRAVITY",
                Parameters = parameters,
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(msg)

            assert.equals("true", response.Success)
            assert.equals("GRAVITY", response.ConditionType)

            local responseData = json.decode(response.Data)
            assert.equals("GRAVITY", responseData.fieldConditionState.conditionType)
            assert.equals(3, #responseData.conditionResult.groundedPokemon)
        end)

        it("should apply Imprison condition successfully", function()
            local affectedPokemon = {
                ["134"] = { -- Vaporeon
                    restrictedMoves = {"TACKLE", "QUICK_ATTACK"}
                }
            }
            local parameters = json.encode({
                affectedPokemon = affectedPokemon
            })

            local msg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "IMPRISON",
                SourceId = "25",
                Parameters = parameters,
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(msg)

            assert.equals("true", response.Success)
            assert.equals("IMPRISON", response.ConditionType)

            local responseData = json.decode(response.Data)
            assert.equals("IMPRISON", responseData.fieldConditionState.conditionType)
            assert.equals(999, responseData.fieldConditionState.turnsRemaining)
        end)

        it("should reject invalid condition type", function()
            local msg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "INVALID_CONDITION",
                SourceId = "25",
                BattleId = testBattleId
            }

            local response = aolite.sendMessage(msg)

            assert.equals("Error", response.Action)
            assert.equals("false", response.Success)
            assert.is_true(string.find(response.Error, "Invalid or missing ConditionType"))
        end)

        it("should reject missing required parameters", function()
            local msg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM"
                -- Missing SourceId and BattleId
            }

            local response = aolite.sendMessage(msg)

            assert.equals("Error", response.Action)
            assert.equals("false", response.Success)
            assert.is_true(string.find(response.Error, "Missing required parameters"))
        end)
    end)

    describe("ApplyFutureAttack Handler", function()

        it("should apply Future Sight attack successfully", function()
            local attackData = json.encode({
                movePower = 120,
                moveType = "PSYCHIC",
                originalStats = {attack = 55, spatk = 50}
            })

            local msg = {
                From = "test_user",
                Action = "ApplyFutureAttack",
                AttackType = "FUTURE_SIGHT",
                SourceId = "196", -- Espeon
                TargetId = "25", -- Pikachu
                Damage = "150",
                DelayTurns = "2",
                AttackData = attackData,
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(msg)

            assert.equals("SaveState", response.Action)
            assert.equals("true", response.Success)
            assert.equals("FUTURE_SIGHT", response.AttackType)
            assert.equals("true", response.Scheduled)

            local responseData = json.decode(response.Data)
            assert.equals("FUTURE_SIGHT", responseData.futureAttack.attackType)
            assert.equals(196, responseData.futureAttack.sourceId)
            assert.equals(25, responseData.futureAttack.targetId)
            assert.equals(150, responseData.futureAttack.damage)
            assert.equals(2, responseData.futureAttack.turnsRemaining)
        end)

        it("should apply Doom Desire attack successfully", function()
            local msg = {
                From = "test_user",
                Action = "ApplyFutureAttack",
                AttackType = "DOOM_DESIRE",
                SourceId = "385", -- Jirachi
                TargetId = "144", -- Articuno
                Damage = "140",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(msg)

            assert.equals("true", response.Success)
            assert.equals("DOOM_DESIRE", response.AttackType)

            local responseData = json.decode(response.Data)
            assert.equals("DOOM_DESIRE", responseData.futureAttack.attackType)
            assert.equals(385, responseData.futureAttack.sourceId)
            assert.equals(144, responseData.futureAttack.targetId)
        end)

        it("should reject invalid attack type", function()
            local msg = {
                From = "test_user",
                Action = "ApplyFutureAttack",
                AttackType = "INVALID_ATTACK",
                SourceId = "25",
                TargetId = "134",
                BattleId = testBattleId
            }

            local response = aolite.sendMessage(msg)

            assert.equals("Error", response.Action)
            assert.equals("false", response.Success)
            assert.is_true(string.find(response.Error, "Invalid or missing AttackType"))
        end)
    end)

    describe("CheckFieldConditionEffects Handler", function()

        it("should check speed priority with Trick Room active", function()
            -- Apply Trick Room first
            local applyMsg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(applyMsg)

            -- Check speed priority effects
            local checkMsg = {
                From = "test_user",
                Action = "CheckFieldConditionEffects",
                CheckType = "SPEED_PRIORITY",
                PokemonId = "134",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(checkMsg)

            assert.equals("SaveState", response.Action)
            assert.equals("true", response.Success)
            assert.equals("SPEED_PRIORITY", response.CheckType)

            local responseData = json.decode(response.Data)
            assert.equals(-1, responseData.effectResults.speedPriorityModifier)
        end)

        it("should check grounding with Gravity active", function()
            -- Apply Gravity first
            local applyMsg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "GRAVITY",
                SourceId = "196",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(applyMsg)

            -- Check grounding effects
            local checkMsg = {
                From = "test_user",
                Action = "CheckFieldConditionEffects",
                CheckType = "GROUNDING",
                PokemonId = "144", -- Flying-type Articuno
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(checkMsg)

            assert.equals("true", response.Success)

            local responseData = json.decode(response.Data)
            assert.equals(true, responseData.effectResults.isGrounded)
        end)

        it("should check move restrictions with Imprison active", function()
            -- Apply Imprison first with restricted moves
            local affectedPokemon = {
                ["134"] = {
                    restrictedMoves = {"TACKLE", "QUICK_ATTACK"}
                }
            }
            local parameters = json.encode({
                affectedPokemon = affectedPokemon
            })

            local applyMsg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "IMPRISON",
                SourceId = "25",
                Parameters = parameters,
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(applyMsg)

            -- Check if TACKLE is restricted for Vaporeon
            local checkMsg = {
                From = "test_user",
                Action = "CheckFieldConditionEffects",
                CheckType = "MOVE_RESTRICTION",
                PokemonId = "134",
                MoveId = "TACKLE",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(checkMsg)

            assert.equals("true", response.Success)

            local responseData = json.decode(response.Data)
            assert.equals(true, responseData.effectResults.moveRestricted)
            assert.equals(25, responseData.effectResults.imprisonSource)
        end)

        it("should check item restrictions with Magic Room active", function()
            -- Apply Magic Room first
            local applyMsg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "MAGIC_ROOM",
                SourceId = "65",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(applyMsg)

            -- Check item restrictions
            local checkMsg = {
                From = "test_user",
                Action = "CheckFieldConditionEffects",
                CheckType = "ITEM_RESTRICTION",
                PokemonId = "25",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(checkMsg)

            assert.equals("true", response.Success)

            local responseData = json.decode(response.Data)
            assert.equals(true, responseData.effectResults.itemsDisabled)
        end)

        it("should check stat swap with Wonder Room active", function()
            -- Apply Wonder Room first
            local applyMsg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "WONDER_ROOM",
                SourceId = "65",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(applyMsg)

            -- Check stat swap effects
            local checkMsg = {
                From = "test_user",
                Action = "CheckFieldConditionEffects",
                CheckType = "STAT_SWAP",
                PokemonId = "25",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(checkMsg)

            assert.equals("true", response.Success)

            local responseData = json.decode(response.Data)
            assert.equals(true, responseData.effectResults.statsSwapped)
        end)
    end)

    describe("AdvanceTurn Handler", function()

        it("should expire conditions after turn countdown", function()
            -- Apply condition with 1 turn remaining
            local applyMsg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25",
                Duration = "1",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(applyMsg)

            -- Advance turn
            local advanceMsg = {
                From = "test_user",
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(advanceMsg)

            assert.equals("SaveState", response.Action)
            assert.equals("true", response.Success)
            assert.equals("1", response.ExpiredCount)

            local responseData = json.decode(response.Data)
            assert.equals(1, #responseData.expiredConditions)
            assert.equals("TRICK_ROOM", responseData.expiredConditions[1].conditionType)
        end)

        it("should execute ready future attacks", function()
            -- Apply future attack with 1 turn delay
            local applyMsg = {
                From = "test_user",
                Action = "ApplyFutureAttack",
                AttackType = "FUTURE_SIGHT",
                SourceId = "196",
                TargetId = "25",
                Damage = "120",
                DelayTurns = "1",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(applyMsg)

            -- Advance turn
            local advanceMsg = {
                From = "test_user",
                Action = "AdvanceTurn",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(advanceMsg)

            assert.equals("true", response.Success)
            assert.equals("1", response.ExecutedCount)

            local responseData = json.decode(response.Data)
            assert.equals(1, #responseData.executedAttacks)
            assert.equals("FUTURE_SIGHT", responseData.executedAttacks[1].attackType)
            assert.equals(196, responseData.executedAttacks[1].sourceId)
            assert.equals(25, responseData.executedAttacks[1].targetId)
            assert.equals(120, responseData.executedAttacks[1].damage)
        end)
    end)

    describe("ProcessFieldConditionInteractions Handler", function()

        it("should handle room effect priority resolution", function()
            -- Apply multiple room effects
            local trickRoomMsg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "TRICK_ROOM",
                SourceId = "25",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }
            aolite.sendMessage(trickRoomMsg)

            local gravityMsg = {
                From = "test_user",
                Action = "ApplyFieldCondition",
                ConditionType = "GRAVITY",
                SourceId = "196",
                BattleId = testBattleId,
                Timestamp = tostring(tonumber(testTimestamp) + 1000)
            }
            aolite.sendMessage(gravityMsg)

            -- Check priority resolution
            local interactionMsg = {
                From = "test_user",
                Action = "ProcessFieldConditionInteractions",
                InteractionType = "PRIORITY",
                BattleId = testBattleId,
                Timestamp = testTimestamp
            }

            local response = aolite.sendMessage(interactionMsg)

            assert.equals("true", response.Success)

            local responseData = json.decode(response.Data)
            assert.equals(2, #responseData.interactionResults.sortedConditions)
            -- Trick Room should be first (priority 100 > Gravity priority 70)
            assert.equals("TRICK_ROOM", responseData.interactionResults.resolutionOrder[1].conditionType)
            assert.equals("GRAVITY", responseData.interactionResults.resolutionOrder[2].conditionType)
        end)
    end)

    describe("ADP Info Handler", function()

        it("should provide comprehensive process information", function()
            local msg = {
                From = "test_user",
                Action = "Info"
            }

            local response = aolite.sendMessage(msg)

            assert.equals("SaveState", response.Action)
            assert.equals("true", response.Success)

            local infoData = json.decode(response.Data)
            assert.equals("Field Condition Engine", infoData.Name)
            assert.equals("1.0", infoData.protocolVersion)
            assert.equals(7, #infoData.handlers)
            assert.is_true(infoData.capabilities.supportsFieldConditions)
            assert.is_true(infoData.capabilities.supportsFutureAttacks)
        end)
    end)

    describe("Ping Handler", function()

        it("should respond to ping with pong", function()
            local msg = {
                From = "test_user",
                Action = "Ping"
            }

            local response = aolite.sendMessage(msg)

            assert.equals("Pong", response.Action)
            assert.equals("pong", response.Data)
            assert.equals("true", response.Success)
        end)
    end)
end)

print("Field Condition Engine unit tests completed")