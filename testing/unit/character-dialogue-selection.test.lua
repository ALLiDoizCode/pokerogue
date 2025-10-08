-- Unit tests for Character Dialogue Selection using message-based testing
-- Tests dialogue variant selection, bounds checking, and edge cases
--
-- Test Coverage:
-- - AC1: Random dialogue selection based on seed (deterministic)
-- - AC4: Variant selection within bounds
-- - AC4: Gender/sub-type variant selection
-- - Edge cases: invalid trainer types, missing phases

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local mockAO = {
    id = "test-character-dialogue-engine",
    send = function(msg)
        table.insert(testMessages, msg)
        return true
    end
}

-- Mock Handlers with proper ADP pattern
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
            local jsonStr = "{"
            local first = true
            for k, v in pairs(t) do
                if not first then jsonStr = jsonStr .. "," end
                first = false
                if type(k) == "string" then
                    jsonStr = jsonStr .. '"' .. k .. '":'
                end
                if type(v) == "string" then
                    jsonStr = jsonStr .. '"' .. v .. '"'
                elseif type(v) == "number" then
                    jsonStr = jsonStr .. tostring(v)
                elseif type(v) == "table" then
                    jsonStr = jsonStr .. mockJSON.encode(v)
                end
            end
            jsonStr = jsonStr .. "}"
            return jsonStr
        end
        return tostring(t)
    end,
    decode = function(s)
        -- Simple mock decode - for testing we just need basic structure
        return {dialogueVariants = {"mock1", "mock2"}, dialogue = "mock", variantIndex = 1, variantCount = 2}
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

    -- Mock require for json library (needed before loading process)
    package.loaded.json = mockJSON
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

-- Load the character dialogue engine after setting up environment
local function loadCharacterDialogueEngine()
    setupTestEnvironment()
    dofile("processes/character-dialogue-engine.lua")
end

