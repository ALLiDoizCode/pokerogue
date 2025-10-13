-- Collection Tracker Integration Tests
-- Tests cross-process coordination and message passing with related processes

local aolite = require("aolite")

-- Test configuration
local TEST_CONFIG = {
    timeout = 30000, -- 30 seconds
    processes = {
        collectionTracker = "collection-tracker",
        pokemonManager = "pokemon-instance-manager", 
        captureEngine = "capture-engine",
        pcStorage = "pc-storage-manager"
    }
}

local function setupTestEnvironment()
    print("Setting up Collection Tracker Integration Test Environment...")
    
    -- Initialize aolite environment
    aolite.setMessageLog(3) -- Verbose logging
    
    -- Load and spawn processes
    local processes = {}
    
    -- Spawn collection tracker process
    processes.collectionTracker = aolite.spawnProcess("Collection Tracker")
    aolite.eval(processes.collectionTracker, [[
        dofile("processes/collection-tracker.lua")
    ]])
    
    print("Collection Tracker process spawned: " .. processes.collectionTracker)
    
    return processes
end

local function testBasicCollectionOperations(processes)
    print("\n=== Integration Test 1: Basic Collection Operations ===")
    
    local playerId = "integration_test_player"
    local testTimestamp = 1234567890
    
    -- Test record capture operation
    local captureMessage = {
        Target = processes.collectionTracker,
        Action = "ProcessLogic",
        Operation = "recordCapture",
        PlayerId = playerId,
        Data = aolite.json.encode({
            pokemonId = "test_pokemon_001",
            captureContext = {
                speciesId = 1, -- Bulbasaur
                level = 5,
                location = "Route 1",
                method = "pokeball",
                attempts = 1,
                critical = false
            }
        }),
        Timestamp = testTimestamp
    }
    
    aolite.send(captureMessage)
    aolite.runScheduler()
    
    -- Get response messages
    local messages = aolite.getAllMsgs()
    local captureResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Operation == "recordCapture" then
            captureResponse = msg
            break
        end
    end
    
    assert(captureResponse ~= nil, "Should receive capture response")
    assert(captureResponse.Success == "true", "Capture should succeed")
    
    local responseData = aolite.json.decode(captureResponse.Data)
    assert(responseData.success == true, "Response should indicate success")
    assert(responseData.wasNewSpecies == true, "Should be new species")
    
    print("✓ Basic capture operation successful")
end

local function testEncounterTracking(processes)
    print("\n=== Integration Test 2: Encounter Tracking ===")
    
    local playerId = "integration_test_player"
    local testTimestamp = 1234567891
    
    -- Test record encounter operation
    local encounterMessage = {
        Target = processes.collectionTracker,
        Action = "ProcessLogic",
        Operation = "recordEncounter",
        PlayerId = playerId,
        Data = aolite.json.encode({
            speciesId = 25, -- Pikachu
            encounterContext = {
                location = "Route 2",
                level = 3,
                shiny = false,
                rare = true
            }
        }),
        Timestamp = testTimestamp
    }
    
    aolite.send(encounterMessage)
    aolite.runScheduler()
    
    -- Verify encounter was recorded
    local messages = aolite.getAllMsgs()
    local encounterResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Operation == "recordEncounter" then
            encounterResponse = msg
            break
        end
    end
    
    assert(encounterResponse ~= nil, "Should receive encounter response")
    assert(encounterResponse.Success == "true", "Encounter should succeed")
    
    local responseData = aolite.json.decode(encounterResponse.Data)
    assert(responseData.success == true, "Response should indicate success")
    assert(responseData.wasNewSighting == true, "Should be new sighting")
    
    print("✓ Encounter tracking successful")
end

local function testAchievementSystem(processes)
    print("\n=== Integration Test 3: Achievement System ===")
    
    local playerId = "integration_test_player"
    local testTimestamp = 1234567892
    
    -- Test achievement checking
    local achievementMessage = {
        Target = processes.collectionTracker,
        Action = "ProcessLogic",
        Operation = "checkAchievements",
        PlayerId = playerId,
        Data = aolite.json.encode({
            triggerEvent = "capture",
            speciesId = 1
        }),
        Timestamp = testTimestamp
    }
    
    aolite.send(achievementMessage)
    aolite.runScheduler()
    
    -- Verify achievements were checked
    local messages = aolite.getAllMsgs()
    local achievementResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Operation == "checkAchievements" then
            achievementResponse = msg
            break
        end
    end
    
    assert(achievementResponse ~= nil, "Should receive achievement response")
    assert(achievementResponse.Success == "true", "Achievement check should succeed")
    
    local responseData = aolite.json.decode(achievementResponse.Data)
    assert(responseData.success == true, "Response should indicate success")
    
    print("✓ Achievement system functional")
end

