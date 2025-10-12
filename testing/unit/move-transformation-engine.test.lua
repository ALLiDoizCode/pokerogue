-- Unit tests for Move Transformation Engine
-- Tests transformation timing logic, stat copying, ability interactions, and duration tracking

local aolite = require("aolite")
local json = require("json")

local PROCESS_PATH = "processes.move-transformation-engine"
local processId = "test-move-transformation-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Move Transformation Engine")
print("Process ID:", processId)

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

local function createMockPokemon(speciesId, form, abilities, stats)
    return {
        speciesId = speciesId,
        form = form or "default",
        abilities = abilities or {},
        baseStats = stats or {hp = 100, atk = 100, def = 100, spa = 100, spd = 100, spe = 100},
        types = {"NORMAL"},
        moveset = {}
    }
end

-- Test 1: Aegislash pre-move transformation (Shield to Blade)
print("📝 Test 1: Aegislash Shield to Blade transformation on offensive move")
local aegislashData = json.encode(createMockPokemon(681, "shield", {STANCE_CHANGE = true}))
local response1 = sendMessage("ProcessPreMoveTransformation", {
    PokemonId = "aegislash_001",
    MoveId = "THUNDERBOLT",
    SpeciesId = "681",
    CurrentForm = "shield"
}, aegislashData)
if not response1 or response1.Action == "Error" then
    error("❌ Test failed: Expected successful Aegislash transformation")
end
print("✅ Test 1 passed: Aegislash Shield to Blade transformation")

