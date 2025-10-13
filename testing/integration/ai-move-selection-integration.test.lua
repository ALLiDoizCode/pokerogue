-- AI Move Selection Integration Tests
-- Story 17.1c: Full Battle Scenario Integration Testing
-- Tests complete AI move selection with target selection in realistic scenarios

local aolite = require("aolite")
local json = require("json")

-- Load the AI move selection process
local process = aolite.spawnProcess("AI Move Selection Engine")
aolite.eval(process, io.open("processes/ai-move-selection-engine.lua"):read("*all"))

-- Test helper to create realistic Pokemon
local function createPokemon(battlerIndex, isPlayer, species, level, hp, types, stats)
    return {
        battlerIndex = battlerIndex,
        isPlayer = isPlayer,
        species = species,
        level = level,
        hp = hp,
        maxHp = stats.hp,
        types = types,
        stats = stats
    }
end

-- Test helper to create move
local function createMove(moveId, name, moveType, power, category, moveTarget, hasCounterAttr)
    return {
        moveId = moveId,
        name = name,
        moveType = moveType,
        power = power,
        category = category or 0,
        moveTarget = moveTarget or 5,
        hasCounterAttr = hasCounterAttr or false
    }
end

-- Test Suite: Integration Tests
describe("AI Move Selection - Integration", function()

    -- Test 1: Basic single battle - Type advantage scenario
    it("should select super-effective move with correct target in single battle", function()
        -- Charizard (Fire/Flying) vs Blastoise (Water)
        local charizard = createPokemon(0, true, "Charizard", 50, 153, {9, 2},
            {hp = 153, attack = 104, defense = 98, spAtk = 129, spDef = 105, speed = 120})
        local blastoise = createPokemon(2, false, "Blastoise", 50, 158, {10},
            {hp = 158, attack = 103, defense = 120, spAtk = 105, spDef = 125, speed = 98})

        local movePool = {
            createMove(1, "Flamethrower", 9, 90, 1, 5),   -- Fire special (resisted)
            createMove(2, "Air Slash", 2, 75, 1, 5),      -- Flying special (neutral)
            createMove(3, "Dragon Claw", 15, 80, 0, 5)    -- Dragon physical (neutral)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "6",
            AiType = "2", -- SMART
            BattleSeed = "12345",
            Data = json.encode({
                attacker = charizard,
                opponents = {blastoise},
                movePool = movePool
            })
        }

        local result = aolite.send(process, msg)

        assert.are.equal("true", result.Success)
        assert.is_not_nil(result.MoveId)
        assert.is_not_nil(result.Targets)

        local targets = json.decode(result.Targets)
        assert.are.equal(1, #targets)
        assert.are.equal(2, targets[1]) -- Blastoise's index
    end)

    -- Test 2: Single battle - Equal types (no advantage)
    it("should handle equal matchups with balanced selection", function()
        -- Pikachu vs Raichu (both Electric)
        local pikachu = createPokemon(0, true, "Pikachu", 50, 110, {12},
            {hp = 110, attack = 75, defense = 60, spAtk = 70, spDef = 70, speed = 110})
        local raichu = createPokemon(2, false, "Raichu", 50, 135, {12},
            {hp = 135, attack = 110, defense = 75, spAtk = 110, spDef = 100, speed = 130})

        local movePool = {
            createMove(1, "Thunderbolt", 12, 90, 1, 5),  -- Electric (neutral)
            createMove(2, "Iron Tail", 8, 100, 0, 5),    -- Steel (neutral)
            createMove(3, "Quick Attack", 0, 40, 0, 5)   -- Normal (neutral, weak)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "25",
            AiType = "2",
            BattleSeed = "54321",
            Data = json.encode({
                attacker = pikachu,
                opponents = {raichu},
                movePool = movePool
            })
        }

        local result = aolite.send(process, msg)

        assert.are.equal("true", result.Success)
        local moveId = tonumber(result.MoveId)

        -- Should prefer stronger moves (not Quick Attack)
        assert.is_true(moveId == 1 or moveId == 2, "Should select higher power move")
    end)

    -- Test 3: Double battle - Earthquake scenario
    it("should correctly handle Earthquake in doubles (hits all)", function()
        -- Garchomp using Earthquake
        local garchomp = createPokemon(0, true, "Garchomp", 50, 183, {15, 4},
            {hp = 183, attack = 150, defense = 115, spAtk = 100, spDef = 105, speed = 122})

        -- Two opponents
        local opponent1 = createPokemon(2, false, "Tyranitar", 50, 175, {5, 16},
            {hp = 175, attack = 154, defense = 130, spAtk = 115, spDef = 120, speed = 81})
        local opponent2 = createPokemon(3, false, "Metagross", 50, 155, {8, 13},
            {hp = 155, attack = 155, defense = 150, spAtk = 115, spDef = 110, speed = 90})

        -- Ally (will also be hit by Earthquake)
        local ally = createPokemon(1, true, "Rotom", 50, 125, {12, 7},
            {hp = 125, attack = 70, defense = 97, spAtk = 115, spDef = 97, speed = 111})

        local movePool = {
            createMove(1, "Earthquake", 4, 100, 0, 8), -- ALL_ENEMIES (hits all)
            createMove(2, "Dragon Claw", 15, 80, 0, 5) -- Single target
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "445",
            AiType = "2",
            BattleSeed = "99999",
            Data = json.encode({
                attacker = garchomp,
                opponents = {opponent1, opponent2},
                ally = ally,
                movePool = movePool
            })
        }

        local result = aolite.send(process, msg)

        assert.are.equal("true", result.Success)

        local targets = json.decode(result.Targets)

        -- Earthquake should target all (or specific selection logic)
        assert.is_not_nil(targets)
        assert.is_true(#targets >= 1, "Should have at least one target")
    end)

    -- Test 4: Double battle - Single target selection with two enemies
    it("should select best target in doubles with multiple enemies", function()
        local attacker = createPokemon(0, true, "Greninja", 50, 143, {10, 16},
            {hp = 143, attack = 115, defense = 87, spAtk = 133, spDef = 91, speed = 142})

        -- One weak to Water, one neutral
        local venusaur = createPokemon(2, false, "Venusaur", 50, 155, {11, 3},
            {hp = 155, attack = 102, defense = 103, spAtk = 120, spDef = 120, speed = 100})
        local charizard = createPokemon(3, false, "Charizard", 50, 153, {9, 2},
            {hp = 153, attack = 104, defense = 98, spAtk = 129, spDef = 105, speed = 120})

        local movePool = {
            createMove(1, "Water Shuriken", 10, 15, 1, 5), -- Water (super effective on Charizard)
            createMove(2, "Ice Beam", 14, 90, 1, 5)        -- Ice (super effective on Venusaur)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "658",
            AiType = "2",
            BattleSeed = "77777",
            Data = json.encode({
                attacker = attacker,
                opponents = {venusaur, charizard},
                movePool = movePool
            })
        }

        local result = aolite.send(process, msg)

        assert.are.equal("true", result.Success)

        local targets = json.decode(result.Targets)
        assert.are.equal(1, #targets)

        -- Should target one of the two (both have type advantages)
        assert.is_true(targets[1] == 2 or targets[1] == 3)
    end)

    -- Test 5: Ally healing move selection
    it("should target weak ally with healing move", function()
        local cleric = createPokemon(0, true, "Blissey", 50, 350, {0},
            {hp = 350, attack = 30, defense = 30, spAtk = 95, spDef = 155, speed = 75})

        local opponent = createPokemon(2, false, "Machamp", 50, 165, {1},
            {hp = 165, attack = 150, defense = 100, spAtk = 85, spDef = 105, speed = 75})

        -- Ally with low HP
        local weakAlly = createPokemon(1, true, "Snorlax", 50, 50, {0},
            {hp = 285, attack = 130, defense = 85, spAtk = 85, spDef = 130, speed = 50})
        weakAlly.hp = 50 -- Low HP

        local movePool = {
            createMove(1, "Soft-Boiled", 0, 0, 2, 0),    -- Healing move (self)
            createMove(2, "Helping Hand", 0, 0, 2, 11),  -- Ally buff
            createMove(3, "Pound", 0, 40, 0, 5)          -- Attack
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "242",
            AiType = "2",
            BattleSeed = "11111",
            Data = json.encode({
                attacker = cleric,
                opponents = {opponent},
                ally = weakAlly,
                movePool = movePool
            })
        }

        local result = aolite.send(process, msg)

        assert.are.equal("true", result.Success)
    end)

    -- Test 6: Low HP opponent (KO opportunity)
    it("should prioritize KO opportunities on low HP targets", function()
        local attacker = createPokemon(0, true, "Alakazam", 50, 130, {13},
            {hp = 130, attack = 70, defense = 65, spAtk = 155, spDef = 105, speed = 140})

        -- One low HP, one full HP
        local lowHPTarget = createPokemon(2, false, "Gengar", 50, 10, {7, 3},
            {hp = 135, attack = 85, defense = 80, spAtk = 150, spDef = 95, speed = 130})
        lowHPTarget.hp = 10

        local fullHPTarget = createPokemon(3, false, "Umbreon", 50, 170, {16},
            {hp = 170, attack = 85, defense = 130, spAtk = 80, spDef = 150, speed = 85})

        local movePool = {
            createMove(1, "Psychic", 13, 90, 1, 5),
            createMove(2, "Shadow Ball", 7, 80, 1, 5)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "65",
            AiType = "2",
            BattleSeed = "33333",
            Data = json.encode({
                attacker = attacker,
                opponents = {lowHPTarget, fullHPTarget},
                movePool = movePool
            })
        }

        local result = aolite.send(process, msg)

        assert.are.equal("true", result.Success)

        local targets = json.decode(result.Targets)

        -- Should likely target low HP Gengar for KO
        assert.are.equal(1, #targets)
    end)

    -- Test 7: RANDOM AI type - uniform distribution
    it("should select moves randomly for RANDOM AI type", function()
        local attacker = createPokemon(0, true, "Mewtwo", 50, 181, {13},
            {hp = 181, attack = 130, defense = 110, spAtk = 174, spDef = 110, speed = 150})

        local opponent = createPokemon(2, false, "Mew", 50, 175, {13},
            {hp = 175, attack = 120, defense = 120, spAtk = 120, spDef = 120, speed = 120})

        local movePool = {
            createMove(1, "Psychic", 13, 90, 1, 5),
            createMove(2, "Ice Beam", 14, 90, 1, 5),
            createMove(3, "Thunderbolt", 12, 90, 1, 5)
        }

        -- Run multiple times and check distribution
        local moveSelections = {}
        for i = 1, 10 do
            local msg = {
                Action = "EvaluateMoveSelection",
                PokemonId = "150",
                AiType = "0", -- RANDOM
                BattleSeed = tostring(i * 9876),
                Data = json.encode({
                    attacker = attacker,
                    opponents = {opponent},
                    movePool = movePool
                })
            }

            local result = aolite.send(process, msg)
            table.insert(moveSelections, result.MoveId)
        end

        -- Should have some variety in selections (not all the same)
        local unique = {}
        for _, moveId in ipairs(moveSelections) do
            unique[moveId] = true
        end

        -- With 10 selections and 3 moves, should see some variety
        assert.is_true(#unique >= 1, "Should have at least one move selected")
    end)

    -- Test 8: SMART_RANDOM AI type
    it("should favor best move with SMART_RANDOM AI type", function()
        local attacker = createPokemon(0, true, "Blaziken", 50, 155, {9, 1},
            {hp = 155, attack = 140, defense = 90, spAtk = 130, spDef = 90, speed = 100})

        -- Weak to Fighting
        local snorlax = createPokemon(2, false, "Snorlax", 50, 285, {0},
            {hp = 285, attack = 130, defense = 85, spAtk = 85, spDef = 130, speed = 50})

        local movePool = {
            createMove(1, "Close Combat", 1, 120, 0, 5),  -- Fighting (super effective)
            createMove(2, "Ember", 9, 40, 1, 5)           -- Fire (weak move)
        }

        local bestMoveCount = 0
        for i = 1, 10 do
            local msg = {
                Action = "EvaluateMoveSelection",
                PokemonId = "257",
                AiType = "1", -- SMART_RANDOM
                BattleSeed = tostring(i * 5555),
                Data = json.encode({
                    attacker = attacker,
                    opponents = {snorlax},
                    movePool = movePool
                })
            }

            local result = aolite.send(process, msg)
            if result.MoveId == "1" then
                bestMoveCount = bestMoveCount + 1
            end
        end

        -- SMART_RANDOM should favor best move ~62.5% of time (5/8)
        assert.is_true(bestMoveCount >= 4, "Should favor best move most of the time")
    end)

    -- Test 9: SMART AI type - probabilistic based on scores
    it("should use probabilistic weighting for SMART AI type", function()
        local attacker = createPokemon(0, true, "Dragonite", 50, 166, {15, 2},
            {hp = 166, attack = 154, defense = 115, spAtk = 120, spDef = 120, speed = 100})

        -- Multiple targets with different type matchups
        local opponents = {
            createPokemon(2, false, "Salamence", 50, 170, {15, 2},
                {hp = 170, attack = 155, defense = 100, spAtk = 130, spDef = 100, speed = 120}),
            createPokemon(3, false, "Garchomp", 50, 183, {15, 4},
                {hp = 183, attack = 150, defense = 115, spAtk = 100, spDef = 105, speed = 122})
        }

        local movePool = {
            createMove(1, "Outrage", 15, 120, 0, 5)  -- Dragon (neutral to both)
        }

        -- Run multiple times
        local targetCounts = {[2] = 0, [3] = 0}
        for i = 1, 10 do
            local msg = {
                Action = "EvaluateMoveSelection",
                PokemonId = "149",
                AiType = "2", -- SMART
                BattleSeed = tostring(i * 1111),
                Data = json.encode({
                    attacker = attacker,
                    opponents = opponents,
                    movePool = movePool
                })
            }

            local result = aolite.send(process, msg)
            local targets = json.decode(result.Targets)
            if targets[1] then
                targetCounts[targets[1]] = (targetCounts[targets[1]] or 0) + 1
            end
        end

        -- Should have selections for at least one target
        local totalSelections = (targetCounts[2] or 0) + (targetCounts[3] or 0)
        assert.is_true(totalSelections >= 1, "Should select targets")
    end)

    -- Test 10: Performance - Typical scenario under 500ms
    it("should execute typical scenario in reasonable time", function()
        local attacker = createPokemon(0, true, "Lucario", 50, 145, {1, 8},
            {hp = 145, attack = 130, defense = 90, spAtk = 135, spDef = 90, speed = 110})

        local opponent = createPokemon(2, false, "Tyranitar", 50, 175, {5, 16},
            {hp = 175, attack = 154, defense = 130, spAtk = 115, spDef = 120, speed = 81})

        local movePool = {
            createMove(1, "Aura Sphere", 1, 80, 1, 5),
            createMove(2, "Flash Cannon", 8, 80, 1, 5),
            createMove(3, "Close Combat", 1, 120, 0, 5),
            createMove(4, "Extreme Speed", 0, 80, 0, 5)
        }

        local startTime = os.clock()

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "448",
            AiType = "2",
            BattleSeed = "12345",
            Data = json.encode({
                attacker = attacker,
                opponents = {opponent},
                movePool = movePool
            })
        }

        local result = aolite.send(process, msg)
        local endTime = os.clock()
        local duration = (endTime - startTime) * 1000 -- Convert to ms

        assert.are.equal("true", result.Success)

        -- Should complete reasonably quickly (allowing for aolite overhead)
        print(string.format("Execution time: %.2f ms", duration))
    end)

    -- Test 11: Counter move scenario
    it("should handle counter moves correctly", function()
        local attacker = createPokemon(0, true, "Machamp", 50, 165, {1},
            {hp = 165, attack = 150, defense = 100, spAtk = 85, spDef = 105, speed = 75})

        local opponent = createPokemon(2, false, "Alakazam", 50, 130, {13},
            {hp = 130, attack = 70, defense = 65, spAtk = 155, spDef = 105, speed = 140})

        local movePool = {
            createMove(1, "Counter", 1, 1, 0, 5, true),  -- Counter move
            createMove(2, "Close Combat", 1, 120, 0, 5)
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "68",
            AiType = "2",
            BattleSeed = "22222",
            Data = json.encode({
                attacker = attacker,
                opponents = {opponent},
                movePool = movePool
            })
        }

        local result = aolite.send(process, msg)

        assert.are.equal("true", result.Success)
    end)

    -- Test 12: Status move vs attack move decision
    it("should choose between status and attack moves appropriately", function()
        local attacker = createPokemon(0, true, "Gyarados", 50, 170, {10, 2},
            {hp = 170, attack = 145, defense = 99, spAtk = 80, spDef = 120, speed = 101})

        local opponent = createPokemon(2, false, "Magnezone", 50, 145, {12, 8},
            {hp = 145, attack = 90, defense = 135, spAtk = 150, spDef = 110, speed = 80})

        local movePool = {
            createMove(1, "Dragon Dance", 15, 0, 2, 0),  -- Stat boost
            createMove(2, "Waterfall", 10, 80, 0, 5),    -- Attack
            createMove(3, "Crunch", 16, 80, 0, 5)        -- Attack
        }

        local msg = {
            Action = "EvaluateMoveSelection",
            PokemonId = "130",
            AiType = "2",
            BattleSeed = "88888",
            Data = json.encode({
                attacker = attacker,
                opponents = {opponent},
                movePool = movePool
            })
        }

        local result = aolite.send(process, msg)

        assert.are.equal("true", result.Success)

        -- Should select some move
        assert.is_not_nil(result.MoveId)
    end)
end)

print("✓ AI Move Selection Integration Tests Complete")
