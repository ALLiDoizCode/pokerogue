-- Integration Tests for Tera Type Engine Process
-- Tests Tera type engine integration with battle systems and multi-process coordination

local json = require("json")
local aosLocal = require("aos-local")

-- Test suite setup
local integrationTests = {}
local testResults = {passed = 0, failed = 0, errors = {}}

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

-- Helper function to create test Pokemon data
local function createTestPokemon(overrides)
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
        stellarTypesBoosted = {}
    }
    
    if overrides then
        for key, value in pairs(overrides) do
            defaultPokemon[key] = value
        end
    end
    
    return defaultPokemon
end

-- Helper function to create battle context
local function createBattleContext(overrides)
    local defaultContext = {
        battleId = "test-battle-" .. math.random(1000, 9999),
        turn = 1,
        phase = "COMMAND_PHASE",
        playerTerasUsed = 0,
        enemyTerasUsed = 0
    }
    
    if overrides then
        for key, value in pairs(overrides) do
            defaultContext[key] = value
        end
    end
    
    return defaultContext
end

-- ===============================
-- MULTI-PROCESS COORDINATION TESTS
-- ===============================

function integrationTests.testTeraTypeAssignmentCoordination()
    -- Spawn Tera type engine and mock Pokemon state manager
    local teraEngine = aosLocal.spawnProcess("tera-type-engine.lua")
    local pokemonManager = aosLocal.spawnProcess("mock-pokemon-manager.lua")
    
    -- Create test Pokemon
    local pokemon = createTestPokemon({types = {"ELECTRIC", "NORMAL"}})
    
    -- Pokemon manager requests Tera type assignment
    local assignResponse = aosLocal.send({
        From = pokemonManager.id,
        Target = teraEngine.id,
        Action = "AssignTeraType",
        Data = json.encode(pokemon),
        Seed = "42"
    })
    
    assert(assignResponse.Action == "TeraTypeAssigned", "Should assign Tera type")
    assert(assignResponse.Success == "true", "Assignment should succeed")
    
    local assignedPokemon = json.decode(assignResponse.Data)
    assert(assignedPokemon.teraType, "Should have assigned Tera type")
    assert(assignedPokemon.teraType == "ELECTRIC" or assignedPokemon.teraType == "NORMAL", 
           "Should be one of natural types")
    
    -- Verify state persistence
    local getResponse = aosLocal.send({
        From = pokemonManager.id,
        Target = teraEngine.id,
        Action = "GetTeraType",
        Data = json.encode(assignedPokemon)
    })
    
    assertEquals(assignedPokemon.teraType, getResponse.TeraType, "Tera type should persist")
end

function integrationTests.testBattleSystemIntegration()
    -- Spawn multiple processes
    local teraEngine = aosLocal.spawnProcess("tera-type-engine.lua")
    local battleEngine = aosLocal.spawnProcess("mock-battle-engine.lua") 
    local damageCalculator = aosLocal.spawnProcess("mock-damage-calculator.lua")
    
    -- Create battle scenario
    local attacker = createTestPokemon({
        id = "attacker-1",
        types = {"ELECTRIC"},
        teraType = "FIRE",
        isTerastallized = false
    })
    
    local defender = createTestPokemon({
        id = "defender-1", 
        types = {"GRASS"}
    })
    
    local battleContext = createBattleContext()
    
    -- Step 1: Battle engine activates terastalization
    local activationResponse = aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "ActivateTerastalization",
        Data = json.encode(attacker),
        BattleId = battleContext.battleId,
        TrainerId = "player-1",
        Turn = tostring(battleContext.turn)
    })
    
    assert(activationResponse.Action == "TerastalizationActivated", "Terastalization should activate")
    
    local terastallizedAttacker = json.decode(activationResponse.Data)
    assert(terastallizedAttacker.isTerastallized, "Attacker should be terastallized")
    
    -- Step 2: Damage calculator requests STAB calculation
    local stabResponse = aosLocal.send({
        From = damageCalculator.id,
        Target = teraEngine.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(terastallizedAttacker),
        MoveType = "FIRE"
    })
    
    assert(stabResponse.Action == "TeraSTABCalculated", "Should calculate STAB")
    assertEquals("1.5", stabResponse.STABMultiplier, "Should get Tera type STAB")
    
    -- Step 3: Damage calculator requests type effectiveness
    local effectivenessResponse = aosLocal.send({
        From = damageCalculator.id,
        Target = teraEngine.id,
        Action = "CalculateTeraEffectiveness",
        AttackerData = json.encode(terastallizedAttacker),
        DefenderData = json.encode(defender),
        MoveType = "FIRE"
    })
    
    assert(effectivenessResponse.Action == "TeraEffectivenessCalculated", "Should calculate effectiveness")
    assertEquals("2", effectivenessResponse.Effectiveness, "Fire vs Grass should be 2x effective")
