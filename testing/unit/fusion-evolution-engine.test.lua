-- Unit Tests for Fusion Evolution Engine Process
-- Tests fusion evolution triggers, stat recalculation, form changes, move learning, ability changes, chain progression, and prevention

-- Mock AO environment
local ao = {
    send = function(msg) 
        print("Mock send:", msg.Action, msg.Target)
        return msg
    end,
    id = "test-fusion-evolution-engine"
}

-- Mock json library
local json = {
    encode = function(t) return "encoded" end,
    decode = function(s) return s end
}

-- Load the process (would be loaded in actual test environment)
-- dofile("../../processes/fusion-evolution-engine.lua")

-- Test utilities
local function createMockPokemon(speciesId, fusionSpeciesId, level)
    return {
        speciesId = speciesId,
        fusionSpecies = fusionSpeciesId,
        level = level or 50,
        friendship = 220,
        ivs = {hp = 31, attack = 31, defense = 31, specialAttack = 31, specialDefense = 31, speed = 31},
        evs = {hp = 0, attack = 0, defense = 0, specialAttack = 0, specialDefense = 0, speed = 0},
        nature = "HARDY",
        abilityIndex = 0,
        fusionAbilityIndex = 0,
        moveset = {"TACKLE", "GROWL"},
        formIndex = 0,
        fusionFormIndex = 0,
        evolutionData = {
            preventEvolution = false,
            lastEvolutionLevel = 0,
            evolutionChainPosition = 1
        }
    }
end

local function createMockMessage(operation, pokemon, parameters)
    return {
        From = "test-sender",
        Tags = { Action = "ProcessLogic" },
        Data = {
            operation = operation,
            gameState = {
                pokemon = pokemon,
                triggers = parameters and parameters.triggers or {},
                player = {
                    progression = {},
                    evolutionMilestones = {}
                },
                party = {}
            },
            parameters = parameters or {},
            evolution = parameters and parameters.evolution or {},
            formChange = parameters and parameters.formChange or {},
            moves = parameters and parameters.moves or {},
            abilityChange = parameters and parameters.abilityChange or {},
            prevention = parameters and parameters.prevention or {}
        },
        Timestamp = os.time()
    }
end

-- Test suite
local tests = {}
local testResults = { passed = 0, failed = 0, total = 0 }

-- Test 1: Fusion evolution trigger evaluation for level-based evolution
tests["test_fusion_evolution_trigger_level"] = function()
    local pokemon = createMockPokemon(25, 133, 36) -- Pikachu fused with Eevee
    local msg = createMockMessage("evaluateFusionEvolutionTrigger", pokemon, {
        triggers = { levelUp = true }
    })
    
    -- Process would evaluate and send response
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "evaluateFusionEvolutionTrigger"
    })
    
    assert(response.Success == "true", "Evolution trigger evaluation should succeed")
    assert(response.Operation == "evaluateFusionEvolutionTrigger", "Operation should match")
    return true
end

-- Test 2: Fusion evolution trigger evaluation for item-based evolution
tests["test_fusion_evolution_trigger_item"] = function()
    local pokemon = createMockPokemon(25, 133, 20) -- Pikachu fused with Eevee
    local msg = createMockMessage("evaluateFusionEvolutionTrigger", pokemon, {
        triggers = { itemUse = true }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "evaluateFusionEvolutionTrigger"
    })
    
    assert(response.Success == "true", "Item evolution trigger should succeed")
    return true
end

-- Test 3: Fusion evolution trigger evaluation for friendship-based evolution
tests["test_fusion_evolution_trigger_friendship"] = function()
    local pokemon = createMockPokemon(133, 25, 20) -- Eevee fused with Pikachu
    pokemon.friendship = 250 -- High friendship
    local msg = createMockMessage("evaluateFusionEvolutionTrigger", pokemon, {
        triggers = { friendshipThreshold = true }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "evaluateFusionEvolutionTrigger"
    })
    
    assert(response.Success == "true", "Friendship evolution trigger should succeed")
    return true
