-- Collection Tracker Unit Tests
-- Tests all core collection operations, achievement system, and analytics

local function runTests()
    local testResults = {
        passed = 0,
        failed = 0,
        errors = {}
    }
    
    local function assert(condition, message)
        if condition then
            testResults.passed = testResults.passed + 1
        else
            testResults.failed = testResults.failed + 1
            table.insert(testResults.errors, message)
            print("FAIL: " .. message)
        end
    end
    
    print("Starting Collection Tracker Unit Tests...")
    
    -- Load the collection tracker process
    dofile("processes/collection-tracker.lua")
    
    -- Test 1: Collection State Creation
    print("\n=== Test 1: Collection State Creation ===")
    
    -- Test creating a new collection
    local testPlayerId = "test_player_123"
    local mockCapture = {
        speciesId = 1, -- Bulbasaur
        level = 5,
        location = "Route 1",
        method = "pokeball",
        attempts = 1,
        critical = false
    }
    
    -- Simulate recordCapture operation
    local result = recordCapture(testPlayerId, "pokemon_123", mockCapture, 1234567890)
    assert(result.success == true, "Collection state should be created successfully")
    assert(result.wasNewSpecies == true, "First capture should be a new species")
    assert(result.speciesId == 1, "Species ID should match")
    
    -- Test 2: Pokedex Progress Tracking
    print("\n=== Test 2: Pokedex Progress Tracking ===")
    
    -- Test multiple captures
    local captureResults = {}
    for i = 2, 5 do
        local capture = {
            speciesId = i,
            level = 5,
            location = "Route 1",
            method = "pokeball",
            attempts = 1
        }
        local result = recordCapture(testPlayerId, "pokemon_" .. i, capture, 1234567890 + i)
        table.insert(captureResults, result)
        assert(result.success == true, "Capture " .. i .. " should succeed")
    end
    
    -- Verify completion calculation
    local completion = calculateCompletion(testPlayerId, "all", nil, 1234567895)
    assert(completion.success == true, "Completion calculation should succeed")
    assert(completion.completion.caught == 5, "Should have 5 caught species")
    assert(completion.completion.percentage > 0, "Completion percentage should be > 0")
    
    -- Test 3: Achievement System
    print("\n=== Test 3: Achievement System ===")
    
    -- Check achievements after first capture
    local achievementResult = checkAchievements(testPlayerId, "capture", {speciesId = 1}, 1234567896)
    assert(achievementResult.success == true, "Achievement check should succeed")
    assert(#achievementResult.newAchievements >= 1, "Should unlock first_catch achievement")
    
    -- Check 10-species achievement after more captures
    for i = 6, 10 do
        local capture = {
            speciesId = i,
            level = 5,
            location = "Route 1"
        }
        recordCapture(testPlayerId, "pokemon_" .. i, capture, 1234567890 + i)
    end
    
    local achievement10 = checkAchievements(testPlayerId, "capture", {speciesId = 10}, 1234567900)
    assert(achievement10.success == true, "10-species achievement check should succeed")
    
    -- Test 4: Statistics Generation
    print("\n=== Test 4: Statistics Generation ===")
    
    local stats = generateStatistics(testPlayerId, "all_time", {"capture", "progress"}, 1234567901)
    assert(stats.success == true, "Statistics generation should succeed")
    assert(stats.statistics.capture ~= nil, "Capture statistics should exist")
    assert(stats.statistics.progress ~= nil, "Progress statistics should exist")
    assert(stats.statistics.capture.successfulCaptures == 10, "Should have 10 successful captures")
    
    -- Test 5: Encounter Tracking
    print("\n=== Test 5: Encounter Tracking ===")
    
    local encounter = recordEncounter(testPlayerId, 25, {location = "Route 2", level = 3}, 1234567902)
    assert(encounter.success == true, "Encounter recording should succeed")
    assert(encounter.wasNewSighting == true, "Should be a new sighting")
    
    -- Test same species encounter
    local encounter2 = recordEncounter(testPlayerId, 25, {location = "Route 2", level = 4}, 1234567903)
    assert(encounter2.success == true, "Second encounter should succeed")
    assert(encounter2.wasNewSighting == false, "Should not be a new sighting")
    
    -- Test 6: Collection Gaps Analysis
    print("\n=== Test 6: Collection Gaps Analysis ===")
    
    local gaps = analyzeCollectionGaps(testPlayerId, "kanto", "missing")
    assert(gaps.success == true, "Gap analysis should succeed")
    assert(#gaps.gaps > 0, "Should have missing species in Kanto")
    
    -- Test 7: Progress Velocity Calculation
    print("\n=== Test 7: Progress Velocity Calculation ===")
    
    local velocity = calculateProgressVelocity(testPlayerId, 7, 1234567904)
    assert(velocity.success == true, "Velocity calculation should succeed")
    assert(velocity.velocities.capturesPerDay >= 0, "Capture velocity should be non-negative")
    
    -- Test 8: Goal Management
    print("\n=== Test 8: Goal Management ===")
    
    local goalDef = {
        type = "species_milestone",
        threshold = 50,
        priority = "high"
    }
    local goal = createGoal(testPlayerId, goalDef, 1234567905)
    assert(goal.success == true, "Goal creation should succeed")
    assert(goal.goal.threshold == 50, "Goal threshold should be 50")
    
    -- Test 9: Collection Export
    print("\n=== Test 9: Collection Export ===")
    
    local export = exportCollection(testPlayerId, "json", {}, 1234567906)
    assert(export.success == true, "Collection export should succeed")
    assert(export.format == "json", "Export format should be JSON")
    assert(export.exportData ~= nil, "Export data should exist")
    
    -- Test 10: Input Validation
    print("\n=== Test 10: Input Validation ===")
    
    -- Test invalid species ID
    local invalidCapture = recordCapture(testPlayerId, "pokemon_999", {speciesId = 9999}, 1234567907)
    assert(invalidCapture.success == false, "Invalid species ID should fail")
    
    -- Test missing parameters
    local missingParams = recordCapture(nil, nil, nil, 1234567908)
    assert(missingParams.success == false, "Missing parameters should fail")
    
    -- Test 11: State Validation
    print("\n=== Test 11: State Validation ===")
    
    -- Get collection state and validate
    if playerCollections[testPlayerId] then
        local fixes = validateCollectionState(playerCollections[testPlayerId])
        assert(type(fixes) == "table", "Validation fixes should return table")
        print("State validation completed with " .. #fixes .. " fixes")
    end
    
    -- Print test summary
    print("\n=== Test Summary ===")
    print("Passed: " .. testResults.passed)
    print("Failed: " .. testResults.failed)
    print("Total:  " .. (testResults.passed + testResults.failed))
    
    if testResults.failed > 0 then
        print("\nFailed tests:")
        for _, error in ipairs(testResults.errors) do
            print("  - " .. error)
        end
    end
    
    return testResults.failed == 0
end

-- Run tests if executed directly
if arg and arg[0] then
    local success = runTests()
    os.exit(success and 0 or 1)
end

return {
    runTests = runTests
}