end

function integrationTests.testStellarTypeWorkflow()
    local teraEngine = aosLocal.spawnProcess("tera-type-engine.lua")
    local battleEngine = aosLocal.spawnProcess("mock-battle-engine.lua")
    
    -- Create Stellar type Pokemon
    local stellarPokemon = createTestPokemon({
        types = {"ELECTRIC", "NORMAL"},
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {}
    })
    
    -- Test first STAB calculation (should get bonus)
    local stab1Response = aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(stellarPokemon),
        MoveType = "FIRE"
    })
    
    assertEquals("1.2", stab1Response.STABMultiplier, "First Stellar use should get 1.2x")
    
    -- Track the usage
    local trackResponse = aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "TrackStellarUsage",
        Data = json.encode(stellarPokemon),
        MoveType = "FIRE"
    })
    
    assert(trackResponse.Action == "StellarUsageTracked", "Should track usage")
    
    local updatedPokemon = json.decode(trackResponse.Data)
    local boostedTypes = json.decode(trackResponse.StellarTypesBoosted)
    assertEquals(1, #boostedTypes, "Should have one boosted type")
    assertEquals("FIRE", boostedTypes[1], "Should track FIRE type")
    
    -- Test second STAB calculation (should not get bonus)
    local stab2Response = aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(updatedPokemon),
        MoveType = "FIRE"
    })
    
    assertEquals("1", stab2Response.STABMultiplier, "Second Stellar use should get no bonus")
end

function integrationTests.testTerapagosSpecialHandling()
    local teraEngine = aosLocal.spawnProcess("tera-type-engine.lua")
    local battleEngine = aosLocal.spawnProcess("mock-battle-engine.lua")
    
    -- Create Terapagos with tracking
    local terapagos = createTestPokemon({
        speciesId = "TERAPAGOS",
        types = {"NORMAL"},
        teraType = "STELLAR", 
        isTerastallized = true,
        stellarTypesBoosted = {"FIRE", "WATER", "ELECTRIC"} -- Already used many types
    })
    
    -- Terapagos should still get Stellar STAB despite usage tracking
    local stabResponse = aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "CalculateTeraSTAB",
        Data = json.encode(terapagos),
        MoveType = "FIRE"
    })
    
    assertEquals("1.2", stabResponse.STABMultiplier, "Terapagos should always get Stellar STAB")
    
    -- Verify getTeraType always returns STELLAR
    local typeResponse = aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "GetTeraType",
        Data = json.encode(terapagos)
    })
    
    assertEquals("STELLAR", typeResponse.TeraType, "Terapagos should always return STELLAR")
end

