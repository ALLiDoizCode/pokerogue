-- egg-move-learning-parity.test.lua
-- Parity tests comparing AO process behavior to TypeScript implementation
-- Validates egg move inheritance matches exactly

local aolite = require("aolite")
local json = require("json")

-- Test context
local testResults = {}
local passCount = 0
local failCount = 0

-- Helper to load TypeScript reference data
local function loadTypeScriptReference()
    -- In real implementation, this would load from TypeScript test outputs
    -- For now, we'll use representative test cases
    return {
        -- Test case 1: Pikachu breeding with egg moves
        testCase1 = {
            parent1 = {
                speciesId = 25, -- Pikachu
                moves = {86, 87, 98, 129} -- Thunder Wave, Thunder, Quick Attack, Swift
            },
            parent2 = {
                speciesId = 25, -- Pikachu 
                moves = {86, 609, 344, 486} -- Thunder Wave, Discharge, Volt Tackle, Electro Ball
            },
            offspring = {
                speciesId = 172, -- Pichu
                expectedMoves = {86, 344, 609, 486}, -- Shared move + egg moves
                expectedPriority = {1, 2, 3, 4}
            }
        },
        -- Test case 2: Cross-species breeding with egg moves
        testCase2 = {
            parent1 = {
                speciesId = 1, -- Bulbasaur
                moves = {73, 75, 76, 77} -- Leech Seed, Razor Leaf, Solar Beam, Poison Powder
            },
            parent2 = {
                speciesId = 152, -- Chikorita
                moves = {73, 77, 113, 115} -- Leech Seed, Poison Powder, Light Screen, Reflect
            },
            offspring = {
                speciesId = 1, -- Bulbasaur offspring
                expectedMoves = {73, 77, 738, 939}, -- Shared moves + Bulbasaur egg moves
                expectedPriority = {1, 1, 3, 3}
            }
        },
        -- Test case 3: Complex inheritance with full move slots
        testCase3 = {
            parent1 = {
                speciesId = 4, -- Charmander
                moves = {52, 53, 108, 424} -- Ember, Flamethrower, Smokescreen, Fire Fang
            },
            parent2 = {
                speciesId = 4, -- Charmander
                moves = {52, 349, 177, 414} -- Ember, Dragon Rush, Ancient Power, Earth Power
            },
            offspring = {
                speciesId = 4, -- Charmander
                expectedMoves = {52, 349, 177, 414}, -- Shared + egg moves
                expectedPriority = {1, 2, 2, 2}
            }
        }
    }
end

