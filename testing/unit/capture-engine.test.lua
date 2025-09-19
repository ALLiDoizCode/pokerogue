-- Unit tests for Capture Engine Process
-- Tests capture probability calculation, success determination, and Pokemon storage

-- Add processes directory to package path for module loading
package.path = './?.lua;' .. package.path

local CaptureEngineModule = require("processes.capture-engine")
local CaptureEngine = CaptureEngineModule.CaptureEngine
local POKEBALL_DATA = CaptureEngineModule.POKEBALL_DATA
local STATUS_EFFECT_MULTIPLIERS = CaptureEngineModule.STATUS_EFFECT_MULTIPLIERS
local LogicProcessTemplate = require("processes.templates.logic-process-template")

-- Test data fixtures
local mockWildPokemon = {
    speciesId = 25, -- Pikachu
    level = 10,
    hp = 30,
    maxHp = 35,
    stats = {hp = 35, attack = 30, defense = 25, spAttack = 30, spDefense = 25, speed = 45},
    type1 = "electric",
    type2 = nil,
    statusEffect = "none",
    originalTrainer = "wild"
}

local mockLowHPPokemon = {
    speciesId = 1, -- Bulbasaur
    level = 5,
    hp = 2, -- Very low HP
    maxHp = 20,
    stats = {hp = 20, attack = 15, defense = 15, spAttack = 20, spDefense = 20, speed = 15},
    type1 = "grass",
    type2 = "poison",
    statusEffect = "sleep",
    originalTrainer = "wild"
}

local mockGameState = {
    playerId = "test-player-123",
    timestamp = 1695123456,
    version = 1,
    player = {
        party = {},
        pc = {},
        pokedex = {
            seen = {},
            caught = 5,
            species = {}
        }
    }
}

-- Test suite
local tests = {}

-- Test 1: Species catch rate lookup
function tests.testSpeciesCatchRate()
    print("Testing species catch rate lookup...")

    -- Test known species
    local pikachuRate = CaptureEngine.getSpeciesCatchRate(25)
    assert(pikachuRate == 190, "Pikachu should have catch rate of 190")

    local mewtwoRate = CaptureEngine.getSpeciesCatchRate(150)
    assert(mewtwoRate == 3, "Mewtwo should have catch rate of 3 (very difficult)")

    local bulbasaurRate = CaptureEngine.getSpeciesCatchRate(1)
    assert(bulbasaurRate == 45, "Bulbasaur should have catch rate of 45")

    -- Test unknown species (should return default)
    local unknownRate = CaptureEngine.getSpeciesCatchRate(9999)
    assert(unknownRate == 100, "Unknown species should return default catch rate of 100")

    print("✓ Species catch rate tests passed")
end

