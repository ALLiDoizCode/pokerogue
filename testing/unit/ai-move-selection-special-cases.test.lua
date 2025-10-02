-- AI Move Selection Special Cases Tests
-- Story 17.1c: Edge Cases and Special Scenarios Testing
-- Tests counter moves, empty targets, multi-target, and special conditions

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
        types = types or {0},
        stats = stats or {attack = 100, defense = 100, spAtk = 100, spDef = 100},
        level = 50
    }
end

-- Test Suite: Special Cases
describe("AI Move Selection - Special Cases", function()

    -- Test 1: Counter move with no targets → ATTACKER
    it("should return ATTACKER (-1) for counter moves with no valid targets", function()
        local attacker = createMockPokemon(0, true, 100, {1})
        local opponents = {} -- No opponents

        local counterMove = {
            moveId = 1,
            moveType = 1,
            power = 60,
            category = 0,
            moveTarget = 5,
            hasCounterAttr = true
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "1",
            AiType = "2",
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                movePool = {counterMove}
            })
        }

        local result = aolite.send(process, msg)
        local targets = json.decode(result.Targets)

        -- Counter move with no targets should return ATTACKER
        assert.are.equal("true", result.Success)
        assert.are.equal(1, #targets)
        assert.are.equal(-1, targets[1]) -- BattlerIndex.ATTACKER
    end)

    -- Test 2: Empty target list → empty array or fallback
    it("should handle empty target list gracefully", function()
        local attacker = createMockPokemon(0, true, 100, {0})
        local opponents = {} -- No opponents

        local normalMove = {
            moveId = 2,
            moveType = 0,
            power = 80,
            category = 0,
            moveTarget = 5,
            hasCounterAttr = false
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "1",
            AiType = "2",
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                movePool = {normalMove}
            })
        }

        local result = aolite.send(process, msg)

        -- Should handle gracefully (may select Struggle or return empty)
        assert.are.equal("true", result.Success)
    end)

    -- Test 3: Multi-target immediate return (Earthquake)
    it("should immediately return all targets for multi-target moves", function()
        local attacker = createMockPokemon(0, true, 100, {4}) -- Ground
        local opponents = {
            createMockPokemon(2, false, 100, {12}), -- Electric
            createMockPokemon(3, false, 100, {9})   -- Fire
        }

        local earthquakeMove = {
            moveId = 3,
            moveType = 4,
            power = 100,
            category = 0,
            moveTarget = 8, -- ALL_ENEMIES
            hasCounterAttr = false
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "3",
            MoveTarget = "8", -- ALL_ENEMIES
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local targets = json.decode(json.decode(result.Data).Targets)

        -- Should return all opponent targets
        assert.are.equal("true", result.Multiple)
        assert.are.equal(2, #targets)
    end)

    -- Test 4: Double battle vs single battle targeting
    it("should handle double battle targeting correctly", function()
        local attacker = createMockPokemon(0, true, 100, {10})
        local opponents = {
            createMockPokemon(2, false, 100, {9}),
            createMockPokemon(3, false, 100, {9})
        }
        local ally = createMockPokemon(1, true, 100, {11})

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "4",
            MoveTarget = "5", -- NEAR_ENEMY
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                ally = ally
            })
        }

        local result = aolite.send(process, msg)
        local data = json.decode(result.Data)
        local targets = json.decode(data.Targets)

        -- Should target enemies only, not ally
        assert.are.equal(2, #targets)
        for _, targetIndex in ipairs(targets) do
            assert.is_true(targetIndex >= 2, "Should only target enemies")
        end
    end)

    -- Test 5: Ally presence/absence handling
    it("should handle ally presence correctly", function()
        local attacker = createMockPokemon(0, true, 100, {0})
        local opponents = {createMockPokemon(2, false, 100, {0})}
        local ally = createMockPokemon(1, true, 100, {0})

        -- Test with ally present
        local msg1 = {
            Action = "GetMoveTargets",
            MoveId = "5",
            MoveTarget = "11", -- ALLY
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                ally = ally
            })
        }

        local result1 = aolite.send(process, msg1)
        local data1 = json.decode(result1.Data)
        local targets1 = json.decode(data1.Targets)

        assert.are.equal(1, #targets1)
        assert.are.equal(1, targets1[1]) -- Ally index

        -- Test without ally
        local msg2 = {
            Action = "GetMoveTargets",
            MoveId = "5",
            MoveTarget = "11", -- ALLY
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
                -- No ally
            })
        }

        local result2 = aolite.send(process, msg2)
        local data2 = json.decode(result2.Data)
        local targets2 = json.decode(data2.Targets)

        assert.are.equal(0, #targets2) -- No ally to target
    end)

    -- Test 6: Self-targeting moves (USER)
    it("should correctly handle self-targeting moves", function()
        local attacker = createMockPokemon(0, true, 100, {1})
        local opponents = {createMockPokemon(2, false, 100, {0})}

        local selfBuffMove = {
            moveId = 6,
            moveType = 1,
            power = 0,
            category = 2, -- STATUS
            moveTarget = 0, -- USER
            hasCounterAttr = false
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "6",
            MoveTarget = "0", -- USER
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local data = json.decode(result.Data)
        local targets = json.decode(data.Targets)

        assert.are.equal(1, #targets)
        assert.are.equal(0, targets[1]) -- Self
        assert.are.equal("false", result.Multiple)
    end)

    -- Test 7: All fainted opponents
    it("should handle all fainted opponents", function()
        local attacker = createMockPokemon(0, true, 100, {0})
        local opponents = {
            createMockPokemon(2, false, 0, {0}), -- Fainted
            createMockPokemon(3, false, 0, {0})  -- Fainted
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "7",
            MoveTarget = "5", -- NEAR_ENEMY
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local data = json.decode(result.Data)
        local targets = json.decode(data.Targets)

        -- No active targets
        assert.are.equal(0, #targets)
    end)

    -- Test 8: Mixed active and fainted opponents
    it("should filter out fainted opponents from target list", function()
        local attacker = createMockPokemon(0, true, 100, {10})
        local opponents = {
            createMockPokemon(2, false, 0, {9}),   -- Fainted
            createMockPokemon(3, false, 100, {9}), -- Active
            createMockPokemon(4, false, 0, {9})    -- Fainted
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "8",
            MoveTarget = "8", -- ALL_ENEMIES
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local data = json.decode(result.Data)
        local targets = json.decode(data.Targets)

        -- Only active opponent
        assert.are.equal(1, #targets)
        assert.are.equal(3, targets[1])
    end)

    -- Test 9: Field-wide moves (USER_SIDE, ENEMY_SIDE)
    it("should handle field-wide targeting moves", function()
        local attacker = createMockPokemon(0, true, 100, {13})
        local opponents = {
            createMockPokemon(2, false, 100, {0}),
            createMockPokemon(3, false, 100, {0})
        }
        local ally = createMockPokemon(1, true, 100, {0})

        -- Test USER_SIDE
        local msg1 = {
            Action = "GetMoveTargets",
            MoveId = "9",
            MoveTarget = "15", -- USER_SIDE
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                ally = ally
            })
        }

        local result1 = aolite.send(process, msg1)
        local data1 = json.decode(result1.Data)
        local targets1 = json.decode(data1.Targets)

        -- Should target user's side (self + ally)
        assert.are.equal(2, #targets1)
        assert.are.equal("true", result1.Multiple)

        -- Test ENEMY_SIDE
        local msg2 = {
            Action = "GetMoveTargets",
            MoveId = "10",
            MoveTarget = "16", -- ENEMY_SIDE
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                ally = ally
            })
        }

        local result2 = aolite.send(process, msg2)
        local data2 = json.decode(result2.Data)
        local targets2 = json.decode(data2.Targets)

        -- Should target enemy side (all opponents)
        assert.are.equal(2, #targets2)
        assert.are.equal("true", result2.Multiple)
    end)

    -- Test 10: CURSE move with type-dependent targeting
    it("should handle CURSE move type-dependent targeting", function()
        -- Non-Ghost attacker
        local normalAttacker = createMockPokemon(0, true, 100, {0})
        local opponents1 = {createMockPokemon(2, false, 100, {0})}

        local msg1 = {
            Action = "GetMoveTargets",
            MoveId = "11",
            MoveTarget = "19", -- CURSE
            BattleSeed = "12345",
            Data = json.encode({
                attacker = normalAttacker,
                opponents = opponents1
            })
        }

        local result1 = aolite.send(process, msg1)
        local data1 = json.decode(result1.Data)
        local targets1 = json.decode(data1.Targets)

        -- Non-Ghost should target self
        assert.are.equal(1, #targets1)
        assert.are.equal(0, targets1[1])

        -- Ghost attacker
        local ghostAttacker = createMockPokemon(0, true, 100, {7}) -- Ghost
        local opponents2 = {createMockPokemon(2, false, 100, {0})}

        local msg2 = {
            Action = "GetMoveTargets",
            MoveId = "11",
            MoveTarget = "19", -- CURSE
            BattleSeed = "12345",
            Data = json.encode({
                attacker = ghostAttacker,
                opponents = opponents2
            })
        }

        local result2 = aolite.send(process, msg2)
        local data2 = json.decode(result2.Data)
        local targets2 = json.decode(data2.Targets)

        -- Ghost should target opponents
        assert.are.equal(1, #targets2)
        assert.are.equal(2, targets2[1])
    end)
end)

print("✓ AI Move Selection Special Cases Tests Complete")
