-- Unit Tests for Tera Type Engine Process
-- Tests all core Tera type mechanics and error handling

-- Mock json for testing (use global json in AO environment)
local json = _G.json or {
    encode = function(t) return "mock_json" end,
    decode = function(s) return {} end
}

-- Mock aolite setup for testing

-- Test suite setup
local tests = {}
local testResults = {passed = 0, failed = 0, errors = {}}

-- Helper function to create test Pokemon data
local function createTestPokemon(overrides)
    local defaultPokemon = {
        id = "test-pokemon-1",
        speciesId = "PIKACHU",
        types = {"ELECTRIC"},
        hp = 100,
        maxHp = 100,
        level = 50,
        isTerastallized = false,
        stellarTypesBoosted = {}
    }
    
    if overrides then
        for key, value in pairs(overrides) do
            defaultPokemon[key] = value
        end
    end
    
    return defaultPokemon
end

-- Helper function to run test and capture results
local function runTest(testName, testFunc)
    local success, error = pcall(testFunc)
    if success then
        testResults.passed = testResults.passed + 1
        print("✅ " .. testName .. " - PASSED")
    else
        testResults.failed = testResults.failed + 1
        table.insert(testResults.errors, {test = testName, error = error})
        print("❌ " .. testName .. " - FAILED: " .. tostring(error))
    end
end

-- Helper function for assertions
local function assert(condition, message)
    if not condition then
        error(message or "Assertion failed")
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

-- ===============================
-- TERA TYPE ASSIGNMENT TESTS
-- ===============================

function tests.testTeraTypeAssignment_DefaultRandomSelection()
    local pokemon = createTestPokemon({types = {"ELECTRIC", "NORMAL"}})
    
    -- Test multiple seeds to ensure deterministic randomness
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Test with seed 1
    local response1 = aolite.send({
        Target = process.id,
        Action = "AssignTeraType",
        Data = json.encode(pokemon),
        Seed = "1"
    }, process.id)
    
    assert(response1.Action == "TeraTypeAssigned", "Expected TeraTypeAssigned action")
    assert(response1.Success == "true", "Assignment should succeed")
    
    local assignedPokemon1 = json.decode(response1.Data)
    assert(assignedPokemon1.teraType == "ELECTRIC" or assignedPokemon1.teraType == "NORMAL", 
           "Tera type should be one of natural types")
    
    -- Test with same seed should give same result
    local pokemon2 = createTestPokemon({types = {"ELECTRIC", "NORMAL"}})
    local response2 = aolite.send({
        Target = process.id,
        Action = "AssignTeraType",
        Data = json.encode(pokemon2),
        Seed = "1"
    }, process.id)
    
    local assignedPokemon2 = json.decode(response2.Data)
    assertEquals(assignedPokemon1.teraType, assignedPokemon2.teraType, "Same seed should give same result")
end

function tests.testTeraTypeAssignment_TerapagosSpecialCase()
    local terapagos = createTestPokemon({
        speciesId = "TERAPAGOS",
        types = {"NORMAL"}
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "AssignTeraType",
        Data = json.encode(terapagos)
    }, process.id)
    
    assert(response.Action == "TeraTypeAssigned", "Expected TeraTypeAssigned action")
    assertEquals("STELLAR", response.TeraType, "Terapagos should always get STELLAR type")
    
    local assignedPokemon = json.decode(response.Data)
    assertEquals("STELLAR", assignedPokemon.teraType, "Terapagos teraType should be STELLAR")
end

function tests.testTeraTypeAssignment_PreferredType()
    local pokemon = createTestPokemon({types = {"ELECTRIC"}})
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "AssignTeraType",
        Data = json.encode(pokemon),
        TeraType = "FIRE"
    }, process.id)
    
    assert(response.Action == "TeraTypeAssigned", "Expected TeraTypeAssigned action")
    assertEquals("FIRE", response.TeraType, "Should assign preferred Tera type")
    
    local assignedPokemon = json.decode(response.Data)
    assertEquals("FIRE", assignedPokemon.teraType, "Assigned Pokemon should have preferred type")
end

function tests.testTeraTypeAssignment_InvalidType()
    local pokemon = createTestPokemon()
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "AssignTeraType",
        Data = json.encode(pokemon),
        TeraType = "INVALID_TYPE"
    }, process.id)
    
    assert(response.Action == "TeraError", "Expected error for invalid type")
    assertEquals("TERA_002", response.ErrorCode, "Should return TERA_002 error code")