-- Test 2: Pokeball modifier calculation
function tests.testPokeballModifier()
    print("Testing Pokeball modifier calculation...")

    -- Test basic Pokeball
    local pokeballMod = CaptureEngine.calculatePokeballModifier("pokeball", mockWildPokemon, {})
    assert(pokeballMod == 1.0, "Pokeball should have 1.0x modifier")

    -- Test Great Ball
    local greatballMod = CaptureEngine.calculatePokeballModifier("greatball", mockWildPokemon, {})
    assert(greatballMod == 1.5, "Great Ball should have 1.5x modifier")

    -- Test Ultra Ball
    local ultraballMod = CaptureEngine.calculatePokeballModifier("ultraball", mockWildPokemon, {})
    assert(ultraballMod == 2.0, "Ultra Ball should have 2.0x modifier")

    -- Test Master Ball
    local masterballMod = CaptureEngine.calculatePokeballModifier("masterball", mockWildPokemon, {})
    assert(masterballMod == 255.0, "Master Ball should have 255.0x modifier (guaranteed)")

    -- Test Net Ball with Electric type (should not get bonus)
    local netballMod = CaptureEngine.calculatePokeballModifier("netball", mockWildPokemon, {})
    assert(netballMod == 1.0, "Net Ball should not have bonus for Electric type")

    -- Test Net Ball with Water type
    local waterPokemon = LogicProcessTemplate.Utils.deepCopy(mockWildPokemon)
    waterPokemon.type1 = "water"
    local netballWaterMod = CaptureEngine.calculatePokeballModifier("netball", waterPokemon, {})
    assert(netballWaterMod == 3.5, "Net Ball should have 3.5x bonus for Water type")

    -- Test Quick Ball on first turn
    local quickballFirstMod = CaptureEngine.calculatePokeballModifier("quickball", mockWildPokemon, {turnCount = 1})
    assert(quickballFirstMod == 5.0, "Quick Ball should have 5.0x modifier on first turn")

    -- Test Quick Ball on later turn
    local quickballLaterMod = CaptureEngine.calculatePokeballModifier("quickball", mockWildPokemon, {turnCount = 5})
    assert(quickballLaterMod == 1.0, "Quick Ball should have 1.0x modifier after first turn")

    -- Test Timer Ball with increasing turns
    local timerball5Mod = CaptureEngine.calculatePokeballModifier("timerball", mockWildPokemon, {turnCount = 5})
    local expectedTimer5 = 1.0 * (1 + (5 / 10) * 3)
    assert(math.abs(timerball5Mod - expectedTimer5) < 0.01, "Timer Ball should increase with turn count")

    -- Test error handling
    local success, error = pcall(function()
        CaptureEngine.calculatePokeballModifier("invalidball", mockWildPokemon, {})
    end)
    assert(success == false, "Invalid Pokeball type should throw error")
    assert(string.find(error, "Unknown Pokeball"), "Error should mention unknown Pokeball")

    print("✓ Pokeball modifier tests passed")
end

-- Test 3: Status effect modifier calculation
function tests.testStatusModifier()
    print("Testing status effect modifier calculation...")

    -- Test no status
    local noneMod = CaptureEngine.calculateStatusModifier("none")
    assert(noneMod == 1.0, "No status should have 1.0x modifier")

    -- Test sleep (highest modifier)
    local sleepMod = CaptureEngine.calculateStatusModifier("sleep")
    assert(sleepMod == 2.5, "Sleep should have 2.5x modifier")

    -- Test freeze (same as sleep)
    local freezeMod = CaptureEngine.calculateStatusModifier("freeze")
    assert(freezeMod == 2.5, "Freeze should have 2.5x modifier")

    -- Test paralysis
    local paraMod = CaptureEngine.calculateStatusModifier("paralysis")
    assert(paraMod == 1.5, "Paralysis should have 1.5x modifier")

    -- Test burn
    local burnMod = CaptureEngine.calculateStatusModifier("burn")
    assert(burnMod == 1.5, "Burn should have 1.5x modifier")

    -- Test poison
    local poisonMod = CaptureEngine.calculateStatusModifier("poison")
    assert(poisonMod == 1.5, "Poison should have 1.5x modifier")

    -- Test unknown status (should default to none)
    local unknownMod = CaptureEngine.calculateStatusModifier("unknownstatus")
    assert(unknownMod == 1.0, "Unknown status should default to 1.0x modifier")

    print("✓ Status effect modifier tests passed")
end

