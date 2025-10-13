-- PC Storage Manager Parity Tests
-- Validates that PC storage behavior matches TypeScript implementation exactly

local json = require("json")

-- Mock AO environment
local MockAO = {
    messages = {},
    id = "pc_storage_parity_test_id"
}

function MockAO.send(message)
    table.insert(MockAO.messages, message)
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

-- TypeScript Reference Behaviors (expected behaviors from original implementation)
local TypeScriptReference = {
    
    -- PC Storage Constants (matching TypeScript values)
    MAX_BOXES = 30,
    MAX_POKEMON_PER_BOX = 30,
    MAX_PARTY_SIZE = 6,
    DEFAULT_BOX_NAME_PATTERN = "Box %d",
    
    -- Expected Storage Structure
    expectedStorageStructure = {
        pcStorage = {
            boxes = "table", -- Should be table with numbered indices
            totalBoxes = 30,
            totalStored = "number",
            currentBox = "number",
            maxBoxCapacity = 30,
            maxTotalCapacity = 900
        },
        party = {
            pokemon = "table", -- Should be table with numbered indices
            totalActive = "number",
            maxPartySize = 6,
            leadPokemon = "number"
        },
        storageMetadata = {
            totalPokemonOwned = "number",
            lastModified = "number",
            storageVersion = "string",
            organizationSettings = "table"
        }
    },
    
    -- Expected Box Structure
    expectedBoxStructure = {
        name = "string",
        pokemon = "table",
        totalStored = "number"
    },
    
    -- Expected Error Messages (matching TypeScript implementation)
    errorMessages = {
        boxNumberInvalid = "Invalid box number",
        slotNumberInvalid = "Invalid slot number",
        slotOccupied = "occupied",
        boxFull = "is full",
        partyFull = "Party is full",
        pokemonNotFound = "No Pokemon",
        operationRequired = "Operation required",
        partyPositionInvalid = "Party position",
        rateLimitExceeded = "Rate limit exceeded"
    }
}

-- Parity Test Utilities
local ParityTestUtils = {}

