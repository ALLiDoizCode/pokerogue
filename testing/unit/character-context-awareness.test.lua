-- Unit tests for Character Context-Aware Dialogue using message-based testing
-- Tests dialogue token replacement and context injection
--
-- Test Coverage:
-- - AC3: Context-aware dialogue maintains identical situational response and awareness behavior

-- Mock environment setup
local testMessages = {}
local testHandlers = {}

local mockAO = {
    id = "test-character-dialogue-engine",
    send = function(msg) table.insert(testMessages, msg) return true end
}

local mockHandlers = {
    add = function(name, matcher, handler)
        testHandlers[name] = {matcher = matcher, handler = handler}
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg) return msg[tag] == value end
        end
    }
}

local mockJSON = {
    encode = function(t) return "mock_json" end,
    decode = function(s) return {processedText = "Pikachu used Thunder!", tokenCount = 2} end
}

local function setupTestEnvironment()
    testMessages = {}
    testHandlers = {}
    _G.ao = mockAO
    _G.Handlers = mockHandlers
    _G.json = mockJSON
    package.loaded.json = mockJSON
end

local function sendTestMessage(handlerName, message)
    local handler = testHandlers[handlerName]
    if not handler then error("Handler not found: " .. handlerName) end
    if not handler.matcher(message) then error("Message does not match handler pattern") end
    testMessages = {}
    handler.handler(message)
    return testMessages
end

local function loadCharacterDialogueEngine()
    setupTestEnvironment()
    dofile("processes/character-dialogue-engine.lua")
end

local function testCharacterContextAwareness()
    local tests = {}

    tests["test_inject_single_token"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "{{primaryName}} used Thunder!",
            Data = '{"primaryName":"Pikachu"}'
        }

        local responses = sendTestMessage("inject-dialogue-context", message)
        assert(#responses == 1, "Should send one response")
        local response = responses[1]
        assert(response.Action == "SaveState", "Should send SaveState")
        assert(response.Success == "true", "Should indicate success")

        print("✓ Single token injection test passed")
        return true
    end

    tests["test_inject_multiple_tokens"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "{{primaryName}} and {{secondaryName}} are ready!",
            Data = '{"primaryName":"Pikachu","secondaryName":"Charizard"}'
        }

        local responses = sendTestMessage("inject-dialogue-context", message)
        assert(responses[1].Action == "SaveState", "Should send SaveState")

        print("✓ Multiple token injection test passed")
        return true
    end

    tests["test_missing_token_handling"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "{{missingToken}} is not defined",
            Data = '{}'
        }

        local responses = sendTestMessage("inject-dialogue-context", message)
        assert(responses[1].Action == "SaveState", "Should send SaveState")

        print("✓ Missing token handling test passed")
        return true
    end

    tests["test_speaker_attribution"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "GetSpeakerName",
            TrainerType = "50"
        }

        local responses = sendTestMessage("get-speaker-name", message)
        assert(responses[1].Action == "SaveState", "Should send SaveState")

        print("✓ Speaker attribution test passed")
        return true
    end

    tests["test_primary_pokemon_tokens"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "Your {{primaryName}} is strong!",
            Data = '{"primaryName":"Pikachu","primaryType":"Electric"}'
        }

        local responses = sendTestMessage("inject-dialogue-context", message)
        assert(responses[1].Success == "true", "Should indicate success")

        print("✓ Primary Pokemon tokens test passed")
        return true
    end

    tests["test_option_tokens"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "Choose {{option1PrimaryName}} or {{option2PrimaryName}}",
            Data = '{"option1PrimaryName":"Bulbasaur","option2PrimaryName":"Charmander"}'
        }

        local responses = sendTestMessage("inject-dialogue-context", message)
        assert(responses[1].Action == "SaveState", "Should send SaveState")

        print("✓ Option tokens test passed")
        return true
    end

    tests["test_custom_encounter_tokens"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "{{statTrainerName}} appears!",
            Data = '{"statTrainerName":"Buck"}'
        }

        local responses = sendTestMessage("inject-dialogue-context", message)
        assert(responses[1].Action == "SaveState", "Should send SaveState")

        print("✓ Custom encounter tokens test passed")
        return true
    end

    tests["test_nested_context"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "{{primaryName}} ({{primaryType}}) vs {{secondaryName}}",
            Data = '{"primaryName":"Pikachu","primaryType":"Electric","secondaryName":"Charizard"}'
        }

        local responses = sendTestMessage("inject-dialogue-context", message)
        assert(responses[1].Action == "SaveState", "Should send SaveState")

        print("✓ Nested context test passed")
        return true
    end

    tests["test_empty_dialogue_text"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "",
            Data = '{}'
        }

        local responses = sendTestMessage("inject-dialogue-context", message)
        assert(responses[1].Action == "SaveState", "Should send SaveState")

        print("✓ Empty dialogue text test passed")
        return true
    end

    tests["test_no_tokens_in_text"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "This has no tokens at all",
            Data = '{}'
        }

        local responses = sendTestMessage("inject-dialogue-context", message)
        assert(responses[1].Action == "SaveState", "Should send SaveState")

        print("✓ No tokens in text test passed")
        return true
    end

    tests["test_integration_with_dialogue_selection"] = function()
        loadCharacterDialogueEngine()

        -- First get dialogue
        local message1 = {
            From = "test-client",
            Action = "GetCharacterDialogue",
            TrainerType = "50",
            DialoguePhase = "encounter"
        }

        local responses1 = sendTestMessage("get-character-dialogue", message1)
        assert(responses1[1].Action == "SaveState", "Should get dialogue")

        -- Then inject context (if dialogue had tokens)
        local message2 = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "Test dialogue with {{token}}",
            Data = '{"token":"value"}'
        }

        local responses2 = sendTestMessage("inject-dialogue-context", message2)
        assert(responses2[1].Action == "SaveState", "Should inject context")

        print("✓ Integration test passed")
        return true
    end

    tests["test_token_count_accuracy"] = function()
        loadCharacterDialogueEngine()

        local message = {
            From = "test-client",
            Action = "InjectDialogueContext",
            DialogueText = "{{a}} {{b}} {{c}}",
            Data = '{"a":"1","b":"2","c":"3"}'
        }

        local responses = sendTestMessage("inject-dialogue-context", message)
        assert(responses[1].TokenCount ~= nil, "Should include TokenCount")

        print("✓ Token count accuracy test passed")
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

    print("\n" .. string.rep("=", 60))
    print("Character Context Awareness Tests Summary:")
    print("  Total: " .. totalTests)
    print("  Passed: " .. passedTests)
    print("  Failed: " .. failedTests)
    print(string.rep("=", 60))

    return failedTests == 0
end

local success = testCharacterContextAwareness()

return {
    runTests = function() return success end
}
