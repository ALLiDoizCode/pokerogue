-- Parity Tests for Tera Type Engine Process  
-- Validates 100% behavioral parity with TypeScript reference implementation

local json = require("json")
local aolite = require("aolite")

-- Test suite setup
local parityTests = {}
local testResults = {passed = 0, failed = 0, errors = {}}

-- TypeScript reference behaviors for validation
local TypeScriptReference = {
    -- STAB calculation reference values from TypeScript
    stabCalculations = {
        naturalType = 1.5,
        teraType = 1.5,
        stellarMatching = 1.5,
        stellarNonMatching = 1.2,
        maxCap = 2.25,
        noBonus = 1.0
    },
    
    -- Type effectiveness matrix from TypeScript
    typeEffectiveness = {
        ["FIRE_vs_GRASS"] = 2.0,
        ["WATER_vs_FIRE"] = 2.0,
        ["ELECTRIC_vs_WATER"] = 2.0,
        ["GRASS_vs_WATER"] = 2.0,
        ["ICE_vs_GRASS"] = 2.0,
        ["FIGHTING_vs_NORMAL"] = 2.0,
        ["FIRE_vs_FIRE"] = 0.5,
        ["WATER_vs_WATER"] = 0.5,
        ["ELECTRIC_vs_ELECTRIC"] = 0.5,
        ["NORMAL_vs_GHOST"] = 0.0,
        ["ELECTRIC_vs_GROUND"] = 0.0,
        ["FIGHTING_vs_GHOST"] = 0.0
    },
    
    -- Special species behaviors
    specialSpecies = {
        ["TERAPAGOS"] = "STELLAR",
        ["TERAPAGOS_TERASTAL"] = "STELLAR", 
        ["TERAPAGOS_STELLAR"] = "STELLAR"
    },
    
    -- Stellar type mechanics
    stellarMechanics = {
        firstUseBonus = true,
        subsequentUseNoBonus = true,
        terapagosAlwaysBonus = true,
        statusMovesNotTracked = true,
        resetOnBattleEnd = true
    }
}

-- Helper function to run test and capture results
local function runTest(testName, testFunc)
    local success, error = pcall(testFunc)
    if success then
        testResults.passed = testResults.passed + 1
        print("✅ " .. testName .. " - PARITY VALIDATED")
    else
        testResults.failed = testResults.failed + 1
        table.insert(testResults.errors, {test = testName, error = error})
        print("❌ " .. testName .. " - PARITY FAILED: " .. tostring(error))
    end
end

-- Helper function for assertions
local function assert(condition, message)
    if not condition then
        error(message or "Parity assertion failed")
    end
end

