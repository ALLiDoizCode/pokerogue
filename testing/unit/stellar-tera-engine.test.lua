-- Unit Tests for Stellar Tera Engine
-- Tests Stellar-specific STAB calculations, usage tracking, and Terapagos exceptions

local aolite = require("aolite")
local json = require("json")

-- Test Configuration
local PROCESS_PATH = "processes.stellar-tera-engine"
local processId = "test-stellar-tera-engine"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("🧪 Starting Aolite Tests for Stellar Tera Engine")
print("Process ID:", processId)
print("==================================================")

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

-- Test Pokemon data
local TEST_POKEMON = {
    charizard = {
        id = "charizard_001",
        speciesId = "CHARIZARD",
        types = {"FIRE", "FLYING"},
        hp = 100,
        teraType = "STELLAR",
        isTerastallized = false,
        stellarTypesBoosted = {}
    },
    pikachu = {
        id = "pikachu_001",
        speciesId = "PIKACHU",
        types = {"ELECTRIC"},
        hp = 100,
        teraType = "STELLAR",
        isTerastallized = false,
        stellarTypesBoosted = {}
    },
    terapagos = {
        id = "terapagos_001",
        speciesId = "TERAPAGOS",
        types = {"NORMAL"},
        hp = 100,
        teraType = "STELLAR",
        isTerastallized = false,
        stellarTypesBoosted = {}
    }
}

-- ===============================
-- STELLAR ACTIVATION TESTS
-- ===============================

print("\n📝 Test 1: Activate Stellar Tera for regular Pokemon")
local pokemon1 = json.decode(json.encode(TEST_POKEMON.charizard))
local response1 = sendMessage("ProcessStellarTera", {
    Operation = "activate",
    BattleId = "test-battle-001"
}, json.encode(pokemon1))

if response1 and response1.Success == "true" then
    local updatedPokemon = json.decode(response1.Data or "{}")
    if updatedPokemon.isTerastallized == true and updatedPokemon.teraType == "STELLAR" then
        print("✅ Test 1 passed - Stellar Tera activated")
    else
        error("❌ Test 1 failed: Stellar Tera activation incomplete")
    end
else
    error("❌ Test 1 failed: Expected Success='true'")
end

print("\n📝 Test 2: Activate Stellar Tera for Terapagos")
local pokemon2 = json.decode(json.encode(TEST_POKEMON.terapagos))
local response2 = sendMessage("ProcessStellarTera", {
    Operation = "activate",
    BattleId = "test-battle-002"
}, json.encode(pokemon2))

if response2 and response2.Success == "true" then
    local updatedPokemon = json.decode(response2.Data or "{}")
    if updatedPokemon.isTerastallized == true then
        print("✅ Test 2 passed - Terapagos Stellar Tera activated")
    else
        error("❌ Test 2 failed: Terapagos Stellar Tera activation incomplete")
    end
else
    error("❌ Test 2 failed: Expected Success='true'")
end

print("\n📝 Test 3: Handle invalid Pokemon data")
local response3 = sendMessage("ProcessStellarTera", {
    Operation = "activate",
    BattleId = "test-battle-003"
}, json.encode({invalid = true}))

if response3 and (response3.Action == "Error" or not response3.Success or response3.Success ~= "true") then
    print("✅ Test 3 passed - Invalid data handled correctly")
else
    error("❌ Test 3 failed: Expected error or non-success response")
end

-- ===============================
-- STAB CALCULATION TESTS
-- ===============================

print("\n📝 Test 4: Calculate 1.5x STAB for matching natural type (first use)")
local pokemon4 = json.decode(json.encode(TEST_POKEMON.charizard))
pokemon4.isTerastallized = true
pokemon4.stellarTypesBoosted = {}
local response4 = sendMessage("CalculateStellarSTAB", {
    MoveType = "FIRE",
    MoveCategory = "SPECIAL"
}, json.encode(pokemon4))

if response4 and response4.STABMultiplier == "1.5" and response4.IsFirstUsage == "true" then
    print("✅ Test 4 passed - 1.5x STAB for matching type")
