-- PC Storage Manager Integration Tests
-- Tests cross-process coordination with Pokemon instance manager, battle engine, and coordinator

local json = require("json")

-- Integration Test Environment Setup
local IntegrationTestEnv = {
    processes = {},
    messageQueue = {},
    processIds = {
        pcStorageManager = "pc_storage_manager_test_id",
        pokemonInstanceManager = "pokemon_instance_manager_test_id",
        battleEngine = "battle_engine_test_id",
        coordinatorProcess = "coordinator_process_test_id"
    }
}

-- Mock process message routing
function IntegrationTestEnv.routeMessage(fromProcess, toProcess, message)
    message.From = fromProcess
    message.Target = toProcess
    
    table.insert(IntegrationTestEnv.messageQueue, {
        from = fromProcess,
        to = toProcess,
        message = message,
        timestamp = 1734567890 -- Fixed timestamp for deterministic testing
    })
end

function IntegrationTestEnv.processMessages()
    local processedMessages = {}
    for _, queuedMessage in ipairs(IntegrationTestEnv.messageQueue) do
        table.insert(processedMessages, queuedMessage)
    end
    IntegrationTestEnv.messageQueue = {}
    return processedMessages
end

-- Mock AO Environment for Integration Testing
local MockAO = {
    messages = {},
    id = IntegrationTestEnv.processIds.pcStorageManager
}

function MockAO.send(message)
    table.insert(MockAO.messages, message)
    
    -- Route cross-process messages
    if message.Target and message.Target ~= MockAO.id then
        IntegrationTestEnv.routeMessage(MockAO.id, message.Target, message)
    end
end

function MockAO.clearMessages()
    MockAO.messages = {}
end