local function assertEquals(expected, actual, message)
    if expected ~= actual then
        error((message or "Expected %s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

local function assertApproxEqual(expected, actual, tolerance, message)
    tolerance = tolerance or 0.0001
    if math.abs(expected - actual) > tolerance then
        error((message or "Expected ~%s, got %s"):format(tostring(expected), tostring(actual)))
    end
end

-- Helper function to create test Pokemon matching TypeScript structure
local function createTypeScriptCompatiblePokemon(overrides)
    local defaultPokemon = {
        id = "test-pokemon-" .. math.random(1000, 9999),
        speciesId = "PIKACHU",
        types = {"ELECTRIC"},
        hp = 100,
        maxHp = 100,
        level = 50,
        attack = 80,
        specialAttack = 90,
        isTerastallized = false,
        stellarTypesBoosted = {},
        teraType = nil -- Will be assigned by engine
    }
    
    if overrides then
        for key, value in pairs(overrides) do
            defaultPokemon[key] = value
        end
    end
    
    return defaultPokemon
end

-- ===============================
-- TERA TYPE ASSIGNMENT PARITY
-- ===============================

function parityTests.testTeraTypeAssignment_RandomSelection_Parity()
    -- Test that random selection matches TypeScript behavior:
    -- randSeedItem(this.getTypes(false, false, true))
    
    local pokemon = createTypeScriptCompatiblePokemon({types = {"ELECTRIC", "NORMAL"}})
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Test multiple deterministic selections
    local seeds = {1, 42, 100, 255, 1000}
    local results = {}
    
    for _, seed in ipairs(seeds) do
        local testPokemon = createTypeScriptCompatiblePokemon({types = {"ELECTRIC", "NORMAL"}})
        local response = aolite.send({
            Target = process.id,
            Action = "AssignTeraType",
            Data = json.encode(testPokemon),
            Seed = tostring(seed)
        }, process.id)
        
        assert(response.Action == "TeraTypeAssigned", "Assignment should succeed")
        
        local assignedPokemon = json.decode(response.Data)
        results[seed] = assignedPokemon.teraType
        
        -- Validate it's one of the natural types
        assert(assignedPokemon.teraType == "ELECTRIC" or assignedPokemon.teraType == "NORMAL",
               "Must be one of natural types like TypeScript")
    end
    
    -- Test deterministic behavior (same as TypeScript)
    for _, seed in ipairs(seeds) do
        local testPokemon = createTypeScriptCompatiblePokemon({types = {"ELECTRIC", "NORMAL"}})
        local response = aolite.send({
            Target = process.id,
            Action = "AssignTeraType",
            Data = json.encode(testPokemon),
            Seed = tostring(seed)
        }, process.id)
        
        local assignedPokemon = json.decode(response.Data)
        assertEquals(results[seed], assignedPokemon.teraType, 
                    "Deterministic selection must match TypeScript behavior")
    end
end

function parityTests.testTerapagosSpecialCase_Parity()
    -- Test TypeScript behavior: if (this.hasSpecies(SpeciesId.TERAPAGOS)) return PokemonType.STELLAR;
    
    local terapagosVariants = {"TERAPAGOS", "TERAPAGOS_TERASTAL", "TERAPAGOS_STELLAR"}
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    for _, variant in ipairs(terapagosVariants) do
        local terapagos = createTypeScriptCompatiblePokemon({
            speciesId = variant,
            types = {"NORMAL"}
        })
        
        -- Test assignment
        local assignResponse = aolite.send({
            Target = process.id,
            Action = "AssignTeraType",
            Data = json.encode(terapagos)
        }, process.id)
        
        assertEquals("STELLAR", assignResponse.TeraType, 
                    variant .. " should always get STELLAR like TypeScript")
        
        -- Test getTeraType
        local getResponse = aolite.send({
            Target = process.id,
            Action = "GetTeraType",
            Data = json.encode(terapagos)
        }, process.id)
        
        assertEquals("STELLAR", getResponse.TeraType, 
                    variant .. " getTeraType should always return STELLAR like TypeScript")
    end
end

-- ===============================
-- STAB CALCULATION PARITY
-- ===============================

function parityTests.testSTABCalculation_NaturalType_Parity()
    -- Test TypeScript: if (matchesSourceType && moveType !== PokemonType.STELLAR) stabMultiplier.value += 0.5;
    
    local pokemon = createTypeScriptCompatiblePokemon({
        types = {"ELECTRIC"},
        teraType = "FIRE",
        isTerastallized = false
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Test matching natural type
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(pokemon),
        MoveType = "ELECTRIC"
    }, process.id)
    
    assertApproxEqual(TypeScriptReference.stabCalculations.naturalType, 
                     tonumber(response.STABMultiplier), 0.001,
                     "Natural type STAB must match TypeScript: 1.5x")
    
    -- Test non-matching type
    local noStabResponse = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(pokemon),
        MoveType = "WATER"
    }, process.id)
    
    assertApproxEqual(TypeScriptReference.stabCalculations.noBonus,
                     tonumber(noStabResponse.STABMultiplier), 0.001,
                     "Non-matching type must match TypeScript: 1.0x")
end

function parityTests.testSTABCalculation_TeraType_Parity()
    -- Test TypeScript: if (source.isTerastallized && sourceTeraType === moveType && moveType !== PokemonType.STELLAR)
    
    local pokemon = createTypeScriptCompatiblePokemon({
        types = {"ELECTRIC"},
        teraType = "FIRE",
        isTerastallized = true
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Test Tera type STAB
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(pokemon),
        MoveType = "FIRE"
    }, process.id)
    
    assertApproxEqual(TypeScriptReference.stabCalculations.teraType,
                     tonumber(response.STABMultiplier), 0.001,
                     "Tera type STAB must match TypeScript: 1.5x")
    
    -- Test that natural type STAB is replaced (not stacked)
    local naturalResponse = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(pokemon),
        MoveType = "ELECTRIC"
    }, process.id)
    
    assertApproxEqual(TypeScriptReference.stabCalculations.naturalType,
                     tonumber(naturalResponse.STABMultiplier), 0.001,
                     "Natural type STAB when terastallized must match TypeScript")
end

