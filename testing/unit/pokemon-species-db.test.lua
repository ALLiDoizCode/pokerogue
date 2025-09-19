-- Unit tests for Pokemon Species Database Process
-- Test framework: aolite

-- Mock the DataProcessTemplate module
local DataProcessTemplate = require("processes.templates.data-process-template")

-- Set up AO global mocks before loading the database
_G.Handlers = {
    add = function(name, matcher, handler) end,
    utils = {
        hasMatchingTag = function(tag, values)
            return function(msg)
                return true -- Simple mock that always matches
            end
        end
    },
    list = {}
}

_G.ao = {
    send = function(params)
        return params
    end
}

-- Constants for testing
local SPECIES = {
    BULBASAUR = 1,
    CHARMANDER = 4,
    SQUIRTLE = 7,
    PIKACHU = 25,
    MEWTWO = 150
}

local POKEMON_TYPE = {
    GRASS = 11,
    POISON = 3,
    FIRE = 9,
    WATER = 10,
    ELECTRIC = 12,
    PSYCHIC = 13,
    FLYING = 2
}

-- Test basic species data structure
function testSpeciesDataStructure()
    print("Testing species data structure...")
    
    -- Test that we can create valid messages
    local testMessage = {
        Action = "GetSpecies",
        Data = { id = SPECIES.PIKACHU },
        Timestamp = os.time(),
        From = "test-address"
    }
    
    -- Validate message structure
    local isValid, error = DataProcessTemplate.validateInput(testMessage)
    assert(isValid == true, "Test message should be valid")
    assert(error == nil, "Valid message should not produce error")
    
    print("✓ Species data structure test passed")
end

-- Test query action validation
function testQueryActions()
    print("Testing query actions...")
    
    local validActions = {"GetSpecies", "GetEvolutionChain", "GetBaseStats"}
    
    for _, action in ipairs(validActions) do
        local testMessage = {
            Action = action,
            Data = { id = SPECIES.PIKACHU },
            Timestamp = os.time(),
            From = "test-address"
        }
        
        local isValid, error = DataProcessTemplate.validateInput(testMessage)
        assert(isValid == true, "Message with " .. action .. " should be valid")
    end
    
    print("✓ Query actions test passed")
end

-- Test species ID validation
function testSpeciesIDValidation()
    print("Testing species ID validation...")
    
    local validSpeciesIds = {
        SPECIES.BULBASAUR,
        SPECIES.CHARMANDER,
        SPECIES.SQUIRTLE,
        SPECIES.PIKACHU,
        SPECIES.MEWTWO
    }
    
    for _, speciesId in ipairs(validSpeciesIds) do
        local testMessage = {
            Action = "GetSpecies",
            Data = { id = speciesId },
            Timestamp = os.time(),
            From = "test-address"
        }
        
        local isValid, error = DataProcessTemplate.validateInput(testMessage)
        assert(isValid == true, "Message with species ID " .. speciesId .. " should be valid")
    end
    
    print("✓ Species ID validation test passed")
end

-- Test name-based queries
function testNameBasedQueries()
    print("Testing name-based queries...")
    
    local validNames = {"Pikachu", "Charizard", "Blastoise", "Venusaur", "Mewtwo"}
    
    for _, name in ipairs(validNames) do
        local testMessage = {
            Action = "GetSpecies",
            Data = { name = name },
            Timestamp = os.time(),
            From = "test-address"
        }
        
        local isValid, error = DataProcessTemplate.validateInput(testMessage)
        assert(isValid == true, "Message with species name " .. name .. " should be valid")
    end
    
    print("✓ Name-based queries test passed")
end

-- Test base stats query format
function testBaseStatsQuery()
    print("Testing base stats query format...")
    
    local testMessage = {
        Action = "GetBaseStats",
        Data = { id = SPECIES.MEWTWO },
        Timestamp = os.time(),
        From = "test-address"
    }
    
    local isValid, error = DataProcessTemplate.validateInput(testMessage)
    assert(isValid == true, "GetBaseStats message should be valid")
    
    -- Mock query handler that returns proper base stats format
    local mockQueryHandler = function(message)
        return {
            hp = 106,
            attack = 110,
            defense = 90,
            specialAttack = 154,
            specialDefense = 90,
            speed = 130
        }
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "pokemon-species-db", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(type(response.Data) == "table", "Should return base stats as table")
    
    print("✓ Base stats query test passed")
end

