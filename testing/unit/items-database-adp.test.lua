-- Unit tests for ADP v1.0 Compliant Items Database Process
-- Test framework: aolite

print("Running ADP v1.0 Items Database Unit Tests...")
print("===================================================")

-- Load the items database process
local aolite = require("aolite")

-- Test results tracking
local testResults = {}

-- Test 1: Process Initialization and ADP Compliance
local function test_process_initialization()
    local processId = aolite.spawnProcess("processes/items-database-adp.lua")
    local result = processId ~= nil
    testResults["test_process_initialization"] = result
    print(result and "✓ Process initialization test passed" or "✗ Process initialization test failed")
    return result
end

-- Test 2: ADP Info Handler
local function test_adp_info_handler()
    local processId = aolite.spawnProcess("processes/items-database-adp.lua")

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

-- Test 3: GetItem Handler
local function test_get_item_handler()
    local processId = aolite.spawnProcess("processes/items-database-adp.lua")

    local itemMessage = {
        Action = "GetItem",
        Data = {id = 1}, -- Poke Ball
        Timestamp = 1234567890,
        From = "test-client"
    }

    aolite.send(processId, itemMessage)
    aolite.runScheduler()

    local messages = aolite.getAllMsgs(processId)
    local itemResponse = nil

    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and not msg.Error then
            itemResponse = msg
            break
        end
    end

    local result = itemResponse ~= nil and itemResponse.Data ~= nil
    testResults["test_get_item_handler"] = result
    print(result and "✓ GetItem handler test passed" or "✗ GetItem handler test failed")
    return result
end

-- Test 4: GetItemsByCategory Handler
local function test_get_items_by_category_handler()
    local processId = aolite.spawnProcess("processes/items-database-adp.lua")

    local categoryMessage = {
        Action = "GetItemsByCategory",
        Data = {category = "pokeball"},
        Timestamp = 1234567890,
        From = "test-client"
    }

    aolite.send(processId, categoryMessage)
    aolite.runScheduler()

    local messages = aolite.getAllMsgs(processId)
    local categoryResponse = nil

    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and not msg.Error then
            categoryResponse = msg
            break
        end
    end

    local result = categoryResponse ~= nil and categoryResponse.Data ~= nil
    testResults["test_get_items_by_category_handler"] = result
    print(result and "✓ GetItemsByCategory handler test passed" or "✗ GetItemsByCategory handler test failed")
    return result
end

-- Test 5: Health Check Handler
local function test_health_check_handler()
    local processId = aolite.spawnProcess("processes/items-database-adp.lua")

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
    local processId = aolite.spawnProcess("processes/items-database-adp.lua")

    local invalidMessage = {
        Action = "GetItem",
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
        test_get_item_handler,
        test_get_items_by_category_handler,
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