function ParityTestUtils.createMockMessage(action, from, data, tags)
    local msg = {
        Action = action,
        From = from or "test_player_parity",
        Timestamp = tostring(1234567890), -- Fixed timestamp for consistency
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

function ParityTestUtils.executeHandler(handlerName, msg)
    MockAO.clearMessages()
    local handler = Handlers._registry[handlerName]
    if handler and handler.handler then
        handler.handler(msg)
    end
    return MockAO.messages
end

function ParityTestUtils.assertStructureMatches(actual, expected, path)
    path = path or "root"
    
    for key, expectedType in pairs(expected) do
        assert(actual[key] ~= nil, "Missing field: " .. path .. "." .. key)
        
        if type(expectedType) == "string" then
            -- Check type
            assert(type(actual[key]) == expectedType, 
                   "Type mismatch at " .. path .. "." .. key .. ": expected " .. expectedType .. ", got " .. type(actual[key]))
        elseif type(expectedType) == "number" then
            -- Check exact value
            assert(actual[key] == expectedType,
                   "Value mismatch at " .. path .. "." .. key .. ": expected " .. expectedType .. ", got " .. actual[key])
        elseif type(expectedType) == "table" then
            -- Recursively check nested structure
            ParityTestUtils.assertStructureMatches(actual[key], expectedType, path .. "." .. key)
        end
    end
end

-- Parity Test Suite
local ParityTestSuite = {}

function ParityTestSuite.testStorageStructureParity()
    print("Testing: Storage Structure Parity with TypeScript")
    
    local playerId = "test_player_parity"
    
    -- Initialize storage
    local msg = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "validateIntegrity"
    })
    local responses = ParityTestUtils.executeHandler("processLogic", msg)
    
    assert(#responses > 0, "No response received")
    local response = responses[1]
    assert(response.Success == "true", "Failed to initialize storage")
    
    local data = json.decode(response.Data)
    local storageState = data.storageState
    
    -- Validate main storage structure matches TypeScript
    ParityTestUtils.assertStructureMatches(storageState, TypeScriptReference.expectedStorageStructure)
    
    -- Validate box structure for all boxes
    for i = 1, TypeScriptReference.MAX_BOXES do
        local box = storageState.pcStorage.boxes[i]
        assert(box ~= nil, "Box " .. i .. " not initialized")
        ParityTestUtils.assertStructureMatches(box, TypeScriptReference.expectedBoxStructure)
        
        -- Validate default box naming matches TypeScript pattern
        local expectedName = string.format(TypeScriptReference.DEFAULT_BOX_NAME_PATTERN, i)
        assert(box.name == expectedName, "Box name mismatch: expected '" .. expectedName .. "', got '" .. box.name .. "'")
    end
    
    -- Validate initial values match TypeScript defaults
    assert(storageState.pcStorage.totalStored == 0, "Initial total stored should be 0")
    assert(storageState.pcStorage.currentBox == 1, "Initial current box should be 1")
    assert(storageState.party.totalActive == 0, "Initial party total should be 0")
    assert(storageState.party.leadPokemon == 1, "Initial lead Pokemon should be 1")
    
    print("✓ Storage structure matches TypeScript implementation")
end

function ParityTestSuite.testDepositBehaviorParity()
    print("Testing: Deposit Behavior Parity with TypeScript")
    
    local playerId = "test_player_deposit_parity"
    
    -- Test 1: Basic deposit to specific slot (TypeScript behavior)
    local msg1 = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "parity_pokemon_001",
        TargetBox = "1",
        TargetSlot = "1"
    })
    local responses1 = ParityTestUtils.executeHandler("processLogic", msg1)
    
    assert(responses1[1].Success == "true", "Basic deposit should succeed")
    local data1 = json.decode(responses1[1].Data)
    assert(data1.result.location.box == 1, "Deposit location box incorrect")
    assert(data1.result.location.slot == 1, "Deposit location slot incorrect")
    
    -- Test 2: Auto-slot selection (TypeScript behavior)
    local msg2 = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "parity_pokemon_002",
        TargetBox = "1"
    })
    local responses2 = ParityTestUtils.executeHandler("processLogic", msg2)
    
    assert(responses2[1].Success == "true", "Auto-slot deposit should succeed")
    local data2 = json.decode(responses2[1].Data)
    assert(data2.result.location.slot == 2, "Auto-selected slot should be 2")
    
    -- Test 3: Deposit to occupied slot (should fail like TypeScript)
    local msg3 = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "parity_pokemon_003",
        TargetBox = "1",
        TargetSlot = "1"
    })
    local responses3 = ParityTestUtils.executeHandler("processLogic", msg3)
    
    assert(responses3[1].Success == "false", "Deposit to occupied slot should fail")
    assert(string.find(responses3[1].Error, TypeScriptReference.errorMessages.slotOccupied), 
           "Error message should contain 'occupied'")
    
    -- Test 4: Invalid box number (TypeScript validation behavior)
    local msg4 = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "parity_pokemon_004",
        TargetBox = "99"
    })
    local responses4 = ParityTestUtils.executeHandler("processLogic", msg4)
    
    assert(responses4[1].Success == "false", "Invalid box deposit should fail")
    assert(string.find(responses4[1].Error, TypeScriptReference.errorMessages.boxNumberInvalid), 
           "Error message should indicate invalid box number")
    
    print("✓ Deposit behavior matches TypeScript implementation")
end

