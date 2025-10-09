-- Unit Tests for Seasonal Event Engine
-- Tests seasonal event timing, multipliers, and event-specific content

-- Simple test structure without requiring aolite framework
local testSuite = {
    processPath = 'processes/seasonal-event-engine.lua',
    processId = 'seasonal-event-test',
    tests = {}
}

-- Mock AO environment
local function setupMocks()
    _G.sent_messages = {}
    _G.ao = {
        id = "test_process_id",
        send = function(msg)
            table.insert(_G.sent_messages, msg)
        end
    }

    _G.Handlers = {
        add = function(name, matcher, handler)
            _G.Handlers[name] = {
                name = name,
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

    _G.json = require("json")
end

-- Load process and run basic tests
local function runTests()
    print("\n=== SEASONAL EVENT ENGINE TESTS ===\n")

    setupMocks()

    -- Load the process
    local loadSuccess, loadError = pcall(dofile, testSuite.processPath)
    if not loadSuccess then
        print("❌ Failed to load process: " .. tostring(loadError))
        return false
    end

    print("✅ Process loaded successfully")

    local passed = 0
    local failed = 0

    -- Test 1: Check handlers registered
    print("\nTest 1: Handler Registration")
    local requiredHandlers = {
        "get-active-event",
        "get-event-multipliers",
        "get-event-encounters",
        "get-weather-modifications",
        "get-event-rewards"
    }

    for _, handlerName in ipairs(requiredHandlers) do
        if _G.Handlers[handlerName] then
            print("  ✓ Handler registered: " .. handlerName)
            passed = passed + 1
        else
            print("  ✗ Handler missing: " .. handlerName)
            failed = failed + 1
        end
    end

    -- Test 2: Get active event during Winter Holiday
    print("\nTest 2: Get Active Event (During Winter Holiday)")
    _G.sent_messages = {}
    local msg = {
        From = "test_sender",
        Timestamp = "1734800000", -- Dec 22, 2024 (during Winter Holiday)
        Action = "GetActiveEvent"
    }

    if _G.Handlers["get-active-event"] then
        _G.Handlers["get-active-event"].handler(msg)

        if #_G.sent_messages > 0 then
            local response = _G.sent_messages[1]
            if response.Target == msg.From and response.Action == "SaveState" then
                print("  ✓ Response sent with correct format")
                passed = passed + 1
            else
                print("  ✗ Response format incorrect")
                failed = failed + 1
            end
        else
            print("  ✗ No response sent")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 3: Get event multipliers
    print("\nTest 3: Get Event Multipliers")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "GetEventMultipliers"
    }

    if _G.Handlers["get-event-multipliers"] then
        _G.Handlers["get-event-multipliers"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Multipliers response sent")
            passed = passed + 1
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 4: Get event encounters
    print("\nTest 4: Get Event Encounters")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "GetEventEncounters"
    }

    if _G.Handlers["get-event-encounters"] then
        _G.Handlers["get-event-encounters"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Encounters response sent")
            passed = passed + 1
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 5: Get weather modifications
    print("\nTest 5: Get Weather Modifications")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "GetWeatherModifications"
    }

    if _G.Handlers["get-weather-modifications"] then
        _G.Handlers["get-weather-modifications"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Weather response sent")
            passed = passed + 1
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 6: No active event
    print("\nTest 6: No Active Event (Outside event period)")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1700000000", -- Nov 2023 (no event)
        Action = "GetActiveEvent"
    }

    if _G.Handlers["get-active-event"] then
        _G.Handlers["get-active-event"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Response sent for non-event period")
            passed = passed + 1
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Summary
    print("\n=== TEST RESULTS ===")
    print(string.format("Passed: %d", passed))
    print(string.format("Failed: %d", failed))
    print(string.format("Total: %d", passed + failed))

    if failed == 0 then
        print("\n✅ ALL TESTS PASSED!")
        return true
    else
        print("\n✗ SOME TESTS FAILED!")
        return false
    end
end

-- Export module
return {
    runTests = runTests
}
