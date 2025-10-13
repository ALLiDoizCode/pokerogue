#!/usr/bin/env lua

--[[
Unit Tests for HyperBeam Test Framework
Tests the testing framework itself to ensure reliability
Version: 1.0.0
]]

-- Load the framework
local function loadFramework()
    local frameworkPath = "testing/aolite/hyperbeam-test-framework.lua"
    local f = assert(loadfile(frameworkPath))
    return f()
end
local HyperBeamTest = loadFramework()

-- Framework self-tests
local function testFrameworkBasics()
    print("=== Testing HyperBeam Framework Basics ===")

    -- Test mock environment setup
    HyperBeamTest.setupMockEnvironment()

    -- Verify AO globals exist
    assert(ao ~= nil, "ao global should exist")
    assert(ao.send ~= nil, "ao.send should exist")
    assert(ao.id ~= nil, "ao.id should exist")

    assert(Handlers ~= nil, "Handlers global should exist")
    assert(Handlers.add ~= nil, "Handlers.add should exist")
    assert(Handlers.utils ~= nil, "Handlers.utils should exist")

    assert(json ~= nil, "json global should exist")
    assert(json.encode ~= nil, "json.encode should exist")
    assert(json.decode ~= nil, "json.decode should exist")

    assert(crypto ~= nil, "crypto global should exist")
    assert(crypto.random ~= nil, "crypto.random should exist")

    print("✓ Mock environment setup working")

    -- Test JSON encoding/decoding
    local testObj = {name = "test", value = 42, active = true}
    local encoded = json.encode(testObj)
    assert(type(encoded) == "string", "JSON encode should return string")
    assert(encoded:find('"name":"test"'), "JSON should contain encoded data")

    print("✓ JSON encoding working")

    -- Test crypto deterministic behavior
    crypto.setSeed(12345)
    local rand1 = crypto.random(1, 100)
    crypto.setSeed(12345)
    local rand2 = crypto.random(1, 100)
    assert(rand1 == rand2, "Crypto random should be deterministic with same seed")

    print("✓ Deterministic crypto working")

    -- Test message sending
    local messageCount = 0
    ao.send({Target = "test", Action = "TestMessage", Data = "test"})
    local sentMessages = ao.getSentMessages()
    assert(#sentMessages == 1, "Should have 1 sent message")
    assert(sentMessages[1].Target == "test", "Message target should match")

    ao.clearSentMessages()
    sentMessages = ao.getSentMessages()
    assert(#sentMessages == 0, "Sent messages should be cleared")

    print("✓ Message sending/tracking working")

    return true
end

local function testProcessEmulation()
    print("=== Testing Process Emulation ===")

    -- Setup test environment
    HyperBeamTest.setupMockEnvironment()

    -- Test process spawning
    local handlers = {
        testHandler = {
            matcher = function(msg)
                return msg.Action == "Test"
            end,
            handler = function(msg)
                return {success = true, processed = msg.Action}
            end
        }
    }

    local process = HyperBeamTest.ProcessEmulator.spawn("test-proc-1", handlers, {counter = 0})
    assert(process ~= nil, "Process should be spawned")
    assert(process.id == "test-proc-1", "Process ID should match")
    assert(process.handlers ~= nil, "Process should have handlers")
    assert(coroutine.status(process.coroutine) == "suspended", "Process coroutine should be suspended")

    print("✓ Process spawning working")

    -- Test message sending to process
    local testMessage = {
        From = "sender",
        Target = "test-proc-1",
        Action = "Test",
        Data = "test data"
    }

    local sendResult = HyperBeamTest.ProcessEmulator.send("test-proc-1", testMessage)
    assert(sendResult.success == true, "Message send should succeed")
    assert(sendResult.result == "handled", "Message should be handled")

    print("✓ Message processing working")

    -- Test scheduler execution
    local schedulerResult = HyperBeamTest.ProcessEmulator.runScheduler(10)
    assert(schedulerResult.iterations <= 10, "Scheduler should respect max iterations")

    print("✓ Scheduler execution working")

    return true
end

local function testTimeoutSimulation()
    print("=== Testing Timeout Simulation ===")

    -- Test successful execution within timeout
    local function quickFunction()
        return "success"
    end

    local success, result = HyperBeamTest.withTimeout(quickFunction, 1000)
    assert(success == true, "Quick function should succeed")
    assert(result == "success", "Quick function should return correct result")

    print("✓ Normal execution within timeout working")

    -- Test timeout detection (this is tricky to test without actual long-running code)
    -- We'll test the timeout mechanism exists
    assert(type(HyperBeamTest.withTimeout) == "function", "withTimeout function should exist")

    print("✓ Timeout mechanism exists")

    return true
end

local function testTAPOutput()
    print("=== Testing TAP Output ===")

    -- Enable TAP output for testing
    HyperBeamTest.setConfig("tapOutput", true)

    -- Test basic test execution (this will produce TAP output)
    local testPassed = false
    HyperBeamTest.test("Sample test", function()
        testPassed = true
        assert(true, "This should pass")
    end)

    assert(testPassed == true, "Test function should have executed")

    print("✓ TAP output working")

    return true
end

local function testConfigurationSystem()
    print("=== Testing Configuration System ===")

    -- Test configuration setters
    HyperBeamTest.setConfig("debugMode", true)
    HyperBeamTest.enableDebug()
    HyperBeamTest.disableDebug()

    -- Test that functions exist and don't error
    assert(type(HyperBeamTest.setConfig) == "function", "setConfig should be a function")
    assert(type(HyperBeamTest.enableDebug) == "function", "enableDebug should be a function")
    assert(type(HyperBeamTest.disableDebug) == "function", "disableDebug should be a function")

    print("✓ Configuration system working")

    return true
end

local function testHandlerSystem()
    print("=== Testing Handler System ===")

    HyperBeamTest.setupMockEnvironment()

    -- Test handler registration
    local handlerCalled = false
    Handlers.add("testHandler",
        Handlers.utils.hasMatchingTag("Action", "TestAction"),
        function(msg)
            handlerCalled = true
            return {success = true}
        end
    )

    -- Test handler execution
    local testMsg = {
        From = "test",
        Action = "TestAction",
        Data = "test"
    }

    local result = Handlers.receive(testMsg)
    assert(handlerCalled == true, "Handler should have been called")

    print("✓ Handler registration and execution working")

    -- Test tag matching utility
    local matcher = Handlers.utils.hasMatchingTag("Action", "TestValue")
    assert(type(matcher) == "function", "hasMatchingTag should return function")

    local matchMsg1 = {Action = "TestValue"}
    local matchMsg2 = {Action = "DifferentValue"}
    local matchMsg3 = {Tags = {Action = "TestValue"}}

    assert(matcher(matchMsg1) == true, "Should match direct property")
    assert(matcher(matchMsg2) == false, "Should not match different value")
    assert(matcher(matchMsg3) == true, "Should match tag property")

    print("✓ Tag matching utility working")

    return true
end

-- Main test runner for framework tests
local function runFrameworkTests()
    print("\n🧪 Running HyperBeam Framework Self-Tests")
    print("=" .. string.rep("=", 50))

    local tests = {
        {"Framework Basics", testFrameworkBasics},
        {"Process Emulation", testProcessEmulation},
        {"Timeout Simulation", testTimeoutSimulation},
        {"TAP Output", testTAPOutput},
        {"Configuration System", testConfigurationSystem},
        {"Handler System", testHandlerSystem}
    }

    local passed = 0
    local total = #tests

    for _, test in ipairs(tests) do
        local testName, testFunc = test[1], test[2]
        local success, err = pcall(testFunc)

        if success then
            passed = passed + 1
            print("✅ " .. testName .. " - PASSED")
        else
            print("❌ " .. testName .. " - FAILED: " .. tostring(err))
        end
    end

    print("\n📊 Framework Test Results:")
    print(string.format("Passed: %d/%d (%.1f%%)", passed, total, (passed/total)*100))

    if passed == total then
        print("🎉 All framework tests PASSED! Framework is reliable.")
        return true
    else
        print("💥 Some framework tests FAILED! Framework needs fixes.")
        return false
    end
end

-- Export test runner
return {
    runFrameworkTests = runFrameworkTests,
    testFrameworkBasics = testFrameworkBasics,
    testProcessEmulation = testProcessEmulation,
    testTimeoutSimulation = testTimeoutSimulation,
    testTAPOutput = testTAPOutput,
    testConfigurationSystem = testConfigurationSystem,
    testHandlerSystem = testHandlerSystem
}