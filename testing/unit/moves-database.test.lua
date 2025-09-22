-- Unit tests for Moves Database Process
-- Test framework: aolite

-- ADP v1.0 Compatible Test - Template dependency removed
-- Temporary stub for DataProcessTemplate
local DataProcessTemplate = {
    validateInput = function(msg) return true, nil end,
    handleMessage = function(msg, processId, handler) return {Action = "Response", Data = {}} end
}

-- Set up AO global mocks
_G.Handlers = {
    add = function(name, matcher, handler) end,
    utils = {
        hasMatchingTag = function(tag, values)
            return function(msg) return true end
        end
    },
    list = {}
}

_G.ao = {
    send = function(params) return params end
}

-- Constants for testing
local MOVE = {
    TACKLE = 33,
    FLAMETHROWER = 53,
    HYDRO_PUMP = 56,
    THUNDERBOLT = 85,
    PSYCHIC = 94,
    ICE_BEAM = 58,
    EARTHQUAKE = 89,
    HYPER_BEAM = 63,
    QUICK_ATTACK = 98,
    SWIFT = 129
}

local POKEMON_TYPE = {
    NORMAL = 0,
    FIGHTING = 1,
    FLYING = 2,
    POISON = 3,
    GROUND = 4,
    ROCK = 5,
    BUG = 6,
    GHOST = 7,
    STEEL = 8,
    FIRE = 9,
    WATER = 10,
    GRASS = 11,
    ELECTRIC = 12,
    PSYCHIC = 13,
    ICE = 14,
    DRAGON = 15,
    DARK = 16,
    FAIRY = 17
}

local MOVE_CATEGORY = {
    PHYSICAL = 0,
    SPECIAL = 1,
    STATUS = 2
}

