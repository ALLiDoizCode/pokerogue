-- Unit tests for dialogue-navigation-engine.lua using message-based testing
-- Tests dialogue tree flow state machine and navigation logic
-- Covers intro → options → selected → outro flow progression

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
            -- Simple JSON encoding for tests
            if #t == 0 then
                return "{}"
            end
            return "mock_json_encoded"
        end
        return tostring(t)
    end,
    decode = function(s)
        if s == "{}" or s == "" then
            return {}
        end
        -- For tests, return mock data structure
        return {}
    end
}

-- Set up test environment
local function setupTestEnvironment()
    -- Clear test state
    testMessages = {}
    testHandlers = {}

    -- Set up global mocks
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

    -- Check if message matches the handler's matcher
    if not handler.matcher(message) then
        error("Message does not match handler pattern")
    end

    -- Clear previous messages
    testMessages = {}

    -- Execute handler
    handler.handler(message)

    -- Return sent messages
    return testMessages
end

-- Load the dialogue navigation process after setting up environment
local function loadDialogueNavigationProcess()
    setupTestEnvironment()
    dofile("processes/dialogue-navigation-engine.lua")
end

-- Test suite for Dialogue Flow Navigation
local function testDialogueFlowNavigation()
    local tests = {}

    -- Test 1: Process loads and registers handlers
    tests["test_process_initialization"] = function()
        loadDialogueNavigationProcess()

        -- Check that required handlers are registered
        local requiredHandlers = {
            "info",
            "get-dialogue-flow",
            "validate-option-selection",
            "process-dialogue-tokens",
            "get-option-consequences",
            "track-dialogue-choice"
        }

        for _, handlerName in ipairs(requiredHandlers) do
            assert(testHandlers[handlerName] ~= nil, "Handler should be registered: " .. handlerName)
            assert(type(testHandlers[handlerName].handler) == "function", "Handler should be a function: " .. handlerName)
        end

        print("✓ Process initialization test passed")
        return true
    end

    -- Test 2: ADP Info Handler
    tests["test_adp_info_handler"] = function()
        loadDialogueNavigationProcess()

        local infoMessage = {
            From = "test-client",
            Action = "Info"
        }

        local responses = sendTestMessage("info", infoMessage)

        assert(#responses == 1, "Should send one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Data ~= nil, "Should include process metadata")

        print("✓ ADP Info handler test passed")
        return true
    end

    -- Test 3: Complete flow progression (intro → options → outro)
    tests["test_complete_flow_progression"] = function()
        loadDialogueNavigationProcess()

        -- Test intro phase
        local introMessage = {
            From = "test-user",
            Action = "GetDialogueFlow",
            EncounterType = "TestEncounter",
            DialoguePhase = "intro",
            Data = json.encode({
                dialogue = {
                    intro = {
                        {speaker = "Professor Oak", text = "Welcome to the mystery encounter!"}
                    }
                }
            })
        }

        local responses = sendTestMessage("get-dialogue-flow", introMessage)
        assert(#responses >= 1, "Should send response for intro phase")
        local introResponse = responses[1]
        assert(introResponse.Target == "test-user", "Should respond to sender")
        assert(introResponse.PhaseType == "intro", "Should indicate intro phase")

        print("✓ Complete flow progression test passed")
        return true
    end

    -- Test 4: Edge case - No intro dialogue
    tests["test_no_intro_dialogue"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "GetDialogueFlow",
            EncounterType = "TestEncounter",
            DialoguePhase = "intro",
            Data = json.encode({
                dialogue = {
                    encounterOptionsDialogue = {
                        title = "What will you do?",
                        options = {
                            {buttonLabel = "Option 1"},
                            {buttonLabel = "Option 2"}
                        }
                    }
                }
            })
        }

        local responses = sendTestMessage("get-dialogue-flow", message)
        assert(#responses >= 1, "Should send response even with no intro")
        local response = responses[1]
        assert(response.Target == "test-user", "Should respond to sender")

        print("✓ No intro dialogue test passed")
        return true
    end

    -- Test 5: Edge case - No outro dialogue
    tests["test_no_outro_dialogue"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "GetDialogueFlow",
            EncounterType = "TestEncounter",
            DialoguePhase = "outro",
            Data = json.encode({
                dialogue = {
                    intro = {{text = "Start encounter"}},
                    encounterOptionsDialogue = {
                        title = "What will you do?",
                        options = {
                            {buttonLabel = "Option 1"},
                            {buttonLabel = "Option 2"}
                        }
                    }
                }
            })
        }

        local responses = sendTestMessage("get-dialogue-flow", message)
        assert(#responses >= 1, "Should send response even with no outro")
        local response = responses[1]
        assert(response.Target == "test-user", "Should respond to sender")

        print("✓ No outro dialogue test passed")
        return true
    end

    -- Test 6: SELECTED phase requires OptionIndex
    tests["test_selected_phase_requires_option_index"] = function()
        loadDialogueNavigationProcess()

        -- Test without OptionIndex - should return error
        local messageNoIndex = {
            From = "test-user",
            Action = "GetDialogueFlow",
            EncounterType = "TestEncounter",
            DialoguePhase = "selected",
            Data = json.encode({
                options = {
                    {dialogue = {selected = {{text = "Option 1 selected"}}}},
                    {dialogue = {selected = {{text = "Option 2 selected"}}}}
                }
            })
        }

        local responses = sendTestMessage("get-dialogue-flow", messageNoIndex)
        assert(#responses >= 1, "Should send error response")
        local response = responses[1]
        assert(response.Action == "Error", "Should return error without OptionIndex")

        print("✓ SELECTED phase requires OptionIndex test passed")
        return true
    end

    -- Test 7: Invalid dialogue phase handling
    tests["test_invalid_dialogue_phase"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "GetDialogueFlow",
            EncounterType = "TestEncounter",
            DialoguePhase = "invalid_phase",
            Data = json.encode({dialogue = {}})
        }

        local responses = sendTestMessage("get-dialogue-flow", message)
        assert(#responses >= 1, "Should send error response")
        local response = responses[1]
        assert(response.Action == "Error", "Should return error for invalid phase")

        print("✓ Invalid dialogue phase test passed")
        return true
    end

    -- Test 8: Missing encounter definition handling
    tests["test_missing_encounter_definition"] = function()
        loadDialogueNavigationProcess()

        local message = {
            From = "test-user",
            Action = "GetDialogueFlow",
            EncounterType = "TestEncounter",
            DialoguePhase = "intro"
            -- No Data field
        }

        local responses = sendTestMessage("get-dialogue-flow", message)
        assert(#responses >= 1, "Should send error response")
        local response = responses[1]
        assert(response.Action == "Error", "Should return error for missing definition")

        print("✓ Missing encounter definition test passed")
        return true
    end

    return tests
end

-- Run all tests
local function runTests()
    print("Running Dialogue Flow Navigation Unit Tests...")
    print("=" .. string.rep("=", 50))

    local tests = testDialogueFlowNavigation()
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
    testDialogueFlowNavigation = testDialogueFlowNavigation,
    setupTestEnvironment = setupTestEnvironment,
    sendTestMessage = sendTestMessage
}