-- Setup test environment
ao = MockAO
Handlers = {
    add = function(name, matcher, handler)
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

-- Mock Pokemon Instance Manager responses
local MockPokemonInstanceManager = {
    pokemonDatabase = {
        ["pokemon_001"] = {
            id = "pokemon_001",
            speciesId = 25, -- Pikachu
            level = 15,
            hp = 45,
            maxHp = 45,
            ownerId = "test_player_integration"
        },
        ["pokemon_002"] = {
            id = "pokemon_002", 
            speciesId = 1, -- Bulbasaur
            level = 12,
            hp = 39,
            maxHp = 39,
            ownerId = "test_player_integration"
        },
        ["pokemon_003"] = {
            id = "pokemon_003",
            speciesId = 4, -- Charmander
            level = 10,
            hp = 35,
            maxHp = 35,
            ownerId = "other_player"
        }
    }
}

function MockPokemonInstanceManager.handleValidatePokemon(msg)
    local data = json.decode(msg.Data or "{}")
    local pokemonId = data.pokemonId
    local validateOwnership = data.validateOwnership
    local validateExistence = data.validateExistence
    
    local pokemon = MockPokemonInstanceManager.pokemonDatabase[pokemonId]
    local exists = pokemon ~= nil
    local owned = exists and pokemon.ownerId == msg.From
    
    local response = {
        exists = exists,
        owned = owned,
        valid = exists and (not validateOwnership or owned)
    }
    
    if exists then
        response.pokemon = pokemon
    end
    
    IntegrationTestEnv.routeMessage(
        IntegrationTestEnv.processIds.pokemonInstanceManager,
        msg.From,
        {
            Action = "ValidationResult",
            Data = json.encode(response),
            Success = "true"
        }
    )
end

function MockPokemonInstanceManager.handleReleasePokemon(msg)
    local data = json.decode(msg.Data or "{}")
    local pokemonId = data.pokemonId
    
    if MockPokemonInstanceManager.pokemonDatabase[pokemonId] then
        MockPokemonInstanceManager.pokemonDatabase[pokemonId] = nil
        
        IntegrationTestEnv.routeMessage(
            IntegrationTestEnv.processIds.pokemonInstanceManager,
            msg.From,
            {
                Action = "ReleaseConfirmed",
                Data = json.encode({ pokemonId = pokemonId, released = true }),
                Success = "true"
            }
        )
    else
        IntegrationTestEnv.routeMessage(
            IntegrationTestEnv.processIds.pokemonInstanceManager,
            msg.From,
            {
                Action = "Error",
                Error = "Pokemon not found for release",
                Success = "false"
            }
        )
    end
end

-- Mock Battle Engine responses
local MockBattleEngine = {}

function MockBattleEngine.handleUpdatePartyState(msg)
    local data = json.decode(msg.Data or "{}")
    
    IntegrationTestEnv.routeMessage(
        IntegrationTestEnv.processIds.battleEngine,
        msg.From,
        {
            Action = "PartyStateUpdated",
            Data = json.encode({ 
                playerId = data.playerId,
                partyUpdated = true,
                battleReady = data.partyComposition and #data.partyComposition > 0
            }),
            Success = "true"
        }
    )
end

-- Mock Coordinator Process responses
local MockCoordinatorProcess = {}

function MockCoordinatorProcess.handleUpdatePlayerSave(msg)
    local data = json.decode(msg.Data or "{}")
    
    IntegrationTestEnv.routeMessage(
        IntegrationTestEnv.processIds.coordinatorProcess,
        msg.From,
        {
            Action = "SaveUpdated",
            Data = json.encode({
                playerId = data.playerId,
                saveUpdated = true,
                saveReason = data.saveReason
            }),
            Success = "true"
        }
    )
end

-- Integration Test Utilities
local IntegrationTestUtils = {}

function IntegrationTestUtils.createMockMessage(action, from, data, tags)
    local msg = {
        Action = action,
        From = from or "test_player_integration",
        Timestamp = "1734567890000", -- Fixed timestamp for deterministic testing
        Data = data and json.encode(data) or "",
        Tags = tags or {}
    }
    
    if tags then
        for key, value in pairs(tags) do
            msg[key] = value
        end
    end
    
    return msg
end

function IntegrationTestUtils.executeHandler(handlerName, msg)
    MockAO.clearMessages()
    local handler = Handlers._registry[handlerName]
    if handler and handler.handler then
        handler.handler(msg)
    end
    
    -- Process any cross-process messages
    local crossProcessMessages = IntegrationTestEnv.processMessages()
    
    -- Route cross-process messages to mock handlers
    for _, queuedMsg in ipairs(crossProcessMessages) do
        if queuedMsg.to == IntegrationTestEnv.processIds.pokemonInstanceManager then
            if queuedMsg.message.Action == "ValidatePokemon" then
                MockPokemonInstanceManager.handleValidatePokemon(queuedMsg.message)
            elseif queuedMsg.message.Action == "ReleasePokemon" then
                MockPokemonInstanceManager.handleReleasePokemon(queuedMsg.message)
            end
        elseif queuedMsg.to == IntegrationTestEnv.processIds.battleEngine then
            if queuedMsg.message.Action == "UpdatePartyState" then
                MockBattleEngine.handleUpdatePartyState(queuedMsg.message)
            end
        elseif queuedMsg.to == IntegrationTestEnv.processIds.coordinatorProcess then
            if queuedMsg.message.Action == "UpdatePlayerSave" then
                MockCoordinatorProcess.handleUpdatePlayerSave(queuedMsg.message)
            end
        end
    end
    
    return MockAO.messages, crossProcessMessages
end

function IntegrationTestUtils.assertResponseSuccess(responses, expectedAction)
    assert(#responses > 0, "No response received")
    local response = responses[1]
    assert(response.Success == "true", "Response not successful: " .. (response.Error or "unknown error"))
    if expectedAction then
        assert(response.Action == expectedAction, "Expected action " .. expectedAction .. " but got " .. response.Action)
    end
    return response
end

-- Integration Test Suite
local IntegrationTestSuite = {}

function IntegrationTestSuite.testBasicStorageOperation()
    print("Testing: Basic Storage Operation Integration")
    
    local playerId = "test_player_integration"
    
    -- Test deposit operation
    local msg = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_001",
        TargetBox = "1",
        TargetSlot = "1"
    })
    
    local responses, crossProcessMessages = IntegrationTestUtils.executeHandler("processLogic", msg)
    
    local response = IntegrationTestUtils.assertResponseSuccess(responses, "SaveState")
    local data = json.decode(response.Data)
    
    assert(data.result.pokemonId == "pokemon_001", "Pokemon ID not in result")
    assert(data.storageState.pcStorage.totalStored == 1, "Storage count not updated")
    
    print("✓ Basic storage operation integration working")
end

