-- Unit tests for Evolution Engine Process
-- Tests Pokemon evolution logic, stat recalculation, and form changes

-- Add processes directory to package path for module loading
package.path = './?.lua;' .. package.path

local EvolutionEngineModule = require("processes.evolution-engine")
local EvolutionEngine = EvolutionEngineModule.EvolutionEngine
local EVOLUTION_TYPES = EvolutionEngineModule.EVOLUTION_TYPES
local LogicProcessTemplate = require("processes.templates.logic-process-template")

-- Test data fixtures
local mockBulbasaur = {
    speciesId = 1,
    level = 50, -- Higher level for more realistic stat comparison
    hp = 130,
    maxHp = 130,
    stats = {hp = 130, attack = 98, defense = 98, spAttack = 128, spDefense = 128, speed = 90},
    ivs = {hp = 20, attack = 20, defense = 20, spAttack = 20, spDefense = 20, speed = 20},
    nature = {attack = 1.0, defense = 1.0, spAttack = 1.1, spDefense = 1.0, speed = 0.9}
}

local mockPikachu = {
    speciesId = 25,
    level = 30,
    hp = 80,
    maxHp = 80,
    stats = {hp = 80, attack = 40, defense = 35, spAttack = 45, spDefense = 45, speed = 65},
    ivs = {hp = 25, attack = 25, defense = 25, spAttack = 25, spDefense = 25, speed = 25},
    nature = {attack = 1.0, defense = 1.0, spAttack = 1.0, spDefense = 1.0, speed = 1.1}
}

local mockGameState = {
    playerId = "test-player-123",
    timestamp = 1695123456,
    version = 1,
    player = {
        party = {mockBulbasaur}
    }
}

-- Test suite
local tests = {}

-- Test 1: Stat calculation formulas
function tests.testStatCalculation()
    print("Testing stat calculation formulas...")
    
    -- Test normal stat calculation
    local stat = EvolutionEngine.calculateStat(50, 20, 1.0, 50) -- base 50, IV 20, level 50
    local expectedStat = math.floor(((2 * 50 + 20) * 50 / 100) + 5) -- Formula: ((2*base + IV) * level / 100) + 5
    assert(stat == expectedStat, "Normal stat calculation should match formula")
    
    -- Test HP calculation
    local hpStat = EvolutionEngine.calculateHPStat(50, 20, 50)
    local expectedHP = math.floor(((2 * 50 + 20) * 50 / 100) + 50 + 10) -- Formula: ((2*base + IV) * level / 100) + level + 10
    assert(hpStat == expectedHP, "HP stat calculation should match formula")
    
    -- Test nature modifiers
    local boostedStat = EvolutionEngine.calculateStat(50, 20, 1.1, 50)
    local expectedBoosted = math.floor(expectedStat * 1.1)
    assert(boostedStat == expectedBoosted, "Nature boost should apply correctly")
    
    local reducedStat = EvolutionEngine.calculateStat(50, 20, 0.9, 50)
    local expectedReduced = math.floor(expectedStat * 0.9)
    assert(reducedStat == expectedReduced, "Nature reduction should apply correctly")
    
    -- Test error handling
    local success1, error1 = pcall(function()
        EvolutionEngine.calculateStat(nil, 20, 1.0, 50)
    end)
    assert(success1 == false, "Missing baseStat should throw error")
    assert(string.find(error1, "required"), "Error should mention required parameters")
    
    print("✓ Stat calculation tests passed")
end

