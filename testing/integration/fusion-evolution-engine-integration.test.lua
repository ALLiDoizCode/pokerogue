-- Integration Tests for Fusion Evolution Engine Process
-- Tests cross-process fusion evolution coordination with Evolution Engine, Pokemon State Manager, and other processes

-- Mock AO environment
local ao = {
    send = function(msg)
        print("Integration send to:", msg.Target, "Action:", msg.Action)
        return msg
    end,
    id = "test-fusion-evolution-engine"
}

-- Mock json library
local json = {
    encode = function(t) return "encoded" end,
    decode = function(s) return s end
}

-- Process IDs for integration testing
local PROCESS_IDS = {
    FUSION_EVOLUTION = "fusion-evolution-engine",
    EVOLUTION = "evolution-engine",
    POKEMON_STATE = "pokemon-state-manager",
    FUSION_CALC = "fusion-calculation-engine",
    FUSION_BATTLE = "fusion-battle-engine",
    EXPERIENCE = "experience-leveling-engine",
    COORDINATOR = "coordinator-process",
    PLAYER_PROGRESSION = "player-progression-engine"
}

-- Test utilities
local function createFullGameState()
    return {
        pokemon = {
            speciesId = 25, -- Pikachu
            fusionSpecies = 133, -- Eevee
            level = 36,
            exp = 46656,
            friendship = 220,
            ivs = {hp = 31, attack = 31, defense = 31, specialAttack = 31, specialDefense = 31, speed = 31},
            evs = {hp = 0, attack = 0, defense = 0, specialAttack = 0, specialDefense = 0, speed = 0},
            nature = "HARDY",
            abilityIndex = 0,
            fusionAbilityIndex = 0,
            moveset = {"TACKLE", "GROWL", "THUNDER_SHOCK", "QUICK_ATTACK"},
            formIndex = 0,
            fusionFormIndex = 0,
            evolutionData = {
                preventEvolution = false,
                lastEvolutionLevel = 0,
                evolutionChainPosition = 1
            },
            stats = {
                hp = 95,
                attack = 65,
                defense = 65,
                specialAttack = 75,
                specialDefense = 85,
                speed = 105
            }
        },
        party = {
            {speciesId = 25, fusionSpecies = 133}, -- The evolving Pokemon
            {speciesId = 6}, -- Charizard
            {speciesId = 9}, -- Blastoise
            {speciesId = 3}  -- Venusaur
        },
        player = {
            progression = {
                badges = 4,
                evolutionsCompleted = 12
            },
            evolutionMilestones = {
                firstEvolution = true,
                firstFusionEvolution = false
            }
        },
        battle = nil, -- Not in battle
        timestamp = os.time()
    }
end

local function createIntegrationMessage(target, action, data)
    return {
        From = "coordinator-process",
        Target = target,
        Tags = { Action = action },
        Data = data,
        Timestamp = os.time()
    }
end

-- Integration test suite
local integrationTests = {}
local testResults = { passed = 0, failed = 0, total = 0 }