function integrationTests.testConcurrentBattleSupport()
    local teraEngine = aosLocal.spawnProcess("tera-type-engine.lua")
    local battle1Engine = aosLocal.spawnProcess("mock-battle-engine-1.lua")
    local battle2Engine = aosLocal.spawnProcess("mock-battle-engine-2.lua")
    
    -- Create Pokemon for two different battles
    local pokemon1 = createTestPokemon({id = "pokemon-1", teraType = "FIRE"})
    local pokemon2 = createTestPokemon({id = "pokemon-2", teraType = "WATER"})
    
    local battle1Context = createBattleContext({battleId = "battle-1"})
    local battle2Context = createBattleContext({battleId = "battle-2"})
    
    -- Both battles activate terastalization simultaneously
    local activation1 = aosLocal.send({
        From = battle1Engine.id,
        Target = teraEngine.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon1),
        BattleId = battle1Context.battleId,
        TrainerId = "trainer-1"
    })
    
    local activation2 = aosLocal.send({
        From = battle2Engine.id,
        Target = teraEngine.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon2),
        BattleId = battle2Context.battleId,
        TrainerId = "trainer-2"
    })
    
    assert(activation1.Action == "TerastalizationActivated", "Battle 1 activation should succeed")
    assert(activation2.Action == "TerastalizationActivated", "Battle 2 activation should succeed")
    
    -- Try second terastalization in battle 1 (should fail)
    local pokemon1b = createTestPokemon({id = "pokemon-1b", teraType = "GRASS"})
    local secondActivation1 = aosLocal.send({
        From = battle1Engine.id,
        Target = teraEngine.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon1b),
        BattleId = battle1Context.battleId,
        TrainerId = "trainer-1"
    })
    
    assert(secondActivation1.Action == "TeraError", "Second activation in same battle should fail")
    assertEquals("TERA_102", secondActivation1.ErrorCode, "Should be usage limit error")
    
    -- But battle 2 can still use their second terastalization
    local pokemon2b = createTestPokemon({id = "pokemon-2b", teraType = "ELECTRIC"})
    local secondActivation2 = aosLocal.send({
        From = battle2Engine.id,
        Target = teraEngine.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon2b),
        BattleId = battle2Context.battleId,
        TrainerId = "trainer-2-second"
    })
    
    assert(secondActivation2.Action == "TerastalizationActivated", "Different trainer in battle 2 should succeed")
end

function integrationTests.testBattleEndCleanup()
    local teraEngine = aosLocal.spawnProcess("tera-type-engine.lua")
    local battleEngine = aosLocal.spawnProcess("mock-battle-engine.lua")
    
    local pokemon = createTestPokemon({
        teraType = "STELLAR",
        isTerastallized = true,
        stellarTypesBoosted = {"FIRE", "WATER"}
    })
    
    local battleContext = createBattleContext()
    
    -- Use terastalization
    aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "ActivateTerastalization",
        Data = json.encode(pokemon),
        BattleId = battleContext.battleId,
        TrainerId = "trainer-1"
    })
    
    -- Reset at battle end
    local resetResponse = aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "ResetTeraState",
        Data = json.encode(pokemon),
        BattleId = battleContext.battleId
    })
    
    assert(resetResponse.Action == "TeraStateReset", "Should reset Tera state")
    assertEquals("true", resetResponse.WasTerastallized, "Should indicate was terastallized")
    
    local resetPokemon = json.decode(resetResponse.Data)
    assert(not resetPokemon.isTerastallized, "Should clear terastallization")
    assertEquals(0, #resetPokemon.stellarTypesBoosted, "Should clear stellar tracking")
    
    -- Verify usage tracking is cleared for new battle
    local newPokemon = createTestPokemon({teraType = "FIRE"})
    local newActivation = aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "ActivateTerastalization",
        Data = json.encode(newPokemon),
        BattleId = battleContext.battleId,
        TrainerId = "trainer-1"
    })
    
    assert(newActivation.Action == "TerastalizationActivated", "Should allow new terastalization after reset")
end

function integrationTests.testErrorHandlingPropagation()
    local teraEngine = aosLocal.spawnProcess("tera-type-engine.lua")
    local battleEngine = aosLocal.spawnProcess("mock-battle-engine.lua")
    
    -- Test error propagation with invalid data
    local invalidPokemon = {invalid = "data"}
    
    local errorResponse = aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "AssignTeraType",
        Data = json.encode(invalidPokemon)
    })
    
    assert(errorResponse.Action == "TeraError", "Should return error for invalid data")
    assert(errorResponse.ErrorCode, "Should have error code")
    assert(errorResponse.ErrorMessage, "Should have error message")
    assert(errorResponse.RecoveryAction, "Should have recovery action")
    
    -- Verify battle engine can handle and recover from error
    local validPokemon = createTestPokemon()
    local validResponse = aosLocal.send({
        From = battleEngine.id,
        Target = teraEngine.id,
        Action = "AssignTeraType",
        Data = json.encode(validPokemon)
    })
    
    assert(validResponse.Action == "TeraTypeAssigned", "Should succeed with valid data")