else
    error("❌ Test 4 failed: Expected STABMultiplier=1.5 and IsFirstUsage=true")
end

print("\n📝 Test 5: Calculate 1.2x STAB for non-matching type (first use)")
local pokemon5 = json.decode(json.encode(TEST_POKEMON.charizard))
pokemon5.isTerastallized = true
pokemon5.stellarTypesBoosted = {}
local response5 = sendMessage("CalculateStellarSTAB", {
    MoveType = "ELECTRIC",
    MoveCategory = "SPECIAL"
}, json.encode(pokemon5))

if response5 and response5.STABMultiplier == "1.2" and response5.IsFirstUsage == "true" then
    print("✅ Test 5 passed - 1.2x STAB for non-matching type")
else
    error("❌ Test 5 failed: Expected STABMultiplier=1.2 and IsFirstUsage=true")
end

print("\n📝 Test 6: Return 1.0x STAB for already boosted type")
local pokemon6 = json.decode(json.encode(TEST_POKEMON.charizard))
pokemon6.isTerastallized = true
pokemon6.stellarTypesBoosted = {"FIRE"}
local response6 = sendMessage("CalculateStellarSTAB", {
    MoveType = "FIRE",
    MoveCategory = "SPECIAL"
}, json.encode(pokemon6))

if response6 and response6.STABMultiplier == "1.0" and response6.IsFirstUsage == "false" then
    print("✅ Test 6 passed - 1.0x STAB for already boosted type")
else
    error("❌ Test 6 failed: Expected STABMultiplier=1.0 and IsFirstUsage=false")
end

print("\n📝 Test 7: Return 1.0x STAB for STATUS moves")
local pokemon7 = json.decode(json.encode(TEST_POKEMON.charizard))
pokemon7.isTerastallized = true
pokemon7.stellarTypesBoosted = {}
local response7 = sendMessage("CalculateStellarSTAB", {
    MoveType = "FIRE",
    MoveCategory = "STATUS"
}, json.encode(pokemon7))

if response7 and response7.STABMultiplier == "1.0" then
    print("✅ Test 7 passed - 1.0x STAB for STATUS moves")
else
    error("❌ Test 7 failed: Expected STABMultiplier=1.0 for STATUS moves")
end

print("\n📝 Test 8: Return 1.0x STAB when not terastallized")
local pokemon8 = json.decode(json.encode(TEST_POKEMON.charizard))
pokemon8.isTerastallized = false
local response8 = sendMessage("CalculateStellarSTAB", {
    MoveType = "FIRE",
    MoveCategory = "SPECIAL"
}, json.encode(pokemon8))

if response8 and response8.STABMultiplier == "1.0" then
    print("✅ Test 8 passed - 1.0x STAB when not terastallized")
else
    error("❌ Test 8 failed: Expected STABMultiplier=1.0 when not terastallized")
end

-- ===============================
-- TERAPAGOS EXCEPTION TESTS
-- ===============================

print("\n📝 Test 9: Terapagos unlimited 1.5x STAB for matching types")
local pokemon9 = json.decode(json.encode(TEST_POKEMON.terapagos))
pokemon9.isTerastallized = true

-- First use
local response9a = sendMessage("CalculateStellarSTAB", {
    MoveType = "NORMAL",
    MoveCategory = "PHYSICAL"
}, json.encode(pokemon9))

if response9a and response9a.STABMultiplier == "1.5" and response9a.IsTerapagos == "true" then
    print("  ✓ First use: 1.5x STAB")
else
    error("❌ Test 9 failed: Expected 1.5x STAB for Terapagos first use")
end