function ParityTestSuite.testWithdrawBehaviorParity()
    print("Testing: Withdraw Behavior Parity with TypeScript")
    
    local playerId = "test_player_withdraw_parity"
    
    -- Setup: deposit a Pokemon first
    ParityTestUtils.executeHandler("processLogic",
        ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "parity_withdraw_001",
            TargetBox = "2",
            TargetSlot = "5"
        }))
    
    -- Test 1: Withdraw to specific party slot (TypeScript behavior)
    local msg1 = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "withdraw",
        SourceBox = "2",
        SourceSlot = "5",
        TargetSlot = "3"
    })
    local responses1 = ParityTestUtils.executeHandler("processLogic", msg1)
    
    assert(responses1[1].Success == "true", "Withdraw to specific slot should succeed")
    local data1 = json.decode(responses1[1].Data)
    assert(data1.result.targetLocation.slot == 3, "Target party slot incorrect")
    assert(data1.storageState.party.pokemon[3] == "parity_withdraw_001", "Pokemon not in correct party slot")
    
    -- Test 2: Lead Pokemon auto-assignment (TypeScript behavior)
    assert(data1.storageState.party.leadPokemon == 3, "Lead Pokemon should be auto-assigned to first party member")
    
    -- Setup another Pokemon for auto-slot test
    ParityTestUtils.executeHandler("processLogic",
        ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "parity_withdraw_002",
            TargetBox = "2",
            TargetSlot = "6"
        }))
    
    -- Test 3: Auto party slot selection (TypeScript behavior)
    local msg3 = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "withdraw",
        SourceBox = "2",
        SourceSlot = "6"
    })
    local responses3 = ParityTestUtils.executeHandler("processLogic", msg3)
    
    assert(responses3[1].Success == "true", "Auto party slot withdraw should succeed")
    local data3 = json.decode(responses3[1].Data)
    assert(data3.result.targetLocation.slot == 1, "Auto-selected party slot should be 1")
    
    -- Test 4: Withdraw from empty slot (should fail like TypeScript)
    local msg4 = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "withdraw",
        SourceBox = "2",
        SourceSlot = "10"
    })
    local responses4 = ParityTestUtils.executeHandler("processLogic", msg4)
    
    assert(responses4[1].Success == "false", "Withdraw from empty slot should fail")
    assert(string.find(responses4[1].Error, TypeScriptReference.errorMessages.pokemonNotFound), 
           "Error should indicate no Pokemon found")
    
    print("✓ Withdraw behavior matches TypeScript implementation")
end

function ParityTestSuite.testPartyConstraintsParity()
    print("Testing: Party Constraints Parity with TypeScript")
    
    local playerId = "test_player_party_parity"
    
    -- Fill party to capacity
    for i = 1, TypeScriptReference.MAX_PARTY_SIZE do
        ParityTestUtils.executeHandler("processLogic",
            ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
                Operation = "deposit",
                PokemonId = "party_pokemon_" .. string.format("%03d", i)
            }))
        
        ParityTestUtils.executeHandler("processLogic",
            ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
                Operation = "withdraw",
                SourceBox = "1",
                SourceSlot = "1",
                TargetSlot = tostring(i)
            }))
    end
    
    -- Test: Party full constraint (TypeScript behavior)
    ParityTestUtils.executeHandler("processLogic",
        ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "party_overflow_pokemon"
        }))
    
    local msg = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "withdraw",
        SourceBox = "1",
        SourceSlot = "1"
    })
    local responses = ParityTestUtils.executeHandler("processLogic", msg)
    
    assert(responses[1].Success == "false", "Withdraw to full party should fail")
    assert(string.find(responses[1].Error, TypeScriptReference.errorMessages.partyFull), 
           "Error should indicate party is full")
    
    print("✓ Party constraints match TypeScript implementation")
end

function ParityTestSuite.testSwapBehaviorParity()
    print("Testing: Swap Behavior Parity with TypeScript")
    
    local playerId = "test_player_swap_parity"
    
    -- Setup: add Pokemon to different locations
    ParityTestUtils.executeHandler("processLogic",
        ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "swap_pc_pokemon",
            TargetBox = "1",
            TargetSlot = "1"
        }))
    
    ParityTestUtils.executeHandler("processLogic",
        ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "swap_party_pokemon"
        }))
    
    ParityTestUtils.executeHandler("processLogic",
        ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "withdraw",
            SourceBox = "1",
            SourceSlot = "1",
            TargetSlot = "1"
        }))
    
    -- Test: PC to Party swap (TypeScript behavior)
    local swapData = {
        operation = "swap",
        sourceLocation = {type = "pc", box = 1, slot = 1},
        targetLocation = {type = "party", slot = 1}
    }
    local msg = ParityTestUtils.createMockMessage("ProcessLogic", playerId, swapData)
    local responses = ParityTestUtils.executeHandler("processLogic", msg)
    
    assert(responses[1].Success == "true", "PC to Party swap should succeed")
    local data = json.decode(responses[1].Data)
    assert(data.result.sourcePokemon == "swap_pc_pokemon", "Source Pokemon incorrect in swap")
    assert(data.result.targetPokemon == "swap_party_pokemon", "Target Pokemon incorrect in swap")
    
    -- Verify swap actually occurred (TypeScript behavior)
    local verifyMsg = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "validateIntegrity"
    })
    local verifyResponses = ParityTestUtils.executeHandler("processLogic", verifyMsg)
    local verifyData = json.decode(verifyResponses[1].Data)
    
    assert(verifyData.storageState.pcStorage.boxes[1].pokemon[1] == "swap_party_pokemon", 
           "Pokemon not swapped to PC correctly")
    assert(verifyData.storageState.party.pokemon[1] == "swap_pc_pokemon", 
           "Pokemon not swapped to party correctly")
    
    print("✓ Swap behavior matches TypeScript implementation")
