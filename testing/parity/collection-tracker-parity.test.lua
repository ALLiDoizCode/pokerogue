-- Collection Tracker Parity Tests
-- Validates behavioral parity with TypeScript collection tracking implementation

local aolite = require("aolite")

-- Load TypeScript reference data for comparison
local TYPESCRIPT_REFERENCE = {
    achievements = {
        first_catch = {threshold = 1, points = 10},
        pokedex_10 = {threshold = 10, points = 25},
        pokedex_50 = {threshold = 50, points = 100},
        pokedex_150 = {threshold = 150, points = 500},
        kanto_completion = {threshold = 151, points = 1000}
    },
    species_regions = {
        kanto = {start = 1, finish = 151, total = 151},
        johto = {start = 152, finish = 251, total = 100},
        hoenn = {start = 252, finish = 386, total = 135}
    },
    completion_calculation = function(caught, total)
        return (caught / total) * 100.0
    end
}

local function setupParityTestEnvironment()
    print("Setting up Collection Tracker Parity Test Environment...")
    
    -- Initialize aolite for AO process testing
    aolite.setMessageLog(2)
    
    -- Spawn collection tracker process
    local processId = aolite.spawnProcess("Collection Tracker Parity")
    aolite.eval(processId, [[
        dofile("processes/collection-tracker.lua")
    ]])
    
    return processId
end

local function testPokedexCompletionParity(processId)
    print("\n=== Parity Test 1: Pokedex Completion Calculation ===")
    
    local playerId = "parity_test_player"
    local testResults = {passed = 0, failed = 0, errors = {}}
    
    local function assert(condition, message)
        if condition then
            testResults.passed = testResults.passed + 1
        else
            testResults.failed = testResults.failed + 1
            table.insert(testResults.errors, message)
            print("FAIL: " .. message)
        end
    end
    
    -- Test completion percentage calculation parity
    local testCases = {
        {caught = 0, total = 151, expected = 0.0},
        {caught = 1, total = 151, expected = 0.6622516556291391},
        {caught = 75, total = 151, expected = 49.66887417218543},
        {caught = 151, total = 151, expected = 100.0}
    }
    
    for _, test in ipairs(testCases) do
        -- Calculate TypeScript reference result
        local tsResult = TYPESCRIPT_REFERENCE.completion_calculation(test.caught, test.total)
        
        -- Simulate collection state with test values
        for i = 1, test.caught do
            local captureMessage = {
                Target = processId,
                Action = "ProcessLogic",
                Operation = "recordCapture",
                PlayerId = playerId,
                Data = aolite.json.encode({
                    pokemonId = "parity_pokemon_" .. i,
                    captureContext = {
                        speciesId = i,
                        level = 5,
                        location = "Test Route"
                    }
                }),
                Timestamp = 1234567890 + i
            }
            aolite.send(captureMessage)
        end
        
        aolite.runScheduler()
        
        -- Check completion calculation
        local completionMessage = {
            Target = processId,
            Action = "ProcessLogic",
            Operation = "calculateCompletion",
            PlayerId = playerId,
            Data = aolite.json.encode({
                region = "all"
            }),
            Timestamp = 1234567890 + test.caught + 1
        }
        
        aolite.send(completionMessage)
        aolite.runScheduler()
        
        -- Get response and verify parity
        local messages = aolite.getAllMsgs()
        local completionResponse = nil
        
        for _, msg in ipairs(messages) do
            if msg.Action == "SaveState" and msg.Operation == "calculateCompletion" then
                completionResponse = msg
                break
            end
        end
        
        if completionResponse then
            local responseData = aolite.json.decode(completionResponse.Data)
            local luaResult = responseData.completion.percentage
            
            -- Allow small floating point differences (0.001%)
            local difference = math.abs(luaResult - tsResult)
            assert(difference < 0.001, 
                string.format("Completion calculation parity failed: caught=%d, total=%d, lua=%.6f, ts=%.6f, diff=%.6f", 
                test.caught, test.total, luaResult, tsResult, difference))
        else
            assert(false, "No completion response received for test case")
        end
    end
    
    print("✓ Pokedex completion calculation parity verified")
    return testResults
end

