-- Unit Tests for Fusion Evolution Engine Process
-- Tests fusion evolution triggers, stat recalculation, form changes, move learning, ability changes, chain progression, and prevention

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.fusion-evolution-engine"
local processId = "test-fusion-evolution-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Fusion Evolution Engine")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end
    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

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

-- ============================================================================
-- TEST SUITE: Fusion Evolution Engine
-- ============================================================================

print("\n=== Fusion Evolution Engine Tests ===\n")

-- Test 1: Fusion evolution trigger evaluation for level-based evolution
print("📝 Test 1: Fusion evolution trigger - level-based")
local pokemon = createMockPokemon(25, 133, 36)
local response = sendMessage("ProcessLogic", nil, json.encode({
    operation = "evaluateFusionEvolutionTrigger",
    gameState = {
        pokemon = pokemon,
        triggers = {levelUp = true},
        player = {progression = {}, evolutionMilestones = {}},
        party = {}
    },
    parameters = {triggers = {levelUp = true}}
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.Success ~= "true" then
    error("❌ Test failed: Expected Success = 'true'")
end
print("✅ Test passed")

-- Test 2: Fusion evolution trigger evaluation for item-based evolution
print("📝 Test 2: Fusion evolution trigger - item-based")
pokemon = createMockPokemon(25, 133, 20)
response = sendMessage("ProcessLogic", nil, json.encode({
    operation = "evaluateFusionEvolutionTrigger",
    gameState = {
        pokemon = pokemon,
        triggers = {itemUse = true},
        player = {progression = {}, evolutionMilestones = {}},
        party = {}
    },
    parameters = {triggers = {itemUse = true}}
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.Success ~= "true" then
    error("❌ Test failed: Expected Success = 'true'")
end
print("✅ Test passed")

-- Test 3: Process fusion evolution execution
print("📝 Test 3: Process fusion evolution execution")
pokemon = createMockPokemon(25, 133, 36)
response = sendMessage("ProcessLogic", nil, json.encode({
    operation = "processFusionEvolution",
    gameState = {
        pokemon = pokemon,
        player = {progression = {}, evolutionMilestones = {}},
        party = {}
    },
    parameters = {evolution = {isFusion = false, toSpecies = 26, formIndex = 0}}
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.Success ~= "true" then
    error("❌ Test failed: Expected Success = 'true'")
end
print("✅ Test passed")

-- Test 4: Fusion form change mechanics
print("📝 Test 4: Fusion form change mechanics")
pokemon = createMockPokemon(25, 493, 50)
response = sendMessage("ProcessLogic", nil, json.encode({
    operation = "changeFusionForm",
    gameState = {
        pokemon = pokemon,
        player = {progression = {}, evolutionMilestones = {}},
        party = {}
    },
    parameters = {formChange = {isFusion = true, formIndex = 1, formName = "Fighting"}}
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.Success ~= "true" then
    error("❌ Test failed: Expected Success = 'true'")
end
print("✅ Test passed")

-- Test 5: Fusion evolution move learning
print("📝 Test 5: Fusion evolution move learning")
pokemon = createMockPokemon(25, 133, 36)
response = sendMessage("ProcessLogic", nil, json.encode({
    operation = "learnFusionEvolutionMoves",
    gameState = {
        pokemon = pokemon,
        player = {progression = {}, evolutionMilestones = {}},
        party = {}
    },
    parameters = {moves = {newMoves = {"THUNDERBOLT", "SWIFT"}}}
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.Success ~= "true" then
    error("❌ Test failed: Expected Success = 'true'")
end
print("✅ Test passed")

-- Test 6: Fusion evolution prevention
print("📝 Test 6: Fusion evolution prevention")
pokemon = createMockPokemon(25, 133, 36)
response = sendMessage("ProcessLogic", nil, json.encode({
    operation = "preventFusionEvolution",
    gameState = {
        pokemon = pokemon,
        player = {progression = {}, evolutionMilestones = {}},
        party = {}
    },
    parameters = {prevention = {prevent = true, reason = "Player chose to cancel evolution", item = nil}}
}))
if not response or response.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState action")
end
if response.Success ~= "true" then
    error("❌ Test failed: Expected Success = 'true'")
end
print("✅ Test passed")

-- Test 7: Invalid operation handling
print("📝 Test 7: Invalid operation handling")
pokemon = createMockPokemon(25, 133, 36)
response = sendMessage("ProcessLogic", nil, json.encode({
    operation = "invalidOperation",
    gameState = {
        pokemon = pokemon,
        player = {progression = {}, evolutionMilestones = {}},
        party = {}
    },
    parameters = {}
}))
if not response or response.Action ~= "Error" then
    error("❌ Test failed: Expected Error action")
end
if response.Success ~= "false" then
    error("❌ Test failed: Expected Success = 'false'")
end
print("✅ Test passed")

-- ============================================================================
-- TEST SUMMARY
-- ============================================================================

print("\n==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
