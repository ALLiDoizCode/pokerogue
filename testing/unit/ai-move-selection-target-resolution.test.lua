-- AI Move Selection Target Resolution Tests
-- Story 17.1c: Target Selection Testing
-- Tests getMoveTargets() for all 19 MoveTarget enum values

local aolite = require("aolite")
local json = require("json")

-- Load the AI move selection process
local process = aolite.spawnProcess("AI Move Selection Engine")
aolite.eval(process, io.open("processes/ai-move-selection-engine.lua"):read("*all"))

-- Test helper to create mock Pokemon
local function createMockPokemon(battlerIndex, isPlayer, hp, types)
    return {
        battlerIndex = battlerIndex,
        isPlayer = isPlayer,
        hp = hp or 100,
        maxHp = 100,
        types = types or {0} -- Default NORMAL type
    }
end

-- Test Suite: Target Resolution (19 MoveTarget types)
describe("AI Move Selection - Target Resolution", function()

    -- Test 1: USER - Self-targeting
    it("should target self for USER moves (Swords Dance)", function()
        local attacker = createMockPokemon(0, true, 100, {9}) -- Fire type
        local opponents = {createMockPokemon(2, false, 100, {10})}

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "1",
            MoveTarget = "0", -- USER
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(1, #response.Targets)
        assert.are.equal(0, response.Targets[1]) -- Attacker's index
        assert.are.equal("false", result.Multiple)
    end)

    -- Test 2: OTHER - Single opponent selection
    it("should target opponents for OTHER moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {
            createMockPokemon(2, false, 100),
            createMockPokemon(3, false, 100)
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "2",
            MoveTarget = "1", -- OTHER
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        -- Should return both opponents as potential targets
        assert.are.equal(2, #response.Targets)
        assert.are.equal("false", result.Multiple) -- Single-target selection
    end)

    -- Test 3: ALL_OTHERS - Multi-target excluding user
    it("should target all others for ALL_OTHERS moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {createMockPokemon(2, false, 100)}
        local ally = createMockPokemon(1, true, 100)

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "3",
            MoveTarget = "2", -- ALL_OTHERS
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                ally = ally
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(2, #response.Targets) -- Opponent + ally
        assert.are.equal("true", result.Multiple)
    end)

    -- Test 4: NEAR_ENEMY - Default single enemy target
    it("should target single enemy for NEAR_ENEMY moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {
            createMockPokemon(2, false, 100),
            createMockPokemon(3, false, 100)
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "4",
            MoveTarget = "5", -- NEAR_ENEMY
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(2, #response.Targets) -- Both potential targets
        assert.are.equal("false", result.Multiple) -- Single-target selection
    end)

    -- Test 5: ALL_ENEMIES - All enemies (Earthquake)
    it("should target all enemies for ALL_ENEMIES moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {
            createMockPokemon(2, false, 100),
            createMockPokemon(3, false, 100)
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "5",
            MoveTarget = "8", -- ALL_ENEMIES
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(2, #response.Targets)
        assert.are.equal("true", result.Multiple)
    end)

    -- Test 6: ATTACKER - Counter move targeting
    it("should return ATTACKER (-1) for counter moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {createMockPokemon(2, false, 100)}

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "6",
            MoveTarget = "9", -- ATTACKER
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(1, #response.Targets)
        assert.are.equal(-1, response.Targets[1]) -- BattlerIndex.ATTACKER
        assert.are.equal("false", result.Multiple)
    end)

    -- Test 7: ALLY - Ally targeting (Helping Hand)
    it("should target ally for ALLY moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {createMockPokemon(2, false, 100)}
        local ally = createMockPokemon(1, true, 100)

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "7",
            MoveTarget = "11", -- ALLY
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                ally = ally
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(1, #response.Targets)
        assert.are.equal(1, response.Targets[1]) -- Ally's index
        assert.are.equal("false", result.Multiple)
    end)

    -- Test 8: USER_AND_ALLIES - Self + all allies
    it("should target self and allies for USER_AND_ALLIES moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {createMockPokemon(2, false, 100)}
        local ally = createMockPokemon(1, true, 100)

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "8",
            MoveTarget = "13", -- USER_AND_ALLIES
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                ally = ally
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(2, #response.Targets) -- Self + ally
        assert.are.equal("true", result.Multiple)
    end)

    -- Test 9: ALL - Everyone on field
    it("should target everyone for ALL moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {
            createMockPokemon(2, false, 100),
            createMockPokemon(3, false, 100)
        }
        local ally = createMockPokemon(1, true, 100)

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "9",
            MoveTarget = "14", -- ALL
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                ally = ally
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(4, #response.Targets) -- All 4 Pokemon
        assert.are.equal("true", result.Multiple)
    end)

    -- Test 10: CURSE - Type-dependent targeting (Ghost vs non-Ghost)
    it("should target self for non-Ghost CURSE moves", function()
        local attacker = createMockPokemon(0, true, 100, {0}) -- NORMAL type
        local opponents = {createMockPokemon(2, false, 100)}

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "10",
            MoveTarget = "19", -- CURSE
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(1, #response.Targets)
        assert.are.equal(0, response.Targets[1]) -- Self
    end)

    -- Test 11: CURSE - Ghost type targets opponents
    it("should target opponents for Ghost CURSE moves", function()
        local attacker = createMockPokemon(0, true, 100, {7}) -- GHOST type
        local opponents = {createMockPokemon(2, false, 100)}

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "11",
            MoveTarget = "19", -- CURSE
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(1, #response.Targets)
        assert.are.equal(2, response.Targets[1]) -- Opponent
    end)

    -- Test 12: RANDOM_NEAR_ENEMY - Random enemy selection (deterministic with seed)
    it("should select random enemy deterministically for RANDOM_NEAR_ENEMY", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {
            createMockPokemon(2, false, 100),
            createMockPokemon(3, false, 100)
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "12",
            MoveTarget = "7", -- RANDOM_NEAR_ENEMY
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(1, #response.Targets) -- Single random target
        assert.are.equal("false", result.Multiple)
    end)

    -- Test 13: Empty opponent list handling
    it("should return empty targets for no opponents", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {}

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "13",
            MoveTarget = "5", -- NEAR_ENEMY
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(0, #response.Targets)
    end)

    -- Test 14: Inactive Pokemon filtering
    it("should filter out fainted Pokemon (hp = 0)", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {
            createMockPokemon(2, false, 0), -- Fainted
            createMockPokemon(3, false, 100) -- Active
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "14",
            MoveTarget = "8", -- ALL_ENEMIES
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(1, #response.Targets) -- Only active opponent
        assert.are.equal(3, response.Targets[1])
    end)

    -- Test 15: USER_SIDE - User's side (Reflect)
    it("should target user side for USER_SIDE moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {createMockPokemon(2, false, 100)}
        local ally = createMockPokemon(1, true, 100)

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "15",
            MoveTarget = "15", -- USER_SIDE
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                ally = ally
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(2, #response.Targets) -- Self + ally
        assert.are.equal("true", result.Multiple)
    end)

    -- Test 16: ENEMY_SIDE - Enemy's side (Stealth Rock)
    it("should target enemy side for ENEMY_SIDE moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {
            createMockPokemon(2, false, 100),
            createMockPokemon(3, false, 100)
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "16",
            MoveTarget = "16", -- ENEMY_SIDE
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(2, #response.Targets)
        assert.are.equal("true", result.Multiple)
    end)

    -- Test 17: PARTY - Self (special case)
    it("should target self for PARTY moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {createMockPokemon(2, false, 100)}

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "17",
            MoveTarget = "18", -- PARTY
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(1, #response.Targets)
        assert.are.equal(0, response.Targets[1])
    end)

    -- Test 18: ALL_NEAR_ENEMIES - Adjacent enemies in doubles
    it("should target adjacent enemies for ALL_NEAR_ENEMIES", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {
            createMockPokemon(2, false, 100),
            createMockPokemon(3, false, 100)
        }

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "18",
            MoveTarget = "6", -- ALL_NEAR_ENEMIES
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(2, #response.Targets)
        assert.are.equal("true", result.Multiple)
    end)

    -- Test 19: BOTH_SIDES - Both sides (Trick Room)
    it("should target both sides for BOTH_SIDES moves", function()
        local attacker = createMockPokemon(0, true, 100)
        local opponents = {createMockPokemon(2, false, 100)}
        local ally = createMockPokemon(1, true, 100)

        local msg = {
            Action = "GetMoveTargets",
            MoveId = "19",
            MoveTarget = "17", -- BOTH_SIDES
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                ally = ally
            })
        }

        local result = aolite.send(process, msg)
        local response = json.decode(result.Data)

        assert.are.equal(3, #response.Targets) -- Self + ally + opponent
        assert.are.equal("true", result.Multiple)
    end)
end)

print("✓ AI Move Selection Target Resolution Tests Complete")
