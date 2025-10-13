-- Specific Test for GetSpecies Handler: Abra (Name) and ID 63
-- Uses the existing aolite testing framework

-- Mock environment setup (matches existing test pattern)
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local mockAO = {
    id = "test-pokemon-species-db",
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
        hasMatchingTag = function(tag, values)
            return function(msg)
                if type(values) == "table" then
                    for _, value in ipairs(values) do
                        if msg[tag] == value then
                            return true
                        end
                    end
                    return false
                else
                    return msg[tag] == values
                end
            end
        end
    }
}

-- Mock JSON
local mockJSON = {
    encode = function(t)
        if type(t) == "table" then
            return "mock_json_encoded"
        end
        return tostring(t)
    end,
    decode = function(s)
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
end

-- Helper function to send a test message to a handler
local function sendTestMessage(handlerName, message)
    local handler = testHandlers[handlerName]
    if not handler then
        error("Handler not found: " .. handlerName)
    end

    -- Check if message matches the handler's matcher
    if not handler.matcher(message) then
        error("Message does not match handler pattern for " .. handlerName)
    end

    -- Clear previous messages
    testMessages = {}

    -- Execute handler
    handler.handler(message)

    -- Return sent messages
    return testMessages
end

-- Load the pokemon species database after setting up environment
local function loadPokemonSpeciesDB()
    setupTestEnvironment()
    dofile("processes/pokemon-species-db.lua")
end

-- Test GetSpecies Handler with Abra and ID 63
local function testAbraAndId63()
    print("=" .. string.rep("=", 70))
    print("Testing GetSpecies Handler: Abra (Name) and ID 63")
    print("=" .. string.rep("=", 70))

    -- Load the process
    loadPokemonSpeciesDB()

    local tests = {}

    -- Test 1: GetSpecies with SpeciesName "Abra"
    tests["test_get_species_by_name_abra"] = function()
        print("\n🧪 TEST 1: GetSpecies with SpeciesName = 'Abra'")
        print("-" .. string.rep("-", 50))

        local abraNameMessage = {
            From = "test-client-abra-name",
            Action = "GetSpecies",
            SpeciesName = "Abra",
            Timestamp = 1234567890
        }

        print("📤 Sending message:")
        print("  From: " .. abraNameMessage.From)
        print("  Action: " .. abraNameMessage.Action)
        print("  SpeciesName: " .. abraNameMessage.SpeciesName)

        local responses = sendTestMessage("get-species", abraNameMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]

        print("\n📥 Response received:")
        print("  Target: " .. (response.Target or "nil"))
        print("  Action: " .. (response.Action or "nil"))
        print("  SpeciesId: " .. (response.SpeciesId or "nil"))
        print("  SpeciesName: " .. (response.SpeciesName or "nil"))
        print("  Generation: " .. (response.Generation or "nil"))
        print("  Type1: " .. (response.Type1 or "nil"))
        print("  Type2: " .. (response.Type2 or ""))
        print("  HP: " .. (response.HP or "nil"))
        print("  Attack: " .. (response.Attack or "nil"))
        print("  Defense: " .. (response.Defense or "nil"))
        print("  SpecialAttack: " .. (response.SpecialAttack or "nil"))
        print("  SpecialDefense: " .. (response.SpecialDefense or "nil"))
        print("  Speed: " .. (response.Speed or "nil"))

        if response.Error then
            print("  ❌ Error: " .. response.Error)
        else
            print("  ✅ Success: Species data retrieved")
        end

        -- Verify response structure
        assert(response.Target == "test-client-abra-name", "Should respond to sender")
        assert(response.Action == "SaveState", "Should have SaveState action")

        if not response.Error then
            -- If successful, verify Abra data
            assert(response.SpeciesName == "Abra", "Should return Abra as species name")
            assert(response.SpeciesId == "63", "Should return 63 as species ID")
            assert(response.Type1 == "14", "Abra should be Psychic type (14)")
        end

        print("✅ GetSpecies by name 'Abra' test passed")
        return true
    end

    -- Test 2: GetSpecies with SpeciesId "63"
    tests["test_get_species_by_id_63"] = function()
        print("\n🧪 TEST 2: GetSpecies with SpeciesId = '63'")
        print("-" .. string.rep("-", 50))

        local abraIdMessage = {
            From = "test-client-abra-id",
            Action = "GetSpecies",
            SpeciesId = "63",
            Timestamp = 1234567890
        }

        print("📤 Sending message:")
        print("  From: " .. abraIdMessage.From)
        print("  Action: " .. abraIdMessage.Action)
        print("  SpeciesId: " .. abraIdMessage.SpeciesId)

        local responses = sendTestMessage("get-species", abraIdMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]

        print("\n📥 Response received:")
        print("  Target: " .. (response.Target or "nil"))
        print("  Action: " .. (response.Action or "nil"))
        print("  SpeciesId: " .. (response.SpeciesId or "nil"))
        print("  SpeciesName: " .. (response.SpeciesName or "nil"))
        print("  Generation: " .. (response.Generation or "nil"))
        print("  Type1: " .. (response.Type1 or "nil"))
        print("  Type2: " .. (response.Type2 or ""))
        print("  HP: " .. (response.HP or "nil"))
        print("  Attack: " .. (response.Attack or "nil"))
        print("  Defense: " .. (response.Defense or "nil"))
        print("  SpecialAttack: " .. (response.SpecialAttack or "nil"))
        print("  SpecialDefense: " .. (response.SpecialDefense or "nil"))
        print("  Speed: " .. (response.Speed or "nil"))

        if response.Error then
            print("  ❌ Error: " .. response.Error)
        else
            print("  ✅ Success: Species data retrieved")
        end

        -- Verify response structure
        assert(response.Target == "test-client-abra-id", "Should respond to sender")
        assert(response.Action == "SaveState", "Should have SaveState action")

        if not response.Error then
            -- If successful, verify Abra data
            assert(response.SpeciesId == "63", "Should return 63 as species ID")
            assert(response.SpeciesName == "Abra", "Should return Abra as species name")
            assert(response.Type1 == "14", "Abra should be Psychic type (14)")
        end

        print("✅ GetSpecies by ID '63' test passed")
        return true
    end

    -- Test 3: Using alternative tag names (Name instead of SpeciesName)
    tests["test_get_species_alternative_tags"] = function()
        print("\n🧪 TEST 3: GetSpecies with alternative tag 'Name' = 'Abra'")
        print("-" .. string.rep("-", 50))

        local abraAltMessage = {
            From = "test-client-abra-alt",
            Action = "GetSpecies",
            Name = "Abra",  -- Alternative tag name
            Timestamp = 1234567890
        }

        print("📤 Sending message:")
        print("  From: " .. abraAltMessage.From)
        print("  Action: " .. abraAltMessage.Action)
        print("  Name: " .. abraAltMessage.Name)

        local responses = sendTestMessage("get-species", abraAltMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]

        print("\n📥 Response received:")
        print("  Target: " .. (response.Target or "nil"))
        print("  Action: " .. (response.Action or "nil"))
        print("  SpeciesId: " .. (response.SpeciesId or "nil"))
        print("  SpeciesName: " .. (response.SpeciesName or "nil"))

        if response.Error then
            print("  ❌ Error: " .. response.Error)
        else
            print("  ✅ Success: Species data retrieved")
        end

        -- Verify response structure
        assert(response.Target == "test-client-abra-alt", "Should respond to sender")
        assert(response.Action == "SaveState", "Should have SaveState action")

        print("✅ GetSpecies with alternative tag test passed")
        return true
    end

    -- Test 4: Using alternative tag names (Id instead of SpeciesId)
    tests["test_get_species_alternative_id_tag"] = function()
        print("\n🧪 TEST 4: GetSpecies with alternative tag 'Id' = '63'")
        print("-" .. string.rep("-", 50))

        local abraAltIdMessage = {
            From = "test-client-abra-alt-id",
            Action = "GetSpecies",
            Id = "63",  -- Alternative tag name
            Timestamp = 1234567890
        }

        print("📤 Sending message:")
        print("  From: " .. abraAltIdMessage.From)
        print("  Action: " .. abraAltIdMessage.Action)
        print("  Id: " .. abraAltIdMessage.Id)

        local responses = sendTestMessage("get-species", abraAltIdMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]

        print("\n📥 Response received:")
        print("  Target: " .. (response.Target or "nil"))
        print("  Action: " .. (response.Action or "nil"))
        print("  SpeciesId: " .. (response.SpeciesId or "nil"))
        print("  SpeciesName: " .. (response.SpeciesName or "nil"))

        if response.Error then
            print("  ❌ Error: " .. response.Error)
        else
            print("  ✅ Success: Species data retrieved")
        end

        -- Verify response structure
        assert(response.Target == "test-client-abra-alt-id", "Should respond to sender")
        assert(response.Action == "SaveState", "Should have SaveState action")

        print("✅ GetSpecies with alternative Id tag test passed")
        return true
    end

    return tests
end

-- Run the tests
local function runTests()
    local tests = testAbraAndId63()
    local passed = 0
    local failed = 0

    for testName, testFunc in pairs(tests) do
        local success, error = pcall(testFunc)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("❌ " .. testName .. " FAILED: " .. tostring(error))
        end
    end

    print("\n" .. string.rep("=", 70))
    print("🏁 FINAL TEST RESULTS")
    print(string.rep("=", 70))
    print("  ✅ Passed: " .. passed)
    print("  ❌ Failed: " .. failed)
    print("  📊 Total:  " .. (passed + failed))

    if failed == 0 then
        print("\n🎉 All Abra and ID 63 tests passed!")
        return true
    else
        print("\n💥 Some tests failed!")
        return false
    end
end

-- Run the test
return runTests()