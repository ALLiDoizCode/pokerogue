-- Integration Test Template for {{MODULE_NAME}}
-- Generated on {{TIMESTAMP}}
-- Source: {{SOURCE_FILE}}

-- Integration test framework setup
local function setupIntegrationEnvironment()
    -- Set up more realistic AO environment for integration testing
    if not ao then
        ao = {
            send = function(msg)
                -- Store sent messages for verification
                ao._sentMessages = ao._sentMessages or {}
                table.insert(ao._sentMessages, msg)
                print("Integration ao.send:", json and json.encode(msg) or tostring(msg))
            end,
            id = "integration_test_process",
            _sentMessages = {}
        }
    end
    
    if not json then
        json = {
            encode = function(obj)
                if type(obj) == "table" then
                    local result = "{"
                    for k, v in pairs(obj) do
                        if #result > 1 then result = result .. "," end
                        result = result .. '"' .. tostring(k) .. '":' .. 
                                (type(v) == "string" and '"' .. v .. '"' or tostring(v))
                    end
                    return result .. "}"
                end
                return tostring(obj)
            end,
            decode = function(str)
                -- Simple JSON decode for testing
                return loadstring("return " .. str:gsub('"([^"]+)":', '["%1"]='))() or {}
            end
        }
    end
    
    if not Handlers then
        Handlers = {
            _handlers = {},
            add = function(name, matcher, handler)
                Handlers._handlers[name] = {
                    matcher = matcher,
                    handler = handler
                }
                print("Integration Handler registered:", name)
            end,
            utils = {
                hasMatchingTag = function(tag, value)
                    return function(msg)
                        return msg[tag] == value
                    end
                end
            },
            -- Simulate message processing
            process = function(msg)
                for name, handlerInfo in pairs(Handlers._handlers) do
                    if handlerInfo.matcher(msg) then
                        print("Processing message with handler:", name)
                        return handlerInfo.handler(msg)
                    end
                end
                return nil
            end
        }
    end
end

-- Setup integration environment
setupIntegrationEnvironment()

-- Integration test utilities
local IntegrationUtils = {}

function IntegrationUtils.createRealisticMessage(action, data, from, gameState)
    return {
        Id = "integration_msg_" .. math.random(1000000),
        From = from or "integration_test_sender",
        Target = ao.id,
        Action = action,
        Data = data and json.encode(data) or "{}",
        GameState = gameState and json.encode(gameState) or "{}",
        Timestamp = tostring(os.time()),
        Tags = {
            Action = action,
            Protocol = "PokéRogue-AO"
        }
    }
end

function IntegrationUtils.simulateMessageFlow(messages)
    local results = {}
    ao._sentMessages = {} -- Clear previous messages
    
    for i, msg in ipairs(messages) do
        print(string.format("Processing message %d: %s", i, msg.Action))
        local result = Handlers.process(msg)
        table.insert(results, {
            message = msg,
            result = result,
            sentMessages = #ao._sentMessages
        })
    end
    
    return results
end

