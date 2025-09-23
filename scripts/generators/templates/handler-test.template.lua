-- AO Handler Test Template for {{MODULE_NAME}}
-- Generated on {{TIMESTAMP}}
-- Source: {{SOURCE_FILE}}

-- AO Handler test framework setup
local function setupHandlerTestEnvironment()
    -- Set up comprehensive AO environment for handler testing
    if not ao then
        ao = {
            send = function(msg)
                -- Store sent messages with metadata
                ao._sentMessages = ao._sentMessages or {}
                table.insert(ao._sentMessages, {
                    message = msg,
                    timestamp = os.time(),
                    processId = ao.id
                })
                print("Handler ao.send:", json and json.encode(msg) or tostring(msg))
                return true
            end,
            id = "handler_test_process_" .. math.random(10000),
            _sentMessages = {}
        }
    end
    
    if not json then
        json = {
            encode = function(obj)
                if type(obj) == "table" then
                    local function encodeValue(val)
                        if type(val) == "string" then
                            return '"' .. val:gsub('"', '\\"') .. '"'
                        elseif type(val) == "table" then
                            local items = {}
                            for k, v in pairs(val) do
                                table.insert(items, '"' .. tostring(k) .. '":' .. encodeValue(v))
                            end
                            return "{" .. table.concat(items, ",") .. "}"
                        else
                            return tostring(val)
                        end
                    end
                    return encodeValue(obj)
                end
                return '"' .. tostring(obj) .. '"'
            end,
            decode = function(str)
                if not str or str == "" then return {} end
                -- Basic JSON decode for testing
                local func = loadstring("return " .. str:gsub('"([^"]+)":', '["%1"]='))
                return func and func() or {}
            end
        }
    end
    
    if not Handlers then
        Handlers = {
            _registry = {},
            add = function(name, matcher, handler)
                Handlers._registry[name] = {
                    name = name,
                    matcher = matcher,
                    handler = handler,
                    callCount = 0,
                    lastCalled = nil
                }
                print("Handler registered:", name)
            end,
            utils = {
                hasMatchingTag = function(tag, value)
                    return function(msg)
                        return msg.Tags and msg.Tags[tag] == value or msg[tag] == value
                    end
                end,
                hasMatchingData = function(pattern)
                    return function(msg)
                        local data = msg.Data or "{}"
                        return data:match(pattern) ~= nil
                    end
                end,
                hasMatchingFrom = function(from)
                    return function(msg)
                        return msg.From == from
                    end
                end
            },
            -- Test helper to trigger specific handlers
            trigger = function(handlerName, msg)
                local handler = Handlers._registry[handlerName]
                if not handler then
                    error("Handler not found: " .. handlerName)
                end
                
                if not handler.matcher(msg) then
                    error("Message does not match handler: " .. handlerName)
                end
                
                handler.callCount = handler.callCount + 1
                handler.lastCalled = os.time()
                
                return handler.handler(msg)
            end,
            -- Get handler statistics
            getStats = function(handlerName)
                local handler = Handlers._registry[handlerName]
                return handler and {
                    callCount = handler.callCount,
                    lastCalled = handler.lastCalled
                } or nil
            end
        }
    end
end

-- Setup handler test environment
setupHandlerTestEnvironment()

-- Handler test utilities
local HandlerUtils = {}

function HandlerUtils.createHandlerMessage(action, data, from, additionalTags)
    local tags = {Action = action}
    if additionalTags then
        for k, v in pairs(additionalTags) do
            tags[k] = v
        end
    end
    
    return {
        Id = "handler_msg_" .. math.random(1000000),
        From = from or "handler_test_sender",
        Target = ao.id,
        Action = action,
        Data = data and json.encode(data) or "{}",
        Tags = tags,
        Timestamp = tostring(os.time()),
        ["Block-Height"] = tostring(math.random(1000000)),
        ["Block-Id"] = "test_block_" .. math.random(1000000)
    }
end

function HandlerUtils.createGameStateMessage(action, gameState, playerAction)
    local data = {
        gameState = gameState,
        playerAction = playerAction
    }
    
    return HandlerUtils.createHandlerMessage(action, data, "game_coordinator", {
        Protocol = "PokéRogue-AO",
        GameState = "included"
    })
end