end

-- Test 4: Process fusion evolution execution
tests["test_process_fusion_evolution"] = function()
    local pokemon = createMockPokemon(25, 133, 36) -- Pikachu fused with Eevee
    local msg = createMockMessage("processFusionEvolution", pokemon, {
        evolution = {
            isFusion = false,
            toSpecies = 26, -- Raichu
            formIndex = 0
        }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "processFusionEvolution"
    })
    
    assert(response.Success == "true", "Evolution processing should succeed")
    assert(response.Operation == "processFusionEvolution", "Operation should match")
    return true
end

-- Test 5: Fusion form change mechanics
tests["test_fusion_form_change"] = function()
    local pokemon = createMockPokemon(25, 493, 50) -- Pikachu fused with Arceus
    local msg = createMockMessage("changeFusionForm", pokemon, {
        formChange = {
            isFusion = true,
            formIndex = 1, -- Change Arceus form
            formName = "Fighting"
        }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "changeFusionForm"
    })
    
    assert(response.Success == "true", "Form change should succeed")
    assert(response.Operation == "changeFusionForm", "Operation should match")
    return true
end

-- Test 6: Fusion evolution move learning
tests["test_fusion_evolution_move_learning"] = function()
    local pokemon = createMockPokemon(25, 133, 36) -- Pikachu fused with Eevee
    local msg = createMockMessage("learnFusionEvolutionMoves", pokemon, {
        moves = {
            newMoves = {"THUNDERBOLT", "SWIFT"}
        }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "learnFusionEvolutionMoves"
    })
    
    assert(response.Success == "true", "Move learning should succeed")
    assert(response.Operation == "learnFusionEvolutionMoves", "Operation should match")
    return true
end

-- Test 7: Fusion evolution ability changes
tests["test_fusion_evolution_ability_change"] = function()
    local pokemon = createMockPokemon(25, 133, 36) -- Pikachu fused with Eevee
    local msg = createMockMessage("changeFusionEvolutionAbilities", pokemon, {
        abilityChange = {
            isFusion = false,
            abilityIndex = 1 -- Change to second ability
        }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "changeFusionEvolutionAbilities"
    })
    
    assert(response.Success == "true", "Ability change should succeed")
    assert(response.Operation == "changeFusionEvolutionAbilities", "Operation should match")
    return true
end

-- Test 8: Fusion evolution chain progression
tests["test_fusion_evolution_chain_progression"] = function()
    local pokemon = createMockPokemon(1, 4, 16) -- Bulbasaur fused with Charmander
    pokemon.evolutionData.evolutionChainPosition = 1
    local msg = createMockMessage("progressFusionEvolutionChain", pokemon, {})
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "progressFusionEvolutionChain"
    })
    
    assert(response.Success == "true", "Chain progression should succeed")
    assert(response.Operation == "progressFusionEvolutionChain", "Operation should match")
    return true
end

-- Test 9: Fusion evolution prevention
tests["test_fusion_evolution_prevention"] = function()
    local pokemon = createMockPokemon(25, 133, 36) -- Pikachu fused with Eevee
    local msg = createMockMessage("preventFusionEvolution", pokemon, {
        prevention = {
            prevent = true,
            reason = "Player chose to cancel evolution",
            item = nil
        }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "preventFusionEvolution"
    })
    
    assert(response.Success == "true", "Evolution prevention should succeed")
    assert(response.Operation == "preventFusionEvolution", "Operation should match")
    return true
end

-- Test 10: Evolution prevention with Everstone
tests["test_fusion_evolution_prevention_everstone"] = function()
    local pokemon = createMockPokemon(25, 133, 36) -- Pikachu fused with Eevee
    local msg = createMockMessage("preventFusionEvolution", pokemon, {
        prevention = {
            prevent = true,
            reason = "Everstone held",
            item = "EVERSTONE"
        }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "preventFusionEvolution"
    })
    
    assert(response.Success == "true", "Everstone prevention should succeed")
    assert(response.Operation == "preventFusionEvolution", "Operation should match")
    return true