-- Test 2: Evolution condition checking
function tests.testEvolutionConditions()
    print("Testing evolution condition checking...")
    
    -- Test level evolution
    local levelEvolution = {type = EVOLUTION_TYPES.LEVEL, level = 16}
    
    local meets = EvolutionEngine.checkEvolutionConditions(mockBulbasaur, levelEvolution, {})
    assert(meets == true, "Pokemon at level 50 should meet level 16 evolution requirement")
    
    local belowLevel = LogicProcessTemplate.Utils.deepCopy(mockBulbasaur)
    belowLevel.level = 15
    local doesntMeet = EvolutionEngine.checkEvolutionConditions(belowLevel, levelEvolution, {})
    assert(doesntMeet == false, "Pokemon below required level should not meet evolution requirement")
    
    -- Test stone evolution
    local stoneEvolution = {type = EVOLUTION_TYPES.STONE, item = "thunderstone"}
    
    local withStone = EvolutionEngine.checkEvolutionConditions(mockPikachu, stoneEvolution, {usedItem = "thunderstone"})
    assert(withStone == true, "Pokemon with correct stone should meet stone evolution requirement")
    
    local withoutStone = EvolutionEngine.checkEvolutionConditions(mockPikachu, stoneEvolution, {})
    assert(withoutStone == false, "Pokemon without stone should not meet stone evolution requirement")
    
    -- Test trade evolution
    local tradeEvolution = {type = EVOLUTION_TYPES.TRADE}
    
    local traded = EvolutionEngine.checkEvolutionConditions(mockPikachu, tradeEvolution, {isTraded = true})
    assert(traded == true, "Traded Pokemon should meet trade evolution requirement")
    
    local notTraded = EvolutionEngine.checkEvolutionConditions(mockPikachu, tradeEvolution, {isTraded = false})
    assert(notTraded == false, "Non-traded Pokemon should not meet trade evolution requirement")
    
    -- Test happiness evolution
    local happinessEvolution = {type = EVOLUTION_TYPES.HAPPINESS, happiness = 220}
    
    local happyPokemon = LogicProcessTemplate.Utils.deepCopy(mockPikachu)
    happyPokemon.happiness = 250
    local happyMeets = EvolutionEngine.checkEvolutionConditions(happyPokemon, happinessEvolution, {})
    assert(happyMeets == true, "Pokemon with high happiness should meet happiness evolution requirement")
    
    local sadPokemon = LogicProcessTemplate.Utils.deepCopy(mockPikachu) 
    sadPokemon.happiness = 100
    local sadDoesntMeet = EvolutionEngine.checkEvolutionConditions(sadPokemon, happinessEvolution, {})
    assert(sadDoesntMeet == false, "Pokemon with low happiness should not meet happiness evolution requirement")
    
    print("✓ Evolution condition tests passed")
end