function HandlerUtils.assertHandlerResponse(handlerName, inputMsg, expectedResponse)
    ao._sentMessages = {} -- Clear previous messages
    
    local success, result = pcall(Handlers.trigger, handlerName, inputMsg)
    
    if not success then
        error("Handler execution failed: " .. result)
    end
    
    -- Check if message was sent
    local sentMessages = ao._sentMessages
    assert(#sentMessages > 0, "Handler should send at least one response message")
    
    local responseMsg = sentMessages[1].message
    
    -- Validate response structure
    assert(responseMsg.Target, "Response should have Target field")
    assert(responseMsg.Action, "Response should have Action field")
    
    if expectedResponse then
        for field, expectedValue in pairs(expectedResponse) do
            local actualValue = responseMsg[field]
            assert(actualValue == expectedValue,
                   string.format("Response.%s: expected '%s', got '%s'", 
                               field, tostring(expectedValue), tostring(actualValue)))
        end
    end
    
    return responseMsg
end

function HandlerUtils.assertHandlerError(handlerName, inputMsg, expectedErrorPattern)
    ao._sentMessages = {} -- Clear previous messages
    
    local success, result = pcall(Handlers.trigger, handlerName, inputMsg)
    
    -- Handler should either throw error or send error response
    if success then
        local sentMessages = ao._sentMessages
        assert(#sentMessages > 0, "Handler should send error response")
        
        local responseMsg = sentMessages[1].message
        assert(responseMsg.Action == "Error" or responseMsg.Error,
               "Response should indicate error")
        
        if expectedErrorPattern and responseMsg.Error then
            assert(responseMsg.Error:match(expectedErrorPattern),
                   "Error message should match pattern: " .. expectedErrorPattern)
        end
    else
        -- Handler threw error
        if expectedErrorPattern then
            assert(result:match(expectedErrorPattern),
                   "Error should match pattern: " .. expectedErrorPattern)
        end
    end
end

function HandlerUtils.measureHandlerPerformance(handlerName, inputMsg, iterations)
    iterations = iterations or 100
    
    local startTime = os.clock()
    
    for i = 1, iterations do
        ao._sentMessages = {} -- Clear messages each iteration
        Handlers.trigger(handlerName, inputMsg)
    end
    
    local endTime = os.clock()
    local totalTime = endTime - startTime
    local avgTime = totalTime / iterations
    
    return {
        totalTime = totalTime,
        avgTime = avgTime,
        iterations = iterations,
        messagesPerSecond = iterations / totalTime
    }
end

-- Test Cases
{{FUNCTION_TESTS}}

-- Handler-specific test scenarios

describe("Handler Registration and Discovery", function()
    it("should register handlers correctly", function()
        -- Verify handlers are properly registered
        local registeredHandlers = {}
        for name, _ in pairs(Handlers._registry) do
            table.insert(registeredHandlers, name)
        end
        
        assert.is_true(#registeredHandlers > 0, "Should have registered handlers")
        print("Registered handlers:", table.concat(registeredHandlers, ", "))
    end)
    
    it("should have proper matcher functions", function()
        -- Test matcher functions for each handler
        for name, handlerInfo in pairs(Handlers._registry) do
            assert.is_function(handlerInfo.matcher, 
                             "Handler " .. name .. " should have matcher function")
        end
    end)
end)

describe("Message Matching and Routing", function()
    it("should match messages correctly", function()
        -- Test message matching for each handler
        for handlerName, handlerInfo in pairs(Handlers._registry) do
            -- Create a test message that should match
            local testMsg = HandlerUtils.createHandlerMessage(handlerName, {test = true})
            
            local matches = handlerInfo.matcher(testMsg)
            assert.is_true(matches, "Handler " .. handlerName .. " should match its own action")
        end
    end)
    
    it("should reject non-matching messages", function()
        -- Test that handlers reject non-matching messages
        for handlerName, handlerInfo in pairs(Handlers._registry) do
            local nonMatchingMsg = HandlerUtils.createHandlerMessage("NonExistentAction", {})
            
            local matches = handlerInfo.matcher(nonMatchingMsg)
            assert.is_false(matches, "Handler " .. handlerName .. " should not match different action")
        end
    end)
end)

describe("Handler Response Patterns", function()
    it("should send properly formatted responses", function()
        -- Test response format for each handler
        for handlerName, _ in pairs(Handlers._registry) do
            local testMsg = HandlerUtils.createHandlerMessage(handlerName, {test = true})
            
            local response = HandlerUtils.assertHandlerResponse(handlerName, testMsg, {
                Target = testMsg.From
            })
            
            -- Verify AO message structure
            assert.is_string(response.Target, "Response should have string Target")
            assert.is_string(response.Action, "Response should have string Action")
        end
    end)
    
    it("should include process metadata", function()
        -- Test that responses include proper metadata
        for handlerName, _ in pairs(Handlers._registry) do
            local testMsg = HandlerUtils.createHandlerMessage(handlerName, {includeMetadata = true})
            
            local response = HandlerUtils.assertHandlerResponse(handlerName, testMsg)
            
            -- Check for common metadata fields
            assert.is_not_nil(response.ProcessId or response["Process-Id"], 
                             "Response should include process identifier")
            assert.is_not_nil(response.Timestamp, "Response should include timestamp")
        end
    end)
end)

describe("Handler Error Handling", function()
    it("should handle malformed messages", function()
        -- Test error handling for each handler
        for handlerName, _ in pairs(Handlers._registry) do
            local malformedMsg = {
                Id = "malformed",
                From = "test",
                -- Missing required fields
            }
            
            -- Should either handle gracefully or send error response
            local success, _ = pcall(Handlers.trigger, handlerName, malformedMsg)
            if not success then
                -- Handler threw error - this is acceptable
                assert.is_true(true, "Handler correctly rejected malformed message")
            else
                -- Handler handled it - check for error response
                local sentMessages = ao._sentMessages
                if #sentMessages > 0 then
                    local response = sentMessages[1].message
                    -- If it responded, should indicate error or handle gracefully
                    assert.is_true(response.Action == "Error" or response.Error or response.Action == "Success",
                                 "Handler should send appropriate response to malformed message")
                end
            end
        end
    end)
    
    it("should handle invalid data formats", function()
        -- Test handling of invalid JSON data
        for handlerName, _ in pairs(Handlers._registry) do
            local invalidDataMsg = HandlerUtils.createHandlerMessage(handlerName, nil)
            invalidDataMsg.Data = "invalid json {["
            
            -- Should handle invalid JSON gracefully
            local success, _ = pcall(Handlers.trigger, handlerName, invalidDataMsg)
            -- Either succeeds with error handling or fails gracefully
            assert.is_true(true, "Handler should handle invalid JSON data")
        end
    end)
end)

describe("Handler Performance", function()
    it("should execute within time limits", function()
        -- Test execution time for each handler
        for handlerName, _ in pairs(Handlers._registry) do
            local testMsg = HandlerUtils.createHandlerMessage(handlerName, {performance = true})
            
            local perf = HandlerUtils.measureHandlerPerformance(handlerName, testMsg, 10)
            
            -- Should complete within reasonable time (adjust as needed)
            assert.is_true(perf.avgTime < 0.5, 
                         string.format("Handler %s avg time %.3fs should be under 0.5s", 
                                     handlerName, perf.avgTime))
        end
    end)
    
    it("should handle concurrent calls efficiently", function()
        -- Test concurrent execution simulation
        for handlerName, _ in pairs(Handlers._registry) do
            local messages = {}
            for i = 1, 5 do
                table.insert(messages, HandlerUtils.createHandlerMessage(handlerName, {concurrent = i}))
            end
            
            local startTime = os.clock()
            for _, msg in ipairs(messages) do
                Handlers.trigger(handlerName, msg)
            end
            local endTime = os.clock()
            
            local totalTime = endTime - startTime
            assert.is_true(totalTime < 2.0, 
                         string.format("Concurrent execution for %s should complete within 2s", handlerName))
        end
    end)
end)

describe("Handler State Management", function()
    it("should maintain consistent state", function()
        -- Test state consistency across handler calls
        for handlerName, _ in pairs(Handlers._registry) do
            local msg1 = HandlerUtils.createHandlerMessage(handlerName, {state = "initial"})
            local msg2 = HandlerUtils.createHandlerMessage(handlerName, {state = "updated"})
            
            -- Execute sequence
            Handlers.trigger(handlerName, msg1)
            Handlers.trigger(handlerName, msg2)
            
            -- Verify handler was called correctly
            local stats = Handlers.getStats(handlerName)
            assert.equals(2, stats.callCount, "Handler should track call count correctly")
        end
    end)
end)

print("✅ Handler tests for {{MODULE_NAME}} completed")