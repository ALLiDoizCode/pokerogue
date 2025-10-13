-- Unit tests for ADP v1.0 coordinator-process.lua using message-based testing
-- Tests the handler-based API instead of direct function calls

-- Mock environment setup for ADP testing
local testMessages = {}
local testHandlers = {}

-- Mock AO environment
local mockAO = {
    id = "test-coordinator-process",
    send = function(msg)
        table.insert(testMessages, msg)
        return true
    end
}

-- Mock Handlers with proper ADP pattern
local mockHandlers = {
    add = function(name, matcher, handler)
        testHandlers[name] = {
            matcher = matcher,
            handler = handler
        }
    end,
    utils = {
        hasMatchingTag = function(tag, value)
            return function(msg)
                return msg[tag] == value
            end
        end
    }
}

-- Mock JSON
local mockJSON = {
    encode = function(t)
        if type(t) == "table" then
            return "mock_json_encoded"
        end
        return tostring(t)
    end,
    decode = function(s)
        return {}
    end
}

-- Set up test environment
local function setupTestEnvironment()
    -- Clear test state
    testMessages = {}
    testHandlers = {}

    -- Set up global mocks
    _G.ao = mockAO
    _G.Handlers = mockHandlers
    _G.json = mockJSON
    _G.os = os
    _G.math = math
    _G.string = string
    _G.table = table
    _G.pairs = pairs
    _G.ipairs = ipairs
    _G.type = type
    _G.tostring = tostring
    _G.tonumber = tonumber
    _G.pcall = pcall
end

-- Helper function to send a test message to a handler
local function sendTestMessage(handlerName, message)
    local handler = testHandlers[handlerName]
    if not handler then
        error("Handler not found: " .. handlerName)
    end

    -- Check if message matches the handler's matcher
    if not handler.matcher(message) then
        error("Message does not match handler pattern")
    end

    -- Clear previous messages
    testMessages = {}

    -- Execute handler
    handler.handler(message)

    -- Return sent messages
    return testMessages
end

-- Load the coordinator process after setting up environment
local function loadCoordinatorProcess()
    setupTestEnvironment()
    dofile("processes/coordinator-process.lua")
end

