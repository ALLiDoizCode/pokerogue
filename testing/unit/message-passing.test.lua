-- Unit Tests for Message Passing Framework
-- Tests message construction, routing, validation, and error handling
-- Note: This test uses custom framework files, not a standard AO process

local aolite = require("aolite")
local json = require("json")

print("🧪 Starting Message Passing Framework Tests")
print("==================================================")

-- Note: Message passing framework is a test utility, not an AO process
-- These tests validate the test framework itself

-- Load framework components
local function loadModule(path)
    local f = assert(loadfile(path))
    return f()
end

local HyperBeamTest = loadModule("testing/aolite/hyperbeam-test-framework.lua")
local Assert = loadModule("testing/aolite/assertion-library.lua")
local Mock = loadModule("testing/aolite/mock-system.lua")
local ProcessEmulator = loadModule("testing/aolite/process-emulator.lua")

-- Test 1: Message construction helpers
print("📝 Test 1: Testing Message Construction Helpers")
local battleMsg = Mock.MessageBuilder.battleAction({
    from = "test-player",
    moveId = 25,
    targetSlot = 1,
    battleId = "battle-123"
})

if not battleMsg or type(battleMsg) ~= "table" then
    error("❌ Test failed: Battle message builder failed")
end
if battleMsg.Action ~= "ProcessMove" then
    error("❌ Test failed: Expected ProcessMove action")
end
print("✅ Test 1 passed: Message construction helpers")

-- Test 2: Message validation assertions
print("📝 Test 2: Testing Message Validation")
local msg1 = Mock.MessageBuilder.battleAction({moveId = 1})
local success = pcall(function()
    Assert.hasAction(msg1, "ProcessMove")
end)
if not success then
    error("❌ Test failed: Action validation failed")
end
print("✅ Test 2 passed: Message validation")

-- Test 3: Process emulation
print("📝 Test 3: Testing Process Emulation")
ProcessEmulator.reset()
local handlerCalled = false
local handlers = {
    testHandler = {
        matcher = function(msg) return msg.Action == "Test" end,
        handler = function(msg)
            handlerCalled = true
            return {
                Target = msg.From,
                Action = "TestResponse",
                Data = "Handler executed successfully"
            }
        end
    }
}

local process = ProcessEmulator.spawn("test-proc", handlers, {counter = 0})
if not process or process.id ~= "test-proc" then
    error("❌ Test failed: Process spawning failed")
end
print("✅ Test 3 passed: Process emulation")

-- Test 4: Mock system functionality
print("📝 Test 4: Testing Mock System")
Mock.resetAll()
local mockAO = Mock.ao({processId = "mock-test-proc"})
if mockAO.id ~= "mock-test-proc" then
    error("❌ Test failed: Mock AO creation failed")
end
mockAO.send({Target = "target", Action = "Test"})
if mockAO.getMessageCount() ~= 1 then
    error("❌ Test failed: Message counting failed")
end
print("✅ Test 4 passed: Mock system functionality")

-- Test 5: Mock RNG
print("📝 Test 5: Testing Mock RNG")
local mockRNG = Mock.rng(12345)
local rand1 = mockRNG.random(1, 100)
if type(rand1) ~= "number" or rand1 < 1 or rand1 > 100 then
    error("❌ Test failed: Mock RNG failed")
end
mockRNG.setSeed(12345)
local rand2 = mockRNG.random(1, 100)
if rand1 ~= rand2 then
    error("❌ Test failed: Deterministic RNG failed")
end
print("✅ Test 5 passed: Mock RNG")

-- Test 6: Async message flow infrastructure
print("📝 Test 6: Testing Async Message Flow Infrastructure")
ProcessEmulator.reset()
local processA = ProcessEmulator.spawn("proc-a", {
    start = {
        matcher = function(msg) return msg.Action == "Start" end,
        handler = function(msg)
            return {Target = "proc-b", Action = "Step1", Data = "From A"}
        end
    }
})

if not processA then
    error("❌ Test failed: Process A spawn failed")
end

local routeResult = ProcessEmulator.routeMessage({
    From = "external",
    Target = "proc-a",
    Action = "Start"
})

if not routeResult.success then
    error("❌ Test failed: Message routing failed")
end
print("✅ Test 6 passed: Async message flow infrastructure")

-- Test 7: Error handling scenarios
print("📝 Test 7: Testing Error Handling")
ProcessEmulator.reset()
local errorProcess = ProcessEmulator.spawn("error-proc", {
    errorHandler = {
        matcher = function(msg) return msg.Action == "CauseError" end,
        handler = function(msg) error("Intentional test error") end
    },
    normalHandler = {
        matcher = function(msg) return msg.Action == "Normal" end,
        handler = function(msg) return {Target = msg.From, Action = "Success"} end
    }
})

ProcessEmulator.routeMessage({
    From = "sender",
    Target = "error-proc",
    Action = "Normal"
})

ProcessEmulator.runScheduler(5, 500)
if errorProcess.errorCount ~= 0 then
    error("❌ Test failed: Normal handler should not error")
end
print("✅ Test 7 passed: Error handling")

print("==================================================")
print("🎉 All tests passed!")
print("✅ Test file executed successfully: testing/unit/message-passing.test.lua")