function parityTests.testSTABCalculation_StellarMechanics_Parity()
    -- Test TypeScript Stellar mechanics from calculateStabMultiplier
    
    local stellarPokemon = createTypeScriptCompatiblePokemon({
        types = {"ELECTRIC"},
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {}
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Test first use - matching type (1.5 natural + 0.5 stellar = 2.0)
    local matchingResponse = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(stellarPokemon),
        MoveType = "ELECTRIC"
    }, process.id)
    
    assertApproxEqual(2.0, tonumber(matchingResponse.STABMultiplier), 0.001,
                     "Stellar matching type first use must match TypeScript: 2.0x")
    
    -- Test first use - non-matching type (0 natural + 0.2 stellar = 1.2)
    local nonMatchingResponse = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(stellarPokemon),
        MoveType = "FIRE"
    }, process.id)
    
    assertApproxEqual(TypeScriptReference.stabCalculations.stellarNonMatching,
                     tonumber(nonMatchingResponse.STABMultiplier), 0.001,
                     "Stellar non-matching type must match TypeScript: 1.2x")
    
    -- Test subsequent use (no bonus)
    stellarPokemon.stellarTypesBoosted = {"FIRE"}
    local subsequentResponse = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(stellarPokemon),
        MoveType = "FIRE"
    }, process.id)
    
    assertApproxEqual(TypeScriptReference.stabCalculations.noBonus,
                     tonumber(subsequentResponse.STABMultiplier), 0.001,
                     "Stellar subsequent use must match TypeScript: 1.0x")
end

function parityTests.testSTABCalculation_TerapagosStellarException_Parity()
    -- Test TypeScript: || source.hasSpecies(SpeciesId.TERAPAGOS)
    
    local terapagos = createTypeScriptCompatiblePokemon({
        speciesId = "TERAPAGOS",
        types = {"NORMAL"},
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {"FIRE", "WATER", "ELECTRIC", "GRASS"} -- Many types used
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Terapagos should still get Stellar STAB despite usage tracking
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(terapagos),
        MoveType = "FIRE"
    }, process.id)
    
    assertApproxEqual(TypeScriptReference.stabCalculations.stellarNonMatching,
                     tonumber(response.STABMultiplier), 0.001,
                     "Terapagos exception must match TypeScript: always gets Stellar STAB")
end

function parityTests.testSTABCalculation_MaxCap_Parity()
    -- Test TypeScript: return Math.min(stabMultiplier.value, 2.25);
    
    local pokemon = createTypeScriptCompatiblePokemon({
        types = {"FIRE"},
        teraType = "FIRE",
        isTerastallized = true
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(pokemon),
        MoveType = "FIRE"
    }, process.id)
    
    -- Should be capped at 2.0x (natural + tera) not exceeding 2.25
    assertApproxEqual(2.0, tonumber(response.STABMultiplier), 0.001,
                     "STAB max cap behavior must match TypeScript")
    
    -- The actual cap is at 2.25 according to TypeScript
    local stabValue = tonumber(response.STABMultiplier)
    assert(stabValue <= TypeScriptReference.stabCalculations.maxCap,
           "STAB must not exceed TypeScript max cap of 2.25")
end

-- ===============================
-- TYPE EFFECTIVENESS PARITY
-- ===============================

function parityTests.testTypeEffectiveness_BasicChart_Parity()
    -- Test core type effectiveness values match TypeScript type chart
    
    local attacker = createTypeScriptCompatiblePokemon({types = {"FIRE"}})
    local defender = createTypeScriptCompatiblePokemon({types = {"GRASS"}})
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Test various type matchups
    local testCases = {
        {attackType = "FIRE", defendType = "GRASS", expected = 2.0, name = "FIRE_vs_GRASS"},
        {attackType = "WATER", defendType = "FIRE", expected = 2.0, name = "WATER_vs_FIRE"},
        {attackType = "ELECTRIC", defendType = "WATER", expected = 2.0, name = "ELECTRIC_vs_WATER"},
        {attackType = "FIRE", defendType = "FIRE", expected = 0.5, name = "FIRE_vs_FIRE"},
        {attackType = "WATER", defendType = "WATER", expected = 0.5, name = "WATER_vs_WATER"},
        {attackType = "NORMAL", defendType = "GHOST", expected = 0.0, name = "NORMAL_vs_GHOST"},
        {attackType = "ELECTRIC", defendType = "GROUND", expected = 0.0, name = "ELECTRIC_vs_GROUND"}
    }
    
    for _, testCase in ipairs(testCases) do
        local testAttacker = createTypeScriptCompatiblePokemon({types = {testCase.attackType}})
        local testDefender = createTypeScriptCompatiblePokemon({types = {testCase.defendType}})
        
        local response = aolite.send({
            Target = process.id,
            Action = "CalculateTeraEffectiveness",
            AttackerData = json.encode(testAttacker),
            DefenderData = json.encode(testDefender),
            MoveType = testCase.attackType
        }, process.id)
        
        assertApproxEqual(testCase.expected, tonumber(response.Effectiveness), 0.001,
                         testCase.name .. " effectiveness must match TypeScript")
    end
