-- ============================================================================
-- Pokemon Species Database Integration Test
-- Tests multi-process communication with coordinator process
-- ============================================================================

-- Mock environment for integration testing
local testMessages = {}
local processMessages = {}

-- Mock multiple processes
local processes = {
    ["species-db"] = {
        id = "pokemon-species-db",
        handlers = {},
        messages = {}
    },
    ["coordinator"] = {
        id = "coordinator-process",
        handlers = {},
        messages = {}
    }
}

-- Mock AO for multi-process communication
local function createMockAO(processId)
    return {
        id = processId,
        send = function(msg)
            -- Route message to target process
            if msg.Target and processes[msg.Target] then
                table.insert(processes[msg.Target].messages, msg)
            end
            table.insert(processMessages, {
                from = processId,
                to = msg.Target,
                message = msg
            })
            return true
        end
    }
end

-- Mock Handlers for each process
local function createMockHandlers(processId)
    return {
        add = function(name, matcher, handler)
            processes[processId].handlers[name] = {
                matcher = matcher,
                handler = handler
            }
        end,
        utils = {
            hasMatchingTag = function(tag, values)
                return function(msg)
                    if type(values) == "table" then
                        for _, value in ipairs(values) do
                            if msg[tag] == value then
                                return true
                            end
                        end
                        return false
                    else
                        return msg[tag] == values
                    end
                end
            end
        }
    }
end

-- Mock JSON
local mockJSON = {
    encode = function(t)
        return "mock_json_encoded"
    end,
    decode = function(s)
        return {}
    end
}

-- Setup test environment for a process
local function setupProcessEnvironment(processName)
    _G.ao = createMockAO(processes[processName].id)
    _G.Handlers = createMockHandlers(processName)
    _G.json = mockJSON
end

-- Simulate message passing between processes
local function routeMessage(from, to, message)
    message.From = processes[from].id
    message.Target = processes[to].id
    
    -- Find matching handler in target process
    for handlerName, handlerData in pairs(processes[to].handlers) do
        if handlerData.matcher(message) then
            -- Set environment for target process
            setupProcessEnvironment(to)
            -- Execute handler
            handlerData.handler(message)
            return true
        end
    end
    return false
end

