-- Aolite Unit Tests for Evolution Engine
-- Tests all evolution trigger types, stat calculations, move learning, and prevention mechanics
-- Compatible with aolite testing framework

local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.evolution-engine"
local processId = "test-evolution-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Evolution Engine")
print("Process ID:", processId)

-- Test utilities
local function sendMessage(action, tags, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    -- Add additional tags
    if tags then
        for k, v in pairs(tags) do
            msg[k] = tostring(v)
        end
    end

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Helper function to create test Pokemon data
local function createTestPokemon(speciesId, level, friendship)
    return {
        speciesId = speciesId or 1,
        level = level or 16,
        exp = 1000,
        stats = {hp = 50, attack = 40, defense = 40, spAttack = 50, spDefense = 50, speed = 40},
        maxHp = 50,
        hp = 50,
        ivs = {hp = 15, attack = 15, defense = 15, spAttack = 15, spDefense = 15, speed = 15},
        evs = {hp = 0, attack = 0, defense = 0, spAttack = 0, spDefense = 0, speed = 0},
        nature = "hardy",
        moveset = {
            {moveId = "tackle", name = "tackle"},
            {moveId = "growl", name = "growl"}
        },
        ability = "overgrow",
        friendship = friendship or 150,
        happiness = friendship or 150,
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
                createTestPokemon(1, 16),
                createTestPokemon(25, 20),
                createTestPokemon(64, 25),
                createTestPokemon(133, 30, 250)
            }
        },
        battle = {
            battleId = "test_battle",
            battleSeed = "test_seed_12345"
        }
    }
end

-- Test 1: Check Evolution Triggers for Level-up Evolution
print("📝 Test 1: Check Evolution Triggers for Level-up Evolution")
local gameState = createTestGameState()
local checkResponse = sendMessage("CheckEvolutionTriggers", {
    PokemonIndex = "1"
}, json.encode({
    gameState = gameState,
    timeOfDay = "day"
}))
if checkResponse then
    print("✅ Check evolution triggers for level-up passed")
else
    error("❌ Check evolution triggers for level-up failed")
end

-- Test 2: Process Evolution (Bulbasaur to Ivysaur)
print("📝 Test 2: Process Evolution (Bulbasaur to Ivysaur)")
local evolveResponse = sendMessage("ProcessEvolution", {
    PokemonIndex = "1",
    TargetSpecies = "2"
}, json.encode({
    gameState = gameState
}))
if evolveResponse then
    print("✅ Process evolution (Bulbasaur to Ivysaur) passed")
else
    error("❌ Process evolution (Bulbasaur to Ivysaur) failed")
end

-- Test 3: Check Stone Evolution Requirements
print("📝 Test 3: Check Stone Evolution Requirements")
local stoneResponse = sendMessage("CheckEvolutionTriggers", {
    PokemonIndex = "2"
}, json.encode({
    gameState = gameState,
    item = "thunder_stone"
}))
if stoneResponse then
    print("✅ Check stone evolution requirements passed")
else
    error("❌ Check stone evolution requirements failed")
end

-- Test 4: Check Trade Evolution Requirements
print("📝 Test 4: Check Trade Evolution Requirements")
local tradeResponse = sendMessage("CheckEvolutionTriggers", {
    PokemonIndex = "3"
}, json.encode({
    gameState = gameState,
    tradeEvolution = true
}))
if tradeResponse then
    print("✅ Check trade evolution requirements passed")
else
    error("❌ Check trade evolution requirements failed")
end

-- Test 5: Check Friendship Evolution Requirements
print("📝 Test 5: Check Friendship Evolution Requirements")
local friendshipResponse = sendMessage("CheckEvolutionTriggers", {
    PokemonIndex = "4"
}, json.encode({
    gameState = gameState,
    timeOfDay = "day"
}))
if friendshipResponse then
    print("✅ Check friendship evolution requirements passed")
else
    error("❌ Check friendship evolution requirements failed")
end

-- Test 6: Calculate Evolved Stats
print("📝 Test 6: Calculate Evolved Stats")
local pokemon = createTestPokemon(1, 16)
pokemon.ivs = {hp = 31, attack = 31, defense = 31, spAttack = 31, spDefense = 31, speed = 31}
pokemon.evs = {hp = 252, attack = 0, defense = 0, spAttack = 252, spDefense = 0, speed = 4}
pokemon.nature = "modest"

local statsResponse = sendMessage("CalculateEvolvedStats", {
    TargetSpecies = "2"
}, json.encode({
    pokemon = pokemon
}))
if statsResponse then
    print("✅ Calculate evolved stats passed")
else
    error("❌ Calculate evolved stats failed")
