-- Test ADP Info handlers for all 4 data processes
local aolite = require("aolite")

-- Test configurations for each process
local processes = {
    {
        name = "abilities-database-adp",
        file = "processes/abilities-database-adp.lua",
        expected_capabilities = {"GetAbility", "GetAbilitiesByTrigger", "GetAbilityActivation", "HealthCheck", "Info"}
    },
    {
        name = "items-database-adp", 
        file = "processes/items-database-adp.lua",
        expected_capabilities = {"GetItem", "GetItemsByCategory", "GetBerryEffect", "GetItemEffect", "HealthCheck", "Info"}
    },
    {
        name = "moves-database-adp",
        file = "processes/moves-database-adp.lua", 
        expected_capabilities = {"GetMove", "GetMovesByType", "GetTypeEffectiveness", "HealthCheck", "Info"}
    },
    {
        name = "pokemon-species-db-adp",
        file = "processes/pokemon-species-db-adp.lua",
        expected_capabilities = {"GetSpecies", "GetEvolutionChain", "GetBaseStats", "HealthCheck", "Info"}
    }
}

-- Test results
local results = {}

-- Test each process
for _, process in ipairs(processes) do
    print("Testing " .. process.name .. "...")
    
    -- Load and spawn the process
    local processId = aolite.spawnProcess(process.file)
    
    -- Test Info handler
    local infoMessage = {
        Action = "Info",
        Data = {},
        Timestamp = os.time(),
        From = "test-client"
    }
    
    aolite.send(processId, infoMessage)
    aolite.runScheduler()
    
    -- Get response messages
    local messages = aolite.getAllMsgs(processId)
    local infoResponse = nil
    
    for _, msg in ipairs(messages) do
        if msg.Action == "SaveState" and msg.Data and msg.Data.process then
            infoResponse = msg
            break
        end
    end
    
    -- Validate response
    local testResult = {
        process = process.name,
        success = false,
        errors = {},
        response = infoResponse
    }
    
    if not infoResponse then
        table.insert(testResult.errors, "No Info response received")
    else
        local data = infoResponse.Data
        
        -- Check ADP v1.0 compliance
        if not data.process then
            table.insert(testResult.errors, "Missing process metadata")
        elseif data.process.adpVersion ~= "1.0" then
            table.insert(testResult.errors, "Invalid adpVersion: " .. tostring(data.process.adpVersion))
        end
        
        -- Check required fields
        if not data.process.name then
            table.insert(testResult.errors, "Missing process name")
        end
        
        if not data.process.capabilities then
            table.insert(testResult.errors, "Missing capabilities list")
        else
            -- Verify expected capabilities
            for _, expectedCap in ipairs(process.expected_capabilities) do
                local found = false
                for _, cap in ipairs(data.process.capabilities) do
                    if cap == expectedCap then
                        found = true
                        break
                    end
                end
                if not found then
                    table.insert(testResult.errors, "Missing capability: " .. expectedCap)
                end
            end
        end
        
        if not data.process.messageSchemas then
            table.insert(testResult.errors, "Missing messageSchemas")
        end
        
        if not data.handlers then
            table.insert(testResult.errors, "Missing handlers list")
        end
        
        if not data.documentation then
            table.insert(testResult.errors, "Missing documentation")
        elseif data.documentation.adpCompliance ~= "v1.0" then
            table.insert(testResult.errors, "Invalid adpCompliance: " .. tostring(data.documentation.adpCompliance))
        end
        
        -- Mark success if no errors
        if #testResult.errors == 0 then
            testResult.success = true
        end
    end
    
    table.insert(results, testResult)
    print("  Result: " .. (testResult.success and "PASS" or "FAIL"))
    if not testResult.success then
        for _, error in ipairs(testResult.errors) do
            print("    Error: " .. error)
        end
    end
end

-- Summary report
print("\n=== ADP Info Handler Test Summary ===")
local passed = 0
local total = #results

for _, result in ipairs(results) do
    if result.success then
        passed = passed + 1
    end
end

print("Tests passed: " .. passed .. "/" .. total)

if passed == total then
    print("✅ All ADP Info handlers working correctly!")
    os.exit(0)
else
    print("❌ Some tests failed - see details above")
    os.exit(1)
end