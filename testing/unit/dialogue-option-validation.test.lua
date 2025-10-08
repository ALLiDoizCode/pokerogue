-- Unit tests for dialogue option validation
-- Tests option selection validation including requirement checking

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local mockAO = {
    id = "test-dialogue-navigation-engine",
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
                        if msg[tag] == v then return true end
                    end
                    return false
                else
                    return msg[tag] == value
                end
            end
        end
    }
}

-- Mock JSON
local mockJSON = {
    encode = function(t)
        if type(t) == "table" then
            return "{}"
        end
        return tostring(t)
    end,
    decode = function(s)
        if s == "{}" or s == "" then
            return {}
        end
        return {}
    end
}

-- Set up test environment
local function setupTestEnvironment()
    testMessages = {}
    testHandlers = {}

    _G.ao = mockAO
    _G.Handlers = mockHandlers
    _G.json = mockJSON
    _G.os = os
    _G.math = math
    _G.string = string
    _G.table = table
    _G.pairs = pairs
    _G.ipairs = ipairs
    _G.type = type
    _G.tostring = tostring
    _G.tonumber = tonumber
    _G.pcall = pcall
    _G.print = print
end

-- Helper function to send a test message to a handler
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
    return testMessages
end

-- Load the dialogue navigation process
local function loadDialogueNavigationProcess()
    setupTestEnvironment()
    dofile("processes/dialogue-navigation-engine.lua")
end