-- Test: Coordinator requests species data
local function testCoordinatorSpeciesRequest()
    print("\n[TEST] Coordinator -> Species DB Communication")
    
    -- Load species database process
    setupProcessEnvironment("species-db")
    dofile("processes/pokemon-species-db.lua")
    
    -- Simulate coordinator requesting species data
    local request = {
        From = processes["coordinator"].id,
        Target = processes["species-db"].id,
        Action = "GetSpecies",
        Data = { id = 25 }, -- Pikachu
        Timestamp = 1234567890
    }
    
    -- Clear message queues
    processes["species-db"].messages = {}
    
    -- Route message to species database
    local routed = routeMessage("coordinator", "species-db", request)
    assert(routed, "Message should be routed to species database")
    
    -- Check for response
    local responses = processes["species-db"].messages
    assert(#responses > 0, "Species database should send response")
    
    local response = responses[1]
    assert(response.Target == processes["coordinator"].id, "Response should target coordinator")
    assert(response.Data, "Response should contain data")
    
    if response.Data.success then
        assert(response.Data.species, "Response should contain species data")
        assert(response.Data.species.name == "Pikachu", "Should return Pikachu data")
        print("  ✓ Species data retrieved successfully")
    else
        error("Species query failed: " .. (response.Data.error or "unknown error"))
    end
    
    return true
end

-- Test: Multiple concurrent requests
local function testConcurrentRequests()
    print("\n[TEST] Concurrent Multi-Process Requests")
    
    -- Load species database process
    setupProcessEnvironment("species-db")
    dofile("processes/pokemon-species-db.lua")
    
    -- Clear message queues
    processes["species-db"].messages = {}
    
    -- Simulate multiple concurrent requests
    local requests = {
        {
            Action = "GetSpecies",
            Data = { id = 1 } -- Bulbasaur
        },
        {
            Action = "GetEvolutionChain",
            Data = { id = 4 } -- Charmander
        },
        {
            Action = "GetBaseStats",
            Data = { id = 6 } -- Charizard
        },
        {
            Action = "GetTypeEffectiveness",
            Data = {
                attackType = "FIRE",
                defenseTypes = {"GRASS", "STEEL"}
            }
        }
    }
    
    -- Send all requests
    for i, req in ipairs(requests) do
        req.From = processes["coordinator"].id
        req.Target = processes["species-db"].id
        req.Timestamp = 1234567890 + i
        
        routeMessage("coordinator", "species-db", req)
    end
    
    -- Check responses
    local responses = processes["species-db"].messages
    assert(#responses >= #requests, "Should receive response for each request")
    
    local successCount = 0
    for _, response in ipairs(responses) do
        if response.Data and response.Data.success then
            successCount = successCount + 1
        end
    end
    
    print(string.format("  ✓ %d/%d requests processed successfully", successCount, #requests))
    assert(successCount == #requests, "All requests should succeed")
    
    return true
end

-- Test: Error handling in multi-process communication
local function testErrorHandling()
    print("\n[TEST] Error Handling in Multi-Process Communication")
    
    -- Load species database process
    setupProcessEnvironment("species-db")
    dofile("processes/pokemon-species-db.lua")
    
    -- Clear message queues
    processes["species-db"].messages = {}
    
    -- Test invalid requests
    local invalidRequests = {
        {
            Action = "GetSpecies",
            Data = { id = 99999 }, -- Non-existent species
            Description = "Non-existent species"
        },
        {
            Action = "GetSpecies",
            Data = {}, -- Missing required parameters
            Description = "Missing parameters"
        },
        {
            Action = "InvalidAction",
            Data = { id = 1 },
            Description = "Invalid action"
        }
    }
    
    local errorCount = 0
    for _, req in ipairs(invalidRequests) do
        req.From = processes["coordinator"].id
        req.Target = processes["species-db"].id
        req.Timestamp = 1234567890
        
        processes["species-db"].messages = {}
        
        local success = pcall(function()
            routeMessage("coordinator", "species-db", req)
        end)
        
        -- Check if error was handled gracefully
        local responses = processes["species-db"].messages
        if #responses > 0 then
            local response = responses[1]
            if response.Error or (response.Data and not response.Data.success) then
                errorCount = errorCount + 1
                print(string.format("  ✓ %s handled correctly", req.Description))
            end
        elseif not success then
            errorCount = errorCount + 1
            print(string.format("  ✓ %s rejected correctly", req.Description))
        end
    end
    
    assert(errorCount > 0, "Should handle at least some error cases")
    
    return true
end

-- Test: Performance under load
local function testPerformanceUnderLoad()
    print("\n[TEST] Performance Under Load")
    
    -- Load species database process
    setupProcessEnvironment("species-db")
    dofile("processes/pokemon-species-db.lua")
    
    local startTime = os.clock()
    local requestCount = 100
    
    -- Clear message queues
    processes["species-db"].messages = {}
    
    -- Send many requests rapidly
    for i = 1, requestCount do
        local request = {
            From = processes["coordinator"].id,
            Target = processes["species-db"].id,
            Action = "GetSpecies",
            Data = { id = (i % 50) + 1 }, -- Cycle through first 50 species
            Timestamp = 1234567890 + i
        }
        
        routeMessage("coordinator", "species-db", request)
    end
    
    local endTime = os.clock()
    local totalTime = endTime - startTime
    local avgTime = (totalTime / requestCount) * 1000
    
    print(string.format("  ✓ Processed %d requests in %.3f seconds", requestCount, totalTime))
    print(string.format("  ✓ Average processing time: %.3f ms", avgTime))
    
    -- Check that all requests were handled
    local responses = processes["species-db"].messages
    assert(#responses >= requestCount, "Should handle all requests")
    
    -- Performance requirement: < 100ms average
    assert(avgTime < 100, string.format("Performance requirement not met: %.3f ms > 100ms", avgTime))
    
    return true
end

-- Test: ADP compliance in multi-process context
local function testADPCompliance()
    print("\n[TEST] ADP v1.0 Compliance in Multi-Process Context")
    
    -- Load species database process
    setupProcessEnvironment("species-db")
    dofile("processes/pokemon-species-db.lua")
    
    -- Clear message queues
    processes["species-db"].messages = {}
    
    -- Request Info for self-documentation
    local infoRequest = {
        From = processes["coordinator"].id,
        Target = processes["species-db"].id,
        Action = "Info",
        Timestamp = 1234567890
    }
    
    routeMessage("coordinator", "species-db", infoRequest)
    
    local responses = processes["species-db"].messages
    assert(#responses > 0, "Should receive Info response")
    
    local response = responses[1]
    assert(response.Action == "SaveState", "Info response should use SaveState action")
    assert(response.Data, "Response should contain data")
    
    local info = response.Data
    assert(info.process, "Should contain process metadata")
    assert(info.process.adpVersion == "1.0", "Should be ADP v1.0 compliant")
    assert(info.process.capabilities, "Should list capabilities")
    assert(info.handlers, "Should list handlers")
    
    print("  ✓ ADP v1.0 compliance verified")
    print("  ✓ Self-documentation available")
    
    -- Verify all advertised capabilities work
    local capabilities = {
        "GetSpecies",
        "GetEvolutionChain",
        "GetBaseStats",
        "GetLevelMoves",
        "GetTypeEffectiveness",
        "HealthCheck"
    }
    
    for _, capability in ipairs(capabilities) do
        local found = false
        for _, cap in ipairs(info.process.capabilities) do
            if cap == capability then
                found = true
                break
            end
        end
        assert(found, string.format("Capability %s should be listed", capability))
    end
    
    print("  ✓ All capabilities documented")
    
    return true
end

-- Main integration test suite
local function runIntegrationTestSuite()
    print("=" .. string.rep("=", 70))
    print("Pokemon Species Database Integration Test Suite")
    print("=" .. string.rep("=", 70))
    
    local tests = {
        { name = "Coordinator Species Request", fn = testCoordinatorSpeciesRequest },
        { name = "Concurrent Multi-Process Requests", fn = testConcurrentRequests },
        { name = "Error Handling", fn = testErrorHandling },
        { name = "Performance Under Load", fn = testPerformanceUnderLoad },
        { name = "ADP v1.0 Compliance", fn = testADPCompliance }
    }
    
    local passed = 0
    local failed = 0
    
    for _, test in ipairs(tests) do
        local success, err = pcall(test.fn)
        if success then
            print("[PASS] " .. test.name)
            passed = passed + 1
        else
            print("[FAIL] " .. test.name .. " - " .. tostring(err))
            failed = failed + 1
        end
    end
    
    print("\n" .. string.rep("=", 70))
    print(string.format("Integration Test Results: %d passed, %d failed", passed, failed))
    print(string.rep("=", 70))
    
    return failed == 0
end

-- Execute test suite
return runIntegrationTestSuite()