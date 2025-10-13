#!/usr/bin/env lua

--[[
Mock System for HyperBeam Testing Framework
Provides mock creation and management for AO processes, data sources, and RNG
Version: 1.0.0
]]

local Mock = {}

-- Mock tracking state
local MockState = {
    activeMocks = {},
    callHistory = {},
    verificationResults = {}
}

-- Message construction helpers for all game action types
Mock.MessageBuilder = {}

function Mock.MessageBuilder.battleAction(options)
    options = options or {}
    
    -- Simple JSON encoding for testing
    local function encode(obj)
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return tostring(obj)
    end
    
    return {
        From = options.from or "test-player",
        Target = options.target or "battle-engine",
        Action = options.action or "ProcessMove",
        Data = options.data or encode({
            moveId = options.moveId or 1,
            targetSlot = options.targetSlot or 0,
            battleId = options.battleId or "test-battle-123"
        }),
        Tags = {
            Action = options.action or "ProcessMove",
            Type = "BattleAction"
        },
        Timestamp = tostring(options.timestamp or 1234567890 * 1000),
        Id = options.id or "msg-" .. (crypto and crypto.random(100000, 999999) or 123456)
    }
end

function Mock.MessageBuilder.stateQuery(options)
    options = options or {}
    
    local function encode(obj)
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return tostring(obj)
    end
    
    return {
        From = options.from or "test-client",
        Target = options.target or "state-handler",
        Action = "QueryState",
        Data = options.data or encode({
            query = options.query or "player",
            filters = options.filters or {}
        }),
        Tags = {
            Action = "QueryState",
            Type = "StateQuery"
        },
        Timestamp = tostring(options.timestamp or 1234567890 * 1000),
        Id = options.id or "msg-" .. (crypto and crypto.random(100000, 999999) or 123456)
    }
end

function Mock.MessageBuilder.gameManagement(options)
    options = options or {}
    
    local function encode(obj)
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return tostring(obj)
    end
    
    return {
        From = options.from or "test-client",
        Target = options.target or "game-management",
        Action = options.action or "SaveGame",
        Data = options.data or encode({
            gameState = options.gameState or {},
            playerId = options.playerId or "test-player-123"
        }),
        Tags = {
            Action = options.action or "SaveGame",
            Type = "GameManagement"
        },
        Timestamp = tostring(options.timestamp or 1234567890 * 1000),
        Id = options.id or "msg-" .. (crypto and crypto.random(100000, 999999) or 123456)
    }
end

function Mock.MessageBuilder.adminOperation(options)
    options = options or {}
    
    return {
        From = options.from or "test-admin",
        Target = options.target or "admin-handler",
        Action = options.action or "Info",
        Data = options.data or "{}",
        Tags = {
            Action = options.action or "Info",
            Type = "AdminOperation"
        },
        Timestamp = tostring(options.timestamp or 1234567890 * 1000),
        Id = options.id or "msg-" .. (crypto and crypto.random(100000, 999999) or 123456)
    }
end

function Mock.MessageBuilder.pokemonOperation(options)
    options = options or {}
    
    local function encode(obj)
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return tostring(obj)
    end
    
    return {
        From = options.from or "test-client",
        Target = options.target or "pokemon-handler",
        Action = options.action or "EvolvePokemon",
        Data = options.data or encode({
            pokemonId = options.pokemonId or "pokemon-123",
            evolutionData = options.evolutionData or {}
        }),
        Tags = {
            Action = options.action or "EvolvePokemon",
            Type = "PokemonOperation"
        },
        Timestamp = tostring(options.timestamp or 1234567890 * 1000),
        Id = options.id or "msg-" .. (crypto and crypto.random(100000, 999999) or 123456)
    }
end

-- Response message builders
function Mock.MessageBuilder.successResponse(options)
    options = options or {}
    
    local function encode(obj)
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return tostring(obj)
    end
    
    return {
        Target = options.target or "test-client",
        Action = "SaveState",
        Data = options.data or encode({
            success = true,
            result = options.result or {},
            gameState = options.gameState or {}
        }),
        Tags = {
            Action = "SaveState",
            Type = "Response"
        },
        ProcessId = options.processId or "test-process",
        Timestamp = tostring(options.timestamp or 1234567890 * 1000)
    }
end

