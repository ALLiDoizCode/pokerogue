-- Unit tests for daily run event seed parsing
-- Tests boss modifier, multiple modifiers, malformed patterns, partial modifiers

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
    print("\nRunning Daily Run Event Seed Parsing Unit Tests...")
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

    -- Test 1: Boss Modifier Parsing - Valid Species
    runTest("test_boss_modifier_parsing_valid", function()
        local eventSeed = "20250103abcdefghij123456/boss014900/"
        local response = sendTestMessage("parse-event-seed", {
            Action = "ParseEventSeed",
            From = "test-sender",
            Data = mockJSON.encode({seed = eventSeed})
        })
        local data = mockJSON.decode(response.Data)
        assert(data.boss ~= nil, "Boss modifier should be parsed")
        -- Note: Full boss object validation would require checking speciesId field
    end)

    -- Test 2: Multiple Modifier Combinations
    runTest("test_multiple_modifiers_combined", function()
        local eventSeed = "20250103abcdefghij123456/starters002500013300003700/boss014900/biome08/luck12/"
        local response = sendTestMessage("parse-event-seed", {
            Action = "ParseEventSeed",
            From = "test-sender",
            Data = mockJSON.encode({seed = eventSeed})
        })
        local data = mockJSON.decode(response.Data)
        assert(data.isEventSeed == true, "Should be detected as event seed")
        assert(data.starters ~= nil, "Starters should be parsed")
        assert(data.boss ~= nil, "Boss should be parsed")
        assert(data.biome == 8, "Biome should be parsed as 8")
        assert(data.luck == 12, "Luck should be parsed as 12")
    end)

    -- Test 3: Malformed Pattern Handling - Invalid Starter Format
    runTest("test_malformed_starter_pattern", function()
        local eventSeed = "20250103abcdefghij123456/starters_invalid/"
        local response = sendTestMessage("parse-event-seed", {
            Action = "ParseEventSeed",
            From = "test-sender",
            Data = mockJSON.encode({seed = eventSeed})
        })
        local data = mockJSON.decode(response.Data)
        assert(data.isEventSeed == true, "Should still be detected as event seed")
        assert(data.starters == nil, "Malformed starter pattern should not parse")
    end)

    -- Test 4: Partial Modifier Scenarios - Only Biome
    runTest("test_partial_modifier_biome_only", function()
        local eventSeed = "20250103abcdefghij123456/biome05/"
        local response = sendTestMessage("parse-event-seed", {
            Action = "ParseEventSeed",
            From = "test-sender",
            Data = mockJSON.encode({seed = eventSeed})
        })
        local data = mockJSON.decode(response.Data)
        assert(data.isEventSeed == true, "Should be event seed")
        assert(data.biome == 5, "Biome should be parsed as 5")
        assert(data.starters == nil, "Starters should not be present")
        assert(data.boss == nil, "Boss should not be present")
        assert(data.luck == nil, "Luck should not be present")
    end)

    -- Test 5: Invalid Biome ID Handling (>34)
    runTest("test_invalid_biome_id_gt_34", function()
        local eventSeed = "20250103abcdefghij123456/biome99/"
        local response = sendTestMessage("parse-event-seed", {
            Action = "ParseEventSeed",
            From = "test-sender",
            Data = mockJSON.encode({seed = eventSeed})
        })
        local data = mockJSON.decode(response.Data)
        assert(data.biome == nil, "Biome 99 should be invalid (>34)")
    end)

    -- Test 6: Invalid Luck Range (>14)
    runTest("test_invalid_luck_gt_14", function()
        local eventSeed = "20250103abcdefghij123456/luck15/"
        local response = sendTestMessage("parse-event-seed", {
            Action = "ParseEventSeed",
            From = "test-sender",
            Data = mockJSON.encode({seed = eventSeed})
        })
        local data = mockJSON.decode(response.Data)
        assert(data.luck == nil, "Luck 15 should be invalid (>14)")
    end)

    -- Test 7: Valid Luck Range Boundary (0 and 14)
    runTest("test_valid_luck_boundaries", function()
        local testCases = {
            {seed = "20250103abcdefghij123456/luck00/", expectedLuck = 0},
            {seed = "20250103abcdefghij123456/luck14/", expectedLuck = 14}
        }
        for _, testCase in ipairs(testCases) do
            local response = sendTestMessage("parse-event-seed", {
                Action = "ParseEventSeed",
                From = "test-sender",
                Data = mockJSON.encode({seed = testCase.seed})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.luck == testCase.expectedLuck,
                "Luck should be " .. testCase.expectedLuck .. ", got " .. tostring(data.luck))
        end
    end)

    -- Print summary
    print("\n==================================================")
    print("Event Seed Parsing Test Results:")
    print("  Passed: " .. passedTests)
    print("  Failed: " .. (totalTests - passedTests))
    print("  Total:  " .. totalTests)
    print("")

    if passedTests == totalTests then
        print("🎉 All event seed parsing tests passed!")
        return true
    else
        print("❌ Some event seed parsing tests failed!")
        return false
    end
end

-- Run tests
return { runTests = runTests }
