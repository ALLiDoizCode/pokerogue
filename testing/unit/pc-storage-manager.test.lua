-- PC Storage Manager Unit Tests
-- Tests all storage operations, party management, and validation functionality

-- Mock JSON for testing
local mockJSON = {
    encode = function(t)
        if type(t) == "table" then
            return "mock_json_encoded"
        end
        return tostring(t)
    end,
    decode = function(s)
        if s == "mock_json_encoded" then
            return {}
        end
        return {}
    end
}

-- Mock AO environment
local MockAO = {
    messages = {},
    id = "test_pc_storage_manager_process_id"
}

function MockAO.send(message)
    table.insert(MockAO.messages, message)
end

function MockAO.clearMessages()
    MockAO.messages = {}
end

-- Setup test environment
ao = MockAO
json = mockJSON
Handlers = {
    add = function(name, matcher, handler)
        print("Handler registered:", name)
        -- Store handler for testing
        if not Handlers._registry then
            Handlers._registry = {}
        end
        Handlers._registry[name] = {
            matcher = matcher,
            handler = handler
        }
    end,
    utils = {
        hasMatchingTag = function(tagName, tagValue)
            return function(msg)
                return msg[tagName] == tagValue or (msg.Tags and msg.Tags[tagName] == tagValue)
            end
        end
    }
}

-- Load the PC Storage Manager process
dofile("processes/pc-storage-manager.lua")

-- Test utilities
local TestUtils = {}

function TestUtils.createMockMessage(action, from, data, tags)
    local msg = {
        Action = action,
        From = from or "test_player_wallet_address",
        Timestamp = "1734567890000", -- Fixed timestamp for deterministic testing
        Data = data and json.encode(data) or "",
        Tags = tags or {}
    }
    
    -- Add tag-level properties
    if tags then
        for key, value in pairs(tags) do
            msg[key] = value
        end
    end
    
    return msg
end

function TestUtils.executeHandler(handlerName, msg)
    MockAO.clearMessages()
    local handler = Handlers._registry[handlerName]
    if handler and handler.handler then
        handler.handler(msg)
    end
    return MockAO.messages
end

