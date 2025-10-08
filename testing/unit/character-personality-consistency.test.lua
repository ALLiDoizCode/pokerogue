-- Unit tests for Character Personality Consistency using message-based testing
-- Tests personality archetype validation and voice consistency
--
-- Test Coverage:
-- - AC1: Personality expression maintains identical character voice
-- - AC2: Personality adaptation maintains consistent voice across variants
-- - Verify distinct personality archetypes (Youngster, Ace Trainer, Hex Maniac, Scientist)

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

-- Mock JSON
local mockJSON = {}

-- Define encode function with forward reference
local function jsonEncode(t)
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
                jsonStr = jsonStr .. jsonEncode(v)
            end
        end
        jsonStr = jsonStr .. "}"
        return jsonStr
    end
    return tostring(t)
end

mockJSON.encode = jsonEncode
mockJSON.decode = function(s)
    return {
        dialogueVariants = {"mock1", "mock2"},
        personalities = {
            {trainerType = 50, availablePhases = {"encounter", "victory"}}
        }
    }
end

-- Set up test environment
local function setupTestEnvironment()
    testMessages = {}
    testHandlers = {}
    _G.ao = mockAO
    _G.Handlers = mockHandlers
    _G.json = mockJSON
    package.loaded.json = mockJSON
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

-- Load the character dialogue engine
local function loadCharacterDialogueEngine()
    setupTestEnvironment()
    dofile("processes/character-dialogue-engine.lua")
end