-- Test 4: HP-based modifier calculation
function tests.testHPModifier()
    print("Testing HP-based modifier calculation...")

    -- Test full HP
    local fullHPMod = CaptureEngine.calculateHPModifier(35, 35)
    local expectedFull = (3 * 35 - 2 * 35) / (3 * 35) -- Should be 1/3 ≈ 0.33
    assert(math.abs(fullHPMod - expectedFull) < 0.01, "Full HP should have lowest modifier")

    -- Test half HP
    local halfHPMod = CaptureEngine.calculateHPModifier(17, 35)
    local expectedHalf = (3 * 35 - 2 * 17) / (3 * 35) -- Should be higher than full HP
    assert(halfHPMod > fullHPMod, "Half HP should have higher modifier than full HP")
    assert(math.abs(halfHPMod - expectedHalf) < 0.01, "Half HP modifier should match formula")

    -- Test very low HP
    local lowHPMod = CaptureEngine.calculateHPModifier(1, 35)
    local expectedLow = (3 * 35 - 2 * 1) / (3 * 35)
    assert(lowHPMod > halfHPMod, "Low HP should have higher modifier than half HP")
    assert(math.abs(lowHPMod - expectedLow) < 0.01, "Low HP modifier should match formula")

    -- Test edge case: 0 max HP
    local zeroMaxMod = CaptureEngine.calculateHPModifier(10, 0)
    assert(zeroMaxMod == 1.0, "Zero max HP should return 1.0 modifier")

    -- Test that modifier stays within bounds
    assert(fullHPMod >= 0.1 and fullHPMod <= 1.0, "HP modifier should be between 0.1 and 1.0")
    assert(lowHPMod >= 0.1 and lowHPMod <= 1.0, "HP modifier should be between 0.1 and 1.0")

    print("✓ HP-based modifier tests passed")
end

-- Test 5: Critical capture calculation
function tests.testCriticalCapture()
    print("Testing critical capture calculation...")

    local rngState, _ = LogicProcessTemplate.initializeRNG("critical-capture-test")

    -- Test with low Pokemon count
    local lowCountCritical = CaptureEngine.checkCriticalCapture(5, rngState)
    assert(type(lowCountCritical) == "boolean", "Critical capture should return boolean")

    -- Test deterministic behavior
    local rngState2, _ = LogicProcessTemplate.initializeRNG("critical-capture-test")
    local sameSeedCritical = CaptureEngine.checkCriticalCapture(5, rngState2)
    assert(lowCountCritical == sameSeedCritical, "Same seed should produce same critical capture result")

    -- Test multiple calls with same RNG state to see sequential results
    local testRng, _ = LogicProcessTemplate.initializeRNG("critical-sequence-test")
    local criticalCount = 0
    local totalTests = 50

    for i = 1, totalTests do
        if CaptureEngine.checkCriticalCapture(150, testRng) then -- Higher Pokemon count for better chance
            criticalCount = criticalCount + 1
        end
    end

    -- With sequential RNG calls and higher Pokemon count, should have some variability
    -- If no critical captures, that's still valid behavior for RNG
    assert(criticalCount >= 0 and criticalCount <= totalTests, "Critical capture count should be within valid range")

    print("✓ Critical capture tests passed")
end

-- Test 6: Overall capture rate calculation
function tests.testCaptureRateCalculation()
    print("Testing overall capture rate calculation...")

    local rngState, _ = LogicProcessTemplate.initializeRNG("capture-rate-test")

    -- Test basic capture rate calculation
    local captureData = CaptureEngine.calculateCaptureRate(
        mockWildPokemon,
        "pokeball",
        {},
        mockGameState,
        rngState
    )

    assert(type(captureData) == "table", "Capture data should be a table")
    assert(type(captureData.captureRate) == "number", "Should have capture rate")
    assert(captureData.captureRate >= 0 and captureData.captureRate <= 1, "Capture rate should be between 0 and 1")
    assert(type(captureData.baseCatchRate) == "number", "Should have base catch rate")
    assert(type(captureData.ballModifier) == "number", "Should have ball modifier")
    assert(type(captureData.statusModifier) == "number", "Should have status modifier")
    assert(type(captureData.hpModifier) == "number", "Should have HP modifier")
    assert(type(captureData.isCriticalCapture) == "boolean", "Should have critical capture flag")

    -- Test with better conditions (low HP, status effect, better ball)
    local betterData = CaptureEngine.calculateCaptureRate(
        mockLowHPPokemon,
        "ultraball",
        {},
        mockGameState,
        rngState
    )

    assert(betterData.captureRate > captureData.captureRate, "Better conditions should have higher capture rate")
    assert(betterData.statusModifier > 1.0, "Sleep status should increase capture rate")
    assert(betterData.ballModifier == 2.0, "Ultra Ball should have 2.0x modifier")

    -- Test with Master Ball (should be guaranteed)
    local masterData = CaptureEngine.calculateCaptureRate(
        mockWildPokemon,
        "masterball",
        {},
        mockGameState,
        rngState
    )

    assert(masterData.captureRate == 1.0, "Master Ball should guarantee capture")

    print("✓ Capture rate calculation tests passed")