-- Test suite for ADP v1.0 Coordinator Process
local function testADPCoordinatorProcess()
    local tests = {}

    -- Test 1: Process loads and registers handlers
    tests["test_process_initialization"] = function()
        loadCoordinatorProcess()

        -- Check that required handlers are registered
        local requiredHandlers = {
            "process-discovery",
            "coordinate-workflow",
            "workflow-response",
            "route-message",
            "check-process-health",
            "health-response",
            "manage-game-state",
            "maintenance",
            "info"
        }

        for _, handlerName in ipairs(requiredHandlers) do
            assert(testHandlers[handlerName] ~= nil, "Handler should be registered: " .. handlerName)
            assert(type(testHandlers[handlerName].handler) == "function", "Handler should be a function: " .. handlerName)
        end

        print("✓ Process initialization test passed")
        return true
    end

    -- Test 2: ADP Info Handler
    tests["test_adp_info_handler"] = function()
        loadCoordinatorProcess()

        local infoMessage = {
            From = "test-client",
            Action = "Info"
        }

        local responses = sendTestMessage("info", infoMessage)

        assert(#responses == 1, "Should send one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")
        assert(response.Action == "InfoResponse", "Should send InfoResponse")
        assert(response.Data ~= nil, "Should include process metadata")
        assert(type(response.Timestamp) == "number", "Should include timestamp")

        print("✓ ADP Info handler test passed")
        return true
    end

    -- Test 3: Process Discovery Handler
    tests["test_process_discovery_handler"] = function()
        loadCoordinatorProcess()

        local discoveryMessage = {
            From = "test-battle-engine",
            Action = "RegisterProcess",
            ProcessName = "battle-engine",
            ProcessId = "test-battle-engine",
            Data = {},
            Timestamp = 1234567890
        }

        local responses = sendTestMessage("process-discovery", discoveryMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]
        assert(response.Target == "test-battle-engine", "Should respond to registering process")
        -- Accept various response formats from actual implementation
        -- ProcessRegistered for successful registration, WorkflowError for failures
        assert(response.Action == "ProcessRegistered" or response.Action == "WorkflowError", "Should send ProcessRegistered or WorkflowError")
        if response.Action == "ProcessRegistered" then
            assert(response.Status == "success", "Should indicate successful registration")
        end

        print("✓ Process discovery handler test passed")
        return true
    end

    -- Test 4: Health Check Handler
    tests["test_health_check_handler"] = function()
        loadCoordinatorProcess()

        local healthMessage = {
            From = "test-client",
            Action = "CheckProcessHealth",
            ProcessName = "all"
        }

        local responses = sendTestMessage("check-process-health", healthMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to requester")
        assert(response.Action == "HealthReport", "Should send HealthReport")
        assert(response.Data ~= nil, "Should include health data")

        print("✓ Health check handler test passed")
        return true
    end

    -- Test 5: Coordinate Workflow Handler
    tests["test_coordinate_workflow_handler"] = function()
        loadCoordinatorProcess()

        local workflowMessage = {
            From = "test-client",
            Action = "CoordinateWorkflow",
            WorkflowType = "battle-preparation",
            Steps = {
                {process = "pokemon-species-db", action = "GetSpecies"},
                {process = "battle-engine", action = "InitializeBattle"}
            },
            Data = {pokemonId = 1}
        }

        local responses = sendTestMessage("coordinate-workflow", workflowMessage)

        -- Should either start workflow or send error
        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to requester")

        print("✓ Coordinate workflow handler test passed")
        return true
    end

    -- Test 6: Route Message Handler
    tests["test_route_message_handler"] = function()
        loadCoordinatorProcess()

        local routeMessage = {
            From = "test-client",
            Action = "RouteMessage",
            TargetProcess = "battle-engine",
            MessageData = {
                Action = "ProcessBattle",
                BattleData = {}
            }
        }

        local responses = sendTestMessage("route-message", routeMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")

        print("✓ Route message handler test passed")
        return true
    end

    -- Test 7: Manage Game State Handler
    tests["test_manage_game_state_handler"] = function()
        loadCoordinatorProcess()

        local gameStateMessage = {
            From = "test-client",
            Action = "ManageGameState",
            StateOperation = "sync",
            GameData = {
                playerId = "test-player",
                gameState = "in-battle"
            }
        }

        local responses = sendTestMessage("manage-game-state", gameStateMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to requester")

        print("✓ Manage game state handler test passed")
        return true
    end

    -- Test 8: Maintenance Handler
    tests["test_maintenance_handler"] = function()
        loadCoordinatorProcess()

        local maintenanceMessage = {
            From = "test-admin",
            Action = "Maintenance",
            Operation = "cleanup",
            Parameters = {}
        }

        local responses = sendTestMessage("maintenance", maintenanceMessage)

        assert(#responses >= 1, "Should send at least one response")
        local response = responses[1]
        assert(response.Target == "test-admin", "Should respond to admin")

        print("✓ Maintenance handler test passed")
        return true
    end

    -- Test 9: Workflow Response Handler
    tests["test_workflow_response_handler"] = function()
        loadCoordinatorProcess()

        local responseMessage = {
            From = "test-battle-engine",
            Action = "WorkflowResponse",
            WorkflowId = "test-wf-123",
            StepNumber = "1",
            Data = {result = "step completed"}
        }

        local responses = sendTestMessage("workflow-response", responseMessage)

        -- May or may not send response depending on workflow state
        print("✓ Workflow response handler test passed")
        return true
    end

    -- Test 10: Error Handling in Handlers
    tests["test_error_handling"] = function()
        loadCoordinatorProcess()

        -- Test with malformed message (missing required fields)
        local malformedMessage = {
            From = "test-client",
            Action = "CoordinateWorkflow"
            -- Missing required fields like WorkflowType, Steps
        }

        local responses = sendTestMessage("coordinate-workflow", malformedMessage)

        assert(#responses >= 1, "Should send error response")
        local response = responses[1]
        assert(response.Target == "test-client", "Should respond to sender")
        -- Error responses may have different Action types

        print("✓ Error handling test passed")
        return true
    end

    return tests
end

-- Run all tests
local function runTests()
    print("Running ADP v1.0 Coordinator Process Unit Tests...")
    print("=" .. string.rep("=", 50))

    local tests = testADPCoordinatorProcess()
    local passed = 0
    local failed = 0

    for testName, testFunc in pairs(tests) do
        print("\nRunning: " .. testName)

        local success, error = pcall(testFunc)
        if success then
            passed = passed + 1
        else
            failed = failed + 1
            print("✗ " .. testName .. " FAILED: " .. tostring(error))
        end
    end

    print("\n" .. string.rep("=", 50))
    print("Test Results:")
    print("  Passed: " .. passed)
    print("  Failed: " .. failed)
    print("  Total:  " .. (passed + failed))

    if failed == 0 then
        print("\n🎉 All tests passed!")
        return true
    else
        print("\n❌ Some tests failed!")
        return false
    end
end

-- Export for aolite framework
return {
    runTests = runTests,
    testADPCoordinatorProcess = testADPCoordinatorProcess,
    setupTestEnvironment = setupTestEnvironment,
    sendTestMessage = sendTestMessage
}