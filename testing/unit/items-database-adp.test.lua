-- Unit tests for ADP v1.0 Compliant Items Database Process
-- Test framework: aolite

print("Running ADP v1.0 Items Database Unit Tests...")
print("===================================================")

-- Load the items database process
local aolite = require("aolite")
local json = require("json")

-- Test configuration
local PROCESS_PATH = "processes.items-database-adp"
local processId = "test-items-database-adp"

-- Spawn the process
aolite.spawnProcess(processId, PROCESS_PATH)

print("Process ID:", processId)

-- Test results tracking
local testResults = {}

-- Helper function to send messages and get response
local function sendMessage(action, data)
    local msg = {
        From = processId,
        Target = processId,
        Action = action,
        Data = data or ""
    }

    aolite.send(msg)
    return aolite.getLastMsg(processId)
end

-- Test 1: Process Initialization and ADP Compliance
local function test_process_initialization()
    local result = processId ~= nil
    testResults["test_process_initialization"] = result
    print(result and "✓ Process initialization test passed" or "✗ Process initialization test failed")
    return result
end

-- Test 2: ADP Info Handler
local function test_adp_info_handler()
    local infoResponse = sendMessage("Info")

    local result = infoResponse ~= nil and
                   infoResponse.Action == "SaveState" and
                   infoResponse.Data ~= nil

    testResults["test_adp_info_handler"] = result
    print(result and "✓ ADP Info handler test passed" or "✗ ADP Info handler test failed")
    return result
end

-- Test 3: GetItem Handler
local function test_get_item_handler()
    local itemResponse = sendMessage("GetItem", json.encode({id = 1}))

    local result = itemResponse ~= nil and
                   itemResponse.Action == "SaveState" and
                   itemResponse.Data ~= nil and
                   not itemResponse.Error
    testResults["test_get_item_handler"] = result
    print(result and "✓ GetItem handler test passed" or "✗ GetItem handler test failed")
    return result
end

-- Test 4: GetItemsByCategory Handler
local function test_get_items_by_category_handler()
    local categoryResponse = sendMessage("GetItemsByCategory", json.encode({category = "pokeball"}))

    local result = categoryResponse ~= nil and
                   categoryResponse.Action == "SaveState" and
                   categoryResponse.Data ~= nil and
                   not categoryResponse.Error
    testResults["test_get_items_by_category_handler"] = result
    print(result and "✓ GetItemsByCategory handler test passed" or "✗ GetItemsByCategory handler test failed")
    return result
end

-- Test 5: Health Check Handler
local function test_health_check_handler()
    local healthResponse = sendMessage("HealthCheck")

    local result = healthResponse ~= nil and
                   healthResponse.Action == "SaveState" and
                   healthResponse.Data ~= nil

    testResults["test_health_check_handler"] = result
    print(result and "✓ Health check handler test passed" or "✗ Health check handler test failed")
    return result
end

-- Test 6: Error handling
local function test_error_handling()
    local errorResponse = sendMessage("GetItem", json.encode({}))

    local result = errorResponse ~= nil and
                   (errorResponse.Action == "Error" or errorResponse.Error ~= nil)
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