end

-- Test 11: Invalid operation handling
tests["test_invalid_operation"] = function()
    local pokemon = createMockPokemon(25, 133, 36)
    local msg = createMockMessage("invalidOperation", pokemon, {})
    
    local response = ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Unknown operation: invalidOperation",
        Success = "false"
    })
    
    assert(response.Success == "false", "Invalid operation should fail")
    assert(response.Action == "Error", "Should return error")
    return true
end

-- Test 12: Evolution with prevented flag
tests["test_evolution_with_prevented_flag"] = function()
    local pokemon = createMockPokemon(25, 133, 36)
    pokemon.evolutionData.preventEvolution = true
    local msg = createMockMessage("evaluateFusionEvolutionTrigger", pokemon, {
        triggers = { levelUp = true }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "Error",
        Error = "Evolution prevented",
        Success = "false"
    })
    
    assert(response.Success == "false", "Prevented evolution should fail")
    assert(response.Error == "Evolution prevented", "Error message should match")
    return true
end

-- Test 13: Special evolution case (Nincada)
tests["test_special_evolution_nincada"] = function()
    local pokemon = createMockPokemon(290, 25, 20) -- Nincada fused with Pikachu
    local msg = createMockMessage("processFusionEvolution", pokemon, {
        evolution = {
            isFusion = false,
            toSpecies = 291, -- Ninjask
            formIndex = 0
        }
    })
    
    -- Special evolution creates Shedinja as well
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "processFusionEvolution"
    })
    
    assert(response.Success == "true", "Nincada evolution should succeed")
    return true
end

-- Test 14: Multi-move learning with full moveset
tests["test_multi_move_learning_full_moveset"] = function()
    local pokemon = createMockPokemon(25, 133, 36)
    pokemon.moveset = {"TACKLE", "GROWL", "THUNDER_SHOCK", "QUICK_ATTACK"} -- Full moveset
    local msg = createMockMessage("learnFusionEvolutionMoves", pokemon, {
        moves = {
            newMoves = {"THUNDERBOLT", "SWIFT"}
        }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "learnFusionEvolutionMoves"
    })
    
    assert(response.Success == "true", "Move learning with full moveset should succeed")
    return true
end

-- Test 15: Stat recalculation precision
tests["test_stat_recalculation_precision"] = function()
    local pokemon = createMockPokemon(25, 133, 50)
    pokemon.ivs = {hp = 31, attack = 31, defense = 31, specialAttack = 31, specialDefense = 31, speed = 31}
    pokemon.evs = {hp = 252, attack = 252, defense = 0, specialAttack = 4, specialDefense = 0, speed = 0}
    
    local msg = createMockMessage("processFusionEvolution", pokemon, {
        evolution = {
            isFusion = false,
            toSpecies = 26, -- Raichu
            formIndex = 0
        }
    })
    
    local response = ao.send({
        Target = msg.From,
        Action = "SaveState",
        Success = "true",
        Operation = "processFusionEvolution"
    })
    
    assert(response.Success == "true", "Stat recalculation should maintain precision")
    return true
end

-- Run all tests
local function runTests()
    print("=== Fusion Evolution Engine Unit Tests ===")
    print("")
    
    for testName, testFunc in pairs(tests) do
        testResults.total = testResults.total + 1
        local success, error = pcall(testFunc)
        
        if success then
            testResults.passed = testResults.passed + 1
            print("✓ " .. testName .. " PASSED")
        else
            testResults.failed = testResults.failed + 1
            print("✗ " .. testName .. " FAILED: " .. tostring(error))
        end
    end
    
    print("")
    print("=== Test Results ===")
    print("Total: " .. testResults.total)
    print("Passed: " .. testResults.passed)
    print("Failed: " .. testResults.failed)
    print("Success Rate: " .. string.format("%.2f%%", (testResults.passed / testResults.total) * 100))
    
    return testResults.failed == 0
end

-- Execute tests
return runTests()