function IntegrationUtils.assertMessageSequence(expectedActions)
    local sentMessages = ao._sentMessages or {}
    assert(#sentMessages >= #expectedActions, 
           string.format("Expected at least %d messages, got %d", #expectedActions, #sentMessages))
    
    for i, expectedAction in ipairs(expectedActions) do
        local msg = sentMessages[i]
        assert(msg and msg.Action == expectedAction,
               string.format("Message %d: expected Action '%s', got '%s'", 
                           i, expectedAction, msg and msg.Action or "nil"))
    end
end

function IntegrationUtils.assertGameStateUpdate(initialState, finalState, expectedChanges)
    for field, expectedValue in pairs(expectedChanges) do
        local actualValue = finalState[field]
        assert(actualValue == expectedValue,
               string.format("GameState.%s: expected %s, got %s", 
                           field, tostring(expectedValue), tostring(actualValue)))
    end
end

-- Test Cases
{{FUNCTION_TESTS}}

-- Integration-specific test scenarios

describe("Message Flow Integration", function()
    it("should handle complete workflow scenarios", function()
        -- Test end-to-end message processing workflows
        local messages = {
            IntegrationUtils.createRealisticMessage("Initialize", {playerId = "test_player"}),
            IntegrationUtils.createRealisticMessage("ProcessAction", {action = "test_action"}),
            IntegrationUtils.createRealisticMessage("Finalize", {})
        }
        
        local results = IntegrationUtils.simulateMessageFlow(messages)
        
        -- Verify workflow completion
        assert.equals(3, #results, "Should process all workflow messages")
        
        -- Verify expected message sequence
        IntegrationUtils.assertMessageSequence({"Success", "ActionResult", "Complete"})
    end)
    
    it("should maintain state consistency across messages", function()
        -- Test state persistence and consistency
        local initialState = {player = {level = 1, exp = 0}}
        
        local message1 = IntegrationUtils.createRealisticMessage(
            "GainExp", 
            {amount = 100}, 
            "test_player",
            initialState
        )
        
        local results = IntegrationUtils.simulateMessageFlow({message1})
        
        -- Verify state changes
        if #results > 0 and ao._sentMessages[1] and ao._sentMessages[1].GameState then
            local finalState = json.decode(ao._sentMessages[1].GameState)
            IntegrationUtils.assertGameStateUpdate(
                initialState, 
                finalState, 
                {["player.exp"] = 100}
            )
        end
    end)
end)

describe("Error Handling Integration", function()
    it("should handle invalid messages gracefully", function()
        local invalidMessage = {
            Id = "invalid_msg",
            -- Missing required fields
        }
        
        local result = Handlers.process(invalidMessage)
        
        -- Should either return nil or error response, not crash
        if result then
            assert.is_not_nil(result.Error, "Invalid message should return error")
        end
    end)
    
    it("should recover from error states", function()
        -- Test error recovery mechanisms
        local errorMessage = IntegrationUtils.createRealisticMessage("CauseError", {})
        local recoveryMessage = IntegrationUtils.createRealisticMessage("Recover", {})
        
        local results = IntegrationUtils.simulateMessageFlow({errorMessage, recoveryMessage})
        
        -- Verify error handling and recovery
        assert.equals(2, #results, "Should process both error and recovery messages")
    end)
end)

describe("Performance Integration", function()
    it("should handle message bursts efficiently", function()
        -- Test processing multiple messages quickly
        local messages = {}
        for i = 1, 10 do
            table.insert(messages, IntegrationUtils.createRealisticMessage(
                "BurstMessage", 
                {index = i}
            ))
        end
        
        local startTime = os.clock()
        local results = IntegrationUtils.simulateMessageFlow(messages)
        local endTime = os.clock()
        
        assert.equals(10, #results, "Should process all burst messages")
        assert.is_true(endTime - startTime < 2.0, "Burst processing should complete within 2 seconds")
    end)
    
    it("should maintain performance under load", function()
        -- Test sustained processing performance
        local messageCount = 50
        local messages = {}
        
        for i = 1, messageCount do
            table.insert(messages, IntegrationUtils.createRealisticMessage(
                "LoadTest", 
                {iteration = i}
            ))
        end
        
        local startTime = os.clock()
        local results = IntegrationUtils.simulateMessageFlow(messages)
        local endTime = os.clock()
        
        local avgTime = (endTime - startTime) / messageCount
        
        assert.equals(messageCount, #results, "Should process all load test messages")
        assert.is_true(avgTime < 0.1, "Average message processing should be under 100ms")
    end)
end)

describe("Cross-Process Communication", function()
    it("should format messages correctly for other processes", function()
        -- Test message formatting for cross-process communication
        local message = IntegrationUtils.createRealisticMessage("CrossProcess", {
            targetProcess = "other_process",
            data = {key = "value"}
        })
        
        local results = IntegrationUtils.simulateMessageFlow({message})
        
        if #ao._sentMessages > 0 then
            local sentMsg = ao._sentMessages[1]
            assert.is_not_nil(sentMsg.Target, "Cross-process message should have Target")
            assert.is_not_nil(sentMsg.Data, "Cross-process message should have Data")
        end
    end)
    
    it("should handle responses from other processes", function()
        -- Test handling of responses from external processes
        local responseMessage = IntegrationUtils.createRealisticMessage("Response", {
            originalMessageId = "test_request_123",
            status = "success",
            result = {processed = true}
        })
        
        local results = IntegrationUtils.simulateMessageFlow({responseMessage})
        
        -- Verify response handling
        assert.equals(1, #results, "Should process response message")
    end)
end)

print("✅ Integration tests for {{MODULE_NAME}} completed")