function TestUtils.assertResponseSuccess(responses, expectedAction)
    assert(#responses > 0, "No response received")
    local response = responses[1]
    assert(response.Success == "true", "Response not successful: " .. (response.Error or "unknown error"))
    if expectedAction then
        assert(response.Action == expectedAction, "Expected action " .. expectedAction .. " but got " .. response.Action)
    end
    return response
end

function TestUtils.assertResponseError(responses, expectedError)
    assert(#responses > 0, "No response received")
    local response = responses[1]
    assert(response.Success == "false" or response.Action == "Error", "Expected error response")
    if expectedError then
        assert(response.Error and string.find(response.Error, expectedError), 
               "Expected error containing '" .. expectedError .. "' but got: " .. (response.Error or "none"))
    end
    return response
end

-- Test Suite
local TestSuite = {}

function TestSuite.testProcessInitialization()
    print("Testing: Process Initialization")
    
    -- Test Info handler
    local msg = TestUtils.createMockMessage("Info", "test_requester")
    local responses = TestUtils.executeHandler("info", msg)
    
    local response = TestUtils.assertResponseSuccess(responses, "SaveState")
    local data = json.decode(response.Data)
    
    assert(data.name == "PC Storage Manager", "Process name incorrect")
    assert(data.adpVersion == "1.0", "ADP version incorrect")
    assert(#data.capabilities > 0, "No capabilities listed")
    assert(#data.handlers > 0, "No handlers listed")
    
    print("✓ Process initialization successful")
end

function TestSuite.testPingHandler()
    print("Testing: Ping Handler")
    
    local msg = TestUtils.createMockMessage("Ping", "test_requester")
    local responses = TestUtils.executeHandler("ping", msg)
    
    assert(#responses > 0, "No ping response")
    local response = responses[1]
    assert(response.Action == "Pong", "Expected Pong response")
    assert(response.Data == "pong", "Expected pong data")
    
    print("✓ Ping handler working")
end

function TestSuite.testPlayerStorageInitialization()
    print("Testing: Player Storage Initialization")
    
    local msg = TestUtils.createMockMessage("ProcessLogic", "test_player_1", nil, {
        Operation = "validateIntegrity"
    })
    local responses = TestUtils.executeHandler("processLogic", msg)
    
    local response = TestUtils.assertResponseSuccess(responses, "SaveState")
    local data = json.decode(response.Data)
    
    assert(data.storageState ~= nil, "Storage state not initialized")
    assert(data.storageState.pcStorage ~= nil, "PC storage not initialized")
    assert(data.storageState.party ~= nil, "Party not initialized")
    assert(data.storageState.storageMetadata ~= nil, "Storage metadata not initialized")
    
    -- Validate PC storage structure
    assert(data.storageState.pcStorage.totalBoxes == 30, "Expected 30 boxes")
    assert(data.storageState.pcStorage.maxBoxCapacity == 30, "Expected 30 slots per box")
    assert(data.storageState.pcStorage.maxTotalCapacity == 900, "Expected 900 total capacity")
    
    -- Validate party structure
    assert(data.storageState.party.maxPartySize == 6, "Expected max party size of 6")
    assert(data.storageState.party.totalActive == 0, "Expected empty party initially")
    assert(data.storageState.party.leadPokemon == 1, "Expected lead Pokemon position 1")
    
    print("✓ Player storage initialization successful")
end

function TestSuite.testDepositPokemon()
    print("Testing: Pokemon Deposit Operations")
    
    local playerId = "test_player_deposit"
    
    -- Test successful deposit
    local msg = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_001",
        TargetBox = "1",
        TargetSlot = "1"
    })
    local responses = TestUtils.executeHandler("processLogic", msg)
    
    local response = TestUtils.assertResponseSuccess(responses, "SaveState")
    local data = json.decode(response.Data)
    
    assert(data.result.pokemonId == "pokemon_001", "Pokemon ID not in result")
    assert(data.result.location.type == "pc", "Expected PC location")
    assert(data.result.location.box == 1, "Expected box 1")
    assert(data.result.location.slot == 1, "Expected slot 1")
    
    -- Verify storage state updated
    assert(data.storageState.pcStorage.totalStored == 1, "Expected 1 Pokemon in PC storage")
    assert(data.storageState.pcStorage.boxes[1].totalStored == 1, "Expected 1 Pokemon in box 1")
    assert(data.storageState.pcStorage.boxes[1].pokemon[1] == "pokemon_001", "Pokemon not in correct slot")
    
    -- Test deposit to occupied slot
    local msg2 = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_002",
        TargetBox = "1",
        TargetSlot = "1"
    })
    local responses2 = TestUtils.executeHandler("processLogic", msg2)
    
    TestUtils.assertResponseError(responses2, "occupied")
    
    -- Test deposit to auto-selected slot
    local msg3 = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_002",
        TargetBox = "1"
    })
    local responses3 = TestUtils.executeHandler("processLogic", msg3)
    
    local response3 = TestUtils.assertResponseSuccess(responses3, "SaveState")
    local data3 = json.decode(response3.Data)
    assert(data3.result.location.slot == 2, "Expected auto-selected slot 2")
    
    print("✓ Pokemon deposit operations working")
end

function TestSuite.testWithdrawPokemon()
    print("Testing: Pokemon Withdraw Operations")
    
    local playerId = "test_player_withdraw"
    
    -- First deposit a Pokemon
    local depositMsg = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_withdraw_001",
        TargetBox = "2",
        TargetSlot = "5"
    })
    TestUtils.executeHandler("processLogic", depositMsg)
    
    -- Test successful withdraw
    local msg = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "withdraw",
        SourceBox = "2",
        SourceSlot = "5",
        TargetSlot = "1"
    })
    local responses = TestUtils.executeHandler("processLogic", msg)
    
    local response = TestUtils.assertResponseSuccess(responses, "SaveState")
    local data = json.decode(response.Data)
    
    assert(data.result.pokemonId == "pokemon_withdraw_001", "Pokemon ID not in result")
    assert(data.result.sourceLocation.type == "pc", "Expected PC source location")
    assert(data.result.targetLocation.type == "party", "Expected party target location")
    assert(data.result.targetLocation.slot == 1, "Expected party slot 1")
    
    -- Verify storage state updated
    assert(data.storageState.party.totalActive == 1, "Expected 1 Pokemon in party")
    assert(data.storageState.party.pokemon[1] == "pokemon_withdraw_001", "Pokemon not in party slot 1")
    assert(data.storageState.pcStorage.totalStored == 0, "Expected 0 Pokemon in PC storage")
    assert(data.storageState.party.leadPokemon == 1, "Expected lead Pokemon to be slot 1")
    
    -- Test withdraw from empty slot
    local msg2 = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "withdraw",
        SourceBox = "2",
        SourceSlot = "5"
    })
    local responses2 = TestUtils.executeHandler("processLogic", msg2)
    
    TestUtils.assertResponseError(responses2, "No Pokemon")
    
    print("✓ Pokemon withdraw operations working")