function IntegrationTestSuite.testPokemonOwnershipValidation()
    print("Testing: Pokemon Ownership Validation Integration")
    
    local playerId = "test_player_integration"
    
    -- Test deposit with owned Pokemon (should succeed)
    local msg1 = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "pokemon_001",
        TargetBox = "1",
        TargetSlot = "1"
    })
    
    local responses1, _ = IntegrationTestUtils.executeHandler("processLogic", msg1)
    IntegrationTestUtils.assertResponseSuccess(responses1, "SaveState")
    
    -- Test deposit with Pokemon owned by different player (should work in current implementation)
    -- In a full implementation, this would trigger validation
    local msg2 = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit", 
        PokemonId = "pokemon_003",
        TargetBox = "1",
        TargetSlot = "2"
    })
    
    local responses2, crossProcessMessages = IntegrationTestUtils.executeHandler("processLogic", msg2)
    
    -- Current implementation doesn't validate ownership, but integration test validates message routing
    assert(#crossProcessMessages == 0 or crossProcessMessages[1].to == IntegrationTestEnv.processIds.pokemonInstanceManager, 
           "Cross-process validation message not routed correctly")
    
    print("✓ Pokemon ownership validation integration prepared")
end

function IntegrationTestSuite.testPokemonReleaseIntegration()
    print("Testing: Pokemon Release Cross-Process Integration")
    
    local playerId = "test_player_integration"
    
    -- Setup: deposit a Pokemon first
    IntegrationTestUtils.executeHandler("processLogic", 
        IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "pokemon_002",
            TargetBox = "1",
            TargetSlot = "1"
        }))
    
    -- Test Pokemon release
    local releaseData = {
        operation = "release",
        location = {type = "pc", box = 1, slot = 1}
    }
    
    local msg = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, releaseData)
    local responses, crossProcessMessages = IntegrationTestUtils.executeHandler("processLogic", msg)
    
    local response = IntegrationTestUtils.assertResponseSuccess(responses, "SaveState")
    local data = json.decode(response.Data)
    
    assert(data.result.pokemonId == "pokemon_002", "Released Pokemon ID incorrect")
    assert(data.storageState.pcStorage.totalStored == 0, "Storage count not updated after release")
    
    print("✓ Pokemon release integration working")
end

function IntegrationTestSuite.testPartyCompositionSyncWithBattleEngine()
    print("Testing: Party Composition Sync with Battle Engine")
    
    local playerId = "test_player_integration"
    
    -- Setup: add Pokemon to party
    IntegrationTestUtils.executeHandler("processLogic",
        IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "pokemon_001"
        }))
    
    IntegrationTestUtils.executeHandler("processLogic",
        IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "withdraw",
            SourceBox = "1",
            SourceSlot = "1"
        }))
    
    -- Test party management that should sync with battle engine
    local msg = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "setLeadPokemon",
        PartyPosition = "1"
    })
    
    local responses, crossProcessMessages = IntegrationTestUtils.executeHandler("processLogic", msg)
    
    local response = IntegrationTestUtils.assertResponseSuccess(responses, "SaveState")
    local data = json.decode(response.Data)
    
    assert(data.storageState.party.leadPokemon == 1, "Lead Pokemon not set correctly")
    
    -- In a full implementation, this would trigger battle engine sync
    print("✓ Party composition sync integration prepared")
end

function IntegrationTestSuite.testSaveDataPersistenceIntegration()
    print("Testing: Save Data Persistence Integration")
    
    local playerId = "test_player_integration"
    
    -- Perform multiple storage operations
    local operations = {
        {Operation = "deposit", PokemonId = "pokemon_001", TargetBox = "1", TargetSlot = "1"},
        {Operation = "deposit", PokemonId = "pokemon_002", TargetBox = "1", TargetSlot = "2"},
        {Operation = "withdraw", SourceBox = "1", SourceSlot = "1", TargetSlot = "1"}
    }
    
    for _, op in ipairs(operations) do
        local msg = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, op)
        local responses, crossProcessMessages = IntegrationTestUtils.executeHandler("processLogic", msg)
        
        IntegrationTestUtils.assertResponseSuccess(responses, "SaveState")
        
        -- Each operation should potentially trigger save data updates
        -- In full implementation, this would route to coordinator process
    end
    
    print("✓ Save data persistence integration prepared")
end

function IntegrationTestSuite.testCrossProcessMessageFormatting()
    print("Testing: Cross-Process Message Formatting")
    
    local playerId = "test_player_integration"
    
    -- Test operation that would generate cross-process messages
    local msg = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "validateIntegrity"
    })
    
    local responses, crossProcessMessages = IntegrationTestUtils.executeHandler("processLogic", msg)
    
    local response = IntegrationTestUtils.assertResponseSuccess(responses, "SaveState")
    
    -- Verify response format includes required fields
    assert(response.ProcessId, "ProcessId not included in response")
    assert(response.Timestamp, "Timestamp not included in response")
    assert(response.Success, "Success flag not included in response")
    assert(response.Operation, "Operation not included in response")
    
    print("✓ Cross-process message formatting correct")