local function testStatisticsGeneration(processes)
    print("\n=== Integration Test 4: Statistics Generation ===")
    
    local playerId = "integration_test_player"
    local testTimestamp = 1234567893
    
    -- Test statistics generation
    local statsMessage = {
        Target = processes.collectionTracker,
        Action = "ProcessLogic",
        Operation = "generateStatistics",
        PlayerId = playerId,
        Data = aolite.json.encode({
            timeframe = "all_time",
            categories = {"capture", "encounter", "progress", "achievement"}
        }),
        Timestamp = testTimestamp
    }
    
    aolite.send(statsMessage)
    aolite.runScheduler()
    
    -- Verify statistics were generated
    local messages = aolite.getAllMsgs()
    local statsResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Operation == "generateStatistics" then
            statsResponse = msg
            break
        end
    end
    
    assert(statsResponse ~= nil, "Should receive statistics response")
    assert(statsResponse.Success == "true", "Statistics generation should succeed")
    
    local responseData = aolite.json.decode(statsResponse.Data)
    assert(responseData.success == true, "Response should indicate success")
    assert(responseData.statistics ~= nil, "Should have statistics data")
    
    print("✓ Statistics generation successful")
end

local function testCollectionExport(processes)
    print("\n=== Integration Test 5: Collection Export ===")
    
    local playerId = "integration_test_player"
    local testTimestamp = 1234567894
    
    -- Test collection export
    local exportMessage = {
        Target = processes.collectionTracker,
        Action = "ProcessLogic",
        Operation = "exportCollection",
        PlayerId = playerId,
        Data = aolite.json.encode({
            format = "json",
            options = {}
        }),
        Timestamp = testTimestamp
    }
    
    aolite.send(exportMessage)
    aolite.runScheduler()
    
    -- Verify export was successful
    local messages = aolite.getAllMsgs()
    local exportResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Operation == "exportCollection" then
            exportResponse = msg
            break
        end
    end
    
    assert(exportResponse ~= nil, "Should receive export response")
    assert(exportResponse.Success == "true", "Export should succeed")
    
    local responseData = aolite.json.decode(exportResponse.Data)
    assert(responseData.success == true, "Response should indicate success")
    assert(responseData.exportData ~= nil, "Should have export data")
    
    print("✓ Collection export successful")
end

local function testADPCompliance(processes)
    print("\n=== Integration Test 6: ADP v1.0 Compliance ===")
    
    -- Test Info handler for ADP compliance
    local infoMessage = {
        Target = processes.collectionTracker,
        Action = "Info"
    }
    
    aolite.send(infoMessage)
    aolite.runScheduler()
    
    -- Verify ADP response
    local messages = aolite.getAllMsgs()
    local infoResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data then
            local data = aolite.json.decode(msg.Data)
            if data.process and data.process.adpVersion then
                infoResponse = data
                break
            end
        end
    end
    
    assert(infoResponse ~= nil, "Should receive ADP info response")
    assert(infoResponse.process.adpVersion == "1.0", "Should be ADP v1.0 compliant")
    assert(infoResponse.process.capabilities ~= nil, "Should have capabilities")
    assert(#infoResponse.process.capabilities > 0, "Should have at least one capability")
    
    print("✓ ADP v1.0 compliance verified")
end

local function testErrorHandling(processes)
    print("\n=== Integration Test 7: Error Handling ===")
    
    -- Test invalid operation
    local invalidMessage = {
        Target = processes.collectionTracker,
        Action = "ProcessLogic",
        Operation = "invalidOperation",
        PlayerId = "test_player",
        Data = aolite.json.encode({}),
        Timestamp = 1234567895
    }
    
    aolite.send(invalidMessage)
    aolite.runScheduler()
    
    -- Verify error response
    local messages = aolite.getAllMsgs()
    local errorResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "Error" then
            errorResponse = msg
            break
        end
    end
    
    assert(errorResponse ~= nil, "Should receive error response")
    assert(string.find(errorResponse.Error, "Unknown operation"), "Should indicate unknown operation")
    
    print("✓ Error handling functional")
end

local function runIntegrationTests()
    print("Starting Collection Tracker Integration Tests...")
    
    local testResults = {
        passed = 0,
        failed = 0,
        errors = {}
    }
    
    function assert(condition, message)
        if condition then
            testResults.passed = testResults.passed + 1
        else
            testResults.failed = testResults.failed + 1
            table.insert(testResults.errors, message)
            print("FAIL: " .. message)
        end
    end
    
    local processes = setupTestEnvironment()
    
    -- Run integration tests
    testBasicCollectionOperations(processes)
    testEncounterTracking(processes)
    testAchievementSystem(processes)
    testStatisticsGeneration(processes)
    testCollectionExport(processes)
    testADPCompliance(processes)
    testErrorHandling(processes)
    
    -- Print test summary
    print("\n=== Integration Test Summary ===")
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
    local success = runIntegrationTests()
    os.exit(success and 0 or 1)
end

return {
    runIntegrationTests = runIntegrationTests
}