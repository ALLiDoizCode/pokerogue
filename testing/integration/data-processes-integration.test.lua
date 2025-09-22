-- Integration Tests for Data Process Specialization
-- Tests all 4 data processes working together

-- ADP v1.0 Compatible Integration Test - Template dependency removed

-- Test summary function
function testDataProcessesIntegration()
    print("Testing Data Processes Integration...")
    
    -- Test that all 4 data processes can be loaded and respond to queries
    local processes = {
        "pokemon-species-db",
        "moves-database", 
        "items-database",
        "abilities-database"
    }
    
    local testQueries = {
        {action = "GetSpecies", data = {id = 25}},
        {action = "GetMove", data = {id = 53}},
        {action = "GetItem", data = {id = 17}},
        {action = "GetAbility", data = {id = 65}}
    }
    
    for i, processName in ipairs(processes) do
        local testMessage = {
            Action = testQueries[i].action,
            Data = testQueries[i].data,
            Timestamp = 1234567890,
            From = "integration-test"
        }
        
        local mockHandler = function(message)
            return { id = testQueries[i].data.id, name = "TestData" .. i }
        end
        
        local response = DataProcessTemplate.handleMessage(testMessage, processName, mockHandler)
        assert(response.Action == "SaveState", "Process " .. processName .. " should respond correctly")
        assert(response.Error == nil, "Process " .. processName .. " should not have errors")
    end
    
    print("✓ Data processes integration test passed")
end

-- Run integration test
testDataProcessesIntegration()
print("✅ Data Processes Integration test passed!")