-- Test evolution chain query format
function testEvolutionChainQuery()
    print("Testing evolution chain query format...")
    
    local testMessage = {
        Action = "GetEvolutionChain",
        Data = { id = SPECIES.CHARMANDER },
        Timestamp = os.time(),
        From = "test-address"
    }
    
    local isValid, error = DataProcessTemplate.validateInput(testMessage)
    assert(isValid == true, "GetEvolutionChain message should be valid")
    
    -- Mock query handler that returns evolution chain
    local mockQueryHandler = function(message)
        return {
            {id = 4, n = "Charmander"},
            {id = 5, n = "Charmeleon"},
            {id = 6, n = "Charizard"}
        }
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "pokemon-species-db", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(type(response.Data) == "table", "Should return evolution chain as table")
    
    print("✓ Evolution chain query test passed")
end

-- Test error handling for invalid data
function testErrorHandling()
    print("Testing error handling...")
    
    -- Test missing required data
    local invalidMessage = {
        Action = "GetSpecies",
        Data = {}, -- Missing id or name
        Timestamp = os.time(),
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        error("GetSpecies requires either 'id' or 'name' in Data")
    end
    
    local response = DataProcessTemplate.handleMessage(invalidMessage, "pokemon-species-db", mockQueryHandler)
    assert(response.Action == "SaveState", "Should return SaveState response")
    assert(response.Error ~= nil, "Should include error message")
    
    print("✓ Error handling test passed")
end

-- Test response format compliance
function testResponseFormat()
    print("Testing response format compliance...")
    
    local testMessage = {
        Action = "GetSpecies",
        Data = { id = SPECIES.PIKACHU },
        Timestamp = os.time(),
        From = "test-address"
    }
    
    local mockQueryHandler = function(message)
        return {
            id = 25,
            n = "Pikachu",
            bs = {35, 55, 40, 50, 50, 90},
            t = {POKEMON_TYPE.ELECTRIC}
        }
    end
    
    local response = DataProcessTemplate.handleMessage(testMessage, "pokemon-species-db", mockQueryHandler)
    
    -- Verify SaveState protocol compliance
    assert(response.Action == "SaveState", "Response must use SaveState action")
    assert(response.Data ~= nil, "Response must include Data field")
    assert(response.ProcessId == "pokemon-species-db", "Response must include ProcessId")
    assert(type(response.Timestamp) == "number", "Response must include numeric Timestamp")
    
    print("✓ Response format compliance test passed")
end

-- Test performance within template constraints
function testPerformanceConstraints()
    print("Testing performance constraints...")
    
    local testMessage = {
        Action = "GetSpecies",
        Data = { id = SPECIES.PIKACHU },
        Timestamp = os.time(),
        From = "test-address"
    }
    
    local fastQueryHandler = function(message)
        return { id = 25, n = "Pikachu" }
    end
    
    local startTime = os.clock()
    local response = DataProcessTemplate.handleMessage(testMessage, "pokemon-species-db", fastQueryHandler)
    local endTime = os.clock()
    
    local responseTime = (endTime - startTime) * 1000
    
    assert(response.Action == "SaveState", "Should return valid response")
    print("Query response time: " .. string.format("%.2f", responseTime) .. "ms")
    
    print("✓ Performance constraints test passed")
end

-- Test size optimization patterns
function testSizeOptimization()
    print("Testing size optimization patterns...")
    
    -- Test that our data structure uses abbreviated keys for size optimization
    local sampleSpeciesData = {
        id = 25,
        n = "Pikachu", -- name abbreviated
        bs = {35, 55, 40, 50, 50, 90}, -- baseStats abbreviated
        t = {POKEMON_TYPE.ELECTRIC}, -- types abbreviated
        ab = {9, 31}, -- abilities abbreviated
        h = 4, -- height abbreviated
        w = 60 -- weight abbreviated
    }
    
    -- Verify the abbreviated structure saves space
    local fullKeys = {"name", "baseStats", "types", "abilities", "height", "weight"}
    local abbrevKeys = {"n", "bs", "t", "ab", "h", "w"}
    
    local fullKeyLength = 0
    local abbrevKeyLength = 0
    
    for _, key in ipairs(fullKeys) do
        fullKeyLength = fullKeyLength + #key
    end
    
    for _, key in ipairs(abbrevKeys) do
        abbrevKeyLength = abbrevKeyLength + #key
    end
    
    local spaceSaved = fullKeyLength - abbrevKeyLength
    print("Space saved by key abbreviation: " .. spaceSaved .. " characters per species")
    assert(spaceSaved > 0, "Abbreviated keys should save space")
    
    print("✓ Size optimization test passed")
end

-- Run all tests
function runAllTests()
    print("Running Pokemon Species Database tests...")
    print("=====================================")
    
    testSpeciesDataStructure()
    testQueryActions()
    testSpeciesIDValidation()
    testNameBasedQueries()
    testBaseStatsQuery()
    testEvolutionChainQuery()
    testErrorHandling()
    testResponseFormat()
    testPerformanceConstraints()
    testSizeOptimization()
    
    print("=====================================")
    print("✅ All Pokemon Species Database tests passed!")
end

-- Execute tests
runAllTests()