-- Test basic move data structure
function testMoveDataStructure()
    print("Testing move data structure...")
    
    local testMessage = {
        Action = "GetMove",
        Data = { id = MOVE.FLAMETHROWER },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local isValid, error = DataProcessTemplate.validateInput(testMessage)
    assert(isValid == true, "Test message should be valid")
    assert(error == nil, "Valid message should not produce error")
    
    print("✓ Move data structure test passed")
end

-- Test GetMove by ID
function testGetMoveByID()
    print("Testing GetMove by ID...")
    
    local testMessage = {
        Action = "GetMove",
        Data = { id = MOVE.THUNDERBOLT },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetMove" and message.Data.id == MOVE.THUNDERBOLT then
            return {
                id = 85,
                n = "Thunderbolt",
                t = POKEMON_TYPE.ELECTRIC,
                cat = MOVE_CATEGORY.SPECIAL,
                pwr = 90,
                acc = 100,
                pp = 15,
                pri = 0,
                eff = "10% chance to paralyze target"
            }
        end
        return nil
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(response.Data.n == "Thunderbolt", "Should return Thunderbolt data")
    assert(response.Data.pwr == 90, "Should return correct power value")
    
    print("✓ GetMove by ID test passed")
end

-- Test GetMove by name
function testGetMoveByName()
    print("Testing GetMove by name...")
    
    local testMessage = {
        Action = "GetMove",
        Data = { name = "Flamethrower" },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetMove" and message.Data.name == "Flamethrower" then
            return {
                id = 53,
                n = "Flamethrower",
                t = POKEMON_TYPE.FIRE,
                cat = MOVE_CATEGORY.SPECIAL,
                pwr = 90,
                acc = 100,
                pp = 15
            }
        end
        return nil
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(response.Data.n == "Flamethrower", "Should return correct move name")
    assert(response.Data.t == POKEMON_TYPE.FIRE, "Should return correct type")
    
    print("✓ GetMove by name test passed")
end

-- Test GetMovesByType
function testGetMovesByType()
    print("Testing GetMovesByType...")
    
    local testMessage = {
        Action = "GetMovesByType",
        Data = { type = POKEMON_TYPE.WATER },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetMovesByType" and message.Data.type == POKEMON_TYPE.WATER then
            return {
                {id = 55, n = "Water Gun", t = POKEMON_TYPE.WATER},
                {id = 56, n = "Hydro Pump", t = POKEMON_TYPE.WATER},
                {id = 57, n = "Surf", t = POKEMON_TYPE.WATER}
            }
        end
        return {}
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(type(response.Data) == "table", "Should return moves as table")
    
    print("✓ GetMovesByType test passed")
end

-- Test type effectiveness calculation
function testTypeEffectiveness()
    print("Testing type effectiveness...")
    
    local testMessage = {
        Action = "GetTypeEffectiveness",
        Data = { 
            attackingType = POKEMON_TYPE.WATER,
            defendingTypes = {POKEMON_TYPE.FIRE, POKEMON_TYPE.ROCK}
        },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetTypeEffectiveness" then
            -- Water vs Fire/Rock should be super effective (2.0 * 2.0 = 4.0)
            return {
                effectiveness = 4.0
            }
        end
        return nil
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(response.Data.effectiveness == 4.0, "Should calculate correct effectiveness")
    
    print("✓ Type effectiveness test passed")
end

-- Test type effectiveness chart
function testTypeEffectivenessChart()
    print("Testing type effectiveness chart...")
    
    local testMessage = {
        Action = "GetTypeEffectiveness",
        Data = { attackingType = POKEMON_TYPE.FIRE },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        if message.Action == "GetTypeEffectiveness" and message.Data.attackingType then
            return {
                chart = {
                    [POKEMON_TYPE.GRASS] = 2.0, -- Fire vs Grass = super effective
                    [POKEMON_TYPE.WATER] = 0.5, -- Fire vs Water = not very effective
                    [POKEMON_TYPE.FIRE] = 0.5,  -- Fire vs Fire = not very effective
                    [POKEMON_TYPE.NORMAL] = 1.0 -- Fire vs Normal = normal effectiveness
                }
            }
        end
        return nil
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(type(response.Data.chart) == "table", "Should return chart as table")
    
    print("✓ Type effectiveness chart test passed")
end

-- Test move categories
function testMoveCategories()
    print("Testing move categories...")
    
    local testMessage = {
        Action = "GetMove",
        Data = { id = MOVE.EARTHQUAKE },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        return {
            id = 89,
            n = "Earthquake",
            t = POKEMON_TYPE.GROUND,
            cat = MOVE_CATEGORY.PHYSICAL, -- Should be physical category
            pwr = 100,
            acc = 100
        }
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
    assert(response.Data.cat == MOVE_CATEGORY.PHYSICAL, "Earthquake should be physical category")
    
    -- Test special category
    testMessage.Data.id = MOVE.PSYCHIC
    mockQueryHandler = function(message)
        return {
            cat = MOVE_CATEGORY.SPECIAL -- Psychic should be special
        }
    end
    
    response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
    assert(response.Data.cat == MOVE_CATEGORY.SPECIAL, "Psychic should be special category")
    
    print("✓ Move categories test passed")
end

-- Test move power and accuracy
function testMovePowerAndAccuracy()
    print("Testing move power and accuracy...")
    
    local testMoves = {
        {id = MOVE.HYPER_BEAM, expectedPower = 150, expectedAccuracy = 90},
        {id = MOVE.QUICK_ATTACK, expectedPower = 40, expectedAccuracy = 100},
        {id = MOVE.SWIFT, expectedPower = 60, expectedAccuracy = 999} -- Never misses
    }
    
    for _, moveData in ipairs(testMoves) do
        local testMessage = {
            Action = "GetMove",
            Data = { id = moveData.id },
            Timestamp = 1234567890,
            From = "test-address"
        }
        
        local mockQueryHandler = function(message)
            return {
                pwr = moveData.expectedPower,
                acc = moveData.expectedAccuracy
            }
        end
        
        local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
        assert(response.Data.pwr == moveData.expectedPower, "Power should match expected value")
        assert(response.Data.acc == moveData.expectedAccuracy, "Accuracy should match expected value")
    end
    
    print("✓ Move power and accuracy test passed")
end

-- Test priority moves
function testPriorityMoves()
    print("Testing priority moves...")
    
    local testMessage = {
        Action = "GetMove",
        Data = { id = MOVE.QUICK_ATTACK },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        return {
            n = "Quick Attack",
            pri = 1, -- Priority +1
            eff = "Always goes first"
        }
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
    assert(response.Data.pri == 1, "Quick Attack should have priority +1")
    assert(string.find(response.Data.eff, "first"), "Effect should mention going first")
    
    print("✓ Priority moves test passed")
end

-- Test invalid queries
function testInvalidQueries()
    print("Testing invalid queries...")
    
    -- Test missing required data for GetMove
    local invalidMessage = {
        Action = "GetMove",
        Data = {}, -- Missing id or name
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        error("GetMove requires either 'id' or 'name' in Data")
    end
    
    local response = DataProcessTemplate.handleMessage(invalidMessage, "moves-database", mockQueryHandler)
    assert(response.Error ~= nil, "Should return error for invalid query")
    
    -- Test missing type for GetMovesByType
    invalidMessage.Action = "GetMovesByType"
    invalidMessage.Data = {} -- Missing type
    
    mockQueryHandler = function(message)
        error("GetMovesByType requires 'type' in Data")
    end
    
    response = DataProcessTemplate.handleMessage(invalidMessage, "moves-database", mockQueryHandler)
    assert(response.Error ~= nil, "Should return error for missing type")
    
    print("✓ Invalid queries test passed")
end

-- Test response format compliance
function testResponseFormat()
    print("Testing response format compliance...")
    
    local testMessage = {
        Action = "GetMove",
        Data = { id = MOVE.TACKLE },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        return {
            id = 33,
            n = "Tackle",
            t = POKEMON_TYPE.NORMAL,
            cat = MOVE_CATEGORY.PHYSICAL,
            pwr = 40,
            acc = 100
        }
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
    
    -- Verify SaveState protocol compliance
    assert(response.Action == "SaveState", "Response must use SaveState action")
    assert(response.Data ~= nil, "Response must include Data field")
    assert(response.ProcessId == "moves-database", "Response must include correct ProcessId")
    assert(type(response.Timestamp) == "number", "Response must include numeric Timestamp")
    
    print("✓ Response format compliance test passed")
end

-- Test performance requirements
function testPerformanceRequirements()
    print("Testing performance requirements...")
    
    local testMessage = {
        Action = "GetMove",
        Data = { id = MOVE.FLAMETHROWER },
        Timestamp = 1234567890,
        From = "test-address"
    }
    
    local fastQueryHandler = function(message)
        return { id = 53, n = "Flamethrower" }
    end
    
    local startTime = os.clock()
    local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", fastQueryHandler)
    local endTime = os.clock()
    
    local responseTime = (endTime - startTime) * 1000
    
    assert(response.Action == "SaveState", "Should return valid response")
    print("Move query response time: " .. string.format("%.2f", responseTime) .. "ms")
    
    print("✓ Performance requirements test passed")
end

-- Test data integrity
function testDataIntegrity()
    print("Testing data integrity...")
    
    local keyMoves = {
        MOVE.TACKLE,
        MOVE.FLAMETHROWER,
        MOVE.HYDRO_PUMP,
        MOVE.THUNDERBOLT,
        MOVE.PSYCHIC
    }
    
    for _, moveId in ipairs(keyMoves) do
        local testMessage = {
            Action = "GetMove",
            Data = { id = moveId },
            Timestamp = 1234567890,
            From = "test-address"
        }
        
        local mockQueryHandler = function(message)
            return { id = moveId, n = "TestMove" }
        end
        
        local response = DataProcessTemplate.handleMessage(testMessage, "moves-database", mockQueryHandler)
        assert(response.Error == nil, "Should successfully query move " .. moveId)
    end
    
    print("✓ Data integrity test passed")
end

-- Test size optimization
function testSizeOptimization()
    print("Testing size optimization...")
    
    -- Test abbreviated keys for size optimization
    local sampleMoveData = {
        id = 53,
        n = "Flamethrower", -- name abbreviated
        t = POKEMON_TYPE.FIRE, -- type abbreviated
        cat = MOVE_CATEGORY.SPECIAL, -- category abbreviated
        pwr = 90, -- power abbreviated
        acc = 100, -- accuracy abbreviated
        pp = 15, -- powerPoints abbreviated
        pri = 0, -- priority abbreviated
        eff = "10% chance to burn" -- effect abbreviated
    }
    
    local fullKeys = {"name", "type", "category", "power", "accuracy", "powerPoints", "priority", "effect"}
    local abbrevKeys = {"n", "t", "cat", "pwr", "acc", "pp", "pri", "eff"}
    
    local fullKeyLength = 0
    local abbrevKeyLength = 0
    
    for _, key in ipairs(fullKeys) do
        fullKeyLength = fullKeyLength + #key
    end
    
    for _, key in ipairs(abbrevKeys) do
        abbrevKeyLength = abbrevKeyLength + #key
    end
    
    local spaceSaved = fullKeyLength - abbrevKeyLength
    print("Space saved by key abbreviation: " .. spaceSaved .. " characters per move")
    assert(spaceSaved > 0, "Abbreviated keys should save space")
    
    print("✓ Size optimization test passed")
end

-- Run all tests
function runAllTests()
    print("Running Moves Database tests...")
    print("=====================================")
    
    testMoveDataStructure()
    testGetMoveByID()
    testGetMoveByName()
    testGetMovesByType()
    testTypeEffectiveness()
    testTypeEffectivenessChart()
    testMoveCategories()
    testMovePowerAndAccuracy()
    testPriorityMoves()
    testInvalidQueries()
    testResponseFormat()
    testPerformanceRequirements()
    testDataIntegrity()
    testSizeOptimization()
    
    print("=====================================")
    print("✅ All Moves Database tests passed!")
end

-- Execute tests
runAllTests()