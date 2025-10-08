-- Unit tests for Game Mode Engine - Creation Tests
-- Tests game mode factory functions and configuration properties

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local mockAO = {
    id = "test-game-mode-process",
    send = function(msg)
        table.insert(testMessages, msg)
        return true
    end
}

-- Mock Handlers
local mockHandlers = {
    add = function(name, matcher, handler)
        testHandlers[name] = {
            matcher = matcher,
            handler = handler
        }
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value
            end
        end
    }
}

-- Mock JSON
local mockJSON = {
    encode = function(t)
        if type(t) == "table" then
            -- Simple JSON encoding for testing
            local result = "{"
            local first = true
            for k, v in pairs(t) do
                if not first then result = result .. "," end
                first = false
                result = result .. '"' .. tostring(k) .. '":' .. (type(v) == "table" and "{}" or tostring(v))
            end
            return result .. "}"
        end
        return tostring(t)
    end,
    decode = function(s)
        -- Mock decode returns table for testing
        return {success = true}
    end
}

-- Setup test environment
local function setupTestEnvironment()
    testMessages = {}
    testHandlers = {}
    _G.ao = mockAO
    _G.Handlers = mockHandlers
    _G.json = mockJSON
end

-- Helper to invoke handler
local function invokeHandler(handlerName, msg)
    testMessages = {}
    local handler = testHandlers[handlerName]
    if handler and handler.handler then
        handler.handler(msg)
        return testMessages[1]
    end
    return nil
end

-- Load the process
local function loadProcess()
    setupTestEnvironment()
    dofile("processes/game-mode-engine.lua")
end