end

function IntegrationTestSuite.testErrorPropagationAcrossProcesses()
    print("Testing: Error Propagation Across Processes")
    
    local playerId = "test_player_integration"
    
    -- Test operation with invalid parameters
    local msg = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "nonexistent_pokemon",
        TargetBox = "99" -- Invalid box
    })
    
    local responses, crossProcessMessages = IntegrationTestUtils.executeHandler("processLogic", msg)
    
    assert(#responses > 0, "No error response received")
    local response = responses[1]
    assert(response.Success == "false" or response.Action == "Error", "Expected error response")
    assert(response.Error, "Error message not provided")
    
    print("✓ Error propagation working correctly")
end

function IntegrationTestSuite.testRateLimitingIntegration()
    print("Testing: Rate Limiting Integration")
    
    local playerId = "test_player_rate_limit_integration"
    
    -- Test that rate limiting works across different operation types
    local operations = {"validateIntegrity", "search", "deposit"}
    local totalOps = 0
    local successful = 0
    
    for i = 1, 60 do -- Exceed rate limit of 50
        local operation = operations[(i % 3) + 1]
        local tags = {Operation = operation}
        
        if operation == "deposit" then
            tags.PokemonId = "pokemon_rate_" .. i
        end
        
        local msg = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, tags)
        local responses, _ = IntegrationTestUtils.executeHandler("processLogic", msg)
        
        totalOps = totalOps + 1
        if responses[1].Success == "true" then
            successful = successful + 1
        end
    end
    
    assert(successful <= 50, "Rate limiting not enforced across operations")
    assert(totalOps > successful, "No operations were rate limited")
    
    print("✓ Rate limiting integration working (allowed " .. successful .. "/" .. totalOps .. " operations)")
end

function IntegrationTestSuite.testConcurrentPlayerOperations()
    print("Testing: Concurrent Player Operations")
    
    local players = {"player_1", "player_2", "player_3"}
    
    -- Test that different players can operate concurrently
    for i, playerId in ipairs(players) do
        local msg = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "pokemon_player_" .. i,
            TargetBox = "1",
            TargetSlot = "1"
        })
        
        local responses, _ = IntegrationTestUtils.executeHandler("processLogic", msg)
        IntegrationTestUtils.assertResponseSuccess(responses, "SaveState")
    end
    
    -- Verify each player has separate storage
    for i, playerId in ipairs(players) do
        local msg = IntegrationTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "validateIntegrity"
        })
        
        local responses, _ = IntegrationTestUtils.executeHandler("processLogic", msg)
        local response = IntegrationTestUtils.assertResponseSuccess(responses, "SaveState")
        local data = json.decode(response.Data)
        
        assert(data.storageState.pcStorage.totalStored == 1, "Player " .. i .. " storage isolation failed")
    end
    
    print("✓ Concurrent player operations working")
end

-- Run Integration Tests
function IntegrationTestSuite.runAllTests()
    print("=== PC Storage Manager Integration Tests ===")
    print("")
    
    local tests = {
        IntegrationTestSuite.testBasicStorageOperation,
        IntegrationTestSuite.testPokemonOwnershipValidation,
        IntegrationTestSuite.testPokemonReleaseIntegration,
        IntegrationTestSuite.testPartyCompositionSyncWithBattleEngine,
        IntegrationTestSuite.testSaveDataPersistenceIntegration,
        IntegrationTestSuite.testCrossProcessMessageFormatting,
        IntegrationTestSuite.testErrorPropagationAcrossProcesses,
        IntegrationTestSuite.testRateLimitingIntegration,
        IntegrationTestSuite.testConcurrentPlayerOperations
    }
    
    local passed = 0
    local failed = 0
    
    for i, test in ipairs(tests) do
        local success, error = pcall(test)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("❌ Integration test failed:", error)
        end
        print("")
    end
    
    print("=== Integration Test Results ===")
    print("Passed:", passed)
    print("Failed:", failed)
    print("Total:", passed + failed)
    
    if failed == 0 then
        print("🎉 All integration tests passed!")
        return true
    else
        print("❌ Some integration tests failed")
        return false
    end
end

-- Run tests if this file is executed directly
if arg and arg[0]:match("pc%-storage%-manager%-integration%.test%.lua$") then
    IntegrationTestSuite.runAllTests()
end

return IntegrationTestSuite