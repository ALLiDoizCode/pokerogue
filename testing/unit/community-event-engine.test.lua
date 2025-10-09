-- Unit Tests for Community Event Engine
-- Tests community event creation, contribution tracking, and progress

local testSuite = {
    processPath = 'processes/community-event-engine.lua',
    processId = 'community-event-test',
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
    print("\n=== COMMUNITY EVENT ENGINE TESTS ===\n")

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
        "create-community-event",
        "get-community-event",
        "get-active-community-events",
        "track-contribution",
        "get-community-progress"
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

    -- Test 2: Create community event
    print("\nTest 2: Create Community Event")
    _G.sent_messages = {}
    local msg = {
        From = "test_sender",
        Timestamp = "1734739200",
        Action = "CreateCommunityEvent",
        EventConfig = '{"name":"Test Event","description":"Test","startDate":1734739200,"endDate":1735948800,"goals":[]}'
    }

    if _G.Handlers["create-community-event"] then
        _G.Handlers["create-community-event"].handler(msg)

        if #_G.sent_messages > 0 then
            local response = _G.sent_messages[1]
            if response.Action == "SaveState" and response.Target == msg.From then
                print("  ✓ Event created successfully")
                passed = passed + 1
            else
                print("  ✗ Response format incorrect")
                failed = failed + 1
            end
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 3: Get community event
    print("\nTest 3: Get Community Event")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "GetCommunityEvent",
        EventId = "test_event_1"
    }

    if _G.Handlers["get-community-event"] then
        _G.Handlers["get-community-event"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Event retrieved")
            passed = passed + 1
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 4: Get active community events
    print("\nTest 4: Get Active Community Events")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "GetActiveCommunityEvents"
    }

    if _G.Handlers["get-active-community-events"] then
        _G.Handlers["get-active-community-events"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Active events retrieved")
            passed = passed + 1
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 5: Track contribution
    print("\nTest 5: Track Contribution")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "TrackContribution",
        EventId = "test_event_1",
        GoalId = "goal_1",
        Value = "100"
    }

    if _G.Handlers["track-contribution"] then
        _G.Handlers["track-contribution"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Contribution tracked")
            passed = passed + 1
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 6: Get community progress
    print("\nTest 6: Get Community Progress")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "GetCommunityProgress",
        EventId = "test_event_1"
    }

    if _G.Handlers["get-community-progress"] then
        _G.Handlers["get-community-progress"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Progress retrieved")
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