end

function ParityTestSuite.testBoxCapacityLimitsParity()
    print("Testing: Box Capacity Limits Parity with TypeScript")
    
    local playerId = "test_player_capacity_parity"
    
    -- Fill a box to exact capacity (TypeScript behavior)
    for i = 1, TypeScriptReference.MAX_POKEMON_PER_BOX do
        local msg = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "capacity_pokemon_" .. string.format("%03d", i),
            TargetBox = "1",
            TargetSlot = tostring(i)
        })
        local responses = ParityTestUtils.executeHandler("processLogic", msg)
        assert(responses[1].Success == "true", "Deposit " .. i .. " should succeed")
    end
    
    -- Verify box is at capacity
    local verifyMsg = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "validateIntegrity"
    })
    local verifyResponses = ParityTestUtils.executeHandler("processLogic", verifyMsg)
    local verifyData = json.decode(verifyResponses[1].Data)
    
    assert(verifyData.storageState.pcStorage.boxes[1].totalStored == TypeScriptReference.MAX_POKEMON_PER_BOX,
           "Box should be at maximum capacity")
    
    -- Test: Auto-slot selection on full box (should fail like TypeScript)
    local overflowMsg = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "overflow_pokemon",
        TargetBox = "1"
    })
    local overflowResponses = ParityTestUtils.executeHandler("processLogic", overflowMsg)
    
    assert(overflowResponses[1].Success == "false", "Deposit to full box should fail")
    assert(string.find(overflowResponses[1].Error, TypeScriptReference.errorMessages.boxFull), 
           "Error should indicate box is full")
    
    print("✓ Box capacity limits match TypeScript implementation")
end

function ParityTestSuite.testLeadPokemonBehaviorParity()
    print("Testing: Lead Pokemon Behavior Parity with TypeScript")
    
    local playerId = "test_player_lead_parity"
    
    -- Test: Lead Pokemon defaults to first party member (TypeScript behavior)
    ParityTestUtils.executeHandler("processLogic",
        ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "lead_pokemon_001"
        }))
    
    ParityTestUtils.executeHandler("processLogic",
        ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "withdraw",
            SourceBox = "1",
            SourceSlot = "1",
            TargetSlot = "3"
        }))
    
    local verifyMsg = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "validateIntegrity"
    })
    local verifyResponses = ParityTestUtils.executeHandler("processLogic", verifyMsg)
    local verifyData = json.decode(verifyResponses[1].Data)
    
    assert(verifyData.storageState.party.leadPokemon == 3, 
           "Lead Pokemon should be set to first party member position")
    
    -- Test: Setting lead Pokemon explicitly (TypeScript behavior)
    ParityTestUtils.executeHandler("processLogic",
        ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "deposit",
            PokemonId = "lead_pokemon_002"
        }))
    
    ParityTestUtils.executeHandler("processLogic",
        ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
            Operation = "withdraw",
            SourceBox = "1",
            SourceSlot = "1",
            TargetSlot = "1"
        }))
    
    local setLeadMsg = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "setLeadPokemon",
        PartyPosition = "1"
    })
    local setLeadResponses = ParityTestUtils.executeHandler("processLogic", setLeadMsg)
    
    assert(setLeadResponses[1].Success == "true", "Set lead Pokemon should succeed")
    local leadData = json.decode(setLeadResponses[1].Data)
    assert(leadData.storageState.party.leadPokemon == 1, "Lead Pokemon not set correctly")
    
    print("✓ Lead Pokemon behavior matches TypeScript implementation")