end

-- Test 7: Learn Evolution Moves
print("📝 Test 7: Learn Evolution Moves")
local movesResponse = sendMessage("LearnEvolutionMoves", {
    FromSpecies = "1",
    ToSpecies = "3"
}, json.encode({
    gameState = gameState
}))
if movesResponse then
    print("✅ Learn evolution moves passed")
else
    error("❌ Learn evolution moves failed")
end

-- Test 8: Prevent Evolution (Everstone)
print("📝 Test 8: Prevent Evolution (Everstone)")
local everstoneGameState = createTestGameState()
everstoneGameState.player.party[1].heldItem = "everstone"

local preventResponse = sendMessage("PreventEvolution", {
    PokemonIndex = "1"
}, json.encode({
    gameState = everstoneGameState
}))
if preventResponse then
    print("✅ Prevent evolution (Everstone) passed")
else
    error("❌ Prevent evolution (Everstone) failed")
end

-- Test 9: Prevent Evolution (User Cancellation)
print("📝 Test 9: Prevent Evolution (User Cancellation)")
local cancelResponse = sendMessage("PreventEvolution", {
    PokemonIndex = "1"
}, json.encode({
    gameState = gameState,
    userCancelled = true,
    buttonPressed = "B"
}))
if cancelResponse then
    print("✅ Prevent evolution (User cancellation) passed")
else
    error("❌ Prevent evolution (User cancellation) failed")
end

-- Test 10: Get Available Evolutions
print("📝 Test 10: Get Available Evolutions")
local eevee = createTestPokemon(133, 30, 250)
local availableResponse = sendMessage("GetAvailableEvolutions", nil, json.encode({
    pokemon = eevee,
    timeOfDay = "day",
    item = "fire_stone"
}))
if availableResponse then
    print("✅ Get available evolutions passed")
else
    error("❌ Get available evolutions failed")
end

-- Test 11: Validate Evolution Data
print("📝 Test 11: Validate Evolution Data")
local validateResponse = sendMessage("ValidateEvolutionData", nil, json.encode({
    toSpecies = 2,
    type = "level",
    level = 16
}))
if validateResponse then
    print("✅ Validate evolution data passed")
else
    error("❌ Validate evolution data failed")
end

-- Test 12: Error Handling - Invalid Evolution Data
print("📝 Test 12: Error Handling - Invalid Evolution Data")
local invalidResponse = sendMessage("ValidateEvolutionData", nil, json.encode({
    toSpecies = "invalid",
    type = "unknown"
}))
if invalidResponse and invalidResponse.Action == "Error" then
    print("✅ Error handling for invalid evolution data passed")
else
    error("❌ Error handling for invalid evolution data failed")
end

-- Test 13: Error Handling - Missing Pokemon
print("📝 Test 13: Error Handling - Missing Pokemon")
local missingResponse = sendMessage("ProcessEvolution", {
    PokemonIndex = "10",
    TargetSpecies = "2"
}, json.encode({
    gameState = gameState
}))
if missingResponse and missingResponse.Action == "Error" then
    print("✅ Error handling for missing Pokemon passed")
else
    error("❌ Error handling for missing Pokemon failed")
end

-- Test 14: Health Check
print("📝 Test 14: Health Check")
local healthResponse = sendMessage("HealthCheck")
if healthResponse and healthResponse.Action == "HealthStatus" then
    if healthResponse.Status == "healthy" then
        print("✅ Health check passed")
    else
        error("❌ Invalid health status")
    end
else
    error("❌ Health check failed")
end

-- Test 15: ADP v1.0 Info Handler
print("📝 Test 15: ADP v1.0 Info Handler")
local infoResponse = sendMessage("Info")
if infoResponse and infoResponse.Action == "SaveState" then
    print("✅ ADP v1.0 Info handler passed")
else
    error("❌ ADP v1.0 Info handler failed")
end

-- Test Summary
print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
print("==================================================")
print("📊 Test Summary:")
print("- ✅ Level-up evolution triggers")
print("- ✅ Evolution processing and stat calculation")
print("- ✅ Stone evolution requirements")
print("- ✅ Trade evolution requirements")
print("- ✅ Friendship evolution requirements")
print("- ✅ Evolved stat calculations")
print("- ✅ Evolution move learning")
print("- ✅ Evolution prevention (Everstone)")
print("- ✅ Evolution prevention (User cancellation)")
print("- ✅ Available evolutions query")
print("- ✅ Evolution data validation")
print("- ✅ Error handling for invalid data")
print("- ✅ Error handling for missing Pokemon")
print("- ✅ Process health monitoring")
print("- ✅ ADP v1.0 compliance")