-- Test suite for Character Dialogue Selection
local function testCharacterDialogueSelection()
    local tests = {}

    -- Test 1: Process loads and registers handlers
    tests["test_process_initialization"] = function()
        loadCharacterDialogueEngine()

        -- Check that required handlers are registered
        local requiredHandlers = {
            "get-character-dialogue",
            "select-random-dialogue",
            "get-speaker-name",
            "inject-dialogue-context",
            "validate-personality",
            "list-available-personalities",
            "info"
        }

        for _, handlerName in ipairs(requiredHandlers) do
            assert(testHandlers[handlerName] ~= nil, "Handler should be registered: " .. handlerName)
            assert(type(testHandlers[handlerName].handler) == "function", "Handler should be a function: " .. handlerName)
        end

        print("✓ Process initialization test passed")
        return true
    end

    -- Test 2: GetCharacterDialogue - retrieve all variants
    tests["test_get_all_dialogue_variants"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "50", -- Youngster
            DialoguePhase = "encounter"
        }

        local responses = sendTestMessage("get-character-dialogue", message)

        assert(#responses == 1, "Should send one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Success == "true", "Should indicate success")
        assert(response.DialogueCount ~= nil, "Should include DialogueCount")
        assert(response.Speaker ~= nil, "Should include Speaker")
        assert(response.Data ~= nil, "Should include dialogue data")

        print("✓ Get all dialogue variants test passed")
        return true
    end

    -- Test 3: GetCharacterDialogue - retrieve specific variant by index
    tests["test_get_specific_variant"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "1", -- Ace Trainer
            DialoguePhase = "encounter",
            VariantIndex = "1"
        }

        local responses = sendTestMessage("get-character-dialogue", message)

        assert(#responses == 1, "Should send one response")
        local response = responses[1]
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Success == "true", "Should indicate success")

        print("✓ Get specific variant test passed")
        return true
    end

    -- Test 4: GetCharacterDialogue - invalid trainer type
    tests["test_invalid_trainer_type"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "999", -- Invalid
            DialoguePhase = "encounter"
        }

        local responses = sendTestMessage("get-character-dialogue", message)

        assert(#responses == 1, "Should send one response")
        local response = responses[1]
        assert(response.Action == "Error", "Should send Error")
        assert(response.Error ~= nil, "Should include error message")

        print("✓ Invalid trainer type test passed")
        return true
    end

    -- Test 5: GetCharacterDialogue - missing trainer type
    tests["test_missing_trainer_type"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            DialoguePhase = "encounter"
            -- TrainerType missing
        }

        local responses = sendTestMessage("get-character-dialogue", message)

        assert(#responses == 1, "Should send one response")
        local response = responses[1]
        assert(response.Action == "Error", "Should send Error")
        assert(response.Error ~= nil, "Should include error message")

        print("✓ Missing trainer type test passed")
        return true
    end

    -- Test 6: SelectRandomDialogue - deterministic selection
    tests["test_deterministic_selection"] = function()
        loadCharacterDialogueEngine()

        local seed = "12345"

        -- First request
        local message1 = {
            From = "test-client",
            Action = "SelectRandomDialogue",
            TrainerType = "50", -- Youngster
            DialoguePhase = "encounter",
            Seed = seed
        }

        local responses1 = sendTestMessage("select-random-dialogue", message1)
        local response1 = responses1[1]

        -- Second request with same seed
        local message2 = {
            From = "test-client",
            Action = "SelectRandomDialogue",
            TrainerType = "50",
            DialoguePhase = "encounter",
            Seed = seed
        }

        local responses2 = sendTestMessage("select-random-dialogue", message2)
        local response2 = responses2[1]

        -- Both should return same variant
        assert(response1.Action == "SaveState", "First should send SaveState")
        assert(response2.Action == "SaveState", "Second should send SaveState")
        assert(response1.VariantIndex == response2.VariantIndex, "Should select same variant index")

        print("✓ Deterministic selection test passed")
        return true
    end

    -- Test 7: SelectRandomDialogue - different seeds
    tests["test_different_seeds"] = function()
        loadCharacterDialogueEngine()

        -- First seed
        local message1 = {
            From = "test-client",
            Action = "SelectRandomDialogue",
            TrainerType = "50",
            DialoguePhase = "encounter",
            Seed = "11111"
        }

        local responses1 = sendTestMessage("select-random-dialogue", message1)
        local response1 = responses1[1]

        -- Different seed
        local message2 = {
            From = "test-client",
            Action = "SelectRandomDialogue",
            TrainerType = "50",
            DialoguePhase = "encounter",
            Seed = "99999"
        }

        local responses2 = sendTestMessage("select-random-dialogue", message2)
        local response2 = responses2[1]

        assert(response1.Action == "SaveState", "First should send SaveState")
        assert(response2.Action == "SaveState", "Second should send SaveState")
        assert(response1.VariantIndex ~= nil, "First should have VariantIndex")
        assert(response2.VariantIndex ~= nil, "Second should have VariantIndex")

        print("✓ Different seeds test passed")
        return true
    end

    -- Test 8: SelectRandomDialogue - variants within bounds
    tests["test_variants_within_bounds"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "SelectRandomDialogue",
            TrainerType = "50",
            DialoguePhase = "encounter",
            Seed = "54321"
        }

        local responses = sendTestMessage("select-random-dialogue", message)
        local response = responses[1]

        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Success == "true", "Should indicate success")

        local variantIndex = tonumber(response.VariantIndex)
        local variantCount = tonumber(response.VariantCount)

        -- VariantIndex should be 1-indexed and within bounds
        assert(variantIndex >= 1, "VariantIndex should be >= 1")
        assert(variantIndex <= variantCount, "VariantIndex should be <= VariantCount")

        print("✓ Variants within bounds test passed")
        return true
    end

    -- Test 9: SelectRandomDialogue - invalid trainer type
    tests["test_select_invalid_trainer"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "SelectRandomDialogue",
            TrainerType = "888",
            DialoguePhase = "encounter",
            Seed = "12345"
        }

        local responses = sendTestMessage("select-random-dialogue", message)
        local response = responses[1]

        assert(response.Action == "Error", "Should send Error")

        print("✓ Select invalid trainer test passed")
        return true
    end

    -- Test 10: SelectRandomDialogue - missing seed
    tests["test_missing_seed"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "SelectRandomDialogue",
            TrainerType = "50",
            DialoguePhase = "encounter"
            -- Seed missing
        }

        local responses = sendTestMessage("select-random-dialogue", message)
        local response = responses[1]

        assert(response.Action == "Error", "Should send Error")

        print("✓ Missing seed test passed")
        return true
    end

    -- Test 11: Gender/sub-type variants - Breeder
    tests["test_gender_variants_breeder"] = function()
        loadCharacterDialogueEngine()

        -- Breeder has male/female variants
        local message = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "9", -- Breeder
            DialoguePhase = "encounter"
        }

        local responses = sendTestMessage("get-character-dialogue", message)
        local response = responses[1]

        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Success == "true", "Should indicate success")
        assert(response.Speaker ~= nil, "Should include Speaker")

        print("✓ Gender variants (Breeder) test passed")
        return true
    end

    -- Test 12: Gender/sub-type variants - Youngster/Lass
    tests["test_gender_variants_youngster"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "GetSpeakerName",
            TrainerType = "50", -- Youngster
            VariantIndex = "1" -- Male variant (1-indexed)
        }

        local responses = sendTestMessage("get-speaker-name", message)
        local response = responses[1]

        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Success == "true", "Should indicate success")
        assert(response.SpeakerKey ~= nil, "Should include SpeakerKey")

        print("✓ Gender variants (Youngster/Lass) test passed")
        return true
    end

    -- Test 13: Edge case - single dialogue variant
    tests["test_single_variant"] = function()
        loadCharacterDialogueEngine()

        -- Scientist typically has fewer variants
        local message = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "40", -- Scientist
            DialoguePhase = "encounter"
        }

        local responses = sendTestMessage("get-character-dialogue", message)
        local response = responses[1]

        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.DialogueCount ~= nil, "Should include DialogueCount")

        print("✓ Single variant test passed")
        return true
    end

    -- Test 14: Edge case - missing dialogue phase
    tests["test_missing_phase"] = function()
        loadCharacterDialogueEngine()

        -- Some trainer types may not have defeat dialogue
        local message = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "40", -- Scientist
            DialoguePhase = "defeat"
        }

        local responses = sendTestMessage("get-character-dialogue", message)
        local response = responses[1]

        -- Should either return empty variants or error
        assert(response.Action ~= nil, "Should send a response")

        print("✓ Missing phase test passed")
        return true
    end

    -- Test 15: Edge case - default to encounter phase
    tests["test_default_phase"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "50"
            -- DialoguePhase not specified
        }

        local responses = sendTestMessage("get-character-dialogue", message)
        local response = responses[1]

        -- Should default to encounter phase and succeed
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Success == "true", "Should indicate success")

        print("✓ Default phase test passed")
        return true
    end

    -- Run all tests
    local totalTests = 0
    local passedTests = 0
    local failedTests = 0

    for testName, testFunc in pairs(tests) do
        totalTests = totalTests + 1
        print("\nRunning: " .. testName)

        local success, err = pcall(testFunc)
        if success then
            passedTests = passedTests + 1
        else
            failedTests = failedTests + 1
            print("❌ Test failed: " .. testName)
            print("Error: " .. tostring(err))
        end
    end

    -- Print summary
    print("\n" .. string.rep("=", 60))
    print("Character Dialogue Selection Tests Summary:")
    print("  Total: " .. totalTests)
    print("  Passed: " .. passedTests)
    print("  Failed: " .. failedTests)
    print(string.rep("=", 60))

    return failedTests == 0
end

-- Run the test suite and return results
local success = testCharacterDialogueSelection()

-- Return module with runTests function for test runner compatibility
return {
    runTests = function() return success end
}