end

function tests.testTeraTypeAssignment_AlreadyAssigned()
    local pokemon = createTestPokemon({teraType = "FIRE"})
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "AssignTeraType",
        Data = json.encode(pokemon)
    }, process.id)
    
    assert(response.Action == "TeraError", "Expected error for already assigned")
    assertEquals("TERA_004", response.ErrorCode, "Should return TERA_004 error code")
end

-- ===============================
-- TERASTALIZATION ACTIVATION TESTS  
-- ===============================

function tests.testTerastalizationActivation_Success()
    local pokemon = createTestPokemon({teraType = "FIRE"})
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon),
        BattleId = "test-battle-1",
        TrainerId = "trainer-1",
        Turn = "1"
    }, process.id)
    
    assert(response.Action == "TerastalizationActivated", "Expected TerastalizationActivated action")
    assertEquals("true", response.Success, "Activation should succeed")
    assertEquals("FIRE", response.TeraType, "Should return Pokemon's Tera type")
    
    local activatedPokemon = json.decode(response.Data)
    assert(activatedPokemon.isTerastallized, "Pokemon should be terastallized")
    assertEquals(1, activatedPokemon.teraActivationTurn, "Should track activation turn")
end

function tests.testTerastalizationActivation_UsageLimitExceeded()
    local pokemon1 = createTestPokemon({teraType = "FIRE", id = "pokemon-1"})
    local pokemon2 = createTestPokemon({teraType = "WATER", id = "pokemon-2"})
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- First activation should succeed
    local response1 = aolite.send({
        Target = process.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon1),
        BattleId = "test-battle-1",
        TrainerId = "trainer-1"
    }, process.id)
    
    assert(response1.Action == "TerastalizationActivated", "First activation should succeed")
    
    -- Second activation should fail
    local response2 = aolite.send({
        Target = process.id,
        Action = "ActivateTerastalization", 
        Data = json.encode(pokemon2),
        BattleId = "test-battle-1",
        TrainerId = "trainer-1"
    }, process.id)
    
    assert(response2.Action == "TeraError", "Second activation should fail")
    assertEquals("TERA_102", response2.ErrorCode, "Should return usage limit error")
end

function tests.testTerastalizationActivation_AlreadyTerastallized()
    local pokemon = createTestPokemon({
        teraType = "FIRE",
        isTerastallized = true
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon),
        BattleId = "test-battle-1",
        TrainerId = "trainer-1"
    }, process.id)
    
    assert(response.Action == "TeraError", "Expected error for already terastallized")
    assertEquals("TERA_101", response.ErrorCode, "Should return TERA_101 error code")
end

function tests.testTerastalizationActivation_FaintedPokemon()
    local pokemon = createTestPokemon({
        teraType = "FIRE",
        hp = 0
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon),
        BattleId = "test-battle-1",
        TrainerId = "trainer-1"
    }, process.id)
    
    assert(response.Action == "TeraError", "Expected error for fainted Pokemon")
    assertEquals("TERA_104", response.ErrorCode, "Should return TERA_104 error code")
end

-- ===============================
-- STAB CALCULATION TESTS
-- ===============================

function tests.testSTABCalculation_NaturalType()
    local pokemon = createTestPokemon({
        types = {"ELECTRIC"},
        teraType = "FIRE",
        isTerastallized = false
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(pokemon),
        MoveType = "ELECTRIC"
    }, process.id)
    
    assert(response.Action == "TeraSTABCalculated", "Expected TeraSTABCalculated action")
    assertApproxEqual(1.5, tonumber(response.STABMultiplier), 0.01, "Should get 1.5x STAB for natural type")
end

function tests.testSTABCalculation_TeraType()
    local pokemon = createTestPokemon({
        types = {"ELECTRIC"},
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
    
    assert(response.Action == "TeraSTABCalculated", "Expected TeraSTABCalculated action")
    assertApproxEqual(1.5, tonumber(response.STABMultiplier), 0.01, "Should get 1.5x STAB for Tera type")
end

function tests.testSTABCalculation_StellarFirstUse()
    local pokemon = createTestPokemon({
        types = {"ELECTRIC"},
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {}
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    
    -- Test matching type (should get 1.5x)
    local response1 = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(pokemon),
        MoveType = "ELECTRIC"
    }, process.id)
    
    assertApproxEqual(2.0, tonumber(response1.STABMultiplier), 0.01, "Stellar matching type: 1.5 natural + 0.5 stellar = 2.0")
    
    -- Test non-matching type (should get 1.2x)
    local response2 = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(pokemon),
        MoveType = "FIRE"
    }, process.id)
    
    assertApproxEqual(1.2, tonumber(response2.STABMultiplier), 0.01, "Stellar non-matching type should get 1.2x")
