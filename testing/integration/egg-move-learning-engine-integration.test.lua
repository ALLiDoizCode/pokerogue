-- egg-move-learning-engine-integration.test.lua
-- Integration tests for egg move learning process using aos-local
-- Tests cross-process communication and coordination

local aolite = require("aolite")
local json = require("json")

-- Test results tracking
local passCount = 0
local failCount = 0

-- Helper function to setup test environment
local function setupTestProcesses()
    -- Load main egg move process
    local eggMoveProcess = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Create mock breeding compatibility process
    local breedingProcess = aolite.spawn(function()
        Handlers = {}
        Handlers.utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg[tag] == value
                end
            end
        }
        Handlers.add = function(name, matcher, handler)
            -- Simple handler registration
        end
        
        ao = {
            send = function(msg)
                -- Mock send
            end
        }
    end)
    
    -- Create mock species database process
    local speciesProcess = aolite.spawn(function()
        Handlers = {}
        Handlers.utils = {
            hasMatchingTag = function(tag, value)
                return function(msg)
                    return msg[tag] == value
                end
            end
        }
        Handlers.add = function(name, matcher, handler)
            -- Simple handler registration
        end
        
        ao = {
            send = function(msg)
                -- Mock send
            end
        }
    end)
    
    return {
        eggMove = eggMoveProcess,
        breeding = breedingProcess,
        species = speciesProcess
    }
end

-- Test 1: Process initialization and Info handler
local function testProcessInitialization()
    print("\n=== Test: Process Initialization ===")
    
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Send Info request
    aolite.send(process, {
        Action = "Info"
    })
    
    aolite.runScheduler()
    local msgs = aolite.getAllMsgs()
    
    local found = false
    for _, msg in ipairs(msgs) do
        if msg.Action == "SaveState" and msg.Data then
            local data = json.decode(msg.Data)
            if data.process and data.process.name == "Egg Move Learning Engine" then
                print("PASS: Process initialized with correct metadata")
                passCount = passCount + 1
                found = true
            end
        end
    end
    
    if not found then
        print("FAIL: Process initialization failed")
        failCount = failCount + 1
    end
end

-- Test 2: Configure process IDs
local function testConfigureProcessIds()
    print("\n=== Test: Configure Process IDs ===")
    
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Configure process IDs
    aolite.send(process, {
        Action = "ConfigureProcessIds",
        BreedingCompatibilityId = "breeding_test",
        GeneticInheritanceId = "genetic_test",
        SpeciesDbId = "species_test",
        MovesDbId = "moves_test",
        InstanceManagerId = "instance_test"
    })
    
    aolite.runScheduler()
    local msgs = aolite.getAllMsgs()
    
    local found = false
    for _, msg in ipairs(msgs) do
        if msg.Action == "ProcessIdsConfigured" and msg.Success == "true" then
            if msg.BreedingCompatibilityId == "breeding_test" and
               msg.SpeciesDbId == "species_test" then
                print("PASS: Process IDs configured successfully")
                passCount = passCount + 1
                found = true
            end
        end
    end
    
    if not found then
        print("FAIL: Process ID configuration failed")
        failCount = failCount + 1
    end
end