end

function TestSuite.testSwapPokemon()
    print("Testing: Pokemon Swap Operations")
    
    local playerId = "test_player_swap"
    
    -- Setup: deposit two Pokemon
    TestUtils.executeHandler("processLogic", TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_swap_001",
        TargetBox = "1",
        TargetSlot = "1"
    }))
    
    TestUtils.executeHandler("processLogic", TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_swap_002",
        TargetBox = "1",
        TargetSlot = "2"
    }))
    
    -- Test PC to PC swap
    local swapData = {
        operation = "swap",
        sourceLocation = {type = "pc", box = 1, slot = 1},
        targetLocation = {type = "pc", box = 1, slot = 2}
    }
    local msg = TestUtils.createMockMessage("ProcessLogic", playerId, swapData)
    local responses = TestUtils.executeHandler("processLogic", msg)
    
    local response = TestUtils.assertResponseSuccess(responses, "SaveState")
    local data = json.decode(response.Data)
    
    assert(data.result.sourcePokemon == "pokemon_swap_001", "Source Pokemon incorrect")
    assert(data.result.targetPokemon == "pokemon_swap_002", "Target Pokemon incorrect")
    
    -- Verify swap occurred
    assert(data.storageState.pcStorage.boxes[1].pokemon[1] == "pokemon_swap_002", "Pokemon not swapped to slot 1")
    assert(data.storageState.pcStorage.boxes[1].pokemon[2] == "pokemon_swap_001", "Pokemon not swapped to slot 2")
    
    print("✓ Pokemon swap operations working")
end

function TestSuite.testReleasePokemon()
    print("Testing: Pokemon Release Operations")
    
    local playerId = "test_player_release"
    
    -- Setup: deposit a Pokemon
    TestUtils.executeHandler("processLogic", TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_release_001",
        TargetBox = "1",
        TargetSlot = "1"
    }))
    
    -- Test release
    local releaseData = {
        operation = "release",
        location = {type = "pc", box = 1, slot = 1}
    }
    local msg = TestUtils.createMockMessage("ProcessLogic", playerId, releaseData)
    local responses = TestUtils.executeHandler("processLogic", msg)
    
    local response = TestUtils.assertResponseSuccess(responses, "SaveState")
    local data = json.decode(response.Data)
    
    assert(data.result.pokemonId == "pokemon_release_001", "Released Pokemon ID incorrect")
    assert(data.storageState.pcStorage.totalStored == 0, "Expected 0 Pokemon after release")
    assert(data.storageState.storageMetadata.totalPokemonOwned == 0, "Total owned count not decremented")
    
    print("✓ Pokemon release operations working")
end

function TestSuite.testPartyManagement()
    print("Testing: Party Management Operations")
    
    local playerId = "test_player_party"
    
    -- Setup: withdraw Pokemon to party
    TestUtils.executeHandler("processLogic", TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_party_001"
    }))
    
    TestUtils.executeHandler("processLogic", TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "withdraw",
        SourceBox = "1",
        SourceSlot = "1"
    }))
    
    TestUtils.executeHandler("processLogic", TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_party_002"
    }))
    
    TestUtils.executeHandler("processLogic", TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "withdraw",
        SourceBox = "1",
        SourceSlot = "1",
        TargetSlot = "2"
    }))
    
    -- Test swap party positions
    local msg1 = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "swapPartyPositions",
        Position1 = "1",
        Position2 = "2"
    })
    local responses1 = TestUtils.executeHandler("processLogic", msg1)
    
    local response1 = TestUtils.assertResponseSuccess(responses1, "SaveState")
    local data1 = json.decode(response1.Data)
    
    assert(data1.result.pokemon1 == "pokemon_party_001", "Party swap Pokemon 1 incorrect")
    assert(data1.result.pokemon2 == "pokemon_party_002", "Party swap Pokemon 2 incorrect")
    
    -- Test set lead Pokemon
    local msg2 = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "setLeadPokemon",
        PartyPosition = "2"
    })
    local responses2 = TestUtils.executeHandler("processLogic", msg2)
    
    local response2 = TestUtils.assertResponseSuccess(responses2, "SaveState")
    local data2 = json.decode(response2.Data)
    
    assert(data2.storageState.party.leadPokemon == 2, "Lead Pokemon not set correctly")
    assert(data2.result.leadPosition == 2, "Lead position not in result")
    
    print("✓ Party management operations working")
end