end

function ParityTestSuite.testErrorMessagesParity()
    print("Testing: Error Messages Parity with TypeScript")
    
    local playerId = "test_player_errors_parity"
    
    -- Test various error conditions and verify messages match TypeScript
    local errorTests = {
        {
            name = "Missing operation",
            message = ParityTestUtils.createMockMessage("ProcessLogic", playerId),
            expectedError = TypeScriptReference.errorMessages.operationRequired
        },
        {
            name = "Invalid box number",
            message = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
                Operation = "deposit",
                PokemonId = "error_pokemon",
                TargetBox = "0"
            }),
            expectedError = TypeScriptReference.errorMessages.boxNumberInvalid
        },
        {
            name = "Invalid party position",
            message = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
                Operation = "setLeadPokemon",
                PartyPosition = "10"
            }),
            expectedError = TypeScriptReference.errorMessages.partyPositionInvalid
        }
    }
    
    for _, test in ipairs(errorTests) do
        local responses = ParityTestUtils.executeHandler("processLogic", test.message)
        assert(responses[1].Success == "false", test.name .. " should fail")
        assert(string.find(responses[1].Error, test.expectedError), 
               test.name .. " error message should contain '" .. test.expectedError .. "'")
    end
    
    print("✓ Error messages match TypeScript implementation")
end

function ParityTestSuite.testTimestampHandlingParity()
    print("Testing: Timestamp Handling Parity with TypeScript")
    
    local playerId = "test_player_timestamp_parity"
    local fixedTimestamp = "1640995200" -- Fixed timestamp for comparison
    
    -- Test that timestamps are properly handled and stored
    local msg = ParityTestUtils.createMockMessage("ProcessLogic", playerId, nil, {
        Operation = "deposit",
        PokemonId = "timestamp_pokemon"
    })
    msg.Timestamp = fixedTimestamp
    
    local responses = ParityTestUtils.executeHandler("processLogic", msg)
    assert(responses[1].Success == "true", "Timestamped operation should succeed")
    
    local data = json.decode(responses[1].Data)
    assert(data.storageState.storageMetadata.lastModified == tonumber(fixedTimestamp),
           "Timestamp not stored correctly in metadata")
    assert(responses[1].Timestamp == fixedTimestamp,
           "Response timestamp should match input timestamp")
    
    print("✓ Timestamp handling matches TypeScript implementation")
end

-- Run Parity Tests
function ParityTestSuite.runAllTests()
    print("=== PC Storage Manager Parity Tests ===")
    print("Validating behavior against TypeScript implementation")
    print("")
    
    local tests = {
        ParityTestSuite.testStorageStructureParity,
        ParityTestSuite.testDepositBehaviorParity,
        ParityTestSuite.testWithdrawBehaviorParity,
        ParityTestSuite.testPartyConstraintsParity,
        ParityTestSuite.testSwapBehaviorParity,
        ParityTestSuite.testBoxCapacityLimitsParity,
        ParityTestSuite.testLeadPokemonBehaviorParity,
        ParityTestSuite.testErrorMessagesParity,
        ParityTestSuite.testTimestampHandlingParity
    }
    
    local passed = 0
    local failed = 0
    
    for i, test in ipairs(tests) do
        local success, error = pcall(test)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("❌ Parity test failed:", error)
        end
        print("")
    end
    
    print("=== Parity Test Results ===")
    print("Passed:", passed)
    print("Failed:", failed) 
    print("Total:", passed + failed)
    
    if failed == 0 then
        print("🎉 Perfect parity with TypeScript implementation!")
        return true
    else
        print("❌ Parity issues detected - behavior differs from TypeScript")
        return false
    end
end

-- Run tests if this file is executed directly
if arg and arg[0]:match("pc%-storage%-parity%.test%.lua$") then
    ParityTestSuite.runAllTests()
end

return ParityTestSuite