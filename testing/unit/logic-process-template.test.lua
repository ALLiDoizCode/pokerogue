-- Unit tests for Logic Process Template
-- Tests pure computation pattern, GameState validation, and error handling

local LogicProcessTemplate = require("processes.templates.logic-process-template")

-- Mock AO environment for testing
local mockAO = {
    send = function(msg)
        return true
    end
}

-- Test data fixtures
local mockGameState = {
    playerId = "test-player-123",
    timestamp = 1695123456,
    version = 1,
    player = {
        party = {
            {
                speciesId = 1,
                level = 50,
                hp = 150,
                maxHp = 150,
                stats = {hp = 150, attack = 100, defense = 90, spAttack = 85, spDefense = 85, speed = 95}
            }
        }
    },
    battle = {
        battleId = "battle-123",
        battleSeed = "test-battle-seed-456",
        turn = 1
    }
}

local mockMessage = {
    Action = "ProcessLogic",
    Data = {
        gameState = mockGameState,
        operation = "testOperation",
        parameters = {}
    },
    Timestamp = 1695123456,
    From = "test-sender"
}

-- Test suite
local tests = {}

-- Test 1: GameState validation
function tests.testGameStateValidation()
    print("Testing GameState validation...")
    
    -- Valid GameState
    local valid, error = LogicProcessTemplate.validateGameState(mockGameState)
    assert(valid == true, "Valid GameState should pass validation")
    assert(error == nil, "Valid GameState should not return error")
    
    -- Invalid GameState - not a table
    local invalid1, error1 = LogicProcessTemplate.validateGameState("not a table")
    assert(invalid1 == false, "String should fail GameState validation")
    assert(string.find(error1, "must be a table"), "Should return appropriate error message")
    
    -- Invalid GameState - missing required field
    local invalidState = {
        timestamp = 1695123456,
        version = 1
        -- missing playerId
    }
    local invalid2, error2 = LogicProcessTemplate.validateGameState(invalidState)
    assert(invalid2 == false, "GameState missing playerId should fail validation")
    assert(string.find(error2, "playerId"), "Should mention missing playerId field")
    
    print("✓ GameState validation tests passed")
end

-- Test 2: Input validation
function tests.testInputValidation()
    print("Testing input validation...")
    
    -- Valid input
    local valid, error = LogicProcessTemplate.validateInput(mockMessage)
    assert(valid == true, "Valid message should pass validation")
    assert(error == nil, "Valid message should not return error")
    
    -- Invalid input - missing Action
    local invalidMessage1 = {
        Data = {gameState = mockGameState, operation = "test"},
        Timestamp = 1695123456
    }
    local invalid1, error1 = LogicProcessTemplate.validateInput(invalidMessage1)
    assert(invalid1 == false, "Message missing Action should fail validation")
    assert(string.find(error1, "Action"), "Should mention missing Action field")
    
    -- Invalid input - missing gameState in Data
    local invalidMessage2 = {
        Action = "ProcessLogic",
        Data = {operation = "test"},
        Timestamp = 1695123456
    }
    local invalid2, error2 = LogicProcessTemplate.validateInput(invalidMessage2)
    assert(invalid2 == false, "Message missing gameState should fail validation")
    assert(string.find(error2, "gameState"), "Should mention missing gameState field")
    
    print("✓ Input validation tests passed")
end

