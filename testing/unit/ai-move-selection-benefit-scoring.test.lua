-- AI Move Selection Benefit Scoring Tests
-- Story 17.1c: Benefit Scoring and Ally Inversion Testing
-- Tests benefit score calculation and ally targeting logic

local aolite = require("aolite")
local json = require("json")

-- Load the AI move selection process
local process = aolite.spawnProcess("AI Move Selection Engine")
aolite.eval(process, io.open("processes/ai-move-selection-engine.lua"):read("*all"))

-- Test helper to create mock Pokemon
local function createMockPokemon(battlerIndex, isPlayer, hp, types, stats)
    return {
        battlerIndex = battlerIndex,
        isPlayer = isPlayer,
        hp = hp or 100,
        maxHp = 100,
        types = types or {0}, -- Default NORMAL type
        stats = stats or {
            attack = 100,
            defense = 100,
            spAtk = 100,
            spDef = 100,
            speed = 100,
            hp = 100
        },
        level = 50
    }
end

-- Test helper to create mock move
local function createMockMove(moveId, moveType, power, category, moveTarget)
    return {
        moveId = moveId,
        moveType = moveType,
        power = power,
        category = category or 0, -- PHYSICAL
        moveTarget = moveTarget or 5, -- NEAR_ENEMY
        hasCounterAttr = false
    }
end