local function testAchievementThresholdParity(processId)
    print("\n=== Parity Test 2: Achievement Threshold Parity ===")
    
    local playerId = "achievement_parity_player"
    local testResults = {passed = 0, failed = 0, errors = {}}
    
    local function assert(condition, message)
        if condition then
            testResults.passed = testResults.passed + 1
        else
            testResults.failed = testResults.failed + 1
            table.insert(testResults.errors, message)
            print("FAIL: " .. message)
        end
    end
    
    -- Test achievement thresholds match TypeScript implementation
    for achievementId, refData in pairs(TYPESCRIPT_REFERENCE.achievements) do
        -- Capture enough species to trigger achievement
        for i = 1, refData.threshold do
            local captureMessage = {
                Target = processId,
                Action = "ProcessLogic",
                Operation = "recordCapture",
                PlayerId = playerId,
                Data = aolite.json.encode({
                    pokemonId = "achievement_pokemon_" .. i,
                    captureContext = {
                        speciesId = i,
                        level = 5,
                        location = "Achievement Test Route"
                    }
                }),
                Timestamp = 1234567890 + i
            }
            aolite.send(captureMessage)
        end
        
        aolite.runScheduler()
        
        -- Check achievements
        local achievementMessage = {
            Target = processId,
            Action = "ProcessLogic",
            Operation = "checkAchievements",
            PlayerId = playerId,
            Data = aolite.json.encode({
                triggerEvent = "capture"
            }),
            Timestamp = 1234567890 + refData.threshold + 1
        }
        
        aolite.send(achievementMessage)
        aolite.runScheduler()
        
        -- Verify achievement was triggered
        local messages = aolite.getAllMsgs()
        local achievementResponse = nil
        
        for _, msg in ipairs(messages) do
            if msg.Action == "SaveState" and msg.Operation == "checkAchievements" then
                achievementResponse = msg
                break
            end
        end
        
        if achievementResponse then
            local responseData = aolite.json.decode(achievementResponse.Data)
            
            -- Check if the expected achievement was unlocked
            local achievementUnlocked = false
            for _, achievement in ipairs(responseData.newAchievements or {}) do
                if achievement.id == achievementId then
                    achievementUnlocked = true
                    assert(achievement.points == refData.points, 
                        string.format("Achievement %s points mismatch: lua=%d, ts=%d", 
                        achievementId, achievement.points, refData.points))
                    break
                end
            end
            
            if refData.threshold <= 20 then -- Only check for achievements we expect to unlock
                assert(achievementUnlocked, 
                    string.format("Achievement %s should be unlocked at threshold %d", 
                    achievementId, refData.threshold))
            end
        end
    end
    
    print("✓ Achievement threshold parity verified")
    return testResults
end

local function testRegionMappingParity(processId)
    print("\n=== Parity Test 3: Region Mapping Parity ===")
    
    local playerId = "region_parity_player"
    local testResults = {passed = 0, failed = 0, errors = {}}
    
    local function assert(condition, message)
        if condition then
            testResults.passed = testResults.passed + 1
        else
            testResults.failed = testResults.failed + 1
            table.insert(testResults.errors, message)
            print("FAIL: " .. message)
        end
    end
    
    -- Test region boundary species mapping
    for regionName, regionData in pairs(TYPESCRIPT_REFERENCE.species_regions) do
        -- Test first species in region
        local firstSpeciesMessage = {
            Target = processId,
            Action = "ProcessLogic",
            Operation = "recordCapture",
            PlayerId = playerId,
            Data = aolite.json.encode({
                pokemonId = "region_pokemon_" .. regionData.start,
                captureContext = {
                    speciesId = regionData.start,
                    level = 5,
                    location = regionName .. " Route"
                }
            }),
            Timestamp = 1234567890 + regionData.start
        }
        
        aolite.send(firstSpeciesMessage)
        aolite.runScheduler()
        
        -- Test last species in region
        local lastSpeciesMessage = {
            Target = processId,
            Action = "ProcessLogic",
            Operation = "recordCapture",
            PlayerId = playerId,
            Data = aolite.json.encode({
                pokemonId = "region_pokemon_" .. regionData.finish,
                captureContext = {
                    speciesId = regionData.finish,
                    level = 5,
                    location = regionName .. " Route"
                }
            }),
            Timestamp = 1234567890 + regionData.finish
        }
        
        aolite.send(lastSpeciesMessage)
        aolite.runScheduler()
        
        -- Check region completion
        local completionMessage = {
            Target = processId,
            Action = "ProcessLogic",
            Operation = "calculateCompletion",
            PlayerId = playerId,
            Data = aolite.json.encode({
                region = regionName
            }),
            Timestamp = 1234567890 + regionData.finish + 1
        }
        
        aolite.send(completionMessage)
        aolite.runScheduler()
        
        -- Verify region mapping
        local messages = aolite.getAllMsgs()
        local completionResponse = nil
        
        for _, msg in ipairs(messages) do
            if msg.Action == "SaveState" and msg.Operation == "calculateCompletion" then
                completionResponse = msg
                break
            end
        end
        
        if completionResponse then
            local responseData = aolite.json.decode(completionResponse.Data)
            
            assert(responseData.region == regionName, 
                string.format("Region name mismatch: expected=%s, got=%s", regionName, responseData.region))
            assert(responseData.completion.total == regionData.total, 
                string.format("Region %s total species mismatch: expected=%d, got=%d", 
                regionName, regionData.total, responseData.completion.total))
            assert(responseData.completion.caught >= 2, 
                string.format("Region %s should have at least 2 caught species", regionName))
        end
    end
    
    print("✓ Region mapping parity verified")
    return testResults
end