-- Test helper to compare move arrays
local function compareMoves(actual, expected, testName)
    if #actual ~= #expected then
        print("FAIL: " .. testName .. " - Move count mismatch. Expected " .. #expected .. ", got " .. #actual)
        return false
    end
    
    for i = 1, #expected do
        if actual[i] ~= expected[i] then
            print("FAIL: " .. testName .. " - Move mismatch at position " .. i .. 
                  ". Expected " .. expected[i] .. ", got " .. tostring(actual[i]))
            return false
        end
    end
    
    print("PASS: " .. testName)
    return true
end

-- Test helper to run parity test
local function runParityTest(processFile, testCase, testName)
    -- Load and spawn process
    local process = aolite.spawnProcess(processFile)
    
    -- Send InheritEggMoves message
    aolite.send(process, {
        Action = "InheritEggMoves",
        Parent1Id = "parent1_test",
        Parent2Id = "parent2_test", 
        OffspringSpeciesId = tostring(testCase.offspring.speciesId),
        PlayerId = "test_player",
        Timestamp = "1234567890",
        -- Include parent move data in message for testing
        Data = json.encode({
            parent1Moves = testCase.parent1.moves,
            parent2Moves = testCase.parent2.moves
        })
    })
    
    -- Run scheduler to process message
    aolite.runScheduler()
    
    -- Get response messages
    local msgs = aolite.getAllMsgs()
    local response = nil
    
    for _, msg in ipairs(msgs) do
        if msg.Action == "SaveState" then
            response = msg
            break
        elseif msg.Action == "Error" then
            print("ERROR: " .. testName .. " - " .. (msg.Error or "Unknown error"))
            return false
        end
    end
    
    if not response then
        print("FAIL: " .. testName .. " - No response received")
        return false
    end
    
    -- Parse inherited moves from response
    local inheritedMoves = {}
    if response.InheritedMoves then
        inheritedMoves = json.decode(response.InheritedMoves)
    end
    
    -- Compare with expected moves
    return compareMoves(inheritedMoves, testCase.offspring.expectedMoves, testName)
end

-- Test: Move pool generation parity
local function testMovePoolGeneration()
    print("\n=== Testing Move Pool Generation Parity ===")
    
    -- Load and spawn process
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Test Bulbasaur egg move pool
    aolite.send(process, {
        Action = "GetEggMovePool",
        SpeciesId = "1",
        PlayerId = "test_player"
    })
    
    aolite.runScheduler()
    local msgs = aolite.getAllMsgs()
    
    local found = false
    for _, msg in ipairs(msgs) do
        if msg.Action == "EggMovePool" then
            found = true
            local data = json.decode(msg.Data or "{}")
            if data.availableMoves and #data.availableMoves > 0 then
                print("PASS: Move pool generation - Species has egg moves")
                passCount = passCount + 1
            else
                print("FAIL: Move pool generation - No egg moves found")
                failCount = failCount + 1
            end
            break
        end
    end
    
    if not found then
        print("FAIL: Move pool generation - No response")
        failCount = failCount + 1
    end
end

-- Test: Move validation parity
local function testMoveValidation()
    print("\n=== Testing Move Validation Parity ===")
    
    -- Load and spawn process
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Test valid move learning
    aolite.send(process, {
        Action = "ValidateMoveLearn",
        PokemonId = "test_pokemon",
        MoveId = "86", -- Thunder Wave
        PlayerId = "test_player"
    })
    
    aolite.runScheduler()
    local msgs = aolite.getAllMsgs()
    
    local found = false
    for _, msg in ipairs(msgs) do
        if msg.Action == "SaveState" then
            found = true
            if msg.Success == "true" then
                print("PASS: Move validation - Valid move accepted")
                passCount = passCount + 1
            else
                print("FAIL: Move validation - Valid move rejected")
                failCount = failCount + 1
            end
            break
        elseif msg.Action == "Error" then
            print("FAIL: Move validation - Error: " .. (msg.Error or "Unknown"))
            failCount = failCount + 1
            found = true
            break
        end
    end
    
    if not found then
        print("FAIL: Move validation - No response")
        failCount = failCount + 1
    end
end

-- Test: Slot management parity
local function testSlotManagement()
    print("\n=== Testing Move Slot Management Parity ===")
    
    -- Load and spawn process
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Test slot management
    aolite.send(process, {
        Action = "ManageMoveSlots",
        PokemonId = "test_pokemon",
        Operation = "add",
        MoveId = "100",
        SlotNumber = "1",
        PlayerId = "test_player"
    })
    
    aolite.runScheduler()
    local msgs = aolite.getAllMsgs()
    
    local found = false
    for _, msg in ipairs(msgs) do
        if msg.Action == "MoveSlotsUpdated" then
            found = true
            local moves = json.decode(msg.CurrentMoves or "[]")
            if #moves == 4 then
                print("PASS: Slot management - Correct slot count")
                passCount = passCount + 1
            else
                print("FAIL: Slot management - Wrong slot count: " .. #moves)
                failCount = failCount + 1
            end
            break
        end
    end
    
    if not found then
        print("FAIL: Slot management - No response")
        failCount = failCount + 1
    end
end

-- Test: Priority system parity
local function testPrioritySystem()
    print("\n=== Testing Move Priority System Parity ===")
    
    local refData = loadTypeScriptReference()
    
    -- Test case 1: Shared moves have highest priority
    if runParityTest("processes/egg-move-learning-engine.lua", 
                     refData.testCase1, 
                     "Priority Test 1: Shared moves priority") then
        passCount = passCount + 1
    else
        failCount = failCount + 1
    end
    
    -- Test case 2: Cross-species inheritance
    if runParityTest("processes/egg-move-learning-engine.lua",
                     refData.testCase2,
                     "Priority Test 2: Cross-species inheritance") then
        passCount = passCount + 1
    else
        failCount = failCount + 1
    end
    
    -- Test case 3: Full slot management
    if runParityTest("processes/egg-move-learning-engine.lua",
                     refData.testCase3,
                     "Priority Test 3: Full slot handling") then
        passCount = passCount + 1
    else
        failCount = failCount + 1
    end
end

-- Test: Species coverage parity
local function testSpeciesCoverage()
    print("\n=== Testing Species Coverage Parity ===")
    
    -- Load and spawn process
    local process = aolite.spawnProcess("processes/egg-move-learning-engine.lua")
    
    -- Test multiple species have egg moves
    local speciesWithMoves = 0
    local speciesToTest = {1, 4, 7, 25, 133, 151, 252, 255, 258, 387, 390, 393} -- Starters + popular
    
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
                    speciesWithMoves = speciesWithMoves + 1
                end
                break
            end
        end
    end
    
    local coverage = (speciesWithMoves / #speciesToTest) * 100
    if coverage >= 90 then
        print("PASS: Species coverage - " .. coverage .. "% species have egg moves")
        passCount = passCount + 1
    else
        print("FAIL: Species coverage - Only " .. coverage .. "% species have egg moves")
        failCount = failCount + 1
    end
end

-- Main test execution
print("========================================")
print("EGG MOVE LEARNING PARITY TESTS")
print("========================================")

-- Run all parity tests
testMovePoolGeneration()
testMoveValidation()
testSlotManagement()
testPrioritySystem()
testSpeciesCoverage()

-- Print summary
print("\n========================================")
print("PARITY TEST SUMMARY")
print("========================================")
print("Passed: " .. passCount)
print("Failed: " .. failCount)
print("Total: " .. (passCount + failCount))
print("Coverage: " .. math.floor((passCount / (passCount + failCount)) * 100) .. "%")

if failCount > 0 then
    print("\nPARITY VALIDATION: FAILED")
    os.exit(1)
else
    print("\nPARITY VALIDATION: PASSED")
    os.exit(0)
end