-- Test runner
local function runTests()
    print("Running ADP v1.0 Game Mode Engine Unit Tests - Creation")
    print("=" .. string.rep("=", 50))

    loadProcess()

    local testsRun = 0
    local testsPassed = 0

    -- Test 1: Create CLASSIC mode
    testsRun = testsRun + 1
    print("\nRunning: test_create_classic_mode")
    local response = invokeHandler("create-game-mode", {
        From = "test-sender",
        Action = "CreateGameMode",
        ModeId = "0"
    })
    if response and response.Action == "SaveState" and response.Data then
        print("✓ CreateGameMode handler returned SaveState")
        testsPassed = testsPassed + 1
    else
        print("✗ CreateGameMode handler failed")
    end

    -- Test 2: Create ENDLESS mode
    testsRun = testsRun + 1
    print("\nRunning: test_create_endless_mode")
    response = invokeHandler("create-game-mode", {
        From = "test-sender",
        Action = "CreateGameMode",
        ModeId = "1"
    })
    if response and response.Action == "SaveState" and response.Data then
        print("✓ CreateGameMode handler returned SaveState for ENDLESS")
        testsPassed = testsPassed + 1
    else
        print("✗ CreateGameMode handler failed for ENDLESS")
    end

    -- Test 3: Create SPLICED_ENDLESS mode
    testsRun = testsRun + 1
    print("\nRunning: test_create_spliced_endless_mode")
    response = invokeHandler("create-game-mode", {
        From = "test-sender",
        Action = "CreateGameMode",
        ModeId = "2"
    })
    if response and response.Action == "SaveState" and response.Data then
        print("✓ CreateGameMode handler returned SaveState for SPLICED_ENDLESS")
        testsPassed = testsPassed + 1
    else
        print("✗ CreateGameMode handler failed for SPLICED_ENDLESS")
    end

    -- Test 4: Create DAILY mode
    testsRun = testsRun + 1
    print("\nRunning: test_create_daily_mode")
    response = invokeHandler("create-game-mode", {
        From = "test-sender",
        Action = "CreateGameMode",
        ModeId = "3"
    })
    if response and response.Action == "SaveState" and response.Data then
        print("✓ CreateGameMode handler returned SaveState for DAILY")
        testsPassed = testsPassed + 1
    else
        print("✗ CreateGameMode handler failed for DAILY")
    end

    -- Test 5: Create CHALLENGE mode
    testsRun = testsRun + 1
    print("\nRunning: test_create_challenge_mode")
    response = invokeHandler("create-game-mode", {
        From = "test-sender",
        Action = "CreateGameMode",
        ModeId = "4"
    })
    if response and response.Action == "SaveState" and response.Data then
        print("✓ CreateGameMode handler returned SaveState for CHALLENGE")
        testsPassed = testsPassed + 1
    else
        print("✗ CreateGameMode handler failed for CHALLENGE")
    end

    -- Test 6: Invalid ModeId (out of range)
    testsRun = testsRun + 1
    print("\nRunning: test_invalid_mode_id")
    response = invokeHandler("create-game-mode", {
        From = "test-sender",
        Action = "CreateGameMode",
        ModeId = "5"
    })
    if response and response.Action == "Error" and response.Error then
        print("✓ CreateGameMode handler correctly rejected invalid ModeId")
        testsPassed = testsPassed + 1
    else
        print("✗ CreateGameMode handler should have rejected invalid ModeId")
    end

    -- Test 7: Missing ModeId
    testsRun = testsRun + 1
    print("\nRunning: test_missing_mode_id")
    response = invokeHandler("create-game-mode", {
        From = "test-sender",
        Action = "CreateGameMode"
    })
    if response and response.Action == "Error" and response.Error then
        print("✓ CreateGameMode handler correctly rejected missing ModeId")
        testsPassed = testsPassed + 1
    else
        print("✗ CreateGameMode handler should have rejected missing ModeId")
    end

    -- Test 8: SetChallengeValue
    testsRun = testsRun + 1
    print("\nRunning: test_set_challenge_value")
    response = invokeHandler("set-challenge-value", {
        From = "test-sender",
        Action = "SetChallengeValue",
        ModeId = "0",
        ChallengeId = "0",
        Value = "5"
    })
    if response and response.Action == "SaveState" and response.Data then
        print("✓ SetChallengeValue handler returned SaveState")
        testsPassed = testsPassed + 1
    else
        print("✗ SetChallengeValue handler failed")
    end

    -- Test 9: GetGameModeInfo (all modes)
    testsRun = testsRun + 1
    print("\nRunning: test_get_all_modes")
    response = invokeHandler("get-game-mode-info", {
        From = "test-sender",
        Action = "GetGameModeInfo"
    })
    if response and response.Action == "SaveState" and response.Data then
        print("✓ GetGameModeInfo handler returned all modes")
        testsPassed = testsPassed + 1
    else
        print("✗ GetGameModeInfo handler failed to return all modes")
    end

    -- Test 10: GetGameModeInfo (single mode)
    testsRun = testsRun + 1
    print("\nRunning: test_get_single_mode")
    response = invokeHandler("get-game-mode-info", {
        From = "test-sender",
        Action = "GetGameModeInfo",
        ModeId = "3"
    })
    if response and response.Action == "SaveState" and response.Data then
        print("✓ GetGameModeInfo handler returned single mode")
        testsPassed = testsPassed + 1
    else
        print("✗ GetGameModeInfo handler failed to return single mode")
    end

    -- Test 11: Info handler (ADP v1.0)
    testsRun = testsRun + 1
    print("\nRunning: test_info_handler")
    response = invokeHandler("info", {
        From = "test-sender",
        Action = "Info"
    })
    if response and response.Action == "SaveState" and response.Data then
        print("✓ Info handler returned process metadata (ADP v1.0)")
        testsPassed = testsPassed + 1
    else
        print("✗ Info handler failed")
    end

    -- Results summary
    print("\n" .. string.rep("=", 50))
    print("Tests run: " .. testsRun)
    print("Tests passed: " .. testsPassed)
    print("Tests failed: " .. (testsRun - testsPassed))

    if testsPassed == testsRun then
        print("✅ All game mode creation tests passed!")
        return true
    else
        print("❌ Some game mode creation tests failed!")
        return false
    end
end

-- Return module for test runner
return {
    runTests = runTests
}
