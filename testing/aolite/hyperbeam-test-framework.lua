#!/usr/bin/env lua

--[[
HyperBeam Unit Testing Framework for AO Processes
Comprehensive testing framework with coroutine-based process emulation
Supports concurrent process testing, message passing validation, and state inspection
Version: 1.0.0
]]

local HyperBeamTest = {}

-- Framework configuration
local Config = {
    maxConcurrentProcesses = 10,
    defaultTimeout = 5000, -- 5 seconds in milliseconds
    tapOutput = true,
    debugMode = false,
    coverageEnabled = true
}

-- Test execution state
local TestState = {
    totalTests = 0,
    passedTests = 0,
    failedTests = 0,
    skipTests = 0,
    currentSuite = nil,
    testResults = {},
    coverage = {},
    startTime = 0,
    processes = {}, -- Active process coroutines
    messageQueues = {}, -- Process message queues
    processStates = {} -- Process state snapshots
}

-- Process emulation environment
local ProcessEmulator = {}

-- Initialize coroutine-based process
function ProcessEmulator.spawn(processId, handlers, initialState)
    local process = {
        id = processId or "process-" .. crypto.random(100000, 999999),
        handlers = handlers or {},
        state = initialState or {},
        messageQueue = {},
        running = true,
        executionTime = 0,
        messageCount = 0,
        errorCount = 0
    }
    
    -- Create process coroutine
    process.coroutine = coroutine.create(function()
        while process.running do
            -- Wait for messages
            if #process.messageQueue == 0 then
                coroutine.yield("waiting")
            else
                -- Process next message
                local msg = table.remove(process.messageQueue, 1)
                process.messageCount = process.messageCount + 1
                
                -- Simulate execution time tracking
                local startExec = os.clock()
                
                -- Find and execute matching handler
                local handled = false
                for name, handler in pairs(process.handlers) do
                    if handler.matcher and handler.matcher(msg) then
                        local success, result = pcall(handler.handler, msg)
                        if not success then
                            process.errorCount = process.errorCount + 1
                            coroutine.yield("error", result)
                        else
                            coroutine.yield("handled", result)
                        end
                        handled = true
                        break
                    end
                end
                
                if not handled then
                    coroutine.yield("no-handler", msg)
                end
                
                process.executionTime = process.executionTime + (os.clock() - startExec)
            end
        end
    end)
    
    -- Store process in global registry
    TestState.processes[process.id] = process
    TestState.messageQueues[process.id] = process.messageQueue
    TestState.processStates[process.id] = process.state
    
    return process
end

-- Send message to process
function ProcessEmulator.send(targetId, message)
    local process = TestState.processes[targetId]
    if not process then
        return {success = false, error = "Process not found: " .. targetId}
    end
    
    -- Add to message queue
    table.insert(process.messageQueue, message)
    
    -- Resume process coroutine
    local status, result, data = coroutine.resume(process.coroutine)
    
    return {
        success = status,
        result = result,
        data = data,
        queueSize = #process.messageQueue
    }
end

-- Execute process scheduler (run all processes)
function ProcessEmulator.runScheduler(maxIterations)
    maxIterations = maxIterations or 100
    local iterations = 0
    local allProcessed = false
    
    while iterations < maxIterations and not allProcessed do
        allProcessed = true
        
        for processId, process in pairs(TestState.processes) do
            if #process.messageQueue > 0 then
                allProcessed = false
                local status = coroutine.status(process.coroutine)
                
                if status == "suspended" then
                    coroutine.resume(process.coroutine)
                end
            end
        end
        
        iterations = iterations + 1
    end
    
    return {
        iterations = iterations,
        completed = allProcessed
    }
end

