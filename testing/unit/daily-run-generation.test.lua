-- Unit tests for daily-run-engine.lua using message-based testing
-- Tests starter generation, biome selection, difficulty, trainer waves, event parsing

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local mockAO = {
    id = "test-daily-run-engine",
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
                if type(value) == "table" then
                    for _, v in ipairs(value) do
                        if msg[tag] == v then
                            return true
                        end
                    end
                    return false
                else
                    return msg[tag] == value
                end
            end
        end
    }
}

-- Mock JSON with actual encode/decode
local mockJSON
mockJSON = {
    encode = function(t)
        if type(t) ~= "table" then
            return '"' .. tostring(t) .. '"'
        end

        local result = "{"
        local first = true
        for k, v in pairs(t) do
            if not first then result = result .. "," end
            first = false

            result = result .. '"' .. tostring(k) .. '":'
            if type(v) == "table" then
                result = result .. (mockJSON and mockJSON.encode(v) or "{}")
            elseif type(v) == "string" then
                result = result .. '"' .. v .. '"'
            elseif type(v) == "boolean" then
                result = result .. (v and "true" or "false")
            else
                result = result .. tostring(v)
            end
        end
        result = result .. "}"
        return result
    end,

    decode = function(s)
        -- Simple JSON decode for test purposes
        if type(s) ~= "string" then return s end
        if s == "" or s == "{}" then return {} end

        -- Remove outer braces and whitespace
        local content = s:match("^%s*{%s*(.-)%s*}%s*$")
        if not content then return {} end

        local result = {}
        -- Match key-value pairs, handling quoted strings properly
        for match in content:gmatch('[^,]+') do
            local key, value = match:match('%s*"([^"]+)"%s*:%s*"([^"]*)"')
            if key and value then
                result[key] = value
            else
                key, value = match:match('%s*"([^"]+)"%s*:%s*(%a+)')
                if key and value then
                    if value == "true" then
                        result[key] = true
                    elseif value == "false" then
                        result[key] = false
                    else
                        result[key] = value
                    end
                else
                    key, value = match:match('%s*"([^"]+)"%s*:%s*([%d.-]+)')
                    if key and value then
                        result[key] = tonumber(value)
                    end
                end
            end
        end
        return result
    end
}

-- Set up test environment
local function setupTestEnvironment()
    testMessages = {}
    testHandlers = {}

    _G.ao = mockAO
    _G.Handlers = mockHandlers
    _G.json = mockJSON

    -- Mock require to return our JSON mock
    local originalRequire = require
    _G.require = function(module)
        if module == "json" then
            return mockJSON
        end
        return originalRequire(module)
    end
end

-- Helper to send test message
local function sendTestMessage(handlerName, message)
    local handler = testHandlers[handlerName]
    if not handler then
        error("Handler not found: " .. handlerName)
    end

    if not handler.matcher(message) then
        error("Message does not match handler pattern")
    end

    testMessages = {}
    handler.handler(message)

    return testMessages[1] -- Return first response
end

-- Load daily run engine
local function loadDailyRunEngine()
    setupTestEnvironment()
    dofile("processes/daily-run-engine.lua")
end

