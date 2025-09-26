-- Unit tests for ADP v1.0 Compliant Pokemon Species Database Process
-- Test framework: aolite

print("Running ADP v1.0 Pokemon Species Database Unit Tests...")
print("===================================================")

-- Load the pokemon species database process
local aolite = require("aolite")

-- Test results tracking
local testResults = {}

-- Test 1: Process Initialization and ADP Compliance
local function test_process_initialization()
    local processId = aolite.spawnProcess("processes/pokemon-species-db-adp.lua")
    local result = processId ~= nil
    testResults["test_process_initialization"] = result
    print(result and "✓ Process initialization test passed" or "✗ Process initialization test failed")
    return result
end

-- Test 2: ADP Info Handler
local function test_adp_info_handler()
    local processId = aolite.spawnProcess("processes/pokemon-species-db-adp.lua")

    local infoMessage = {
        Action = "Info",
        Timestamp = 1234567890,
        From = "test-client"
    }

    aolite.send(processId, infoMessage)
    aolite.runScheduler()

    local messages = aolite.getAllMsgs(processId)
    local infoResponse = nil

    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and msg.Data.process then
            infoResponse = msg
            break
        end
    end

    local result = infoResponse ~= nil and
                   infoResponse.Data.process.adpVersion == "1.0" and
                   infoResponse.Data.documentation.adpCompliance == "v1.0"

    testResults["test_adp_info_handler"] = result
    print(result and "✓ ADP Info handler test passed" or "✗ ADP Info handler test failed")
    return result
end

-- Test 3: GetSpecies Handler
local function test_get_species_handler()
    local processId = aolite.spawnProcess("processes/pokemon-species-db-adp.lua")

    local speciesMessage = {
        Action = "GetSpecies",
        Data = {id = 1}, -- Bulbasaur
        Timestamp = 1234567890,
        From = "test-client"
    }

    aolite.send(processId, speciesMessage)
    aolite.runScheduler()

    local messages = aolite.getAllMsgs(processId)
    local speciesResponse = nil

    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and not msg.Error then
            speciesResponse = msg
            break
        end
    end

    local result = speciesResponse ~= nil and speciesResponse.Data ~= nil
    testResults["test_get_species_handler"] = result
    print(result and "✓ GetSpecies handler test passed" or "✗ GetSpecies handler test failed")
    return result
end

-- Test 4: GetEvolutionChain Handler
local function test_get_evolution_chain_handler()
    local processId = aolite.spawnProcess("processes/pokemon-species-db-adp.lua")

    local evolutionMessage = {
        Action = "GetEvolutionChain",
        Data = {id = 1}, -- Bulbasaur evolution chain
        Timestamp = 1234567890,
        From = "test-client"
    }

    aolite.send(processId, evolutionMessage)
    aolite.runScheduler()

    local messages = aolite.getAllMsgs(processId)
    local evolutionResponse = nil

    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and not msg.Error then
            evolutionResponse = msg
            break
        end
    end

    local result = evolutionResponse ~= nil and evolutionResponse.Data ~= nil
    testResults["test_get_evolution_chain_handler"] = result
    print(result and "✓ GetEvolutionChain handler test passed" or "✗ GetEvolutionChain handler test failed")
    return result
end

-- Test 5: GetBaseStats Handler
local function test_get_base_stats_handler()
    local processId = aolite.spawnProcess("processes/pokemon-species-db-adp.lua")

    local statsMessage = {
        Action = "GetBaseStats",
        Data = {id = 1}, -- Bulbasaur stats
        Timestamp = 1234567890,
        From = "test-client"
    }

    aolite.send(processId, statsMessage)
    aolite.runScheduler()

    local messages = aolite.getAllMsgs(processId)
    local statsResponse = nil

    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and not msg.Error then
            statsResponse = msg
            break
        end
    end

    local result = statsResponse ~= nil and statsResponse.Data ~= nil
    testResults["test_get_base_stats_handler"] = result
    print(result and "✓ GetBaseStats handler test passed" or "✗ GetBaseStats handler test failed")
    return result
end

-- Test 6: Health Check Handler
local function test_health_check_handler()
    local processId = aolite.spawnProcess("processes/pokemon-species-db-adp.lua")

    local healthMessage = {
        Action = "HealthCheck",
        Timestamp = 1234567890,
        From = "test-client"
    }

    aolite.send(processId, healthMessage)
    aolite.runScheduler()

    local messages = aolite.getAllMsgs(processId)
    local healthResponse = nil

    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data then
            healthResponse = msg
            break
        end
    end

    local result = healthResponse ~= nil and
                   healthResponse.Data.status == "healthy" and
                   healthResponse.Data.adpCompliant == true

    testResults["test_health_check_handler"] = result
    print(result and "✓ Health check handler test passed" or "✗ Health check handler test failed")
    return result
end

-- Test 7: Error handling
local function test_error_handling()
    local processId = aolite.spawnProcess("processes/pokemon-species-db-adp.lua")

    local invalidMessage = {
        Action = "GetSpecies",
        Data = {}, -- Missing required id or name
        Timestamp = 1234567890,
        From = "test-client"
    }

    aolite.send(processId, invalidMessage)
    aolite.runScheduler()

    local messages = aolite.getAllMsgs(processId)
    local errorResponse = nil

    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Error then
            errorResponse = msg
            break
        end
    end

    local result = errorResponse ~= nil and errorResponse.Error ~= nil
    testResults["test_error_handling"] = result
    print(result and "✓ Error handling test passed" or "✗ Error handling test failed")
    return result
end

-- Run all tests
local function run_tests()
    local tests = {
        test_process_initialization,
        test_adp_info_handler,
        test_get_species_handler,
        test_get_evolution_chain_handler,
        test_get_base_stats_handler,
        test_health_check_handler,
        test_error_handling
    }

    local passed = 0
    local total = #tests

    for _, test in ipairs(tests) do
        if test() then
            passed = passed + 1
        end
    end

    print("\n==================================================")
    print("Test Results:")
    print("  Passed: " .. passed)
    print("  Failed: " .. (total - passed))
    print("  Total:  " .. total)

    if passed == total then
        print("\n🎉 All tests passed!")
        return true
    else
        print("\n💥 Some tests failed!")
        return false
    end
end

-- Execute tests
return run_tests()