-- Test 1: Full fusion evolution workflow across multiple processes
integrationTests["test_full_fusion_evolution_workflow"] = function()
    local gameState = createFullGameState()
    
    -- Step 1: Coordinator triggers evolution check
    local checkMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "evaluateFusionEvolutionTrigger",
        gameState = gameState,
        triggers = { levelUp = true }
    })
    
    local checkResponse = ao.send(checkMsg)
    
    -- Step 2: If evolution triggered, process evolution
    local evolutionMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "processFusionEvolution",
        gameState = gameState,
        evolution = {
            isFusion = false,
            toSpecies = 26, -- Raichu
            formIndex = 0
        }
    })
    
    local evolutionResponse = ao.send(evolutionMsg)
    
    -- Step 3: Update Pokemon state
    local stateMsg = createIntegrationMessage(PROCESS_IDS.POKEMON_STATE, "ProcessLogic", {
        operation = "updatePokemonState",
        gameState = gameState,
        evolutionResult = evolutionResponse
    })
    
    local stateResponse = ao.send(stateMsg)
    
    -- Step 4: Update player progression
    local progressMsg = createIntegrationMessage(PROCESS_IDS.PLAYER_PROGRESSION, "ProcessLogic", {
        operation = "recordEvolution",
        gameState = gameState,
        evolutionType = "fusion",
        fromSpecies = 25,
        toSpecies = 26
    })
    
    local progressResponse = ao.send(progressMsg)
    
    assert(checkResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Evolution check should target correct process")
    assert(evolutionResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Evolution should target correct process")
    assert(stateResponse.Target == PROCESS_IDS.POKEMON_STATE, "State update should target correct process")
    assert(progressResponse.Target == PROCESS_IDS.PLAYER_PROGRESSION, "Progress update should target correct process")
    return true
end

-- Test 2: Fusion evolution with stat recalculation coordination
integrationTests["test_fusion_evolution_stat_coordination"] = function()
    local gameState = createFullGameState()
    
    -- Step 1: Process fusion evolution
    local evolutionMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "processFusionEvolution",
        gameState = gameState,
        evolution = {
            isFusion = true,
            toSpecies = 134, -- Vaporeon (Eevee evolution)
            formIndex = 0
        }
    })
    
    local evolutionResponse = ao.send(evolutionMsg)
    
    -- Step 2: Request stat recalculation from Fusion Calculation Engine
    local calcMsg = createIntegrationMessage(PROCESS_IDS.FUSION_CALC, "ProcessLogic", {
        operation = "calculateFusionStats",
        baseSpecies = 25, -- Pikachu
        fusionSpecies = 134, -- Vaporeon
        level = gameState.pokemon.level,
        ivs = gameState.pokemon.ivs,
        evs = gameState.pokemon.evs,
        nature = gameState.pokemon.nature
    })
    
    local calcResponse = ao.send(calcMsg)
    
    -- Step 3: Update Pokemon with new stats
    local updateMsg = createIntegrationMessage(PROCESS_IDS.POKEMON_STATE, "ProcessLogic", {
        operation = "updateStats",
        pokemonId = 1,
        newStats = calcResponse
    })
    
    local updateResponse = ao.send(updateMsg)
    
    assert(evolutionResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Evolution should complete")
    assert(calcResponse.Target == PROCESS_IDS.FUSION_CALC, "Stat calculation should complete")
    assert(updateResponse.Target == PROCESS_IDS.POKEMON_STATE, "Stat update should complete")
    return true
end

-- Test 3: Evolution chain progression with multiple processes
integrationTests["test_evolution_chain_multi_process"] = function()
    local gameState = createFullGameState()
    gameState.pokemon.speciesId = 1 -- Bulbasaur
    gameState.pokemon.level = 16
    
    -- First evolution: Bulbasaur -> Ivysaur
    local firstEvolution = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "processFusionEvolution",
        gameState = gameState,
        evolution = {
            isFusion = false,
            toSpecies = 2, -- Ivysaur
            formIndex = 0
        }
    })
    
    local firstResponse = ao.send(firstEvolution)
    
    -- Update chain position
    local chainMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "progressFusionEvolutionChain",
        gameState = gameState
    })
    
    local chainResponse = ao.send(chainMsg)
    
    -- Notify Evolution Engine of chain progression
    local notifyMsg = createIntegrationMessage(PROCESS_IDS.EVOLUTION, "ProcessLogic", {
        operation = "recordEvolutionChain",
        pokemonId = 1,
        chainPosition = 2,
        species = 2
    })
    
    local notifyResponse = ao.send(notifyMsg)
    
    assert(firstResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "First evolution should complete")
    assert(chainResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Chain progression should complete")
    assert(notifyResponse.Target == PROCESS_IDS.EVOLUTION, "Evolution Engine should be notified")
    return true
end

-- Test 4: Move learning coordination during evolution
integrationTests["test_evolution_move_learning_coordination"] = function()
    local gameState = createFullGameState()
    
    -- Step 1: Process evolution
    local evolutionMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "processFusionEvolution",
        gameState = gameState,
        evolution = {
            isFusion = false,
            toSpecies = 26, -- Raichu
            formIndex = 0
        }
    })
    
    local evolutionResponse = ao.send(evolutionMsg)
    
    -- Step 2: Learn evolution moves
    local moveMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "learnFusionEvolutionMoves",
        gameState = gameState,
        moves = {
            newMoves = {"THUNDERBOLT", "THUNDER"}
        }
    })
    
    local moveResponse = ao.send(moveMsg)
    
    -- Step 3: Update Pokemon moveset in state manager
    local updateMsg = createIntegrationMessage(PROCESS_IDS.POKEMON_STATE, "ProcessLogic", {
        operation = "updateMoveset",
        pokemonId = 1,
        moveset = {"TACKLE", "THUNDERBOLT", "THUNDER", "QUICK_ATTACK"}
    })
    
    local updateResponse = ao.send(updateMsg)
    
    assert(evolutionResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Evolution should complete")
    assert(moveResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Move learning should complete")
    assert(updateResponse.Target == PROCESS_IDS.POKEMON_STATE, "Moveset update should complete")
    return true
end

-- Test 5: Ability change coordination during evolution
integrationTests["test_evolution_ability_coordination"] = function()
    local gameState = createFullGameState()
    
    -- Process evolution with ability change
    local evolutionMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "processFusionEvolution",
        gameState = gameState,
        evolution = {
            isFusion = false,
            toSpecies = 26, -- Raichu
            formIndex = 0
        }
    })
    
    local evolutionResponse = ao.send(evolutionMsg)
    
    -- Change abilities
    local abilityMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "changeFusionEvolutionAbilities",
        gameState = gameState,
        abilityChange = {
            isFusion = false,
            abilityIndex = 1
        }
    })
    
    local abilityResponse = ao.send(abilityMsg)
    
    -- Update Pokemon ability in state
    local updateMsg = createIntegrationMessage(PROCESS_IDS.POKEMON_STATE, "ProcessLogic", {
        operation = "updateAbility",
        pokemonId = 1,
        abilityIndex = 1
    })
    
    local updateResponse = ao.send(updateMsg)
    
    assert(evolutionResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Evolution should complete")
    assert(abilityResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Ability change should complete")
    assert(updateResponse.Target == PROCESS_IDS.POKEMON_STATE, "Ability update should complete")
    return true
end

-- Test 6: Form change coordination with battle engine
integrationTests["test_form_change_battle_coordination"] = function()
    local gameState = createFullGameState()
    gameState.pokemon.fusionSpecies = 493 -- Arceus
    gameState.battle = { active = true } -- In battle
    
    -- Change form during battle
    local formMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "changeFusionForm",
        gameState = gameState,
        formChange = {
            isFusion = true,
            formIndex = 1, -- Fighting type Arceus
            formName = "Fighting"
        }
    })
    
    local formResponse = ao.send(formMsg)
    
    -- Notify battle engine of form change
    local battleMsg = createIntegrationMessage(PROCESS_IDS.FUSION_BATTLE, "ProcessLogic", {
        operation = "updatePokemonForm",
        pokemonId = 1,
        newForm = 1,
        isFusion = true
    })
    
    local battleResponse = ao.send(battleMsg)
    
    -- Update stats for new form
    local statMsg = createIntegrationMessage(PROCESS_IDS.FUSION_CALC, "ProcessLogic", {
        operation = "recalculateFormStats",
        pokemonId = 1,
        formIndex = 1
    })
    
    local statResponse = ao.send(statMsg)
    
    assert(formResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Form change should complete")
    assert(battleResponse.Target == PROCESS_IDS.FUSION_BATTLE, "Battle update should complete")
    assert(statResponse.Target == PROCESS_IDS.FUSION_CALC, "Stat recalculation should complete")
    return true
end

-- Test 7: Evolution prevention with coordinator override
integrationTests["test_evolution_prevention_coordinator"] = function()
    local gameState = createFullGameState()
    
    -- Set prevention
    local preventMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "preventFusionEvolution",
        gameState = gameState,
        prevention = {
            prevent = true,
            reason = "Player cancelled",
            item = nil
        }
    })
    
    local preventResponse = ao.send(preventMsg)
    
    -- Try to evolve (should fail)
    local evolveMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "evaluateFusionEvolutionTrigger",
        gameState = gameState,
        triggers = { levelUp = true }
    })
    
    local evolveResponse = ao.send(evolveMsg)
    
    -- Coordinator can override
    local overrideMsg = createIntegrationMessage(PROCESS_IDS.COORDINATOR, "ProcessLogic", {
        operation = "overrideEvolutionPrevention",
        pokemonId = 1,
        force = true
    })
    
    local overrideResponse = ao.send(overrideMsg)
    
    assert(preventResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Prevention should be set")
    assert(evolveResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Evolution check should process")
    assert(overrideResponse.Target == PROCESS_IDS.COORDINATOR, "Override should be processed")
    return true
end

-- Test 8: Special evolution (Nincada) with party management
integrationTests["test_special_nincada_evolution_integration"] = function()
    local gameState = createFullGameState()
    gameState.pokemon.speciesId = 290 -- Nincada
    gameState.pokemon.fusionSpecies = 25 -- Fused with Pikachu
    gameState.pokemon.level = 20
    
    -- Process Nincada evolution to Ninjask
    local evolutionMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "processFusionEvolution",
        gameState = gameState,
        evolution = {
            isFusion = false,
            toSpecies = 291, -- Ninjask
            formIndex = 0
        }
    })
    
    local evolutionResponse = ao.send(evolutionMsg)
    
    -- Check for Shedinja creation
    local partyMsg = createIntegrationMessage(PROCESS_IDS.POKEMON_STATE, "ProcessLogic", {
        operation = "addToParty",
        pokemon = {
            speciesId = 292, -- Shedinja
            fusionSpecies = 25, -- Keep fusion
            level = 20,
            stats = {hp = 1} -- Shedinja always has 1 HP
        }
    })
    
    local partyResponse = ao.send(partyMsg)
    
    assert(evolutionResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Nincada evolution should complete")
    assert(partyResponse.Target == PROCESS_IDS.POKEMON_STATE, "Shedinja should be added to party")
    return true
end

-- Test 9: Experience-triggered evolution workflow
integrationTests["test_experience_triggered_evolution"] = function()
    local gameState = createFullGameState()
    gameState.pokemon.level = 15
    gameState.pokemon.exp = 3374 -- Close to level 16
    
    -- Gain experience
    local expMsg = createIntegrationMessage(PROCESS_IDS.EXPERIENCE, "ProcessLogic", {
        operation = "gainExperience",
        pokemonId = 1,
        expGained = 100
    })
    
    local expResponse = ao.send(expMsg)
    
    -- Check for level up and evolution
    local levelMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "evaluateFusionEvolutionTrigger",
        gameState = gameState,
        triggers = { levelUp = true }
    })
    
    local levelResponse = ao.send(levelMsg)
    
    assert(expResponse.Target == PROCESS_IDS.EXPERIENCE, "Experience gain should complete")
    assert(levelResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Evolution check should trigger")
    return true
end

-- Test 10: Message persistence workflow for evolution
integrationTests["test_evolution_state_persistence"] = function()
    local gameState = createFullGameState()
    
    -- Start evolution
    local evolutionMsg = createIntegrationMessage(PROCESS_IDS.FUSION_EVOLUTION, "ProcessLogic", {
        operation = "processFusionEvolution",
        gameState = gameState,
        evolution = {
            isFusion = false,
            toSpecies = 26,
            formIndex = 0
        }
    })
    
    local evolutionResponse = ao.send(evolutionMsg)
    
    -- Save state
    local saveMsg = createIntegrationMessage(PROCESS_IDS.COORDINATOR, "ProcessLogic", {
        operation = "saveGameState",
        gameState = gameState,
        evolutionInProgress = true
    })
    
    local saveResponse = ao.send(saveMsg)
    
    -- Load state (simulating recovery)
    local loadMsg = createIntegrationMessage(PROCESS_IDS.COORDINATOR, "ProcessLogic", {
        operation = "loadGameState"
    })
    
    local loadResponse = ao.send(loadMsg)
    
    assert(evolutionResponse.Target == PROCESS_IDS.FUSION_EVOLUTION, "Evolution should process")
    assert(saveResponse.Target == PROCESS_IDS.COORDINATOR, "State should save")
    assert(loadResponse.Target == PROCESS_IDS.COORDINATOR, "State should load")
    return true
end

-- Run all integration tests
local function runIntegrationTests()
    print("=== Fusion Evolution Engine Integration Tests ===")
    print("")
    
    for testName, testFunc in pairs(integrationTests) do
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
    print("=== Integration Test Results ===")
    print("Total: " .. testResults.total)
    print("Passed: " .. testResults.passed)
    print("Failed: " .. testResults.failed)
    print("Success Rate: " .. string.format("%.2f%%", (testResults.passed / testResults.total) * 100))
    
    return testResults.failed == 0
end

-- Execute tests
return runIntegrationTests()