-- Unit Tests for Modifier Engine
-- Tests modifier generation, application, and validation

local testSuite = {
    processPath = 'processes/modifier-engine.lua',
    processId = 'modifier-engine-test',
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
    print("\n=== MODIFIER ENGINE TESTS ===\n")

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
        "get-modifier-info",
        "generate-modifier-options",
        "apply-modifier",
        "validate-modifier",
        "ping"
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

    -- Test 2: Ping handler
    print("\nTest 2: Ping Handler")
    _G.sent_messages = {}
    local msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "Ping"
    }

    if _G.Handlers["ping"] then
        _G.Handlers["ping"].handler(msg)

        if #_G.sent_messages > 0 then
            local response = _G.sent_messages[1]
            if response.Action == "Pong" and response.Target == msg.From then
                print("  ✓ Ping response correct")
                passed = passed + 1
            else
                print("  ✗ Ping response incorrect")
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

    -- Test 3: Get modifier info
    print("\nTest 3: Get Modifier Info")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "GetModifierInfo",
        ModifierId = "SHINY_CHARM"
    }

    if _G.Handlers["get-modifier-info"] then
        _G.Handlers["get-modifier-info"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Modifier info response sent")
            passed = passed + 1
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 4: Generate modifier options
    print("\nTest 4: Generate Modifier Options")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "GenerateModifierOptions",
        ModifierTier = "COMMON",
        Count = "3"
    }

    if _G.Handlers["generate-modifier-options"] then
        _G.Handlers["generate-modifier-options"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Options generated")
            passed = passed + 1
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 5: Apply modifier
    print("\nTest 5: Apply Modifier")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "ApplyModifier",
        ModifierId = "HP_UP",
        PokemonId = "1"
    }

    if _G.Handlers["apply-modifier"] then
        _G.Handlers["apply-modifier"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Modifier applied")
            passed = passed + 1
        else
            print("  ✗ No response")
            failed = failed + 1
        end
    else
        print("  ✗ Handler not found")
        failed = failed + 1
    end

    -- Test 6: Validate modifier
    print("\nTest 6: Validate Modifier")
    _G.sent_messages = {}
    msg = {
        From = "test_sender",
        Timestamp = "1734800000",
        Action = "ValidateModifier",
        ModifierId = "SHINY_CHARM",
        Context = "battle"
    }

    if _G.Handlers["validate-modifier"] then
        _G.Handlers["validate-modifier"].handler(msg)

        if #_G.sent_messages > 0 then
            print("  ✓ Validation complete")
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