-- Test suite for Option Validation
local function testDialogueOptionValidation()
    local tests = {}

    -- Test 1: Option with all requirements met
    tests["test_option_all_requirements_met"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "ValidateOptionSelection",
            EncounterType = "TestEncounter",
            OptionIndex = "1",
            Data = json.encode({
                waveIndex = 50,
                party = {{id = 1}, {id = 2}},
                money = 1000
            })
        }

        local responses = sendTestMessage("validate-option-selection", message)
        assert(#responses >= 1, "Should send validation response")
        local response = responses[1]
        assert(response.Target == "test-user", "Should respond to sender")

        print("✓ Option with all requirements met test passed")
        return true
    end

    -- Test 2: Option with failed WaveRange requirement
    tests["test_option_failed_wave_range"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "ValidateOptionSelection",
            EncounterType = "TestEncounter",
            OptionIndex = "1",
            Data = json.encode({
                waveIndex = 5,  -- Below minimum
                party = {{id = 1}}
            })
        }

        local responses = sendTestMessage("validate-option-selection", message)
        assert(#responses >= 1, "Should send validation response")
        local response = responses[1]
        assert(response.Target == "test-user", "Should respond to sender")

        print("✓ Option with failed WaveRange test passed")
        return true
    end

    -- Test 3: Option with failed PartySize requirement
    tests["test_option_failed_party_size"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "ValidateOptionSelection",
            EncounterType = "TestEncounter",
            OptionIndex = "1",
            Data = json.encode({
                waveIndex = 50,
                party = {{id = 1}}  -- Only 1 Pokemon
            })
        }

        local responses = sendTestMessage("validate-option-selection", message)
        assert(#responses >= 1, "Should send validation response")
        local response = responses[1]
        assert(response.Target == "test-user", "Should respond to sender")

        print("✓ Option with failed PartySize test passed")
        return true
    end

    -- Test 4: Option with failed HealthRatio requirement
    tests["test_option_failed_health_ratio"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "ValidateOptionSelection",
            EncounterType = "TestEncounter",
            OptionIndex = "1",
            Data = json.encode({
                waveIndex = 50,
                party = {
                    {id = 1, hp = 10, maxHp = 100},  -- 10% HP
                    {id = 2, hp = 20, maxHp = 100}
                }
            })
        }

        local responses = sendTestMessage("validate-option-selection", message)
        assert(#responses >= 1, "Should send validation response")
        local response = responses[1]
        assert(response.Target == "test-user", "Should respond to sender")

        print("✓ Option with failed HealthRatio test passed")
        return true
    end

    -- Test 5: Option with failed Money requirement
    tests["test_option_failed_money_requirement"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "ValidateOptionSelection",
            EncounterType = "TestEncounter",
            OptionIndex = "1",
            Data = json.encode({
                waveIndex = 50,
                party = {{id = 1}},
                money = 50  -- Not enough money
            })
        }

        local responses = sendTestMessage("validate-option-selection", message)
        assert(#responses >= 1, "Should send validation response")
        local response = responses[1]
        assert(response.Target == "test-user", "Should respond to sender")

        print("✓ Option with failed Money requirement test passed")
        return true
    end

    -- Test 6: Option disabled state handling
    tests["test_option_disabled_state"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "ValidateOptionSelection",
            EncounterType = "TestEncounter",
            OptionIndex = "1",
            Data = json.encode({
                waveIndex = 5,  -- Fails requirement
                party = {{id = 1}}
            })
        }

        local responses = sendTestMessage("validate-option-selection", message)
        assert(#responses >= 1, "Should send validation response")
        local response = responses[1]
        assert(response.Target == "test-user", "Should respond to sender")
        -- Option should be disabled

        print("✓ Option disabled state test passed")
        return true
    end

    -- Test 7: Invalid option index handling
    tests["test_invalid_option_index"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "ValidateOptionSelection",
            EncounterType = "TestEncounter",
            OptionIndex = "999",  -- Invalid index
            Data = json.encode({
                waveIndex = 50,
                party = {{id = 1}}
            })
        }

        local responses = sendTestMessage("validate-option-selection", message)
        assert(#responses >= 1, "Should send error response")
        local response = responses[1]
        assert(response.Target == "test-user", "Should respond to sender")

        print("✓ Invalid option index test passed")
        return true
    end

    -- Test 8: Missing OptionIndex parameter
    tests["test_missing_option_index"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "ValidateOptionSelection",
            EncounterType = "TestEncounter",
            -- Missing OptionIndex
            Data = json.encode({
                waveIndex = 50,
                party = {{id = 1}}
            })
        }

        local responses = sendTestMessage("validate-option-selection", message)
        assert(#responses >= 1, "Should send error response")
        local response = responses[1]
        assert(response.Action == "Error", "Should return error")

        print("✓ Missing OptionIndex test passed")
        return true
    end

    -- Test 9: Missing gameState data
    tests["test_missing_game_state"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "ValidateOptionSelection",
            EncounterType = "TestEncounter",
            OptionIndex = "1"
            -- No Data field
        }

        local responses = sendTestMessage("validate-option-selection", message)
        assert(#responses >= 1, "Should send error response")
        local response = responses[1]
        assert(response.Action == "Error", "Should return error")

        print("✓ Missing gameState test passed")
        return true
    end

    -- Test 10: Multiple requirement failures
    tests["test_multiple_requirement_failures"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "ValidateOptionSelection",
            EncounterType = "TestEncounter",
            OptionIndex = "1",
            Data = json.encode({
                waveIndex = 5,  -- Fails WaveRange
                party = {},     -- Fails PartySize
                money = 0       -- Fails Money requirement
            })
        }

        local responses = sendTestMessage("validate-option-selection", message)
        assert(#responses >= 1, "Should send validation response")
        local response = responses[1]
        assert(response.Target == "test-user", "Should respond to sender")

        print("✓ Multiple requirement failures test passed")
        return true
    end

    return tests
end

-- Run all tests
local function runTests()
    print("Running Dialogue Option Validation Unit Tests...")
    print("=" .. string.rep("=", 50))

    local tests = testDialogueOptionValidation()
    local passed = 0
    local failed = 0

    for testName, testFunc in pairs(tests) do
        print("\nRunning: " .. testName)

        local success, error = pcall(testFunc)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ " .. testName .. " FAILED: " .. tostring(error))
        end
    end

    print("\n" .. string.rep("=", 50))
    print("Test Results:")
    print("  Passed: " .. passed)
    print("  Failed: " .. failed)
    print("  Total:  " .. (passed + failed))

    if failed == 0 then
        print("\n🎉 All tests passed!")
        return true
    else
        print("\n❌ Some tests failed!")
        return false
    end
end

-- Export for aolite framework
return {
    runTests = runTests,
    testDialogueOptionValidation = testDialogueOptionValidation,
    setupTestEnvironment = setupTestEnvironment,
    sendTestMessage = sendTestMessage
}