end

function tests.testSTABCalculation_StellarSubsequentUse()
    local pokemon = createTestPokemon({
        types = {"ELECTRIC"},
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {"FIRE"}
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(pokemon),
        MoveType = "FIRE"
    }, process.id)
    
    assertApproxEqual(1.0, tonumber(response.STABMultiplier), 0.01, "Subsequent Stellar use should get no bonus")
end

function tests.testSTABCalculation_TerapagosException()
    local terapagos = createTestPokemon({
        speciesId = "TERAPAGOS",
        types = {"NORMAL"},
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {"FIRE", "WATER", "ELECTRIC"}
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(terapagos),
        MoveType = "FIRE"
    }, process.id)
    
    assertApproxEqual(1.2, tonumber(response.STABMultiplier), 0.01, "Terapagos should always get Stellar STAB")
end

function tests.testSTABCalculation_MaxCap()
    local pokemon = createTestPokemon({
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
    
    assertApproxEqual(2.0, tonumber(response.STABMultiplier), 0.01, "Natural + Tera STAB should be 2.0x (capped)")
end

-- ===============================
-- TYPE EFFECTIVENESS TESTS
-- ===============================

function tests.testTypeEffectiveness_NormalCase()
    local attacker = createTestPokemon({types = {"ELECTRIC"}})
    local defender = createTestPokemon({types = {"WATER"}})
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraEffectiveness",
        AttackerData = json.encode(attacker),
        DefenderData = json.encode(defender),
        MoveType = "ELECTRIC"
    }, process.id)
    
    assert(response.Action == "TeraEffectivenessCalculated", "Expected effectiveness calculation")
    assertApproxEqual(2.0, tonumber(response.Effectiveness), 0.01, "Electric vs Water should be 2x effective")
end

function tests.testTypeEffectiveness_TeraTypeAttacker()
    local attacker = createTestPokemon({
        types = {"ELECTRIC"},
        teraType = "FIRE",
        isTerastallized = true
    })
    local defender = createTestPokemon({types = {"GRASS"}})
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "CalculateTeraEffectiveness",
        AttackerData = json.encode(attacker),
        DefenderData = json.encode(defender),
        MoveType = "FIRE"
    }, process.id)
    
    assertApproxEqual(2.0, tonumber(response.Effectiveness), 0.01, "Tera Fire vs Grass should be 2x effective")
end