function Mock.MessageBuilder.errorResponse(options)
    options = options or {}
    
    local function encode(obj)
        if type(obj) == "table" then
            local parts = {}
            for k, v in pairs(obj) do
                table.insert(parts, '"' .. tostring(k) .. '":' .. (type(v) == "string" and '"' .. v .. '"' or tostring(v)))
            end
            return "{" .. table.concat(parts, ",") .. "}"
        end
        return tostring(obj)
    end
    
    return {
        Target = options.target or "test-client",
        Action = "Error",
        Error = options.error or "Test error message",
        Data = options.data or encode({
            success = false,
            error = options.error or "Test error message"
        }),
        Tags = {
            Action = "Error",
            Type = "Response"
        },
        ProcessId = options.processId or "test-process",
        Timestamp = tostring(options.timestamp or 1234567890 * 1000)
    }
end

-- Mock AO environment
function Mock.ao(config)
    config = config or {}
    
    local sentMessages = {}
    local processId = config.processId or "mock-process-" .. (crypto and crypto.random(100000, 999999) or 123456)
    
    local mockAO = {
        id = processId,
        send = function(msg)
            table.insert(sentMessages, {
                message = msg,
                timestamp = os.clock() * 1000,
                processId = processId
            })
            
            -- Track call in mock state
            local callKey = "ao.send"
            MockState.callHistory[callKey] = MockState.callHistory[callKey] or {}
            table.insert(MockState.callHistory[callKey], {
                args = {msg},
                timestamp = os.clock() * 1000,
                processId = processId
            })
            
            if config.onSend then
                config.onSend(msg)
            end
            
            return {success = true, id = "msg-" .. #sentMessages}
        end,
        getSentMessages = function()
            return sentMessages
        end,
        clearSentMessages = function()
            sentMessages = {}
        end,
        getMessageCount = function()
            return #sentMessages
        end
    }
    
    MockState.activeMocks["ao-" .. processId] = mockAO
    return mockAO
end

-- Mock process
function Mock.process(processId, handlers, config)
    config = config or {}
    processId = processId or "mock-proc-" .. (crypto and crypto.random(100000, 999999) or 123456)
    
    local processState = config.initialState or {}
    local messageQueue = {}
    local callCounts = {}
    
    local mockProcess = {
        id = processId,
        handlers = handlers or {},
        state = processState,
        messageQueue = messageQueue,
        
        addMessage = function(msg)
            table.insert(messageQueue, msg)
        end,
        
        processMessage = function(msg)
            for name, handler in pairs(handlers or {}) do
                if handler.matcher and handler.matcher(msg) then
                    callCounts[name] = (callCounts[name] or 0) + 1
                    
                    -- Track call
                    local callKey = processId .. "." .. name
                    MockState.callHistory[callKey] = MockState.callHistory[callKey] or {}
                    table.insert(MockState.callHistory[callKey], {
                        args = {msg},
                        timestamp = os.clock() * 1000,
                        processId = processId
                    })
                    
                    return handler.handler(msg)
                end
            end
            return nil
        end,
        
        getCallCount = function(handlerName)
            return callCounts[handlerName] or 0
        end,
        
        getState = function()
            return processState
        end,
        
        setState = function(newState)
            processState = newState
        end
    }
    
    MockState.activeMocks["process-" .. processId] = mockProcess
    return mockProcess
end

-- Mock message factory
function Mock.message(template)
    local defaultMsg = {
        From = "test-sender",
        Target = "test-target",
        Action = "Test",
        Data = "{}",
        Tags = {Action = "Test"},
        Timestamp = tostring(1234567890 * 1000),
        Id = "msg-" .. (crypto and crypto.random(100000, 999999) or 123456)
    }
    
    if template then
        for key, value in pairs(template) do
            defaultMsg[key] = value
        end
    end
    
    return defaultMsg
end

-- Mock RNG with deterministic behavior
function Mock.rng(seed)
    seed = seed or 12345
    local rngState = {seed = seed, calls = 0}
    
    local mockRNG = {
        random = function(min, max)
            rngState.calls = rngState.calls + 1
            rngState.seed = (rngState.seed * 1103515245 + 12345) % 2147483648
            local rand = rngState.seed / 2147483648
            
            -- Track call
            local callKey = "rng.random"
            MockState.callHistory[callKey] = MockState.callHistory[callKey] or {}
            table.insert(MockState.callHistory[callKey], {
                args = {min, max},
                result = rand,
                timestamp = os.clock() * 1000,
                seed = rngState.seed
            })
            
            if min and max then
                return math.floor(rand * (max - min + 1)) + min
            end
            return rand
        end,
        
        setSeed = function(newSeed)
            rngState.seed = newSeed
            rngState.calls = 0
        end,
        
        getSeed = function()
            return rngState.seed
        end,
        
        getCallCount = function()
            return rngState.calls
        end
    }
    
    MockState.activeMocks["rng-" .. seed] = mockRNG
    return mockRNG
end

-- Mock data source
function Mock.dataSource(data)
    data = data or {}
    local accessCounts = {}
    
    local mockDataSource = {
        get = function(key)
            accessCounts[key] = (accessCounts[key] or 0) + 1
            
            -- Track call
            local callKey = "get"
            MockState.callHistory[callKey] = MockState.callHistory[callKey] or {}
            table.insert(MockState.callHistory[callKey], {
                args = {key},
                result = data[key],
                timestamp = os.clock() * 1000
            })
            
            return data[key]
        end,
        
        set = function(key, value)
            data[key] = value
            accessCounts[key] = (accessCounts[key] or 0) + 1
            
            -- Track call
            local callKey = "set"
            MockState.callHistory[callKey] = MockState.callHistory[callKey] or {}
            table.insert(MockState.callHistory[callKey], {
                args = {key, value},
                timestamp = os.clock() * 1000
            })
        end,
        
        has = function(key)
            local hasKey = data[key] ~= nil
            
            -- Track call
            local callKey = "has"
            MockState.callHistory[callKey] = MockState.callHistory[callKey] or {}
            table.insert(MockState.callHistory[callKey], {
                args = {key},
                result = hasKey,
                timestamp = os.clock() * 1000
            })
            
            return hasKey
        end,
        
        getAccessCount = function(key)
            return accessCounts[key] or 0
        end,
        
        getAllData = function()
            return data
        end,
        
        clear = function()
            data = {}
            accessCounts = {}
        end
    }
    
    MockState.activeMocks["dataSource-" .. tostring(data)] = mockDataSource
    return mockDataSource
end

-- Mock verification functions
function Mock.verify(mockObj, method, times)
    if not mockObj then
        error("Mock object is required for verification", 2)
    end
    
    -- Use method name directly for verification since we track by method name
    local verificationKey = method
    local callHistory = MockState.callHistory[verificationKey] or {}
    local actualCalls = #callHistory
    
    local result = {
        method = method,
        expectedCalls = times,
        actualCalls = actualCalls,
        success = false,
        message = ""
    }
    
    if times == nil then
        -- Just verify it was called at least once
        result.success = actualCalls > 0
        result.message = string.format("Expected %s to be called, was called %d times",
            method, actualCalls)
    elseif type(times) == "number" then
        -- Verify exact number of calls
        result.success = actualCalls == times
        result.message = string.format("Expected %s to be called %d times, was called %d times",
            method, times, actualCalls)
    elseif type(times) == "table" then
        -- Verify call count range
        local min, max = times.min or 0, times.max or math.huge
        result.success = actualCalls >= min and actualCalls <= max
        result.message = string.format("Expected %s to be called %d-%d times, was called %d times",
            method, min, max, actualCalls)
    end
    
    table.insert(MockState.verificationResults, result)
    
    if not result.success then
        error("Mock verification failed: " .. result.message, 2)
    end
    
    return result
end

function Mock.verifyNever(mockObj, method)
    return Mock.verify(mockObj, method, 0)
end

function Mock.verifyAtLeast(mockObj, method, times)
    return Mock.verify(mockObj, method, {min = times})
end

function Mock.verifyAtMost(mockObj, method, times)
    return Mock.verify(mockObj, method, {max = times})
end

-- Mock management functions
function Mock.resetAll()
    MockState.activeMocks = {}
    MockState.callHistory = {}
    MockState.verificationResults = {}
end

function Mock.getCallHistory(key)
    return MockState.callHistory[key] or {}
end

function Mock.getVerificationResults()
    return MockState.verificationResults
end

function Mock.getActiveMocks()
    return MockState.activeMocks
end

-- Failure simulation helpers
function Mock.simulateFailure(mockObj, method, failureRate)
    failureRate = failureRate or 0.1 -- 10% failure rate by default
    
    if not mockObj[method] then
        error("Method " .. method .. " does not exist on mock object", 2)
    end
    
    local originalMethod = mockObj[method]
    
    mockObj[method] = function(...)
        if (crypto and crypto.random() or 0.5) < failureRate then
            error("Simulated failure in " .. method, 2)
        end
        return originalMethod(...)
    end
    
    return mockObj
end

function Mock.simulateLatency(mockObj, method, latencyMs)
    latencyMs = latencyMs or 100
    
    if not mockObj[method] then
        error("Method " .. method .. " does not exist on mock object", 2)
    end
    
    local originalMethod = mockObj[method]
    
    mockObj[method] = function(...)
        -- Simulate latency (in testing, this is just a delay)
        local startTime = os.clock()
        while (os.clock() - startTime) * 1000 < latencyMs do
            -- Busy wait to simulate latency
        end
        return originalMethod(...)
    end
    
    return mockObj
end

return Mock