-- Test 3: RNG initialization and deterministic behavior
function tests.testDeterministicRNG()
    print("Testing deterministic RNG...")
    
    -- Test RNG initialization
    local rngState1, error1 = LogicProcessTemplate.initializeRNG("test-seed-123")
    assert(rngState1 ~= nil, "RNG should initialize successfully with valid seed")
    assert(error1 == nil, "RNG initialization should not return error")
    
    -- Test deterministic behavior - same seed should produce same sequence
    local rngState2, error2 = LogicProcessTemplate.initializeRNG("test-seed-123")
    assert(rngState2 ~= nil, "Second RNG should initialize successfully")
    
    local random1a = LogicProcessTemplate.nextRandom(rngState1, 1, 100)
    local random1b = LogicProcessTemplate.nextRandom(rngState1, 1, 100)
    
    local random2a = LogicProcessTemplate.nextRandom(rngState2, 1, 100)
    local random2b = LogicProcessTemplate.nextRandom(rngState2, 1, 100)
    
    assert(random1a == random2a, "Same seed should produce same first random number")
    assert(random1b == random2b, "Same seed should produce same second random number")
    assert(random1a ~= random1b, "Sequential calls should produce different numbers")
    
    -- Test invalid seed
    local invalidRNG, invalidError = LogicProcessTemplate.initializeRNG(nil)
    assert(invalidRNG == nil, "RNG should fail with nil seed")
    assert(string.find(invalidError, "required"), "Should return appropriate error message")
    
    print("✓ Deterministic RNG tests passed")
end

-- Test 4: Performance monitoring
function tests.testPerformanceMonitoring()
    print("Testing performance monitoring...")
    
    -- Test normal operation
    LogicProcessTemplate.startPerformanceMonitoring()
    -- Simulate some work
    local sum = 0
    for i = 1, 1000 do
        sum = sum + i
    end
    local responseTime = LogicProcessTemplate.endPerformanceMonitoring()
    
    assert(responseTime ~= nil, "Performance monitoring should return response time")
    assert(responseTime >= 0, "Response time should be non-negative")
    assert(responseTime < 1000, "Simple operation should complete quickly")
    
    print("✓ Performance monitoring tests passed")
end

-- Test 5: Rate limiting
function tests.testRateLimit()
    print("Testing rate limiting...")
    
    local address = "test-address-123"
    
    -- First requests should succeed
    for i = 1, 10 do
        local allowed, error = LogicProcessTemplate.checkRateLimit(address)
        assert(allowed == true, "Early requests should be allowed")
        assert(error == nil, "Early requests should not return error")
    end
    
    -- Test rate limit enforcement by making many requests
    local hitLimit = false
    for i = 1, 60 do
        local allowed, error = LogicProcessTemplate.checkRateLimit(address)
        if not allowed then
            hitLimit = true
            assert(string.find(error, "Rate limit"), "Should return rate limit error message")
            break
        end
    end
    
    assert(hitLimit == true, "Rate limit should eventually be hit")
    
    print("✓ Rate limiting tests passed")
end

-- Test 6: GameState transformation validation
function tests.testGameStateTransformation()
    print("Testing GameState transformation validation...")
    
    local originalState = {
        playerId = "player-123",
        version = 1,
        timestamp = 1695123456
    }
    
    -- Valid transformation
    local validTransformed = {
        playerId = "player-123",
        version = 2,
        timestamp = 1695123500
    }
    
    local valid, error = LogicProcessTemplate.validateGameStateTransformation(originalState, validTransformed)
    assert(valid == true, "Valid transformation should pass validation")
    assert(error == nil, "Valid transformation should not return error")
    
    -- Invalid transformation - player ID changed
    local invalidTransformed1 = {
        playerId = "different-player",
        version = 2,
        timestamp = 1695123500
    }
    
    local invalid1, error1 = LogicProcessTemplate.validateGameStateTransformation(originalState, invalidTransformed1)
    assert(invalid1 == false, "Transformation changing player ID should fail")
    assert(string.find(error1, "Player ID"), "Should mention player ID error")
    
    -- Invalid transformation - version not incremented
    local invalidTransformed2 = {
        playerId = "player-123",
        version = 1, -- same version
        timestamp = 1695123500
    }
    
    local invalid2, error2 = LogicProcessTemplate.validateGameStateTransformation(originalState, invalidTransformed2)
    assert(invalid2 == false, "Transformation without version increment should fail")
    assert(string.find(error2, "version"), "Should mention version error")
    
    print("✓ GameState transformation validation tests passed")
