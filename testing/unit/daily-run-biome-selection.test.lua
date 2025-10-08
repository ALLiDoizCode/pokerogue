-- Unit tests for daily run biome selection logic
-- Tests weighted random selection, biome exclusion, deterministic behavior

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
    print("\nRunning Daily Run Biome Selection Unit Tests...")
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

    -- Test 1: Weighted Random Selection - Validate Non-Zero Result
    runTest("test_weighted_random_selection_non_zero", function()
        local response = sendTestMessage("generate-daily-run", {
            Action = "GenerateDailyRun",
            From = "test-sender",
            Data = '{"seed":"20250103biometest123456"}'
        })
        local data = mockJSON.decode(response.Data)
        assert(data.startingBiome > 0, "Biome should be > 0 (not TOWN)")
        assert(data.startingBiome < 34, "Biome should be < 34 (not END)")
    end)

    -- Test 2: TOWN (0) Never Selected
    runTest("test_town_biome_never_selected", function()
        for i = 1, 50 do
            local seed = "town" .. string.format("%020d", i)
            local response = sendTestMessage("generate-daily-run", {
                Action = "GenerateDailyRun",
                From = "test-sender",
                Data = mockJSON.encode({seed = seed})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.startingBiome ~= 0, "TOWN (0) should never be selected on iteration " .. i)
        end
    end)

    -- Test 3: END (34) Never Selected
    runTest("test_end_biome_never_selected", function()
        for i = 1, 50 do
            local seed = "end" .. string.format("%021d", i)
            local response = sendTestMessage("generate-daily-run", {
                Action = "GenerateDailyRun",
                From = "test-sender",
                Data = mockJSON.encode({seed = seed})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.startingBiome ~= 34, "END (34) should never be selected on iteration " .. i)
        end
    end)

    -- Test 4: Cumulative Threshold Calculation Produces Valid Biome
    runTest("test_cumulative_threshold_valid_biome", function()
        local response = sendTestMessage("generate-daily-run", {
            Action = "GenerateDailyRun",
            From = "test-sender",
            Data = '{"seed":"20250103cumulative1234567"}'
        })
        local data = mockJSON.decode(response.Data)
        assert(data.startingBiome >= 1 and data.startingBiome <= 33,
            "Biome should be in valid range [1, 33], got " .. tostring(data.startingBiome))
    end)

    -- Test 5: Deterministic Selection - Same Seed Same Biome
    runTest("test_deterministic_same_seed_same_biome", function()
        local seed = "20250103deterministic123"
        local response1 = sendTestMessage("generate-daily-run", {
            Action = "GenerateDailyRun",
            From = "test-sender",
            Data = mockJSON.encode({seed = seed})
        })
        local response2 = sendTestMessage("generate-daily-run", {
            Action = "GenerateDailyRun",
            From = "test-sender",
            Data = mockJSON.encode({seed = seed})
        })
        local data1 = mockJSON.decode(response1.Data)
        local data2 = mockJSON.decode(response2.Data)
        assert(data1.startingBiome == data2.startingBiome,
            "Same seed should produce same biome")
    end)

    -- Test 6: Different Seeds Produce Variation
    runTest("test_different_seeds_produce_variation", function()
        local biomes = {}
        for i = 1, 30 do
            local seed = "variation" .. string.format("%016d", i)
            local response = sendTestMessage("generate-daily-run", {
                Action = "GenerateDailyRun",
                From = "test-sender",
                Data = mockJSON.encode({seed = seed})
            })
            local data = mockJSON.decode(response.Data)
            biomes[data.startingBiome] = true
        end
        local uniqueCount = 0
        for _ in pairs(biomes) do uniqueCount = uniqueCount + 1 end
        assert(uniqueCount >= 5, "Should have at least 5 unique biomes in 30 runs, got " .. uniqueCount)
    end)

    -- Test 7: Weight-3 Biomes Appear in Sample
    runTest("test_weight_3_biomes_appear", function()
        local weight3Biomes = {1, 3, 5, 7, 9, 11, 12, 13}  -- PLAINS, TALL_GRASS, FOREST, SWAMP, LAKE, MOUNTAIN, BADLANDS, CAVE
        local biomeFrequency = {}
        for i = 1, 100 do
            local seed = "weight3" .. string.format("%017d", i)
            local response = sendTestMessage("generate-daily-run", {
                Action = "GenerateDailyRun",
                From = "test-sender",
                Data = mockJSON.encode({seed = seed})
            })
            local data = mockJSON.decode(response.Data)
            biomeFrequency[data.startingBiome] = (biomeFrequency[data.startingBiome] or 0) + 1
        end
        local weight3Total = 0
        for _, biomeId in ipairs(weight3Biomes) do
            weight3Total = weight3Total + (biomeFrequency[biomeId] or 0)
        end
        assert(weight3Total > 30, "Weight-3 biomes should appear frequently (>30%), got " .. weight3Total)
    end)

    -- Test 8: All Weight-3 Biomes Eventually Appear
    runTest("test_all_weight_3_biomes_eventually_appear", function()
        local weight3Biomes = {1, 3, 5, 7, 9, 11, 12, 13}
        local biomesFound = {}
        for i = 1, 200 do
            local seed = "allweight3" .. string.format("%014d", i)
            local response = sendTestMessage("generate-daily-run", {
                Action = "GenerateDailyRun",
                From = "test-sender",
                Data = mockJSON.encode({seed = seed})
            })
            local data = mockJSON.decode(response.Data)
            for _, biomeId in ipairs(weight3Biomes) do
                if data.startingBiome == biomeId then
                    biomesFound[biomeId] = true
                end
            end
        end
        local foundCount = 0
        for _ in pairs(biomesFound) do foundCount = foundCount + 1 end
        assert(foundCount >= 6, "Should find at least 6/8 weight-3 biomes in 200 runs, got " .. foundCount)
    end)

    -- Test 9: Biome Range Validation (1-33)
    runTest("test_biome_range_1_to_33", function()
        for i = 1, 50 do
            local seed = "range" .. string.format("%019d", i)
            local response = sendTestMessage("generate-daily-run", {
                Action = "GenerateDailyRun",
                From = "test-sender",
                Data = mockJSON.encode({seed = seed})
            })
            local data = mockJSON.decode(response.Data)
            assert(data.startingBiome >= 1 and data.startingBiome <= 33,
                "Biome must be in range [1, 33], got " .. tostring(data.startingBiome))
        end
    end)

    -- Test 10: Event Seed Biome Override
    runTest("test_event_seed_biome_override", function()
        local eventSeed = "20250103abcdefghij123456/biome08/"
        local response = sendTestMessage("generate-daily-run", {
            Action = "GenerateDailyRun",
            From = "test-sender",
            Data = mockJSON.encode({seed = eventSeed})
        })
        local data = mockJSON.decode(response.Data)
        assert(data.startingBiome == 8, "Event seed should override biome to 8, got " .. tostring(data.startingBiome))
    end)

    -- Print summary
    print("\n==================================================")
    print("Biome Selection Test Results:")
    print("  Passed: " .. passedTests)
    print("  Failed: " .. (totalTests - passedTests))
    print("  Total:  " .. totalTests)
    print("")

    if passedTests == totalTests then
        print("🎉 All biome selection tests passed!")
        return true
    else
        print("❌ Some biome selection tests failed!")
        return false
    end
end

-- Run tests
return { runTests = runTests }