-- Test 3: Get possible evolutions
function tests.testGetPossibleEvolutions()
    print("Testing get possible evolutions...")
    
    -- Test Bulbasaur at evolution level
    local evolutions = EvolutionEngine.getPossibleEvolutions(mockBulbasaur, {})
    assert(type(evolutions) == "table", "Should return table of evolutions")
    assert(#evolutions > 0, "Bulbasaur at level 16 should have possible evolutions")
    assert(evolutions[1].toSpecies == 2, "Bulbasaur should evolve to Ivysaur (species 2)")
    
    -- Test Bulbasaur below evolution level
    local lowLevelBulbasaur = LogicProcessTemplate.Utils.deepCopy(mockBulbasaur)
    lowLevelBulbasaur.level = 10
    local noEvolutions = EvolutionEngine.getPossibleEvolutions(lowLevelBulbasaur, {})
    assert(#noEvolutions == 0, "Bulbasaur below level 16 should have no possible evolutions")
    
    -- Test Pikachu with stone
    local pikachuEvolutions = EvolutionEngine.getPossibleEvolutions(mockPikachu, {usedItem = "thunderstone"})
    assert(#pikachuEvolutions > 0, "Pikachu with thunder stone should have possible evolutions")
    assert(pikachuEvolutions[1].toSpecies == 26, "Pikachu should evolve to Raichu (species 26)")
    
    -- Test Pokemon with no evolution chain
    local noChainPokemon = {speciesId = 999, level = 50} -- Non-existent species
    local noChainEvolutions = EvolutionEngine.getPossibleEvolutions(noChainPokemon, {})
    assert(#noChainEvolutions == 0, "Pokemon with no evolution chain should have no possible evolutions")
    
    print("✓ Get possible evolutions tests passed")
end

-- Test 4: Stat recalculation during evolution
function tests.testStatRecalculation()
    print("Testing stat recalculation during evolution...")
    
    -- Test stat recalculation for Bulbasaur -> Ivysaur
    local newStats = EvolutionEngine.recalculateStats(mockBulbasaur, 2) -- Ivysaur
    
    assert(type(newStats) == "table", "Recalculated stats should be a table")
    assert(newStats.hp ~= nil, "Should have HP stat")
    assert(newStats.attack ~= nil, "Should have attack stat")
    assert(newStats.defense ~= nil, "Should have defense stat")
    assert(newStats.spAttack ~= nil, "Should have special attack stat")
    assert(newStats.spDefense ~= nil, "Should have special defense stat")
    assert(newStats.speed ~= nil, "Should have speed stat")
    
    -- Stats should be calculated correctly based on base stats
    -- HP should be higher or equal (Ivysaur has higher base HP)
    assert(newStats.hp >= mockBulbasaur.stats.hp - 5, "Evolved HP should be reasonable relative to original")
    
    -- Check that we're using the correct base stats (Ivysaur has higher base stats than Bulbasaur)
    local bulbasaurBaseHP = EvolutionEngineModule.SPECIES_BASE_STATS[1].hp
    local ivysaurBaseHP = EvolutionEngineModule.SPECIES_BASE_STATS[2].hp
    assert(ivysaurBaseHP > bulbasaurBaseHP, "Ivysaur should have higher base HP than Bulbasaur")
    
    -- Test with different species
    local raichu = EvolutionEngine.recalculateStats(mockPikachu, 26) -- Raichu
    assert(raichu.attack > mockPikachu.stats.attack, "Raichu attack should be higher than Pikachu")
    
    -- Test error handling
    local success, error = pcall(function()
        EvolutionEngine.recalculateStats(mockBulbasaur, 9999) -- Non-existent species
    end)
    assert(success == false, "Non-existent species should throw error")
    assert(string.find(error, "not found"), "Error should mention species not found")
    
    print("✓ Stat recalculation tests passed")
end

-- Test 5: Pokemon evolution process
function tests.testPokemonEvolution()
    print("Testing Pokemon evolution process...")
    
    local originalPokemon = LogicProcessTemplate.Utils.deepCopy(mockBulbasaur)
    
    -- Evolve Bulbasaur to Ivysaur
    local evolvedPokemon = EvolutionEngine.evolvePokemon(originalPokemon, 2)
    
    assert(evolvedPokemon.speciesId == 2, "Evolved Pokemon should have new species ID")
    assert(originalPokemon.speciesId == 1, "Original Pokemon should not be modified")
    
    -- Check stat changes (maxHp should increase due to higher base stats)
    assert(evolvedPokemon.maxHp >= originalPokemon.maxHp, "Evolved Pokemon should have equal or higher max HP")
    
    -- Verify that base stats are actually higher for evolved species
    local originalBase = EvolutionEngineModule.SPECIES_BASE_STATS[originalPokemon.speciesId]
    local evolvedBase = EvolutionEngineModule.SPECIES_BASE_STATS[evolvedPokemon.speciesId]
    assert(evolvedBase.hp > originalBase.hp, "Evolved species should have higher base HP")
    
    -- Check HP ratio preservation for damaged Pokemon
    local damagedPokemon = LogicProcessTemplate.Utils.deepCopy(mockBulbasaur)
    damagedPokemon.hp = 25 -- Half HP
    local damagedEvolved = EvolutionEngine.evolvePokemon(damagedPokemon, 2)
    
    local originalRatio = damagedPokemon.hp / damagedPokemon.maxHp
    local evolvedRatio = damagedEvolved.hp / damagedEvolved.maxHp
    assert(math.abs(originalRatio - evolvedRatio) < 0.1, "HP ratio should be approximately preserved")
    
    -- Check metadata
    assert(evolvedPokemon.evolutionLevel == originalPokemon.level, "Evolution level should be recorded")
    assert(evolvedPokemon.evolutionTimestamp ~= nil, "Evolution timestamp should be set")
    assert(evolvedPokemon.canEvolve == nil, "canEvolve flag should be cleared")
    
    print("✓ Pokemon evolution tests passed")
end

-- Test 6: Form change handling
function tests.testFormChange()
    print("Testing form change handling...")
    
    local originalPokemon = LogicProcessTemplate.Utils.deepCopy(mockPikachu)
    
    -- Test basic form change
    local formedPokemon = EvolutionEngine.handleFormChange(originalPokemon, "alolan", {})
    
    assert(formedPokemon.form == "alolan", "Pokemon should have new form")
    assert(formedPokemon.formChangeTimestamp ~= nil, "Form change timestamp should be set")
    assert(originalPokemon.form == nil, "Original Pokemon should not be modified")
    
    -- Test form change with stat modifications
    local formContext = {
        statChanges = {
            attack = 1.2,
            speed = 0.8
        },
        newType1 = "electric",
        newType2 = "psychic"
    }
    
    local statChangedPokemon = EvolutionEngine.handleFormChange(originalPokemon, "alolan", formContext)
    
    local expectedAttack = math.floor(originalPokemon.stats.attack * 1.2)
    local expectedSpeed = math.floor(originalPokemon.stats.speed * 0.8)
    
    assert(statChangedPokemon.stats.attack == expectedAttack, "Attack stat should be modified by form change")
    assert(statChangedPokemon.stats.speed == expectedSpeed, "Speed stat should be modified by form change")
    assert(statChangedPokemon.type1 == "electric", "Type 1 should be updated")
    assert(statChangedPokemon.type2 == "psychic", "Type 2 should be updated")
    
    print("✓ Form change tests passed")
end

-- Test 7: Evolution path validation
function tests.testEvolutionPathValidation()
    print("Testing evolution path validation...")
    
    -- Test valid evolution path
    local valid1, error1 = EvolutionEngine.validateEvolutionPath(1, 2) -- Bulbasaur -> Ivysaur
    assert(valid1 == true, "Bulbasaur to Ivysaur should be valid evolution")
    assert(error1 == nil, "Valid evolution should not return error")
    
    local valid2, error2 = EvolutionEngine.validateEvolutionPath(25, 26) -- Pikachu -> Raichu
    assert(valid2 == true, "Pikachu to Raichu should be valid evolution")
    
    -- Test invalid evolution path
    local invalid1, invalidError1 = EvolutionEngine.validateEvolutionPath(1, 4) -- Bulbasaur -> Charmander
    assert(invalid1 == false, "Bulbasaur to Charmander should be invalid evolution")
    assert(string.find(invalidError1, "not a valid evolution"), "Error should mention invalid evolution")
    
    -- Test species with no evolution chain
    local invalid2, invalidError2 = EvolutionEngine.validateEvolutionPath(999, 1000) -- Non-existent species
    assert(invalid2 == false, "Non-existent species should be invalid")
    assert(string.find(invalidError2, "No evolution chain"), "Error should mention no evolution chain")
    
    print("✓ Evolution path validation tests passed")
end

-- Test 8: Logic operation handling
function tests.testLogicOperationHandling()
    print("Testing logic operation handling...")
    
    local testGameState = LogicProcessTemplate.Utils.deepCopy(mockGameState)
    local rngState, _ = LogicProcessTemplate.initializeRNG("evolution-test-seed")
    
    -- Test checkEvolution operation
    local checkParams = {
        pokemonIndex = 1,
        evolutionContext = {}
    }
    
    local checkResult = EvolutionEngine.handleLogicOperation(testGameState, "checkEvolution", checkParams, rngState)
    assert(checkResult.gameState ~= nil, "Check evolution should return gameState")
    assert(checkResult.possibleEvolutions ~= nil, "Check evolution should return possible evolutions")
    assert(type(checkResult.canEvolve) == "boolean", "Check evolution should return canEvolve boolean")
    
    -- Test evolvePokemon operation
    local evolveParams = {
        pokemonIndex = 1,
        targetSpecies = 2
    }
    
    local evolveResult = EvolutionEngine.handleLogicOperation(testGameState, "evolvePokemon", evolveParams, rngState)
    assert(evolveResult.gameState ~= nil, "Evolve Pokemon should return gameState")
    assert(evolveResult.evolvedPokemon ~= nil, "Evolve Pokemon should return evolved Pokemon")
    assert(evolveResult.evolutionSuccess == true, "Evolve Pokemon should return success flag")
    assert(evolveResult.gameState.player.party[1].speciesId == 2, "Pokemon in party should be evolved")
    
    -- Test recalculateStats operation
    local recalcParams = {
        pokemonIndex = 1,
        speciesId = 3
    }
    
    local recalcResult = EvolutionEngine.handleLogicOperation(testGameState, "recalculateStats", recalcParams, rngState)
    assert(recalcResult.gameState ~= nil, "Recalculate stats should return gameState")
    assert(recalcResult.recalculatedStats ~= nil, "Recalculate stats should return stats")
    
    -- Test handleFormChange operation
    local formParams = {
        pokemonIndex = 1,
        newForm = "alolan",
        formContext = {}
    }
    
    local formResult = EvolutionEngine.handleLogicOperation(testGameState, "handleFormChange", formParams, rngState)
    assert(formResult.gameState ~= nil, "Form change should return gameState")
    assert(formResult.formedPokemon ~= nil, "Form change should return formed Pokemon")
    assert(formResult.formChangeSuccess == true, "Form change should return success flag")
    
    -- Test invalid operation
    local success, error = pcall(function()
        EvolutionEngine.handleLogicOperation(testGameState, "invalidOperation", {}, rngState)
    end)
    assert(success == false, "Invalid operation should throw error")
    assert(string.find(error, "Unknown"), "Error should mention unknown operation")
    
    print("✓ Logic operation handling tests passed")
end

-- Test 9: Message handling integration
function tests.testMessageHandling()
    print("Testing message handling integration...")
    
    local message = {
        Action = "ProcessLogic",
        Data = {
            gameState = mockGameState,
            operation = "checkEvolution",
            parameters = {
                pokemonIndex = 1,
                evolutionContext = {}
            }
        },
        Timestamp = os.time(),
        From = "test-sender"
    }
    
    -- Test message handling through template
    local response = LogicProcessTemplate.handleMessage(message, "evolution-engine", EvolutionEngine.handleLogicOperation)
    
    assert(response.Action == "SaveState", "Response should use SaveState action")
    assert(response.ProcessId == "evolution-engine", "Response should include correct process ID")
    assert(response.Data ~= nil, "Response should contain data")
    assert(response.Data.result ~= nil, "Response should contain result")
    assert(response.Data.result.possibleEvolutions ~= nil, "Response should contain possible evolutions")
    
    print("✓ Message handling integration tests passed")
end

-- Test 10: Error handling and edge cases
function tests.testErrorHandling()
    print("Testing error handling and edge cases...")
    
    local testGameState = LogicProcessTemplate.Utils.deepCopy(mockGameState)
    local rngState, _ = LogicProcessTemplate.initializeRNG("error-test-seed")
    
    -- Test missing Pokemon in party
    local missingPokemonParams = {
        pokemonIndex = 5, -- Index that doesn't exist
        targetSpecies = 2
    }
    
    local success1, error1 = pcall(function()
        EvolutionEngine.handleLogicOperation(testGameState, "evolvePokemon", missingPokemonParams, rngState)
    end)
    assert(success1 == false, "Missing Pokemon should throw error")
    assert(string.find(error1, "not found"), "Error should mention Pokemon not found")
    
    -- Test invalid evolution target
    local invalidTargetParams = {
        pokemonIndex = 1,
        targetSpecies = 999 -- Non-existent species
    }
    
    local success2, error2 = pcall(function()
        EvolutionEngine.handleLogicOperation(testGameState, "evolvePokemon", invalidTargetParams, rngState)
    end)
    assert(success2 == false, "Invalid evolution target should throw error")
    
    -- Test missing required parameters
    local missingParamParams = {
        pokemonIndex = 1
        -- Missing targetSpecies
    }
    
    local success3, error3 = pcall(function()
        EvolutionEngine.handleLogicOperation(testGameState, "evolvePokemon", missingParamParams, rngState)
    end)
    assert(success3 == false, "Missing required parameters should throw error")
    assert(string.find(error3, "required"), "Error should mention required parameter")
    
    print("✓ Error handling tests passed")
end

-- Run all tests
function tests.runAllTests()
    print("Running Evolution Engine unit tests...")
    print("=" .. string.rep("=", 50))
    
    tests.testStatCalculation()
    tests.testEvolutionConditions()
    tests.testGetPossibleEvolutions()
    tests.testStatRecalculation()
    tests.testPokemonEvolution()
    tests.testFormChange()
    tests.testEvolutionPathValidation()
    tests.testLogicOperationHandling()
    tests.testMessageHandling()
    tests.testErrorHandling()
    
    print("=" .. string.rep("=", 50))
    print("✅ All Evolution Engine tests passed!")
    return true
end

-- Export test runner
return tests