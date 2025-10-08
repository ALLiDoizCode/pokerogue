-- Unit tests for daily run difficulty scaling edge cases
-- Tests wave progression, classic comparison, monotonic progression

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
                return msg[tag] == value
            end
        end
    }
}

-- Mock JSON (defined early for use in test cases)
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
                result = result .. mockJSON.encode(v)
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
        if type(s) ~= "string" or s == "" or s == "{}" then return {} end
        local content = s:match("^%s*{%s*(.-)%s*}%s*$")
        if not content then return {} end
        local result = {}
        for match in content:gmatch('[^,]+') do
            local key, value = match:match('%s*"([^"]+)"%s*:%s*"([^"]*)"')
            if key and value then
                result[key] = value
            else
                key, value = match:match('%s*"([^"]+)"%s*:%s*([%d.-]+)')
                if key and value then
                    result[key] = tonumber(value)
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
    local originalRequire = require
    _G.require = function(module)
        if module == "json" then return mockJSON end
        return originalRequire(module)
    end
end

-- Helper to send test message
local function sendTestMessage(handlerName, message)
    local handler = testHandlers[handlerName]
    if not handler then error("Handler not found: " .. handlerName) end
    if not handler.matcher(message) then error("Message does not match handler pattern") end
    testMessages = {}
    handler.handler(message)
    return testMessages[1]
end

-- Load daily run engine
local function loadDailyRunEngine()
    setupTestEnvironment()
    dofile("processes/daily-run-engine.lua")
end