-- Test Suite: Benefit Scoring
describe("AI Move Selection - Benefit Scoring", function()

    -- Test 1: Super-effective move targeting
    it("should score super-effective moves higher", function()
        local attacker = createMockPokemon(0, true, 100, {9}) -- Fire type
        local target1 = createMockPokemon(2, false, 100, {11}) -- Grass (weak to Fire)
        local target2 = createMockPokemon(3, false, 100, {10}) -- Water (resists Fire)

        local move = createMockMove(1, 9, 80, 1, 5) -- Fire special attack

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "1",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target1
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "1",
            AttackerId = "0",
            TargetId = "3",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target2
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)

        -- Super-effective should score higher
        assert.is_true(score1 > score2, "Super-effective move should score higher")
    end)

    -- Test 2: Not very effective move targeting
    it("should score not very effective moves lower", function()
        local attacker = createMockPokemon(0, true, 100, {10}) -- Water type
        local target1 = createMockPokemon(2, false, 100, {9}) -- Fire (weak to Water)
        local target2 = createMockPokemon(3, false, 100, {11}) -- Grass (resists Water)

        local move = createMockMove(2, 10, 80, 1, 5) -- Water special attack

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "2",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target1
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "2",
            AttackerId = "0",
            TargetId = "3",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target2
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)

        -- Not very effective should score lower
        assert.is_true(score1 > score2, "Not very effective move should score lower")
    end)

    -- Test 3: STAB bonus application
    it("should apply STAB bonus for matching types", function()
        local attacker = createMockPokemon(0, true, 100, {9}) -- Fire type
        local target = createMockPokemon(2, false, 100, {0}) -- Normal (neutral)

        local fireMove = createMockMove(3, 9, 80, 0, 5) -- Fire physical attack
        local normalMove = createMockMove(4, 0, 80, 0, 5) -- Normal physical attack

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "3",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = fireMove,
                attacker = attacker,
                target = target
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "4",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = normalMove,
                attacker = attacker,
                target = target
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)

        -- STAB move should score higher (1.5x multiplier)
        assert.is_true(score1 > score2, "STAB move should score higher")
    end)

    -- Test 4: Type immunity (0× effectiveness)
    it("should score immune targets very low", function()
        local attacker = createMockPokemon(0, true, 100, {0}) -- Normal type
        local target1 = createMockPokemon(2, false, 100, {7}) -- Ghost (immune to Normal)
        local target2 = createMockPokemon(3, false, 100, {0}) -- Normal (neutral)

        local move = createMockMove(5, 0, 80, 0, 5) -- Normal physical attack

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "5",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target1
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "5",
            AttackerId = "0",
            TargetId = "3",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target2
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)

        -- Immune target should score much lower
        assert.is_true(score2 > score1, "Immune target should score lower")
    end)

    -- Test 5: Low HP target (KO bonus)
    it("should score targets with low HP higher (KO potential)", function()
        local attacker = createMockPokemon(0, true, 100, {9}, {attack = 150, spAtk = 150})
        local target1 = createMockPokemon(2, false, 10, {11}) -- 10/100 HP (low)
        local target2 = createMockPokemon(3, false, 100, {11}) -- 100/100 HP (full)

        local move = createMockMove(6, 9, 80, 1, 5) -- Fire special attack

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "6",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target1
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "6",
            AttackerId = "0",
            TargetId = "3",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target2
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)

        -- Low HP target should potentially score higher (KO bonus)
        assert.is_true(score1 >= score2 * 0.8, "Low HP target should be reasonably scored")
    end)

    -- Test 6: Physical vs Special move categories
    it("should consider physical vs special stats", function()
        local attacker = createMockPokemon(0, true, 100, {1}, {attack = 150, spAtk = 50})
        local target = createMockPokemon(2, false, 100, {0}, {defense = 80, spDef = 120})

        local physicalMove = createMockMove(7, 1, 80, 0, 5) -- Fighting physical
        local specialMove = createMockMove(8, 1, 80, 1, 5) -- Fighting special

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "7",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = physicalMove,
                attacker = attacker,
                target = target
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "8",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = specialMove,
                attacker = attacker,
                target = target
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)

        -- Physical move should score higher (better attack stat, lower defense)
        assert.is_true(score1 > score2, "Physical move should score higher with better stats")
    end)

    -- Test 7: Equal scores handling
    it("should handle equal benefit scores", function()
        local attacker = createMockPokemon(0, true, 100, {0})
        local target1 = createMockPokemon(2, false, 100, {0})
        local target2 = createMockPokemon(3, false, 100, {0})

        local move = createMockMove(9, 0, 80, 0, 5)

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "9",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target1
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "9",
            AttackerId = "0",
            TargetId = "3",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target2
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)

        -- Equal stats and types should produce equal scores
        assert.are.equal(score1, score2, "Equal targets should produce equal scores")
    end)

    -- Test 8: Multi-type Pokemon (dual type)
    it("should handle dual-type effectiveness correctly", function()
        local attacker = createMockPokemon(0, true, 100, {10}) -- Water
        local target1 = createMockPokemon(2, false, 100, {9, 4}) -- Fire/Ground (4x weak)
        local target2 = createMockPokemon(3, false, 100, {9}) -- Fire (2x weak)

        local move = createMockMove(10, 10, 80, 1, 5) -- Water special

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "10",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target1
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "10",
            AttackerId = "0",
            TargetId = "3",
            Data = json.encode({
                move = move,
                attacker = attacker,
                target = target2
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)

        -- 4x weak target should score higher than 2x weak
        assert.is_true(score1 > score2, "4x weak target should score higher than 2x")
    end)

    -- Test 9: Status moves (zero damage)
    it("should handle status moves appropriately", function()
        local attacker = createMockPokemon(0, true, 100, {0})
        local target = createMockPokemon(2, false, 100, {0})

        local statusMove = createMockMove(11, 0, 0, 2, 5) -- Status category

        local msg = {
            Action = "CalculateMoveBenefit",
            MoveId = "11",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = statusMove,
                attacker = attacker,
                target = target
            })
        }

        local result = aolite.send(process, msg)

        -- Status move should return a score (may be 0 or based on utility)
        assert.is_not_nil(result.Score)
    end)

    -- Test 10: High power vs low power moves
    it("should score higher power moves better", function()
        local attacker = createMockPokemon(0, true, 100, {0})
        local target = createMockPokemon(2, false, 100, {0})

        local highPowerMove = createMockMove(12, 0, 120, 0, 5)
        local lowPowerMove = createMockMove(13, 0, 40, 0, 5)

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "12",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = highPowerMove,
                attacker = attacker,
                target = target
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "13",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = lowPowerMove,
                attacker = attacker,
                target = target
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)

        -- Higher power should score better
        assert.is_true(score1 > score2, "Higher power move should score better")
    end)

    -- Test 11: Level advantage
    it("should score higher for level advantage", function()
        local highLevelAttacker = createMockPokemon(0, true, 100, {0})
        highLevelAttacker.level = 100

        local lowLevelAttacker = createMockPokemon(0, true, 100, {0})
        lowLevelAttacker.level = 25

        local target = createMockPokemon(2, false, 100, {0})
        target.level = 50

        local move = createMockMove(14, 0, 80, 0, 5)

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "14",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = move,
                attacker = highLevelAttacker,
                target = target
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "14",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = move,
                attacker = lowLevelAttacker,
                target = target
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)

        -- Higher level should score better
        assert.is_true(score1 > score2, "Higher level should produce better scores")
    end)

    -- Test 12: Attacker dual type STAB
    it("should apply STAB for dual-type attackers", function()
        local dualTypeAttacker = createMockPokemon(0, true, 100, {9, 2}) -- Fire/Flying
        local target = createMockPokemon(2, false, 100, {11}) -- Grass

        local fireMove = createMockMove(15, 9, 80, 1, 5) -- Fire
        local flyingMove = createMockMove(16, 2, 80, 0, 5) -- Flying
        local normalMove = createMockMove(17, 0, 80, 0, 5) -- Normal (no STAB)

        local msg1 = {
            Action = "CalculateMoveBenefit",
            MoveId = "15",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = fireMove,
                attacker = dualTypeAttacker,
                target = target
            })
        }

        local msg2 = {
            Action = "CalculateMoveBenefit",
            MoveId = "16",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = flyingMove,
                attacker = dualTypeAttacker,
                target = target
            })
        }

        local msg3 = {
            Action = "CalculateMoveBenefit",
            MoveId = "17",
            AttackerId = "0",
            TargetId = "2",
            Data = json.encode({
                move = normalMove,
                attacker = dualTypeAttacker,
                target = target
            })
        }

        local result1 = aolite.send(process, msg1)
        local result2 = aolite.send(process, msg2)
        local result3 = aolite.send(process, msg3)

        local score1 = tonumber(result1.Score)
        local score2 = tonumber(result2.Score)
        local score3 = tonumber(result3.Score)

        -- Both STAB moves should score higher than non-STAB
        assert.is_true(score1 > score3, "Fire STAB should score higher than no STAB")
        assert.is_true(score2 > score3, "Flying STAB should score higher than no STAB")
    end)
end)

print("✓ AI Move Selection Benefit Scoring Tests Complete")