end

function integrationTests.testPerformanceUnderLoad()
    local teraEngine = aosLocal.spawnProcess("tera-type-engine.lua")
    local numRequests = 50
    local successCount = 0
    
    -- Send multiple concurrent requests
    local responses = {}
    for i = 1, numRequests do
        local pokemon = createTestPokemon({id = "pokemon-" .. i})
        local response = aosLocal.send({
            Target = teraEngine.id,
            Action = "AssignTeraType",
            Data = json.encode(pokemon),
            Seed = tostring(i)
        })
        
        table.insert(responses, response)
        if response.Action == "TeraTypeAssigned" then
            successCount = successCount + 1
        end
    end
    
    assertEquals(numRequests, successCount, "All requests should succeed under load")
    
    -- Verify deterministic behavior
    for i = 1, math.min(5, numRequests) do
        local pokemon1 = createTestPokemon({id = "test-1"})
        local pokemon2 = createTestPokemon({id = "test-2"})
        
        local response1 = aosLocal.send({
            Target = teraEngine.id,
            Action = "AssignTeraType",
            Data = json.encode(pokemon1),
            Seed = "1000"
        })
        
        local response2 = aosLocal.send({
            Target = teraEngine.id,
            Action = "AssignTeraType",
            Data = json.encode(pokemon2),
            Seed = "1000"
        })
        
        assertEquals(response1.TeraType, response2.TeraType, "Same seed should give same result")
    end
end

function integrationTests.testADPComplianceInIntegration()
    local teraEngine = aosLocal.spawnProcess("tera-type-engine.lua")
    local clientProcess = aosLocal.spawnProcess("mock-client.lua")
    
    -- Test Info handler for process discovery
    local infoResponse = aosLocal.send({
        From = clientProcess.id,
        Target = teraEngine.id,
        Action = "Info"
    })
    
    local info = json.decode(infoResponse.Data)
    assert(info.protocolVersion == "1.0", "Should be ADP v1.0 compliant")
    assert(info.handlers, "Should provide handler registry")
    
    -- Test Ping for health checking
    local pingResponse = aosLocal.send({
        From = clientProcess.id,
        Target = teraEngine.id,
        Action = "Ping"
    })
    
    assertEquals("Pong", pingResponse.Action, "Should respond to ping")
    assertEquals("TeraTypeEngine", pingResponse.ProcessType, "Should identify process type")
    
    -- Verify client can dynamically discover and use handlers
    local handlerNames = {}
    for _, handler in ipairs(info.handlers) do
        handlerNames[handler.action] = true
    end
    
    assert(handlerNames["AssignTeraType"], "Should discover AssignTeraType handler")
    
    -- Use discovered handler
    local pokemon = createTestPokemon()
    local assignResponse = aosLocal.send({
        From = clientProcess.id,
        Target = teraEngine.id,
        Action = "AssignTeraType",
        Data = json.encode(pokemon)
    })
    
    assert(assignResponse.Action == "TeraTypeAssigned", "Should use discovered handler successfully")
end

-- ===============================
-- RUN ALL INTEGRATION TESTS
-- ===============================

function runAllIntegrationTests()
    print("🔗 Running Tera Type Engine Integration Tests")
    print("=" .. string.rep("=", 60))
    
    for testName, testFunc in pairs(integrationTests) do
        runTest(testName, testFunc)
    end
    
    print("=" .. string.rep("=", 60))
    print(string.format("📊 Integration Test Results: %d passed, %d failed", testResults.passed, testResults.failed))
    
    if testResults.failed > 0 then
        print("❌ Failed Tests:")
        for _, error in ipairs(testResults.errors) do
            print("  - " .. error.test .. ": " .. error.error)
        end
    else
        print("✅ All integration tests passed!")
    end
    
    return testResults.failed == 0
end

-- Export test runner
return {
    runAllIntegrationTests = runAllIntegrationTests,
    integrationTests = integrationTests,
    testResults = testResults
}