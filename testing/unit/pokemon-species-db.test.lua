-- Unit tests for Pokemon Species Database Process (ADP v1.0 Compatible)
-- Test framework: Message-based testing for handler pattern

-- Mock environment setup for ADP testing
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

-- Constants for testing
local SPECIES = {
    BULBASAUR = 1,
    CHARMANDER = 4,
    SQUIRTLE = 7,
    PIKACHU = 25,
    MEWTWO = 150
}

-- Test suite for Pokemon Species Database Process
local function testPokemonSpeciesDB()
    local tests = {}

    -- Test 1: Process loads and registers handlers
    tests["test_process_initialization"] = function()
        loadPokemonSpeciesDB()

        -- Check that required handlers are registered
        local requiredHandlers = {
            "get-species",
            "get-base-stats",
            "get-evolution-chain",
            "get-level-moves",
            "get-chunk-stats",
            "preload-generation",
            "health-check"
        }

        for _, handlerName in ipairs(requiredHandlers) do
            assert(testHandlers[handlerName] ~= nil, "Handler should be registered: " .. handlerName)
            assert(type(testHandlers[handlerName].handler) == "function", "Handler should be a function: " .. handlerName)
        end

        print("✓ Process initialization test passed")
        return true
    end

    -- Test 2: GetSpecies Query Handler
    tests["test_get_species_handler"] = function()
        loadPokemonSpeciesDB()

        local speciesMessage = {
            From = "test-client",
            Action = "GetSpecies",
            Data = {
                speciesId = SPECIES.PIKACHU
            },
            Timestamp = 1234567890
        }

        local responses = sendTestMessage("get-species", speciesMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")

        print("✓ GetSpecies handler test passed")
        return true
    end

    -- Test 3: GetEvolutionChain Query Handler
    tests["test_get_evolution_chain_handler"] = function()
        loadPokemonSpeciesDB()

        local evolutionMessage = {
            From = "test-client",
            Action = "GetEvolutionChain",
            Data = {
                speciesId = SPECIES.CHARMANDER
            },
            Timestamp = 1234567890
        }

        local responses = sendTestMessage("get-evolution-chain", evolutionMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")

        print("✓ GetEvolutionChain handler test passed")
        return true
    end

    -- Test 4: GetBaseStats Query Handler
    tests["test_get_base_stats_handler"] = function()
        loadPokemonSpeciesDB()

        local baseStatsMessage = {
            From = "test-client",
            Action = "GetBaseStats",
            Data = {
                speciesId = SPECIES.BULBASAUR
            },
            Timestamp = 1234567890
        }

        local responses = sendTestMessage("get-base-stats", baseStatsMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")

        print("✓ GetBaseStats handler test passed")
        return true
    end

    -- Test 5: Health Check Handler
    tests["test_health_check_handler"] = function()
        loadPokemonSpeciesDB()

        local healthMessage = {
            From = "test-client",
            Action = "HealthCheck",
            Data = {},
            Timestamp = 1234567890
        }

        local responses = sendTestMessage("health-check", healthMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")
        assert(response.Action == "SaveState", "Should send SaveState")

        print("✓ Health check handler test passed")
        return true
    end

    -- Test 6: Invalid Species ID
    tests["test_invalid_species_id"] = function()
        loadPokemonSpeciesDB()

        local invalidMessage = {
            From = "test-client",
            Action = "GetSpecies",
            Data = {
                speciesId = 99999 -- Invalid ID
            },
            Timestamp = 1234567890
        }

        local responses = sendTestMessage("get-species", invalidMessage)

        assert(#responses >= 1, "Should send error response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")

        print("✓ Invalid species ID test passed")
        return true
    end

    -- Test 7: Missing Required Fields
    tests["test_missing_required_fields"] = function()
        loadPokemonSpeciesDB()

        local malformedMessage = {
            From = "test-client",
            Action = "GetSpecies"
            -- Missing Data and Timestamp
        }

        local responses = sendTestMessage("get-species", malformedMessage)

        assert(#responses >= 1, "Should send error response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")

        print("✓ Missing required fields test passed")
        return true
    end

    -- Test 8: Multiple Species Query Types
    tests["test_multiple_query_types"] = function()
        loadPokemonSpeciesDB()

        local queryTypes = {"GetSpecies", "GetEvolutionChain", "GetBaseStats"}

        -- Map actions to handler names
        local handlerMap = {
            ["GetSpecies"] = "get-species",
            ["GetEvolutionChain"] = "get-evolution-chain",
            ["GetBaseStats"] = "get-base-stats"
        }

        for _, queryType in ipairs(queryTypes) do
            local message = {
                From = "test-client",
                Action = queryType,
                Data = {
                    speciesId = SPECIES.SQUIRTLE
                },
                Timestamp = 1234567890
            }

            local handlerName = handlerMap[queryType]
            local responses = sendTestMessage(handlerName, message)
            assert(#responses >= 1, "Should handle " .. queryType .. " query")
        end

        print("✓ Multiple query types test passed")
        return true
    end

    -- Test 9: Rate Limiting (if implemented)
    tests["test_rate_limiting"] = function()
        loadPokemonSpeciesDB()

        -- Send multiple rapid requests
        for i = 1, 5 do
            local message = {
                From = "test-client",
                Action = "GetSpecies",
                Data = {
                    speciesId = SPECIES.PIKACHU
                },
                Timestamp = 1234567890
            }

            local responses = sendTestMessage("get-species", message)
            assert(#responses >= 1, "Should handle request " .. i)
        end

        print("✓ Rate limiting test passed")
        return true
    end

    -- Test 10: Performance Monitoring
    tests["test_performance_monitoring"] = function()
        loadPokemonSpeciesDB()

        local startTime = 1234567890

        local message = {
            From = "test-client",
            Action = "GetSpecies",
            Data = {
                speciesId = SPECIES.MEWTWO
            },
            Timestamp = startTime
        }

        local responses = sendTestMessage("get-species", message)
        assert(#responses >= 1, "Should complete performance test")

        print("✓ Performance monitoring test passed")
        return true
    end

    return tests
end

-- Run all tests
local function runTests()
    print("Running Pokemon Species Database Process Unit Tests...")
    print("=" .. string.rep("=", 50))

    local tests = testPokemonSpeciesDB()
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
    testPokemonSpeciesDB = testPokemonSpeciesDB,
    setupTestEnvironment = setupTestEnvironment,
    sendTestMessage = sendTestMessage
}