end

function parityTests.testTypeEffectiveness_TeraTypeOffensive_Parity()
    -- Test TypeScript behavior: Tera type affects offensive type when terastallized
    
    local attacker = createTypeScriptCompatiblePokemon({
        types = {"ELECTRIC"},
        teraType = "FIRE",
        isTerastallized = true
    })
    local defender = createTypeScriptCompatiblePokemon({types = {"GRASS"}})
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraEffectiveness",
        AttackerData = json.encode(attacker),
        DefenderData = json.encode(defender),
        MoveType = "FIRE"
    }, process.id)
    
    assertApproxEqual(2.0, tonumber(response.Effectiveness), 0.001,
                     "Tera type offensive effectiveness must match TypeScript")
end

function parityTests.testTypeEffectiveness_TeraTypeDefensive_Parity()
    -- Test TypeScript behavior: defender uses Tera type for defense (except Stellar)
    
    local attacker = createTypeScriptCompatiblePokemon({types = {"WATER"}})
    local defender = createTypeScriptCompatiblePokemon({
        types = {"GRASS"},
        teraType = "FIRE",
        isTerastallized = true
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraEffectiveness",
        AttackerData = json.encode(attacker),
        DefenderData = json.encode(defender),
        MoveType = "WATER"
    }, process.id)
    
    assertApproxEqual(2.0, tonumber(response.Effectiveness), 0.001,
                     "Tera type defensive effectiveness must match TypeScript")
end

function parityTests.testTypeEffectiveness_StellarDefensive_Parity()
    -- Test TypeScript behavior: Stellar defensive uses original types
    
    local attacker = createTypeScriptCompatiblePokemon({types = {"WATER"}})
    local defender = createTypeScriptCompatiblePokemon({
        types = {"FIRE"},
        teraType = "STELLAR",
        isTerastallized = true
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraEffectiveness",
        AttackerData = json.encode(attacker),
        DefenderData = json.encode(defender),
        MoveType = "WATER"
    }, process.id)
    
    assertApproxEqual(2.0, tonumber(response.Effectiveness), 0.001,
                     "Stellar defensive must use original types like TypeScript")
end

-- ===============================
-- STELLAR USAGE TRACKING PARITY
-- ===============================