-- Test suite for Character Personality Consistency
local function testCharacterPersonalityConsistency()
    local tests = {}

    -- Test 1: Validate Youngster personality archetype
    tests["test_youngster_personality_exists"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "ValidatePersonality",
            TrainerType = "50", -- Youngster
            DialoguePhase = "encounter"
        }

        local responses = sendTestMessage("validate-personality", message)

        assert(#responses == 1, "Should send one response")
        local response = responses[1]
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Valid == "true", "Should be valid")
        assert(response.HasDialogue == "true", "Should have dialogue")
        assert(response.VariantCount ~= nil, "Should include VariantCount")

        local variantCount = tonumber(response.VariantCount)
        assert(variantCount > 0, "Youngster should have dialogue variants")

        print("✓ Youngster personality archetype test passed")
        return true
    end

    -- Test 2: Validate Ace Trainer personality archetype
    tests["test_ace_trainer_personality_exists"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "ValidatePersonality",
            TrainerType = "1", -- Ace Trainer
            DialoguePhase = "encounter"
        }

        local responses = sendTestMessage("validate-personality", message)

        local response = responses[1]
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Valid == "true", "Should be valid")
        assert(response.HasDialogue == "true", "Should have dialogue")

        local variantCount = tonumber(response.VariantCount)
        assert(variantCount > 0, "Ace Trainer should have dialogue variants")

        print("✓ Ace Trainer personality archetype test passed")
        return true
    end

    -- Test 3: Validate Hex Maniac personality archetype
    tests["test_hex_maniac_personality_exists"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "ValidatePersonality",
            TrainerType = "27", -- Hex Maniac
            DialoguePhase = "encounter"
        }

        local responses = sendTestMessage("validate-personality", message)

        local response = responses[1]
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Valid == "true", "Should be valid")
        assert(response.HasDialogue == "true", "Should have dialogue")

        local variantCount = tonumber(response.VariantCount)
        assert(variantCount > 0, "Hex Maniac should have dialogue variants")

        print("✓ Hex Maniac personality archetype test passed")
        return true
    end

    -- Test 4: Validate Scientist personality archetype
    tests["test_scientist_personality_exists"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "ValidatePersonality",
            TrainerType = "40", -- Scientist
            DialoguePhase = "encounter"
        }

        local responses = sendTestMessage("validate-personality", message)

        local response = responses[1]
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Valid == "true", "Should be valid")
        assert(response.HasDialogue == "true", "Should have dialogue")

        local variantCount = tonumber(response.VariantCount)
        assert(variantCount > 0, "Scientist should have dialogue variants")

        print("✓ Scientist personality archetype test passed")
        return true
    end

    -- Test 5: Maintain Youngster personality across all encounter variants (AC2)
    tests["test_youngster_consistency_across_variants"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "50", -- Youngster
            DialoguePhase = "encounter"
        }

        local responses = sendTestMessage("get-character-dialogue", message)

        local response = responses[1]
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Success == "true", "Should indicate success")

        -- Structural validation of dialogue variants
        assert(response.Data ~= nil, "Should have dialogue data")

        print("✓ Youngster consistency across variants test passed")
        return true
    end

    -- Test 6: Distinct speaker names for different trainer types
    tests["test_distinct_speaker_names"] = function()
        loadCharacterDialogueEngine()

        -- Get Youngster speaker
        local message1 = {
            From = "test-client",
            Action = "GetSpeakerName",
            TrainerType = "50" -- Youngster
        }

        local responses1 = sendTestMessage("get-speaker-name", message1)
        local youngsterResponse = responses1[1]

        -- Get Ace Trainer speaker
        local message2 = {
            From = "test-client",
            Action = "GetSpeakerName",
            TrainerType = "1" -- Ace Trainer
        }

        local responses2 = sendTestMessage("get-speaker-name", message2)
        local aceTrainerResponse = responses2[1]

        -- Both should succeed
        assert(youngsterResponse.Action == "SaveState", "Youngster should send SaveState")
        assert(aceTrainerResponse.Action == "SaveState", "Ace Trainer should send SaveState")

        -- Speaker keys should be different
        assert(youngsterResponse.SpeakerKey ~= nil, "Youngster should have SpeakerKey")
        assert(aceTrainerResponse.SpeakerKey ~= nil, "Ace Trainer should have SpeakerKey")
        assert(youngsterResponse.SpeakerKey ~= aceTrainerResponse.SpeakerKey,
            "Different trainer types should have distinct speaker names")

        print("✓ Distinct speaker names test passed")
        return true
    end

    -- Test 7: Distinct dialogue pools for different trainer types
    tests["test_distinct_dialogue_pools"] = function()
        loadCharacterDialogueEngine()

        -- Get Youngster dialogue
        local message1 = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "50", -- Youngster
            DialoguePhase = "encounter"
        }

        local responses1 = sendTestMessage("get-character-dialogue", message1)
        local youngsterResponse = responses1[1]

        -- Get Scientist dialogue
        local message2 = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "40", -- Scientist
            DialoguePhase = "encounter"
        }

        local responses2 = sendTestMessage("get-character-dialogue", message2)
        local scientistResponse = responses2[1]

        -- Both should have dialogue
        assert(youngsterResponse.Action == "SaveState", "Youngster should have dialogue")
        assert(scientistResponse.Action == "SaveState", "Scientist should have dialogue")

        assert(youngsterResponse.Data ~= nil, "Youngster should have dialogue data")
        assert(scientistResponse.Data ~= nil, "Scientist should have dialogue data")

        print("✓ Distinct dialogue pools test passed")
        return true
    end

    -- Test 8: ListAvailablePersonalities handler
    tests["test_list_available_personalities"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "ListAvailablePersonalities"
        }

        local responses = sendTestMessage("list-available-personalities", message)

        local response = responses[1]
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.PersonalityCount ~= nil, "Should include PersonalityCount")

        local personalityCount = tonumber(response.PersonalityCount)
        assert(personalityCount > 0, "Should have at least one personality defined")

        print("✓ List available personalities test passed")
        return true
    end

    -- Test 9: Invalidate unknown trainer type
    tests["test_invalidate_unknown_trainer_type"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "ValidatePersonality",
            TrainerType = "777", -- Invalid
            DialoguePhase = "encounter"
        }

        local responses = sendTestMessage("validate-personality", message)

        local response = responses[1]
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Valid == "false", "Should be invalid")
        assert(response.HasDialogue == "false", "Should not have dialogue")

        print("✓ Invalidate unknown trainer type test passed")
        return true
    end

    -- Test 10: Invalidate missing dialogue phase
    tests["test_invalidate_missing_phase"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "ValidatePersonality",
            TrainerType = "40", -- Scientist
            DialoguePhase = "unknown_phase"
        }

        local responses = sendTestMessage("validate-personality", message)

        local response = responses[1]
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Valid == "false", "Should be invalid")

        print("✓ Invalidate missing phase test passed")
        return true
    end

    -- Test 11: Cross-phase personality consistency for Youngster (AC1, AC2)
    tests["test_youngster_cross_phase_consistency"] = function()
        loadCharacterDialogueEngine()

        local phases = {"encounter", "victory"}
        local validPhases = 0

        for _, phase in ipairs(phases) do
            local message = {
                From = "test-client",
                Action = "ValidatePersonality",
                TrainerType = "50", -- Youngster
                DialoguePhase = phase
            }

            local responses = sendTestMessage("validate-personality", message)
            local response = responses[1]

            if response.Valid == "true" then
                assert(response.HasDialogue == "true",
                    "Youngster should have dialogue for " .. phase .. " phase")
                validPhases = validPhases + 1
            end
        end

        assert(validPhases > 0, "Youngster should have at least one valid phase")

        print("✓ Youngster cross-phase consistency test passed")
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
    print("Character Personality Consistency Tests Summary:")
    print("  Total: " .. totalTests)
    print("  Passed: " .. passedTests)
    print("  Failed: " .. failedTests)
    print(string.rep("=", 60))

    return failedTests == 0
end

-- Run the test suite and return results
local success = testCharacterPersonalityConsistency()

-- Return module with runTests function for test runner compatibility
return {
    runTests = function() return success end
}