function tests.testTypeEffectiveness_TeraTypeDefender()
    local attacker = createTestPokemon({types = {"WATER"}})
    local defender = createTestPokemon({
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
    
    assertApproxEqual(2.0, tonumber(response.Effectiveness), 0.01, "Water vs Tera Fire should be 2x effective")
end

function tests.testTypeEffectiveness_StellarDefensive()
    local attacker = createTestPokemon({types = {"WATER"}})
    local defender = createTestPokemon({
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
    
    assertApproxEqual(2.0, tonumber(response.Effectiveness), 0.01, "Stellar defensive should use natural types")
end

-- ===============================
-- STELLAR USAGE TRACKING TESTS
-- ===============================

function tests.testStellarUsageTracking()
    local pokemon = createTestPokemon({
        types = {"ELECTRIC"},
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {}
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "TrackStellarUsage",
        Data = json.encode(pokemon),
        MoveType = "FIRE"
    }, process.id)
    
    assert(response.Action == "StellarUsageTracked", "Expected stellar usage tracking")
    
    local updatedPokemon = json.decode(response.Data)
    local boostedTypes = json.decode(response.StellarTypesBoosted)
    
    assertEquals(1, #boostedTypes, "Should have one boosted type")
    assertEquals("FIRE", boostedTypes[1], "Should track FIRE type")
end

function tests.testStellarUsageTracking_StatusMoves()
    local pokemon = createTestPokemon({
        types = {"ELECTRIC"},
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {}
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "TrackStellarUsage",
        Data = json.encode(pokemon),
        MoveType = "STATUS"
    }, process.id)
    
    local boostedTypes = json.decode(response.StellarTypesBoosted)
    assertEquals(0, #boostedTypes, "STATUS moves should not be tracked")
end

-- ===============================
-- TERA TYPE RETRIEVAL TESTS
-- ===============================

function tests.testGetTeraType_Normal()
    local pokemon = createTestPokemon({teraType = "FIRE"})
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "GetTeraType",
        Data = json.encode(pokemon)
    }, process.id)
    
    assert(response.Action == "TeraTypeRetrieved", "Expected TeraTypeRetrieved action")
    assertEquals("FIRE", response.TeraType, "Should return assigned Tera type")
    assertEquals("false", response.IsTerastallized, "Should return terastallization status")
end

function tests.testGetTeraType_TerapagosOverride()
    local terapagos = createTestPokemon({
        speciesId = "TERAPAGOS",
        teraType = "FIRE"
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "GetTeraType",
        Data = json.encode(terapagos)
    }, process.id)
    
    assertEquals("STELLAR", response.TeraType, "Terapagos should always return STELLAR")
end

-- ===============================
-- STATE RESET TESTS
-- ===============================

function tests.testResetTeraState()
    local pokemon = createTestPokemon({
        teraType = "FIRE",
        isTerastallized = true,
        stellarTypesBoosted = {"WATER", "GRASS"}
    })
    
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "ResetTeraState",
        Data = json.encode(pokemon),
        BattleId = "test-battle-1"
    }, process.id)
    
    assert(response.Action == "TeraStateReset", "Expected TeraStateReset action")
    assertEquals("true", response.WasTerastallized, "Should indicate Pokemon was terastallized")
    
    local resetPokemon = json.decode(response.Data)
    assert(not resetPokemon.isTerastallized, "Should reset terastallization")
    assertEquals(0, #resetPokemon.stellarTypesBoosted, "Should clear stellar types boosted")
end

-- ===============================
-- HEALTH CHECK TESTS
-- ===============================

function tests.testHealthCheck()
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "HealthCheck"
    }, process.id)
    
    assert(response.Action == "HealthCheckResponse", "Expected health check response")
    assertEquals("healthy", response.Status, "Process should report healthy status")
end

-- ===============================
-- ADP COMPLIANCE TESTS
-- ===============================

function tests.testADPCompliance_InfoHandler()
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "Info"
    }, process.id)
    
    local info = json.decode(response.Data)
    
    assert(info.Name, "Should have process name")
    assert(info.protocolVersion == "1.0", "Should be ADP v1.0 compliant")
    assert(info.handlers, "Should have handlers list")
    assert(#info.handlers >= 8, "Should have all core handlers")
    
    -- Check for required handlers
    local handlerNames = {}
    for _, handler in ipairs(info.handlers) do
        handlerNames[handler.action] = true
    end
    
    assert(handlerNames["AssignTeraType"], "Should have AssignTeraType handler")
    assert(handlerNames["ActivateTerastalization"], "Should have ActivateTerastalization handler")
    assert(handlerNames["CalculateTeraSTAB"], "Should have CalculateTeraSTAB handler")
    assert(handlerNames["Info"], "Should have Info handler")
    assert(handlerNames["Ping"], "Should have Ping handler")
end

function tests.testADPCompliance_PingHandler()
    local process = aolite.spawnProcess("tera-type-engine.lua")
    local response = aolite.send({
        Target = process.id,
        Action = "Ping"
    }, process.id)
    
    assert(response.Action == "Pong", "Should respond to ping with pong")
    assertEquals("pong", response.Data, "Should return pong data")
    assertEquals("TeraTypeEngine", response.ProcessType, "Should identify process type")
end

-- ===============================
-- RUN ALL TESTS
-- ===============================

function runAllTests()
    print("🧪 Running Tera Type Engine Unit Tests")
    print("=" .. string.rep("=", 50))
    
    for testName, testFunc in pairs(tests) do
        runTest(testName, testFunc)
    end
    
    print("=" .. string.rep("=", 50))
    print(string.format("📊 Test Results: %d passed, %d failed", testResults.passed, testResults.failed))
    
    if testResults.failed > 0 then
        print("❌ Failed Tests:")
        for _, error in ipairs(testResults.errors) do
            print("  - " .. error.test .. ": " .. error.error)
        end
    else
        print("✅ All tests passed!")
    end
    
    return testResults.failed == 0
end

-- Export test runner
return {
    runAllTests = runAllTests,
    tests = tests,
    testResults = testResults
}