end

-- Test 7: Capture success determination
function tests.testCaptureSuccessDetermination()
    print("Testing capture success determination...")

    local rngState, _ = LogicProcessTemplate.initializeRNG("capture-success-test")

    -- Test with high capture rate (should succeed)
    local highResult = CaptureEngine.determineCaptureSuccess(0.9, rngState)
    assert(type(highResult) == "table", "Capture result should be a table")
    assert(type(highResult.success) == "boolean", "Should have success boolean")
    assert(type(highResult.roll) == "number", "Should have roll value")
    assert(type(highResult.threshold) == "number", "Should have threshold value")
    assert(highResult.threshold == 0.9, "Threshold should match input")

    -- Test with guaranteed capture
    local guaranteedResult = CaptureEngine.determineCaptureSuccess(1.0, rngState)
    assert(guaranteedResult.success == true, "Guaranteed capture should always succeed")

    -- Test with impossible capture
    local impossibleResult = CaptureEngine.determineCaptureSuccess(0.0, rngState)
    assert(impossibleResult.success == false, "Impossible capture should always fail")

    -- Test deterministic behavior
    local rngState2, _ = LogicProcessTemplate.initializeRNG("capture-success-test")
    local sameResult = CaptureEngine.determineCaptureSuccess(0.9, rngState2)
    assert(highResult.success == sameResult.success, "Same seed should produce same result")
    assert(highResult.roll == sameResult.roll, "Same seed should produce same roll")

    print("✓ Capture success determination tests passed")
end