-- Track usage (shouldn't affect Terapagos)
sendMessage("TrackStellarUsage", {
    MoveType = "NORMAL",
    MoveCategory = "PHYSICAL"
}, json.encode(pokemon9))

-- Second use - should still get bonus
local response9b = sendMessage("CalculateStellarSTAB", {
    MoveType = "NORMAL",
    MoveCategory = "PHYSICAL"
}, json.encode(pokemon9))

if response9b and response9b.STABMultiplier == "1.5" and response9b.IsTerapagos == "true" then
    print("  ✓ Second use: 1.5x STAB (unlimited)")
    print("✅ Test 9 passed - Terapagos unlimited STAB")
else
    error("❌ Test 9 failed: Expected 1.5x STAB for Terapagos second use")
end

print("\n📝 Test 10: Terapagos unlimited 1.2x STAB for non-matching types")
local pokemon10 = json.decode(json.encode(TEST_POKEMON.terapagos))
pokemon10.isTerastallized = true

-- Multiple uses of non-matching type
for i = 1, 3 do
    local response = sendMessage("CalculateStellarSTAB", {
        MoveType = "WATER",
        MoveCategory = "SPECIAL"
    }, json.encode(pokemon10))

    if not (response and response.STABMultiplier == "1.2" and response.IsTerapagos == "true") then
        error("❌ Test 10 failed: Expected 1.2x STAB for Terapagos non-matching (iteration " .. i .. ")")
    end

    -- Track usage (shouldn't affect Terapagos)
    sendMessage("TrackStellarUsage", {
        MoveType = "WATER",
        MoveCategory = "SPECIAL"
    }, json.encode(pokemon10))
end
print("✅ Test 10 passed - Terapagos unlimited 1.2x STAB")

print("\n📝 Test 11: Recognize all Terapagos forms")
local forms = {"TERAPAGOS", "TERAPAGOS_TERASTAL", "TERAPAGOS_STELLAR"}
for _, form in ipairs(forms) do
    local pokemon = {
        id = "test_" .. form,
        speciesId = form,
        types = {"NORMAL"},
        hp = 100,
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {}
    }

    local response = sendMessage("CalculateStellarSTAB", {
        MoveType = "NORMAL",
        MoveCategory = "PHYSICAL"
    }, json.encode(pokemon))

    if not (response and response.IsTerapagos == "true" and response.STABMultiplier == "1.5") then
        error("❌ Test 11 failed: Expected Terapagos recognition for " .. form)
    end
end
print("✅ Test 11 passed - All Terapagos forms recognized")

-- ===============================
-- USAGE TRACKING TESTS
-- ===============================

print("\n📝 Test 12: Track first-time type usage")
local pokemon12 = json.decode(json.encode(TEST_POKEMON.pikachu))
pokemon12.isTerastallized = true
pokemon12.stellarTypesBoosted = {}
pokemon12.id = "pikachu_test12"

local response12 = sendMessage("TrackStellarUsage", {
    MoveType = "ELECTRIC",
    MoveCategory = "SPECIAL"
}, json.encode(pokemon12))

if response12 and response12.Tracked == "true" then
    local boostedTypes = json.decode(response12.StellarTypesBoosted or "[]")
    if #boostedTypes == 1 and boostedTypes[1] == "ELECTRIC" and response12.RemainingBoosts == "17" then
        print("✅ Test 12 passed - First-time usage tracked")
    else
        error("❌ Test 12 failed: Usage tracking incomplete")
    end
else
    error("❌ Test 12 failed: Expected Tracked=true")
end

print("\n📝 Test 13: Not track duplicate type usage")
local pokemon13 = json.decode(json.encode(TEST_POKEMON.pikachu))
pokemon13.isTerastallized = true
pokemon13.stellarTypesBoosted = {"ELECTRIC"}
pokemon13.id = "pikachu_test13"

local response13 = sendMessage("TrackStellarUsage", {
    MoveType = "ELECTRIC",
    MoveCategory = "SPECIAL"
}, json.encode(pokemon13))

if response13 and response13.Tracked == "false" then
    local boostedTypes = json.decode(response13.StellarTypesBoosted or "[]")
    if #boostedTypes == 1 then
        print("✅ Test 13 passed - Duplicate usage not tracked")
    else
        error("❌ Test 13 failed: Boosted types count mismatch")
    end
else
    error("❌ Test 13 failed: Expected Tracked=false")
end

print("\n📝 Test 14: Not track STATUS moves")
local pokemon14 = json.decode(json.encode(TEST_POKEMON.pikachu))
pokemon14.isTerastallized = true
pokemon14.stellarTypesBoosted = {}
pokemon14.id = "pikachu_test14"

local response14 = sendMessage("TrackStellarUsage", {
    MoveType = "ELECTRIC",
    MoveCategory = "STATUS"
}, json.encode(pokemon14))

if response14 and response14.Tracked == "false" then
    local boostedTypes = json.decode(response14.StellarTypesBoosted or "[]")
    if #boostedTypes == 0 then
        print("✅ Test 14 passed - STATUS moves not tracked")
    else
        error("❌ Test 14 failed: STATUS move was tracked")
    end
else
    error("❌ Test 14 failed: Expected Tracked=false for STATUS")
end

print("\n📝 Test 15: Not track usage for Terapagos")
local pokemon15 = json.decode(json.encode(TEST_POKEMON.terapagos))
pokemon15.isTerastallized = true
pokemon15.stellarTypesBoosted = {}
pokemon15.id = "terapagos_test15"

local response15 = sendMessage("TrackStellarUsage", {
    MoveType = "NORMAL",
    MoveCategory = "PHYSICAL"
}, json.encode(pokemon15))

if response15 and response15.Tracked == "true" then
    local boostedTypes = json.decode(response15.StellarTypesBoosted or "[]")
    if #boostedTypes == 0 then
        print("✅ Test 15 passed - Terapagos doesn't track usage")
    else
        error("❌ Test 15 failed: Terapagos tracking should remain empty")
    end
else
    error("❌ Test 15 failed: Expected Tracked=true but no actual tracking")
end

-- ===============================
-- MULTI-TYPE SCENARIO TESTS
-- ===============================

print("\n📝 Test 16: Handle Charizard multi-type sequence correctly")
local pokemon16 = json.decode(json.encode(TEST_POKEMON.charizard))
pokemon16.isTerastallized = true
pokemon16.stellarTypesBoosted = {}
pokemon16.id = "charizard_test16"

local moveSequence = {
    {type = "FIRE", category = "SPECIAL"},      -- Matching: 1.5x
    {type = "FLYING", category = "PHYSICAL"},   -- Matching: 1.5x
    {type = "ELECTRIC", category = "SPECIAL"},  -- Non-matching: 1.2x
    {type = "FIRE", category = "SPECIAL"}       -- Already used: 1.0x
}

local response16 = sendMessage("ProcessMultiTypeStellar", {
    MoveSequence = json.encode(moveSequence)
}, json.encode(pokemon16))

if response16 and response16.Results then
    local results = json.decode(response16.Results or "[]")
    local updatedPokemon = json.decode(response16.UpdatedPokemonData or "{}")

    if results[1].stabMultiplier == 1.5 and results[1].tracked == true and
       results[2].stabMultiplier == 1.5 and results[2].tracked == true and
       results[3].stabMultiplier == 1.2 and results[3].tracked == true and
       results[4].stabMultiplier == 1 and results[4].tracked == true and
       #updatedPokemon.stellarTypesBoosted == 3 then
        print("✅ Test 16 passed - Multi-type sequence correct")
    else
        error("❌ Test 16 failed: Multi-type sequence results incorrect")
    end
else
    error("❌ Test 16 failed: Expected Results field")
end

print("\n📝 Test 17: Filter STATUS moves from tracking")
local pokemon17 = json.decode(json.encode(TEST_POKEMON.charizard))
pokemon17.isTerastallized = true
pokemon17.stellarTypesBoosted = {}
pokemon17.id = "charizard_test17"

local moveSequence17 = {
    {type = "FIRE", category = "STATUS"},
    {type = "FIRE", category = "SPECIAL"},
    {type = "FLYING", category = "STATUS"},
    {type = "FLYING", category = "PHYSICAL"}
}

local response17 = sendMessage("ProcessMultiTypeStellar", {
    MoveSequence = json.encode(moveSequence17)
}, json.encode(pokemon17))

if response17 and response17.Results then
    local results = json.decode(response17.Results or "[]")
    local updatedPokemon = json.decode(response17.UpdatedPokemonData or "{}")

    if results[1].stabMultiplier == 1 and  -- STATUS: no STAB
       results[2].stabMultiplier == 1.5 and -- First FIRE attack
       results[3].stabMultiplier == 1 and  -- STATUS: no STAB
       results[4].stabMultiplier == 1.5 and -- First FLYING attack
       #updatedPokemon.stellarTypesBoosted == 2 then -- Only FIRE and FLYING
        print("✅ Test 17 passed - STATUS moves filtered correctly")
    else
        error("❌ Test 17 failed: STATUS move filtering incorrect")
    end
else
    error("❌ Test 17 failed: Expected Results field")
end

-- ===============================
-- STATE MANAGEMENT TESTS
-- ===============================

print("\n📝 Test 18: Reset Stellar state correctly")
local pokemon18 = json.decode(json.encode(TEST_POKEMON.pikachu))
pokemon18.isTerastallized = true
pokemon18.stellarTypesBoosted = {"ELECTRIC", "WATER", "FIRE"}
pokemon18.id = "pikachu_test18"

local response18 = sendMessage("ProcessStellarTera", {
    Operation = "reset",
    BattleId = "test-battle-018"
}, json.encode(pokemon18))

if response18 and response18.Success == "true" then
    local updatedPokemon = json.decode(response18.Data or "{}")
    if updatedPokemon.isTerastallized == false and #updatedPokemon.stellarTypesBoosted == 0 then
        print("✅ Test 18 passed - Stellar state reset")
    else
        error("❌ Test 18 failed: State reset incomplete")
    end
else
    error("❌ Test 18 failed: Expected Success=true")
end

print("\n📝 Test 19: Get Stellar state information")
local pokemon19 = json.decode(json.encode(TEST_POKEMON.charizard))
pokemon19.isTerastallized = true
pokemon19.stellarTypesBoosted = {"FIRE", "WATER"}
pokemon19.id = "charizard_test19"

local response19 = sendMessage("ProcessStellarTera", {
    Operation = "get_state"
}, json.encode(pokemon19))

if response19 and response19.StellarState then
    local state = json.decode(response19.StellarState or "{}")
    if state.isActive == true and #state.stellarTypesBoosted == 2 and
       state.isTerapagos == false and state.remainingBoostCount == 16 then
        print("✅ Test 19 passed - Stellar state retrieved")
    else
        error("❌ Test 19 failed: State information incorrect")
    end
else
    error("❌ Test 19 failed: Expected StellarState field")
end

print("\n📝 Test 20: Reset battle-wide Stellar tracking")
local pokemonList = {
    json.decode(json.encode(TEST_POKEMON.charizard)),
    json.decode(json.encode(TEST_POKEMON.pikachu))
}

for i, pokemon in ipairs(pokemonList) do
    pokemon.isTerastallized = true
    pokemon.stellarTypesBoosted = {"FIRE", "WATER"}
    pokemon.id = "pokemon_test20_" .. i
end

local response20 = sendMessage("ResetBattleStellar", {
    BattleId = "test-battle-020",
    PokemonList = json.encode(pokemonList)
})

if response20 and response20.BattleId == "test-battle-020" and response20.PokemonCount == "2" then
    print("✅ Test 20 passed - Battle-wide reset successful")
else
    error("❌ Test 20 failed: Expected BattleId and PokemonCount")
end

-- ===============================
-- STATE VALIDATION TESTS
-- ===============================

print("\n📝 Test 21: Validate correct Stellar state")
local battleState21 = {
    playerTeam = {
        pokemon1 = {
            teraType = "STELLAR",
            stellarTypesBoosted = {"FIRE", "WATER"},
            speciesId = "CHARIZARD"
        }
    },
    enemyTeam = {
        pokemon1 = {
            teraType = "STELLAR",
            stellarTypesBoosted = {"DARK"},
            speciesId = "UMBREON"
        }
    }
}

local response21 = sendMessage("ValidateStellarState", {}, json.encode(battleState21))

if response21 and response21.Valid == "true" then
    print("✅ Test 21 passed - Valid state recognized")
else
    error("❌ Test 21 failed: Expected Valid=true")
end

print("\n📝 Test 22: Detect duplicate Stellar boosts")
local battleState22 = {
    playerTeam = {
        pokemon1 = {
            teraType = "STELLAR",
            stellarTypesBoosted = {"FIRE", "WATER", "FIRE"}, -- Duplicate
            speciesId = "CHARIZARD"
        }
    }
}

local response22 = sendMessage("ValidateStellarState", {}, json.encode(battleState22))

if response22 and response22.Valid == "false" then
    local results = json.decode(response22.ValidationResults or "{}")
    if results.errors and #results.errors > 0 then
        print("✅ Test 22 passed - Duplicate boosts detected")
    else
        error("❌ Test 22 failed: Expected validation errors")
    end
else
    error("❌ Test 22 failed: Expected Valid=false")
end

print("\n📝 Test 23: Warn about Terapagos with tracking")
local battleState23 = {
    playerTeam = {
        pokemon1 = {
            teraType = "STELLAR",
            stellarTypesBoosted = {"NORMAL"}, -- Shouldn't have tracking
            speciesId = "TERAPAGOS"
        }
    }
}

local response23 = sendMessage("ValidateStellarState", {}, json.encode(battleState23))

if response23 and response23.ValidationResults then
    local results = json.decode(response23.ValidationResults or "{}")
    if results.warnings and #results.warnings > 0 then
        print("✅ Test 23 passed - Terapagos tracking warning issued")
    else
        error("❌ Test 23 failed: Expected validation warnings")
    end
else
    error("❌ Test 23 failed: Expected ValidationResults field")
end

-- ===============================
-- TYPE EFFECTIVENESS TESTS
-- ===============================

print("\n📝 Test 24: Return 1.0x effectiveness for Stellar moves")
local attacker24 = json.decode(json.encode(TEST_POKEMON.charizard))
attacker24.isTerastallized = true
attacker24.id = "charizard_test24"

local defender24 = {
    types = {"WATER", "GROUND"}
}

local response24 = sendMessage("GetStellarEffectiveness", {
    AttackerData = json.encode(attacker24),
    DefenderData = json.encode(defender24),
    MoveType = "STELLAR"
})

if response24 and response24.Effectiveness == "1.0" and response24.IsStellarMove == "true" then
    print("✅ Test 24 passed - Stellar effectiveness 1.0x")
else
    error("❌ Test 24 failed: Expected Effectiveness=1.0 and IsStellarMove=true")
end

print("\n📝 Test 25: Not affect non-Stellar move effectiveness")
local attacker25 = json.decode(json.encode(TEST_POKEMON.charizard))
attacker25.isTerastallized = true
attacker25.id = "charizard_test25"

local defender25 = {
    types = {"GRASS"}
}

local response25 = sendMessage("GetStellarEffectiveness", {
    AttackerData = json.encode(attacker25),
    DefenderData = json.encode(defender25),
    MoveType = "FIRE"
})

if response25 and response25.Effectiveness == "1.0" and response25.IsStellarMove == "false" then
    print("✅ Test 25 passed - Non-Stellar moves unaffected")
else
    error("❌ Test 25 failed: Expected Effectiveness=1.0 and IsStellarMove=false")
end

-- ===============================
-- ERROR HANDLING TESTS
-- ===============================

print("\n📝 Test 26: Handle missing Pokemon data")
local response26 = sendMessage("CalculateStellarSTAB", {
    MoveType = "FIRE",
    MoveCategory = "SPECIAL"
}, json.encode(nil))

if response26 and response26.STABMultiplier == "1.0" then
    print("✅ Test 26 passed - Missing Pokemon data handled")
else
    error("❌ Test 26 failed: Expected STABMultiplier=1.0 for nil data")
end

print("\n📝 Test 27: Handle missing move type (defaults to NORMAL)")
local pokemon27 = json.decode(json.encode(TEST_POKEMON.charizard))
pokemon27.isTerastallized = true
pokemon27.id = "charizard_test27"

local response27 = sendMessage("CalculateStellarSTAB", {
    -- Missing MoveType (defaults to NORMAL)
}, json.encode(pokemon27))

-- For Charizard (FIRE/FLYING), NORMAL is non-matching so 1.2x
if response27 and response27.STABMultiplier == "1.2" and response27.MoveType == "NORMAL" then
    print("✅ Test 27 passed - Missing move type defaults to NORMAL (1.2x non-matching)")
else
    error("❌ Test 27 failed: Expected STABMultiplier=1.2 for default NORMAL type")
end

print("\n📝 Test 28: Handle corrupted stellarTypesBoosted array")
local pokemon28 = json.decode(json.encode(TEST_POKEMON.charizard))
pokemon28.isTerastallized = true
pokemon28.stellarTypesBoosted = "not_an_array" -- Corrupted
pokemon28.id = "charizard_test28"

local response28 = sendMessage("CalculateStellarSTAB", {
    MoveType = "FIRE",
    MoveCategory = "SPECIAL"
}, json.encode(pokemon28))

if response28 and response28.STABMultiplier then
    print("✅ Test 28 passed - Corrupted array handled gracefully")
else
    error("❌ Test 28 failed: Expected STABMultiplier field")
end

-- ===============================
-- ADP COMPLIANCE TESTS
-- ===============================

print("\n📝 Test 29: Respond to Info action with complete metadata")
local response29 = sendMessage("Info")

if response29 and response29.Data then
    local info = json.decode(response29.Data or "{}")
    if info.Name == "Stellar Tera Engine" and
       info.adpVersion == "1.0" and
       info.handlers and #info.handlers > 0 and
       info.capabilities and info.capabilities.adpCompliant == true and
       info.constants and info.constants.stellarMatchingBonus == 1.5 and
       info.constants.stellarNonMatchingBonus == 1.2 then
        print("✅ Test 29 passed - ADP v1.0 compliant Info response")
    else
        error("❌ Test 29 failed: Info response incomplete or incorrect")
    end
else
    error("❌ Test 29 failed: Expected Data field in Info response")
end

print("\n📝 Test 30: Respond to Ping action")
local response30 = sendMessage("Ping")

if response30 and response30.Action == "Pong" and
   response30.Data == "pong" and
   response30.ProcessType == "StellarTeraEngine" then
    print("✅ Test 30 passed - Ping/Pong successful")
else
    error("❌ Test 30 failed: Expected Pong response")
end

print("\n📝 Test 31: Respond to HealthCheck action")
local response31 = sendMessage("HealthCheck")

if response31 and response31.Action == "HealthCheckResponse" and
   response31.Status == "healthy" and
   response31.Version and
   response31.ActiveBattles then
    print("✅ Test 31 passed - HealthCheck successful")
else
    error("❌ Test 31 failed: Expected HealthCheckResponse with Status, Version, ActiveBattles")
end

-- ===============================
-- TEST SUMMARY
-- ===============================

print("\n==================================================")
print("🎉 All 31 tests passed!")
print("✅ Test file executed successfully: " .. PROCESS_PATH)
print("==================================================")
print("\n📊 Test Coverage Summary:")
print("  - Stellar activation: 3 tests")
print("  - STAB calculations: 5 tests")
print("  - Terapagos exceptions: 3 tests")
print("  - Usage tracking: 4 tests")
print("  - Multi-type scenarios: 2 tests")
print("  - State management: 3 tests")
print("  - State validation: 3 tests")
print("  - Type effectiveness: 2 tests")
print("  - Error handling: 3 tests")
print("  - ADP compliance: 3 tests")
print("==================================================")