-- Test 3: Egg move inheritance with parent data
local function testEggMoveInheritance()
    print("\n=== Test: Egg Move Inheritance ===")
    
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Test inheritance for Bulbasaur
    aolite.send(process, {
        Action = "InheritEggMoves",
        Parent1Id = "parent1",
        Parent2Id = "parent2",
        OffspringSpeciesId = "1", -- Bulbasaur
        PlayerId = "test_player",
        Timestamp = "1234567890",
        Data = json.encode({
            parent1Moves = {73, 75, 76, 77}, -- Parent 1 moves
            parent2Moves = {73, 75, 412, 402}  -- Parent 2 moves
        })
    })
    
    aolite.runScheduler()
    local msgs = aolite.getAllMsgs()
    
    local found = false
    for _, msg in ipairs(msgs) do
        if msg.Action == "SaveState" and msg.Success == "true" then
            if msg.InheritedMoves then
                local moves = json.decode(msg.InheritedMoves)
                if #moves > 0 then
                    print("PASS: Egg moves inherited: " .. #moves .. " moves")
                    passCount = passCount + 1
                    found = true
                end
            end
        end
    end
    
    if not found then
        print("FAIL: Egg move inheritance failed")
        failCount = failCount + 1
    end
end

-- Test 4: Get egg move pool for species
local function testGetEggMovePool()
    print("\n=== Test: Get Egg Move Pool ===")
    
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Test popular species
    local speciesToTest = {1, 4, 7, 25, 133, 252, 255, 258}
    local successCount = 0
    
    for _, speciesId in ipairs(speciesToTest) do
        aolite.send(process, {
            Action = "GetEggMovePool",
            SpeciesId = tostring(speciesId),
            PlayerId = "test_player"
        })
        
        aolite.runScheduler()
        local msgs = aolite.getAllMsgs()
        
        for _, msg in ipairs(msgs) do
            if msg.Action == "EggMovePool" and msg.SpeciesId == tostring(speciesId) then
                local data = json.decode(msg.Data or "{}")
                if data.availableMoves and #data.availableMoves > 0 then
                    successCount = successCount + 1
                end
                break
            end
        end
    end
    
    if successCount == #speciesToTest then
        print("PASS: All " .. successCount .. " species have egg move pools")
        passCount = passCount + 1
    else
        print("FAIL: Only " .. successCount .. "/" .. #speciesToTest .. " species have egg move pools")
        failCount = failCount + 1
    end
end

-- Test 5: Validate move learning
local function testValidateMoveLearn()
    print("\n=== Test: Validate Move Learning ===")
    
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Test valid move
    aolite.send(process, {
        Action = "ValidateMoveLearn",
        PokemonId = "test_pokemon",
        MoveId = "73", -- Leech Seed
        PlayerId = "test_player"
    })
    
    aolite.runScheduler()
    local msgs = aolite.getAllMsgs()
    
    local validFound = false
    for _, msg in ipairs(msgs) do
        if msg.Action == "SaveState" and msg.Success == "true" then
            print("PASS: Valid move learning accepted")
            passCount = passCount + 1
            validFound = true
            break
        end
    end
    
    if not validFound then
        print("FAIL: Valid move learning rejected")
        failCount = failCount + 1
    end
    
    -- Test invalid move (missing required params)
    aolite.send(process, {
        Action = "ValidateMoveLearn",
        PokemonId = "test_pokemon"
        -- Missing MoveId
    })
    
    aolite.runScheduler()
    msgs = aolite.getAllMsgs()
    
    local errorFound = false
    for _, msg in ipairs(msgs) do
        if msg.Action == "Error" then
            print("PASS: Invalid request properly rejected")
            passCount = passCount + 1
            errorFound = true
            break
        end
    end
    
    if not errorFound then
        print("FAIL: Invalid request not rejected")
        failCount = failCount + 1
    end
end

-- Test 6: Manage move slots
local function testManageMoveSlots()
    print("\n=== Test: Manage Move Slots ===")
    
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Test add operation
    aolite.send(process, {
        Action = "ManageMoveSlots",
        PokemonId = "test_pokemon",
        Operation = "add",
        MoveId = "86",
        SlotNumber = "1",
        PlayerId = "test_player"
    })
    
    aolite.runScheduler()
    local msgs = aolite.getAllMsgs()
    
    local found = false
    for _, msg in ipairs(msgs) do
        if msg.Action == "MoveSlotsUpdated" and msg.Success == "true" then
            local moves = json.decode(msg.CurrentMoves or "[]")
            if #moves == 4 then
                print("PASS: Move slots updated correctly")
                passCount = passCount + 1
                found = true
            end
            break
        end
    end
    
    if not found then
        print("FAIL: Move slot management failed")
        failCount = failCount + 1
    end
end

-- Test 7: Cross-process message format validation
local function testMessageFormatCompliance()
    print("\n=== Test: Message Format Compliance ===")
    
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Send message with proper tags and Data field usage
    aolite.send(process, {
        Action = "InheritEggMoves",
        Parent1Id = "parent1",
        Parent2Id = "parent2",
        OffspringSpeciesId = "25", -- Pikachu
        PlayerId = "test_player",
        Timestamp = "1234567890",
        Data = json.encode({
            parent1Moves = {86, 87, 98, 129},
            parent2Moves = {86, 609, 344, 486}
        })
    })
    
    aolite.runScheduler()
    local msgs = aolite.getAllMsgs()
    
    local found = false
    for _, msg in ipairs(msgs) do
        if msg.Action == "SaveState" then
            -- Check proper use of tags vs Data field
            if msg.Success and type(msg.Success) == "string" and
               msg.InheritedMoves and type(msg.InheritedMoves) == "string" then
                print("PASS: Message format complies with AO standards")
                passCount = passCount + 1
                found = true
            end
            break
        end
    end
    
    if not found then
        print("FAIL: Message format non-compliant")
        failCount = failCount + 1
    end
end

-- Test 8: Database completeness
local function testDatabaseCompleteness()
    print("\n=== Test: Egg Move Database Completeness ===")
    
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Test a large sample of species
    local sampleSize = 50
    local speciesWithMoves = 0
    
    for i = 1, sampleSize do
        local speciesId = math.random(1, 700) -- Sample from gen 1-6
        
        aolite.send(process, {
            Action = "GetEggMovePool",
            SpeciesId = tostring(speciesId),
            PlayerId = "test_player"
        })
        
        aolite.runScheduler()
        local msgs = aolite.getAllMsgs()
        
        for _, msg in ipairs(msgs) do
            if msg.Action == "EggMovePool" and msg.SpeciesId == tostring(speciesId) then
                local data = json.decode(msg.Data or "{}")
                if data.availableMoves and #data.availableMoves > 0 then
                    speciesWithMoves = speciesWithMoves + 1
                end
                break
            end
        end
    end
    
    local coverage = (speciesWithMoves / sampleSize) * 100
    if coverage >= 80 then
        print("PASS: Database coverage " .. coverage .. "%")
        passCount = passCount + 1
    else
        print("FAIL: Database coverage only " .. coverage .. "%")
        failCount = failCount + 1
    end
end

-- Main test execution
print("========================================")
print("EGG MOVE LEARNING INTEGRATION TESTS")
print("========================================")

-- Run all integration tests
testProcessInitialization()
testConfigureProcessIds()
testEggMoveInheritance()
testGetEggMovePool()
testValidateMoveLearn()
testManageMoveSlots()
testMessageFormatCompliance()
testDatabaseCompleteness()

-- Print summary
print("\n========================================")
print("INTEGRATION TEST SUMMARY")
print("========================================")
print("Passed: " .. passCount)
print("Failed: " .. failCount)
print("Total: " .. (passCount + failCount))
print("Success Rate: " .. math.floor((passCount / (passCount + failCount)) * 100) .. "%")

if failCount > 0 then
    print("\nINTEGRATION TESTS: FAILED")
    os.exit(1)
else
    print("\nINTEGRATION TESTS: PASSED")
    os.exit(0)
end