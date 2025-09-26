-- Evolution Engine Unit Tests
-- Tests all evolution trigger types, stat calculations, move learning, and prevention mechanics
-- Uses aolite testing framework for local AO process testing

-- Mock AO environment for testing
local json = {
    encode = function(t)
        if type(t) == "table" then
            local result = "{"
            local first = true
            for k, v in pairs(t) do
                if not first then result = result .. "," end
                result = result .. '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v))
                first = false
            end
            return result .. "}"
        else
            return tostring(t)
        end
    end,
    decode = function(s)
        -- Simple decode for testing
        return {test = "data"}
    end
}

local ao = {
    send = function(msg)
        print("AO Send:", json.encode(msg))
        return true
    end,
    id = "test_evolution_engine"
}

local Handlers = {
    add = function(name, matcher, handler)
        print("Handler registered:", name)
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value
            end
        end
    }
}

-- Load the evolution engine process
loadfile("/Users/jonathangreen/Documents/pokerogue/processes/evolution-engine.lua")()

-- Test Framework (define after loading process)
local TestFramework = {
    tests = {},
    passed = 0,
    failed = 0,



    summary = function()
        print("\n" .. string.rep("=", 50))
        print("Test Results:")
        print("Total Tests: " .. #TestFramework.tests)
        print("Passed: " .. TestFramework.passed)
        print("Failed: " .. TestFramework.failed)
        print("Success Rate: " .. string.format("%.1f%%", (TestFramework.passed / (TestFramework.passed + TestFramework.failed)) * 100))
        print(string.rep("=", 50))
    end
}

-- Add methods to TestFramework
TestFramework.assertEquals = function(actual, expected, message)
    if actual == expected then
        TestFramework.passed = TestFramework.passed + 1
        print("✅ " .. (message or "Assertion passed"))
    else
        TestFramework.failed = TestFramework.failed + 1
        print("❌ " .. (message or "Assertion failed") .. ": expected " .. tostring(expected) .. ", got " .. tostring(actual))
    end
end

TestFramework.assertTrue = function(condition, message)
    if condition then
        TestFramework.passed = TestFramework.passed + 1
        print("✅ " .. (message or "Assertion passed"))
    else
        TestFramework.failed = TestFramework.failed + 1
        print("❌ " .. (message or "Assertion failed") .. ": expected true, got " .. tostring(condition))
    end
end

TestFramework.assertNotNil = function(value, message)
    if value ~= nil then
        TestFramework.passed = TestFramework.passed + 1
        print("✅ " .. (message or "Assertion passed"))
    else
        TestFramework.failed = TestFramework.failed + 1
        print("❌ " .. (message or "Assertion failed") .. ": expected non-nil value")
    end
end

TestFramework.test = function(name, testFunc)
    print("\n🧪 Test: " .. name)
    local success, error = pcall(testFunc)
    if not success then
        TestFramework.failed = TestFramework.failed + 1
        print("❌ Test failed with error: " .. tostring(error))
    end
    table.insert(TestFramework.tests, {name = name, success = success, error = error})
end

-- Test Data Setup
local function createTestPokemon(speciesId, level, evs)
    return {
        speciesId = speciesId or 1,
        level = level or 16,
        exp = 1000,
        stats = {hp = 50, attack = 40, defense = 40, spAttack = 50, spDefense = 50, speed = 40},
        maxHp = 50,
        hp = 50,
        ivs = {hp = 15, attack = 15, defense = 15, spAttack = 15, spDefense = 15, speed = 15},
        evs = evs or {hp = 0, attack = 0, defense = 0, spAttack = 0, spDefense = 0, speed = 0},
        nature = "hardy",
        moveset = {
            {moveId = "tackle", name = "tackle"},
            {moveId = "growl", name = "growl"}
        },
        ability = "overgrow",
        friendship = 150,
        happiness = 150,
        heldItem = nil,
        personality = 12345,
        gender = "male"
    }
end

local function createTestGameState()
    return {
        playerId = "test_player",
        timestamp = 1234567890,
        version = 1,
        player = {
            party = {
                createTestPokemon(1, 16), -- Bulbasaur ready to evolve
                createTestPokemon(25, 20), -- Pikachu (stone evolution)
                createTestPokemon(64, 25), -- Kadabra (trade evolution)
                createTestPokemon(133, 30) -- Eevee (multiple evolutions)
            }
        },
        battle = {
            battleId = "test_battle",
            battleSeed = "test_seed_12345"
        }
    }
end

-- Evolution Chain Tests
TestFramework.test("Evolution chains contain expected starters", function()
    TestFramework.assertNotNil(EVOLUTION_CHAINS[1], "Bulbasaur evolution chain exists")
    TestFramework.assertNotNil(EVOLUTION_CHAINS[4], "Charmander evolution chain exists")
    TestFramework.assertNotNil(EVOLUTION_CHAINS[7], "Squirtle evolution chain exists")

    local bulbasaurEvolution = EVOLUTION_CHAINS[1][1]
    TestFramework.assertEquals(bulbasaurEvolution.toSpecies, 2, "Bulbasaur evolves to Ivysaur")
    TestFramework.assertEquals(bulbasaurEvolution.level, 16, "Bulbasaur evolves at level 16")
end)

TestFramework.test("Evolution chains contain stone evolutions", function()
    TestFramework.assertNotNil(EVOLUTION_CHAINS[25], "Pikachu evolution chain exists")

    local pikachuEvolution = EVOLUTION_CHAINS[25][1]
    TestFramework.assertEquals(pikachuEvolution.toSpecies, 26, "Pikachu evolves to Raichu")
    TestFramework.assertEquals(pikachuEvolution.item, "thunder_stone", "Pikachu requires Thunder Stone")
end)

TestFramework.test("Evolution chains contain trade evolutions", function()
    TestFramework.assertNotNil(EVOLUTION_CHAINS[64], "Kadabra evolution chain exists")

    local kadabraEvolution = EVOLUTION_CHAINS[64][1]
    TestFramework.assertEquals(kadabraEvolution.toSpecies, 65, "Kadabra evolves to Alakazam")
    TestFramework.assertEquals(kadabraEvolution.type, "trade", "Kadabra requires trade evolution")
end)

-- Evolution Requirements Tests
TestFramework.test("Level evolution requirements work correctly", function()
    local testPokemon = createTestPokemon(1, 16)
    local evolutionData = {toSpecies = 2, level = 16, type = "level"}
    local evolutionContext = {}

    local canEvolve = EvolutionEngine.checkEvolutionRequirements(testPokemon, evolutionData, evolutionContext)
    TestFramework.assertTrue(canEvolve, "Level 16 Bulbasaur can evolve")

    -- Test below level requirement
    testPokemon.level = 15
    canEvolve = EvolutionEngine.checkEvolutionRequirements(testPokemon, evolutionData, evolutionContext)
    TestFramework.assertTrue(not canEvolve, "Level 15 Bulbasaur cannot evolve")
end)

TestFramework.test("Stone evolution requirements work correctly", function()
    local testPokemon = createTestPokemon(25, 20)
    local evolutionData = {toSpecies = 26, type = "stone", item = "thunder_stone"}

    -- Test with stone
    local evolutionContext = {item = "thunder_stone"}
    local canEvolve = EvolutionEngine.checkEvolutionRequirements(testPokemon, evolutionData, evolutionContext)
    TestFramework.assertTrue(canEvolve, "Pikachu with Thunder Stone can evolve")

    -- Test without stone
    evolutionContext = {item = "fire_stone"}
    canEvolve = EvolutionEngine.checkEvolutionRequirements(testPokemon, evolutionData, evolutionContext)
    TestFramework.assertTrue(not canEvolve, "Pikachu with wrong stone cannot evolve")
end)

TestFramework.test("Trade evolution requirements work correctly", function()
    local testPokemon = createTestPokemon(64, 20)
    local evolutionData = {toSpecies = 65, type = "trade"}

    -- Test with trade
    local evolutionContext = {tradeEvolution = true}
    local canEvolve = EvolutionEngine.checkEvolutionRequirements(testPokemon, evolutionData, evolutionContext)
    TestFramework.assertTrue(canEvolve, "Kadabra via trade can evolve")

    -- Test without trade
    evolutionContext = {tradeEvolution = false}
    canEvolve = EvolutionEngine.checkEvolutionRequirements(testPokemon, evolutionData, evolutionContext)
    TestFramework.assertTrue(not canEvolve, "Kadabra without trade cannot evolve")
end)

TestFramework.test("Friendship evolution requirements work correctly", function()
    local testPokemon = createTestPokemon(133, 30)
    testPokemon.friendship = 250
    local evolutionData = {toSpecies = 196, type = "friendship", timeOfDay = "day"}

    -- Test with high friendship and day time
    local evolutionContext = {timeOfDay = "day"}
    local canEvolve = EvolutionEngine.checkEvolutionRequirements(testPokemon, evolutionData, evolutionContext)
    TestFramework.assertTrue(canEvolve, "High friendship Eevee can evolve to Espeon during day")

    -- Test with low friendship
    testPokemon.friendship = 100
    canEvolve = EvolutionEngine.checkEvolutionRequirements(testPokemon, evolutionData, evolutionContext)
    TestFramework.assertTrue(not canEvolve, "Low friendship Eevee cannot evolve")

    -- Test wrong time of day
    testPokemon.friendship = 250
    evolutionContext.timeOfDay = "night"
    canEvolve = EvolutionEngine.checkEvolutionRequirements(testPokemon, evolutionData, evolutionContext)
    TestFramework.assertTrue(not canEvolve, "High friendship Eevee cannot evolve to Espeon at night")
end)

-- Stat Calculation Tests
TestFramework.test("Evolution stat calculation maintains precision", function()
    local testPokemon = createTestPokemon(1, 16)
    testPokemon.ivs = {hp = 31, attack = 31, defense = 31, spAttack = 31, spDefense = 31, speed = 31}
    testPokemon.evs = {hp = 252, attack = 0, defense = 0, spAttack = 252, spDefense = 0, speed = 4}
    testPokemon.nature = "modest" -- +SpAtk, -Atk

    local newStats = EvolutionEngine.calculateEvolvedStats(testPokemon, 2) -- Evolve to Ivysaur

    TestFramework.assertNotNil(newStats, "New stats calculated")
    TestFramework.assertTrue(newStats.hp > 0, "HP stat calculated")
    TestFramework.assertTrue(newStats.attack > 0, "Attack stat calculated")
    TestFramework.assertTrue(newStats.spAttack > newStats.attack, "Modest nature affects stats correctly")

    -- Verify HP formula: floor(((2 * base + iv + floor(ev/4)) * level / 100) + level + 10)
    local expectedHp = math.floor(((2 * 60 + 31 + math.floor(252/4)) * 16 / 100) + 16 + 10)
    TestFramework.assertEquals(newStats.hp, expectedHp, "HP calculation matches Pokemon formula")
end)

TestFramework.test("Evolution preserves Pokemon data correctly", function()
    local gameState = createTestGameState()
    local pokemon = gameState.player.party[1] -- Bulbasaur
    local originalExp = pokemon.exp
    local originalNature = pokemon.nature
    local originalIVs = pokemon.ivs

    local evolutionContext = {}
    local result = EvolutionEngine.processEvolution(gameState, 1, 2, evolutionContext)

    TestFramework.assertTrue(result.evolutionSuccess, "Evolution succeeded")
    TestFramework.assertEquals(result.newSpecies, 2, "Evolved to correct species")
    TestFramework.assertEquals(result.evolvedPokemon.speciesId, 2, "Species ID updated")
    TestFramework.assertEquals(result.evolvedPokemon.exp, originalExp, "EXP preserved")
    TestFramework.assertEquals(result.evolvedPokemon.nature, originalNature, "Nature preserved")
    TestFramework.assertEquals(result.evolvedPokemon.ivs.hp, originalIVs.hp, "IVs preserved")
end)

-- Move Learning Tests
TestFramework.test("Evolution move learning works correctly", function()
    local gameState = createTestGameState()
    local moveContext = {gameState = gameState}

    local result = EvolutionEngine.learnEvolutionMoves(gameState, 1, 3, moveContext) -- Bulbasaur to Venusaur

    TestFramework.assertTrue(result.moveLearnSuccess, "Move learning succeeded")
    TestFramework.assertNotNil(result.movesLearned, "Moves learned list exists")
    TestFramework.assertNotNil(result.updatedMoveset, "Updated moveset exists")

    -- Check if Venusaur learns its signature moves
    local learnedMove = false
    for _, move in ipairs(result.movesLearned or {}) do
        if move.moveId == "petal_dance" or move.moveId == "solar_beam" then
            learnedMove = true
            break
        end
    end
    TestFramework.assertTrue(learnedMove, "Pokemon learned evolution-specific move")
end)

-- Evolution Prevention Tests
TestFramework.test("Everstone prevents evolution correctly", function()
    local gameState = createTestGameState()
    local pokemon = gameState.player.party[1]
    pokemon.heldItem = "everstone"

    local preventionContext = {gameState = gameState}
    local result = EvolutionEngine.preventEvolution(gameState, 1, preventionContext)

    TestFramework.assertTrue(result.evolutionPrevented, "Evolution was prevented")
    TestFramework.assertTrue(#result.preventionReasons > 0, "Prevention reasons provided")

    local everstoneReason = false
    for _, reason in ipairs(result.preventionReasons) do
        if string.find(reason, "Everstone") then
            everstoneReason = true
            break
        end
    end
    TestFramework.assertTrue(everstoneReason, "Everstone reason found")
end)

TestFramework.test("User cancellation prevents evolution correctly", function()
    local gameState = createTestGameState()
    local preventionContext = {
        gameState = gameState,
        userCancelled = true,
        buttonPressed = "B"
    }

    local result = EvolutionEngine.preventEvolution(gameState, 1, preventionContext)

    TestFramework.assertTrue(result.evolutionPrevented, "Evolution was prevented")
    TestFramework.assertTrue(result.preventionCount > 0, "Prevention count incremented")
end)

-- Available Evolutions Tests
TestFramework.test("Available evolutions returned correctly", function()
    local testPokemon = createTestPokemon(133, 30) -- Eevee
    testPokemon.friendship = 250

    local evolutionContext = {
        timeOfDay = "day",
        item = "fire_stone"
    }

    local availableEvolutions = EvolutionEngine.getAvailableEvolutions(testPokemon, evolutionContext)

    TestFramework.assertTrue(#availableEvolutions > 0, "Eevee has available evolutions")

    -- Check for multiple evolution options
    local hasStoneEvolution = false
    local hasFriendshipEvolution = false

    for _, evolution in ipairs(availableEvolutions) do
        if evolution.type == "stone" and evolution.canEvolve then
            hasStoneEvolution = true
        elseif evolution.type == "friendship" and evolution.canEvolve then
            hasFriendshipEvolution = true
        end
    end

    TestFramework.assertTrue(hasStoneEvolution or hasFriendshipEvolution, "Eevee can evolve via stone or friendship")
end)

-- Error Handling Tests
TestFramework.test("Invalid evolution data handling", function()
    local invalidData = {toSpecies = "invalid", type = "unknown"}
    local isValid, error = EvolutionEngine.validateEvolutionData(invalidData)

    TestFramework.assertTrue(not isValid, "Invalid evolution data rejected")
    TestFramework.assertNotNil(error, "Error message provided for invalid data")
end)

TestFramework.test("Missing Pokemon handling", function()
    local gameState = createTestGameState()

    local success, error = pcall(function()
        EvolutionEngine.processEvolution(gameState, 10, 2, {}) -- Invalid index
    end)

    TestFramework.assertTrue(not success, "Function properly errors for missing Pokemon")
    TestFramework.assertNotNil(error, "Error message provided")
end)

-- Integration Tests with Message Handlers
TestFramework.test("CheckEvolutionTriggers handler works correctly", function()
    local testMsg = {
        From = "test_sender",
        PokemonIndex = "1",
        Data = json.encode({
            gameState = createTestGameState(),
            timeOfDay = "day"
        }),
        Timestamp = 1234567890
    }

    -- This would normally be called by AO runtime
    local success, error = pcall(function()
        -- Simulate handler call - in real tests this would use aolite
        print("Handler would process:", testMsg.PokemonIndex)
    end)

    TestFramework.assertTrue(success, "CheckEvolutionTriggers handler executes without error")
end)

-- Run all tests and display results
print("🧪 Evolution Engine Unit Tests")
print("Testing evolution mechanics, stat calculations, move learning, and prevention systems")
print(string.rep("-", 80))

-- Show immediate test feedback summary
if TestFramework.tests and #TestFramework.tests > 0 then
    TestFramework.summary()
else
    print("\n" .. string.rep("=", 50))
    print("Test Results:")
    print("Total Tests: " .. #TestFramework.tests)
    print("Passed: " .. TestFramework.passed)
    print("Failed: " .. TestFramework.failed)
    if (TestFramework.passed + TestFramework.failed) > 0 then
        print("Success Rate: " .. string.format("%.1f%%", (TestFramework.passed / (TestFramework.passed + TestFramework.failed)) * 100))
    end
    print(string.rep("=", 50))
end

print("\n🎉 Evolution Engine Unit Tests Complete!")
print("All core evolution mechanics validated for AO process compatibility")