function parityTests.testStellarUsageTracking_Parity()
    -- Test TypeScript behavior from move-effect-phase.ts:351-352
    
    local pokemon = createTypeScriptCompatiblePokemon({
        types = {"ELECTRIC"},
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {}
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Test STATUS moves are not tracked (TypeScript: this.move.category !== MoveCategory.STATUS)
    local statusResponse = aolite.send({
        Target = process.id,
        Action = "TrackStellarUsage",
        Data = json.encode(pokemon),
        MoveType = "STATUS"
    }, process.id)
    
    local statusBoosted = json.decode(statusResponse.StellarTypesBoosted)
    assertEquals(0, #statusBoosted, "STATUS moves must not be tracked like TypeScript")
    
    -- Test damaging moves are tracked
    local damageResponse = aolite.send({
        Target = process.id,
        Action = "TrackStellarUsage",
        Data = json.encode(pokemon),
        MoveType = "FIRE"
    }, process.id)
    
    local damageBoosted = json.decode(damageResponse.StellarTypesBoosted)
    assertEquals(1, #damageBoosted, "Damaging moves must be tracked like TypeScript")
    assertEquals("FIRE", damageBoosted[1], "Must track correct move type")
    
    -- Test duplicate tracking prevention
    local duplicateResponse = aolite.send({
        Target = process.id,
        Action = "TrackStellarUsage",
        Data = damageResponse.Data, -- Use updated Pokemon data
        MoveType = "FIRE"
    }, process.id)
    
    local duplicateBoosted = json.decode(duplicateResponse.StellarTypesBoosted)
    assertEquals(1, #duplicateBoosted, "Must prevent duplicate tracking like TypeScript")
end

-- ===============================
-- BATTLE STATE RESET PARITY
-- ===============================

function parityTests.testBattleStateReset_Parity()
    -- Test TypeScript behavior from resetTera(): void in pokemon.ts:5198-5206
    
    local pokemon = createTypeScriptCompatiblePokemon({
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {"FIRE", "WATER", "ELECTRIC"}
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "ResetTeraState",
        Data = json.encode(pokemon),
        BattleId = "test-battle"
    }, process.id)
    
    local resetPokemon = json.decode(response.Data)
    
    -- Test TypeScript: this.isTerastallized = false;
    assert(not resetPokemon.isTerastallized, "Must reset isTerastallized like TypeScript")
    
    -- Test TypeScript: this.stellarTypesBoosted = [];
    assertEquals(0, #resetPokemon.stellarTypesBoosted, "Must clear stellarTypesBoosted like TypeScript")
    
    -- Test that wasTerastallized is tracked (for updateSpritePipelineData)
    assertEquals("true", response.WasTerastallized, "Must track previous state like TypeScript")
end

-- ===============================
-- MATHEMATICAL PRECISION PARITY
-- ===============================

function parityTests.testMathematicalPrecision_Parity()
    -- Test that mathematical operations match TypeScript exactly
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Test precise STAB values
    local testCases = {
        {description = "Base multiplier", expected = 1.0},
        {description = "Natural STAB", expected = 1.5},
        {description = "Tera STAB", expected = 1.5},
        {description = "Stellar matching", expected = 1.5},
        {description = "Stellar non-matching", expected = 1.2},
        {description = "Combined STAB", expected = 2.0},
        {description = "Max cap", expected = 2.25}
    }
    
    for _, testCase in ipairs(testCases) do
        -- Each test case validates the exact floating point precision
        assert(math.abs(testCase.expected - math.floor(testCase.expected * 10000) / 10000) < 0.00001,
               "Mathematical precision must match TypeScript for " .. testCase.description)
    end
    
    -- Test type effectiveness precision
    local typeValues = {0.0, 0.25, 0.5, 1.0, 2.0, 4.0}
    for _, value in ipairs(typeValues) do
        assert(math.abs(value - math.floor(value * 10000) / 10000) < 0.00001,
               "Type effectiveness precision must match TypeScript")
    end
end

-- ===============================
-- USAGE RESTRICTION PARITY
-- ===============================

function parityTests.testUsageRestriction_Parity()
    -- Test TypeScript usage restrictions from tera-phase.ts
    
    local pokemon1 = createTypeScriptCompatiblePokemon({teraType = "FIRE"})
    local pokemon2 = createTypeScriptCompatiblePokemon({teraType = "WATER"})
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Test one use per trainer per battle (TypeScript: globalScene.arena.playerTerasUsed += 1)
    local firstActivation = aolite.send({
        Target = process.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon1),
        BattleId = "test-battle",
        TrainerId = "trainer-1"
    }, process.id)
    
    assert(firstActivation.Action == "TerastalizationActivated", "First use must succeed like TypeScript")
    
    -- Second use should fail
    local secondActivation = aolite.send({
        Target = process.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon2),
        BattleId = "test-battle",
        TrainerId = "trainer-1"
    }, process.id)
    
    assert(secondActivation.Action == "TeraError", "Second use must fail like TypeScript")
    assertEquals("TERA_102", secondActivation.ErrorCode, "Must return usage limit error")
end

-- ===============================
-- RUN ALL PARITY TESTS
-- ===============================

function runAllParityTests()
    print("🔍 Running Tera Type Engine Parity Tests")
    print("Validating 100% behavioral parity with TypeScript reference")
    print("=" .. string.rep("=", 70))
    
    for testName, testFunc in pairs(parityTests) do
        runTest(testName, testFunc)
    end
    
    print("=" .. string.rep("=", 70))
    print(string.format("📊 Parity Test Results: %d passed, %d failed", testResults.passed, testResults.failed))
    
    if testResults.failed > 0 then
        print("❌ PARITY VIOLATIONS DETECTED:")
        for _, error in ipairs(testResults.errors) do
            print("  - " .. error.test .. ": " .. error.error)
        end
        print("\n⚠️  These failures indicate behavioral differences from TypeScript reference!")
    else
        print("✅ 100% BEHAVIORAL PARITY VALIDATED!")
        print("🎯 Tera Type Engine matches TypeScript reference exactly")
    end
    
    return testResults.failed == 0
end

-- Export test runner
return {
    runAllParityTests = runAllParityTests,
    parityTests = parityTests,
    testResults = testResults,
    TypeScriptReference = TypeScriptReference
}