-- Unit tests for daily run trainer wave detection
-- Tests X5 waves, X0 waves, exclusions, non-trainer waves

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
    print("\nRunning Daily Run Trainer Wave Unit Tests...")
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

    -- Test 1: All X5 Waves Are Trainer Waves
    runTest("test_all_x5_waves_are_trainer", function()
        local x5Waves = {5, 15, 25, 35, 45}
        for _, wave in ipairs(x5Waves) do
            local response = sendTestMessage("is-trainer-wave", {
                Action = "IsTrainerWave",
                From = "test-sender",
                Data = mockJSON.encode({waveIndex = wave, isFinalWave = false})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.isTrainer == true,
                "Wave " .. wave .. " (X5) should be trainer wave")
        end
    end)

    -- Test 2: All X0 Waves > 10 Are Trainer Waves
    runTest("test_all_x0_waves_gt_10_are_trainer", function()
        local x0Waves = {20, 30, 40}
        for _, wave in ipairs(x0Waves) do
            local response = sendTestMessage("is-trainer-wave", {
                Action = "IsTrainerWave",
                From = "test-sender",
                Data = mockJSON.encode({waveIndex = wave, isFinalWave = false})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.isTrainer == true,
                "Wave " .. wave .. " (X0, >10) should be trainer wave")
        end
    end)

    -- Test 3: Wave 10 Edge Case (X0 but Excluded)
    runTest("test_wave_10_edge_case_not_trainer", function()
        local response = sendTestMessage("is-trainer-wave", {
            Action = "IsTrainerWave",
            From = "test-sender",
            Data = '{"waveIndex":10,"isFinalWave":false}'
        })
        local data = mockJSON.decode(response.Data)
        assert(data.isTrainer == false,
            "Wave 10 should NOT be trainer wave (excluded)")
    end)

    -- Test 4: Non-Trainer Waves Validation
    runTest("test_non_trainer_waves", function()
        local nonTrainerWaves = {1, 2, 3, 4, 6, 7, 8, 9, 10, 11, 12, 13, 14, 16, 17, 18, 19, 21, 22, 23, 24, 26}
        for _, wave in ipairs(nonTrainerWaves) do
            local response = sendTestMessage("is-trainer-wave", {
                Action = "IsTrainerWave",
                From = "test-sender",
                Data = mockJSON.encode({waveIndex = wave, isFinalWave = false})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.isTrainer == false,
                "Wave " .. wave .. " should NOT be trainer wave")
        end
    end)

    -- Test 5: Final Wave Not Trainer (X0 Waves Only)
    -- Note: X5 waves (5, 15, 25, 35, 45) ignore isFinalWave per current implementation
    runTest("test_final_wave_not_trainer_x0_only", function()
        local finalWavesX0 = {50, 40, 30, 20, 10}
        for _, wave in ipairs(finalWavesX0) do
            local response = sendTestMessage("is-trainer-wave", {
                Action = "IsTrainerWave",
                From = "test-sender",
                Data = mockJSON.encode({waveIndex = wave, isFinalWave = true})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.isTrainer == false,
                "Wave " .. wave .. " (X0) should NOT be trainer wave when isFinalWave=true")
        end
    end)

    -- Test 6: Full 50-Wave Schedule Validation
    runTest("test_full_50_wave_schedule", function()
        local expectedTrainerWaves = {5, 15, 20, 25, 30, 35, 40, 45}
        local actualTrainerWaves = {}
        for wave = 1, 50 do
            local isFinal = (wave == 50)
            local response = sendTestMessage("is-trainer-wave", {
                Action = "IsTrainerWave",
                From = "test-sender",
                Data = mockJSON.encode({waveIndex = wave, isFinalWave = isFinal})
            })
            local data = mockJSON.decode(response.Data)
            if data.isTrainer then
                table.insert(actualTrainerWaves, wave)
            end
        end
        assert(#actualTrainerWaves == #expectedTrainerWaves,
            "Should have " .. #expectedTrainerWaves .. " trainer waves, got " .. #actualTrainerWaves)
        for i, wave in ipairs(expectedTrainerWaves) do
            assert(actualTrainerWaves[i] == wave,
                "Trainer wave " .. i .. " should be " .. wave .. ", got " .. tostring(actualTrainerWaves[i]))
        end
    end)

    -- Test 7: X5 Wave Pattern Validation (Beyond Wave 50)
    runTest("test_x5_pattern_beyond_wave_50", function()
        local extendedX5Waves = {55, 65, 75, 85, 95}
        for _, wave in ipairs(extendedX5Waves) do
            local response = sendTestMessage("is-trainer-wave", {
                Action = "IsTrainerWave",
                From = "test-sender",
                Data = mockJSON.encode({waveIndex = wave, isFinalWave = false})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.isTrainer == true,
                "Wave " .. wave .. " (X5) should be trainer wave even beyond 50")
        end
    end)

    -- Print summary
    print("\n==================================================")
    print("Trainer Wave Detection Test Results:")
    print("  Passed: " .. passedTests)
    print("  Failed: " .. (totalTests - passedTests))
    print("  Total:  " .. totalTests)
    print("")

    if passedTests == totalTests then
        print("🎉 All trainer wave detection tests passed!")
        return true
    else
        print("❌ Some trainer wave detection tests failed!")
        return false
    end
end

-- Run tests
return { runTests = runTests }