-- Mock AO environment setup
local function setupMockEnvironment()
    -- Global message storage for inspection
    local sentMessages = {}
    
    -- Mock ao object
    _G.ao = {
        id = "test-process-main",
        send = function(msg)
            table.insert(sentMessages, msg)
            if Config.debugMode then
                print("ao.send:", msg.Target, msg.Action)
            end
            
            -- Route to target process if exists
            if TestState.processes[msg.Target] then
                ProcessEmulator.send(msg.Target, msg)
            end
            
            return {success = true, id = "msg-" .. #sentMessages}
        end,
        getSentMessages = function()
            return sentMessages
        end,
        clearSentMessages = function()
            sentMessages = {}
        end
    }
    
    -- Mock Handlers object
    _G.Handlers = {
        _handlers = {},
        add = function(name, matcher, handler)
            _G.Handlers._handlers[name] = {
                name = name,
                matcher = matcher,
                handler = handler,
                callCount = 0
            }
            if Config.debugMode then
                print("Handler added:", name)
            end
        end,
        utils = {
            hasMatchingTag = function(tagName, tagValue)
                return function(msg)
                    if msg.Tags then
                        return msg.Tags[tagName] == tagValue
                    elseif msg[tagName] then
                        return msg[tagName] == tagValue
                    end
                    return false
                end
            end,
            continue = function(handler)
                return function(msg)
                    handler(msg)
                    return msg
                end
            end
        },
        receive = function(msg)
            for name, handler in pairs(_G.Handlers._handlers) do
                if handler.matcher(msg) then
                    handler.callCount = handler.callCount + 1
                    return handler.handler(msg)
                end
            end
            return nil
        end
    }
    
    -- Mock json object
    _G.json = {
        encode = function(obj)
            -- Simple JSON encoding
            if type(obj) == "nil" then
                return "null"
            elseif type(obj) == "boolean" then
                return tostring(obj)
            elseif type(obj) == "number" then
                return tostring(obj)
            elseif type(obj) == "string" then
                return '"' .. obj:gsub('"', '\\"') .. '"'
            elseif type(obj) == "table" then
                local isArray = true
                local count = 0
                for k, v in pairs(obj) do
                    count = count + 1
                    if type(k) ~= "number" or k ~= count then
                        isArray = false
                        break
                    end
                end
                
                if isArray then
                    local parts = {}
                    for i = 1, #obj do
                        table.insert(parts, _G.json.encode(obj[i]))
                    end
                    return "[" .. table.concat(parts, ",") .. "]"
                else
                    local parts = {}
                    for k, v in pairs(obj) do
                        table.insert(parts, '"' .. tostring(k) .. '":' .. _G.json.encode(v))
                    end
                    return "{" .. table.concat(parts, ",") .. "}"
                end
            end
            return "null"
        end,
        decode = function(str)
            -- Simplified decode for testing
            return loadstring("return " .. str:gsub('"%w+":', function(s)
                return s:gsub('"', '')
            end):gsub('[%[%]{}]', function(c)
                if c == '[' then return '{' end
                if c == ']' then return '}' end
                return c
            end))()
        end
    }
    
    -- Mock crypto for deterministic testing (AO-compliant)
    _G.crypto = {
        _seed = 12345,
        random = function(min, max)
            -- Deterministic pseudo-random for testing (AO-compliant)
            _G.crypto._seed = (_G.crypto._seed * 1103515245 + 12345) % 2147483648
            local rand = _G.crypto._seed / 2147483648
            if min and max then
                return math.floor(rand * (max - min + 1)) + min
            end
            return rand
        end,
        setSeed = function(seed)
            _G.crypto._seed = seed
        end
    }
end

-- Execution timeout simulation
local function withTimeout(func, timeoutMs)
    timeoutMs = timeoutMs or Config.defaultTimeout
    local startTime = os.clock() * 1000
    local co = coroutine.create(func)
    
    local function checkTimeout()
        local elapsed = (os.clock() * 1000) - startTime
        if elapsed > timeoutMs then
            return false, "Execution timeout: " .. elapsed .. "ms > " .. timeoutMs .. "ms"
        end
        return true
    end
    
    local status, result
    repeat
        local timeoutOk, timeoutErr = checkTimeout()
        if not timeoutOk then
            return false, timeoutErr
        end
        
        status, result = coroutine.resume(co)
    until coroutine.status(co) == "dead"
    
    return status, result
end

-- TAP output formatter
local function tapOutput(testNum, passed, description, diagnostic)
    if not Config.tapOutput then return end
    
    if passed then
        print(string.format("ok %d - %s", testNum, description))
    else
        print(string.format("not ok %d - %s", testNum, description))
        if diagnostic then
            print("  ---")
            print("  error: " .. tostring(diagnostic))
            print("  ...")
        end
    end
end

-- Test runner with TAP output
function HyperBeamTest.test(description, testFunc)
    TestState.totalTests = TestState.totalTests + 1
    local testNum = TestState.totalTests
    
    -- Setup clean environment for each test
    setupMockEnvironment()
    
    -- Clear process registry
    TestState.processes = {}
    TestState.messageQueues = {}
    TestState.processStates = {}
    
    -- Execute test with timeout
    local success, result = withTimeout(testFunc, Config.defaultTimeout)
    
    if success then
        TestState.passedTests = TestState.passedTests + 1
        tapOutput(testNum, true, description)
        table.insert(TestState.testResults, {
            name = description,
            suite = TestState.currentSuite,
            status = "pass",
            duration = 0
        })
    else
        TestState.failedTests = TestState.failedTests + 1
        tapOutput(testNum, false, description, result)
        table.insert(TestState.testResults, {
            name = description,
            suite = TestState.currentSuite,
            status = "fail",
            error = result,
            duration = 0
        })
    end
    
    return success
end

-- Test suite management
function HyperBeamTest.suite(name, tests)
    TestState.currentSuite = name
    
    if Config.tapOutput then
        print("# Test suite: " .. name)
    end
    
    -- Run all tests in suite
    for testName, testFunc in pairs(tests) do
        if type(testFunc) == "function" then
            HyperBeamTest.test(testName, testFunc)
        end
    end
    
    TestState.currentSuite = nil
end

-- Skip test
function HyperBeamTest.skip(description, reason)
    TestState.totalTests = TestState.totalTests + 1
    TestState.skipTests = TestState.skipTests + 1
    
    if Config.tapOutput then
        print(string.format("ok %d - %s # SKIP %s", 
            TestState.totalTests, description, reason or ""))
    end
end

-- Test lifecycle hooks
local lifecycleHooks = {
    beforeEach = nil,
    afterEach = nil,
    beforeAll = nil,
    afterAll = nil
}

function HyperBeamTest.beforeEach(hookFunc)
    lifecycleHooks.beforeEach = hookFunc
end

function HyperBeamTest.afterEach(hookFunc)
    lifecycleHooks.afterEach = hookFunc
end

function HyperBeamTest.beforeAll(hookFunc)
    lifecycleHooks.beforeAll = hookFunc
end

function HyperBeamTest.afterAll(hookFunc)
    lifecycleHooks.afterAll = hookFunc
end

-- Test discovery and execution
function HyperBeamTest.run(path)
    TestState.startTime = os.clock()
    
    if Config.tapOutput then
        print("TAP version 13")
        print("# HyperBeam Test Framework v1.0.0")
    end
    
    -- Execute beforeAll hook
    if lifecycleHooks.beforeAll then
        lifecycleHooks.beforeAll()
    end
    
    -- Auto-discover and run test files
    -- Note: In real implementation, would scan directory
    -- For now, tests must be manually registered
    
    -- Execute afterAll hook
    if lifecycleHooks.afterAll then
        lifecycleHooks.afterAll()
    end
    
    -- Generate summary
    local totalTime = os.clock() - TestState.startTime
    
    if Config.tapOutput then
        print(string.format("1..%d", TestState.totalTests))
        print(string.format("# Tests: %d, Passed: %d, Failed: %d, Skipped: %d",
            TestState.totalTests, TestState.passedTests, 
            TestState.failedTests, TestState.skipTests))
        print(string.format("# Duration: %.2fs", totalTime))
    end
    
    return TestState.failedTests == 0
end

-- Export process emulator for advanced testing
HyperBeamTest.ProcessEmulator = ProcessEmulator
HyperBeamTest.setupMockEnvironment = setupMockEnvironment
HyperBeamTest.withTimeout = withTimeout

-- Configuration setters
function HyperBeamTest.setConfig(key, value)
    if Config[key] ~= nil then
        Config[key] = value
    end
end

function HyperBeamTest.enableDebug()
    Config.debugMode = true
end

function HyperBeamTest.disableDebug()
    Config.debugMode = false
end

return HyperBeamTest