-- Test 2: Aegislash pre-move transformation (Blade to Shield with King's Shield)
print("📝 Test 2: Aegislash Blade to Shield transformation on King's Shield")
local aegislashBladeData = json.encode(createMockPokemon(681, "blade", {STANCE_CHANGE = true}))
local response2 = sendMessage("ProcessPreMoveTransformation", {
    PokemonId = "aegislash_001",
    MoveId = "KINGS_SHIELD",
    SpeciesId = "681",
    CurrentForm = "blade"
}, aegislashBladeData)
if not response2 or response2.Action == "Error" then
    error("❌ Test failed: Expected successful King's Shield transformation")
end
print("✅ Test 2 passed: Aegislash Blade to Shield transformation")

-- Test 3: Aegislash transformation blocked without Stance Change ability
print("📝 Test 3: Aegislash transformation blocked without required ability")
local noAbilityData = json.encode(createMockPokemon(681, "shield", {}))
local response3 = sendMessage("ProcessPreMoveTransformation", {
    PokemonId = "aegislash_001",
    MoveId = "THUNDERBOLT",
    SpeciesId = "681",
    CurrentForm = "shield"
}, noAbilityData)
if response3 and response3.Action ~= "Error" and response3.Action ~= "NoTransformation" then
    error("❌ Test failed: Expected transformation to be blocked")
end
print("✅ Test 3 passed: Transformation blocked without required ability")

-- Test 4: Meloetta post-move transformation (Aria to Pirouette)
print("📝 Test 4: Meloetta Aria to Pirouette transformation on Relic Song")
local meloettaData = json.encode(createMockPokemon(648, "aria", {}))
local response4 = sendMessage("ProcessPostMoveTransformation", {
    PokemonId = "meloetta_001",
    MoveId = "RELIC_SONG",
    SpeciesId = "648",
    CurrentForm = "aria"
}, meloettaData)
if not response4 or response4.Action == "Error" then
    error("❌ Test failed: Expected successful Meloetta transformation")
end
print("✅ Test 4 passed: Meloetta Aria to Pirouette transformation")

-- Test 5: Meloetta transformation blocked by Sheer Force
print("📝 Test 5: Meloetta transformation blocked by Sheer Force ability")
local sheerForceData = json.encode(createMockPokemon(648, "aria", {SHEER_FORCE = true}))
local response5 = sendMessage("ProcessPostMoveTransformation", {
    PokemonId = "meloetta_001",
    MoveId = "RELIC_SONG",
    SpeciesId = "648",
    CurrentForm = "aria"
}, sheerForceData)
if response5 and response5.Action ~= "Error" and response5.Action ~= "NoTransformation" then
    error("❌ Test failed: Expected transformation to be blocked by Sheer Force")
end
print("✅ Test 5 passed: Meloetta transformation blocked by Sheer Force")

-- Test 6: Transform move success
print("📝 Test 6: Transform move complete species transformation")
local userPokemon = createMockPokemon(132, "default", {}, {hp = 48, atk = 48, def = 48, spa = 48, spd = 48, spe = 48})
local targetPokemon = createMockPokemon(25, "default", {STATIC = true}, {hp = 35, atk = 55, def = 40, spa = 50, spd = 50, spe = 90})
targetPokemon.types = {"ELECTRIC"}
targetPokemon.moveset = {
    {moveId = "THUNDERBOLT", pp = 15, maxPP = 15},
    {moveId = "QUICK_ATTACK", pp = 30, maxPP = 30}
}

local transformData = json.encode({
    user = userPokemon,
    target = targetPokemon
})

local response6 = sendMessage("ProcessTransformMove", {
    UserPokemonId = "ditto_001",
    TargetPokemonId = "pikachu_001",
    BattleId = "battle_001"
}, transformData)
if not response6 or response6.Action == "Error" then
    error("❌ Test failed: Expected successful Transform move")
end
print("✅ Test 6 passed: Transform move success")

-- Test 7: Transform move failure (same species)
print("📝 Test 7: Transform move fails on same species")
local sameSpeciesData = json.encode({
    user = createMockPokemon(25, "default"),
    target = createMockPokemon(25, "default")
})

local response7 = sendMessage("ProcessTransformMove", {
    UserPokemonId = "pikachu_001",
    TargetPokemonId = "pikachu_002"
}, sameSpeciesData)
if response7 and response7.Action ~= "Error" and response7.Action ~= "TransformFailed" then
    error("❌ Test failed: Expected Transform to fail on same species")
end
print("✅ Test 7 passed: Transform move failure on same species")

-- Test 8: Transformation reversion on switch out
print("📝 Test 8: Transform reversion on switch out")
local response8 = sendMessage("RevertTransformation", {
    PokemonId = "ditto_001",
    BattleId = "battle_001",
    RevertType = "switch_out"
})
if not response8 or response8.Action == "Error" then
    error("❌ Test failed: Expected successful transformation reversion")
end
print("✅ Test 8 passed: Transformation reversion")

-- Test 9: Move learned transformation (Keldeo)
print("📝 Test 9: Keldeo transformation on Secret Sword learned")
local keldeoData = json.encode(createMockPokemon(647, "ordinary", {}))
local response9 = sendMessage("ProcessMoveLearnedTransformation", {
    PokemonId = "keldeo_001",
    MoveId = "SECRET_SWORD",
    SpeciesId = "647",
    CurrentForm = "ordinary"
}, keldeoData)
if not response9 or response9.Action == "Error" then
    error("❌ Test failed: Expected successful Keldeo transformation")
end
print("✅ Test 9 passed: Keldeo transformation on Secret Sword learned")

-- Test 10: Get transformation info
print("📝 Test 10: Get transformation info for Aegislash")
local response10 = sendMessage("GetTransformationInfo", {
    SpeciesId = "681"
})
if not response10 or response10.Action == "Error" then
    error("❌ Test failed: Expected successful transformation info retrieval")
end
print("✅ Test 10 passed: Get transformation info")

-- Test 11: ADP Info handler
print("📝 Test 11: ADP Info handler returns comprehensive process information")
local response11 = sendMessage("Info")
if not response11 or response11.Action ~= "SaveState" then
    error("❌ Test failed: Expected SaveState response for Info")
end
print("✅ Test 11 passed: ADP Info handler")

-- Test 12: Ping handler
print("📝 Test 12: Ping handler responds correctly")
local response12 = sendMessage("Ping")
if not response12 or response12.Action ~= "Pong" then
    error("❌ Test failed: Expected Pong response")
end
print("✅ Test 12 passed: Ping handler")

print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