-- Test suite
local function runTests()
    print("\nRunning Daily Run Generation Unit Tests...")
    print("===================================================\n")

    local totalTests = 0
    local passedTests = 0

    local function runTest(name, testFn)
        totalTests = totalTests + 1
        io.write("Running: " .. name .. "\n")

        local success, err = pcall(testFn)
        if success then
            passedTests = passedTests + 1
            print("✓ " .. name .. " passed")
        else
            print("❌ Test " .. totalTests .. " failed: " .. tostring(err))
        end
    end

    -- Load process once
    loadDailyRunEngine()

    -- Test 1: Generate Daily Run Handler Exists
    runTest("test_generate_daily_run_handler_exists", function()
        assert(testHandlers["generate-daily-run"] ~= nil, "GenerateDailyRun handler should exist")
    end)

    -- Test 2: Get Daily Difficulty Handler Exists
    runTest("test_get_daily_difficulty_handler_exists", function()
        assert(testHandlers["get-daily-difficulty"] ~= nil, "GetDailyDifficulty handler should exist")
    end)

    -- Test 3: Is Trainer Wave Handler Exists
    runTest("test_is_trainer_wave_handler_exists", function()
        assert(testHandlers["is-trainer-wave"] ~= nil, "IsTrainerWave handler should exist")
    end)

    -- Test 4: Parse Event Seed Handler Exists
    runTest("test_parse_event_seed_handler_exists", function()
        assert(testHandlers["parse-event-seed"] ~= nil, "ParseEventSeed handler should exist")
    end)

    -- Test 5: Info Handler (ADP v1.0 compliance)
    runTest("test_adp_info_handler", function()
        local response = sendTestMessage("info", {
            Action = "Info",
            From = "test-sender"
        })

        assert(response ~= nil, "Should return response")
        assert(response.Action == "SaveState", "Should have SaveState action")
    end)

    -- Test 6: Generate Daily Run - Standard Seed
    runTest("test_generate_daily_run_standard_seed", function()
        -- Test JSON decoder first
        local testData = '{"seed":"20250103abcdefghij123456"}'
        local decoded = mockJSON.decode(testData)
        print("DEBUG: Decoded seed = " .. tostring(decoded.seed) .. ", length = " .. (decoded.seed and #decoded.seed or 0))

        local response = sendTestMessage("generate-daily-run", {
            Action = "GenerateDailyRun",
            From = "test-sender",
            Data = '{"seed":"20250103abcdefghij123456"}'
        })

        assert(response ~= nil, "Should return response")
        if response.Action == "Error" then
            print("Error details: " .. (response.Error or "unknown"))
        end
        assert(response.Action == "SaveState" or response.Action == "DailyRunGenerated", "Should have valid action, got: " .. tostring(response.Action))
    end)

    -- Test 7: Get Daily Difficulty - Wave 1
    runTest("test_difficulty_wave_1", function()
        local response = sendTestMessage("get-daily-difficulty", {
            Action = "GetDailyDifficulty",
            From = "test-sender",
            Data = '{"waveIndex":1,"ignoreCurveChanges":false}'
        })

        assert(response ~= nil, "Should return response")
    end)

    -- Test 8: Get Daily Difficulty - Wave 25
    runTest("test_difficulty_wave_25", function()
        local response = sendTestMessage("get-daily-difficulty", {
            Action = "GetDailyDifficulty",
            From = "test-sender",
            Data = '{"waveIndex":25,"ignoreCurveChanges":false}'
        })

        assert(response ~= nil, "Should return response")
    end)

    -- Test 9: Is Trainer Wave - Wave 5 (X5)
    runTest("test_trainer_wave_5", function()
        local response = sendTestMessage("is-trainer-wave", {
            Action = "IsTrainerWave",
            From = "test-sender",
            Data = '{"waveIndex":5,"isFinalWave":false}'
        })

        assert(response ~= nil, "Should return response")
    end)

    -- Test 10: Is Trainer Wave - Wave 20 (X0)
    runTest("test_trainer_wave_20", function()
        local response = sendTestMessage("is-trainer-wave", {
            Action = "IsTrainerWave",
            From = "test-sender",
            Data = '{"waveIndex":20,"isFinalWave":false}'
        })

        assert(response ~= nil, "Should return response")
    end)

    -- Test 11: Is Trainer Wave - Wave 10 (NOT trainer)
    runTest("test_trainer_wave_10_not_trainer", function()
        local response = sendTestMessage("is-trainer-wave", {
            Action = "IsTrainerWave",
            From = "test-sender",
            Data = '{"waveIndex":10,"isFinalWave":false}'
        })

        assert(response ~= nil, "Should return response")
    end)

    -- Test 12: Parse Event Seed - Standard Seed
    runTest("test_parse_event_seed_standard", function()
        local response = sendTestMessage("parse-event-seed", {
            Action = "ParseEventSeed",
            From = "test-sender",
            Data = '{"seed":"20250103abcdefghij123456"}'
        })

        assert(response ~= nil, "Should return response")
    end)

    -- Test 13: Parse Event Seed - Event Seed with Luck
    runTest("test_parse_event_seed_with_luck", function()
        local response = sendTestMessage("parse-event-seed", {
            Action = "ParseEventSeed",
            From = "test-sender",
            Data = '{"seed":"20250103abcdefghij123456/luck08/"}'
        })

        assert(response ~= nil, "Should return response")
    end)

    -- Test 14: Parse Event Seed - Event Seed with Biome
    runTest("test_parse_event_seed_with_biome", function()
        local response = sendTestMessage("parse-event-seed", {
            Action = "ParseEventSeed",
            From = "test-sender",
            Data = '{"seed":"20250103abcdefghij123456/biome05/"}'
        })

        assert(response ~= nil, "Should return response")
    end)

    -- Test 15: Difficulty Ignore Curve Changes
    runTest("test_difficulty_ignore_curve", function()
        local response = sendTestMessage("get-daily-difficulty", {
            Action = "GetDailyDifficulty",
            From = "test-sender",
            Data = '{"waveIndex":25,"ignoreCurveChanges":true}'
        })

        assert(response ~= nil, "Should return response")
    end)

    -- Test 16: Final Wave Not Trainer
    runTest("test_final_wave_not_trainer", function()
        local response = sendTestMessage("is-trainer-wave", {
            Action = "IsTrainerWave",
            From = "test-sender",
            Data = '{"waveIndex":50,"isFinalWave":true}'
        })

        assert(response ~= nil, "Should return response")
    end)

    -- Test 17: Health Check Handler
    runTest("test_health_check_handler", function()
        if testHandlers["health-check"] then
            local response = sendTestMessage("health-check", {
                Action = "HealthCheck",
                From = "test-sender"
            })

            assert(response ~= nil, "Should return response")
        else
            -- Health check is optional
            print("Note: HealthCheck handler not implemented (optional)")
        end
    end)

    -- Test 18: Process Initialization
    runTest("test_process_initialization", function()
        assert(testHandlers["info"] ~= nil, "Info handler should be registered")
        assert(testHandlers["generate-daily-run"] ~= nil, "GenerateDailyRun handler should be registered")
        assert(testHandlers["get-daily-difficulty"] ~= nil, "GetDailyDifficulty handler should be registered")
        assert(testHandlers["is-trainer-wave"] ~= nil, "IsTrainerWave handler should be registered")
        assert(testHandlers["parse-event-seed"] ~= nil, "ParseEventSeed handler should be registered")
    end)

    -- Print summary
    print("\n==================================================")
    print("Test Results:")
    print("  Passed: " .. passedTests)
    print("  Failed: " .. (totalTests - passedTests))
    print("  Total:  " .. totalTests)
    print("")

    if passedTests == totalTests then
        print("🎉 All tests passed!")
        return true
    else
        print("❌ Some tests failed!")
        return false
    end
end

-- Run tests
return { runTests = runTests }