function TestSuite.testSearchPokemon()
    print("Testing: Pokemon Search Operations")
    
    local playerId = "test_player_search"
    
    -- Setup: add multiple Pokemon
    for i = 1, 5 do
        TestUtils.executeHandler("processLogic", TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "pokemon_search_00" .. i,
            TargetBox = "1",
            TargetSlot = tostring(i)
        }))
    end
    
    -- Move one to party
    TestUtils.executeHandler("processLogic", TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "withdraw",
        SourceBox = "1",
        SourceSlot = "1"
    }))
    
    -- Test search
    local searchData = {
        operation = "search",
        searchCriteria = {}
    }
    local msg = TestUtils.createMockMessage("ProcessLogic", playerId, searchData)
    local responses = TestUtils.executeHandler("processLogic", msg)
    
    local response = TestUtils.assertResponseSuccess(responses, "SaveState")
    local data = json.decode(response.Data)
    
    assert(data.result.totalFound == 5, "Expected 5 Pokemon found")
    assert(#data.result.results.party == 1, "Expected 1 Pokemon in party")
    assert(#data.result.results.pc == 4, "Expected 4 Pokemon in PC")
    
    print("✓ Pokemon search operations working")
end

function TestSuite.testRateLimiting()
    print("Testing: Rate Limiting")
    
    local playerId = "test_player_rate_limit"
    local successfulOps = 0
    
    -- Attempt operations beyond rate limit (50 per minute)
    for i = 1, 55 do
        local msg = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "validateIntegrity"
        })
        local responses = TestUtils.executeHandler("processLogic", msg)
        
        if responses[1].Success == "true" then
            successfulOps = successfulOps + 1
        end
    end
    
    assert(successfulOps <= 50, "Rate limiting not working - too many operations succeeded")
    print("✓ Rate limiting working (allowed " .. successfulOps .. " operations)")
end

function TestSuite.testErrorHandling()
    print("Testing: Error Handling")
    
    local playerId = "test_player_errors"
    
    -- Test missing operation
    local msg1 = TestUtils.createMockMessage("ProcessLogic", playerId)
    local responses1 = TestUtils.executeHandler("processLogic", msg1)
    TestUtils.assertResponseError(responses1, "Operation required")
    
    -- Test invalid operation
    local msg2 = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "invalidOperation"
    })
    local responses2 = TestUtils.executeHandler("processLogic", msg2)
    TestUtils.assertResponseError(responses2, "Unknown operation")
    
    -- Test invalid box number
    local msg3 = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_error",
        TargetBox = "99"
    })
    local responses3 = TestUtils.executeHandler("processLogic", msg3)
    TestUtils.assertResponseError(responses3, "Invalid box number")
    
    print("✓ Error handling working")
end

function TestSuite.testStorageCapacityLimits()
    print("Testing: Storage Capacity Limits")
    
    local playerId = "test_player_capacity"
    
    -- Fill a box to capacity
    for i = 1, 30 do
        TestUtils.executeHandler("processLogic", TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "pokemon_capacity_" .. string.format("%03d", i),
            TargetBox = "1",
            TargetSlot = tostring(i)
        }))
    end
    
    -- Try to add one more (should fail)
    local msg = TestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_overflow",
        TargetBox = "1"
    })
    local responses = TestUtils.executeHandler("processLogic", msg)
    
    TestUtils.assertResponseError(responses, "is full")
    
    print("✓ Storage capacity limits working")
end

-- Run all tests
function TestSuite.runAllTests()
    print("=== PC Storage Manager Unit Tests ===")
    print("")
    
    local tests = {
        TestSuite.testProcessInitialization,
        TestSuite.testPingHandler,
        TestSuite.testPlayerStorageInitialization,
        TestSuite.testDepositPokemon,
        TestSuite.testWithdrawPokemon,
        TestSuite.testSwapPokemon,
        TestSuite.testReleasePokemon,
        TestSuite.testPartyManagement,
        TestSuite.testSearchPokemon,
        TestSuite.testRateLimiting,
        TestSuite.testErrorHandling,
        TestSuite.testStorageCapacityLimits
    }
    
    local passed = 0
    local failed = 0
    
    for i, test in ipairs(tests) do
        local success, error = pcall(test)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("❌ Test failed:", error)
        end
        print("")
    end
    
    print("=== Test Results ===")
    print("Passed:", passed)
    print("Failed:", failed)
    print("Total:", passed + failed)
    
    if failed == 0 then
        print("🎉 All tests passed!")
        return true
    else
        print("❌ Some tests failed")
        return false
    end
end

-- Run tests if this file is executed directly
if arg and arg[0]:match("pc%-storage%-manager%.test%.lua$") then
    TestSuite.runAllTests()
end

return TestSuite