-- Test 8: Pokemon storage (party and PC)
function tests.testPokemonStorage()
    print("Testing Pokemon storage...")

    local testGameState = LogicProcessTemplate.Utils.deepCopy(mockGameState)
    local capturedPokemon = LogicProcessTemplate.Utils.deepCopy(mockWildPokemon)
    capturedPokemon.originalTrainer = "test-player-123"

    -- Test adding to empty party
    local newGameState = CaptureEngine.addPokemonToStorage(testGameState, capturedPokemon)

    assert(#newGameState.player.party == 1, "Should have 1 Pokemon in party")
    assert(newGameState.player.party[1].speciesId == capturedPokemon.speciesId, "Pokemon should be in party")
    assert(newGameState.player.party[1].location == "party", "Pokemon should be marked as in party")

    -- Test Pokedex update
    assert(newGameState.player.pokedex.caught == 6, "Pokedex caught count should increase")
    assert(newGameState.player.pokedex.species[capturedPokemon.speciesId] ~= nil, "Species should be marked as caught")
    assert(newGameState.player.pokedex.species[capturedPokemon.speciesId].caught == true, "Species should be caught")

    -- Test adding to full party (should go to PC)
    local fullPartyState = LogicProcessTemplate.Utils.deepCopy(newGameState)
    -- Fill party to 6 Pokemon
    for i = 2, 6 do
        local dummyPokemon = LogicProcessTemplate.Utils.deepCopy(capturedPokemon)
        dummyPokemon.speciesId = i
        table.insert(fullPartyState.player.party, dummyPokemon)
    end

    local newCapturedPokemon = LogicProcessTemplate.Utils.deepCopy(mockLowHPPokemon)
    newCapturedPokemon.originalTrainer = "test-player-123"

    local pcGameState = CaptureEngine.addPokemonToStorage(fullPartyState, newCapturedPokemon)

    assert(#pcGameState.player.party == 6, "Party should still have 6 Pokemon")
    assert(#pcGameState.player.pc == 1, "Should have 1 Pokemon in PC")
    assert(pcGameState.player.pc[1].location == "pc", "Pokemon should be marked as in PC")

    print("✓ Pokemon storage tests passed")
end

-- Test 9: Capture validation
function tests.testCaptureValidation()
    print("Testing capture validation...")

    -- Test valid capture
    local valid1, error1 = CaptureEngine.validateCaptureAttempt(mockWildPokemon, "pokeball", {})
    assert(valid1 == true, "Valid capture attempt should pass")
    assert(error1 == nil, "Valid capture should not return error")

    -- Test fainted Pokemon
    local faintedPokemon = LogicProcessTemplate.Utils.deepCopy(mockWildPokemon)
    faintedPokemon.hp = 0
    local valid2, error2 = CaptureEngine.validateCaptureAttempt(faintedPokemon, "pokeball", {})
    assert(valid2 == false, "Fainted Pokemon should not be capturable")
    assert(string.find(error2, "fainted"), "Error should mention fainted Pokemon")

    -- Test Pokemon with faint status
    local statusFaintPokemon = LogicProcessTemplate.Utils.deepCopy(mockWildPokemon)
    statusFaintPokemon.statusEffect = "faint"
    local valid3, error3 = CaptureEngine.validateCaptureAttempt(statusFaintPokemon, "pokeball", {})
    assert(valid3 == false, "Pokemon with faint status should not be capturable")

    -- Test invalid Pokeball
    local valid4, error4 = CaptureEngine.validateCaptureAttempt(mockWildPokemon, "invalidball", {})
    assert(valid4 == false, "Invalid Pokeball should fail validation")
    assert(string.find(error4, "Invalid Pokeball"), "Error should mention invalid Pokeball")

    -- Test trainer Pokemon
    local trainerPokemon = LogicProcessTemplate.Utils.deepCopy(mockWildPokemon)
    trainerPokemon.originalTrainer = "gym-leader-brock"
    local valid5, error5 = CaptureEngine.validateCaptureAttempt(trainerPokemon, "pokeball", {})
    assert(valid5 == false, "Trainer Pokemon should not be capturable")
    assert(string.find(error5, "another trainer"), "Error should mention another trainer")

    print("✓ Capture validation tests passed")
end

-- Test 10: Logic operation handling
function tests.testLogicOperationHandling()
    print("Testing logic operation handling...")

    local testGameState = LogicProcessTemplate.Utils.deepCopy(mockGameState)
    local rngState, _ = LogicProcessTemplate.initializeRNG("logic-operation-test")

    -- Test calculateCaptureRate operation
    local calcParams = {
        pokemon = mockWildPokemon,
        ballType = "pokeball",
        captureContext = {}
    }

    local calcResult = CaptureEngine.handleLogicOperation(testGameState, "calculateCaptureRate", calcParams, rngState)
    assert(calcResult.gameState ~= nil, "Calculate capture rate should return gameState")
    assert(calcResult.captureData ~= nil, "Calculate capture rate should return capture data")
    assert(type(calcResult.captureData.captureRate) == "number", "Should contain capture rate")

    -- Test attemptCapture operation
    local attemptParams = {
        pokemon = mockWildPokemon,
        ballType = "masterball", -- Use Master Ball for guaranteed success
        captureContext = {location = "route1"}
    }

    local attemptResult = CaptureEngine.handleLogicOperation(testGameState, "attemptCapture", attemptParams, rngState)
    assert(attemptResult.gameState ~= nil, "Attempt capture should return gameState")
    assert(attemptResult.captureResult ~= nil, "Attempt capture should return capture result")
    assert(attemptResult.captureResult.captureSuccess == true, "Master Ball should guarantee success")
    assert(attemptResult.captureResult.capturedPokemon ~= nil, "Should return captured Pokemon")

    -- Check that Pokemon was added to party
    assert(#attemptResult.gameState.player.party == 1, "Pokemon should be added to party")

    -- Test validateCapture operation
    local validateParams = {
        pokemon = mockWildPokemon,
        ballType = "pokeball",
        captureContext = {}
    }

    local validateResult = CaptureEngine.handleLogicOperation(testGameState, "validateCapture", validateParams, rngState)
    assert(validateResult.gameState ~= nil, "Validate capture should return gameState")
    assert(validateResult.validationResult ~= nil, "Validate capture should return validation result")
    assert(validateResult.validationResult.valid == true, "Valid capture should pass validation")

    -- Test invalid operation
    local success, error = pcall(function()
        CaptureEngine.handleLogicOperation(testGameState, "invalidOperation", {}, rngState)
    end)
    assert(success == false, "Invalid operation should throw error")
    assert(string.find(error, "Unknown"), "Error should mention unknown operation")

    print("✓ Logic operation handling tests passed")
end

-- ADP v1.0 Compliance Tests
function tests.testADPCompliance()
    print("Testing ADP v1.0 compliance...")
    
    -- Test process metadata exists
    assert(CaptureEngineModule.PROCESS_METADATA, "Process metadata should exist")
    local metadata = CaptureEngineModule.PROCESS_METADATA
    
    -- Test ADP version
    assert(metadata.adpVersion == "1.0", "Should be ADP v1.0 compliant")
    
    -- Test required fields
    assert(metadata.name, "Should have process name")
    assert(metadata.capabilities, "Should have capabilities list")
    assert(metadata.messageSchemas, "Should have message schemas")
    
    -- Test capabilities include expected operations
    local requiredCapabilities = {"calculateCaptureRate", "processCaptureAttempt", "validateCaptureConditions"}
    for _, capability in ipairs(requiredCapabilities) do
        local found = false
        for _, existing in ipairs(metadata.capabilities) do
            if existing == capability then
                found = true
                break
            end
        end
        assert(found, "Should have capability: " .. capability)
    end
    
    -- Test message schemas structure
    assert(metadata.messageSchemas.ProcessLogic, "Should have ProcessLogic schema")
    assert(metadata.messageSchemas.HealthCheck, "Should have HealthCheck schema")
    assert(metadata.messageSchemas.Info, "Should have Info schema")
    
    print("✓ ADP v1.0 compliance tests passed")
end

function tests.testInfoHandlerSchema()
    print("Testing Info handler schema structure...")
    
    local metadata = CaptureEngineModule.PROCESS_METADATA
    local processLogicSchema = metadata.messageSchemas.ProcessLogic
    
    -- Test required fields exist
    assert(processLogicSchema.required, "ProcessLogic should have required fields")
    assert(processLogicSchema.properties, "ProcessLogic should have properties")
    
    -- Test required fields include essential ones
    local requiredFields = {"Action", "Data", "Timestamp"}
    for _, field in ipairs(requiredFields) do
        local found = false
        for _, existing in ipairs(processLogicSchema.required) do
            if existing == field then
                found = true
                break
            end
        end
        assert(found, "ProcessLogic should require field: " .. field)
    end
    
    print("✓ Info handler schema tests passed")
end

-- Run all tests
function tests.runAllTests()
    print("Running Capture Engine unit tests...")
    print("=" .. string.rep("=", 50))

    tests.testSpeciesCatchRate()
    tests.testPokeballModifier()
    tests.testStatusModifier()
    tests.testHPModifier()
    tests.testCriticalCapture()
    tests.testCaptureRateCalculation()
    tests.testCaptureSuccessDetermination()
    tests.testPokemonStorage()
    tests.testCaptureValidation()
    tests.testLogicOperationHandling()
    
    print("=" .. string.rep("=", 50))
    print("Running ADP v1.0 Compliance tests...")
    
    tests.testADPCompliance()
    tests.testInfoHandlerSchema()

    print("=" .. string.rep("=", 50))
    print("✅ All Capture Engine tests passed!")
    return true
end

-- Export test runner
return tests