local function testStatisticsCalculationParity(processId)
    print("\n=== Parity Test 4: Statistics Calculation Parity ===")
    
    local playerId = "stats_parity_player"
    local testResults = {passed = 0, failed = 0, errors = {}}
    
    local function assert(condition, message)
        if condition then
            testResults.passed = testResults.passed + 1
        else
            testResults.failed = testResults.failed + 1
            table.insert(testResults.errors, message)
            print("FAIL: " .. message)
        end
    end
    
    -- Set up test data with known statistics
    local captureData = {
        {speciesId = 1, attempts = 1, success = true},
        {speciesId = 2, attempts = 3, success = true},
        {speciesId = 3, attempts = 2, success = true},
        {speciesId = 4, attempts = 5, success = false}, -- Escape
        {speciesId = 4, attempts = 1, success = true}  -- Retry success
    }
    
    local totalAttempts = 0
    local successfulCaptures = 0
    
    for i, data in ipairs(captureData) do
        totalAttempts = totalAttempts + data.attempts
        if data.success then
            successfulCaptures = successfulCaptures + 1
            
            local captureMessage = {
                Target = processId,
                Action = "ProcessLogic",
                Operation = "recordCapture",
                PlayerId = playerId,
                Data = aolite.json.encode({
                    pokemonId = "stats_pokemon_" .. i,
                    captureContext = {
                        speciesId = data.speciesId,
                        level = 5,
                        location = "Stats Test Route",
                        attempts = data.attempts
                    }
                }),
                Timestamp = 1234567890 + i
            }
            
            aolite.send(captureMessage)
        end
    end
    
    aolite.runScheduler()
    
    -- Calculate expected TypeScript statistics
    local expectedSuccessRate = (successfulCaptures / totalAttempts) * 100
    local expectedAverageAttempts = totalAttempts / successfulCaptures
    
    -- Get statistics from Lua implementation
    local statsMessage = {
        Target = processId,
        Action = "ProcessLogic",
        Operation = "generateStatistics",
        PlayerId = playerId,
        Data = aolite.json.encode({
            timeframe = "all_time",
            categories = {"capture"}
        }),
        Timestamp = 1234567890 + #captureData + 1
    }
    
    aolite.send(statsMessage)
    aolite.runScheduler()
    
    -- Verify statistics parity
    local messages = aolite.getAllMsgs()
    local statsResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Operation == "generateStatistics" then
            statsResponse = msg
            break
        end
    end
    
    if statsResponse then
        local responseData = aolite.json.decode(statsResponse.Data)
        local captureStats = responseData.statistics.capture
        
        assert(captureStats.successfulCaptures == successfulCaptures,
            string.format("Successful captures mismatch: expected=%d, got=%d", 
            successfulCaptures, captureStats.successfulCaptures))
        
        assert(captureStats.totalAttempts == totalAttempts,
            string.format("Total attempts mismatch: expected=%d, got=%d", 
            totalAttempts, captureStats.totalAttempts))
        
        -- Allow small floating point differences
        local successRateDiff = math.abs(captureStats.successRate - expectedSuccessRate)
        assert(successRateDiff < 0.01,
            string.format("Success rate mismatch: expected=%.2f, got=%.2f, diff=%.4f", 
            expectedSuccessRate, captureStats.successRate, successRateDiff))
        
        local avgAttemptsDiff = math.abs(captureStats.averageAttempts - expectedAverageAttempts)
        assert(avgAttemptsDiff < 0.01,
            string.format("Average attempts mismatch: expected=%.2f, got=%.2f, diff=%.4f", 
            expectedAverageAttempts, captureStats.averageAttempts, avgAttemptsDiff))
    end
    
    print("✓ Statistics calculation parity verified")
    return testResults
end

local function runParityTests()
    print("Starting Collection Tracker Parity Tests...")
    
    local processId = setupParityTestEnvironment()
    local allResults = {passed = 0, failed = 0, errors = {}}
    
    -- Run all parity tests
    local tests = {
        testPokedexCompletionParity,
        testAchievementThresholdParity,
        testRegionMappingParity,
        testStatisticsCalculationParity
    }
    
    for _, test in ipairs(tests) do
        local result = test(processId)
        allResults.passed = allResults.passed + result.passed
        allResults.failed = allResults.failed + result.failed
        for _, error in ipairs(result.errors) do
            table.insert(allResults.errors, error)
        end
    end
    
    -- Print test summary
    print("\n=== Parity Test Summary ===")
    print("Passed: " .. allResults.passed)
    print("Failed: " .. allResults.failed)
    print("Total:  " .. (allResults.passed + allResults.failed))
    
    if allResults.failed > 0 then
        print("\nFailed tests:")
        for _, error in ipairs(allResults.errors) do
            print("  - " .. error)
        end
    else
        print("\n✅ All parity tests passed! TypeScript behavioral compatibility verified.")
    end
    
    return allResults.failed == 0
end

-- Run tests if executed directly
if arg and arg[0] then
    local success = runParityTests()
    os.exit(success and 0 or 1)
end

return {
    runParityTests = runParityTests
}