end

-- Test 7: Message handling with mock logic handler
function tests.testMessageHandling()
    print("Testing message handling...")
    
    -- Mock logic handler that transforms GameState
    local function mockLogicHandler(gameState, operation, parameters, rngState)
        if operation == "testOperation" then
            local newGameState = LogicProcessTemplate.Utils.deepCopy(gameState)
            newGameState.version = (gameState.version or 0) + 1
            newGameState.testField = "added by logic handler"
            
            return {
                gameState = newGameState,
                operationResult = "success"
            }
        else
            error("Unknown operation: " .. operation)
        end
    end
    
    -- Test successful operation
    local response = LogicProcessTemplate.handleMessage(mockMessage, "test-process", mockLogicHandler)
    assert(response.Action == "SaveState", "Response should use SaveState action")
    assert(response.Data ~= nil, "Response should contain data")
    assert(response.Data.gameState ~= nil, "Response should contain transformed gameState")
    assert(response.Data.gameState.testField == "added by logic handler", "GameState should be transformed")
    assert(response.ProcessId == "test-process", "Response should include process ID")
    
    -- Test invalid input
    local invalidMessage = {
        Action = "ProcessLogic",
        -- missing Data field
        Timestamp = 1695123456
    }
    
    local errorResponse = LogicProcessTemplate.handleMessage(invalidMessage, "test-process", mockLogicHandler)
    assert(errorResponse.Action == "SaveState", "Error response should use SaveState action")
    assert(errorResponse.Error ~= nil, "Error response should contain error message")
    assert(string.find(errorResponse.Error, "required"), "Error message should mention missing field")
    
    print("✓ Message handling tests passed")
end

-- Test 8: Utility functions
function tests.testUtilityFunctions()
    print("Testing utility functions...")
    
    -- Test deep copy
    local original = {
        a = 1,
        b = {
            c = 2,
            d = {
                e = 3
            }
        }
    }
    
    local copy = LogicProcessTemplate.Utils.deepCopy(original)
    assert(copy.a == original.a, "Shallow fields should be copied")
    assert(copy.b.c == original.b.c, "Nested fields should be copied")
    assert(copy.b.d.e == original.b.d.e, "Deep nested fields should be copied")
    
    -- Modify copy and ensure original is unchanged
    copy.b.c = 999
    assert(original.b.c == 2, "Original should not be modified when copy is changed")
    
    -- Test stat calculation with nature modifier
    assert(LogicProcessTemplate.Utils.calculateStatWithNature(100, 1.1) == 110, "1.1 nature modifier should work")
    assert(LogicProcessTemplate.Utils.calculateStatWithNature(100, 0.9) == 90, "0.9 nature modifier should work")
    assert(LogicProcessTemplate.Utils.calculateStatWithNature(100, 1.0) == 100, "1.0 nature modifier should work")
    
    -- Test Pokemon validation
    local validPokemon = {
        speciesId = 1,
        level = 50,
        hp = 150,
        maxHp = 150,
        stats = {hp = 150, attack = 100}
    }
    
    local pokemonValid, pokemonError = LogicProcessTemplate.Utils.validatePokemon(validPokemon)
    assert(pokemonValid == true, "Valid Pokemon should pass validation")
    assert(pokemonError == nil, "Valid Pokemon should not return error")
    
    print("✓ Utility function tests passed")
end

-- Run all tests
function tests.runAllTests()
    print("Running Logic Process Template unit tests...")
    print("=" .. string.rep("=", 50))
    
    tests.testGameStateValidation()
    tests.testInputValidation()
    tests.testDeterministicRNG()
    tests.testPerformanceMonitoring()
    tests.testRateLimit()
    tests.testGameStateTransformation()
    tests.testMessageHandling()
    tests.testUtilityFunctions()
    
    print("=" .. string.rep("=", 50))
    print("✅ All Logic Process Template tests passed!")
    return true
end

-- Export test runner
return tests