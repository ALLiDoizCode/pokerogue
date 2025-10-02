-- AI Move Selection Weight Normalization Tests
-- Story 17.1c: Weight Normalization and Probabilistic Selection Testing
-- Tests Phase 5-6 of getNextTargets algorithm

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

-- Test Suite: Weight Normalization and Selection
describe("AI Move Selection - Weight Normalization", function()

    -- Test 1: Weight normalization when lowest < 1
    it("should normalize weights when lowest weight < 1", function()
        -- Create scenario where benefit scores produce weights < 1
        local attacker = createMockPokemon(0, true, 100, {0})
        local opponents = {
            createMockPokemon(2, false, 100, {7}), -- Ghost (immune to Normal)
            createMockPokemon(3, false, 100, {5})  -- Rock (resistant to Normal)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "1",
            AiType = "2", -- SMART
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                movePool = {
                    {moveId = 1, moveType = 0, power = 80, category = 0, moveTarget = 5, hasCounterAttr = false}
                }
            })
        }

        local result = aolite.send(process, msg)

        -- Should successfully select a target even with low scores
        assert.are.equal("true", result.Success)
        assert.is_not_nil(result.Targets)
    end)

    -- Test 2: Cutoff application (remove < maxWeight/2)
    it("should filter out targets below half max weight", function()
        local attacker = createMockPokemon(0, true, 100, {9}) -- Fire
        local opponents = {
            createMockPokemon(2, false, 100, {11}), -- Grass (super effective, 2x)
            createMockPokemon(3, false, 100, {10})  -- Water (not effective, 0.5x)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "1",
            AiType = "2", -- SMART
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                movePool = {
                    {moveId = 1, moveType = 9, power = 80, category = 1, moveTarget = 5, hasCounterAttr = false}
                }
            })
        }

        local result = aolite.send(process, msg)
        local targets = json.decode(result.Targets)

        -- Should likely select the Grass target (higher weight)
        assert.are.equal("true", result.Success)
        assert.are.equal(1, #targets)
    end)

    -- Test 3: Single target after cutoff
    it("should handle single target remaining after cutoff", function()
        local attacker = createMockPokemon(0, true, 100, {12}) -- Electric
        local opponents = {
            createMockPokemon(2, false, 100, {10}), -- Water (super effective)
            createMockPokemon(3, false, 100, {4})   -- Ground (immune)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "1",
            AiType = "2",
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                movePool = {
                    {moveId = 1, moveType = 12, power = 80, category = 1, moveTarget = 5, hasCounterAttr = false}
                }
            })
        }

        local result = aolite.send(process, msg)
        local targets = json.decode(result.Targets)

        -- Should select the Water target (only viable option)
        assert.are.equal("true", result.Success)
        assert.are.equal(1, #targets)
        assert.are.equal(2, targets[1]) -- Water target index
    end)

    -- Test 4: Multiple targets surviving cutoff
    it("should handle multiple targets above cutoff threshold", function()
        local attacker = createMockPokemon(0, true, 100, {10}) -- Water
        local opponents = {
            createMockPokemon(2, false, 100, {9}), -- Fire (super effective, 2x)
            createMockPokemon(3, false, 100, {4})  -- Ground (super effective, 2x)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "1",
            AiType = "2",
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                movePool = {
                    {moveId = 1, moveType = 10, power = 80, category = 1, moveTarget = 5, hasCounterAttr = false}
                }
            })
        }

        local result = aolite.send(process, msg)

        -- Both targets should be viable
        assert.are.equal("true", result.Success)
    end)

    -- Test 5: Probabilistic selection distribution
    it("should use probabilistic selection with battle seed", function()
        local attacker = createMockPokemon(0, true, 100, {0})
        local opponents = {
            createMockPokemon(2, false, 100, {0}),
            createMockPokemon(3, false, 100, {0})
        }

        -- Run with same seed multiple times - should get same result
        local targets = {}
        for i = 1, 3 do
            local msg = {
                Action = "EvaluateMoveSelection",
                PokemonId = "1",
                AiType = "2",
                BattleSeed = "54321", -- Fixed seed
                Data = json.encode({
                    attacker = attacker,
                    opponents = opponents,
                    movePool = {
                        {moveId = 1, moveType = 0, power = 80, category = 0, moveTarget = 5, hasCounterAttr = false}
                    }
                })
            }

            local result = aolite.send(process, msg)
            table.insert(targets, json.decode(result.Targets)[1])
        end

        -- With same seed, should always select same target
        assert.are.equal(targets[1], targets[2])
        assert.are.equal(targets[2], targets[3])
    end)

    -- Test 6: All weights equal
    it("should handle all equal weights", function()
        local attacker = createMockPokemon(0, true, 100, {0})
        local opponents = {
            createMockPokemon(2, false, 100, {0}),
            createMockPokemon(3, false, 100, {0}),
            createMockPokemon(4, false, 100, {0})
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "1",
            AiType = "2",
            BattleSeed = "99999",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                movePool = {
                    {moveId = 1, moveType = 0, power = 80, category = 0, moveTarget = 5, hasCounterAttr = false}
                }
            })
        }

        local result = aolite.send(process, msg)
        local targets = json.decode(result.Targets)

        -- Should select one target successfully
        assert.are.equal("true", result.Success)
        assert.are.equal(1, #targets)
    end)

    -- Test 7: One weight dominates (>2× others)
    it("should heavily favor dominating weight", function()
        local attacker = createMockPokemon(0, true, 100, {9}) -- Fire
        local opponents = {
            createMockPokemon(2, false, 10, {11}), -- Grass, low HP (high priority)
            createMockPokemon(3, false, 100, {0})  -- Normal, full HP (low priority)
        }

        -- Run multiple times with different seeds
        local grassTargetCount = 0
        for i = 1, 10 do
            local msg = {
                Action = "EvaluateMoveSelection",
                PokemonId = "1",
                AiType = "2",
                BattleSeed = tostring(i * 1234),
                Data = json.encode({
                    attacker = attacker,
                    opponents = opponents,
                    movePool = {
                        {moveId = 1, moveType = 9, power = 80, category = 1, moveTarget = 5, hasCounterAttr = false}
                    }
                })
            }

            local result = aolite.send(process, msg)
            local targets = json.decode(result.Targets)

            if targets[1] == 2 then
                grassTargetCount = grassTargetCount + 1
            end
        end

        -- Should favor low HP Grass target most of the time
        assert.is_true(grassTargetCount >= 7, "Should favor high-value target in most cases")
    end)

    -- Test 8: Random seed determinism
    it("should produce deterministic results with fixed seed", function()
        local attacker = createMockPokemon(0, true, 100, {1}) -- Fighting
        local opponents = {
            createMockPokemon(2, false, 100, {0}), -- Normal
            createMockPokemon(3, false, 100, {8})  -- Steel
        }

        local seed = "42424242"
        local results = {}

        -- Run same scenario 5 times with same seed
        for i = 1, 5 do
            local msg = {
                Action = "EvaluateMoveSelection",
                PokemonId = "1",
                AiType = "2",
                BattleSeed = seed,
                Data = json.encode({
                    attacker = attacker,
                    opponents = opponents,
                    movePool = {
                        {moveId = 1, moveType = 1, power = 80, category = 0, moveTarget = 5, hasCounterAttr = false}
                    }
                })
            }

            local result = aolite.send(process, msg)
            table.insert(results, json.decode(result.Targets)[1])
        end

        -- All results should be identical
        for i = 2, #results do
            assert.are.equal(results[1], results[i], "Same seed should produce same result")
        end
    end)

    -- Test 9: Negative benefit scores normalization
    it("should handle negative benefit scores", function()
        local attacker = createMockPokemon(0, true, 100, {13}) -- Psychic
        local opponents = {
            createMockPokemon(2, false, 100, {16}), -- Dark (immune, 0x)
            createMockPokemon(3, false, 100, {8})   -- Steel (not effective, 0.5x)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "1",
            AiType = "2",
            BattleSeed = "11111",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                movePool = {
                    {moveId = 1, moveType = 13, power = 80, category = 1, moveTarget = 5, hasCounterAttr = false}
                }
            })
        }

        local result = aolite.send(process, msg)

        -- Should still select a target despite poor matchups
        assert.are.equal("true", result.Success)
    end)

    -- Test 10: Edge case - empty weight list after cutoff
    it("should handle all weights filtered by cutoff", function()
        -- This is an edge case that shouldn't happen often but must be handled
        local attacker = createMockPokemon(0, true, 100, {0})
        local opponents = {
            createMockPokemon(2, false, 100, {7}) -- Ghost (immune to Normal)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "1",
            AiType = "2",
            BattleSeed = "77777",
            Data = json.encode({
                attacker = attacker,
                opponents = opponents,
                movePool = {
                    {moveId = 1, moveType = 0, power = 80, category = 0, moveTarget = 5, hasCounterAttr = false}
                }
            })
        }

        local result = aolite.send(process, msg)

        -- Should still produce a result (possibly struggle or best available)
        assert.are.equal("true", result.Success)
    end)
end)

print("✓ AI Move Selection Weight Normalization Tests Complete")
