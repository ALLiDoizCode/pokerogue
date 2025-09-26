-- Unit tests for ADP v1.0 Compliant Moves Database Process
-- Test framework: aolite

print("Running ADP v1.0 Moves Database Unit Tests...")
print("===================================================")

-- Load the moves database process
local aolite = require("aolite")

-- Test results tracking
local testResults = {}

-- Test 1: Process Initialization and ADP Compliance
local function test_process_initialization()
    local processId = aolite.spawnProcess("processes/moves-database-adp.lua")
    local result = processId ~= nil
    testResults["test_process_initialization"] = result
    print(result and "✓ Process initialization test passed" or "✗ Process initialization test failed")
    return result
end

-- Test 2: ADP Info Handler
local function test_adp_info_handler()
    local processId = aolite.spawnProcess("processes/moves-database-adp.lua")

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

-- Test 3: GetMove Handler
local function test_get_move_handler()
    local processId = aolite.spawnProcess("processes/moves-database-adp.lua")

    local moveMessage = {
        Action = "GetMove",
        Data = {id = 1}, -- Pound
        Timestamp = 1234567890,
        From = "test-client"
    }

    aolite.send(processId, moveMessage)
    aolite.runScheduler()

    local messages = aolite.getAllMsgs(processId)
    local moveResponse = nil

    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and not msg.Error then
            moveResponse = msg
            break
        end
    end

    local result = moveResponse ~= nil and moveResponse.Data ~= nil
    testResults["test_get_move_handler"] = result
    print(result and "✓ GetMove handler test passed" or "✗ GetMove handler test failed")
    return result
end

-- Test 4: GetMovesByType Handler
local function test_get_moves_by_type_handler()
    local processId = aolite.spawnProcess("processes/moves-database-adp.lua")

    local typeMessage = {
        Action = "GetMovesByType",
        Data = {type = "normal"},
        Timestamp = 1234567890,
        From = "test-client"
    }

    aolite.send(processId, typeMessage)
    aolite.runScheduler()

    local messages = aolite.getAllMsgs(processId)
    local typeResponse = nil

    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and not msg.Error then
            typeResponse = msg
            break
        end
    end

    local result = typeResponse ~= nil and typeResponse.Data ~= nil
    testResults["test_get_moves_by_type_handler"] = result
    print(result and "✓ GetMovesByType handler test passed" or "✗ GetMovesByType handler test failed")
    return result
end

-- Test 5: Health Check Handler
local function test_health_check_handler()
    local processId = aolite.spawnProcess("processes/moves-database-adp.lua")

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

-- Test 6: Error handling
local function test_error_handling()
    local processId = aolite.spawnProcess("processes/moves-database-adp.lua")

    local invalidMessage = {
        Action = "GetMove",
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
        test_get_move_handler,
        test_get_moves_by_type_handler,
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