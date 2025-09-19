-- Unit tests for ADP v1.0 Compliant Abilities Database Process
-- Test framework: aolite

print("Running ADP v1.0 Abilities Database Unit Tests...")
print("===================================================")

-- Load the abilities database process
local aolite = require("aolite")

-- Test configurations
local testResults = {}

-- Test 1: Process Initialization and ADP Compliance
local function test_process_initialization()
    local processId = aolite.spawnProcess("processes/abilities-database-adp.lua")
    local result = processId ~= nil
    testResults["test_process_initialization"] = result
    print(result and "✓ Process initialization test passed" or "✗ Process initialization test failed")
    return result
end

-- Test 2: ADP Info Handler
local function test_adp_info_handler()
    local processId = aolite.spawnProcess("processes/abilities-database-adp.lua")
    
    local infoMessage = {
        Action = "Info",
        Timestamp = os.time(),
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

-- Test 3: GetAbility Handler
local function test_get_ability_handler()
    local processId = aolite.spawnProcess("processes/abilities-database-adp.lua")
    
    local abilityMessage = {
        Action = "GetAbility",
        Data = {id = 65}, -- Overgrow
        Timestamp = os.time(),
        From = "test-client"
    }
    
    aolite.send(processId, abilityMessage)
    aolite.runScheduler()
    
    local messages = aolite.getAllMsgs(processId)
    local abilityResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and not msg.Error then
            abilityResponse = msg
            break
        end
    end
    
    local result = abilityResponse ~= nil and abilityResponse.Data ~= nil
    testResults["test_get_ability_handler"] = result
    print(result and "✓ GetAbility handler test passed" or "✗ GetAbility handler test failed")
    return result
end

-- Test 4: GetAbilitiesByTrigger Handler
local function test_get_abilities_by_trigger_handler()
    local processId = aolite.spawnProcess("processes/abilities-database-adp.lua")
    
    local triggerMessage = {
        Action = "GetAbilitiesByTrigger",
        Data = {trigger = "on_contact"},
        Timestamp = os.time(),
        From = "test-client"
    }
    
    aolite.send(processId, triggerMessage)
    aolite.runScheduler()
    
    local messages = aolite.getAllMsgs(processId)
    local triggerResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and not msg.Error then
            triggerResponse = msg
            break
        end
    end
    
    local result = triggerResponse ~= nil and triggerResponse.Data ~= nil
    testResults["test_get_abilities_by_trigger_handler"] = result
    print(result and "✓ GetAbilitiesByTrigger handler test passed" or "✗ GetAbilitiesByTrigger handler test failed")
    return result
end

-- Test 5: Health Check Handler
local function test_health_check_handler()
    local processId = aolite.spawnProcess("processes/abilities-database-adp.lua")
    
    local healthMessage = {
        Action = "HealthCheck",
        Timestamp = os.time(),
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
    local processId = aolite.spawnProcess("processes/abilities-database-adp.lua")
    
    local invalidMessage = {
        Action = "GetAbility",
        Data = {}, -- Missing required id or name
        Timestamp = os.time(),
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
        test_get_ability_handler,
        test_get_abilities_by_trigger_handler,
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