-- Test suite
local function runTests()
    print("\nRunning Daily Run Difficulty Scaling Unit Tests...")
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

    -- Test 1: Wave 10 Difficulty = 42 (10 + 30 + 2)
    runTest("test_wave_10_difficulty", function()
        local response = sendTestMessage("get-daily-difficulty", {
            Action = "GetDailyDifficulty",
            From = "test-sender",
            Data = '{"waveIndex":10,"ignoreCurveChanges":false}'
        })
        local data = mockJSON.decode(response.Data)
        assert(data.effectiveWave == 42,
            "Wave 10 should be difficulty 42, got " .. tostring(data.effectiveWave))
    end)

    -- Test 2: Wave 50 Difficulty = 90 (50 + 30 + 10)
    runTest("test_wave_50_difficulty", function()
        local response = sendTestMessage("get-daily-difficulty", {
            Action = "GetDailyDifficulty",
            From = "test-sender",
            Data = '{"waveIndex":50,"ignoreCurveChanges":false}'
        })
        local data = mockJSON.decode(response.Data)
        assert(data.effectiveWave == 90,
            "Wave 50 should be difficulty 90, got " .. tostring(data.effectiveWave))
    end)

    -- Test 3: Classic Mode Comparison - Wave 1
    runTest("test_classic_comparison_wave_1", function()
        local dailyResponse = sendTestMessage("get-daily-difficulty", {
            Action = "GetDailyDifficulty",
            From = "test-sender",
            Data = '{"waveIndex":1,"ignoreCurveChanges":false}'
        })
        local dailyData = mockJSON.decode(dailyResponse.Data)
        -- Classic wave 1 = 1 (no offset)
        -- Daily wave 1 = 31 (1 + 30 + 0)
        assert(dailyData.effectiveWave == 31,
            "Daily wave 1 should be 31 (harder than classic 1)")
    end)

    -- Test 4: Monotonic Progression (1-50)
    runTest("test_monotonic_progression_waves_1_to_50", function()
        local prevDifficulty = 0
        for wave = 1, 50 do
            local response = sendTestMessage("get-daily-difficulty", {
                Action = "GetDailyDifficulty",
                From = "test-sender",
                Data = mockJSON.encode({waveIndex = wave, ignoreCurveChanges = false})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.effectiveWave > prevDifficulty,
                "Wave " .. wave .. " difficulty should be > previous (" .. prevDifficulty .. "), got " .. data.effectiveWave)
            prevDifficulty = data.effectiveWave
        end
    end)

    -- Test 5: Effective Wave Calculation for All Ranges
    runTest("test_effective_wave_all_ranges", function()
        local testCases = {
            {wave = 1, expected = 31},
            {wave = 5, expected = 36},
            {wave = 10, expected = 42},
            {wave = 15, expected = 48},
            {wave = 20, expected = 54},
            {wave = 25, expected = 60},
            {wave = 30, expected = 66},
            {wave = 40, expected = 78},
            {wave = 50, expected = 90}
        }
        for _, testCase in ipairs(testCases) do
            local response = sendTestMessage("get-daily-difficulty", {
                Action = "GetDailyDifficulty",
                From = "test-sender",
                Data = mockJSON.encode({waveIndex = testCase.wave, ignoreCurveChanges = false})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.effectiveWave == testCase.expected,
                "Wave " .. testCase.wave .. " should be " .. testCase.expected .. ", got " .. data.effectiveWave)
        end
    end)

    -- Test 6: Progression Bonus Calculation Accuracy
    runTest("test_progression_bonus_accuracy", function()
        local testCases = {
            {wave = 4, expectedBonus = 0},
            {wave = 5, expectedBonus = 1},
            {wave = 9, expectedBonus = 1},
            {wave = 10, expectedBonus = 2},
            {wave = 14, expectedBonus = 2},
            {wave = 15, expectedBonus = 3},
            {wave = 24, expectedBonus = 4},
            {wave = 25, expectedBonus = 5},
            {wave = 49, expectedBonus = 9},
            {wave = 50, expectedBonus = 10}
        }
        for _, testCase in ipairs(testCases) do
            local response = sendTestMessage("get-daily-difficulty", {
                Action = "GetDailyDifficulty",
                From = "test-sender",
                Data = mockJSON.encode({waveIndex = testCase.wave, ignoreCurveChanges = false})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.progressionBonus == testCase.expectedBonus,
                "Wave " .. testCase.wave .. " progression bonus should be " .. testCase.expectedBonus .. ", got " .. data.progressionBonus)
        end
    end)

    -- Test 7: Ignore Curve Changes Validation
    runTest("test_ignore_curve_changes_removes_bonus", function()
        local testCases = {10, 25, 50}
        for _, wave in ipairs(testCases) do
            local normalResponse = sendTestMessage("get-daily-difficulty", {
                Action = "GetDailyDifficulty",
                From = "test-sender",
                Data = '{"waveIndex":' .. wave .. ',"ignoreCurveChanges":false}'
            })
            local ignoredResponse = sendTestMessage("get-daily-difficulty", {
                Action = "GetDailyDifficulty",
                From = "test-sender",
                Data = '{"waveIndex":' .. wave .. ',"ignoreCurveChanges":true}'
            })
            local normalData = mockJSON.decode(normalResponse.Data)
            local ignoredData = mockJSON.decode(ignoredResponse.Data)
            local expectedDifference = math.floor(wave / 5)
            assert(normalData.effectiveWave - ignoredData.effectiveWave == expectedDifference,
                "Wave " .. wave .. " should have " .. expectedDifference .. " bonus difference, got " ..
                (normalData.effectiveWave - ignoredData.effectiveWave))
        end
    end)

    -- Test 8: Base Offset Consistency (Always 30)
    runTest("test_base_offset_always_30", function()
        local testWaves = {1, 10, 25, 50}
        for _, wave in ipairs(testWaves) do
            local response = sendTestMessage("get-daily-difficulty", {
                Action = "GetDailyDifficulty",
                From = "test-sender",
                Data = mockJSON.encode({waveIndex = wave, ignoreCurveChanges = false})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.baseOffset == 30,
                "Wave " .. wave .. " base offset should always be 30, got " .. tostring(data.baseOffset))
        end
    end)

    -- Print summary
    print("\n==================================================")
    print("Difficulty Scaling Test Results:")
    print("  Passed: " .. passedTests)
    print("  Failed: " .. (totalTests - passedTests))
    print("  Total:  " .. totalTests)
    print("")

    if passedTests == totalTests then
        print("🎉 All difficulty scaling tests passed!")
        return true
    else
        print("❌ Some difficulty scaling tests failed!")
        return false
    end
end

-- Run tests
return { runTests = runTests }
